using System;
using System.Collections.Generic;
using System.Linq;
using GAS.Runtime;
using UnityEngine;
using UnityEngine.Events;

namespace FantasyWord.GameCore
{
    public abstract partial class CharacterBase
    {
        private readonly UnityEvent<CharacterBase> m_provoked = new();
        private readonly UnityEvent<Stats> m_statsChanged = new();
        private readonly UnityEvent<Stats> m_currentStatsChanged = new();
        private readonly UnityEvent<int> m_levelUpped = new();
        private readonly UnityEvent<CharacterTemporalEffectPresentationSnapshot> m_temporalEffectPresentationAdded = new();
        private readonly UnityEvent<CharacterTemporalEffectPresentationSnapshot> m_temporalEffectPresentationRemoved = new();
        private readonly Dictionary<CharacterAbilitySourceKey, CharacterAlignmentOverrideRuntimeEntry> m_alterationAlignmentOverrides = new();
        private readonly Dictionary<CharacterAbilitySourceKey, int> m_alterationPlayerControlLocks = new();
        private readonly Dictionary<CharacterAbilitySourceKey, int> m_alterationAIControlOverrides = new();

        private readonly struct CharacterAlignmentOverrideRuntimeEntry
        {
            public CharacterAlignmentOverrideRuntimeEntry(EAlignment alignment, int priority, int stackCount)
            {
                Alignment = alignment;
                Priority = priority;
                StackCount = stackCount;
            }

            public EAlignment Alignment { get; }
            public int Priority { get; }
            public int StackCount { get; }
        }

        public int Cleanse(params EEffectType[] effectTypes)
        {
            return CleanseOwnedTemporalEffects(effectTypes);
        }

        public void AddProvokedListener(UnityAction<CharacterBase> listener)
        {
            m_provoked.AddListener(listener);
        }

        public void RemoveProvokedListener(UnityAction<CharacterBase> listener)
        {
            m_provoked.RemoveListener(listener);
        }

        public void AddTemporalEffectPresentationAddedListener(UnityAction<CharacterTemporalEffectPresentationSnapshot> listener)
        {
            m_temporalEffectPresentationAdded.AddListener(listener);
        }

        public void RemoveTemporalEffectPresentationAddedListener(UnityAction<CharacterTemporalEffectPresentationSnapshot> listener)
        {
            m_temporalEffectPresentationAdded.RemoveListener(listener);
        }

        public void AddTemporalEffectPresentationRemovedListener(UnityAction<CharacterTemporalEffectPresentationSnapshot> listener)
        {
            m_temporalEffectPresentationRemoved.AddListener(listener);
        }

        public void RemoveTemporalEffectPresentationRemovedListener(UnityAction<CharacterTemporalEffectPresentationSnapshot> listener)
        {
            m_temporalEffectPresentationRemoved.RemoveListener(listener);
        }

        public void AddLevelUppedListener(UnityAction<int> listener)
        {
            m_levelUpped.AddListener(listener);
        }

        public void RemoveLevelUppedListener(UnityAction<int> listener)
        {
            m_levelUpped.RemoveListener(listener);
        }

        /// <summary>
        /// 当前阶段把基础属性/当前属性通知重新收回角色正式拥有者。
        /// UI 和死亡链只允许订阅 CharacterBase，不再把属性启动缓冲当现役通知真相。
        /// </summary>
        private void NotifyBaseStatsChanged(Stats previousStats)
        {
            m_statsChanged.Invoke(previousStats ?? new Stats());
        }

        private void NotifyCurrentStatsChanged(Stats previousStats)
        {
            Stats safePreviousStats = previousStats ?? new Stats();
            m_currentStatsChanged.Invoke(safePreviousStats);

            if (DidReachZeroHealth(safePreviousStats))
            {
                Kill();
            }
        }

        private void PublishStatChanges(Stats previousBaseStats, Stats previousCurrentStats)
        {
            Stats safePreviousBaseStats = previousBaseStats ?? new Stats();
            Stats safePreviousCurrentStats = previousCurrentStats ?? new Stats();

            if (!AreStatsEqual(safePreviousBaseStats, CreateStatsSnapshot()))
            {
                NotifyBaseStatsChanged(safePreviousBaseStats);
            }

            if (!AreStatsEqual(safePreviousCurrentStats, CreateCurrentStatsSnapshot()))
            {
                NotifyCurrentStatsChanged(safePreviousCurrentStats);
            }
        }

