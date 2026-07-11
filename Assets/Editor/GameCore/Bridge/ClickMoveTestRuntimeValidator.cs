#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// ClickMoveTest 的 AIBridge 候选 PlayMode 验证入口。
    /// 这里只通过当前正式输入目标分发点击移动，不创建测试控制器，也不直接改角色坐标。
    /// </summary>
    public static class ClickMoveTestRuntimeValidator
    {
        private const int FramesToObserveAfterDispatch = 120;
        private const float RequiredMoveDistance = 0.1f;
        private const float RequiredCameraFollowAlignment = 0.9f;
        private const string ResultRelativePath = "Temp/UnityBridge/results/clickmove-e2e-runtime.json";

        private static ValidationResult? s_result;
        private static int s_dispatchFrame;
        private static bool s_running;

        public static string ResultPath => Path.GetFullPath(ResultRelativePath);

        public static string Start()
        {
            if (!Application.isPlaying)
            {
                WriteResult(Fail("ClickMoveTest 运行态验证只能在 PlayMode 下启动。"));
                return ResultPath;
            }

            s_result = new ValidationResult
            {
                ScenePath = UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,
                ScreenSize = $"{Screen.width}x{Screen.height}",
            };

            s_running = true;
            EditorApplication.update -= Tick;
            EditorApplication.update += Tick;
            return ResultPath;
        }

        private static void Tick()
        {
            if (!s_running || s_result == null)
            {
                StopTicking();
                return;
            }

            if (!Application.isPlaying)
            {
                WriteResult(Fail("验证过程中 PlayMode 已退出。"));
                StopTicking();
                return;
            }

            try
            {
                if (!s_result.Dispatched)
                {
                    DispatchClickMove(s_result);
                    s_dispatchFrame = Time.frameCount;
                    return;
                }

                if (Time.frameCount - s_dispatchFrame < FramesToObserveAfterDispatch)
                {
                    return;
                }

                CaptureAfterMovement(s_result);
                FinalizeResult(s_result);
                WriteResult(s_result);
            }
            catch (Exception exception)
            {
                WriteResult(Fail(exception.ToString()));
            }
            finally
            {
                if (s_result is { Completed: true })
                {
                    StopTicking();
                }
            }
        }

        private static void DispatchClickMove(ValidationResult result)
        {
            Camera? camera = GameManager.Exists() ? GameManager.MainCamera : null;
            result.CameraExists = camera != null;
            if (camera != null)
            {
                result.CameraBefore = Format(camera.transform.position);
                result.CameraBeforeVector = camera.transform.position;
                result.CameraOrthographicSize = camera.orthographicSize;
            }

            result.GameManagerExists = GameManager.Exists();
            result.HasPlayerSystem = result.GameManagerExists && GameManager.HasSystem<PlayerSystem>();
            result.HasInputSystem = result.GameManagerExists && GameManager.HasSystem<InputSystem>();

            CharacterBase? character = null;
            IPlayerInputTarget? inputTarget = null;
            if (result.HasPlayerSystem)
            {
                character = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
                GameManager.PlayerSystem.TryGetCurrentInputTarget(out inputTarget);
            }

            result.InputTargetType = inputTarget?.GetType().FullName ?? "null";
            result.CharacterName = character != null ? character.name : "null";
            result.CanMoveBefore = character != null && character.Can(EActionFlags.Move);
            result.HasMoveOrderBefore = character != null && character.HasMoveOrder();
            result.PlayerBefore = character != null ? Format(character.transform.position) : "null";
            result.PlayerBeforeVector = character != null ? character.transform.position : Vector3.zero;

            if (inputTarget is CharacterPlayerControl playerControl)
            {
                result.ControlModeBefore = playerControl.GetMovementControlMode().ToString();
                playerControl.SetMovementControlMode(EPlayerMovementControlMode.ClickToMove);
                result.ControlModeAfterSet = playerControl.GetMovementControlMode().ToString();
            }
            else
            {
                result.ControlModeBefore = "not-character-player-control";
                result.ControlModeAfterSet = "not-character-player-control";
            }

            Vector2 screenPosition = new(Screen.width * 0.75f, Screen.height * 0.5f);
            result.ScreenClick = Format(screenPosition);
            result.ClickWasOverUi = UIPointerUtility.IsPositionOverUI(screenPosition);

            Vector2? worldPosition = null;
            if (camera != null && character != null)
            {
                float distanceToSubjectPlane = character.transform.position.z - camera.transform.position.z;
                Vector3 world = camera.ScreenToWorldPoint(new Vector3(screenPosition.x, screenPosition.y, distanceToSubjectPlane));
                result.WorldClick = Format(world);
                worldPosition = world;
            }

            PlayerCommandRequest commandRequest = new(
                GameCommandContext.LocalPlayer(character),
                EPlayerCommandKind.ClickMove,
                worldPosition: worldPosition);
            PlayerCommandResult commandResult = result.HasPlayerSystem
                ? GameManager.PlayerSystem.SubmitPlayerCommand(commandRequest)
                : PlayerCommandResult.Failed(commandRequest, EPlayerCommandFailureReason.MissingInputTarget);
            result.CommandSucceeded = commandResult.Succeeded;
            result.CommandFailureReason = commandResult.FailureReason.ToString();

            result.Dispatched = true;
            result.HasMoveOrderAfterDispatch = character != null && character.HasMoveOrder();
            result.PlayerAfterDispatch = character != null ? Format(character.transform.position) : "null";
        }

        private static void CaptureAfterMovement(ValidationResult result)
        {
            CharacterBase? character = null;
            if (GameManager.Exists() && GameManager.HasSystem<PlayerSystem>())
            {
                character = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
            }

            Vector3 playerAfter = character != null ? character.transform.position : Vector3.zero;
            Vector2 playerDelta = playerAfter - result.PlayerBeforeVector;
            result.PlayerAfterObserve = character != null ? Format(playerAfter) : "null";
            result.PlayerDelta = Format(playerDelta);
            result.MovedDistance = Vector2.Distance(result.PlayerBeforeVector, playerAfter);
            result.HasMoveOrderAfterObserve = character != null && character.HasMoveOrder();

            Camera? camera = GameManager.Exists() ? GameManager.MainCamera : null;
            if (camera != null)
            {
                Vector2 cameraDelta = camera.transform.position - result.CameraBeforeVector;
                result.CameraAfter = Format(camera.transform.position);
                result.CameraDelta = Format(cameraDelta);
                result.CameraMovedDistance = cameraDelta.magnitude;
                if (playerDelta.sqrMagnitude > Mathf.Epsilon && cameraDelta.sqrMagnitude > Mathf.Epsilon)
                {
                    result.CameraFollowAlignment = Vector2.Dot(playerDelta.normalized, cameraDelta.normalized);
                }
            }

            List<string> references = new();
            foreach (GameObject gameObject in UnityEngine.Object.FindObjectsByType<GameObject>(FindObjectsSortMode.InstanceID))
            {
                if (gameObject.name.Contains("参照") || gameObject.name.Contains("原点") || gameObject.name.Contains("轴"))
                {
                    references.Add($"{gameObject.name}@{Format(gameObject.transform.position)}");
                }
            }

            result.ReferenceObjects = references.ToArray();
        }

        private static void FinalizeResult(ValidationResult result)
        {
            List<string> failures = new();
            Require(result.CameraExists, "场景没有 MainCamera。", failures);
            Require(result.GameManagerExists, "GameManager 未启动。", failures);
            Require(result.HasPlayerSystem, "PlayerSystem 未注册。", failures);
            Require(result.HasInputSystem, "InputSystem 未注册。", failures);
            Require(result.InputTargetType.Contains(nameof(CharacterPlayerControl)), "当前输入目标不是 CharacterPlayerControl。", failures);
            Require(result.CanMoveBefore, "玩家点击前不可移动。", failures);
            Require(!result.ClickWasOverUi, "验证点击位置被 UI 吃掉。", failures);
            Require(result.CommandSucceeded, $"点击移动命令失败：{result.CommandFailureReason}。", failures);
            Require(result.HasMoveOrderAfterDispatch, "点击移动入口没有生成移动指令。", failures);
            Require(result.MovedDistance >= RequiredMoveDistance, $"玩家移动距离不足 {RequiredMoveDistance:0.###}。", failures);
            Require(result.CameraMovedDistance >= RequiredMoveDistance, "相机没有跟随玩家移动。", failures);
            Require(
                result.CameraFollowAlignment >= RequiredCameraFollowAlignment,
                $"相机移动方向没有跟随玩家，方向一致度低于 {RequiredCameraFollowAlignment:0.##}。",
                failures);
            Require(result.ReferenceObjects.Length > 0, "场景缺少移动参照物。", failures);

            result.Success = failures.Count == 0;
            result.Failures = failures.ToArray();
            result.Message = result.Success
                ? "ClickMoveTest 候选点击移动验证通过。"
                : string.Join(" | ", failures);
            result.Completed = true;
        }

        private static ValidationResult Fail(string message)
        {
            return new ValidationResult
            {
                Completed = true,
                Success = false,
                Message = message,
                Failures = new[] { message }
            };
        }

        private static void WriteResult(ValidationResult result)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(ResultPath)!);
            File.WriteAllText(ResultPath, JsonUtility.ToJson(result, true));
        }

        private static void StopTicking()
        {
            s_running = false;
            EditorApplication.update -= Tick;
        }

        private static void Require(bool condition, string failure, List<string> failures)
        {
            if (!condition)
            {
                failures.Add(failure);
            }
        }

        private static string Format(Vector2 value) => $"({value.x:0.###}, {value.y:0.###})";
        private static string Format(Vector3 value) => $"({value.x:0.###}, {value.y:0.###}, {value.z:0.###})";

        [Serializable]
        public sealed class ValidationResult
        {
            public bool Completed;
            public bool Success;
            public string Message = string.Empty;
            public string ScenePath = string.Empty;
            public string ScreenSize = string.Empty;
            public bool Dispatched;
            public bool CameraExists;
            public string CameraBefore = string.Empty;
            public string CameraAfter = string.Empty;
            public string CameraDelta = string.Empty;
            public float CameraMovedDistance;
            public float CameraFollowAlignment;
            public float CameraOrthographicSize;
            public bool GameManagerExists;
            public bool HasPlayerSystem;
            public bool HasInputSystem;
            public string InputTargetType = string.Empty;
            public string CharacterName = string.Empty;
            public bool CanMoveBefore;
            public bool HasMoveOrderBefore;
            public bool HasMoveOrderAfterDispatch;
            public bool HasMoveOrderAfterObserve;
            public bool CommandSucceeded;
            public string CommandFailureReason = string.Empty;
            public string ControlModeBefore = string.Empty;
            public string ControlModeAfterSet = string.Empty;
            public string ScreenClick = string.Empty;
            public string WorldClick = string.Empty;
            public bool ClickWasOverUi;
            public string PlayerBefore = string.Empty;
            public string PlayerAfterDispatch = string.Empty;
            public string PlayerAfterObserve = string.Empty;
            public string PlayerDelta = string.Empty;
            public float MovedDistance;
            public string[] ReferenceObjects = Array.Empty<string>();
            public string[] Failures = Array.Empty<string>();

            [NonSerialized] public Vector3 PlayerBeforeVector;
            [NonSerialized] public Vector3 CameraBeforeVector;
        }
    }
}
