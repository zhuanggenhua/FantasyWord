using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 单个对话选项按钮。
    /// 它只保存选项序号和显示文本，点击后通过父级回调合同交给 UIDialogue 推进。
    /// </summary>
    public class UIDialogueOption : MonoBehaviour
    {
        [SerializeField]
        [LabelText("选项文本")]
        [Tooltip("显示选项名称的 TMP 文本。")]
        private TextMeshProUGUI m_text = null;

        [SerializeField]
        [LabelText("选项序号")]
        [Tooltip("传给 DialogueSystem.Next 的选项索引。")]
        private int m_optionID = 0;

        private Button m_button = null;
        private IDialogueHudEventReceiver m_receiver = null;

        /// <summary>缓存按钮和父级回调接收者，并注册点击事件。</summary>
        private void Awake()
        {
            m_button = GetComponent<Button>();
            m_receiver = GetComponentInParent<IDialogueHudEventReceiver>();
            Debug.Assert(m_receiver != null, $"{nameof(UIDialogueOption)} 需要父级实现 {nameof(IDialogueHudEventReceiver)}。");
            m_button.onClick.AddListener(OnClicked);
        }

        /// <summary>销毁时注销按钮点击事件，避免按钮复用时残留旧监听。</summary>
        private void OnDestroy()
        {
            if (m_button)
            {
                m_button.onClick.RemoveListener(OnClicked);
            }
        }

        /// <summary>按钮点击后通知父级选择了哪个选项序号。</summary>
        private void OnClicked()
        {
            m_receiver?.HandleDialogueOptionClicked(m_optionID);
        }

        /// <summary>切换选项按钮显隐。</summary>
        public void SetVisible(bool visible)
        {
            gameObject.SetActive(visible);
        }

        /// <summary>刷新选项显示文本。</summary>
        public void SetText(string text)
        {
            m_text.text = text;
        }
    }
}
