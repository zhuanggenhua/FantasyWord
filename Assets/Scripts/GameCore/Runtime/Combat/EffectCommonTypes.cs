using System;
using System.Linq;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public enum EEffectInteractionResult
    {
        NotApplicable,
        ApplyFailed,
        ApplySucceeded,
        Consumed
    }

    public enum EEffectImpactDataType
    {
        SourcePosition,
        Velocity
    }

    public enum EDamagePushMode
    {
        Default,
        Disabled,
        Override
    }

    /// <summary>
    /// 伤害命中后的动作表现参数。
    /// 它只控制击退和短暂无敌等受击手感，伤害数值、阵营和命中结果仍由 RPG 战斗规则决定。
    /// </summary>
    [Serializable]
    public struct DamageImpactSettings
    {
        public EDamagePushMode pushMode;
        public float pushIntensity;
        public float pushResistance;
        public float invincibilityDuration;

        public float sanitizedPushIntensity => Mathf.Max(0.0f, pushIntensity);
        public float sanitizedPushResistance => Mathf.Max(0.0f, pushResistance);
        public float sanitizedInvincibilityDuration => Mathf.Max(0.0f, invincibilityDuration);
    }

    [Serializable]
    public struct EffectImpactSettings
    {
        public EEffectImpactDataType impactDataType;
        public Vector2 impactData;
        public DamageImpactSettings damageImpact;
    }

    public readonly struct EffectApplicationResult
    {
        private readonly EEffectInteractionResult[] m_feed;
        private readonly CharacterBase[] m_affectedTargets;

        public int AffectedTargetCount => m_affectedTargets.Length;

        public EffectApplicationResult(EEffectInteractionResult[] feedSnapshot, CharacterBase[] affectedTargetSnapshot)
        {
            m_feed = feedSnapshot != null ? (EEffectInteractionResult[])feedSnapshot.Clone() : Array.Empty<EEffectInteractionResult>();
            m_affectedTargets = affectedTargetSnapshot != null ? affectedTargetSnapshot.Where(target => target != null).ToArray() : Array.Empty<CharacterBase>();
        }

        public bool HasAnyInteractionBeyond(EEffectInteractionResult interactionResult)
        {
            return Array.Exists(m_feed, item => item != interactionResult);
        }

        public EEffectInteractionResult[] CreateFeedSnapshot()
        {
            return (EEffectInteractionResult[])m_feed.Clone();
        }

        public CharacterBase[] CreateAffectedTargetsSnapshot()
        {
            return (CharacterBase[])m_affectedTargets.Clone();
        }
    }
}
