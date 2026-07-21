using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// HUD 对话主控。
    /// 它监听 DialogueSystem 状态，把当前节点写入消息框和选项框，并在对话期间临时加上 Dialogue 游戏状态层。
    /// </summary>
    public class UIDialogue : MonoBehaviour, IDialogueHudEventReceiver
    {
        #region Inspector 配置

        [SerializeField]
        [LabelText("交互遮挡层")]
        [Tooltip("对话打开时启用，用来拦截对话外的 UI 或场景交互。")]
        private Graphic m_interactionBlocker = null;

        [SerializeField]
        [LabelText("消息框")]
        [Tooltip("显示说话人、正文和跳字动画的消息框。")]
        private UIDialogueMessageBox m_messageBox = null;

        [SerializeField]
        [LabelText("选项框")]
        [Tooltip("显示多选项分支的选项框。")]
        private UIDialogueChoiceBox m_choiceBox = null;

        #endregion

        private DialogueNode m_currentNode = null;
        private readonly InputActionReleaseGate m_skipInputReleaseGate = new();
        private bool m_dialogueRuntimeListening = false;
        private bool m_dialogueLayerApplied = false;

        #region 生命周期

        /// <summary>启用时尝试接入 DialogueSystem、InputSystem 和 GameStateSystem。</summary>
        private void OnEnable()
        {
            StartDialogueRuntimeIfReady();
        }

        /// <summary>补一次运行时接入，覆盖 HUD 早于系统初始化的场景。</summary>
        private void Start()
        {
            StartDialogueRuntimeIfReady();
        }

        /// <summary>禁用时注销运行时监听并关闭当前对话 UI。</summary>
        private void OnDisable()
        {
            StopDialogueRuntime();
            CloseDialogue();
        }

        /// <summary>销毁时重复清理，避免残留输入监听或 Dialogue 状态层。</summary>
        private void OnDestroy()
        {
            StopDialogueRuntime();
            CloseDialogue();
        }

        #endregion

        #region 对话状态同步

        /// <summary>关闭对话 UI，并移除本控件曾经添加的 Dialogue 状态层。</summary>
        private void CloseDialogue()
        {
            m_currentNode = null;
            m_interactionBlocker.gameObject.SetActive(false);
            m_messageBox.Hide();
            m_choiceBox.Hide();
            RemoveDialogueLayerIfApplied();
        }

        /// <summary>对话开始时打开遮挡层、消息框和输入释放门，避免同一次按键立刻跳过文本。</summary>
        private void OnDialogueStarted(DialogueTree dialogue)
        {
            GameManager.InputSystem.PrepareUIReleaseGate(
                m_skipInputReleaseGate,
                EUIInputAction.Submit,
                EUIInputAction.Cancel,
                EUIInputAction.Click);
            m_interactionBlocker.gameObject.SetActive(true);
            m_messageBox.Show();
            AddDialogueLayerIfNeeded();
        }

        /// <summary>对话结束时关闭 UI。</summary>
        private void OnDialogueEnded(DialogueTree dialogue) => CloseDialogue();

        /// <summary>当前对话节点变化后刷新正文，并在跳字结束前先隐藏多选框。</summary>
        private void OnDialogueNodeChanged(DialogueNode node)
        {
            m_currentNode = node;

            if (node != null)
            {
                m_messageBox.SetText(node.speaker, node.text, node.optionCount == 1);

                if (m_currentNode.optionCount < 2)
                {
                    m_choiceBox.Hide();
                }
            }
            else
            {
                m_choiceBox.Hide();
            }
        }

        /// <summary>消息框跳字完成后刷新选项框。</summary>
        public void HandleMessageBoxTextAnimationFinished()
        {
            UpdateChoiceBox();
        }

        /// <summary>只有多选项节点才显示选项框；单选项节点继续由跳过输入推进。</summary>
        private void UpdateChoiceBox()
        {
            if (m_currentNode != null && m_currentNode.optionCount > 1)
            {
                m_choiceBox.Show(m_currentNode.GetOptions());
            }
        }

        #endregion

        #region 输入处理

        /// <summary>记录跳过相关输入已经松开，解除释放门拦截。</summary>
        private void OnSkipInputReleased(InputAction.CallbackContext context)
        {
            m_skipInputReleaseGate.NotifyReleased(context.action);
        }

        /// <summary>处理提交、取消或点击跳过：先补全文本，再推进对话节点。</summary>
        public void OnSkip(InputAction.CallbackContext context)
        {
            if (!GameManager.DialogueSystem.IsPlaying() || m_skipInputReleaseGate.IsBlocked(context.action))
            {
                return;
            }

            if (!m_messageBox.IsTextAnimationFinished())
            {
                m_messageBox.SkipTextAnimation();
                m_skipInputReleaseGate.ArmIfPressed(context.action);
            }
            else if (GameManager.DialogueSystem.TrySkipping())
            {
                m_skipInputReleaseGate.ArmIfPressed(context.action);
            }
        }

        /// <summary>选项按钮点击后把分支序号交给 DialogueSystem 推进。</summary>
        public void HandleDialogueOptionClicked(int option)
        {
            GameManager.DialogueSystem.Next(option);
        }

        #endregion

        #region 运行时接入

        /// <summary>系统准备好后注册对话和 UI 输入监听，并同步当前正在播放的对话。</summary>
        private void StartDialogueRuntimeIfReady()
        {
            if (m_dialogueRuntimeListening)
            {
                return;
            }

            if (!GameManager.Exists() ||
                !GameManager.HasSystem<DialogueSystem>() ||
                !GameManager.HasSystem<InputSystem>() ||
                !GameManager.HasSystem<GameStateSystem>())
            {
                return;
            }

            m_dialogueRuntimeListening = true;
            GameManager.DialogueSystem.AddStartedListener(OnDialogueStarted);
            GameManager.DialogueSystem.AddEndedListener(OnDialogueEnded);
            GameManager.DialogueSystem.AddNodeChangedListener(OnDialogueNodeChanged);

            GameManager.InputSystem.AddUIActionListener(EUIInputAction.Submit, EInputActionPhase.Started, OnSkip);
            GameManager.InputSystem.AddUIActionListener(EUIInputAction.Submit, EInputActionPhase.Canceled, OnSkipInputReleased);
            GameManager.InputSystem.AddUIActionListener(EUIInputAction.Cancel, EInputActionPhase.Started, OnSkip);
            GameManager.InputSystem.AddUIActionListener(EUIInputAction.Cancel, EInputActionPhase.Canceled, OnSkipInputReleased);
            GameManager.InputSystem.AddUIActionListener(EUIInputAction.Click, EInputActionPhase.Started, OnSkip);
            GameManager.InputSystem.AddUIActionListener(EUIInputAction.Click, EInputActionPhase.Canceled, OnSkipInputReleased);

            m_choiceBox.Hide();
            SyncCurrentDialogueIfPlaying();
        }

        /// <summary>注销所有对话和 UI 输入监听；系统已释放时跳过对应注销入口。</summary>
        private void StopDialogueRuntime()
        {
            if (!m_dialogueRuntimeListening)
            {
                return;
            }

            m_dialogueRuntimeListening = false;
            m_skipInputReleaseGate.Clear();

            if (GameManager.Exists() && GameManager.HasSystem<DialogueSystem>())
            {
                GameManager.DialogueSystem.RemoveStartedListener(OnDialogueStarted);
                GameManager.DialogueSystem.RemoveEndedListener(OnDialogueEnded);
                GameManager.DialogueSystem.RemoveNodeChangedListener(OnDialogueNodeChanged);
            }

            if (GameManager.Exists() && GameManager.HasSystem<InputSystem>())
            {
                GameManager.InputSystem.RemoveUIActionListener(EUIInputAction.Submit, EInputActionPhase.Started, OnSkip);
                GameManager.InputSystem.RemoveUIActionListener(EUIInputAction.Submit, EInputActionPhase.Canceled, OnSkipInputReleased);
                GameManager.InputSystem.RemoveUIActionListener(EUIInputAction.Cancel, EInputActionPhase.Started, OnSkip);
                GameManager.InputSystem.RemoveUIActionListener(EUIInputAction.Cancel, EInputActionPhase.Canceled, OnSkipInputReleased);
                GameManager.InputSystem.RemoveUIActionListener(EUIInputAction.Click, EInputActionPhase.Started, OnSkip);
                GameManager.InputSystem.RemoveUIActionListener(EUIInputAction.Click, EInputActionPhase.Canceled, OnSkipInputReleased);
            }
        }

        /// <summary>HUD 启用时若对话已经在播放，主动同步当前树和节点。</summary>
        private void SyncCurrentDialogueIfPlaying()
        {
            if (!GameManager.DialogueSystem.TryGetCurrentState(out DialogueTree dialogue, out DialogueNode node))
            {
                CloseDialogue();
                return;
            }

            OnDialogueStarted(dialogue);
            OnDialogueNodeChanged(node);
        }

        #endregion

        #region 游戏状态层

        /// <summary>对话打开时添加 Dialogue 状态层；如果外部已经处于 Dialogue 状态则只记录已应用。</summary>
        private void AddDialogueLayerIfNeeded()
        {
            if (m_dialogueLayerApplied)
            {
                return;
            }

            if (!GameManager.Exists() || !GameManager.HasSystem<GameStateSystem>())
            {
                return;
            }

            if (GameManager.GameStateSystem.currentState != EGameState.Dialogue)
            {
                GameManager.GameStateSystem.AddLayer(EGameState.Dialogue);
            }

            m_dialogueLayerApplied = true;
        }

        /// <summary>只移除本控件添加过且当前仍位于栈顶的 Dialogue 状态层。</summary>
        private void RemoveDialogueLayerIfApplied()
        {
            if (!m_dialogueLayerApplied)
            {
                return;
            }

            m_dialogueLayerApplied = false;
            if (GameManager.Exists() &&
                GameManager.HasSystem<GameStateSystem>() &&
                GameManager.GameStateSystem.currentState == EGameState.Dialogue)
            {
                GameManager.GameStateSystem.RemoveLayer(EGameState.Dialogue);
            }
        }

        #endregion
    }
}
