using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class TemporalAbilitySuppressionEffectPersistedState : TemporalEffectPersistedState
    {
        public int[] formalGasAbilityCodes;
    }

    [Serializable]
    public class TemporalAbilitySuppressionEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        [Serializable]
        internal struct AbilitySuppressionData
        {
            public int[] formalGasAbilityCodes;
        }

        [SerializeField] private AbilitySuppressionData m_abilitySuppressionData;

        public override TemporalEffectRuntimeTraits GetRuntimeTraits() =>
            TemporalEffectRuntimeTraits.NeedsLocalLifetimeAdvance;

        protected override bool OnApply()
        {
            SuppressAbilities();
            return true;
        }

        protected override void OnRuntimeStateRestored()
        {
            SuppressAbilities();
        }

        protected override void OnCompleted()
        {
            if (targetCharacter != null &&
                TryCreateStatusEffectAbilitySource(out CharacterAbilitySourceKey source))
            {
                targetCharacter.RemoveAllStatusEffectAbilitySuppressions(source);
            }
        }

        public override ITemporalEffect Clone()
        {
            TemporalAbilitySuppressionEffect clone = new()
            {
                m_abilitySuppressionData = new AbilitySuppressionData
                {
                    formalGasAbilityCodes = TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(m_abilitySuppressionData.formalGasAbilityCodes)
                }
            };

            CopySharedTemporalStateTo(clone);
            return clone;
        }

        protected override TemporalEffectPresentationState BuildPresentationState()
        {
            return CreatePresentationState(
                TemporalAbilityEffectSupport.CreateAbilityListDetails(
                    m_abilitySuppressionData.formalGasAbilityCodes));
        }

        protected override bool TryResolvePresentationEffectType(out EEffectType effectType)
        {
            effectType = EEffectType.Debuff;
            return true;
        }

        public bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState)
        {
            TemporalAbilitySuppressionEffectPersistedState state = new()
            {
                formalGasAbilityCodes = TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(
                    m_abilitySuppressionData.formalGasAbilityCodes)
            };

            state.CaptureSharedStateFrom(this);
            persistedState = state;
            return true;
        }

        public void RestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalAbilitySuppressionEffectPersistedState state)
            {
                return;
            }

            state.RestoreSharedStateTo(this);
            m_abilitySuppressionData.formalGasAbilityCodes = TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(state.formalGasAbilityCodes);
        }

        private void SuppressAbilities()
        {
            if (targetCharacter == null ||
                !TryCreateStatusEffectAbilitySource(out CharacterAbilitySourceKey source))
            {
                return;
            }

            foreach (int formalGasAbilityCode in TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(
                m_abilitySuppressionData.formalGasAbilityCodes))
            {
                targetCharacter.AddStatusEffectFormalGasAbilitySuppression(formalGasAbilityCode, source);
            }
        }

    }
}
