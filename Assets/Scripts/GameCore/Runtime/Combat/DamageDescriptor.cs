using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Flags]
    public enum EDamageFlag
    {
        [HideInInspector] None = 0,
        Critical = 1 << 0,
        Miss = 1 << 1,
        [HideInInspector] All = ~None
    }

    public enum EResolutionBehavior
    {
        Default,
        Always,
        Never
    }

    public enum EDamageType
    {
        None,
        Physical,
        Magical
    }

    public interface IDamageSource
    {
        public bool TryResolveCharacter(out CharacterBase character);
        public bool TryGetCombatStatSnapshot(out CombatStatSnapshot snapshot);
    }

    public struct UnknownDamageSource : IDamageSource
    {
        public bool TryResolveCharacter(out CharacterBase character)
        {
            character = null;
            return false;
        }

        public bool TryGetCombatStatSnapshot(out CombatStatSnapshot snapshot)
        {
            snapshot = default;
            return false;
        }
    }

    [Serializable]
    public struct CharacterDamageSource : IDamageSource
    {
        public static CharacterDamageSource Create(CharacterBase character)
        {
            CharacterDamageSource source = new();
            source.m_character = character;
            source.m_combatStats = character != null ? character.CreateCombatStatSnapshot() : default;
            return source;
        }

        // We store the attacker as a reference for behaviors that depend on the attacker's instance.
        // i.e. provocation system, or any other system that needs to know where the attack is coming from.
        [SerializeField] private PersistableReference<CharacterBase> m_character;

        // 我们继续保留“攻击发起那一刻”的已缓存战斗属性，
        // 但不再把整份 Stats 都塞进伤害来源，只缓存正式命中结算实际需要的最小集合。
        [SerializeField] private CombatStatSnapshot m_combatStats;

        public bool TryResolveCharacter(out CharacterBase resolvedCharacter)
        {
            resolvedCharacter = m_character.ResolveOrNull();
            return resolvedCharacter != null;
        }

        public bool TryGetCombatStatSnapshot(out CombatStatSnapshot snapshot)
        {
            snapshot = m_combatStats;
            return true;
        }
    }

    /// <summary>
    /// Damage settings
    /// </summary>
    [Serializable]
    public struct DamageDescriptor
    {
        public EDamageType damageType;
        [Min(0)] public float scalingFactor;
        [Min(0)] public int flatDamages;
        public EResolutionBehavior criticalBehavior;
        public EResolutionBehavior missBehavior;
        public bool ignoreDefense;
        public bool silent;
    }

    /// <summary>
    /// Damages output by the attacker after calculations (attack/critical)
    /// </summary>
    [Serializable]
    public struct DamageOutputDescriptor
    {
        [SerializeReference] public IDamageSource source;
        public EDamageType type;
        public int damage;
        public EDamageFlag flags;
        public EResolutionBehavior missBehavior;
        public bool ignoreDefense;
        public bool silent;

        public bool TryGetSourceCharacter(out CharacterBase character)
        {
            character = null;
            return source != null && source.TryResolveCharacter(out character);
        }

        public bool TryGetSourceCombatStatSnapshot(out CombatStatSnapshot snapshot)
        {
            snapshot = default;
            return source != null && source.TryGetCombatStatSnapshot(out snapshot);
        }
    }

    /// <summary>
    /// Damages received by the target after mitigation (defense/miss)
    /// </summary>
    public struct DamageInputDescriptor
    {
        [SerializeReference] public IDamageSource source;
        public int damage;
        public EDamageFlag flags;
        public bool silent;

        public bool IsCriticalHit => flags.HasFlag(EDamageFlag.Critical);

        public bool IsMissed => flags.HasFlag(EDamageFlag.Miss);

        public bool IsRegularHit => flags == EDamageFlag.None;

        public bool IsSilentAppliedHit => silent && !IsMissed;

        public bool TryGetSourceCharacter(out CharacterBase character)
        {
            character = null;
            return source != null && source.TryResolveCharacter(out character);
        }
    }
}
