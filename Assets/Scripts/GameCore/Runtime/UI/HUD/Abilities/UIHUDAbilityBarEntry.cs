using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// HUD 技能栏里的单个技能条目。
    /// 它在基类图标显示之外，补充快捷键提示和主动技能冷却显示。
    /// </summary>
    public class UIHUDAbilityBarEntry : UIAbility
    {
        [SerializeField]
        [LabelText("控制器按钮提示")]
        [Tooltip("显示当前技能槽对应输入动作的按钮提示。")]
        private UIControllerButton m_controllerButton = null;

        [SerializeField]
        [LabelText("冷却滑条")]
        [Tooltip("显示主动技能冷却剩余比例的 Slider。")]
        private Slider m_cooldownSlider = null;

        [SerializeField]
        [LabelText("冷却文本")]
        [Tooltip("显示冷却剩余秒数的 TMP 文本。")]
        private TextMeshProUGUI m_cooldownText = null;

        private CharacterBase m_boundCharacter = null;

        /// <summary>绑定技能槽并根据槽位序号同步按钮动作提示。</summary>
        public override void SetAbility(CharacterEquippedAbilitySlotView slot, int index)
        {
            base.SetAbility(slot, index);

            gameObject.SetActive(slot.HasDisplaySource);

            if (slot.HasDisplaySource)
            {
                m_controllerButton.SetAction((UIControllerButtonManager.EAction)(index + (int)UIControllerButtonManager.EAction.FireAbility1));
            }
        }

        /// <summary>设置用于查询冷却快照的角色；解绑时同步清空冷却显示。</summary>
        public void SetBoundCharacter(CharacterBase character)
        {
            m_boundCharacter = character;
            if (m_boundCharacter == null)
            {
                ClearCooldownUI();
            }
        }

        /// <summary>每帧刷新当前技能槽冷却；没有绑定角色或技能时保持空冷却显示。</summary>
        private void Update()
        {
            if (m_boundCharacter == null || !m_abilitySlot.HasDisplaySource)
            {
                ClearCooldownUI();
                return;
            }

            if (m_boundCharacter.TryGetActiveAbilityCooldownSnapshot(m_abilitySlot, out CharacterAbilityCooldownSnapshot cooldownSnapshot))
            {
                float remainingCooldown = cooldownSnapshot.RemainingCooldown;
                float cooldown = cooldownSnapshot.Cooldown;
                if (cooldown > 0.0f)
                {
                    float cooldownRatio = (cooldown - remainingCooldown) / cooldown;
                    m_cooldownSlider.value = 1.0f - cooldownRatio;
                }
                else
                {
                    m_cooldownSlider.value = 0.0f;
                }

                int seconds = Mathf.CeilToInt(remainingCooldown);
                m_cooldownText.text =
                    remainingCooldown > 0.0f ?
                    (remainingCooldown < 0.5f ? $"{remainingCooldown:0.0}" : $"{seconds}") :
                    string.Empty;
            }
            else
            {
                ClearCooldownUI();
            }
        }

        /// <summary>清空冷却滑条和文本，避免旧技能槽的剩余时间残留。</summary>
        private void ClearCooldownUI()
        {
            m_cooldownSlider.value = 0.0f;
            m_cooldownText.text = string.Empty;
        }
    }
}

