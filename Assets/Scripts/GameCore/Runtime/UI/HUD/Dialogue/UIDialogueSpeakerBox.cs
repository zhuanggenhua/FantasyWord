using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 对话说话人名称框。
    /// 没有说话人文本时自动隐藏，避免空名字框占位。
    /// </summary>
    public class UIDialogueSpeakerBox : MonoBehaviour
    {
        [SerializeField]
        [LabelText("说话人文本")]
        [Tooltip("显示当前对话节点说话人名称的 TMP 文本。")]
        private TextMeshProUGUI m_text = null;

        /// <summary>显示说话人框。</summary>
        public void Show() => SetVisible(true);

        /// <summary>隐藏说话人框。</summary>
        public void Hide() => SetVisible(false);

        /// <summary>设置说话人文本；空白文本会直接隐藏整个说话人框。</summary>
        public void SetText(string text)
        {
            SetVisible(!string.IsNullOrWhiteSpace(text));
            m_text.text = text;
        }

        /// <summary>切换说话人框显隐。</summary>
        private void SetVisible(bool visible)
        {
            gameObject.SetActive(visible);
        }
    }
}
