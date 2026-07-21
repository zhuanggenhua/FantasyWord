using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 对话选项框，负责把当前节点的多个选项写入固定按钮槽位。
    /// 它不决定分支逻辑，只把按钮焦点交给第一条可选项。
    /// </summary>
    public class UIDialogueChoiceBox : MonoBehaviour
    {
        [SerializeField]
        [LabelText("选项按钮")]
        [Tooltip("按显示顺序排列的固定选项按钮；多余按钮会在选项不足时隐藏。")]
        private UIDialogueOption[] m_options = null;

        /// <summary>切换整个选项框显隐。</summary>
        private void SetVisible(bool visible)
        {
            gameObject.SetActive(visible);
        }

        /// <summary>把选项文本写入固定按钮槽位，超出当前选项数量的按钮会隐藏。</summary>
        public void SetOptions(string[] options)
        {
            for (int i = 0; i < m_options.Length; ++i)
            {
                UIDialogueOption option = m_options[i];

                if (i < options.Length)
                {
                    option.SetText(options[i]);
                    option.SetVisible(true);
                }
                else
                {
                    option.SetVisible(false);
                }
            }
        }

        /// <summary>从对话节点选项中提取显示名称。</summary>
        public string[] GetOptionNames(DialogueNodeOption[] options)
        {
            string[] output = new string[options.Length];

            for (int i = 0; i < options.Length; ++i)
            {
                output[i] = options[i].name;
            }

            return output;
        }

        /// <summary>显示选项框并把默认焦点放到第一条选项。</summary>
        public void Show(DialogueNodeOption[] options)
        {
            SetVisible(true);
            SetOptions(GetOptionNames(options));
            GameManager.EventSystem.SetSelectedGameObject(m_options[0].gameObject);
        }

        /// <summary>隐藏选项框；按钮槽位内容保留到下一次刷新覆盖。</summary>
        public void Hide()
        {
            SetVisible(false);
        }
    }
}
