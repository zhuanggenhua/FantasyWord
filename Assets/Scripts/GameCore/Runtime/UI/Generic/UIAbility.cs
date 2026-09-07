using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 能力图标 UI 基类。
    /// 它只负责把已解析的装备技能槽视图写入图标，不解析技能来源、不决定技能是否可释放。
    /// </summary>
    public class UIAbility : MonoBehaviour
    {
        [SerializeField]
        [LabelText("技能图标")]
        [Tooltip("显示技能图标的 Image；槽位没有显示来源时会被关闭并清空 Sprite。")]
        private Image m_icon = null;

        protected CharacterEquippedAbilitySlotView m_abilitySlot = default;
        protected int m_abilityIndex = -1;

        /// <summary>绑定一个已解析的装备技能槽，并按最大可装备数量和显示来源刷新图标状态。</summary>
        public virtual void SetAbility(CharacterEquippedAbilitySlotView slot, int index)
        {
            gameObject.SetActive(index < GameManager.Config.maxEquippableAbilities);

            m_abilitySlot = slot;
            m_abilityIndex = index;

            if (m_abilitySlot.HasDisplaySource)
            {
                m_icon.enabled = true;
                m_icon.sprite = m_abilitySlot.Icon;
            }
            else
            {
                m_icon.enabled = false;
                m_icon.sprite = null;
            }
        }
    }
}
