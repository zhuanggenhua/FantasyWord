#nullable enable

using System;
using System.IO;
using System.Reflection;
using ContextSteering2D;
using UnityEditor;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// ClickMoveTest 的“NPC 攻击后继续追击 / 玩家受击后恢复”PlayMode 验证入口。
    /// 只在播放态临时摆放当前场景已有玩家和 NPC，不保存运行态场景。
    /// </summary>
    [InitializeOnLoad]
    public static class ClickMoveTestPostAttackChaseValidator
    {
        private const int MaximumFramesToObserveHit = 240;
        private const int MaximumFramesToObserveChase = 240;
        private const float PlayerMoveAwayDistance = 2.6f;
        private const float NpcAttackSetupDistance = 0.72f;
        private const float RequiredNpcMoveDistance = 0.2f;
        private const float RequiredFinalAttackDistance = 1.45f;
        private const string PendingSessionKey =
            "FantasyWord.ClickMoveTestPostAttackChaseValidator.Pending";
        private const string ResultRelativePath =
            "Temp/UnityBridge/results/clickmove-post-attack-chase-runtime.json";

        private static readonly FieldInfo MovementDirectionField =
            typeof(Movable).GetField("m_movementDirection", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly FieldInfo TargetField =
            typeof(AIController).GetField("m_target", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly FieldInfo UseOrbitField =
            typeof(AIController).GetField("m_useTargetOrbitSteeringAtSoughtDistance", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly FieldInfo OrbitGroupField =
            typeof(AIController).GetField("m_targetOrbitSteeringGroupId", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly PropertyInfo ShouldUseOrbitProperty =
            typeof(AIController).GetProperty("ShouldUseTargetOrbitSteeringAtSoughtDistance", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly PropertyInfo BehaviourRuntimeProperty =
            typeof(AIController).GetProperty("behaviourRuntime", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly FieldInfo SteeringAdapterField =
            typeof(AIController)
                .GetNestedType("BehaviourRuntime", BindingFlags.NonPublic)
                ?.GetField("m_steeringAdapter", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly FieldInfo TargetPositionField =
            typeof(AIController)
                .GetNestedType("BehaviourRuntime", BindingFlags.NonPublic)
                ?.GetField("m_targetPosition", BindingFlags.Instance | BindingFlags.NonPublic);

        private static ValidationResult? s_result;
        private static CharacterBase? s_player;
        private static CharacterBase? s_npc;
        private static AIController? s_controller;
        private static MonoBehaviour? s_playerCharacterActionAnimatorDriver;
        private static MonoBehaviour? s_npcCharacterActionAnimatorDriver;
        private static Vector2 s_npcPositionWhenPlayerMoved;
        private static int s_phase;
        private static int s_phaseStartFrame;

        static ClickMoveTestPostAttackChaseValidator()
        {
            EditorApplication.playModeStateChanged -= OnPlayModeStateChanged;
            EditorApplication.playModeStateChanged += OnPlayModeStateChanged;
        }

        public static string ResultPath => Path.GetFullPath(ResultRelativePath);

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
                WriteResult(Fail("启动攻击后追击验收前必须打开 ClickMoveTest。"));
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
                WriteResult(Fail("攻击后追击验收只能在 PlayMode 下启动。"));
                return ResultPath;
            }

            BeginObservation();
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
            s_result = new ValidationResult
            {
                ScenePath = UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,
                StartFrame = Time.frameCount,
                MinimumDistanceAfterPlayerMoved = float.MaxValue,
            };

            try
            {
                if (!TryResolveParticipants(out s_player, out s_npc, out s_controller))
                {
                    FinalizeResult("ClickMoveTest 缺少可验证的玩家或带 AIController 的真实 NPC。");
                    return;
                }

                s_playerCharacterActionAnimatorDriver = ResolveCharacterActionAnimatorDriver(s_player);
                s_npcCharacterActionAnimatorDriver = ResolveCharacterActionAnimatorDriver(s_npc);
                InitializeCombatSetup(s_result);
                s_phase = 0;
                s_phaseStartFrame = Time.frameCount;
                EditorApplication.update += Tick;
            }
            catch (Exception exception)
            {
                WriteResult(Fail(exception.ToString()));
                Stop();
            }
        }

        private static void InitializeCombatSetup(ValidationResult result)
        {
            if (s_player == null || s_npc == null || s_controller == null)
            {
                throw new InvalidOperationException("攻击后追击验收初始化缺少玩家、NPC 或 AIController。");
            }

            Vector2 playerPosition = s_player.transform.position;
            Vector2 npcPosition = playerPosition + Vector2.up * NpcAttackSetupDistance;
            PositionCharacter(s_player, playerPosition);
            PositionCharacter(s_npc, npcPosition);
            InvokeTryPlayAnimation(s_playerCharacterActionAnimatorDriver, "Idle");
            InvokeTryPlayAnimation(s_npcCharacterActionAnimatorDriver, "Idle");

            result.PlayerName = s_player.name;
            result.NpcName = s_npc.name;
            result.PlayerPositionAtStart = Format(s_player.transform.position);
            result.NpcPositionAtStart = Format(s_npc.transform.position);
            result.NpcTrySetCombatTargetResult = s_controller.TrySetCombatTarget(s_player);
            result.OrbitEnabledField = UseOrbitField != null && (bool)UseOrbitField.GetValue(s_controller);
            result.OrbitGroupId = OrbitGroupField?.GetValue(s_controller)?.ToString() ?? string.Empty;
            result.ShouldUseOrbitResolved = ShouldUseOrbitProperty != null &&
                (bool)ShouldUseOrbitProperty.GetValue(s_controller);

            if (!result.NpcTrySetCombatTargetResult)
            {
                throw new InvalidOperationException($"NPC '{s_npc.name}' 无法把玩家设为正式战斗目标。");
            }
        }

        private static void Tick()
        {
            if (s_result == null)
            {
                Stop();
                return;
            }

            if (!Application.isPlaying)
            {
                FinalizeResult("攻击后追击验收过程中 PlayMode 已退出。");
                return;
            }

            try
            {
                if (s_phase == 0)
                {
                    ObserveUntilPlayerHit(s_result);
                }
                else
                {
                    ObservePostHitChase(s_result);
                }
            }
            catch (Exception exception)
            {
                WriteResult(Fail(exception.ToString()));
                Stop();
            }
        }

        private static void ObserveUntilPlayerHit(ValidationResult result)
        {
            string playerAnimation = GetCurrentAnimationKey(s_playerCharacterActionAnimatorDriver);
            if (string.Equals(playerAnimation, "Dmg", StringComparison.Ordinal))
            {
                result.PlayerHitFrame = Time.frameCount;
                result.PlayerAnimationAtHit = playerAnimation;
                MovePlayerAwayAfterHit(result);
                s_phase = 1;
                s_phaseStartFrame = Time.frameCount;
                return;
            }

            if (Time.frameCount - s_phaseStartFrame > MaximumFramesToObserveHit)
            {
                FinalizeResult("限定帧数内没有观察到玩家进入 Dmg 受击动作，未命中用户描述的攻击后症状。");
            }
        }

        private static void MovePlayerAwayAfterHit(ValidationResult result)
        {
            if (s_player == null || s_npc == null || s_controller == null)
            {
                return;
            }

            Vector2 away = (Vector2)s_player.transform.position - (Vector2)s_npc.transform.position;
            if (away.sqrMagnitude <= 0.0001f)
            {
                away = Vector2.down;
            }

            away.Normalize();
            Vector2 desiredPlayerMovedPosition =
                (Vector2)s_player.transform.position + away * PlayerMoveAwayDistance;
            Vector2 playerMovedPosition = ResolveReachablePlayerMovePosition(
                (Vector2)s_player.transform.position,
                desiredPlayerMovedPosition,
                s_npc.transform.position,
                out string resolutionStatus);
            PositionCharacter(s_player, playerMovedPosition);
            s_controller.TrySetCombatTarget(s_player);

            s_npcPositionWhenPlayerMoved = s_npc.transform.position;
            result.PlayerMovedFrame = Time.frameCount;
            result.PlayerMoveDesiredPosition = Format(desiredPlayerMovedPosition);
            result.PlayerMoveResolutionStatus = resolutionStatus;
            result.PlayerPositionAfterMove = Format(s_player.transform.position);
            result.NpcPositionWhenPlayerMoved = Format(s_npc.transform.position);
            result.InitialDistanceAfterPlayerMoved = Vector2.Distance(
                s_player.transform.position,
                s_npc.transform.position);
        }

        private static Vector2 ResolveReachablePlayerMovePosition(
            Vector2 currentPlayerPosition,
            Vector2 desiredPosition,
            Vector2 npcPosition,
            out string resolutionStatus)
        {
            TerrainNavigationMap navigationMap = UnityEngine.Object.FindFirstObjectByType<TerrainNavigationMap>(
                FindObjectsInactive.Exclude);
            if (navigationMap == null)
            {
                resolutionStatus = "未找到 TerrainNavigationMap，使用原始拉开点。";
                return desiredPosition;
            }

            float requiredDistance = Mathf.Max(RequiredFinalAttackDistance + 0.5f, 2.0f);
            if (TryResolveReachableDestination(
                    navigationMap,
                    npcPosition,
                    desiredPosition,
                    requiredDistance,
                    out Vector2 resolvedDesired))
            {
                resolutionStatus = "原始拉开点已吸附到可追击导航点。";
                return resolvedDesired;
            }

            Vector2[] directions =
            {
                Vector2.right,
                Vector2.left,
                Vector2.up,
                Vector2.down,
                new(1.0f, 1.0f),
                new(-1.0f, 1.0f),
                new(1.0f, -1.0f),
                new(-1.0f, -1.0f),
            };

            for (int i = 0; i < directions.Length; i++)
            {
                Vector2 direction = directions[i].normalized;
                Vector2 candidate = currentPlayerPosition + direction * PlayerMoveAwayDistance;
                if (TryResolveReachableDestination(
                        navigationMap,
                        npcPosition,
                        candidate,
                        requiredDistance,
                        out Vector2 resolvedCandidate))
                {
                    resolutionStatus = $"原始拉开点不可追，改用可追击导航点 {i + 1}。";
                    return resolvedCandidate;
                }
            }

            resolutionStatus = "没有找到足够远的可追击导航点，使用原始拉开点。";
            return desiredPosition;
        }

        private static bool TryResolveReachableDestination(
            TerrainNavigationMap navigationMap,
            Vector2 npcPosition,
            Vector2 candidatePosition,
            float requiredDistance,
            out Vector2 resolvedPosition)
        {
            resolvedPosition = candidatePosition;
            if (!navigationMap.TryBuildWorldPath(npcPosition, candidatePosition, out Vector2[] path) ||
                path == null ||
                path.Length == 0)
            {
                return false;
            }

            resolvedPosition = path[^1];
            return Vector2.Distance(npcPosition, resolvedPosition) >= requiredDistance;
        }

        private static void ObservePostHitChase(ValidationResult result)
        {
            CapturePostHitSample(result);
            if (Time.frameCount - s_phaseStartFrame <= MaximumFramesToObserveChase)
            {
                return;
            }

            bool chaseSucceeded =
                result.NpcDistanceMovedAfterPlayerMoved >= RequiredNpcMoveDistance ||
                result.FinalDistanceToPlayer <= RequiredFinalAttackDistance;
            FinalizeResult(chaseSucceeded
                ? string.Empty
                : "玩家被拉开后 NPC 没有明显追击，也没有回到攻击距离。");
        }

        private static void CapturePostHitSample(ValidationResult result)
        {
            if (s_player == null || s_npc == null || s_controller == null)
            {
                return;
            }

            Vector2 playerPosition = s_player.transform.position;
            Vector2 npcPosition = s_npc.transform.position;
            float distanceToPlayer = Vector2.Distance(npcPosition, playerPosition);
            Vector2 movementDirection = MovementDirectionField != null
                ? (Vector2)MovementDirectionField.GetValue(s_npc)
                : Vector2.zero;
            SteeringResult2D steeringResult = ResolveLatestSteeringResult();

            result.FinalPlayerAnimation = GetCurrentAnimationKey(s_playerCharacterActionAnimatorDriver);
            result.FinalNpcAnimation = GetCurrentAnimationKey(s_npcCharacterActionAnimatorDriver);
            result.FinalPlayerStillDmg = string.Equals(result.FinalPlayerAnimation, "Dmg", StringComparison.Ordinal);
            result.FinalNpcCanMove = s_npc.CanMove();
            result.FinalNpcHasActiveMovementIntent = s_npc.HasActiveMovementIntent();
            result.FinalNpcIsMoving = s_npc.IsMoving();
            result.HasTargetAfterPlayerMoved = TargetField?.GetValue(s_controller) != null;
            result.FinalMovementDirection = Format(movementDirection);
            result.FinalSafeDirection = Format(steeringResult.SafeDirection);
            result.FinalSafeVelocity = Format(steeringResult.SafeVelocity);
            result.FinalPreferredVelocity = Format(steeringResult.PreferredVelocity);
            result.FinalNpcPosition = Format(npcPosition);
            result.FinalPlayerPosition = Format(playerPosition);
            result.FinalDistanceToPlayer = distanceToPlayer;
            result.NpcDistanceMovedAfterPlayerMoved = Vector2.Distance(s_npcPositionWhenPlayerMoved, npcPosition);
            result.MinimumDistanceAfterPlayerMoved = Mathf.Min(result.MinimumDistanceAfterPlayerMoved, distanceToPlayer);
            result.MaximumDistanceAfterPlayerMoved = Mathf.Max(result.MaximumDistanceAfterPlayerMoved, distanceToPlayer);
            result.AnyNonZeroMovementDirectionAfterPlayerMoved |= movementDirection.sqrMagnitude > 0.0001f;
            result.AnyNonZeroSafeDirectionAfterPlayerMoved |= steeringResult.SafeDirection.sqrMagnitude > 0.0001f;

            if (TargetPositionField != null && BehaviourRuntimeProperty != null)
            {
                object runtime = BehaviourRuntimeProperty.GetValue(s_controller);
                if (runtime != null)
                {
                    result.FinalAiTargetPosition = Format((Vector2)TargetPositionField.GetValue(runtime));
                }
            }

            TerrainNavigationMap navigationMap = UnityEngine.Object.FindFirstObjectByType<TerrainNavigationMap>(
                FindObjectsInactive.Exclude);
            if (navigationMap != null)
            {
                bool pathSucceeded = navigationMap.TryBuildWorldPath(npcPosition, playerPosition, out Vector2[] path);
                result.FinalNavigationPathStatus = pathSucceeded
                    ? $"成功：{path.Length} 个路径点"
                    : "失败";
                result.AnyNavigationPathSuccessAfterPlayerMoved |= pathSucceeded;
                result.AnyNavigationPathFailureAfterPlayerMoved |= !pathSucceeded;
            }
            else
            {
                result.FinalNavigationPathStatus = "缺少 TerrainNavigationMap";
            }
        }

        private static SteeringResult2D ResolveLatestSteeringResult()
        {
            if (s_controller == null || BehaviourRuntimeProperty == null || SteeringAdapterField == null)
            {
                return default;
            }

            object runtime = BehaviourRuntimeProperty.GetValue(s_controller);
            object adapter = runtime != null ? SteeringAdapterField.GetValue(runtime) : null;
            PropertyInfo latestResultProperty = adapter?.GetType().GetProperty(
                "LatestResult",
                BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            return latestResultProperty != null
                ? (SteeringResult2D)latestResultProperty.GetValue(adapter)
                : default;
        }

        private static bool TryResolveParticipants(
            out CharacterBase? player,
            out CharacterBase? npc,
            out AIController? controller)
        {
            player = ResolvePlayer();
            npc = null;
            controller = null;
            if (player == null)
            {
                return false;
            }

            foreach (ContextSteeringDebugProbe2D probe in
                     UnityEngine.Object.FindObjectsByType<ContextSteeringDebugProbe2D>(
                         FindObjectsInactive.Exclude,
                         FindObjectsSortMode.InstanceID))
            {
                CharacterBase candidate = probe.GetComponent<CharacterBase>();
                if (candidate != null &&
                    candidate != player &&
                    candidate.TryGetController(out AIController candidateController))
                {
                    npc = candidate;
                    controller = candidateController;
                    return true;
                }
            }

            return false;
        }

        private static CharacterBase? ResolvePlayer()
        {
            if (GameManager.Exists() && GameManager.HasSystem<PlayerSystem>())
            {
                CharacterBase player = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
                if (player != null)
                {
                    return player;
                }
            }

            GameObject playerObject = GameObject.FindWithTag("Player");
            return playerObject != null ? playerObject.GetComponent<CharacterBase>() : null;
        }

        private static MonoBehaviour? ResolveCharacterActionAnimatorDriver(CharacterBase? character)
        {
            if (character == null)
            {
                return null;
            }

            foreach (MonoBehaviour component in character.GetComponentsInChildren<MonoBehaviour>(true))
            {
                if (component == null)
                {
                    continue;
                }

                Type type = component.GetType();
                if (type.Name == "CharacterActionAnimatorDriver" &&
                    type.GetMethod("TryPlayAnimation", BindingFlags.Instance | BindingFlags.Public) != null &&
                    type.GetProperty("CurrentAnimationKey", BindingFlags.Instance | BindingFlags.Public) != null)
                {
                    return component;
                }
            }

            return null;
        }

        private static bool InvokeTryPlayAnimation(MonoBehaviour? animationController, string animationKey)
        {
            MethodInfo method = animationController != null
                ? animationController.GetType().GetMethod("TryPlayAnimation", BindingFlags.Instance | BindingFlags.Public)
                : null;
            return method != null && (bool)method.Invoke(animationController, new object[] { animationKey });
        }

        private static string GetCurrentAnimationKey(MonoBehaviour? animationController)
        {
            PropertyInfo property = animationController != null
                ? animationController.GetType().GetProperty("CurrentAnimationKey", BindingFlags.Public | BindingFlags.Instance)
                : null;
            return property?.GetValue(animationController)?.ToString() ?? "null";
        }

        private static void PositionCharacter(CharacterBase character, Vector2 position)
        {
            character.ResetMovement();
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

        private static void FinalizeResult(string failure)
        {
            if (s_result == null)
            {
                Stop();
                return;
            }

            CapturePostHitSample(s_result);
            s_result.Completed = true;
            s_result.EndFrame = Time.frameCount;

            var failures = new System.Collections.Generic.List<string>();
            if (!string.IsNullOrWhiteSpace(failure))
            {
                failures.Add(failure);
            }

            Require(s_result.PlayerHitFrame > 0, "没有观察到玩家被 NPC 打出 Dmg 受击动作。", failures);
            Require(!s_result.FinalPlayerStillDmg, "玩家受击后仍卡在 Dmg 动作。", failures);
            Require(s_result.FinalNpcCanMove, "NPC 攻击后仍处于不可移动状态。", failures);
            Require(s_result.HasTargetAfterPlayerMoved, "NPC 攻击后丢失玩家目标。", failures);
            Require(
                s_result.NpcDistanceMovedAfterPlayerMoved >= RequiredNpcMoveDistance ||
                s_result.FinalDistanceToPlayer <= RequiredFinalAttackDistance,
                "NPC 攻击后没有继续追击玩家，也没有回到攻击距离。",
                failures);

            s_result.Success = failures.Count == 0;
            s_result.Failures = failures.ToArray();
            s_result.Message = s_result.Success
                ? "ClickMoveTest 攻击后追击验收通过：玩家受击动作恢复，NPC 攻击后继续追击或回到攻击距离。"
                : string.Join(" | ", failures);
            WriteResult(s_result);
            Stop();
        }

        private static ValidationResult Fail(string message)
        {
            return new ValidationResult
            {
                Completed = true,
                Success = false,
                Message = message,
                Failures = new[] { message },
                ScenePath = UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,
                StartFrame = Time.frameCount,
                EndFrame = Time.frameCount,
            };
        }

        private static void Require(bool condition, string failure, System.Collections.Generic.ICollection<string> failures)
        {
            if (!condition)
            {
                failures.Add(failure);
            }
        }

        private static void WriteResult(ValidationResult result)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(ResultPath));
            File.WriteAllText(ResultPath, JsonUtility.ToJson(result, true));
        }

        private static string Format(Vector2 value)
        {
            return $"{value.x:0.000},{value.y:0.000}";
        }

        private static string Format(Vector3 value)
        {
            return $"{value.x:0.000},{value.y:0.000},{value.z:0.000}";
        }

        private static void Stop()
        {
            EditorApplication.update -= Tick;
            s_result = null;
            s_player = null;
            s_npc = null;
            s_controller = null;
            s_playerCharacterActionAnimatorDriver = null;
            s_npcCharacterActionAnimatorDriver = null;
            s_phase = 0;
            s_phaseStartFrame = 0;
        }

        [Serializable]
        private sealed class ValidationResult
        {
            public bool Completed;
            public bool Success;
            public string Message = string.Empty;
            public string[] Failures = Array.Empty<string>();
            public string ScenePath = string.Empty;
            public int StartFrame;
            public int EndFrame;
            public int PlayerHitFrame;
            public int PlayerMovedFrame;
            public string PlayerName = string.Empty;
            public string NpcName = string.Empty;
            public string PlayerAnimationAtHit = string.Empty;
            public string FinalPlayerAnimation = string.Empty;
            public string FinalNpcAnimation = string.Empty;
            public bool FinalPlayerStillDmg;
            public bool FinalNpcCanMove;
            public bool FinalNpcHasActiveMovementIntent;
            public bool FinalNpcIsMoving;
            public bool HasTargetAfterPlayerMoved;
            public bool NpcTrySetCombatTargetResult;
            public bool OrbitEnabledField;
            public string OrbitGroupId = string.Empty;
            public bool ShouldUseOrbitResolved;
            public bool AnyNonZeroMovementDirectionAfterPlayerMoved;
            public bool AnyNonZeroSafeDirectionAfterPlayerMoved;
            public bool AnyNavigationPathSuccessAfterPlayerMoved;
            public bool AnyNavigationPathFailureAfterPlayerMoved;
            public float InitialDistanceAfterPlayerMoved;
            public float FinalDistanceToPlayer;
            public float MinimumDistanceAfterPlayerMoved;
            public float MaximumDistanceAfterPlayerMoved;
            public float NpcDistanceMovedAfterPlayerMoved;
            public string PlayerPositionAtStart = string.Empty;
            public string NpcPositionAtStart = string.Empty;
            public string PlayerMoveDesiredPosition = string.Empty;
            public string PlayerMoveResolutionStatus = string.Empty;
            public string PlayerPositionAfterMove = string.Empty;
            public string NpcPositionWhenPlayerMoved = string.Empty;
            public string FinalNpcPosition = string.Empty;
            public string FinalPlayerPosition = string.Empty;
            public string FinalMovementDirection = string.Empty;
            public string FinalSafeDirection = string.Empty;
            public string FinalSafeVelocity = string.Empty;
            public string FinalPreferredVelocity = string.Empty;
            public string FinalAiTargetPosition = string.Empty;
            public string FinalNavigationPathStatus = string.Empty;
        }
    }
}
