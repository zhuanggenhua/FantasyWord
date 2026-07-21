using System;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 技能压制持续效果的存档快照，只记录仍需保持压制的 Formal GAS 技能编码。
    /// </summary>
    [Serializable]
    public class TemporalAbilitySuppressionEffectPersistedState : TemporalEffectPersistedState
    {
        /// <summary>
        /// 读档后需要继续压制的目标技能编码。
        /// </summary>
        public int[] formalGasAbilityCodes;
    }

    /// <summary>
    /// 在持续时间内按来源键压制目标角色的指定 Formal GAS 技能，效果结束后撤销压制。
    /// </summary>
    [Serializable]
    public class TemporalAbilitySuppressionEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        /// <summary>
        /// 设计时配置的技能压制列表；运行时会按状态来源登记，避免误删其他来源的压制。
        /// </summary>
        [Serializable]
        internal struct AbilitySuppressionData
        {
            [LabelText("压制技能编码")]
            [Tooltip("持续效果生效期间暂时禁用的目标 Formal GAS 技能编码列表。")]
            public int[] formalGasAbilityCodes;
        }

        [LabelText("技能压制配置")]
        [Tooltip("配置该持续效果会暂时禁用哪些 Formal GAS 技能。")]
        [SerializeField] private AbilitySuppressionData m_abilitySuppressionData;

        public override TemporalEffectRuntimeTraits GetRuntimeTraits() =>
            TemporalEffectRuntimeTraits.NeedsLocalLifetimeAdvance;

        protected override bool OnApply()
        {
            EnsureFormalGasAbilityCodeConfiguration();
            if (!TemporalAbilityEffectSupport.HasConfiguredFormalGasAbilityCodes(
                    m_abilitySuppressionData.formalGasAbilityCodes))
            {
                return false;
            }

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

        public bool TryRestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalAbilitySuppressionEffectPersistedState state)
            {
                return false;
            }

            if (!TemporalAbilityEffectSupport.TryValidateRestoredFormalGasAbilityCodeConfiguration(
                    nameof(TemporalAbilitySuppressionEffect),
                    nameof(TemporalAbilitySuppressionEffectPersistedState.formalGasAbilityCodes),
                    state.formalGasAbilityCodes) ||
                !TemporalAbilityEffectSupport.TryHasRestoredFormalGasAbilityCodes(
                    nameof(TemporalAbilitySuppressionEffect),
                    state.formalGasAbilityCodes))
            {
                return false;
            }

            state.RestoreSharedStateTo(this);
            m_abilitySuppressionData.formalGasAbilityCodes = TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(state.formalGasAbilityCodes);
            return true;
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

        private void EnsureFormalGasAbilityCodeConfiguration()
        {
            TemporalAbilityEffectSupport.EnsureFormalGasAbilityCodeConfiguration(
                nameof(TemporalAbilitySuppressionEffect),
                nameof(AbilitySuppressionData.formalGasAbilityCodes),
                m_abilitySuppressionData.formalGasAbilityCodes);
        }

    }
}
