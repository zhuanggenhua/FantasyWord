using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class AddOrRemoveAbility : IContextualCommand
    {
        [SerializeField] private EAction m_action = EAction.Add;
        [SerializeField] private int m_formalGasAbilityCode = 0;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            CharacterBase target = context.ResolveActorOrCurrentControlledCharacter();
            if (target == null)
            {
                return Task.CompletedTask;
            }

            int formalGasAbilityCode = m_formalGasAbilityCode;
            switch (m_action)
            {
                case EAction.Add:
                    if (formalGasAbilityCode > 0)
                    {
                        target.AddBonusFormalGasAbility(formalGasAbilityCode, CreateCommandAbilitySource(formalGasAbilityCode));
                    }
                    break;

                case EAction.Remove:
                    if (formalGasAbilityCode > 0)
                    {
                        target.RemoveBonusFormalGasAbility(formalGasAbilityCode, CreateCommandAbilitySource(formalGasAbilityCode));
                    }
                    break;
            }

            return Task.CompletedTask;
        }

        private CharacterAbilitySourceKey CreateCommandAbilitySource(int formalGasAbilityCode = 0)
        {
            string sourceId = formalGasAbilityCode > 0
                ? $"{GetType().FullName}:{formalGasAbilityCode}"
                : GetType().FullName;
            return new CharacterAbilitySourceKey(ECharacterAbilitySourceKind.Script, sourceId);
        }
    }
}

