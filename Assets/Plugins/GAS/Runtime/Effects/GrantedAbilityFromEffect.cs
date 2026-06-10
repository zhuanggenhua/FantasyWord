using System;
using GAS.General;
using NaughtyAttributes;
using UnityEngine;

namespace GAS.Runtime
{
    /// <summary>
    /// 授予能力的激活策略
    /// </summary>
    public enum GrantedAbilityActivationPolicy
    {
        /// <summary>
        /// 不激活, 等待用户调用ASC激活
        /// </summary>
        [Label("None - 不激活, 等待用户调用ASC激活")]
        None,

        /// <summary>
        /// 能力添加时激活（GE添加时激活）
        /// </summary>
        [Label("WhenAdded - 能力添加时激活（GE添加时激活）")]
        WhenAdded,

        /// <summary>
        /// 同步GE激活时激活
        /// </summary>
        [Label("SyncWithEffect - 同步GE激活时激活")]
        SyncWithEffect,
    }

    /// <summary>
    /// 授予能力的取消激活策略
    /// </summary>
    public enum GrantedAbilityDeactivationPolicy
    {
        /// <summary>
        /// 无相关取消激活逻辑, 需要用户调用ASC取消激活
        /// </summary>
        [Label("None - 无相关取消激活逻辑, 需要用户调用ASC取消激活")]
        None,

        /// <summary>
        /// 同步GE，GE失活时取消激活
        /// </summary>
        [Label("SyncWithEffect - 同步GE，GE失活时取消激活")]
        SyncWithEffect,
    }

    /// <summary>
    /// 授予能力的移除策略
    /// </summary>
    public enum GrantedAbilityRemovePolicy
    {
        /// <summary>
        /// 不移除
        /// </summary>
        [Label("None - 不移除")]
        None,

        /// <summary>
        /// 同步GE，GE移除时移除
        /// </summary>
        [Label("SyncWithEffect - 同步GE，GE移除时移除")]
        SyncWithEffect,

        /// <summary>
        /// 能力结束时自己移除
        /// </summary>
        [Label("WhenEnd - 能力结束时自己移除")]
        WhenEnd,

        /// <summary>
        /// 能力取消时自己移除
        /// </summary>
        [Label("WhenCancel - 能力取消时自己移除")]
        WhenCancel,

        /// <summary>
        /// 能力结束或取消时自己移除
        /// </summary>
        [Label("WhenCancelOrEnd - 能力结束或取消时自己移除")]
        WhenCancelOrEnd,
    }

    [Serializable]
    public struct GrantedAbilityConfig
    {
        private const int LABEL_WIDTH = 50;

                [Label(GASTextDefine.LABEL_GRANT_ABILITY)]
                public AbilityAsset AbilityAsset;

                [Label(GASTextDefine.LABEL_GRANT_ABILITY_LEVEL)]
        public int AbilityLevel;

                [Label(GASTextDefine.LABEL_GRANT_ABILITY_ACTIVATION_POLICY)]
        [Tooltip(GASTextDefine.TIP_GRANT_ABILITY_ACTIVATION_POLICY)]
        public GrantedAbilityActivationPolicy ActivationPolicy;

                [Label(GASTextDefine.LABEL_GRANT_ABILITY_DEACTIVATION_POLICY)]
        [Tooltip(GASTextDefine.TIP_GRANT_ABILITY_DEACTIVATION_POLICY)]
        public GrantedAbilityDeactivationPolicy DeactivationPolicy;

                [Label(GASTextDefine.LABEL_GRANT_ABILITY_REMOVE_POLICY)]
        [Tooltip(GASTextDefine.TIP_GRANT_ABILITY_REMOVE_POLICY)]
        public GrantedAbilityRemovePolicy RemovePolicy;
    }

    public class GrantedAbilityFromEffect
    {
        public readonly AbstractAbility Ability;
        public readonly int AbilityLevel;
        public readonly GrantedAbilityActivationPolicy ActivationPolicy;
        public readonly GrantedAbilityDeactivationPolicy DeactivationPolicy;
        public readonly GrantedAbilityRemovePolicy RemovePolicy;

        public GrantedAbilityFromEffect(GrantedAbilityConfig config)
        {
            Ability =
                Activator.CreateInstance(config.AbilityAsset.AbilityType(), args: config.AbilityAsset) as
                    AbstractAbility;
            AbilityLevel = config.AbilityLevel;
            ActivationPolicy = config.ActivationPolicy;
            DeactivationPolicy = config.DeactivationPolicy;
            RemovePolicy = config.RemovePolicy;
        }

        public GrantedAbilityFromEffect(
            AbstractAbility ability,
            int abilityLevel,
            GrantedAbilityActivationPolicy activationPolicy,
            GrantedAbilityDeactivationPolicy deactivationPolicy,
            GrantedAbilityRemovePolicy removePolicy)
        {
            Ability = ability;
            AbilityLevel = abilityLevel;
            ActivationPolicy = activationPolicy;
            DeactivationPolicy = deactivationPolicy;
            RemovePolicy = removePolicy;
        }

        public GrantedAbilitySpecFromEffect CreateSpec(GameplayEffectSpec sourceEffectSpec)
        {
            var grantedAbility = new GrantedAbilitySpecFromEffect(this, sourceEffectSpec);
            return grantedAbility;
        }
    }

    public class GrantedAbilitySpecFromEffect
    {
        public readonly GrantedAbilityFromEffect GrantedAbility;
        public readonly GameplayEffectSpec SourceEffectSpec;
        public readonly AbilitySystemComponent Owner;

        public readonly string AbilityName;
        public int AbilityLevel => GrantedAbility.AbilityLevel;
        public GrantedAbilityActivationPolicy ActivationPolicy => GrantedAbility.ActivationPolicy;
        public GrantedAbilityDeactivationPolicy DeactivationPolicy => GrantedAbility.DeactivationPolicy;
        public GrantedAbilityRemovePolicy RemovePolicy => GrantedAbility.RemovePolicy;
        public AbilitySpec AbilitySpec => Owner.AbilityContainer.AbilitySpecs()[AbilityName];

        public GrantedAbilitySpecFromEffect(GrantedAbilityFromEffect grantedAbility,
            GameplayEffectSpec sourceEffectSpec)
        {
            GrantedAbility = grantedAbility;
            SourceEffectSpec = sourceEffectSpec;
            AbilityName = GrantedAbility.Ability.Name;
            Owner = SourceEffectSpec.Owner;
            if (Owner.AbilityContainer.HasAbility(AbilityName))
            {
                Debug.LogError($"GrantedAbilitySpecFromEffect: {Owner.name} already has ability {AbilityName}");
            }

            Owner.GrantAbility(GrantedAbility.Ability);
            AbilitySpec.SetLevel(AbilityLevel);

            // 是否添加时激活
            if (ActivationPolicy == GrantedAbilityActivationPolicy.WhenAdded)
            {
                Owner.TryActivateAbility(AbilityName);
            }

            switch (RemovePolicy)
            {
                case GrantedAbilityRemovePolicy.WhenEnd:
                    AbilitySpec.RegisterEndAbility(RemoveSelf);
                    break;
                case GrantedAbilityRemovePolicy.WhenCancel:
                    AbilitySpec.RegisterCancelAbility(RemoveSelf);
                    break;
                case GrantedAbilityRemovePolicy.WhenCancelOrEnd:
                    AbilitySpec.RegisterEndAbility(RemoveSelf);
                    AbilitySpec.RegisterCancelAbility(RemoveSelf);
                    break;
            }
        }

        private void RemoveSelf()
        {
            Owner.RemoveAbility(AbilityName);
        }
    }
}