using System.Collections.Generic;
using System.Linq;

namespace FantasyWord.GameCore
{
    public abstract partial class CharacterBase
    {
        // 当前角色身上已经生效的变身/感染规则，以及每条规则的叠层数。
        // 字典只记录规则资产和层数；能力来源、动作锁、AI 接管等实际效果分别落到对应的运行时容器里。
        private readonly Dictionary<CharacterAlterationRule, int> m_activeAlterationRules = new();

        /// <summary>
        /// 使用全局数据库把一条变身/感染规则应用到角色身上。
        /// 入口用于普通运行时调用；测试或迁移流程需要指定数据库时走重载。
        /// </summary>
        public bool ApplyCharacterAlterationRule(CharacterAlterationRule alterationRule)
        {
            return ApplyCharacterAlterationRule(alterationRule, GameManager.Database);
        }

        /// <summary>
        /// 应用变身/感染规则，并同步授予/压制能力、非能力状态和玩家控制资格。
        /// 规则必须能解析出稳定来源键，否则无法在后续撤回、读档或叠层时匹配到同一来源。
        /// </summary>
        public bool ApplyCharacterAlterationRule(CharacterAlterationRule alterationRule, DatabaseRegistry database)
        {
            if (!alterationRule ||
                database == null ||
                !alterationRule.TryCreateAbilitySourceKey(database, out _))
            {
                return false;
            }

            alterationRule.EnsureFormalGasAbilityCodeConfiguration();

            // Unique 规则同一角色只能存在一层；Stackable 规则才允许重复叠加。
            if (m_activeAlterationRules.TryGetValue(alterationRule, out int currentStackCount) &&
                alterationRule.stackingPolicy != ECharacterAlterationStackingPolicy.Stackable)
            {
                return false;
            }

            // 互斥组先裁决优先级，再真正写入新规则，避免低优先级规则半应用后还要回滚。
            if (!TryRemoveLowerPriorityExclusiveAlterationRules(alterationRule, database))
            {
                return false;
            }

            CharacterAlterationAbilityChangeResult result = alterationRule.ApplyAbilityChanges(this, database);
            if (!result.SourceResolved)
            {
                return false;
            }

            alterationRule.ApplyNonAbilityChanges(this, database);
            m_activeAlterationRules[alterationRule] = currentStackCount + 1;
            RevalidatePlayerControlEligibility();
            return true;
        }

        /// <summary>
        /// 使用全局数据库移除整条变身/感染规则。
        /// 这会清掉该规则对应来源下的全部能力和非能力效果，不只移除一层叠层。
        /// </summary>
        public bool RemoveCharacterAlterationRule(CharacterAlterationRule alterationRule)
        {
            return RemoveCharacterAlterationRule(alterationRule, GameManager.Database);
        }

        /// <summary>
        /// 移除整条变身/感染规则。
        /// 适合规则被强制解除、互斥组被高优先级规则顶替，或角色重置时使用。
        /// </summary>
        public bool RemoveCharacterAlterationRule(CharacterAlterationRule alterationRule, DatabaseRegistry database)
        {
            if (!alterationRule || database == null)
            {
                return false;
            }

            bool wasActive = m_activeAlterationRules.Remove(alterationRule);
            CharacterAlterationAbilityChangeResult result = alterationRule.RemoveAbilityChanges(this, database);
            alterationRule.RemoveNonAbilityChanges(this, database);
            RevalidatePlayerControlEligibility();
            return wasActive || result.SourceResolved;
        }

        /// <summary>
        /// 使用全局数据库移除一层变身/感染规则叠层。
        /// 只有可叠层规则的单次退场应走这个入口。
        /// </summary>
        public bool RemoveCharacterAlterationRuleStack(CharacterAlterationRule alterationRule)
        {
            return RemoveCharacterAlterationRuleStack(alterationRule, GameManager.Database);
        }

        /// <summary>
        /// 移除一层变身/感染规则叠层。
        /// 当层数归零时才删除规则条目；能力来源和非能力状态也只撤回对应的一层。
        /// </summary>
        public bool RemoveCharacterAlterationRuleStack(CharacterAlterationRule alterationRule, DatabaseRegistry database)
        {
            if (!alterationRule ||
                database == null ||
                !m_activeAlterationRules.TryGetValue(alterationRule, out int currentStackCount) ||
                currentStackCount <= 0)
            {
                return false;
            }

            CharacterAlterationAbilityChangeResult result = alterationRule.RemoveAbilityChangeStack(this, database);
            if (!result.SourceResolved)
            {
                return false;
            }

            alterationRule.RemoveNonAbilityChangeStack(this, database);

            if (currentStackCount <= 1)
            {
                m_activeAlterationRules.Remove(alterationRule);
            }
            else
            {
                m_activeAlterationRules[alterationRule] = currentStackCount - 1;
            }

            RevalidatePlayerControlEligibility();
            return true;
        }

