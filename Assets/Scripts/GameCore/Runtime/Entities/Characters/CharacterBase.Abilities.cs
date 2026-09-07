using System.Collections.Generic;
using System.Linq;
using GAS.Runtime;
using UnityEngine;
using UnityEngine.Events;
using UnityObject = UnityEngine.Object;

namespace FantasyWord.GameCore
{
    public abstract partial class CharacterBase
    {
        /// <summary>
        /// 正式 EX-GAS 能力进入角色拥有列表后的统一收口。
        /// 这里同时登记到技能槽组件、应用已有压制状态并广播展示事件。
        /// </summary>
        protected virtual void OnFormalGasAbilityAdded(int formalGasAbilityCode)
        {
            if (formalGasAbilityCode <= 0 || !TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                return;
            }

            abilitySet.RegisterFormalGasAbilityRule(formalGasAbilityCode);
            ApplyFormalGasAbilitySuppressionState(formalGasAbilityCode);
            abilitySet.TryAutoEquipOwnedFormalGasAbilityCode(formalGasAbilityCode);
            GameRuntimeEvents.NotifyCharacterFormalGasAbilityAdded(this, formalGasAbilityCode);
        }

        /// <summary>
        /// 正式 EX-GAS 能力离开角色拥有列表后的统一收口。
        /// 移除时必须同步清理所有装备槽，避免 UI 或输入仍指向已释放的能力编号。
        /// </summary>
        protected virtual void OnFormalGasAbilityRemoved(int formalGasAbilityCode)
        {
            if (formalGasAbilityCode <= 0 || !TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                return;
            }

            abilitySet.UnregisterFormalGasAbilityRule(formalGasAbilityCode);
            abilitySet.RemoveEquippedFormalGasAbilityCodeFromAllSlots(formalGasAbilityCode);
            GameRuntimeEvents.NotifyCharacterFormalGasAbilityRemoved(this, formalGasAbilityCode);
        }

        /// <summary>
        /// 初始化角色等级带来的正式能力。
        /// 如果存在 <see cref="CharacterAbilitySet"/>，由它先合并初始槽位规则；否则直接使用 Sheet 的可用能力列表。
        /// </summary>
        private void InitializeAbilities()
        {
            IEnumerable<int> formalGasAbilityCodes =
                TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet)
                    ? abilitySet.CreateInitialFormalGasAbilityCodeSet(characterSheet.GetAvailableFormalGasAbilitiesAtLevel(m_level))
                    : characterSheet.GetAvailableFormalGasAbilitiesAtLevel(m_level);
            UnlockFormalGasAbilitiesForLevel(formalGasAbilityCodes);
        }

