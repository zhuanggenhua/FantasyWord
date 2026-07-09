using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class ItemAddAbilityEffect : AItemEffect
    {
        [SerializeField] private int m_formalGasAbilityCode = 0;

        protected override ItemUsageResult OnUse(Item item, CharacterBase sourceOwner, CharacterBase target, EItemLocation location)
        {
            if (m_formalGasAbilityCode > 0)
            {
                if (!target.HasFormalGasAbility(m_formalGasAbilityCode) &&
                    target.AddBonusFormalGasAbility(m_formalGasAbilityCode, CreateItemUseAbilitySource(item)))
                {
                    return new()
                    {
                        success = true,
                        message = $"You learned EX-GAS Ability {m_formalGasAbilityCode}"
                    };
                }

                return new ItemUsageResult { success = false };
            }

            return new ItemUsageResult { success = false };
        }
        private static CharacterAbilitySourceKey CreateItemUseAbilitySource(Item item)
        {
            string sourceId = item
                ? GameManager.Database.CreateReference(item).guid
                : "unknown-item";

            return new CharacterAbilitySourceKey(ECharacterAbilitySourceKind.ItemUse, sourceId);
        }
    }
}

