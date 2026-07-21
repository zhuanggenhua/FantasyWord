using System;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 技能替换持续效果的存档快照，分别记录临时授予和临时压制的技能编码。
    /// </summary>
    [Serializable]
    public class TemporalAbilityReplacementEffectPersistedState : TemporalEffectPersistedState
    {
        /// <summary>
        /// 读档后需要重新授予给目标的 Formal GAS 技能编码。
        /// </summary>
        public int[] grantedFormalGasAbilityCodes;

        /// <summary>
        /// 读档后需要继续压制的 Formal GAS 技能编码。
        /// </summary>
        public int[] suppressedFormalGasAbilityCodes;
    }

    /// <summary>
    /// 在持续时间内同时压制一组技能并授予另一组技能，用于“替换技能形态”这类状态效果。
    /// </summary>
    [Serializable]
    public class TemporalAbilityReplacementEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        /// <summary>
        /// 技能替换的设计时配置；授予和压制共享同一个状态来源，结束时一起撤销。
        /// </summary>
        [Serializable]
        internal struct AbilityReplacementData
        {
            [LabelText("授予技能编码")]
            [Tooltip("状态生效期间临时添加到目标身上的 Formal GAS 技能编码。")]
            public int[] grantedFormalGasAbilityCodes;

            [LabelText("压制技能编码")]
            [Tooltip("状态生效期间暂时禁用的目标原有 Formal GAS 技能编码。")]
            public int[] suppressedFormalGasAbilityCodes;
        }

        [LabelText("技能替换配置")]
        [Tooltip("定义本状态要授予哪些技能、同时压制哪些技能。")]
        [SerializeField] private AbilityReplacementData m_abilityReplacementData;

        public override TemporalEffectRuntimeTraits GetRuntimeTraits() =>
            TemporalEffectRuntimeTraits.NeedsLocalLifetimeAdvance;

        protected override bool OnApply()
        {
            EnsureFormalGasAbilityCodeConfiguration();
            if (!TemporalAbilityEffectSupport.HasConfiguredFormalGasAbilityCodes(
                    m_abilityReplacementData.grantedFormalGasAbilityCodes,
                    m_abilityReplacementData.suppressedFormalGasAbilityCodes))
            {
                return false;
            }

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

        public bool TryRestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalAbilityReplacementEffectPersistedState state)
            {
                return false;
            }

            if (!TemporalAbilityEffectSupport.TryValidateRestoredFormalGasAbilityCodeConfiguration(
                    nameof(TemporalAbilityReplacementEffect),
                    nameof(TemporalAbilityReplacementEffectPersistedState.grantedFormalGasAbilityCodes),
                    state.grantedFormalGasAbilityCodes) ||
                !TemporalAbilityEffectSupport.TryValidateRestoredFormalGasAbilityCodeConfiguration(
                    nameof(TemporalAbilityReplacementEffect),
                    nameof(TemporalAbilityReplacementEffectPersistedState.suppressedFormalGasAbilityCodes),
                    state.suppressedFormalGasAbilityCodes) ||
                !TemporalAbilityEffectSupport.TryHasRestoredFormalGasAbilityCodes(
                    nameof(TemporalAbilityReplacementEffect),
                    state.grantedFormalGasAbilityCodes,
                    state.suppressedFormalGasAbilityCodes))
            {
                return false;
            }

            state.RestoreSharedStateTo(this);
            m_abilityReplacementData.grantedFormalGasAbilityCodes = TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(state.grantedFormalGasAbilityCodes);
            m_abilityReplacementData.suppressedFormalGasAbilityCodes = TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(state.suppressedFormalGasAbilityCodes);
            return true;
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

        private void EnsureFormalGasAbilityCodeConfiguration()
        {
            TemporalAbilityEffectSupport.EnsureFormalGasAbilityCodeConfiguration(
                nameof(TemporalAbilityReplacementEffect),
                nameof(AbilityReplacementData.grantedFormalGasAbilityCodes),
                m_abilityReplacementData.grantedFormalGasAbilityCodes);
            TemporalAbilityEffectSupport.EnsureFormalGasAbilityCodeConfiguration(
                nameof(TemporalAbilityReplacementEffect),
                nameof(AbilityReplacementData.suppressedFormalGasAbilityCodes),
                m_abilityReplacementData.suppressedFormalGasAbilityCodes);
        }

    }
}