        private bool DidReachZeroHealth(Stats previousStats)
        {
            return previousStats != null && previousStats[EStat.Health] > 0 && GetCurrentHealth() == 0;
        }

        private static bool AreStatsEqual(Stats a, Stats b)
        {
            if (ReferenceEquals(a, b))
            {
                return true;
            }

            if (a == null || b == null)
            {
                return false;
            }

            foreach (FormalAttributeDefinition definition in FormalAttributeCatalog.Definitions)
            {
                if (a[definition.Stat] != b[definition.Stat])
                {
                    return false;
                }
            }

            return true;
        }

        public void AddTemporalEffect(ITemporalEffect effect)
        {
            ITemporalEffect replacedEffect = RegisterOwnedTemporalEffect(effect);
            FinalizeOwnedTemporalEffects(replacedEffect);

            CharacterTemporalEffectPresentationSnapshot snapshot = CreateTemporalEffectPresentationSnapshotCore(effect);
            NotifyTemporalEffectPresentationAdded(snapshot);
            NotifyTemporalEffectPresentation(snapshot, effect != null ? effect.visualFlags : EEffectVisualFlags.None);
        }

        public bool TryConsumeTemporalEffect(ITemporalEffect effect)
        {
            return TryConsumeTemporalEffectStackFromRegisteredEffects(effect);
        }

        /// <summary>
        /// 未映射到 formal stacking 的 effect 叠层仍要扫描当前已登记 runtime。
        /// 这里直接消费当前 key 快照，避免调用方先展开对象数组再回查注册表。
        /// </summary>
        private bool TryConsumeTemporalEffectStackFromRegisteredEffects(ITemporalEffect effect)
        {
            if (effect == null)
            {
                return false;
            }

            foreach (int runtimeKey in GetOwnedTemporalEffectRuntimeKeySnapshot())
            {
                if (!TryGetOwnedTemporalEffect(runtimeKey, out ITemporalEffect targetEffect) ||
                    targetEffect == null ||
                    !targetEffect.TryStack(effect))
                {
                    continue;
                }
                return true;
            }

            return false;
        }

        public string ApplyMoveSpeedFactor(float factor)
        {
            return m_actionRuntime.ApplyMoveSpeedFactor(factor);
        }

        /// <summary>
        /// 持续效果派生的移速修饰现在统一由角色拥有者按 effect runtimeKey 持有。
        /// 旧 effect 不再自己保存一份不透明 handle key，读档恢复也回到这条正式入口。
        /// </summary>
        public void ApplyTemporalMoveSpeedRule(int runtimeKey, float factor)
        {
            try
            {
                m_actionRuntime.ApplyTemporalEffectMoveSpeedFactor(runtimeKey, factor);
            }
            catch (InvalidOperationException exception)
            {
                Debug.Assert(false, exception.Message);
            }
        }

        public void UpdateTemporalMoveSpeedRule(int runtimeKey, float factor)
        {
            try
            {
                m_actionRuntime.UpdateTemporalEffectMoveSpeedFactor(runtimeKey, factor);
            }
            catch (InvalidOperationException exception)
            {
                Debug.Assert(false, exception.Message);
            }
        }

        public void RemoveTemporalMoveSpeedRule(int runtimeKey)
        {
            try
            {
                m_actionRuntime.RemoveTemporalEffectMoveSpeedFactor(runtimeKey);
            }
            catch (InvalidOperationException exception)
            {
                Debug.Assert(false, exception.Message);
            }
        }

        public void UpdateMoveSpeedFactor(string key, float factor)
        {
            try
            {
                m_actionRuntime.UpdateMoveSpeedFactor(key, factor);
            }
            catch (InvalidOperationException exception)
            {
                Debug.Assert(false, exception.Message);
            }
        }

        public void RemoveMoveSpeedFactor(string key)
        {
            try
            {
                m_actionRuntime.RemoveMoveSpeedFactor(key);
            }
            catch (InvalidOperationException exception)
            {
                Debug.Assert(false, exception.Message);
            }
        }

        public string LockActions(EActionFlags actions)
        {
            return m_actionRuntime.LockActions(actions);
        }

