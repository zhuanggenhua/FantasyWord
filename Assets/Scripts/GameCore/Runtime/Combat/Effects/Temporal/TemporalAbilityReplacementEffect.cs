using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class TemporalAbilityReplacementEffectPersistedState : TemporalEffectPersistedState
    {
        public int[] grantedFormalGasAbilityCodes;
        public int[] suppressedFormalGasAbilityCodes;
    }

    [Serializable]
    public class TemporalAbilityReplacementEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        [Serializable]
        internal struct AbilityReplacementData
        {
            public int[] grantedFormalGasAbilityCodes;
            public int[] suppressedFormalGasAbilityCodes;
        }

        [SerializeField] private AbilityReplacementData m_abilityReplacementData;

        public override TemporalEffectRuntimeTraits GetRuntimeTraits() =>
            TemporalEffectRuntimeTraits.NeedsLocalLifetimeAdvance;

        protected override bool OnApply()
        {
            ApplyReplacement();
            return true;
        }

        protected override void OnRuntimeStateRestored()
        {
            ApplyReplacement();
        }

        protected override void OnCompleted()
        {
            if (targetCharacter != null &&
                TryCreateStatusEffectAbilitySource(out CharacterAbilitySourceKey source))
            {
                targetCharacter.RemoveAllStatusEffectAbilities(source);
                targetCharacter.RemoveAllStatusEffectAbilitySuppressions(source);
            }
        }

        public override ITemporalEffect Clone()
        {
            TemporalAbilityReplacementEffect clone = new()
            {
                m_abilityReplacementData = new AbilityReplacementData
                {
                    grantedFormalGasAbilityCodes = TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(m_abilityReplacementData.grantedFormalGasAbilityCodes),
                    suppressedFormalGasAbilityCodes = TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(m_abilityReplacementData.suppressedFormalGasAbilityCodes)
                }
            };

            CopySharedTemporalStateTo(clone);
            return clone;
        }

        protected override TemporalEffectPresentationState BuildPresentationState()
        {
            return CreatePresentationState(
                CreateReplacementDetails());
        }

        protected override bool TryResolvePresentationEffectType(out EEffectType effectType)
        {
            effectType = HasSuppressedAbilities() ? EEffectType.Debuff : EEffectType.Buff;
            return true;
        }

        public bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState)
        {
            TemporalAbilityReplacementEffectPersistedState state = new()
            {
                grantedFormalGasAbilityCodes = TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(
                    m_abilityReplacementData.grantedFormalGasAbilityCodes),
                suppressedFormalGasAbilityCodes = TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(
                    m_abilityReplacementData.suppressedFormalGasAbilityCodes)
            };

            state.CaptureSharedStateFrom(this);
            persistedState = state;
            return true;
        }

        public void RestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalAbilityReplacementEffectPersistedState state)
            {
                return;
            }

            state.RestoreSharedStateTo(this);
            m_abilityReplacementData.grantedFormalGasAbilityCodes = TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(state.grantedFormalGasAbilityCodes);
            m_abilityReplacementData.suppressedFormalGasAbilityCodes = TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(state.suppressedFormalGasAbilityCodes);
        }

        private void ApplyReplacement()
        {
            if (targetCharacter == null)
            {
                return;
            }

            SuppressAbilities();
            GrantAbilities();
        }

        private void GrantAbilities()
        {
            if (!TryCreateStatusEffectAbilitySource(out CharacterAbilitySourceKey source))
            {
                return;
            }

            foreach (int formalGasAbilityCode in TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(
                m_abilityReplacementData.grantedFormalGasAbilityCodes))
            {
                targetCharacter.AddStatusEffectFormalGasAbility(formalGasAbilityCode, source);
            }
        }

        private void SuppressAbilities()
        {
            if (!TryCreateStatusEffectAbilitySource(out CharacterAbilitySourceKey source))
            {
                return;
            }

            foreach (int formalGasAbilityCode in TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(
                m_abilityReplacementData.suppressedFormalGasAbilityCodes))
            {
                targetCharacter.AddStatusEffectFormalGasAbilitySuppression(formalGasAbilityCode, source);
            }
        }

        private bool HasSuppressedAbilities()
        {
            return m_abilityReplacementData.suppressedFormalGasAbilityCodes != null &&
                m_abilityReplacementData.suppressedFormalGasAbilityCodes.Length > 0;
        }

        private string CreateReplacementDetails()
        {
            string granted = TemporalAbilityEffectSupport.CreateAbilityListDetails(
                m_abilityReplacementData.grantedFormalGasAbilityCodes);
            string suppressed = TemporalAbilityEffectSupport.CreateAbilityListDetails(
                m_abilityReplacementData.suppressedFormalGasAbilityCodes);

            if (string.IsNullOrEmpty(granted))
            {
                return suppressed;
            }

            if (string.IsNullOrEmpty(suppressed))
            {
                return granted;
            }

            return $"{granted} / {suppressed}";
        }

    }
}
