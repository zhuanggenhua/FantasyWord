using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class TemporalAbilityGrantEffectPersistedState : TemporalEffectPersistedState
    {
        public int[] formalGasAbilityCodes;
    }

    [Serializable]
    public class TemporalAbilityGrantEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        [Serializable]
        internal struct AbilityGrantData
        {
            public int[] formalGasAbilityCodes;
        }

        [SerializeField] private AbilityGrantData m_abilityGrantData;

        public override TemporalEffectRuntimeTraits GetRuntimeTraits() =>
            TemporalEffectRuntimeTraits.NeedsLocalLifetimeAdvance;

        protected override bool OnApply()
        {
            GrantAbilities();
            return true;
        }

        protected override void OnRuntimeStateRestored()
        {
            GrantAbilities();
        }

        protected override void OnCompleted()
        {
            if (targetCharacter != null &&
                TryCreateStatusEffectAbilitySource(out CharacterAbilitySourceKey source))
            {
                targetCharacter.RemoveAllStatusEffectAbilities(source);
            }
        }

        public override ITemporalEffect Clone()
        {
            TemporalAbilityGrantEffect clone = new()
            {
                m_abilityGrantData = new AbilityGrantData
                {
                    formalGasAbilityCodes = TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(m_abilityGrantData.formalGasAbilityCodes)
                }
            };

            CopySharedTemporalStateTo(clone);
            return clone;
        }

        protected override TemporalEffectPresentationState BuildPresentationState()
        {
            return CreatePresentationState(
                TemporalAbilityEffectSupport.CreateAbilityListDetails(
                    m_abilityGrantData.formalGasAbilityCodes));
        }

        protected override bool TryResolvePresentationEffectType(out EEffectType effectType)
        {
            effectType = EEffectType.Buff;
            return true;
        }

        public bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState)
        {
            TemporalAbilityGrantEffectPersistedState state = new()
            {
                formalGasAbilityCodes = TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(
                    m_abilityGrantData.formalGasAbilityCodes)
            };

            state.CaptureSharedStateFrom(this);
            persistedState = state;
            return true;
        }

        public void RestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalAbilityGrantEffectPersistedState state)
            {
                return;
            }

            state.RestoreSharedStateTo(this);
            m_abilityGrantData.formalGasAbilityCodes = TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(state.formalGasAbilityCodes);
        }

        private void GrantAbilities()
        {
            if (targetCharacter == null ||
                !TryCreateStatusEffectAbilitySource(out CharacterAbilitySourceKey source))
            {
                return;
            }

            foreach (int formalGasAbilityCode in TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(
                m_abilityGrantData.formalGasAbilityCodes))
            {
                targetCharacter.AddStatusEffectFormalGasAbility(formalGasAbilityCode, source);
            }
        }

    }
}