        /// <summary>
        /// 创建当前变身/感染规则的存档快照。
        /// 可叠层规则会按层数重复写入同一规则引用，读档时再逐条恢复，保持旧存档结构简单。
        /// </summary>
        internal DatabaseEntryReference<CharacterAlterationRule>[] CreateActiveAlterationRuleSnapshots()
        {
            if (m_activeAlterationRules.Count == 0)
            {
                return System.Array.Empty<DatabaseEntryReference<CharacterAlterationRule>>();
            }

            List<DatabaseEntryReference<CharacterAlterationRule>> snapshots = new();
            foreach ((CharacterAlterationRule rule, int stackCount) in m_activeAlterationRules)
            {
                if (!rule || stackCount <= 0)
                {
                    throw new System.InvalidOperationException(
                        $"[{nameof(CharacterBase)}] 当前角色存在无效变身/感染规则状态，不能把运行时状态保存成部分存档。");
                }

                for (int i = 0; i < stackCount; i++)
                {
                    snapshots.Add(GameManager.Database.CreateReference(rule));
                }
            }

            return snapshots.ToArray();
        }

        /// <summary>
        /// 从存档引用恢复变身/感染规则的非能力效果和叠层状态。
        /// 能力来源已由正式能力来源快照恢复，这里只重建动作锁、控制锁、装备压制和阵营覆盖等非能力部分。
        /// </summary>
        internal void RestoreActiveAlterationRules(DatabaseEntryReference<CharacterAlterationRule>[] activeAlterationRules)
        {
            // 读档前先清掉旧非能力效果，避免对象复用时残留上一个存档或场景状态。
            m_activeAlterationRules.Clear();
            ClearAlterationActionLockRules();
            ClearAlterationPlayerControlLockRules();
            ClearAlterationAIControlRules();
            ClearAlterationEquipmentEffectSuppressionRules();
            ClearAlterationAlignmentRules();
            if (activeAlterationRules == null)
            {
                RevalidatePlayerControlEligibility();
                return;
            }

            foreach (DatabaseEntryReference<CharacterAlterationRule> alterationRuleReference in activeAlterationRules)
            {
                if (alterationRuleReference == null)
                {
                    continue;
                }

                CharacterAlterationRule alterationRule = GameManager.Database.LoadFromReference(alterationRuleReference);
                if (alterationRule)
                {
                    alterationRule.ApplyNonAbilityChanges(this, GameManager.Database);
                    m_activeAlterationRules.TryGetValue(alterationRule, out int currentStackCount);
                    m_activeAlterationRules[alterationRule] = currentStackCount + 1;
                    continue;
                }

                UnityEngine.Debug.LogError($"[{nameof(CharacterBase)}] 存档中的变身/感染规则 GUID 无法解析，已跳过：{alterationRuleReference.guid}", this);
            }

            RevalidatePlayerControlEligibility();
        }

        /// <summary>
        /// 清空所有变身/感染运行时状态。
        /// 用于角色卸载、重置或存档恢复前的基线清理，必须同步清理所有非能力派生效果。
        /// </summary>
        internal void ClearActiveAlterationRules()
        {
            m_activeAlterationRules.Clear();
            ClearAlterationActionLockRules();
            ClearAlterationPlayerControlLockRules();
            ClearAlterationAIControlRules();
            ClearAlterationEquipmentEffectSuppressionRules();
            ClearAlterationAlignmentRules();
            RevalidatePlayerControlEligibility();
        }

        private bool TryRemoveLowerPriorityExclusiveAlterationRules(
            CharacterAlterationRule incomingRule,
            DatabaseRegistry database)
        {
            if (string.IsNullOrWhiteSpace(incomingRule.exclusiveGroupId))
            {
                return true;
            }

            CharacterAlterationRule[] conflictingRules = m_activeAlterationRules.Keys
                .Where(rule => rule != null &&
                    rule != incomingRule &&
                    string.Equals(rule.exclusiveGroupId, incomingRule.exclusiveGroupId, System.StringComparison.Ordinal))
                .ToArray();

            // 已有高优先级规则时，新规则不能覆盖，调用方会把本次应用视为失败。
            if (conflictingRules.Any(rule => rule.priority > incomingRule.priority))
            {
                return false;
            }

            // 同组低优先级或同优先级规则会先整条退场，再让新规则接管该互斥组。
            foreach (CharacterAlterationRule conflictingRule in conflictingRules)
            {
                RemoveCharacterAlterationRule(conflictingRule, database);
            }

            return true;
        }

        /// <summary>
        /// 变身/感染可能夺走或恢复玩家控制权，所有写入入口结束后都要刷新玩家系统当前控制对象。
        /// </summary>
        private void RevalidatePlayerControlEligibility()
        {
            GameManager.PlayerSystem.RevalidateCurrentControlledCharacter();
        }
    }
}