        /// <summary>
        /// 授予额外正式能力。
        /// 该入口可用于装备、永久成长或其它非临时来源；来源键决定后续撤回和叠加计数。
        /// </summary>
        public bool AddBonusFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)
        {
            if (formalGasAbilityCode <= 0 || count <= 0)
            {
                return false;
            }

            return AbilityRuntime.TryRegisterBonusFormalGasAbility(
                formalGasAbilityCode,
                source,
                InstantiateFormalGasAbilityPrefab,
                count,
                OnFormalGasAbilityAdded);
        }

        /// <summary>
        /// 撤回额外正式能力。
        /// count 只减少对应来源的叠层，叠层归零时才释放能力实例。
        /// </summary>
        public bool RemoveBonusFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)
        {
            if (formalGasAbilityCode <= 0 || count <= 0)
            {
                return false;
            }

            return AbilityRuntime.TryUnregisterBonusFormalGasAbility(
                formalGasAbilityCode,
                source,
                count,
                ReleaseAbilityPrefab,
                OnFormalGasAbilityRemoved);
        }

        /// <summary>
        /// 状态效果、变形和感染等临时规则只通过来源键授予能力。
        /// 这样效果结束或形态退出时可以精确撤回对应来源，不会误删装备、永久成长或其它状态授予的同名能力。
        /// </summary>
        public bool AddSourcedBonusFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)
        {
            if (formalGasAbilityCode <= 0 || count <= 0 || !IsTemporaryAbilitySourceKind(source.Kind))
            {
                return false;
            }

            return AbilityRuntime.TryRegisterBonusFormalGasAbility(
                formalGasAbilityCode,
                source,
                InstantiateFormalGasAbilityPrefab,
                count,
                OnFormalGasAbilityAdded);
        }

        /// <summary>
        /// 撤回临时来源授予的正式能力。
        /// 非临时来源会被拒绝，避免状态效果接口误删装备或永久成长带来的能力。
        /// </summary>
        public bool RemoveSourcedBonusFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)
        {
            if (formalGasAbilityCode <= 0 || count <= 0 || !IsTemporaryAbilitySourceKind(source.Kind))
            {
                return false;
            }

            return AbilityRuntime.TryUnregisterBonusFormalGasAbility(
                formalGasAbilityCode,
                source,
                count,
                ReleaseAbilityPrefab,
                OnFormalGasAbilityRemoved);
        }

        /// <summary>
        /// 移除某个临时来源授予的全部正式能力。
        /// 返回移除前的来源条目，方便调用方做审计、存档回滚或展示刷新。
        /// </summary>
        public CharacterAbilitySourceRuntimeEntry[] RemoveAllSourcedBonusAbilities(CharacterAbilitySourceKey source)
        {
            if (!IsTemporaryAbilitySourceKind(source.Kind))
            {
                return System.Array.Empty<CharacterAbilitySourceRuntimeEntry>();
            }

            CharacterAbilitySourceRuntimeEntry[] entries = AbilityRuntime.CreateBonusAbilitySourceEntrySnapshot(source);
            foreach (CharacterAbilitySourceRuntimeEntry entry in entries)
            {
                if (entry.HasFormalGasAbility)
                {
                    AbilityRuntime.TryUnregisterBonusFormalGasAbility(
                        entry.FormalGasAbilityCode,
                        entry.Source,
                        entry.StackCount,
                        ReleaseAbilityPrefab,
                        OnFormalGasAbilityRemoved);
                }
            }

            return entries;
        }

        /// <summary>
        /// 状态效果、变形和感染禁用能力时只登记来源化压制，不删除能力实例。
        /// 这样变形/沉默结束时只撤回自己的禁用层，不会误恢复仍被其它来源压制的能力。
        /// </summary>
        public bool AddSourcedFormalGasAbilitySuppression(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)
        {
            if (formalGasAbilityCode <= 0 || count <= 0 || !IsTemporaryAbilitySourceKind(source.Kind))
            {
                return false;
            }

            bool changed = AbilityRuntime.TrySuppressFormalGasAbility(formalGasAbilityCode, source, count);
            if (changed)
            {
                ApplyFormalGasAbilitySuppressionState(formalGasAbilityCode);
            }

            return true;
        }

        /// <summary>
        /// 移除临时来源的能力压制叠层。
        /// 压制状态变化后会立即同步到能力实例的可用状态和 GameObject 激活状态。
        /// </summary>
        public bool RemoveSourcedFormalGasAbilitySuppression(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)
        {
            if (formalGasAbilityCode <= 0 || count <= 0 || !IsTemporaryAbilitySourceKind(source.Kind))
            {
                return false;
            }

            bool changed = AbilityRuntime.TryUnsuppressFormalGasAbility(formalGasAbilityCode, source, count);
            if (changed)
            {
                ApplyFormalGasAbilitySuppressionState(formalGasAbilityCode);
            }

            return true;
        }

        /// <summary>
        /// 移除某个临时来源造成的全部能力压制。
        /// 只撤回该来源自己的叠层，仍被其它来源压制的能力不会被误恢复。
        /// </summary>
        public CharacterAbilitySourceRuntimeEntry[] RemoveAllSourcedAbilitySuppressions(CharacterAbilitySourceKey source)
        {
            if (!IsTemporaryAbilitySourceKind(source.Kind))
            {
                return System.Array.Empty<CharacterAbilitySourceRuntimeEntry>();
            }

            CharacterAbilitySourceRuntimeEntry[] entries = AbilityRuntime.CreateSuppressedAbilitySourceEntrySnapshot(source);
            foreach (CharacterAbilitySourceRuntimeEntry entry in entries)
            {
                bool changed = entry.HasFormalGasAbility &&
                    AbilityRuntime.TryUnsuppressFormalGasAbility(entry.FormalGasAbilityCode, entry.Source, entry.StackCount);
                if (changed)
                {
                    ApplyFormalGasAbilitySuppressionState(entry.FormalGasAbilityCode);
                }
            }

            return entries;
        }

        /// <summary>状态效果授予正式能力的语义入口。</summary>
        public bool AddStatusEffectFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)
        {
            return AddSourcedBonusFormalGasAbility(formalGasAbilityCode, source, count);
        }

        /// <summary>状态效果撤回正式能力的语义入口。</summary>
        public bool RemoveStatusEffectFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)
        {
            return RemoveSourcedBonusFormalGasAbility(formalGasAbilityCode, source, count);
        }

        /// <summary>移除某个状态效果授予的全部正式能力。</summary>
        public CharacterAbilitySourceRuntimeEntry[] RemoveAllStatusEffectAbilities(CharacterAbilitySourceKey source)
        {
            return RemoveAllSourcedBonusAbilities(source);
        }

        /// <summary>状态效果压制正式能力的语义入口。</summary>
        public bool AddStatusEffectFormalGasAbilitySuppression(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)
        {
            return AddSourcedFormalGasAbilitySuppression(formalGasAbilityCode, source, count);
        }

        /// <summary>撤回状态效果造成的正式能力压制。</summary>
        public bool RemoveStatusEffectFormalGasAbilitySuppression(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)
        {
            return RemoveSourcedFormalGasAbilitySuppression(formalGasAbilityCode, source, count);
        }

        /// <summary>移除某个状态效果造成的全部正式能力压制。</summary>
        public CharacterAbilitySourceRuntimeEntry[] RemoveAllStatusEffectAbilitySuppressions(CharacterAbilitySourceKey source)
        {
            return RemoveAllSourcedAbilitySuppressions(source);
        }

        /// <summary>移除指定变形来源授予的全部正式能力。</summary>
        public CharacterAbilitySourceRuntimeEntry[] RemoveAllTransformationAbilities(string transformationId)
        {
            return RemoveAllSourcedBonusAbilities(CreateTransformationAbilitySource(transformationId));
        }

        /// <summary>移除指定变形来源造成的全部正式能力压制。</summary>
        public CharacterAbilitySourceRuntimeEntry[] RemoveAllTransformationAbilitySuppressions(string transformationId)
        {
            return RemoveAllSourcedAbilitySuppressions(CreateTransformationAbilitySource(transformationId));
        }

        /// <summary>移除指定感染来源授予的全部正式能力。</summary>
        public CharacterAbilitySourceRuntimeEntry[] RemoveAllInfectionAbilities(string infectionId)
        {
            return RemoveAllSourcedBonusAbilities(CreateInfectionAbilitySource(infectionId));
        }

        /// <summary>移除指定感染来源造成的全部正式能力压制。</summary>
        public CharacterAbilitySourceRuntimeEntry[] RemoveAllInfectionAbilitySuppressions(string infectionId)
        {
            return RemoveAllSourcedAbilitySuppressions(CreateInfectionAbilitySource(infectionId));
        }

        /// <summary>查询角色当前是否拥有指定正式能力编号。</summary>
        public bool HasFormalGasAbility(int formalGasAbilityCode)
        {
            return AbilityRuntime.HasFormalGasAbility(formalGasAbilityCode);
        }

        /// <summary>查询指定正式能力是否被来源化规则压制。</summary>
        public bool IsFormalGasAbilitySuppressed(int formalGasAbilityCode)
        {
            return AbilityRuntime.IsFormalGasAbilitySuppressed(formalGasAbilityCode);
        }

        /// <summary>创建当前角色拥有的正式能力编号快照。</summary>
        public int[] CreateOwnedFormalGasAbilityCodeSnapshot()
        {
            return AbilityRuntime.GetFormalGasAbilityCodeSnapshots();
        }

        /// <summary>
        /// 读档前必须先撤掉当前对象上残留的来源化能力与压制状态。
        /// 仅清空计数会把复用对象上的旧实例或禁用状态带进新档。
        /// </summary>
        private void ClearOwnedAbilitySourceRuntimeState()
        {
            foreach (CharacterAbilitySourceRuntimeEntry entry in AbilityRuntime.CreateBonusAbilitySourceEntrySnapshot())
            {
                if (entry.HasFormalGasAbility)
                {
                    AbilityRuntime.TryUnregisterBonusFormalGasAbility(
                        entry.FormalGasAbilityCode,
                        entry.Source,
                        entry.StackCount,
                        ReleaseAbilityPrefab,
                        OnFormalGasAbilityRemoved);
                }
            }

            foreach (CharacterAbilitySourceRuntimeEntry entry in AbilityRuntime.CreateSuppressedAbilitySourceEntrySnapshot())
            {
                bool changed = AbilityRuntime.TryUnsuppressFormalGasAbility(entry.FormalGasAbilityCode, entry.Source, entry.StackCount);
                if (changed)
                {
                    ApplyFormalGasAbilitySuppressionState(entry.FormalGasAbilityCode);
                }
            }
        }

        /// <summary>
        /// 将来源化压制状态应用到能力实例。
        /// 压制时取消技能槽生命周期、打断能力并禁用实例；恢复时只按默认激活规则重新启用。
        /// </summary>
        private void ApplyFormalGasAbilitySuppressionState(int formalGasAbilityCode)
        {
            if (!AbilityRuntime.TryGetFormalGasAbilityInstance(
                    formalGasAbilityCode,
                    out AbilityBase abilityInstance) ||
                abilityInstance == null)
            {
                return;
            }

            bool suppressed = AbilityRuntime.IsFormalGasAbilitySuppressed(formalGasAbilityCode);
            if (abilityInstance is ActiveAbilityBase activeAbility)
            {
                activeAbility.PermitAbility(!suppressed);
            }

            if (suppressed)
            {
                if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
                {
                    abilitySet.CancelFormalGasAbilityRuleLifecycle(formalGasAbilityCode);
                }

                abilityInstance.Interrupt();
                abilityInstance.gameObject.SetActive(false);
                return;
            }

            abilityInstance.gameObject.SetActive(GetDefaultAbilityState(abilityInstance));
        }

        /// <summary>构建变形来源键。</summary>
        private static CharacterAbilitySourceKey CreateTransformationAbilitySource(string transformationId)
        {
            return new CharacterAbilitySourceKey(ECharacterAbilitySourceKind.Transformation, transformationId);
        }

        /// <summary>构建感染来源键。</summary>
        private static CharacterAbilitySourceKey CreateInfectionAbilitySource(string infectionId)
        {
            return new CharacterAbilitySourceKey(ECharacterAbilitySourceKind.Infection, infectionId);
        }

        /// <summary>
        /// 判断来源是否属于临时能力来源。
        /// 只有临时来源允许走 sourced 接口，装备和永久成长应走普通 bonus 接口。
        /// </summary>
        private static bool IsTemporaryAbilitySourceKind(ECharacterAbilitySourceKind sourceKind)
        {
            return sourceKind == ECharacterAbilitySourceKind.StatusEffect ||
                sourceKind == ECharacterAbilitySourceKind.Transformation ||
                sourceKind == ECharacterAbilitySourceKind.Infection;
        }

        /// <summary>
        /// 能力菜单和其它展示层只允许拿主动能力资产快照。
        /// 这里由角色正式拥有者从实例仓库投影出可读结果，而不是把查询职责继续塞在内部 runtime helper 上。
        /// </summary>
        public CharacterAbilityMenuEntry[] GetActiveAbilityMenuEntrySnapshots()
        {
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                return abilitySet.CreateActiveAbilityMenuEntrySnapshot();
            }

            return System.Array.Empty<CharacterAbilityMenuEntry>();
        }

        /// <summary>
        /// 能力菜单和其它展示层只允许拿被动能力资产快照。
        /// 这里和主动能力入口保持同一层角色公开接口，避免 UI 直接依赖内部能力集合。
        /// </summary>
        public bool TryGetFirstTriggerableFormalGasAbilityCode(out int formalGasAbilityCode)
        {
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                return abilitySet.TryGetFirstTriggerableFormalGasAbilityCode(out formalGasAbilityCode);
            }

            formalGasAbilityCode = 0;
            return false;
        }

        /// <summary>
        /// 查询主动能力冷却快照。
        /// UI 只拿只读快照，不直接访问 CharacterAbilitySet 内部槽位状态。
        /// </summary>
        public bool TryGetActiveAbilityCooldownSnapshot(
            CharacterEquippedAbilitySlotView slot,
            out CharacterAbilityCooldownSnapshot snapshot)
        {
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                return abilitySet.TryGetActiveAbilityCooldownSnapshot(slot, out snapshot);
            }

            snapshot = default;
            return false;
        }

        /// <summary>
        /// 创建当前快捷技能槽视图快照。
        /// 结果用于 HUD、能力菜单和存档前预览，不把内部槽位数组暴露出去。
        /// </summary>
        public CharacterEquippedAbilitySlotView[] GetEquippedAbilitySlotViewSnapshots()
        {
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                return abilitySet.CreateEquippedAbilitySlotViewSnapshot();
            }

            return System.Array.Empty<CharacterEquippedAbilitySlotView>();
        }

        /// <summary>
        /// 触发指定快捷技能槽。
        /// 这个公开入口只接收命令上下文，瞄准和目标上下文由内部重载或命令执行器补齐。
        /// </summary>
        public CharacterAbilityFireResult FireEquippedAbilityAtIndex(int index, GameCommandContext commandContext)
        {
            return FireEquippedAbilityAtIndex(index, commandContext, null);
        }

        /// <summary>
        /// 触发指定快捷技能槽，并传入已解析的 EX-GAS 激活上下文。
        /// 没有能力槽组件时返回 Unknown，不在这里临时创建替代组件。
        /// </summary>
        internal CharacterAbilityFireResult FireEquippedAbilityAtIndex(
            int index,
            GameCommandContext commandContext,
            AbilityActivationContext activationContext)
        {
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                return abilitySet.FireEquippedAbilityAtIndex(index, commandContext, activationContext);
            }

            return new CharacterAbilityFireResult(EAbilityFireCheckResult.Unknown, 0);
        }

        /// <summary>
        /// 停止指定快捷技能槽的持续输入。
        /// 没有能力槽组件或槽位无效时返回 false。
        /// </summary>
        public bool StopFireEquippedAbilityAtIndex(int index)
        {
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                return abilitySet.StopFireEquippedAbilityAtIndex(index);
            }

            return false;
        }

        /// <summary>
        /// 直接触发指定正式 EX-GAS 能力。
        /// 这是角色级能力触发入口；缺少 CharacterAbilitySet 时会报错并返回 Unknown。
        /// </summary>
        public EAbilityFireCheckResult FireFormalGasAbility(int formalGasAbilityCode, GameCommandContext commandContext)
        {
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                return abilitySet.FireFormalGasAbility(formalGasAbilityCode, commandContext);
            }

            Debug.LogError($"[{nameof(CharacterBase)}] Missing formal {nameof(CharacterAbilitySet)} for EX-GAS ability fire.", this);
            return EAbilityFireCheckResult.Unknown;
        }

        /// <summary>
        /// 停止指定正式 EX-GAS 能力的持续输入。
        /// </summary>
        public bool StopFireFormalGasAbility(int formalGasAbilityCode)
        {
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                return abilitySet.StopFireFormalGasAbility(formalGasAbilityCode);
            }

            return false;
        }

        /// <summary>
        /// 将正式能力编号装备到快捷技能槽。
        /// 只委托给 CharacterAbilitySet，角色本体不直接维护槽位数组。
        /// </summary>
        public bool TryEquipFormalGasAbilityCodeToSlot(int formalGasAbilityCode, int index)
        {
            return TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet) &&
                abilitySet.TryEquipFormalGasAbilityCodeToSlot(formalGasAbilityCode, index);
        }

        /// <summary>
        /// 清空指定快捷技能槽。
        /// </summary>
        public bool ClearEquippedAbilitySlot(int index)
        {
            return TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet) &&
                abilitySet.ClearEquippedAbilitySlot(index);
        }

        /// <summary>
        /// 创建快捷技能槽存档快照。
        /// 只保存槽位索引和正式能力编号，不保存运行时能力实例。
        /// </summary>
        public CharacterAbilitySlotData[] CreateEquippedAbilitySlotDataSnapshot(DatabaseRegistry databaseRegistry)
        {
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                return abilitySet.CreateEquippedAbilitySlotDataSnapshot(databaseRegistry);
            }

            return System.Array.Empty<CharacterAbilitySlotData>();
        }

        /// <summary>
        /// 从存档槽位恢复快捷技能布局。
        /// 恢复前提是正式能力实例已经由 CharacterBase/AbilityRuntime 恢复完成。
        /// </summary>
        public bool RestoreEquippedAbilitiesFromSlotData(
            System.Collections.Generic.IEnumerable<CharacterAbilitySlotData> quickAbilitySlots)
        {
            return TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet) &&
                abilitySet.RestoreEquippedAbilitiesFromSlotData(quickAbilitySlots);
        }

        /// <summary>
        /// 订阅快捷技能槽变化。
        /// 空监听会被忽略，避免 UnityEvent 注册空委托。
        /// </summary>
        public void AddEquippedAbilitiesChangedListener(UnityAction<CharacterEquippedAbilitySlotView[]> listener)
        {
            if (listener == null)
            {
                return;
            }

            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                abilitySet.AddEquippedAbilitiesChangedListener(listener);
            }
        }

        /// <summary>
        /// 取消订阅快捷技能槽变化。
        /// </summary>
        public void RemoveEquippedAbilitiesChangedListener(UnityAction<CharacterEquippedAbilitySlotView[]> listener)
        {
            if (listener == null)
            {
                return;
            }

            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                abilitySet.RemoveEquippedAbilitiesChangedListener(listener);
            }
        }

        /// <summary>
        /// 查询除指定能力外，是否有其它可触发能力处于指定本地输入门控状态。
        /// 这是 GameCore 对“同一角色不能同时进入多个出手流程”的本地门控，不承载命中、伤害或表现真相。
        /// </summary>
        public bool HasOtherAbilityInInputGateState(ActiveAbilityBase ignoredAbility, EFormalAbilityInputGateState[] blockedStates)
        {
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                return abilitySet.HasOtherAbilityInInputGateState(ignoredAbility, blockedStates);
            }

            return false;
        }

        /// <summary>
        /// 动作打断只通知显式声明了中断合同的能力实例。
        /// 这里不再用 BroadcastMessage 依赖字符串和层级扫描，避免把打断语义偷偷扩散到无关组件。
        /// </summary>
        private void InterruptActions() => AbilityRuntime.NotifyActionInterrupted();

        /// <summary>
        /// 根据等级解锁正式能力。
        /// 能力实例创建、角色层注册和事件广播都通过 OnFormalGasAbilityAdded 收口。
        /// </summary>
        private void UnlockFormalGasAbilitiesForLevel(IEnumerable<int> formalGasAbilityCodes)
        {
            if (formalGasAbilityCodes == null)
            {
                return;
            }

            foreach (int formalGasAbilityCode in formalGasAbilityCodes)
            {
                AbilityRuntime.TryAddUnlockedFormalGasAbility(
                    formalGasAbilityCode,
                    InstantiateFormalGasAbilityPrefab,
                    OnFormalGasAbilityAdded);
            }
        }

        /// <summary>
        /// 实例化正式 EX-GAS 能力 Prefab。
        /// 配置缺失、Prefab 缺失或根节点缺失都会明确报错，不创建半成品能力实例。
        /// </summary>
        private AbilityBase InstantiateFormalGasAbilityPrefab(int formalGasAbilityCode)
        {
            if (formalGasAbilityCode <= 0 ||
                !FormalGasAbilityRuntimeConfigResolver.TryResolveRuntimeConfig(
                    formalGasAbilityCode,
                    out FormalGasAbilityRuntimeConfig config) ||
                !config.TryLoadPrefab(out GameObject prefab) ||
                prefab == null)
            {
                Debug.LogError($"EX-GAS Ability {formalGasAbilityCode} 缺少可创建的正式 Prefab；请补齐 exgas.abilityGameCore 配置。", this);
                return null;
            }

            Transform abilityRoot = null;
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                abilitySet.TryResolveFormalGasAbilityRoot(config.AbilityRootMode, out abilityRoot);
            }

            Debug.Assert(abilityRoot != null, "No ability root found! Make sure to assign each ability root in the inspector.");

            GameObject instance = UnityObject.Instantiate(prefab, abilityRoot);
            instance.name = FormalGasAbilityIdentityResolver.TryResolveAbilityIdentity(
                    formalGasAbilityCode,
                    out FormalGasAbilityIdentity identity) &&
                !string.IsNullOrWhiteSpace(identity.DisplayName)
                    ? identity.DisplayName
                    : $"EX-GAS Ability {formalGasAbilityCode}";

            AbilityBase ability = instance.GetComponent<AbilityBase>();
            Debug.Assert(ability, $"The provided ability prefab doesn't have a behaviour of type {typeof(AbilityBase).Name} attached to its root");
            if (ability == null)
            {
                UnityObject.Destroy(instance);
                return null;
            }

            ability.InitFormalGasAbility(this, formalGasAbilityCode);
            ability.gameObject.SetActive(GetDefaultAbilityState(ability));
            return ability;
        }

        /// <summary>
        /// 释放能力 Prefab 实例。
        /// 播放态使用 Destroy，编辑器非播放态使用 DestroyImmediate，避免遗留编辑器对象。
        /// </summary>
        private void ReleaseAbilityPrefab(AbilityBase ability)
        {
            if (ability)
            {
                if (Application.isPlaying)
                {
                    UnityObject.Destroy(ability.gameObject);
                }
                else
                {
                    UnityObject.DestroyImmediate(ability.gameObject);
                }
            }
        }

        /// <summary>
        /// 判断能力实例创建后的默认激活状态。
        /// 持续存在的被动/规则能力默认激活，可触发能力默认交给输入入口触发。
        /// </summary>
        private static bool GetDefaultAbilityState(AbilityBase abilityInstance)
        {
            if (abilityInstance == null)
            {
                return false;
            }

            return abilityInstance.usesFormalGasAbilityForRuntime &&
                abilityInstance is not ITriggerableAbility;
        }

    }
}