        public void ApplyAlterationActionLockRule(CharacterAbilitySourceKey source, EActionFlags actions)
        {
            m_actionRuntime.ApplyAlterationRuleActionLock(source, actions);
        }

        public void RemoveAlterationActionLockRuleStack(CharacterAbilitySourceKey source)
        {
            m_actionRuntime.RemoveAlterationRuleActionLockStack(source);
        }

        public void RemoveAllAlterationActionLockRules(CharacterAbilitySourceKey source)
        {
            m_actionRuntime.RemoveAllAlterationRuleActionLocks(source);
        }

        internal void ClearAlterationActionLockRules()
        {
            m_actionRuntime.ClearAlterationRuleActionLocks();
        }

        public void ApplyAlterationPlayerControlLockRule(CharacterAbilitySourceKey source)
        {
            m_alterationPlayerControlLocks.TryGetValue(source, out int currentStackCount);
            m_alterationPlayerControlLocks[source] = currentStackCount + 1;
        }

        public void RemoveAlterationPlayerControlLockRuleStack(CharacterAbilitySourceKey source)
        {
            if (!m_alterationPlayerControlLocks.TryGetValue(source, out int currentStackCount))
            {
                return;
            }

            int nextStackCount = currentStackCount - 1;
            if (nextStackCount <= 0)
            {
                m_alterationPlayerControlLocks.Remove(source);
                return;
            }

            m_alterationPlayerControlLocks[source] = nextStackCount;
        }

        public void RemoveAllAlterationPlayerControlLockRules(CharacterAbilitySourceKey source)
        {
            m_alterationPlayerControlLocks.Remove(source);
        }

        internal void ClearAlterationPlayerControlLockRules()
        {
            m_alterationPlayerControlLocks.Clear();
        }

        public void ApplyAlterationAIControlRule(CharacterAbilitySourceKey source)
        {
            m_alterationAIControlOverrides.TryGetValue(source, out int currentStackCount);
            m_alterationAIControlOverrides[source] = currentStackCount + 1;
            RefreshAlterationControllerOverride();
        }

        public void RemoveAlterationAIControlRuleStack(CharacterAbilitySourceKey source)
        {
            if (!m_alterationAIControlOverrides.TryGetValue(source, out int currentStackCount))
            {
                return;
            }

            int nextStackCount = currentStackCount - 1;
            if (nextStackCount <= 0)
            {
                m_alterationAIControlOverrides.Remove(source);
            }
            else
            {
                m_alterationAIControlOverrides[source] = nextStackCount;
            }

            RefreshAlterationControllerOverride();
        }

        public void RemoveAllAlterationAIControlRules(CharacterAbilitySourceKey source)
        {
            m_alterationAIControlOverrides.Remove(source);
            RefreshAlterationControllerOverride();
        }

        internal void ClearAlterationAIControlRules()
        {
            m_alterationAIControlOverrides.Clear();
            RefreshAlterationControllerOverride();
        }

        public bool CanBePlayerControlled()
        {
            return !dead && !HasAlterationPlayerControlLock();
        }

        public virtual void ApplyAlterationEquipmentEffectSuppressionRule(CharacterAbilitySourceKey source)
        {
            if (TryGetComponent(out CharacterEquipment equipmentComponent) && equipmentComponent != null)
            {
                equipmentComponent.ApplyAlterationEquipmentEffectSuppressionRule(source);
            }
        }

        public virtual void RemoveAlterationEquipmentEffectSuppressionRuleStack(CharacterAbilitySourceKey source)
        {
            if (TryGetComponent(out CharacterEquipment equipmentComponent) && equipmentComponent != null)
            {
                equipmentComponent.RemoveAlterationEquipmentEffectSuppressionRuleStack(source);
            }
        }

        public virtual void RemoveAllAlterationEquipmentEffectSuppressionRules(CharacterAbilitySourceKey source)
        {
            if (TryGetComponent(out CharacterEquipment equipmentComponent) && equipmentComponent != null)
            {
                equipmentComponent.RemoveAllAlterationEquipmentEffectSuppressionRules(source);
            }
        }

        internal virtual void ClearAlterationEquipmentEffectSuppressionRules()
        {
            if (TryGetComponent(out CharacterEquipment equipmentComponent) && equipmentComponent != null)
            {
                equipmentComponent.ClearAlterationEquipmentEffectSuppressionRules();
            }
        }

