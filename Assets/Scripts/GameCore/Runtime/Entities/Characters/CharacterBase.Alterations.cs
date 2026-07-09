using System.Collections.Generic;
using System.Linq;

namespace FantasyWord.GameCore
{
    public abstract partial class CharacterBase
    {
        private readonly Dictionary<CharacterAlterationRule, int> m_activeAlterationRules = new();

        public bool ApplyCharacterAlterationRule(CharacterAlterationRule alterationRule)
        {
            return ApplyCharacterAlterationRule(alterationRule, GameManager.Database);
        }

        public bool ApplyCharacterAlterationRule(CharacterAlterationRule alterationRule, DatabaseRegistry database)
        {
            if (!alterationRule ||
                database == null ||
                !alterationRule.TryCreateAbilitySourceKey(database, out _))
            {
                return false;
            }

            if (m_activeAlterationRules.TryGetValue(alterationRule, out int currentStackCount) &&
                alterationRule.stackingPolicy != ECharacterAlterationStackingPolicy.Stackable)
            {
                return false;
            }

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

        public bool RemoveCharacterAlterationRule(CharacterAlterationRule alterationRule)
        {
            return RemoveCharacterAlterationRule(alterationRule, GameManager.Database);
        }

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

        public bool RemoveCharacterAlterationRuleStack(CharacterAlterationRule alterationRule)
        {
            return RemoveCharacterAlterationRuleStack(alterationRule, GameManager.Database);
        }

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

        internal DatabaseEntryReference<CharacterAlterationRule>[] CreateActiveAlterationRuleSnapshots()
        {
            if (m_activeAlterationRules.Count == 0)
            {
                return System.Array.Empty<DatabaseEntryReference<CharacterAlterationRule>>();
            }

            return m_activeAlterationRules
                .Where(entry => entry.Key != null && entry.Value > 0)
                .SelectMany(entry => Enumerable.Repeat(entry.Key, entry.Value))
                .Select(rule => GameManager.Database.CreateReference(rule))
                .ToArray();
        }

        internal void RestoreActiveAlterationRules(DatabaseEntryReference<CharacterAlterationRule>[] activeAlterationRules)
        {
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
                }
            }

            RevalidatePlayerControlEligibility();
        }

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

            if (conflictingRules.Any(rule => rule.priority > incomingRule.priority))
            {
                return false;
            }

            foreach (CharacterAlterationRule conflictingRule in conflictingRules)
            {
                RemoveCharacterAlterationRule(conflictingRule, database);
            }

            return true;
        }

        private void RevalidatePlayerControlEligibility()
        {
            if (!GameManager.Exists() || !GameManager.TryGetSystem<PlayerSystem>(out PlayerSystem playerSystem))
            {
                return;
            }

            playerSystem.RevalidateCurrentControlledCharacter();
        }
    }
}
