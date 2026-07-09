using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    public class UICharacterStat : UIStat
    {
        [Header("References")]
        [SerializeField] private Button m_decreaseButton;
        [SerializeField] private Button m_increaseButton;

        public void RegisterCallbacks(UnityAction<EStat> decrease, UnityAction<EStat> increase)
        {
            m_decreaseButton.onClick.AddListener(() => decrease(m_stat));
            m_increaseButton.onClick.AddListener(() => increase(m_stat));
        }

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

        // 只回答默认焦点对象，不把内部 Button 直接外借给外层菜单。
        public GameObject GetDefaultFocusTarget() => m_decreaseButton != null ? m_decreaseButton.gameObject : gameObject;
    }
}