        private bool HasAlterationPlayerControlLock()
        {
            foreach (int stackCount in m_alterationPlayerControlLocks.Values)
            {
                if (stackCount > 0)
                {
                    return true;
                }
            }

            return false;
        }

        private bool HasAlterationAIControlOverride()
        {
            foreach (int stackCount in m_alterationAIControlOverrides.Values)
            {
                if (stackCount > 0)
                {
                    return true;
                }
            }

            return false;
        }

        private void RefreshAlterationControllerOverride()
        {
            if (HasAlterationAIControlOverride())
            {
                TryActivateController<AIController>();
                return;
            }

            ClearControllerOverride<AIController>();
        }

        public void ApplyAlterationAlignmentRule(CharacterAbilitySourceKey source, EAlignment alignment, int priority)
        {
            m_alterationAlignmentOverrides.TryGetValue(source, out CharacterAlignmentOverrideRuntimeEntry currentEntry);
            m_alterationAlignmentOverrides[source] = new CharacterAlignmentOverrideRuntimeEntry(
                alignment,
                priority,
                currentEntry.StackCount + 1);
        }

        public void RemoveAlterationAlignmentRuleStack(CharacterAbilitySourceKey source)
        {
            if (!m_alterationAlignmentOverrides.TryGetValue(source, out CharacterAlignmentOverrideRuntimeEntry currentEntry))
            {
                return;
            }

            int nextStackCount = currentEntry.StackCount - 1;
            if (nextStackCount <= 0)
            {
                m_alterationAlignmentOverrides.Remove(source);
                return;
            }

            m_alterationAlignmentOverrides[source] = new CharacterAlignmentOverrideRuntimeEntry(
                currentEntry.Alignment,
                currentEntry.Priority,
                nextStackCount);
        }

        public void RemoveAllAlterationAlignmentRules(CharacterAbilitySourceKey source)
        {
            m_alterationAlignmentOverrides.Remove(source);
        }

        internal void ClearAlterationAlignmentRules()
        {
            m_alterationAlignmentOverrides.Clear();
        }

        private bool TryResolveAlterationAlignmentOverride(out EAlignment alignment)
        {
            alignment = default;
            bool hasResolvedAlignment = false;
            CharacterAbilitySourceKey resolvedSource = default;
            int resolvedPriority = int.MinValue;

            foreach ((CharacterAbilitySourceKey source, CharacterAlignmentOverrideRuntimeEntry entry) in m_alterationAlignmentOverrides)
            {
                if (entry.StackCount <= 0)
                {
                    continue;
                }

                if (!hasResolvedAlignment ||
                    entry.Priority > resolvedPriority ||
                    (entry.Priority == resolvedPriority && CompareAlignmentOverrideSource(source, resolvedSource) < 0))
                {
                    alignment = entry.Alignment;
                    resolvedPriority = entry.Priority;
                    resolvedSource = source;
                    hasResolvedAlignment = true;
                }
            }

            return hasResolvedAlignment;
        }

        private static int CompareAlignmentOverrideSource(CharacterAbilitySourceKey a, CharacterAbilitySourceKey b)
        {
            int kindComparison = ((int)a.Kind).CompareTo((int)b.Kind);
            return kindComparison != 0
                ? kindComparison
                : string.Compare(a.SourceId, b.SourceId, StringComparison.Ordinal);
        }

        /// <summary>
        /// 持续效果派生的动作锁现在统一由角色拥有者按 effect runtimeKey 持有。
        /// 这样动作锁恢复主键与 formal temporal effect 实例键保持一致，不再散落在各效果私有字段里。
        /// </summary>
        public void ApplyTemporalActionLockRule(int runtimeKey, EActionFlags actions)
        {
            try
            {
                m_actionRuntime.ApplyTemporalEffectActionLock(runtimeKey, actions);
            }
            catch (InvalidOperationException exception)
            {
                Debug.Assert(false, exception.Message);
            }
        }

        public void RemoveTemporalActionLockRule(int runtimeKey)
        {
            try
            {
                m_actionRuntime.RemoveTemporalEffectActionLock(runtimeKey);
            }
            catch (InvalidOperationException exception)
            {
                Debug.Assert(false, exception.Message);
            }
        }

