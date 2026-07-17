using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 技能授予持续效果的存档快照，只保存配置中的技能编码和父类共享计时状态。
    /// </summary>
    [Serializable]
    public class TemporalAbilityGrantEffectPersistedState : TemporalEffectPersistedState
    {
        /// <summary>
        /// 持续效果仍然有效时，由该效果临时授予目标的 Formal GAS 技能编码。
        /// </summary>
        public int[] formalGasAbilityCodes;
    }

    /// <summary>
    /// 在持续时间内向目标角色临时授予 Formal GAS 技能，效果结束或来源恢复时按来源键统一移除。
    /// </summary>
    [Serializable]
    public class TemporalAbilityGrantEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier
    {
        /// <summary>
        /// 设计时配置的技能授予列表；运行时会拷贝数组，避免多个效果实例共享可变引用。
        /// </summary>
        [Serializable]
        internal struct AbilityGrantData
        {
            [InspectorName("授予技能编码")]
            [Tooltip("持续效果生效期间临时授予目标的 Formal GAS 技能编码列表；效果结束后会按状态来源统一移除。")]
            public int[] formalGasAbilityCodes;
        }

        [InspectorName("技能授予配置")]
        [Tooltip("配置该持续效果会临时授予哪些 Formal GAS 技能。")]
        [SerializeField] private AbilityGrantData m_abilityGrantData;

        public override TemporalEffectRuntimeTraits GetRuntimeTraits() =>
            TemporalEffectRuntimeTraits.NeedsLocalLifetimeAdvance;

        protected override bool OnApply()
        {
            EnsureFormalGasAbilityCodeConfiguration();
            if (!TemporalAbilityEffectSupport.HasConfiguredFormalGasAbilityCodes(
                    m_abilityGrantData.formalGasAbilityCodes))
            {
                return false;
            }

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

        public bool TryRestorePersistedState(TemporalEffectPersistedState persistedState)
        {
            if (persistedState is not TemporalAbilityGrantEffectPersistedState state)
            {
                return false;
            }

            if (!TemporalAbilityEffectSupport.TryValidateRestoredFormalGasAbilityCodeConfiguration(
                    nameof(TemporalAbilityGrantEffect),
                    nameof(TemporalAbilityGrantEffectPersistedState.formalGasAbilityCodes),
                    state.formalGasAbilityCodes) ||
                !TemporalAbilityEffectSupport.TryHasRestoredFormalGasAbilityCodes(
                    nameof(TemporalAbilityGrantEffect),
                    state.formalGasAbilityCodes))
            {
                return false;
            }

            state.RestoreSharedStateTo(this);
            m_abilityGrantData.formalGasAbilityCodes = TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(state.formalGasAbilityCodes);
            return true;
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

        private void EnsureFormalGasAbilityCodeConfiguration()
        {
            TemporalAbilityEffectSupport.EnsureFormalGasAbilityCodeConfiguration(
                nameof(TemporalAbilityGrantEffect),
                nameof(AbilityGrantData.formalGasAbilityCodes),
                m_abilityGrantData.formalGasAbilityCodes);
        }

    }
}
