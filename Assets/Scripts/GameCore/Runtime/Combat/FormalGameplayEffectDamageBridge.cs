using System;
using GAS.Runtime;
using Unity.Entities;
using UnityEngine;
using UEntity = Unity.Entities.Entity;

namespace FantasyWord.GameCore
{
    public enum EFormalDamageConditionKind
    {
        None = 0,
        Backstab = 1
    }

    [Serializable]
    public struct FormalDamageEffectPayload
    {
        [SerializeField] private DamageDescriptor m_damageDescriptor;
        [SerializeField] private EEffectVisualFlags m_visualFlags;
        [SerializeField] private DamageImpactSettings m_damageImpact;
        [SerializeField] private EEffectImpactDataType m_impactDataType;
        [SerializeField] private Vector2 m_impactData;

        public FormalDamageEffectPayload(
            DamageDescriptor damageDescriptor,
            EEffectVisualFlags visualFlags,
            DamageImpactSettings damageImpact,
            EEffectImpactDataType impactDataType,
            Vector2 impactData)
        {
            m_damageDescriptor = damageDescriptor;
            m_visualFlags = visualFlags;
            m_damageImpact = damageImpact;
            m_impactDataType = impactDataType;
            m_impactData = impactData;
        }

        public DamageDescriptor damageDescriptor => m_damageDescriptor;
        public EEffectVisualFlags visualFlags => m_visualFlags;
        public DamageImpactSettings damageImpact => m_damageImpact;
        public EEffectImpactDataType impactDataType => m_impactDataType;
        public Vector2 impactData => m_impactData;
        public bool isConfigured => m_damageDescriptor.flatDamages > 0 || Mathf.Abs(m_damageDescriptor.scalingFactor) > 0.0001f;

        public bool TryGenerateDescription(out EffectDescription description)
        {
            description = default;
            if (!isConfigured)
            {
                return false;
            }

            string flatDamage = m_damageDescriptor.flatDamages != 0
                ? $"{m_damageDescriptor.flatDamages:0.#} {GameConfig.GetSafeTermDefinition("flat_damage").shortName}"
                : string.Empty;
            string scaledDamage = m_damageDescriptor.scalingFactor != 0.0f
                ? $"{m_damageDescriptor.scalingFactor:0.#} {GameConfig.GetSafeTermDefinition("scaled_damage").shortName}"
                : string.Empty;

            description = new EffectDescription
            {
                name = GameConfig.GetSafeTermDefinition("remove_health").shortName,
                details = $"{flatDamage}{(string.IsNullOrEmpty(flatDamage) || string.IsNullOrEmpty(scaledDamage) ? string.Empty : "+")}{scaledDamage} {GameConfig.GetSafeTermDefinition(m_damageDescriptor.damageType).shortName}"
            };
            return true;
        }
    }

    public sealed class MCConfFormalDamageEffect : GameplayEffectComponentConfig
    {
        public FormalDamageEffectPayload payload;

        public override void LoadToGameplayEffectEntity(UEntity ge)
        {
            EntityHelper.AddManagedComponent<MCFormalDamageEffect>(ge);
            EntityHelper.SetManagedComponent(ge, new MCFormalDamageEffect(payload));
        }
    }

    public sealed class MCFormalDamageEffect : IComponentData
    {
        public MCFormalDamageEffect()
        {
            Payload = default;
        }

        public MCFormalDamageEffect(FormalDamageEffectPayload payload)
        {
            Payload = payload;
        }

        public FormalDamageEffectPayload Payload;
    }

    [Serializable]
    public readonly struct FormalDamageConditionPayload
    {
        public FormalDamageConditionPayload(EFormalDamageConditionKind kind, float facingDotThreshold)
        {
            Kind = kind;
            FacingDotThreshold = Mathf.Clamp(facingDotThreshold, -1.0f, 1.0f);
        }

        public EFormalDamageConditionKind Kind { get; }
        public float FacingDotThreshold { get; }
        public bool requiresCondition => Kind != EFormalDamageConditionKind.None;
    }

    [Serializable]
    public readonly struct FormalConditionalDamageEffectPayload
    {
        public FormalConditionalDamageEffectPayload(
            FormalDamageConditionPayload condition,
            FormalDamageEffectPayload damage)
        {
            Condition = condition;
            Damage = damage;
        }

        public FormalDamageConditionPayload Condition { get; }
        public FormalDamageEffectPayload Damage { get; }
        public bool isConfigured => Damage.isConfigured && Condition.requiresCondition;
    }

    public sealed class MCConfFormalConditionalDamageEffect : GameplayEffectComponentConfig
    {
        public FormalConditionalDamageEffectPayload payload;

        public override void LoadToGameplayEffectEntity(UEntity ge)
        {
            EntityHelper.AddManagedComponent<MCFormalConditionalDamageEffect>(ge);
            EntityHelper.SetManagedComponent(ge, new MCFormalConditionalDamageEffect(payload));
        }
    }

    public sealed class MCFormalConditionalDamageEffect : IComponentData
    {
        public MCFormalConditionalDamageEffect()
        {
            Payload = default;
        }

        public MCFormalConditionalDamageEffect(FormalConditionalDamageEffectPayload payload)
        {
            Payload = payload;
        }

        public FormalConditionalDamageEffectPayload Payload;
    }
}
