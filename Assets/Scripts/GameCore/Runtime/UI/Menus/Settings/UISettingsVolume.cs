using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 单行音量设置控件基类。
    /// 它只负责显示数值和提供默认焦点按钮，具体音量读写和按钮回调由上层设置面板或派生类负责。
    /// </summary>
    public class UISettingsVolume : MonoBehaviour
    {
        [Header("音量控件")]
        [SerializeField]
        [LabelText("数值文本")]
        [Tooltip("显示音量数值和后缀的 TMP 文本。")]
        protected TextMeshProUGUI m_value = null;

        [SerializeField]
        [LabelText("降低按钮")]
        [Tooltip("用于降低音量的按钮，也是默认焦点优先返回对象。")]
        protected Button m_decreaseButton;

        [SerializeField]
        [LabelText("提高按钮")]
        [Tooltip("用于提高音量的按钮。具体点击回调由派生类或设置面板注册。")]
        protected Button m_increaseButton;

        /// <summary>刷新显示文本。传入值已经由上层按音量比例换算，本控件只负责展示。</summary>
        public void UpdateUI(int volume, string suffix = "")
        {
            m_value.text = $"{volume}{suffix}";
        }

        /// <summary>只回答默认焦点对象，不把内部按钮数组或布局细节外借给外层菜单。</summary>
        public GameObject GetDefaultFocusTarget() => m_decreaseButton != null ? m_decreaseButton.gameObject : gameObject;
    }
}
