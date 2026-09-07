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
        // 受到有效伤害时通知攻击来源，供 AI 仇恨、任务或表现层订阅。
        private readonly UnityEvent<CharacterBase> m_provoked = new();

        // 基础属性变化事件。参数是变化前快照，订阅者可自行和当前值比较。
        private readonly UnityEvent<Stats> m_statsChanged = new();

        // 当前属性变化事件。生命归零的延迟死亡请求也从这条链路触发。
        private readonly UnityEvent<Stats> m_currentStatsChanged = new();

        // 等级变化事件，参数是升级后的等级。
        private readonly UnityEvent<int> m_levelUpped = new();

        // 持续效果展示新增/移除事件只传展示快照，不暴露 effect 实例本体。
        private readonly UnityEvent<CharacterTemporalEffectPresentationSnapshot> m_temporalEffectPresentationAdded = new();
        private readonly UnityEvent<CharacterTemporalEffectPresentationSnapshot> m_temporalEffectPresentationRemoved = new();

        // 来源化阵营覆盖。priority 决定同一角色同时被多个规则影响时谁赢。
        private readonly Dictionary<CharacterAbilitySourceKey, CharacterAlignmentOverrideRuntimeEntry> m_alterationAlignmentOverrides = new();

        // 来源化玩家控制锁。只影响玩家输入资格，不直接启停 AIController。
        private readonly Dictionary<CharacterAbilitySourceKey, int> m_alterationPlayerControlLocks = new();

        // 来源化 AI 控制覆盖。存在任意叠层时激活 AIController，移除后清理覆盖。
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

        /// <summary>
        /// 清除指定展示类型的持续效果。
        /// 具体匹配和移除由正式持续效果运行时处理，返回实际清除数量。
        /// </summary>
        public int Cleanse(params EEffectType[] effectTypes)
        {
            return CleanseOwnedTemporalEffects(effectTypes);
        }

        /// <summary>订阅角色被攻击来源激怒事件。</summary>
        public void AddProvokedListener(UnityAction<CharacterBase> listener)
        {
            m_provoked.AddListener(listener);
        }

        /// <summary>取消订阅角色被攻击来源激怒事件。</summary>
        public void RemoveProvokedListener(UnityAction<CharacterBase> listener)
        {
            m_provoked.RemoveListener(listener);
        }

        /// <summary>订阅持续效果展示新增事件。</summary>
        public void AddTemporalEffectPresentationAddedListener(UnityAction<CharacterTemporalEffectPresentationSnapshot> listener)
        {
            m_temporalEffectPresentationAdded.AddListener(listener);
        }

        /// <summary>取消订阅持续效果展示新增事件。</summary>
        public void RemoveTemporalEffectPresentationAddedListener(UnityAction<CharacterTemporalEffectPresentationSnapshot> listener)
        {
            m_temporalEffectPresentationAdded.RemoveListener(listener);
        }

        /// <summary>订阅持续效果展示移除事件。</summary>
        public void AddTemporalEffectPresentationRemovedListener(UnityAction<CharacterTemporalEffectPresentationSnapshot> listener)
        {
            m_temporalEffectPresentationRemoved.AddListener(listener);
        }

        /// <summary>取消订阅持续效果展示移除事件。</summary>
        public void RemoveTemporalEffectPresentationRemovedListener(UnityAction<CharacterTemporalEffectPresentationSnapshot> listener)
        {
            m_temporalEffectPresentationRemoved.RemoveListener(listener);
        }

        /// <summary>订阅角色升级事件。</summary>
        public void AddLevelUppedListener(UnityAction<int> listener)
        {
            m_levelUpped.AddListener(listener);
        }

        /// <summary>取消订阅角色升级事件。</summary>
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

        /// <summary>
        /// 发布当前属性变化。
        /// 生命从正数变为 0 时，只请求延迟死亡，避免在属性写入回调栈里直接进入死亡流程。
        /// </summary>
        private void NotifyCurrentStatsChanged(Stats previousStats)
        {
            Stats safePreviousStats = previousStats ?? new Stats();
            m_currentStatsChanged.Invoke(safePreviousStats);

            if (DidReachZeroHealth(safePreviousStats))
            {
                RequestDeathAfterFormalCurrentValueMutation();
            }
        }

        /// <summary>
        /// 对比并发布基础/当前属性变化。
        /// 参数必须是变化前快照，这样订阅者可以自行计算差值。
        /// </summary>
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

        /// <summary>
        /// 判断生命是否刚刚归零。
        /// 只有从正数降到 0 才触发死亡请求，避免读档或重复通知反复排队死亡。
        /// </summary>
        private bool DidReachZeroHealth(Stats previousStats)
        {
            return previousStats != null && previousStats[EStat.Health] > 0 && GetCurrentHealth() == 0;
        }

        /// <summary>
        /// 比较两份正式属性快照。
        /// 只比较 FormalAttributeCatalog 中登记的属性，避免旧 Stats 容器里的杂项字段影响发布判断。
        /// </summary>
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

        /// <summary>
        /// 添加一个持续效果到角色拥有者。
        /// 若注册表返回被替换的旧效果，会先完成旧效果，再发布新效果展示。
        /// </summary>
        public void AddTemporalEffect(ITemporalEffect effect)
        {
            ITemporalEffect replacedEffect = RegisterOwnedTemporalEffect(effect);
            FinalizeOwnedTemporalEffects(replacedEffect);

            CharacterTemporalEffectPresentationSnapshot snapshot = CreateTemporalEffectPresentationSnapshotCore(effect);
            NotifyTemporalEffectPresentationAdded(snapshot);
            NotifyTemporalEffectPresentation(snapshot, effect != null ? effect.visualFlags : EEffectVisualFlags.None);
        }

        /// <summary>
        /// 尝试把传入持续效果消费为已有叠层。
        /// 返回 true 表示被现有 effect 吃掉，调用方不应再额外注册新实例。
        /// </summary>
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

        /// <summary>
        /// 添加普通移速倍率规则。
        /// 返回的 key 必须由调用方保存，用于后续更新或移除。
        /// </summary>
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

        /// <summary>
        /// 更新持续效果派生的移速规则。
        /// runtimeKey 必须来自角色拥有的正式持续效果实例。
        /// </summary>
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

        /// <summary>
        /// 移除持续效果派生的移速规则。
        /// </summary>
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

        /// <summary>
        /// 更新普通移速倍率规则。
        /// key 必须是 <see cref="ApplyMoveSpeedFactor"/> 返回的句柄。
        /// </summary>
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

        /// <summary>
        /// 移除普通移速倍率规则。
        /// </summary>
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

        /// <summary>
        /// 添加动作锁规则。
        /// 返回 key 由调用方保存，后续必须用同一个 key 解锁。
        /// </summary>
        public string LockActions(EActionFlags actions)
        {
            return m_actionRuntime.LockActions(actions);
        }

        /// <summary>
        /// 应用来源化动作锁。
        /// 同一来源可叠加，移除时按来源逐层撤回。
        /// </summary>
        public void ApplyAlterationActionLockRule(CharacterAbilitySourceKey source, EActionFlags actions)
        {
            m_actionRuntime.ApplyAlterationRuleActionLock(source, actions);
        }

        /// <summary>
        /// 移除来源化动作锁的一层叠层。
        /// </summary>
        public void RemoveAlterationActionLockRuleStack(CharacterAbilitySourceKey source)
        {
            m_actionRuntime.RemoveAlterationRuleActionLockStack(source);
        }

        /// <summary>
        /// 移除某个来源的全部动作锁。
        /// </summary>
        public void RemoveAllAlterationActionLockRules(CharacterAbilitySourceKey source)
        {
            m_actionRuntime.RemoveAllAlterationRuleActionLocks(source);
        }

        /// <summary>
        /// 清空所有来源化动作锁。
        /// 主要用于角色重置、读档或对象复用前的状态清理。
        /// </summary>
        internal void ClearAlterationActionLockRules()
        {
            m_actionRuntime.ClearAlterationRuleActionLocks();
        }

        /// <summary>
        /// 应用玩家控制锁。
        /// 锁存在时玩家输入系统不能把该角色当成可控目标。
        /// </summary>
        public void ApplyAlterationPlayerControlLockRule(CharacterAbilitySourceKey source)
        {
            m_alterationPlayerControlLocks.TryGetValue(source, out int currentStackCount);
            m_alterationPlayerControlLocks[source] = currentStackCount + 1;
        }

        /// <summary>
        /// 移除玩家控制锁的一层叠层。
        /// </summary>
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

        /// <summary>
        /// 移除某个来源的全部玩家控制锁。
        /// </summary>
        public void RemoveAllAlterationPlayerControlLockRules(CharacterAbilitySourceKey source)
        {
            m_alterationPlayerControlLocks.Remove(source);
        }

        /// <summary>
        /// 清空所有玩家控制锁。
        /// </summary>
        internal void ClearAlterationPlayerControlLockRules()
        {
            m_alterationPlayerControlLocks.Clear();
        }

        /// <summary>
        /// 应用 AI 控制覆盖。
        /// 任意来源存在时都会刷新控制器覆盖，确保 AIController 接管该角色。
        /// </summary>
        public void ApplyAlterationAIControlRule(CharacterAbilitySourceKey source)
        {
            m_alterationAIControlOverrides.TryGetValue(source, out int currentStackCount);
            m_alterationAIControlOverrides[source] = currentStackCount + 1;
            RefreshAlterationControllerOverride();
        }

        /// <summary>
        /// 移除 AI 控制覆盖的一层叠层，并刷新控制器覆盖状态。
        /// </summary>
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

        /// <summary>
        /// 移除某个来源的全部 AI 控制覆盖。
        /// </summary>
        public void RemoveAllAlterationAIControlRules(CharacterAbilitySourceKey source)
        {
            m_alterationAIControlOverrides.Remove(source);
            RefreshAlterationControllerOverride();
        }

        /// <summary>
        /// 清空所有 AI 控制覆盖。
        /// </summary>
        internal void ClearAlterationAIControlRules()
        {
            m_alterationAIControlOverrides.Clear();
            RefreshAlterationControllerOverride();
        }

        /// <summary>
        /// 当前角色是否可以被玩家系统控制。
        /// 死亡或存在玩家控制锁时都不可控。
        /// </summary>
        public bool CanBePlayerControlled()
        {
            return !dead && !HasAlterationPlayerControlLock();
        }

        /// <summary>
        /// 应用装备效果压制规则。
        /// 只有角色实际带有 CharacterEquipment 时才转发，缺组件表示该角色没有装备层能力。
        /// </summary>
        public virtual void ApplyAlterationEquipmentEffectSuppressionRule(CharacterAbilitySourceKey source)
        {
            if (TryGetComponent(out CharacterEquipment equipmentComponent) && equipmentComponent != null)
            {
                equipmentComponent.ApplyAlterationEquipmentEffectSuppressionRule(source);
            }
        }

        /// <summary>
        /// 移除装备效果压制的一层叠层。
        /// </summary>
        public virtual void RemoveAlterationEquipmentEffectSuppressionRuleStack(CharacterAbilitySourceKey source)
        {
            if (TryGetComponent(out CharacterEquipment equipmentComponent) && equipmentComponent != null)
            {
                equipmentComponent.RemoveAlterationEquipmentEffectSuppressionRuleStack(source);
            }
        }

        /// <summary>
        /// 移除某个来源的全部装备效果压制。
        /// </summary>
        public virtual void RemoveAllAlterationEquipmentEffectSuppressionRules(CharacterAbilitySourceKey source)
        {
            if (TryGetComponent(out CharacterEquipment equipmentComponent) && equipmentComponent != null)
            {
                equipmentComponent.RemoveAllAlterationEquipmentEffectSuppressionRules(source);
            }
        }

        /// <summary>
        /// 清空全部装备效果压制。
        /// </summary>
        internal virtual void ClearAlterationEquipmentEffectSuppressionRules()
        {
            if (TryGetComponent(out CharacterEquipment equipmentComponent) && equipmentComponent != null)
            {
                equipmentComponent.ClearAlterationEquipmentEffectSuppressionRules();
            }
        }

        /// <summary>
        /// 是否存在玩家控制锁。
        /// 字典值是叠层数，只要任意来源仍大于 0 就视为锁定。
        /// </summary>
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

        /// <summary>
        /// 是否存在 AI 控制覆盖。
        /// </summary>
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

        /// <summary>
        /// 根据来源化 AI 控制覆盖刷新控制器。
        /// 这里只激活或清理 AIController 覆盖，不创建新的控制规则。
        /// </summary>
        private void RefreshAlterationControllerOverride()
        {
            if (HasAlterationAIControlOverride())
            {
                TryActivateController<AIController>();
                return;
            }

            ClearControllerOverride<AIController>();
        }

        /// <summary>
        /// 应用阵营覆盖规则。
        /// priority 越高越优先；同优先级下用来源键稳定排序，避免字典遍历顺序影响结果。
        /// </summary>
        public void ApplyAlterationAlignmentRule(CharacterAbilitySourceKey source, EAlignment alignment, int priority)
        {
            m_alterationAlignmentOverrides.TryGetValue(source, out CharacterAlignmentOverrideRuntimeEntry currentEntry);
            m_alterationAlignmentOverrides[source] = new CharacterAlignmentOverrideRuntimeEntry(
                alignment,
                priority,
                currentEntry.StackCount + 1);
        }

        /// <summary>
        /// 移除阵营覆盖的一层叠层。
        /// </summary>
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

        /// <summary>
        /// 移除某个来源的全部阵营覆盖。
        /// </summary>
        public void RemoveAllAlterationAlignmentRules(CharacterAbilitySourceKey source)
        {
            m_alterationAlignmentOverrides.Remove(source);
        }

        /// <summary>
        /// 清空所有阵营覆盖。
        /// </summary>
        internal void ClearAlterationAlignmentRules()
        {
            m_alterationAlignmentOverrides.Clear();
        }

        /// <summary>
        /// 解析当前最高优先级阵营覆盖。
        /// 返回 false 表示继续使用角色基础阵营或外部显式 override。
        /// </summary>
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

        /// <summary>
        /// 稳定比较两个阵营覆盖来源。
        /// 用于同优先级时保证解析结果不依赖 Dictionary 遍历顺序。
        /// </summary>
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

        /// <summary>
        /// 移除持续效果派生的动作锁。
        /// </summary>
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

        /// <summary>
        /// 使用 key 解锁普通动作锁。
        /// key 必须来自 <see cref="LockActions"/>。
        /// </summary>
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

        /// <summary>
        /// 查询动作是否被锁住。
        /// 同时检查本地动作运行时和正式 GameplayTag 门禁。
        /// </summary>
        public bool IsActionLocked(EActionFlags actions)
        {
            return m_actionRuntime.IsActionLocked(actions) || HasFormalActionLock(actions);
        }

        /// <summary>启用指定动作位。</summary>
        public void EnableActions(EActionFlags actions)
        {
            m_actionRuntime.EnableActions(actions);
        }

        /// <summary>禁用指定动作位。</summary>
        public void DisableActions(EActionFlags actions)
        {
            m_actionRuntime.DisableActions(actions);
        }

        /// <summary>
        /// 查询角色当前是否允许执行指定动作。
        /// 正式 GameplayTag 门禁会额外阻止移动、技能和朝向更新。
        /// </summary>
        public bool Can(EActionFlags actions)
        {
            return m_actionRuntime.Can(actions) && !HasFormalActionLock(actions);
        }

        /// <summary>
        /// 从正式 GameplayTag 解析动作门禁。
        /// 攻击中、眩晕、定身和沉默等正式标签会覆盖本地动作运行时结果。
        /// </summary>
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
                HasFormalGameplayTag(abilitySystemComponent, FormalGameplayTagCatalog.AttackingEvent))
            {
                return true;
            }

            // 控制效果的禁用语义现在优先看 formal GameplayTag，而不是再让执行壳长期镜像一份动作锁。
            if (actions.HasFlag(EActionFlags.Move) &&
                (HasFormalGameplayTag(abilitySystemComponent, FormalGameplayTagCatalog.StunControlEffect) ||
                 HasFormalGameplayTag(abilitySystemComponent, FormalGameplayTagCatalog.RootControlEffect)))
            {
                return true;
            }

            if (actions.HasFlag(EActionFlags.UseAbility) &&
                (HasFormalGameplayTag(abilitySystemComponent, FormalGameplayTagCatalog.StunControlEffect) ||
                 HasFormalGameplayTag(abilitySystemComponent, FormalGameplayTagCatalog.SilenceControlEffect)))
            {
                return true;
            }

            if (actions.HasFlag(EActionFlags.UpdateTargetDirection) &&
                HasFormalGameplayTag(abilitySystemComponent, FormalGameplayTagCatalog.StunControlEffect))
            {
                return true;
            }

            return false;
        }

        /// <summary>检查正式 ASC 是否带有指定 GameplayTag。</summary>
        private static bool HasFormalGameplayTag(
            AbilitySystemComponent abilitySystemComponent,
            FormalGameplayTagDefinition tagDefinition)
        {
            return abilitySystemComponent != null &&
                   tagDefinition.TagCode > 0 &&
                   abilitySystemComponent.HasTag(tagDefinition.TagCode);
        }

        /// <summary>
        /// 标记角色为召唤物。
        /// 该标记影响阵营、死亡或存档等后续规则的归属判断。
        /// </summary>
        public void FlagAsSummoned()
        {
            m_isSummoned = true;
        }

        /// <summary>
        /// 设置显式阵营覆盖。
        /// null 表示撤销外部覆盖，回到基础阵营和来源化覆盖解析。
        /// </summary>
        public void SetAlignmentOverride(EAlignment? alignment)
        {
            m_alignmentOverride = alignment;
        }

        /// <summary>
        /// 获取当前持续效果展示快照。
        /// 只返回可展示的 effect，内部运行时效果不会泄露给 UI。
        /// </summary>
        public CharacterTemporalEffectPresentationSnapshot[] GetTemporalEffectPresentationSnapshots()
        {
            int[] runtimeKeySnapshot = GetOwnedTemporalEffectRuntimeKeySnapshot();
            return CreateTemporalEffectPresentationSnapshots(runtimeKeySnapshot);
        }

        /// <summary>
        /// 通知持续效果展示新增。
        /// 没有展示语义的 effect 不会触发 UI 事件。
        /// </summary>
        private void NotifyTemporalEffectPresentationAdded(CharacterTemporalEffectPresentationSnapshot snapshot)
        {
            if (!snapshot.HasPresentation)
            {
                return;
            }

            m_temporalEffectPresentationAdded.Invoke(snapshot);
        }

        /// <summary>
        /// 通知持续效果展示移除。
        /// 即使 effect 结束时无法还原完整展示状态，也会用 runtimeKey 发送最小移除信号。
        /// </summary>
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

        /// <summary>
        /// 发送持续效果即时展示事件。
        /// 用于飘字、图标闪烁或其它表现层反馈，不替代 added/removed 状态事件。
        /// </summary>
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

        /// <summary>
        /// 推进单个持续效果。
        /// 需要 tick 回调的 effect 走 Update；只需要本地寿命推进的 effect 只推进 lifetime。
        /// </summary>
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

        /// <summary>
        /// 从 effect 实例创建展示快照。
        /// 只有 ATemporalEffect 且能提供展示类型和展示状态时才会投影。
        /// </summary>
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
