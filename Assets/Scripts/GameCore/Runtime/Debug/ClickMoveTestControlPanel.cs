using TMPro;
using UnityEngine;
using UnityEngine.InputSystem;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// ClickMoveTest 场景静态测试面板的运行时状态刷新器。
    /// 面板本体必须直接存在于场景 UI 中，本脚本只更新当前移动状态。
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class ClickMoveTestControlPanel : MonoBehaviour
    {
        [Header("Startup")]
        [SerializeField] private bool m_forceClickToMoveOnStart = true;

        [Header("Scene UI")]
        [SerializeField] private TextMeshProUGUI m_titleText;
        [SerializeField] private TextMeshProUGUI m_bodyText;
        [SerializeField, Min(1f)] private float m_titleFontSize = 48f;
        [SerializeField, Min(1f)] private float m_bodyFontSize = 36f;
        [SerializeField, Min(0f)] private float m_bodyLineSpacing = 6f;

        private CharacterPlayerControl m_playerControl;
        private bool m_appliedDefaultMode;
        private bool m_registeredControlledCharacterListener;
        private bool m_registeredGameplayClickListener;
        private int m_pendingClickInspectionFrames = -1;
        private int m_lastClickFrame = -1;
        private Vector2 m_lastClickScreenPosition = Vector2.zero;
        private Vector2 m_lastClickResolvedWorldPosition = Vector2.zero;
        private bool m_lastClickWasOverUi;
        private bool m_lastClickHadInputTarget;
        private bool m_lastClickCouldMove;
        private bool m_lastClickMoveOrderAfterDispatch;
        private Vector2 m_lastClickPlayerPositionAfterDispatch = Vector2.zero;
        private string m_lastClickMovementMode = "未知";

        private void OnEnable()
        {
            TryRegisterControlledCharacterListener();
            TryRegisterGameplayClickListener();
            TryResolveCurrentPlayerControl();
        }

        private void Start()
        {
            TryResolveCurrentPlayerControl();
            TryApplyDefaultMode();
            RefreshPanelText();
        }

        private void OnDisable()
        {
            UnregisterGameplayClickListener();
            UnregisterControlledCharacterListener();
        }

        private void Update()
        {
            TryRegisterControlledCharacterListener();
            TryRegisterGameplayClickListener();
            TryResolveCurrentPlayerControl();
            TryApplyDefaultMode();
            UpdatePendingClickInspection();
            RefreshPanelText();
        }

        private void OnCurrentControlledCharacterChanged(CharacterBase character)
        {
            m_playerControl = character != null
                ? character.GetComponent<CharacterPlayerControl>()
                : null;

            RefreshPanelText();
        }

        private void TryApplyDefaultMode()
        {
            if (m_appliedDefaultMode || !m_forceClickToMoveOnStart || m_playerControl == null)
            {
                return;
            }

            m_playerControl.SetMovementControlMode(EPlayerMovementControlMode.ClickToMove);
            m_appliedDefaultMode = true;
        }

        private string BuildBodyText()
        {
            string currentMode = m_playerControl == null
                ? "未接到玩家控制组件"
                : GetMovementModeLabel(m_playerControl.GetMovementControlMode());

            string modeHint = m_playerControl != null && m_playerControl.GetMovementControlMode() == EPlayerMovementControlMode.Directional
                ? "当前是方向移动模式，左键点地不会驱动角色移动。"
                : "当前是点击移动模式，左键点地会让玩家前往目标点。";
            string clickState = BuildLastClickSummary();
            string runtimeState = BuildRuntimeSummary();

            return
                $"当前移动模式：{currentMode}\n" +
                $"{runtimeState}\n" +
                "左键点地：点击移动\n" +
                "Tab：切换 点击移动 / WASD\n" +
                "WASD / 方向键：方向移动对照\n" +
                "镜头判断：如果角色总在屏幕中间，就看场景里的空白参照块是否相对屏幕滑动。\n" +
                $"{modeHint}\n" +
                $"{clickState}";
        }

        private static string GetMovementModeLabel(EPlayerMovementControlMode mode)
        {
            return mode == EPlayerMovementControlMode.ClickToMove ? "点击移动" : "方向移动";
        }

        private void TryRegisterControlledCharacterListener()
        {
            if (m_registeredControlledCharacterListener || !GameManager.Exists() || !GameManager.HasSystem<PlayerSystem>())
            {
                return;
            }

            GameManager.PlayerSystem.AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            m_registeredControlledCharacterListener = true;
        }

        private void TryRegisterGameplayClickListener()
        {
            if (m_registeredGameplayClickListener || !GameManager.Exists() || !GameManager.HasSystem<InputSystem>())
            {
                return;
            }

            GameManager.InputSystem.AddGameplayActionListener(EGameplayInputAction.Click, EInputActionPhase.Performed, OnGameplayClickPerformed);
            m_registeredGameplayClickListener = true;
        }

        private void UnregisterGameplayClickListener()
        {
            if (!m_registeredGameplayClickListener || !GameManager.Exists() || !GameManager.HasSystem<InputSystem>())
            {
                m_registeredGameplayClickListener = false;
                return;
            }

            GameManager.InputSystem.RemoveGameplayActionListener(EGameplayInputAction.Click, EInputActionPhase.Performed, OnGameplayClickPerformed);
            m_registeredGameplayClickListener = false;
        }

        private void UnregisterControlledCharacterListener()
        {
            if (!m_registeredControlledCharacterListener || !GameManager.Exists() || !GameManager.HasSystem<PlayerSystem>())
            {
                m_registeredControlledCharacterListener = false;
                return;
            }

            GameManager.PlayerSystem.RemoveCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            m_registeredControlledCharacterListener = false;
        }

        private void TryResolveCurrentPlayerControl()
        {
            if (!GameManager.Exists() || !GameManager.HasSystem<PlayerSystem>())
            {
                return;
            }

            CharacterBase currentCharacter = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
            if (currentCharacter != null && currentCharacter.TryGetComponent(out CharacterPlayerControl playerControl))
            {
                m_playerControl = playerControl;
            }
        }

        private void OnGameplayClickPerformed(InputAction.CallbackContext _)
        {
            m_lastClickFrame = Time.frameCount;
            m_lastClickScreenPosition = GameManager.InputSystem.ReadPointerScreenPosition(EActionMap.Gameplay);
            m_lastClickWasOverUi = UIPointerUtility.IsPositionOverUI(m_lastClickScreenPosition);
            m_lastClickHadInputTarget = GameManager.PlayerSystem.TryGetCurrentInputTarget(out IPlayerInputTarget _);
            m_lastClickCouldMove = TryGetControlledCharacter(out CharacterBase character) && character.Can(EActionFlags.Move);
            m_lastClickMovementMode = m_playerControl == null ? "未接到玩家控制组件" : GetMovementModeLabel(m_playerControl.GetMovementControlMode());
            m_lastClickResolvedWorldPosition = ResolvePointerWorldPosition(m_lastClickScreenPosition);
            m_pendingClickInspectionFrames = 1;
        }

        private void UpdatePendingClickInspection()
        {
            if (m_pendingClickInspectionFrames < 0)
            {
                return;
            }

            if (m_pendingClickInspectionFrames > 0)
            {
                m_pendingClickInspectionFrames--;
                return;
            }

            if (TryGetControlledCharacter(out CharacterBase character))
            {
                m_lastClickMoveOrderAfterDispatch = character.HasMoveOrder();
                m_lastClickPlayerPositionAfterDispatch = character.transform.position;
            }
            else
            {
                m_lastClickMoveOrderAfterDispatch = false;
                m_lastClickPlayerPositionAfterDispatch = Vector2.zero;
            }

            m_pendingClickInspectionFrames = -1;
        }

        private Vector2 ResolvePointerWorldPosition(Vector2 screenPosition)
        {
            Camera camera = GameManager.MainCamera;
            if (camera == null || !TryGetControlledCharacter(out CharacterBase character))
            {
                return Vector2.zero;
            }

            float distanceToSubjectPlane = character.transform.position.z - camera.transform.position.z;
            return camera.ScreenToWorldPoint(new Vector3(screenPosition.x, screenPosition.y, distanceToSubjectPlane));
        }

        private string BuildRuntimeSummary()
        {
            if (!TryGetControlledCharacter(out CharacterBase character))
            {
                return "运行时状态：当前没有接到玩家控制组件";
            }

            string inputTarget = GameManager.Exists() && GameManager.HasSystem<PlayerSystem>() && GameManager.PlayerSystem.TryGetCurrentInputTarget(out IPlayerInputTarget target)
                ? target.GetType().Name
                : "无";

            return
                $"运行时状态：输入目标={inputTarget}，可移动={(character.Can(EActionFlags.Move) ? "是" : "否")}，" +
                $"当前有移动指令={(character.HasMoveOrder() ? "是" : "否")}，当前位置=({character.transform.position.x:F2}, {character.transform.position.y:F2})";
        }

        private bool TryGetControlledCharacter(out CharacterBase character)
        {
            character = null;
            return m_playerControl != null && m_playerControl.TryGetControlledCharacter(out character);
        }

        private string BuildLastClickSummary()
        {
            if (m_lastClickFrame < 0)
            {
                return "最近一次点击：还没有收到 Gameplay 点击输入";
            }

            return
                $"最近一次点击：frame={m_lastClickFrame}，屏幕=({m_lastClickScreenPosition.x:F0}, {m_lastClickScreenPosition.y:F0})，" +
                $"世界=({m_lastClickResolvedWorldPosition.x:F2}, {m_lastClickResolvedWorldPosition.y:F2})\n" +
                $"点击诊断：命中UI={(m_lastClickWasOverUi ? "是" : "否")}，有输入目标={(m_lastClickHadInputTarget ? "是" : "否")}，" +
                $"点击时模式={m_lastClickMovementMode}，点击时可移动={(m_lastClickCouldMove ? "是" : "否")}，" +
                $"点击后生成移动指令={(m_lastClickMoveOrderAfterDispatch ? "是" : "否")}，" +
                $"点击后角色位置=({m_lastClickPlayerPositionAfterDispatch.x:F2}, {m_lastClickPlayerPositionAfterDispatch.y:F2})";
        }

        private void RefreshPanelText()
        {
            if (m_titleText == null || m_bodyText == null)
            {
                return;
            }

            m_titleText.text = "ClickMoveTest 当前测试提示";
            m_titleText.fontSize = m_titleFontSize;
            m_titleText.fontStyle = FontStyles.Bold;
            m_titleText.textWrappingMode = TextWrappingModes.NoWrap;
            m_bodyText.text = BuildBodyText();
            m_bodyText.fontSize = m_bodyFontSize;
            m_bodyText.lineSpacing = m_bodyLineSpacing;
        }
    }
}
