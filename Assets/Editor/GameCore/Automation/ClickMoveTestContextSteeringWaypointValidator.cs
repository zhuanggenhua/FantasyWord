#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using ContextSteering2D;
using UnityEditor;
using UnityEngine;
using UnityEngine.Tilemaps;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// ClickMoveTest 的 Context Steering 航点转折 PlayMode 验证入口。
    /// 只在播放态临时摆放已有角色，验证正式地形路线的中间转折不会 Arrive 停车，也不会切角穿过不可行走格。
    /// </summary>
    [InitializeOnLoad]
    public static class ClickMoveTestContextSteeringWaypointValidator
    {
        private const double MaximumSecondsToObserve = 120.0;
        private const float RouteSampleSpacing = 0.1f;
        private const float CornerObservationRadius = 0.65f;
        private const float NonStopSpeedThreshold = 0.05f;
        private const float MinimumRequiredMoveDistance = 0.5f;
        private const float StaticClearanceSkin = 0.03f;
        private const string TransitGroupId = "transit";
        private const string PredictiveTargetGroupId = "predictive-target";
        private const string PendingSessionKey =
            "FantasyWord.ClickMoveTestContextSteeringWaypointValidator.Pending";
        private const string ResultRelativePath =
            "Temp/UnityBridge/results/clickmove-context-steering-waypoint-runtime.json";

        private static readonly Vector2 PreferredRouteStart = new(-5.5f, 5.5f);
        private static readonly Vector2 PreferredRouteDestination = new(-3.5f, 3.5f);
        private static readonly MethodInfo BuildPathWithoutDebugMethod =
            typeof(TerrainNavigationMap).GetMethod(
                "TryBuildWorldPathWithoutDebug",
                BindingFlags.Instance | BindingFlags.NonPublic);

        private static ValidationResult? s_result;
        private static TerrainNavigationMap? s_navigationMap;
        private static ContextSteeringDebugProbe2D? s_probe;
        private static CharacterBase? s_npc;
        private static CharacterBase? s_player;
        private static Vector2[] s_fullRoute = Array.Empty<Vector2>();
        private static Vector2 s_primaryCorner;
        private static Vector2 s_previousPosition;
        private static int s_startFrame;
        private static double s_startEditorTime;

        static ClickMoveTestContextSteeringWaypointValidator()
        {
            EditorApplication.playModeStateChanged -= OnPlayModeStateChanged;
            EditorApplication.playModeStateChanged += OnPlayModeStateChanged;
        }

        public static string ResultPath => Path.GetFullPath(ResultRelativePath);

        [MenuItem("Tools/FantasyWord/Validation/Start ClickMoveTest Context Steering Waypoint Validator")]
        public static void StartFromMenu()
        {
            Start();
        }

        public static string StartFromEditMode()
        {
            Stop();
            if (Application.isPlaying)
            {
                return Start();
            }

            UnityEngine.SceneManagement.Scene scene =
                UnityEngine.SceneManagement.SceneManager.GetActiveScene();
            if (scene.path != "Assets/Scenes/ClickMoveTest.unity")
            {
                WriteResult(Fail("启动航点转折验收前必须打开 ClickMoveTest。"));
                return ResultPath;
            }

            if (scene.isDirty)
            {
                WriteResult(Fail("ClickMoveTest 有未保存修改，拒绝自动进入 PlayMode。"));
                return ResultPath;
            }

            SessionState.SetBool(PendingSessionKey, true);
            EditorApplication.isPlaying = true;
            return ResultPath;
        }

        public static string Start()
        {
            Stop();
            if (!Application.isPlaying)
            {
                WriteResult(Fail("航点转折运行验收只能在 PlayMode 下启动。"));
                return ResultPath;
            }

            try
            {
                BeginObservation();
            }
            catch (Exception exception)
            {
                WriteResult(Fail(exception.ToString()));
                Stop();
            }

            return ResultPath;
        }

        private static void OnPlayModeStateChanged(PlayModeStateChange state)
        {
            if (state != PlayModeStateChange.EnteredPlayMode ||
                !SessionState.GetBool(PendingSessionKey, false))
            {
                return;
            }

            SessionState.SetBool(PendingSessionKey, false);
            Start();
        }

        private static void BeginObservation()
        {
            s_navigationMap = ResolveActiveTerrainNavigationMap();
            if (s_navigationMap == null || s_navigationMap.RuleTilemap == null)
            {
                throw new InvalidOperationException("ClickMoveTest 缺少有效 TerrainNavigationMap。");
            }

            s_player = ResolvePlayer();
            if (s_player == null)
            {
                throw new InvalidOperationException("ClickMoveTest 缺少 Player 角色。");
            }

            if (!TryResolveNpcProbe(out s_probe, out s_npc, out AIController controller))
            {
                throw new InvalidOperationException("ClickMoveTest 缺少带 AIController 的 ContextSteeringDebugProbe2D。");
            }

            float staticClearanceRadius = ResolveStaticClearanceRadius(controller);
            if (!TryResolveValidationRoute(
                    s_navigationMap,
                    PreferredRouteStart,
                    PreferredRouteDestination,
                    staticClearanceRadius,
                    out s_fullRoute,
                    out s_primaryCorner,
                    out string routeSource))
            {
                throw new InvalidOperationException("ClickMoveTest 未找到可用于航点转折验收的正式地形路线。");
            }

            s_result = new ValidationResult
            {
                ScenePath = UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,
                RouteSource = routeSource,
                NpcName = s_npc.name,
                PlayerName = s_player.name,
                RoutePoints = s_fullRoute.Select(Format).ToArray(),
                PrimaryCorner = Format(s_primaryCorner),
                StaticPathCutCornerViolationCount =
                    CountSurfaceViolationsAlongPolyline(s_navigationMap, s_fullRoute),
                StaticPhysicsClearanceRadius = staticClearanceRadius,
                StaticPhysicsClearanceViolationCount =
                    CountPhysicsClearanceViolationsAlongPolyline(s_fullRoute, staticClearanceRadius),
                RequiredMoveDistance =
                    CalculateRequiredMoveDistance(s_fullRoute[0], s_primaryCorner),
                MinimumTransitSpeedNearCorner = float.MaxValue,
                MinimumDistanceToCorner = float.MaxValue,
                MinimumDistanceToDestination = float.MaxValue,
            };
            s_result.CornerCount = CountCorners(s_fullRoute);
            s_result.RouteLength = CalculatePolylineLength(s_fullRoute);

            PositionCharacter(s_npc, s_fullRoute[0]);
            PositionCharacter(s_player, s_fullRoute[^1]);
            MoveOtherProbesAway(s_probe, s_fullRoute[0], s_result);
            if (!controller.TrySetCombatTarget(s_player))
            {
                throw new InvalidOperationException($"NPC '{s_npc.name}' 无法把玩家设为正式战斗目标。");
            }

            s_previousPosition = s_npc.transform.position;
            s_startFrame = Time.frameCount;
            s_startEditorTime = EditorApplication.timeSinceStartup;
            EditorApplication.update += Tick;
        }

        private static void Tick()
        {
            if (s_result == null || s_navigationMap == null || s_probe == null || s_npc == null)
            {
                Stop();
                return;
            }

            try
            {
                if (!Application.isPlaying)
                {
                    WriteResult(Fail("航点转折验收过程中 PlayMode 已退出。"));
                    Stop();
                    return;
                }

                s_result.FramesObserved = Time.frameCount - s_startFrame;
                s_result.SecondsObserved = (float)(EditorApplication.timeSinceStartup - s_startEditorTime);
                CaptureFrame(s_result);
                if (!HasRequiredSignals(s_result) &&
                    s_result.SecondsObserved < MaximumSecondsToObserve)
                {
                    return;
                }

                FinalizeResult(s_result);
                WriteResult(s_result);
                Stop();
            }
            catch (Exception exception)
            {
                WriteResult(Fail(exception.ToString()));
                Stop();
            }
        }

        private static void CaptureFrame(ValidationResult result)
        {
            Vector2 currentPosition = s_npc.transform.position;
            result.MaximumMoveDistance = Mathf.Max(
                result.MaximumMoveDistance,
                Vector2.Distance(s_fullRoute[0], currentPosition));
            result.MinimumDistanceToCorner = Mathf.Min(
                result.MinimumDistanceToCorner,
                Vector2.Distance(currentPosition, s_primaryCorner));
            result.MinimumDistanceToDestination = Mathf.Min(
                result.MinimumDistanceToDestination,
                Vector2.Distance(currentPosition, s_fullRoute[^1]));
            result.RuntimeCutCornerViolationCount += CountSurfaceViolationsAlongSegment(
                s_navigationMap!,
                s_previousPosition,
                currentPosition);
            s_previousPosition = currentPosition;

            SteeringDebugSnapshot2D snapshot = s_probe!.Snapshot;
            if (snapshot == null)
            {
                return;
            }

            result.LastBehaviourGroup = snapshot.BehaviourGroupId;
            result.ObservedTransit |= snapshot.BehaviourGroupId == TransitGroupId;
            result.ObservedFinalGroup |= snapshot.BehaviourGroupId == PredictiveTargetGroupId;
            result.ObservedPreferredVelocity |= snapshot.Result.PreferredVelocity.sqrMagnitude > 0.0001f;
            result.ObservedSafeVelocity |= snapshot.Result.SafeVelocity.sqrMagnitude > 0.0001f;

            float speed = snapshot.Result.SafeVelocity.magnitude;
            float distanceToCorner = Vector2.Distance(currentPosition, s_primaryCorner);
            if (snapshot.BehaviourGroupId == TransitGroupId &&
                distanceToCorner <= CornerObservationRadius)
            {
                result.ObservedCornerTransit = true;
                result.MinimumTransitSpeedNearCorner = Mathf.Min(
                    result.MinimumTransitSpeedNearCorner,
                    speed);
                result.MaximumTransitSpeedNearCorner = Mathf.Max(
                    result.MaximumTransitSpeedNearCorner,
                    speed);
            }
        }

        private static void FinalizeResult(ValidationResult result)
        {
            List<string> failures = new();
            Require(result.ScenePath == "Assets/Scenes/ClickMoveTest.unity", "运行的不是 ClickMoveTest。", failures);
            Require(result.CornerCount > 0, "验证路线没有正式转折点。", failures);
            Require(result.StaticPathCutCornerViolationCount == 0, "正式地形路线采样穿过不可行走格。", failures);
            Require(result.StaticPhysicsClearanceViolationCount == 0, "正式地形路线采样穿过真实碰撞体。", failures);
            Require(result.ObservedTransit, "没有观察到中间航点 transit 行为组。", failures);
            Require(result.ObservedCornerTransit, "NPC 没有在转角附近保持 transit 行为组。", failures);
            Require(
                result.MinimumTransitSpeedNearCorner >= NonStopSpeedThreshold,
                $"转角附近 transit 速度低于 {NonStopSpeedThreshold:0.###}，疑似中间航点停车。",
                failures);
            Require(result.ObservedFinalGroup, "没有观察到最终 predictive-target 行为组。", failures);
            Require(result.ObservedPreferredVelocity, "没有生成 preferred velocity。", failures);
            Require(result.ObservedSafeVelocity, "没有生成 safe velocity。", failures);
            Require(result.RuntimeCutCornerViolationCount == 0, "NPC 实际移动轨迹穿过不可行走格。", failures);
            Require(
                result.MaximumMoveDistance >= result.RequiredMoveDistance,
                "NPC 实际移动距离不足，未覆盖转折路线。",
                failures);

            result.Completed = true;
            result.Success = failures.Count == 0;
            result.Failures = failures.ToArray();
            result.Message = result.Success
                ? "ClickMoveTest 航点转折运行验收通过：中间转折保持 transit 且轨迹没有切角穿越阻挡格。"
                : string.Join(" | ", failures);
        }

        private static bool HasRequiredSignals(ValidationResult result)
        {
            return result.ScenePath == "Assets/Scenes/ClickMoveTest.unity" &&
                result.CornerCount > 0 &&
                result.StaticPathCutCornerViolationCount == 0 &&
                result.StaticPhysicsClearanceViolationCount == 0 &&
                result.ObservedTransit &&
                result.ObservedCornerTransit &&
                result.MinimumTransitSpeedNearCorner >= NonStopSpeedThreshold &&
                result.ObservedFinalGroup &&
                result.ObservedPreferredVelocity &&
                result.ObservedSafeVelocity &&
                result.RuntimeCutCornerViolationCount == 0 &&
                result.MaximumMoveDistance >= result.RequiredMoveDistance;
        }

        private static bool TryResolveValidationRoute(
            TerrainNavigationMap navigationMap,
            Vector2 start,
            Vector2 destination,
            float staticClearanceRadius,
            out Vector2[] fullRoute,
            out Vector2 primaryCorner,
            out string routeSource)
        {
            if (TryBuildWorldPathWithoutDebug(navigationMap, start, destination, out Vector2[] path) &&
                TryCreateFullRoute(start, path, out fullRoute, out primaryCorner) &&
                CountSurfaceViolationsAlongPolyline(navigationMap, fullRoute) == 0 &&
                CountPhysicsClearanceViolationsAlongPolyline(fullRoute, staticClearanceRadius) == 0)
            {
                routeSource = "preferred-clickmove-corner";
                return true;
            }

            return TryFindFallbackRoute(
                navigationMap,
                staticClearanceRadius,
                out fullRoute,
                out primaryCorner,
                out routeSource);
        }

        private static bool TryFindFallbackRoute(
            TerrainNavigationMap navigationMap,
            float staticClearanceRadius,
            out Vector2[] fullRoute,
            out Vector2 primaryCorner,
            out string routeSource)
        {
            fullRoute = Array.Empty<Vector2>();
            primaryCorner = default;
            routeSource = string.Empty;

            Tilemap tilemap = navigationMap.RuleTilemap;
            if (tilemap == null)
            {
                return false;
            }

            List<Vector3Int> walkableCells = new();
            foreach (Vector3Int cell in tilemap.cellBounds.allPositionsWithin)
            {
                if (navigationMap.TryGetSurfaceSample(cell, out _))
                {
                    walkableCells.Add(cell);
                }
            }

            float bestLength = float.MaxValue;
            for (int i = 0; i < walkableCells.Count; i++)
            {
                Vector3Int startCell = walkableCells[i];
                Vector2 candidateStart = tilemap.GetCellCenterWorld(startCell);
                for (int j = 0; j < walkableCells.Count; j++)
                {
                    Vector3Int destinationCell = walkableCells[j];
                    int manhattanDistance =
                        Mathf.Abs(startCell.x - destinationCell.x) +
                        Mathf.Abs(startCell.y - destinationCell.y);
                    if (manhattanDistance < 5 || manhattanDistance > 10)
                    {
                        continue;
                    }

                    Vector2 candidateDestination = tilemap.GetCellCenterWorld(destinationCell);
                    if (!TryBuildWorldPathWithoutDebug(
                            navigationMap,
                            candidateStart,
                            candidateDestination,
                            out Vector2[] path) ||
                        !TryCreateFullRoute(candidateStart, path, out Vector2[] candidateRoute, out Vector2 corner))
                    {
                        continue;
                    }

                    float length = CalculatePolylineLength(candidateRoute);
                    if (length < 3.0f ||
                        length > 8.0f ||
                        length >= bestLength ||
                        Vector2.Distance(corner, candidateRoute[^1]) < 1.6f ||
                        CountSurfaceViolationsAlongPolyline(navigationMap, candidateRoute) > 0 ||
                        CountPhysicsClearanceViolationsAlongPolyline(candidateRoute, staticClearanceRadius) > 0)
                    {
                        continue;
                    }

                    bestLength = length;
                    fullRoute = candidateRoute;
                    primaryCorner = corner;
                    routeSource = $"fallback:{startCell}->{destinationCell}";
                }
            }

            return fullRoute.Length > 0;
        }

        private static bool TryBuildWorldPathWithoutDebug(
            TerrainNavigationMap navigationMap,
            Vector2 start,
            Vector2 destination,
            out Vector2[] path)
        {
            path = Array.Empty<Vector2>();
            if (BuildPathWithoutDebugMethod == null)
            {
                return false;
            }

            object[] args = { start, destination, null };
            bool success = (bool)BuildPathWithoutDebugMethod.Invoke(navigationMap, args);
            if (!success)
            {
                return false;
            }

            path = (Vector2[])args[2];
            return path.Length > 0;
        }

        private static bool TryCreateFullRoute(
            Vector2 start,
            IReadOnlyList<Vector2> path,
            out Vector2[] fullRoute,
            out Vector2 primaryCorner)
        {
            primaryCorner = default;
            if (path == null || path.Count < 2)
            {
                fullRoute = Array.Empty<Vector2>();
                return false;
            }

            List<Vector2> route = new(path.Count + 1) { start };
            route.AddRange(path);
            if (CountCorners(route) <= 0)
            {
                fullRoute = Array.Empty<Vector2>();
                return false;
            }

            for (int i = 1; i < route.Count - 1; i++)
            {
                Vector2 previous = route[i] - route[i - 1];
                Vector2 next = route[i + 1] - route[i];
                float cross = previous.x * next.y - previous.y * next.x;
                if (Mathf.Abs(cross) <= 0.0001f)
                {
                    continue;
                }

                if (Vector2.Distance(route[i], route[^1]) >= 1.6f)
                {
                    primaryCorner = route[i];
                    fullRoute = route.ToArray();
                    return true;
                }
            }

            fullRoute = Array.Empty<Vector2>();
            return false;
        }

        private static int CountCorners(IReadOnlyList<Vector2> points)
        {
            int count = 0;
            for (int i = 1; i < points.Count - 1; i++)
            {
                Vector2 previous = points[i] - points[i - 1];
                Vector2 next = points[i + 1] - points[i];
                float cross = previous.x * next.y - previous.y * next.x;
                if (Mathf.Abs(cross) > 0.0001f)
                {
                    count++;
                }
            }

            return count;
        }

        private static float CalculatePolylineLength(IReadOnlyList<Vector2> points)
        {
            float length = 0.0f;
            for (int i = 1; i < points.Count; i++)
            {
                length += Vector2.Distance(points[i - 1], points[i]);
            }

            return length;
        }

        private static float CalculateRequiredMoveDistance(Vector2 routeStart, Vector2 primaryCorner)
        {
            // The cursor may advance before the exact corner center; entering the non-stop
            // observation band is the behaviour contract this validator is proving.
            return Mathf.Max(
                MinimumRequiredMoveDistance,
                Vector2.Distance(routeStart, primaryCorner) - CornerObservationRadius);
        }

        private static int CountSurfaceViolationsAlongPolyline(
            TerrainNavigationMap navigationMap,
            IReadOnlyList<Vector2> points)
        {
            int violations = 0;
            for (int i = 1; i < points.Count; i++)
            {
                violations += CountSurfaceViolationsAlongSegment(
                    navigationMap,
                    points[i - 1],
                    points[i]);
            }

            return violations;
        }

        private static int CountSurfaceViolationsAlongSegment(
            TerrainNavigationMap navigationMap,
            Vector2 from,
            Vector2 to)
        {
            float distance = Vector2.Distance(from, to);
            int steps = Mathf.Max(1, Mathf.CeilToInt(distance / RouteSampleSpacing));
            int violations = 0;
            for (int i = 0; i <= steps; i++)
            {
                Vector2 sample = Vector2.Lerp(from, to, i / (float)steps);
                if (!navigationMap.TryGetSurfaceSample(sample, out _))
                {
                    violations++;
                }
            }

            return violations;
        }

        private static int CountPhysicsClearanceViolationsAlongPolyline(
            IReadOnlyList<Vector2> points,
            float clearanceRadius)
        {
            int violations = 0;
            for (int i = 1; i < points.Count; i++)
            {
                violations += CountPhysicsClearanceViolationsAlongSegment(
                    points[i - 1],
                    points[i],
                    clearanceRadius);
            }

            return violations;
        }

        private static int CountPhysicsClearanceViolationsAlongSegment(
            Vector2 from,
            Vector2 to,
            float clearanceRadius)
        {
            float distance = Vector2.Distance(from, to);
            int steps = Mathf.Max(1, Mathf.CeilToInt(distance / RouteSampleSpacing));
            int violations = 0;
            for (int i = 0; i <= steps; i++)
            {
                Vector2 sample = Vector2.Lerp(from, to, i / (float)steps);
                if (HasBlockingCollider(sample, clearanceRadius))
                {
                    violations++;
                }
            }

            return violations;
        }

        private static bool HasBlockingCollider(Vector2 position, float clearanceRadius)
        {
            foreach (Collider2D collider in Physics2D.OverlapCircleAll(position, clearanceRadius))
            {
                if (collider != null &&
                    !collider.isTrigger &&
                    collider.GetComponentInParent<CharacterBase>() == null)
                {
                    return true;
                }
            }

            return false;
        }

        private static float ResolveStaticClearanceRadius(AIController controller)
        {
            FieldInfo profileField = typeof(AIController).GetField(
                "m_steeringProfile",
                BindingFlags.Instance | BindingFlags.NonPublic);
            if (profileField?.GetValue(controller) is ContextSteeringProfile2D profile)
            {
                return Mathf.Max(profile.AgentRadius - StaticClearanceSkin, 0.1f);
            }

            return 0.3f;
        }

        private static TerrainNavigationMap? ResolveActiveTerrainNavigationMap()
        {
            return UnityEngine.Object.FindFirstObjectByType<TerrainNavigationMap>(
                FindObjectsInactive.Exclude);
        }

        private static CharacterBase? ResolvePlayer()
        {
            GameObject playerObject = GameObject.FindWithTag("Player");
            CharacterBase player = playerObject != null
                ? playerObject.GetComponent<CharacterBase>()
                : null;
            if (player != null)
            {
                return player;
            }

            if (GameManager.Exists() && GameManager.HasSystem<PlayerSystem>())
            {
                return GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
            }

            return null;
        }

        private static bool TryResolveNpcProbe(
            out ContextSteeringDebugProbe2D? probe,
            out CharacterBase? npc,
            out AIController controller)
        {
            foreach (ContextSteeringDebugProbe2D candidate in
                     UnityEngine.Object.FindObjectsByType<ContextSteeringDebugProbe2D>(
                         FindObjectsInactive.Exclude,
                         FindObjectsSortMode.InstanceID))
            {
                CharacterBase character = candidate.GetComponent<CharacterBase>();
                if (character != null &&
                    character.TryGetController(out controller))
                {
                    probe = candidate;
                    npc = character;
                    return true;
                }
            }

            probe = null;
            npc = null;
            controller = null;
            return false;
        }

        private static void PositionCharacter(CharacterBase character, Vector2 position)
        {
            character.transform.position = new Vector3(position.x, position.y, character.transform.position.z);
            if (character.TryGetComponent(out Rigidbody2D body))
            {
                body.position = position;
                body.linearVelocity = Vector2.zero;
                body.angularVelocity = 0.0f;
            }

            character.SetSteeringMotion(1.0f, Vector2.zero);
            character.SetMovementDirection(Vector2.zero);
        }

        private static void MoveOtherProbesAway(
            ContextSteeringDebugProbe2D activeProbe,
            Vector2 routeStart,
            ValidationResult result)
        {
            List<string> movedNames = new();
            Vector2 away = routeStart + new Vector2(16.0f, 16.0f);
            foreach (ContextSteeringDebugProbe2D probe in
                     UnityEngine.Object.FindObjectsByType<ContextSteeringDebugProbe2D>(
                         FindObjectsInactive.Exclude,
                         FindObjectsSortMode.InstanceID))
            {
                if (probe == activeProbe ||
                    !probe.TryGetComponent(out CharacterBase character))
                {
                    continue;
                }

                PositionCharacter(character, away);
                movedNames.Add(probe.name);
                away += new Vector2(1.0f, 0.0f);
            }

            result.MovedOtherProbeNames = movedNames.ToArray();
        }

        private static ValidationResult Fail(string message)
        {
            return new ValidationResult
            {
                Completed = true,
                Success = false,
                Message = message,
                Failures = new[] { message },
            };
        }

        private static void Require(bool condition, string failure, List<string> failures)
        {
            if (!condition)
            {
                failures.Add(failure);
            }
        }

        private static void WriteResult(ValidationResult result)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(ResultPath)!);
            File.WriteAllText(ResultPath, JsonUtility.ToJson(result, true));
        }

        private static void Stop()
        {
            EditorApplication.update -= Tick;
            SessionState.SetBool(PendingSessionKey, false);
            s_result = null;
            s_navigationMap = null;
            s_probe = null;
            s_npc = null;
            s_player = null;
            s_fullRoute = Array.Empty<Vector2>();
            s_primaryCorner = default;
            s_previousPosition = default;
            s_startEditorTime = 0.0;
        }

        private static string Format(Vector2 value) => $"({value.x:0.###}, {value.y:0.###})";

        [Serializable]
        public sealed class ValidationResult
        {
            public bool Completed;
            public bool Success;
            public string Message = string.Empty;
            public string ScenePath = string.Empty;
            public string RouteSource = string.Empty;
            public string NpcName = string.Empty;
            public string PlayerName = string.Empty;
            public string[] MovedOtherProbeNames = Array.Empty<string>();
            public string[] RoutePoints = Array.Empty<string>();
            public string PrimaryCorner = string.Empty;
            public string LastBehaviourGroup = string.Empty;
            public int FramesObserved;
            public float SecondsObserved;
            public int CornerCount;
            public float RouteLength;
            public float MaximumMoveDistance;
            public float RequiredMoveDistance;
            public float MinimumDistanceToCorner;
            public float MinimumDistanceToDestination;
            public float MinimumTransitSpeedNearCorner;
            public float MaximumTransitSpeedNearCorner;
            public float StaticPhysicsClearanceRadius;
            public int StaticPathCutCornerViolationCount;
            public int StaticPhysicsClearanceViolationCount;
            public int RuntimeCutCornerViolationCount;
            public bool ObservedTransit;
            public bool ObservedCornerTransit;
            public bool ObservedFinalGroup;
            public bool ObservedPreferredVelocity;
            public bool ObservedSafeVelocity;
            public string[] Failures = Array.Empty<string>();
        }
    }
}
