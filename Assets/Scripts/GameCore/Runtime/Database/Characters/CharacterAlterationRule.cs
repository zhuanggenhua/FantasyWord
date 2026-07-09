using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public enum ECharacterAlterationRuleKind
    {
        Transformation,
        Infection
    }

    public enum ECharacterAlterationStackingPolicy
    {
        Unique,
        Stackable
    }

    public readonly struct CharacterAlterationAbilityChangeResult
    {
        public CharacterAlterationAbilityChangeResult(
            bool sourceResolved,
            int grantedAbilityCount,
            int suppressedAbilityCount,
            int removedGrantedAbilityCount,
            int removedSuppressedAbilityCount)
        {
            SourceResolved = sourceResolved;
            GrantedAbilityCount = grantedAbilityCount;
            SuppressedAbilityCount = suppressedAbilityCount;
            RemovedGrantedAbilityCount = removedGrantedAbilityCount;
            RemovedSuppressedAbilityCount = removedSuppressedAbilityCount;
        }

        public bool SourceResolved { get; }
        public int GrantedAbilityCount { get; }
        public int SuppressedAbilityCount { get; }
        public int RemovedGrantedAbilityCount { get; }
        public int RemovedSuppressedAbilityCount { get; }
    }

    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Characters + nameof(CharacterAlterationRule))]
    public class CharacterAlterationRule : DatabaseEntry, INameable
    {
        [Header("UI Settings")]
        [SerializeField] private string m_displayName = string.Empty;
        [SerializeField] private string m_description = string.Empty;

        [Header("Rule Identity")]
        [SerializeField]
        [Tooltip("规则类型决定来源键归入变形还是感染。丧尸化当前按感染类规则处理，后续如需要独立来源类型再单独裁决。")]
        private ECharacterAlterationRuleKind m_ruleKind = ECharacterAlterationRuleKind.Transformation;

        [SerializeField]
        [Tooltip("唯一规则同一角色只能激活一次；可叠层规则每次激活都会增加一层能力授予/压制来源。")]
        private ECharacterAlterationStackingPolicy m_stackingPolicy = ECharacterAlterationStackingPolicy.Unique;

        [SerializeField]
        [Tooltip("非空时，同组规则会按优先级互斥。用于狼人形态、丧尸阶段等同一身体状态只能保留一个胜出规则的场景。")]
        private string m_exclusiveGroupId = string.Empty;

        [SerializeField]
        [Tooltip("同一互斥组内，高优先级规则会保留；低优先级规则不能覆盖高优先级规则。")]
        private int m_priority;

        [Header("Ability Changes")]
        [SerializeField]
        [Tooltip("规则生效期间临时授予角色的 EX-GAS Ability Code。正式技能必须填这里。")]
        private int[] m_grantedFormalGasAbilityCodes = Array.Empty<int>();

        [SerializeField]
        [Tooltip("规则生效期间临时压制的 EX-GAS Ability Code。正式技能必须填这里。")]
        private int[] m_suppressedFormalGasAbilityCodes = Array.Empty<int>();

        [Header("Control Changes")]
        [SerializeField]
        [Tooltip("规则生效期间锁定的角色动作。会影响玩家输入、AI 移动、能力权限、装备变更和主动背包操作。")]
        private EActionFlags m_lockedActions = EActionFlags.None;

        [SerializeField]
        [Tooltip("勾选后，规则生效期间角色不能作为玩家当前控制对象。适用于丧尸化、失控变形或被精神控制等会夺走直接操控权的状态。")]
        private bool m_lockPlayerControl = false;

        [SerializeField]
        [Tooltip("勾选后，规则生效期间尝试把角色切到同一角色上已配置的 AIController。它会同时锁定玩家直接控制；没有 AIController 时不会伪造第二套 AI。")]
        private bool m_forceAIControl = false;

        [SerializeField]
        [Tooltip("勾选后，规则生效期间角色身上的装备属性和装备授予能力会暂时失效，但装备物品本身仍留在原槽位。")]
        private bool m_suppressEquipmentEffects = false;

        [SerializeField]
        [Tooltip("勾选后，规则生效期间临时覆盖角色阵营。感染、丧尸化或敌对变形可用它影响 AI 选敌和伤害判定。")]
        private bool m_overrideAlignment = false;

        [SerializeField]
        [Tooltip("规则生效期间覆盖到的阵营。多条规则同时覆盖时按规则优先级裁决。")]
        private EAlignment m_alignmentOverride = EAlignment.Default;

        public string displayName => DisplayNameUtils.GetNameOrDefault(this, m_displayName);
        public string description => m_description;
        public ECharacterAlterationRuleKind ruleKind => m_ruleKind;
        public ECharacterAlterationStackingPolicy stackingPolicy => m_stackingPolicy;
        public string exclusiveGroupId => m_exclusiveGroupId;
        public int priority => m_priority;
        public EActionFlags lockedActions => m_lockedActions;
        public bool locksPlayerControl => m_lockPlayerControl;
        public bool forcesAIControl => m_forceAIControl;
        public bool suppressesEquipmentEffects => m_suppressEquipmentEffects;
        public bool overridesAlignment => m_overrideAlignment;
        public EAlignment alignmentOverride => m_alignmentOverride;
        public int[] grantedFormalGasAbilityCodes => CreateGrantedFormalGasAbilityCodeSnapshot();
        public int[] suppressedFormalGasAbilityCodes => CreateSuppressedFormalGasAbilityCodeSnapshot();

        public int[] CreateGrantedFormalGasAbilityCodeSnapshot() =>
            TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(m_grantedFormalGasAbilityCodes);

        public int[] CreateSuppressedFormalGasAbilityCodeSnapshot() =>
            TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(m_suppressedFormalGasAbilityCodes);

        public bool TryCreateAbilitySourceKey(DatabaseRegistry database, out CharacterAbilitySourceKey source)
        {
            source = default;
            if (!database)
            {
                return false;
            }

            if (!TryResolveRegisteredSourceId(database, out string sourceId))
            {
                return false;
            }

            source = new CharacterAbilitySourceKey(MapSourceKind(m_ruleKind), sourceId);
            return true;
        }

        public CharacterAlterationAbilityChangeResult ApplyAbilityChanges(CharacterBase target, DatabaseRegistry database)
        {
            if (!target || !TryCreateAbilitySourceKey(database, out CharacterAbilitySourceKey source))
            {
                return default;
            }

            int suppressedCount = 0;
            foreach (int formalGasAbilityCode in CreateSuppressedFormalGasAbilityCodeSnapshot())
            {
                if (target.AddSourcedFormalGasAbilitySuppression(formalGasAbilityCode, source))
                {
                    suppressedCount++;
                }
            }

            int grantedCount = 0;
            foreach (int formalGasAbilityCode in CreateGrantedFormalGasAbilityCodeSnapshot())
            {
                if (target.AddSourcedBonusFormalGasAbility(formalGasAbilityCode, source))
                {
                    grantedCount++;
                }
            }

            return new CharacterAlterationAbilityChangeResult(
                true,
                grantedCount,
                suppressedCount,
                0,
                0);
        }

        public CharacterAlterationAbilityChangeResult RemoveAbilityChanges(CharacterBase target, DatabaseRegistry database)
        {
            if (!target || !TryCreateAbilitySourceKey(database, out CharacterAbilitySourceKey source))
            {
                return default;
            }

            CharacterAbilitySourceRuntimeEntry[] removedGrantedAbilities = target.RemoveAllSourcedBonusAbilities(source);
            CharacterAbilitySourceRuntimeEntry[] removedSuppressions = target.RemoveAllSourcedAbilitySuppressions(source);

            return new CharacterAlterationAbilityChangeResult(
                true,
                0,
                0,
                removedGrantedAbilities.Length,
                removedSuppressions.Length);
        }

        public CharacterAlterationAbilityChangeResult RemoveAbilityChangeStack(CharacterBase target, DatabaseRegistry database)
        {
            if (!target || !TryCreateAbilitySourceKey(database, out CharacterAbilitySourceKey source))
            {
                return default;
            }

            int removedGrantedCount = 0;
            foreach (int formalGasAbilityCode in CreateGrantedFormalGasAbilityCodeSnapshot())
            {
                if (target.RemoveSourcedBonusFormalGasAbility(formalGasAbilityCode, source))
                {
                    removedGrantedCount++;
                }
            }

            int removedSuppressedCount = 0;
            foreach (int formalGasAbilityCode in CreateSuppressedFormalGasAbilityCodeSnapshot())
            {
                if (target.RemoveSourcedFormalGasAbilitySuppression(formalGasAbilityCode, source))
                {
                    removedSuppressedCount++;
                }
            }

            return new CharacterAlterationAbilityChangeResult(
                true,
                0,
                0,
                removedGrantedCount,
                removedSuppressedCount);
        }

        public bool ApplyNonAbilityChanges(CharacterBase target, DatabaseRegistry database)
        {
            if (!target || !TryCreateAbilitySourceKey(database, out CharacterAbilitySourceKey source))
            {
                return false;
            }

            if (m_lockedActions != EActionFlags.None)
            {
                target.ApplyAlterationActionLockRule(source, m_lockedActions);
            }

            if (m_lockPlayerControl || m_forceAIControl)
            {
                target.ApplyAlterationPlayerControlLockRule(source);
            }

            if (m_forceAIControl)
            {
                target.ApplyAlterationAIControlRule(source);
            }

            if (m_suppressEquipmentEffects)
            {
                target.ApplyAlterationEquipmentEffectSuppressionRule(source);
            }

            if (m_overrideAlignment)
            {
                target.ApplyAlterationAlignmentRule(source, m_alignmentOverride, m_priority);
            }

            return true;
        }

        public bool RemoveNonAbilityChanges(CharacterBase target, DatabaseRegistry database)
        {
            if (!target || !TryCreateAbilitySourceKey(database, out CharacterAbilitySourceKey source))
            {
                return false;
            }

            target.RemoveAllAlterationActionLockRules(source);
            target.RemoveAllAlterationPlayerControlLockRules(source);
            target.RemoveAllAlterationAIControlRules(source);
            target.RemoveAllAlterationEquipmentEffectSuppressionRules(source);
            target.RemoveAllAlterationAlignmentRules(source);
            return true;
        }

        public bool RemoveNonAbilityChangeStack(CharacterBase target, DatabaseRegistry database)
        {
            if (!target || !TryCreateAbilitySourceKey(database, out CharacterAbilitySourceKey source))
            {
                return false;
            }

            target.RemoveAlterationActionLockRuleStack(source);
            target.RemoveAlterationPlayerControlLockRuleStack(source);
            target.RemoveAlterationAIControlRuleStack(source);
            target.RemoveAlterationEquipmentEffectSuppressionRuleStack(source);
            target.RemoveAlterationAlignmentRuleStack(source);
            return true;
        }

        private static ECharacterAbilitySourceKind MapSourceKind(ECharacterAlterationRuleKind ruleKind)
        {
            return ruleKind switch
            {
                ECharacterAlterationRuleKind.Infection => ECharacterAbilitySourceKind.Infection,
                _ => ECharacterAbilitySourceKind.Transformation
            };
        }

        private bool TryResolveRegisteredSourceId(DatabaseRegistry database, out string sourceId)
        {
            sourceId = string.Empty;
            foreach (var entry in database.GetEntries())
            {
                if (entry.Value == this)
                {
                    sourceId = entry.Key;
                    return !string.IsNullOrEmpty(sourceId);
                }
            }

            return false;
        }
    }
}
