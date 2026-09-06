#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ContextSteering2D;
using UnityEditor;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// ClickMoveTest 的 Context Steering PlayMode 验证入口，采集移动、避障、转向和调试快照证据。
    /// </summary>
    [InitializeOnLoad]
    public static class ClickMoveTestContextSteeringValidator
    {
        private const int MaximumFramesToObserve = 9000;
        private const float VectorThreshold = 0.0001f;
        private const float RequiredMoveDistance = 0.05f;
        private const string TransitGroupId = "transit";
        private const string PredictiveTargetGroupId = "predictive-target";
        private const string OrbitGroupId = "orbit";
        private const string PendingSessionKey =
            "FantasyWord.ClickMoveTestContextSteeringValidator.Pending";
        private const string ResultRelativePath =
            "Temp/UnityBridge/results/clickmove-context-steering-runtime.json";

        private static readonly Dictionary<int, Vector3> StartPositions = new();
        private static ValidationResult? s_result;
        private static int s_startFrame;

        static ClickMoveTestContextSteeringValidator()
        {
            EditorApplication.playModeStateChanged -= OnPlayModeStateChanged;
            EditorApplication.playModeStateChanged += OnPlayModeStateChanged;
        }

        public static string ResultPath => Path.GetFullPath(ResultRelativePath);

        public static string Start()
        {
            Stop();
            if (!Application.isPlaying)
            {
                WriteResult(Fail("Context Steering 运行验收只能在 PlayMode 下启动。"));
                return ResultPath;
            }

            BeginObservation();
            return ResultPath;
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
                WriteResult(Fail("启动验收前必须打开 ClickMoveTest。"));
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

        private static void OnPlayModeStateChanged(PlayModeStateChange state)
        {
            if (state != PlayModeStateChange.EnteredPlayMode ||
                !SessionState.GetBool(PendingSessionKey, false))
            {
                return;
            }

            SessionState.SetBool(PendingSessionKey, false);
            BeginObservation();
        }

        private static void BeginObservation()
        {
            ContextSteeringDebugProbe2D[] probes = FindProbes();
            AssignCombatTargets(probes);
            StartPositions.Clear();
            for (int i = 0; i < probes.Length; i++)
            {
                StartPositions[probes[i].GetInstanceID()] = probes[i].transform.position;
            }

            s_result = new ValidationResult
            {
                ScenePath = UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,
                ProbeCount = probes.Length,
                ProbeNames = probes.Select(probe => probe.name).ToArray(),
                InitialProbePositions = probes
                    .Select(probe => (Vector2)probe.transform.position)
                    .ToArray(),
                CharacterSelfCollisionIgnored = Physics2D.GetIgnoreLayerCollision(
                    LayerMask.NameToLayer("Character"),
                    LayerMask.NameToLayer("Character")),
                SimulationExists = ContextSteeringSimulation2D.Current != null,
                AgentCount = ContextSteeringSimulation2D.Current != null
                    ? ContextSteeringSimulation2D.Current.AgentCount
                    : 0,
                InitialProbeDistance = ResolveMinimumTransformDistance(probes),
                MinimumSnapshotProbeDistance = float.MaxValue,
            };
            s_startFrame = Time.frameCount;
            EditorApplication.update += Tick;
        }

        private static void Tick()
        {
            if (s_result == null)
            {
                Stop();
                return;
            }

            try
            {
                if (!Application.isPlaying)
                {
                    WriteResult(Fail("运行验收过程中 PlayMode 已退出。"));
                    Stop();
                    return;
                }

                s_result.FramesObserved = Time.frameCount - s_startFrame;
                CaptureFrame(s_result);
                if (!HasRequiredSignals(s_result) &&
                    s_result.FramesObserved < MaximumFramesToObserve)
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
            ContextSteeringDebugProbe2D[] probes = FindProbes();
            result.ProbeCount = Mathf.Max(result.ProbeCount, probes.Length);
            result.AgentCount = Mathf.Max(
                result.AgentCount,
                ContextSteeringSimulation2D.Current != null
                    ? ContextSteeringSimulation2D.Current.AgentCount
                    : 0);

            int movedCount = 0;
            for (int i = 0; i < probes.Length; i++)
            {
                ContextSteeringDebugProbe2D probe = probes[i];
                result.ObservedPushCorrection |=
                    probe.MaximumObservedPushCorrectionSqrMagnitude > VectorThreshold;
                if (StartPositions.TryGetValue(probe.GetInstanceID(), out Vector3 start))
                {
                    float moved = Vector2.Distance(start, probe.transform.position);
                    result.MaximumMoveDistance = Mathf.Max(result.MaximumMoveDistance, moved);
                    if (moved >= RequiredMoveDistance)
                    {
                        movedCount++;
                    }
                }

                SteeringDebugSnapshot2D snapshot = probe.Snapshot;
                if (snapshot == null)
                {
                    continue;
                }

                result.SnapshotProbeCount = Mathf.Max(result.SnapshotProbeCount, i + 1);
                result.ProfileName = snapshot.ProfileName;
                result.LastBehaviourGroup = snapshot.BehaviourGroupId;
                result.ObservedPathFollow |= snapshot.BehaviourGroupId == TransitGroupId;
                result.ObservedPursuit |= snapshot.BehaviourGroupId == PredictiveTargetGroupId;
                result.ObservedArriveSlowdown |= snapshot.BehaviourGroupId == PredictiveTargetGroupId &&
                    snapshot.Result.SpeedScale > 0.0f &&
                    snapshot.Result.SpeedScale < 0.99f;
                if (snapshot.BehaviourGroupId == OrbitGroupId)
                {
                    result.ObservedOrbit = true;
                    result.ObservedOrbitPreferredVelocity |=
                        snapshot.Result.PreferredVelocity.sqrMagnitude > VectorThreshold;
                    result.ObservedOrbitSafeVelocity |=
                        snapshot.Result.SafeVelocity.sqrMagnitude > VectorThreshold;
                    result.ObservedOrbitOutput |= snapshot.Result.HasOutput;
                    result.MaximumOrbitSafeSpeed = Mathf.Max(
                        result.MaximumOrbitSafeSpeed,
                        snapshot.Result.SafeVelocity.magnitude);
                }

                result.ObservedPreferredVelocity |= snapshot.Result.PreferredVelocity.sqrMagnitude > VectorThreshold;
                result.ObservedSafeVelocity |= snapshot.Result.SafeVelocity.sqrMagnitude > VectorThreshold;
                result.ObservedAvoidanceCorrection |=
                    (snapshot.Result.SafeVelocity - snapshot.Result.PreferredVelocity).sqrMagnitude > VectorThreshold;
                result.ObservedSeparationContribution |= Array.Exists(
                    snapshot.Contributions,
                    contribution => contribution.StableId == "separation");
                result.MaximumNeighbourCount = Mathf.Max(result.MaximumNeighbourCount, snapshot.Neighbours.Length);
                result.MaximumObstacleCount = Mathf.Max(result.MaximumObstacleCount, snapshot.Obstacles.Length);
                result.MaximumSemanticColliderCount = Mathf.Max(
                    result.MaximumSemanticColliderCount,
                    snapshot.DetectedColliderCount);
            }

            result.MovedProbeCount = Mathf.Max(result.MovedProbeCount, movedCount);
            CapturePairMetrics(result, probes);
        }

        private static void CapturePairMetrics(
            ValidationResult result,
            ContextSteeringDebugProbe2D[] probes)
        {
            for (int i = 0; i < probes.Length; i++)
            {
                SteeringDebugSnapshot2D? first = probes[i].Snapshot;
                if (first == null) continue;

                for (int j = i + 1; j < probes.Length; j++)
                {
                    SteeringDebugSnapshot2D? second = probes[j].Snapshot;
                    if (second == null) continue;

                    float distance = Vector2.Distance(first.Position, second.Position);
                    if (!result.CapturedFirstSnapshotPair)
                    {
                        result.CapturedFirstSnapshotPair = true;
                        result.FirstSnapshotProbeDistance = distance;
                    }

                    result.MinimumSnapshotProbeDistance = Mathf.Min(
                        result.MinimumSnapshotProbeDistance,
                        distance);
                    result.MaximumObservedPenetration = Mathf.Max(
                        result.MaximumObservedPenetration,
                        first.AgentRadius + second.AgentRadius - distance);
                }
            }
        }

        private static float ResolveMinimumTransformDistance(
            ContextSteeringDebugProbe2D[] probes)
        {
            float minimum = float.MaxValue;
            for (int i = 0; i < probes.Length; i++)
            {
                for (int j = i + 1; j < probes.Length; j++)
                {
                    minimum = Mathf.Min(
                        minimum,
                        Vector2.Distance(probes[i].transform.position, probes[j].transform.position));
                }
            }

            return minimum;
        }

        private static void FinalizeResult(ValidationResult result)
        {
            List<string> failures = new();
            Require(result.ScenePath == "Assets/Scenes/ClickMoveTest.unity", "运行的不是 ClickMoveTest。", failures);
            Require(result.SimulationExists, "场景缺少 ContextSteeringSimulation2D。", failures);
            Require(result.AgentCount >= 2, "世界模拟没有登记至少两个 NPC Agent。", failures);
            Require(result.ProbeCount >= 2, "场景缺少两个转向调试探针。", failures);
            Require(result.SnapshotProbeCount >= 2, "两个 NPC 没有都发布调试快照。", failures);
            Require(result.ObservedPathFollow, "没有观察到中间航点 transit 行为组。", failures);
            Require(
                result.ObservedPursuit || result.ObservedOrbit,
                "没有观察到最终追逐 predictive-target 或近身 orbit 行为组。",
                failures);
            Require(
                result.ObservedArriveSlowdown || result.ObservedOrbit,
                "最终阶段既没有观察到 Arrive 降速，也没有进入近身 orbit。",
                failures);
            Require(result.ObservedOrbit, "目标进入保持距离后没有切到近身 orbit 行为组。", failures);
            Require(result.ObservedOrbitPreferredVelocity, "近身 orbit 没有生成 preferred velocity。", failures);
            Require(result.ObservedOrbitSafeVelocity, "近身 orbit 没有生成 safe velocity。", failures);
            Require(result.ObservedOrbitOutput, "近身 orbit 没有产生非零转向输出。", failures);
            Require(result.ObservedPreferredVelocity, "没有生成 preferred velocity。", failures);
            Require(result.ObservedSafeVelocity, "RVO2 没有生成 safe velocity。", failures);
            Require(result.ObservedAvoidanceCorrection, "没有观察到 RVO2 对 preferred velocity 的修正。", failures);
            Require(result.ObservedSeparationContribution, "快照中缺少 Separation 行为来源。", failures);
            Require(result.MaximumSemanticColliderCount > 0, "共享检测快照没有发布语义 Collider。", failures);
            Require(result.MaximumNeighbourCount > 0, "NPC 快照没有检测到邻近 Agent。", failures);
            Require(result.ObservedPushCorrection, "初始接触没有产生 PBD push correction。", failures);
            Require(result.MovedProbeCount >= 2, "两个 NPC 没有都产生实际位移。", failures);

            result.Success = failures.Count == 0;
            result.Failures = failures.ToArray();
            result.Message = result.Success
                ? "ClickMoveTest Context Steering 运行验收通过。"
                : string.Join(" | ", failures);
            result.Completed = true;
        }

        private static bool HasRequiredSignals(ValidationResult result)
        {
            return result.ScenePath == "Assets/Scenes/ClickMoveTest.unity" &&
                result.SimulationExists &&
                result.AgentCount >= 2 &&
                result.ProbeCount >= 2 &&
                result.SnapshotProbeCount >= 2 &&
                result.ObservedPathFollow &&
                (result.ObservedPursuit || result.ObservedOrbit) &&
                (result.ObservedArriveSlowdown || result.ObservedOrbit) &&
                result.ObservedOrbit &&
                result.ObservedOrbitPreferredVelocity &&
                result.ObservedOrbitSafeVelocity &&
                result.ObservedOrbitOutput &&
                result.ObservedPreferredVelocity &&
                result.ObservedSafeVelocity &&
                result.ObservedAvoidanceCorrection &&
                result.ObservedSeparationContribution &&
                result.MaximumSemanticColliderCount > 0 &&
                result.MaximumNeighbourCount > 0 &&
                result.ObservedPushCorrection &&
                result.MovedProbeCount >= 2;
        }

        private static ContextSteeringDebugProbe2D[] FindProbes()
        {
            return UnityEngine.Object.FindObjectsByType<ContextSteeringDebugProbe2D>(
                FindObjectsInactive.Exclude,
                FindObjectsSortMode.InstanceID);
        }

        private static void AssignCombatTargets(ContextSteeringDebugProbe2D[] probes)
        {
            GameObject playerObject = GameObject.FindWithTag("Player");
            CharacterBase player = playerObject != null
                ? playerObject.GetComponent<CharacterBase>()
                : null;
            if (player == null)
            {
                throw new InvalidOperationException("ClickMoveTest 缺少 Player 角色，无法建立追击验收场景。");
            }

            for (int i = 0; i < probes.Length; i++)
            {
                CharacterBase npc = probes[i].GetComponent<CharacterBase>();
                if (npc == null ||
                    !npc.TryGetController(out AIController controller) ||
                    !controller.TrySetCombatTarget(player))
                {
                    throw new InvalidOperationException(
                        $"NPC '{probes[i].name}' 无法把玩家设为正式战斗目标。");
                }
            }
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
            StartPositions.Clear();
        }

        /// <summary>
        /// Context Steering 运行验收的 JSON 结果对象。
        /// </summary>
        [Serializable]
        public sealed class ValidationResult
        {
            public bool Completed;
            public bool Success;
            public string Message = string.Empty;
            public string ScenePath = string.Empty;
            public string ProfileName = string.Empty;
            public string LastBehaviourGroup = string.Empty;
            public string[] ProbeNames = Array.Empty<string>();
            public Vector2[] InitialProbePositions = Array.Empty<Vector2>();
            public bool CharacterSelfCollisionIgnored;
            public bool SimulationExists;
            public int AgentCount;
            public int ProbeCount;
            public int SnapshotProbeCount;
            public int MovedProbeCount;
            public int FramesObserved;
            public int MaximumNeighbourCount;
            public int MaximumObstacleCount;
            public int MaximumSemanticColliderCount;
            public float MaximumMoveDistance;
            public float MaximumOrbitSafeSpeed;
            public float InitialProbeDistance;
            public bool CapturedFirstSnapshotPair;
            public float FirstSnapshotProbeDistance;
            public float MinimumSnapshotProbeDistance;
            public float MaximumObservedPenetration;
            public bool ObservedPathFollow;
            public bool ObservedPursuit;
            public bool ObservedArriveSlowdown;
            public bool ObservedOrbit;
            public bool ObservedOrbitPreferredVelocity;
            public bool ObservedOrbitSafeVelocity;
            public bool ObservedOrbitOutput;
            public bool ObservedPreferredVelocity;
            public bool ObservedSafeVelocity;
            public bool ObservedAvoidanceCorrection;
            public bool ObservedSeparationContribution;
            public bool ObservedPushCorrection;
            public string[] Failures = Array.Empty<string>();
        }
    }
}