        public void UnlockActions(string key)
        {
            try
            {
                m_actionRuntime.UnlockActions(key);
            }
            catch (InvalidOperationException exception)
            {
                Debug.Assert(false, exception.Message);
            }
        }

        public bool IsActionLocked(EActionFlags actions)
        {
            return m_actionRuntime.IsActionLocked(actions) || HasFormalActionLock(actions);
        }

        public void EnableActions(EActionFlags actions)
        {
            m_actionRuntime.EnableActions(actions);
        }

        public void DisableActions(EActionFlags actions)
        {
            m_actionRuntime.DisableActions(actions);
        }

        public bool Can(EActionFlags actions)
        {
            return m_actionRuntime.Can(actions) && !HasFormalActionLock(actions);
        }

        private bool HasFormalActionLock(EActionFlags actions)
        {
            if (!TryGetFormalAbilitySystem(out AbilitySystemComponent abilitySystemComponent) ||
                abilitySystemComponent == null)
            {
                return false;
            }

            if ((actions.HasFlag(EActionFlags.Move) ||
                 actions.HasFlag(EActionFlags.UseAbility) ||
                 actions.HasFlag(EActionFlags.UpdateTargetDirection)) &&
                abilitySystemComponent.HasTag(FormalGameplayTagCatalog.AttackingEvent.TagCode))
            {
                return true;
            }

            // 控制效果的禁用语义现在优先看 formal GameplayTag，而不是再让执行壳长期镜像一份动作锁。
            if (actions.HasFlag(EActionFlags.Move) &&
                (abilitySystemComponent.HasTag(FormalGameplayTagCatalog.StunControlEffect.TagCode) ||
                 abilitySystemComponent.HasTag(FormalGameplayTagCatalog.RootControlEffect.TagCode)))
            {
                return true;
            }

            if (actions.HasFlag(EActionFlags.UseAbility) &&
                (abilitySystemComponent.HasTag(FormalGameplayTagCatalog.StunControlEffect.TagCode) ||
                 abilitySystemComponent.HasTag(FormalGameplayTagCatalog.SilenceControlEffect.TagCode)))
            {
                return true;
            }

            if (actions.HasFlag(EActionFlags.UpdateTargetDirection) &&
                abilitySystemComponent.HasTag(FormalGameplayTagCatalog.StunControlEffect.TagCode))
            {
                return true;
            }

            return false;
        }

        public void FlagAsSummoned()
        {
            m_isSummoned = true;
        }

        public void SetAlignmentOverride(EAlignment? alignment)
        {
            m_alignmentOverride = alignment;
        }

        public CharacterTemporalEffectPresentationSnapshot[] GetTemporalEffectPresentationSnapshots()
        {
            int[] runtimeKeySnapshot = GetOwnedTemporalEffectRuntimeKeySnapshot();
            return CreateTemporalEffectPresentationSnapshots(runtimeKeySnapshot);
        }

        private void NotifyTemporalEffectPresentationAdded(CharacterTemporalEffectPresentationSnapshot snapshot)
        {
            if (!snapshot.HasPresentation)
            {
                return;
            }

            m_temporalEffectPresentationAdded.Invoke(snapshot);
        }

        private void NotifyTemporalEffectPresentationRemoved(ITemporalEffect effect)
        {
            if (effect == null)
            {
                return;
            }

            CharacterTemporalEffectPresentationSnapshot snapshot = CreateTemporalEffectPresentationSnapshotCore(effect);
            if (!snapshot.HasPresentation && effect.runtimeKey > 0)
            {
                snapshot = new CharacterTemporalEffectPresentationSnapshot(
                    effect.runtimeKey,
                    true,
                    default,
                    default,
                    string.Empty);
            }

            if (snapshot.HasPresentation)
            {
                m_temporalEffectPresentationRemoved.Invoke(snapshot);
            }
        }

        private void NotifyTemporalEffectPresentation(
            CharacterTemporalEffectPresentationSnapshot snapshot,
            EEffectVisualFlags visualFlags)
        {
            if (!snapshot.HasPresentation)
            {
                return;
            }

            GameRuntimeEvents.NotifyTemporalEffectPresentation(
                new TemporalEffectPresentationContext(
                    transform.position,
                    this,
                    snapshot,
                    visualFlags));
        }

