using System;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色变化规则类型。
    /// 用于把能力来源归入变形或感染等不同来源桶。
    /// </summary>
    public enum ECharacterAlterationRuleKind
    {
        Transformation,
        Infection
    }

    /// <summary>
    /// 同一角色变化规则重复生效时的叠加策略。
    /// </summary>
    public enum ECharacterAlterationStackingPolicy
    {
        Unique,
        Stackable
    }

    /// <summary>
    /// 角色变化规则对能力授予/压制产生的结果统计。
    /// 用于 UI、调试和自动化验证，不直接表示规则整体是否完成。
    /// </summary>
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

    /// <summary>
    /// 角色变形、感染或失控状态的规则资产。
    /// 它统一管理临时授予/压制能力、动作锁、AI 接管、装备效果压制和阵营覆盖。
    /// 规则本身不直接持有角色运行时状态；生效后由 CharacterBase 按来源键写入对应运行时容器。
    /// </summary>
    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Characters + nameof(CharacterAlterationRule))]
    public class CharacterAlterationRule : DatabaseEntry, INameable
    {
        [SerializeField]
        [LabelText("显示名称"), Tooltip("规则在 UI 或调试输出中的中文名称。为空时使用数据库条目名称兜底。")]
        private string m_displayName = string.Empty;
        [SerializeField]
        [LabelText("描述"), Tooltip("说明该变化状态对玩家或角色造成的影响。")]
        private string m_description = string.Empty;

        [Header("规则身份")]
        [SerializeField]
        [LabelText("规则类型"), Tooltip("规则类型决定来源键归入变形还是感染。丧尸化当前按感染类规则处理，后续如需要独立来源类型再单独裁决。")]
        private ECharacterAlterationRuleKind m_ruleKind = ECharacterAlterationRuleKind.Transformation;

        [SerializeField]
        [LabelText("叠加策略"), Tooltip("唯一规则同一角色只能激活一次；可叠层规则每次激活都会增加一层能力授予/压制来源。")]
        private ECharacterAlterationStackingPolicy m_stackingPolicy = ECharacterAlterationStackingPolicy.Unique;

        [SerializeField]
        [LabelText("互斥组 ID"), Tooltip("非空时，同组规则会按优先级互斥。用于狼人形态、丧尸阶段等同一身体状态只能保留一个胜出规则的场景。")]
        private string m_exclusiveGroupId = string.Empty;

        [SerializeField]
        [LabelText("优先级"), Tooltip("同一互斥组内，高优先级规则会保留；低优先级规则不能覆盖高优先级规则。")]
        private int m_priority;

        [SerializeField]
        [LabelText("授予能力编号"), Tooltip("规则生效期间临时授予角色的 EX-GAS Ability Code。正式技能必须填这里。")]
        private int[] m_grantedFormalGasAbilityCodes = Array.Empty<int>();

        [SerializeField]
        [LabelText("压制能力编号"), Tooltip("规则生效期间临时压制的 EX-GAS Ability Code。正式技能必须填这里。")]
        private int[] m_suppressedFormalGasAbilityCodes = Array.Empty<int>();

        [Header("控制变化")]
        [SerializeField]
        [LabelText("锁定动作"), Tooltip("规则生效期间锁定的角色动作。会影响玩家输入、AI 移动、能力权限、装备变更和主动背包操作。")]
        private EActionFlags m_lockedActions = EActionFlags.None;

        [SerializeField]
        [LabelText("锁定玩家控制"), Tooltip("勾选后，规则生效期间角色不能作为玩家当前控制对象。适用于丧尸化、失控变形或被精神控制等会夺走直接操控权的状态。")]
        private bool m_lockPlayerControl = false;

        [SerializeField]
        [LabelText("强制 AI 控制"), Tooltip("勾选后，规则生效期间尝试把角色切到同一角色上已配置的 AIController。它会同时锁定玩家直接控制；没有 AIController 时不会伪造第二套 AI。")]
        private bool m_forceAIControl = false;

        [SerializeField]
        [LabelText("压制装备效果"), Tooltip("勾选后，规则生效期间角色身上的装备属性和装备授予能力会暂时失效，但装备物品本身仍留在原槽位。")]
        private bool m_suppressEquipmentEffects = false;

        [SerializeField]
        [LabelText("覆盖阵营"), Tooltip("勾选后，规则生效期间临时覆盖角色阵营。感染、丧尸化或敌对变形可用它影响 AI 选敌和伤害判定。")]
        private bool m_overrideAlignment = false;

        [SerializeField]
        [LabelText("阵营覆盖值"), Tooltip("规则生效期间覆盖到的阵营。多条规则同时覆盖时按规则优先级裁决。")]
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

        /// <summary>
        /// 创建规则会临时授予的正式能力编号快照。
        /// 返回数组已经过滤无效值，调用方可以直接用于来源化能力授予。
        /// </summary>
        public int[] CreateGrantedFormalGasAbilityCodeSnapshot() =>
            TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(m_grantedFormalGasAbilityCodes);

        /// <summary>
        /// 创建规则会临时压制的正式能力编号快照。
        /// 返回数组已经过滤无效值，调用方可以直接用于来源化能力压制。
        /// </summary>
        public int[] CreateSuppressedFormalGasAbilityCodeSnapshot() =>
            TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(m_suppressedFormalGasAbilityCodes);

        /// <summary>
        /// 校验正式能力编号配置。
        /// 这里选择直接抛错，因为无效 ability code 会导致能力来源无法审计，不能静默当成空配置。
        /// </summary>
        public void EnsureFormalGasAbilityCodeConfiguration()
        {
            if (!TryValidateFormalGasAbilityCodeConfiguration(out string errorMessage))
            {
                throw new InvalidOperationException(errorMessage);
            }
        }

        /// <summary>
        /// 检查授予/压制能力编号是否都是有效正式 ability code。
        /// 返回 false 时会给出面向配置者的中文错误信息。
        /// </summary>
        public bool TryValidateFormalGasAbilityCodeConfiguration(out string errorMessage)
        {
            if (TryCreateInvalidFormalGasAbilityCodeMessage(
                    m_grantedFormalGasAbilityCodes,
                    "授予",
                    out errorMessage))
            {
                return false;
            }

            if (TryCreateInvalidFormalGasAbilityCodeMessage(
                    m_suppressedFormalGasAbilityCodes,
                    "压制",
                    out errorMessage))
            {
                return false;
            }

            errorMessage = string.Empty;
            return true;
        }

        /// <summary>
        /// 创建这条规则对应的稳定能力来源键。
        /// 来源 ID 来自数据库注册键，保证同一规则在存档、撤回和叠层恢复时能匹配到同一来源。
        /// </summary>
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

        /// <summary>
        /// 把规则里的能力授予和能力压制写入目标角色。
        /// 成功前提是规则可以解析出来源键；否则调用方不能安全地在后续撤回这些来源。
        /// </summary>
        public CharacterAlterationAbilityChangeResult ApplyAbilityChanges(CharacterBase target, DatabaseRegistry database)
        {
            if (!target || !TryCreateAbilitySourceKey(database, out CharacterAbilitySourceKey source))
            {
                return default;
            }

            EnsureFormalGasAbilityCodeConfiguration();

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

        /// <summary>
        /// 移除这条规则来源下的全部能力授予和压制。
        /// 用于整条规则退场、互斥组替换或角色重置，不关心当前叠层数。
        /// </summary>
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

        /// <summary>
        /// 移除这条规则来源下的一层能力授予和压制。
        /// 只用于可叠层规则的单层退场，避免把同来源剩余层数一次性清空。
        /// </summary>
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

        /// <summary>
        /// 把规则中的非能力效果写入目标角色。
        /// 动作锁、玩家控制锁、AI 接管、装备压制和阵营覆盖都通过同一个来源键落到 CharacterBase。
        /// </summary>
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

        /// <summary>
        /// 移除这条规则来源下的全部非能力效果。
        /// 整条规则失效时使用，确保动作锁、控制覆盖和阵营覆盖不会残留。
        /// </summary>
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

        /// <summary>
        /// 移除这条规则来源下的一层非能力效果。
        /// 对可叠层规则来说，只有最后一层退场后 CharacterBase 里的来源化规则才会真正归零。
        /// </summary>
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

        /// <summary>
        /// 把规则类型映射成能力来源类型。
        /// 未识别类型默认按 Transformation 处理，保持旧规则资产的兼容行为。
        /// </summary>
        private static ECharacterAbilitySourceKind MapSourceKind(ECharacterAlterationRuleKind ruleKind)
        {
            return ruleKind switch
            {
                ECharacterAlterationRuleKind.Infection => ECharacterAbilitySourceKind.Infection,
                _ => ECharacterAbilitySourceKind.Transformation
            };
        }

        /// <summary>
        /// 从数据库注册表反查这条规则的稳定来源 ID。
        /// 规则未登记时不能生成来源键，因为运行时无法保证读档和撤回命中同一来源。
        /// </summary>
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

        /// <summary>
        /// 生成无效正式能力编号的中文错误信息。
        /// 这里按数组位置报错，方便配置者直接定位是哪一项填了 0 或负数。
        /// </summary>
        private bool TryCreateInvalidFormalGasAbilityCodeMessage(
            int[] formalGasAbilityCodes,
            string operationName,
            out string errorMessage)
        {
            if (formalGasAbilityCodes != null)
            {
                for (int index = 0; index < formalGasAbilityCodes.Length; index++)
                {
                    if (formalGasAbilityCodes[index] > 0)
                    {
                        continue;
                    }

                    errorMessage =
                        $"[{nameof(CharacterAlterationRule)}] 角色变化规则 {displayName} 的{operationName}能力编号第 {index + 1} 项必须大于 0，" +
                        "不能把无效 Formal GAS 技能编码静默当成未配置。";
                    return true;
                }
            }

            errorMessage = string.Empty;
            return false;
        }
    }
}
