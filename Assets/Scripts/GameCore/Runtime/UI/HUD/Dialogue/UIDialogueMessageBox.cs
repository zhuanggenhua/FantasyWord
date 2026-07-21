using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 对话消息框，负责正文跳字、说话人显示、继续箭头和可选动画参数。
    /// 它只处理 HUD 表现，不直接推进 DialogueSystem 分支。
    /// </summary>
    public class UIDialogueMessageBox : MonoBehaviour
    {
        #region Inspector 配置

        [Header("消息框表现")]
        [SerializeField]
        [LabelText("显隐动画参数")]
        [Tooltip("Animator 中用于控制消息框显隐的 bool 参数名。")]
        private string m_animationParameter = "visible";

        [SerializeField]
        [LabelText("对话跳字音效")]
        [Tooltip("每个非空白字符出现时请求播放的音效。")]
        private AudioClipResolver m_dialogueBlipAudio;

        [SerializeField]
        [LabelText("正文文本")]
        [Tooltip("显示对话正文的 TMP 文本。")]
        private TextMeshProUGUI m_text = null;

        [SerializeField]
        [LabelText("说话人框")]
        [Tooltip("显示当前说话人名称的子组件。")]
        private UIDialogueSpeakerBox m_speakerBox = null;

        [SerializeField]
        [LabelText("继续箭头")]
        [Tooltip("单选项节点文本播放完成后显示的继续提示。")]
        private GameObject m_arrow = null;

        #endregion

        private Queue<char> m_charQueue = null;
        private bool m_hasAnimationParameter = false;
        private bool m_visible = false;
        private bool m_textAnimationInProgress = false;
        private bool m_showArrow = false;
        private Animator m_animator = null;
        private IDialogueHudEventReceiver m_receiver = null;
        private Coroutine m_textAnimationCoroutine = null;

        #region 生命周期

        /// <summary>缓存 Animator 和父级回调接收者，并确认显隐动画参数是否存在。</summary>
        private void Awake()
        {
            m_animator = GetComponent<Animator>();
            m_receiver = GetComponentInParent<IDialogueHudEventReceiver>();
            Debug.Assert(m_receiver != null, $"{nameof(UIDialogueMessageBox)} 需要父级实现 {nameof(IDialogueHudEventReceiver)}。");

            if (m_animator)
            {
                m_hasAnimationParameter = AnimationUtils.HasParameter(m_animator, m_animationParameter);
            }
        }

        /// <summary>禁用时终止当前跳字协程，避免后台继续写文本。</summary>
        private void OnDisable()
        {
            AbortTextAnimation();
        }

        /// <summary>销毁时终止跳字协程并清理状态。</summary>
        private void OnDestroy()
        {
            AbortTextAnimation();
        }

        #endregion

        #region 显隐与文本入口

        /// <summary>显示消息框。</summary>
        public void Show() => SetVisible(true);

        /// <summary>隐藏消息框，并终止当前跳字流程。</summary>
        public void Hide()
        {
            AbortTextAnimation();
            SetVisible(false);
        }

        /// <summary>设置说话人和正文，并从头启动跳字动画。</summary>
        public void SetText(string speaker, string text, bool showArrow)
        {
            AbortTextAnimation();
            m_speakerBox.SetText(speaker);
            m_showArrow = showArrow;
            m_text.text = string.Empty;
            m_charQueue = new Queue<char>(text ?? string.Empty);
            m_textAnimationCoroutine = StartCoroutine(UpdateText());
        }

        /// <summary>调整正文文本边距，供布局或外部适配使用。</summary>
        public void SetMargin(Vector4 margins)
        {
            m_text.margin = margins;
        }

        /// <summary>切换消息框显隐；Animator 缺少参数时只更新内部状态，不写 Animator。</summary>
        private void SetVisible(bool visible)
        {
            if (visible != m_visible)
            {
                m_visible = visible;

                if (m_animator && m_hasAnimationParameter)
                {
                    m_animator.SetBool(m_animationParameter, visible);
                }
            }
        }

        #endregion

        #region 跳字动画

        /// <summary>逐字显示正文，并在非空白字符出现时请求播放跳字音效。</summary>
        private IEnumerator UpdateText()
        {
            OnTextAnimationStart();

            while (m_charQueue != null && m_charQueue.Count > 0)
            {
                char c = m_charQueue.Dequeue();

                m_text.text += c;

                if (!char.IsWhiteSpace(c))
                {
                    GameRuntimeEvents.RequestAudioPlayback(m_dialogueBlipAudio);
                }

                yield return new WaitForSecondsRealtime(0.05f);
            }

            m_textAnimationCoroutine = null;
            CompleteTextAnimation();
        }

        /// <summary>跳字开始时隐藏继续箭头。</summary>
        private void OnTextAnimationStart()
        {
            m_textAnimationInProgress = true;
            m_arrow.SetActive(false);
        }

        /// <summary>跳字完成后按节点类型显示继续箭头，并通知父级刷新选项框。</summary>
        private void CompleteTextAnimation()
        {
            if (m_showArrow)
            {
                m_arrow.SetActive(true);
            }
            else
            {
                m_arrow.SetActive(false);
            }

            m_textAnimationInProgress = false;
            m_charQueue = null;
            m_receiver?.HandleMessageBoxTextAnimationFinished();
        }

        /// <summary>玩家跳过文本时立即补齐剩余字符，并走统一完成流程。</summary>
        public void SkipTextAnimation()
        {
            if (!m_textAnimationInProgress)
            {
                return;
            }

            StopTextAnimationCoroutine();

            if (m_charQueue != null && m_charQueue.Count > 0)
            {
                m_text.text += new string(m_charQueue.ToArray());
            }

            CompleteTextAnimation();
        }

        /// <summary>返回当前跳字动画是否已经完成。</summary>
        public bool IsTextAnimationFinished()
        {
            return !m_textAnimationInProgress;
        }

        /// <summary>停止当前跳字协程，并清空协程句柄。</summary>
        private void StopTextAnimationCoroutine()
        {
            if (m_textAnimationCoroutine == null)
            {
                return;
            }

            StopCoroutine(m_textAnimationCoroutine);
            m_textAnimationCoroutine = null;
        }

        /// <summary>对话关闭或切换到下一句时直接终止当前跳字，避免旧协程在后台继续驱动 UI 状态。</summary>
        private void AbortTextAnimation()
        {
            StopTextAnimationCoroutine();
            m_textAnimationInProgress = false;
            m_charQueue = null;
            m_arrow.SetActive(false);
        }

        #endregion
    }
}