        /// <summary>
        /// 持续效果每帧推进与完成裁决现在统一回到角色拥有者。
        /// 运行时注册表只回答“当前还登记着哪些 effect”，不再替 CharacterBase 决定什么时候推进、什么时候完成退场。
        /// </summary>
        private void AdvanceOwnedTemporalEffects(float deltaTime)
        {
            HashSet<int> completedRuntimeKeys = new();

            foreach (int runtimeKey in GetOwnedTemporalEffectRuntimeKeySnapshot())
            {
                if (!TryGetOwnedTemporalEffect(runtimeKey, out ITemporalEffect effect) ||
                    effect == null)
                {
                    continue;
                }

                AdvanceOwnedTemporalEffect(effect, deltaTime);

                if (effect.completed &&
                    IsCurrentOwnedTemporalEffect(effect))
                {
                    completedRuntimeKeys.Add(runtimeKey);
                }
            }

            FinalizeOwnedTemporalEffects(
                RemoveOwnedTemporalEffectsByRuntimeKeySnapshot(completedRuntimeKeys.ToArray()));
        }

        private static void AdvanceOwnedTemporalEffect(ITemporalEffect effect, float deltaTime)
        {
            if (effect == null)
            {
                return;
            }

            TemporalEffectRuntimeTraits traits = effect.GetRuntimeTraits();
            if (traits.HasFlag(TemporalEffectRuntimeTraits.NeedsTickCallbacks))
            {
                effect.Update(deltaTime);
                return;
            }

            if (traits.HasFlag(TemporalEffectRuntimeTraits.NeedsLocalLifetimeAdvance))
            {
                effect.AdvanceRuntimeLifetime(Mathf.Max(0.0f, deltaTime));
            }
        }

        /// <summary>
        /// 持续效果执行壳当前只负责注册表增删与查询。
        /// 真正的完成、副作用回滚、展示移除和 formal spec 注销统一由角色拥有者收尾，
        /// 避免旧 helper 继续兼任角色级生命周期协调者。
        /// </summary>
        private void FinalizeOwnedTemporalEffects(params ITemporalEffect[] effects)
        {
            if (effects == null)
            {
                return;
            }

            HashSet<ITemporalEffect> finalizedEffects = new();
            foreach (ITemporalEffect effect in effects)
            {
                if (effect == null || !finalizedEffects.Add(effect))
                {
                    continue;
                }

                effect.Complete();
                NotifyTemporalEffectPresentationRemoved(effect);
            }
        }

        private static CharacterTemporalEffectPresentationSnapshot CreateTemporalEffectPresentationSnapshotCore(ITemporalEffect effect)
        {
            // 展示和分类现在分别读取最小合同，避免共享对象继续混着两类语义。
            if (effect is not ATemporalEffect temporalEffect ||
                !temporalEffect.TryGetPresentationEffectType(out EEffectType effectType) ||
                !temporalEffect.TryGetPresentationState(out TemporalEffectPresentationState presentationState))
            {
                return default;
            }

            return new CharacterTemporalEffectPresentationSnapshot(
                effect.runtimeKey,
                true,
                effectType,
                presentationState.info,
                presentationState.details);
        }

        /// <summary>
        /// CharacterBase 自己决定哪些 effect 需要投影成 UI 快照。
        /// </summary>
        private CharacterTemporalEffectPresentationSnapshot[] CreateTemporalEffectPresentationSnapshots(
            int[] runtimeKeySnapshot)
        {
            if (runtimeKeySnapshot == null)
            {
                return Array.Empty<CharacterTemporalEffectPresentationSnapshot>();
            }

            List<CharacterTemporalEffectPresentationSnapshot> snapshots = new();
            foreach (int runtimeKey in runtimeKeySnapshot)
            {
                if (!TryGetOwnedTemporalEffect(runtimeKey, out ITemporalEffect effect) ||
                    effect == null)
                {
                    continue;
                }

                CharacterTemporalEffectPresentationSnapshot snapshot = CreateTemporalEffectPresentationSnapshotCore(effect);
                if (snapshot.HasPresentation)
                {
                    snapshots.Add(snapshot);
                }
            }

            return snapshots.ToArray();
        }

    }
}
