using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色属性加点行，在通用属性显示的基础上管理加减按钮回调和临时点数展示。
    /// 它不直接写角色属性，最终写回统一交给外层 <see cref="UICharacter"/>。
    /// </summary>
    public class UICharacterStat : UIStat
    {
        [SerializeField]
        [LabelText("减少按钮"), Tooltip("撤回该属性 1 个临时加点；已应用到角色的点数不会被这里回退。")]
        private Button m_decreaseButton;

        [SerializeField]
        [LabelText("增加按钮"), Tooltip("给该属性增加 1 个临时点数，是否可加由外层角色菜单判断。")]
        private Button m_increaseButton;

        private UnityAction m_decreaseCallback;
        private UnityAction m_increaseCallback;

        /// <summary>登记外层菜单的加减点回调；重复登记前会先移除旧回调，避免按钮一次点击触发多次。</summary>
        public void RegisterCallbacks(UnityAction<EStat> decrease, UnityAction<EStat> increase)
        {
            UnregisterCallbacks();
            m_decreaseCallback = () => decrease(m_stat);
            m_increaseCallback = () => increase(m_stat);
            m_decreaseButton.onClick.AddListener(m_decreaseCallback);
            m_increaseButton.onClick.AddListener(m_increaseCallback);
        }

        /// <summary>移除按钮回调，面板销毁或重新登记前必须调用，避免持有旧菜单实例。</summary>
        public void UnregisterCallbacks()
        {
            if (m_decreaseCallback != null)
            {
                m_decreaseButton.onClick.RemoveListener(m_decreaseCallback);
                m_decreaseCallback = null;
            }

            if (m_increaseCallback != null)
            {
                m_increaseButton.onClick.RemoveListener(m_increaseCallback);
                m_increaseCallback = null;
            }
        }

        /// <summary>刷新属性数值；临时加点大于 0 时追加括号提示，方便玩家确认尚未应用的分配。</summary>
        public void UpdateUI(CharacterBase target, Stats tempStats)
        {
            int baseValue = target != null ? target.GetStatValue(definition) : 0;
            int pendingValue = tempStats != null ? tempStats[m_stat] : 0;

            if (pendingValue > 0)
            {
                m_value.text = string.Format("{0} (+{1})", baseValue, pendingValue);
            }
            else
            {
                m_value.text = string.Format("{0}", baseValue);
            }
        }

        /// <summary>只回答默认焦点对象，不把内部 Button 直接外借给外层菜单。</summary>
        public GameObject GetDefaultFocusTarget() => m_decreaseButton != null ? m_decreaseButton.gameObject : gameObject;
    }
}
