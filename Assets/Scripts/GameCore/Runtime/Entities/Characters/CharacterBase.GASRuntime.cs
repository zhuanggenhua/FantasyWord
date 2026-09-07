using System.Collections.Generic;
using GAS.Runtime;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public abstract partial class CharacterBase
    {
        [SerializeField]
        [LabelText("正式能力系统组件")]
        [Tooltip("实体级正式 AbilitySystemComponent。当前阶段只允许角色自己持有，不允许升格为 GameManager 级系统。")]
        private AbilitySystemComponent m_abilitySystemComponent = null;

        // 正式 ASC 初始化完成前，属性读取只允许在启动缓冲窗口内短暂回退，避免运行时长期双轨。
        private bool m_isFormalAbilitySystemReady = false;

        // 订阅状态单独记录，保证 OnEnable/OnDisable 或对象复用时不会重复注册属性事件。
        private bool m_formalAttributeEventsRegistered = false;

        // 整组快照覆盖会统一发布一次属性变化，期间屏蔽逐字段 ASC 当前值事件，避免 UI 和死亡链收到半成品快照。
        private bool m_suppressFormalCurrentValueEvents = false;

        // 按 EStat 保存委托，注销时必须使用同一实例，否则 GAS 事件中心无法精确解除订阅。
        private readonly Dictionary<EStat, System.Action<float, float>> m_formalCurrentValueChangedHandlers = new();

        /// <summary>
        /// 清除角色自己持有的指定类型持续效果。
        /// 这里按运行时 key 快照删除，避免遍历过程中 effect 完成或移除导致集合变化。
        /// </summary>
        private int CleanseOwnedTemporalEffects(EEffectType[] effectTypes)
        {
            EEffectType[] normalizedEffectTypes = NormalizeTemporalEffectTypes(effectTypes);
            if (normalizedEffectTypes.Length == 0)
            {
                return 0;
            }

            int[] runtimeKeys = CollectOwnedTemporalEffectRuntimeKeysForCleanse(
                GetOwnedTemporalEffectRuntimeKeySnapshot(),
                new System.Collections.Generic.HashSet<EEffectType>(normalizedEffectTypes));

            ITemporalEffect[] removedEffects = RemoveOwnedTemporalEffectsByRuntimeKeySnapshot(runtimeKeys);
            FinalizeOwnedTemporalEffects(removedEffects);
            return removedEffects != null ? removedEffects.Length : 0;
        }

        /// <summary>
        /// 解析角色正式 ASC。
        /// 只从同物体缓存/补取，不做场景搜索；缺失时调用方需要按当前入口决定是否报错。
        /// </summary>
        public bool TryGetFormalAbilitySystem(out AbilitySystemComponent abilitySystemComponent)
        {
            if (!m_abilitySystemComponent)
            {
                m_abilitySystemComponent = GetComponent<AbilitySystemComponent>();
            }

            abilitySystemComponent = m_abilitySystemComponent;
            return abilitySystemComponent != null;
        }

        /// <summary>
        /// 用当前角色属性初始化正式 ASC。
        /// 这是 CharacterBase 属性真相切到 FormalAttributeCatalog 的入口，初始化后同步已有能力规则到能力槽运行时。
        /// </summary>
        protected void InitializeFormalAbilitySystemFromCurrentAttributes()
        {
            Stats initialBaseStats = CreateStatsSnapshot();
            Stats initialCurrentStats = CreateCurrentStatsSnapshot();

            if (!TryGetFormalAbilitySystem(out AbilitySystemComponent abilitySystemComponent) ||
                abilitySystemComponent == null)
            {
                return;
            }

            AbilitySystemCellConfig config = new(
                baseTags: System.Array.Empty<int>(),
                attrSets: new[] { FormalAttributeCatalog.CreateAttributeSetConfig(initialBaseStats) },
                baseAbilities: System.Array.Empty<AbilityConfig>(),
                level: m_level);

            abilitySystemComponent.Init(config);
            ApplyStatsSnapshotToFormalAbilitySystem(
                abilitySystemComponent,
                initialBaseStats,
                initialCurrentStats,
                initialBaseStats,
                initialCurrentStats);
            m_isFormalAbilitySystemReady = true;
            SyncFormalAbilityRuleRosterFromRuntime();
        }

        /// <summary>
        /// 将装备、成长和自定义点数结算后的基础属性写回正式 ASC。
        /// 当前值按“基础属性变化量”平移，保留受伤、耗蓝等运行时缺口。
        /// </summary>
        protected void ApplyResolvedBaseStatsToFormalAbilitySystem(
            Stats resolvedBaseStats,
            Stats previousBaseStats,
            Stats previousCurrentStats)
        {
            if (!TryGetFormalAbilitySystem(out AbilitySystemComponent abilitySystemComponent) ||
                abilitySystemComponent == null)
            {
                return;
            }

            Stats nextCurrentStats = CreateAdjustedCurrentStatsSnapshot(previousBaseStats, previousCurrentStats, resolvedBaseStats);
            ApplyStatsSnapshotToFormalAbilitySystem(
                abilitySystemComponent,
                resolvedBaseStats ?? new Stats(),
                nextCurrentStats,
                previousBaseStats,
                previousCurrentStats);
        }

        /// <summary>
        /// 读档时只恢复当前资源状态。
        /// 基础属性、装备、等级和持续效果先重建，再把受伤/耗蓝状态通过 GAS Modifier 写回资源属性。
        /// </summary>
        protected void ApplySavedCurrentResourcesToOwnedAttributeTruth(CharacterResourceStateData currentResources)
        {
            if (currentResources == null)
            {
                return;
            }

            ApplySavedCurrentResource(EStat.Health, currentResources.health, GetMaxHealth());
            ApplySavedCurrentResource(EStat.Mana, currentResources.mana, GetMaxMana());
        }

        private void ApplySavedCurrentResource(EStat stat, int requestedValue, int maxValue)
        {
            int targetValue = Mathf.Clamp(requestedValue, 0, Mathf.Max(0, maxValue));
            int currentValue = GetCurrentStatValue(stat);
            if (targetValue == currentValue)
            {
                return;
            }

            if (!FormalGameplayEffectResourceModifier.TryApplyCurrentStatDelta(
                    this,
                    stat,
                    targetValue - currentValue,
                    minValue: 0,
                    maxValue: maxValue,
                    sourceCharacter: this,
                    out _,
                    out _))
            {
                Debug.LogError($"[{nameof(CharacterBase)}] 读档资源恢复必须命中正式 ASC，无法为 {name} 恢复 {stat}={targetValue}。", this);
            }
        }

        /// <summary>
        /// 只有正式 ASC 初始化完成并且组件可用时，才允许外部读取正式属性。
        /// 启动期回退由上层 bootstrap buffer 专用入口处理。
        /// </summary>
        private bool TryGetInitializedFormalAttributes(out AbilitySystemComponent abilitySystemComponent)
        {
            abilitySystemComponent = null;
            if (!m_isFormalAbilitySystemReady)
            {
                return false;
            }

            if (!TryGetFormalAbilitySystem(out abilitySystemComponent) || abilitySystemComponent == null)
            {
                return false;
            }

            return true;
        }

        /// <summary>
        /// 从 FormalAttributeCatalog 读取基础属性。
        /// 返回 false 表示正式属性真相尚未准备好，上层决定是否允许启动缓冲回退。
        /// </summary>
        private bool TryGetFormalBaseStat(EStat stat, out int value)
        {
            value = 0;
            if (!TryGetInitializedFormalAttributes(out AbilitySystemComponent abilitySystemComponent))
            {
                return false;
            }

            value = Mathf.RoundToInt(abilitySystemComponent.GetAttrBaseValue(
                FormalAttributeCatalog.AttributeSetCode,
                FormalAttributeCatalog.GetBaseAttributeCode(stat)));
            return true;
        }

        /// <summary>
        /// 从 FormalAttributeCatalog 读取当前属性。
        /// Health/Mana 和其它当前值都走同一正式 ASC 查询入口。
        /// </summary>
        private bool TryGetFormalCurrentStat(EStat stat, out int value)
        {
            value = 0;
            if (!TryGetInitializedFormalAttributes(out AbilitySystemComponent abilitySystemComponent))
            {
                return false;
            }

            value = Mathf.RoundToInt(abilitySystemComponent.GetAttrCurrentValue(
                FormalAttributeCatalog.AttributeSetCode,
                FormalAttributeCatalog.GetCurrentAttributeCode(stat)));
            return true;
        }

        /// <summary>
        /// 创建正式基础属性快照。
        /// 缺字段会被逐项报错，避免存档或 UI 拿到静默缺项的属性包。
        /// </summary>
        private Stats CreateFormalBaseStatsSnapshot()
        {
            Stats snapshot = new();
            foreach (FormalAttributeDefinition definition in FormalAttributeCatalog.Definitions)
            {
                snapshot[definition.Stat] = ReadFormalBaseStatOrReportFailure(definition.Stat);
            }

            return snapshot;
        }

        /// <summary>
        /// 创建正式当前属性快照。
        /// 主要服务存档、批量通知和战斗前快照，不作为常规单值读取路径。
        /// </summary>
        private Stats CreateFormalCurrentStatsSnapshot()
        {
            Stats snapshot = new();
            foreach (FormalAttributeDefinition definition in FormalAttributeCatalog.Definitions)
            {
                snapshot[definition.Stat] = ReadFormalCurrentStatOrReportFailure(definition.Stat);
            }

            return snapshot;
        }

        /// <summary>
        /// 创建战斗结算所需的最小属性快照。
        /// 伤害系统只拿攻击、防御、敏捷和幸运，避免依赖整份 Stats。
        /// </summary>
        private CombatStatSnapshot CreateFormalCombatStatSnapshot()
        {
            Stats currentStats = CreateFormalCurrentStatsSnapshot();
            return new CombatStatSnapshot(
                currentStats[EStat.PhysicalAttack],
                currentStats[EStat.MagicalAttack],
                currentStats[EStat.PhysicalDefense],
                currentStats[EStat.MagicalDefense],
                currentStats[EStat.Agility],
                currentStats[EStat.Luck]);
        }

        /// <summary>
        /// 写入正式当前属性。
        /// 运行时变化通过 Instant Modifier 改属性 BaseValue，再由 EX-GAS 重算 CurrentValue。
        /// </summary>
        private bool TrySetFormalCurrentStat(EStat stat, int value)
        {
            if (!TryGetFormalAbilitySystem(out AbilitySystemComponent abilitySystemComponent) ||
                abilitySystemComponent == null)
            {
                return false;
            }

            int attributeCode = FormalAttributeCatalog.GetCurrentAttributeCode(stat);
            int currentValue = Mathf.RoundToInt(abilitySystemComponent.GetAttrCurrentValue(
                FormalAttributeCatalog.AttributeSetCode,
                attributeCode));
            return FormalGameplayEffectResourceModifier.TryApplyCurrentStatDelta(
                       abilitySystemComponent,
                       stat,
                       value - currentValue,
                       minValue: null,
                       maxValue: null,
                       sourceAbilitySystem: null,
                       out _,
                       out int newValue) &&
                   newValue == value;
        }

        /// <summary>
        /// 注册正式当前属性变更事件。
        /// 只监听 current value after 事件，用来把角色自己发起的资源变化同步给 UI、死亡链和其它订阅者。
        /// </summary>
        protected void RegisterFormalAttributeEvents()
        {
            if (m_formalAttributeEventsRegistered ||
                !TryGetFormalAbilitySystem(out AbilitySystemComponent abilitySystemComponent) ||
                abilitySystemComponent == null)
            {
                return;
            }

            foreach (FormalAttributeDefinition definition in FormalAttributeCatalog.Definitions)
            {
                EStat stat = definition.Stat;
                int attributeCode = FormalAttributeCatalog.GetCurrentAttributeCode(stat);

                System.Action<float, float> currentHandler = (oldValue, _) => OnFormalCurrentValueChanged(stat, oldValue);
                m_formalCurrentValueChangedHandlers[stat] = currentHandler;

                GASEventCenter.RegisterOnAttrCurrentValueChangeAfter(
                    abilitySystemComponent.Cell,
                    FormalAttributeCatalog.AttributeSetCode,
                    attributeCode,
                    currentHandler);
            }

            m_formalAttributeEventsRegistered = true;
        }

        /// <summary>
        /// 注销正式属性事件。
        /// 对象禁用、销毁或复用时必须清掉委托缓存，避免旧角色继续收到 ASC 回调。
        /// </summary>
        protected void UnregisterFormalAttributeEvents()
        {
            if (!m_formalAttributeEventsRegistered ||
                !TryGetFormalAbilitySystem(out AbilitySystemComponent abilitySystemComponent) ||
                abilitySystemComponent == null)
            {
                return;
            }

            foreach (FormalAttributeDefinition definition in FormalAttributeCatalog.Definitions)
            {
                EStat stat = definition.Stat;
                int attributeCode = FormalAttributeCatalog.GetCurrentAttributeCode(stat);

                if (m_formalCurrentValueChangedHandlers.TryGetValue(stat, out System.Action<float, float> currentHandler))
                {
                    GASEventCenter.UnRegisterOnAttrCurrentValueChangeAfter(
                        abilitySystemComponent.Cell,
                        FormalAttributeCatalog.AttributeSetCode,
                        attributeCode,
                        currentHandler);
                }
            }

            m_formalCurrentValueChangedHandlers.Clear();
            m_formalAttributeEventsRegistered = false;
        }

        /// <summary>
        /// 立即重算正式 ASC 上所有当前属性。
        /// 供规则变更后主动刷新，不替代角色自己的属性快照发布流程。
        /// </summary>
        protected bool TryRecalculateFormalCurrentAttributesImmediately()
        {
            if (!TryGetFormalAbilitySystem(out AbilitySystemComponent abilitySystemComponent) ||
                abilitySystemComponent == null)
            {
                return false;
            }

            return abilitySystemComponent.Cell.Entity.TryRecalculateAttributeCurrentValue();
        }

        /// <summary>
        /// 立即重算单个正式当前属性。
        /// 用于局部属性依赖变化，避免每次都刷新整套 AttributeSet。
        /// </summary>
        protected bool TryRecalculateFormalCurrentAttributeImmediately(EStat stat)
        {
            if (!TryGetFormalAbilitySystem(out AbilitySystemComponent abilitySystemComponent) ||
                abilitySystemComponent == null)
            {
                return false;
            }

            AttributeHelper.RecalculateCurrentValue(
                abilitySystemComponent.Cell.Entity,
                FormalAttributeCatalog.AttributeSetCode,
                FormalAttributeCatalog.GetCurrentAttributeCode(stat));
            return true;
        }

        /// <summary>
        /// 包装一次整组快照覆盖。
        /// 批量写入期间屏蔽单字段当前值事件，完成后由调用方按完整前置快照发布一次变化。
        /// </summary>
        private void ExecuteFormalSnapshotOverride(System.Action mutation)
        {
            if (mutation == null)
            {
                return;
            }

            bool previousSuppressionState = m_suppressFormalCurrentValueEvents;
            m_suppressFormalCurrentValueEvents = true;
            try
            {
                mutation();
            }
            finally
            {
                m_suppressFormalCurrentValueEvents = previousSuppressionState;
            }
        }

        /// <summary>
        /// 接收正式当前属性变化回调。
        /// 外部 GAS 规则、正式伤害和资源消耗都必须回流到 CharacterBase 通知链，UI 和死亡链只订阅这一层。
        /// </summary>
        private void OnFormalCurrentValueChanged(EStat stat, float oldValue)
        {
            if (m_suppressFormalCurrentValueEvents)
            {
                return;
            }

            Stats previousCurrentStats = CreateCurrentStatsSnapshot();
            previousCurrentStats[stat] = Mathf.RoundToInt(oldValue);
            NotifyCurrentStatsChanged(previousCurrentStats);
        }

        /// <summary>
        /// 读取正式基础属性，失败时输出明确错误。
        /// 返回 0 只是错误后的保底值，不代表属性真实为 0。
        /// </summary>
        private int ReadFormalBaseStatOrReportFailure(EStat stat)
        {
            if (TryGetFormalBaseStat(stat, out int value))
            {
                return value;
            }

            Debug.LogError($"[{nameof(CharacterBase)}] 正式基础属性快照缺失字段 {stat}，当前角色无法从正式属性真相读取该字段。", this);
            return 0;
        }

        /// <summary>
        /// 读取正式当前属性，失败时输出明确错误。
        /// 返回 0 只是错误后的保底值，不允许调用方当作成功结果解释。
        /// </summary>
        private int ReadFormalCurrentStatOrReportFailure(EStat stat)
        {
            if (TryGetFormalCurrentStat(stat, out int value))
            {
                return value;
            }

            Debug.LogError($"[{nameof(CharacterBase)}] 正式当前属性快照缺失字段 {stat}，当前角色无法从正式属性真相读取该字段。", this);
            return 0;
        }

        /// <summary>
        /// 批量写入正式 ASC 属性快照，并发布基础/当前属性变化。
        /// 启动缓冲窗口仍打开时同步镜像一份，保证 Awake 初始化过程中旧入口读取到同一套值。
        /// </summary>
        private void ApplyStatsSnapshotToFormalAbilitySystem(
            AbilitySystemComponent abilitySystemComponent,
            Stats baseStats,
            Stats currentStats,
            Stats previousBaseStats,
            Stats previousCurrentStats)
        {
            if (abilitySystemComponent == null)
            {
                return;
            }

            Stats safeBaseStats = baseStats ?? new Stats();
            Stats safeCurrentStats = currentStats ?? safeBaseStats;

            ExecuteFormalSnapshotOverride(() =>
            {
                foreach (FormalAttributeDefinition definition in FormalAttributeCatalog.Definitions)
                {
                    int currentAttributeCode = FormalAttributeCatalog.GetCurrentAttributeCode(definition.Stat);
                    int baseAttributeCode = FormalAttributeCatalog.GetBaseAttributeCode(definition.Stat);

                    if (baseAttributeCode == currentAttributeCode)
                    {
                        abilitySystemComponent.SetAttrBaseValueAndRecalculate(
                            FormalAttributeCatalog.AttributeSetCode,
                            baseAttributeCode,
                            safeBaseStats[definition.Stat]);
                        continue;
                    }

                    abilitySystemComponent.SetAttrBaseValueAndRecalculate(
                        FormalAttributeCatalog.AttributeSetCode,
                        currentAttributeCode,
                        safeCurrentStats[definition.Stat]);

                    abilitySystemComponent.SetAttrBaseValueAndRecalculate(
                        FormalAttributeCatalog.AttributeSetCode,
                        baseAttributeCode,
                        safeBaseStats[definition.Stat]);
                }
            });

            if (IsAttributeBootstrapReadWindowOpen())
            {
                m_attributeBootstrapBuffer.MirrorFromFormalSnapshots(safeBaseStats, safeCurrentStats);
            }

            PublishStatChanges(previousBaseStats, previousCurrentStats);
        }

        /// <summary>
        /// 按基础属性变化量平移当前属性。
        /// 这样升级或装备变化会保留“当前缺了多少血/蓝”的运行时状态。
        /// </summary>
        private static Stats CreateAdjustedCurrentStatsSnapshot(Stats previousBaseStats, Stats previousCurrentStats, Stats nextBaseStats)
        {
            Stats safePreviousBaseStats = previousBaseStats ?? new Stats();
            Stats safePreviousCurrentStats = previousCurrentStats ?? new Stats();
            Stats safeNextBaseStats = nextBaseStats ?? new Stats();
            return safePreviousCurrentStats + (safeNextBaseStats - safePreviousBaseStats);
        }

        /// <summary>
        /// 规范化待清除的效果类型列表。
        /// 去重后再匹配，避免一次 Cleanse 对同一类型重复扫描。
        /// </summary>
        private static EEffectType[] NormalizeTemporalEffectTypes(EEffectType[] effectTypes)
        {
            if (effectTypes == null)
            {
                return System.Array.Empty<EEffectType>();
            }

            System.Collections.Generic.HashSet<EEffectType> uniqueEffectTypes = new();
            foreach (EEffectType effectType in effectTypes)
            {
                uniqueEffectTypes.Add(effectType);
            }

            if (uniqueEffectTypes.Count == 0)
            {
                return System.Array.Empty<EEffectType>();
            }

            EEffectType[] normalizedEffectTypes = new EEffectType[uniqueEffectTypes.Count];
            uniqueEffectTypes.CopyTo(normalizedEffectTypes);
            return normalizedEffectTypes;
        }

        /// <summary>
        /// 从当前角色持有的持续效果 runtime key 中筛出可清除目标。
        /// 只匹配能投影展示类型的正式持续效果，避免误删没有类型语义的内部效果。
        /// </summary>
        private int[] CollectOwnedTemporalEffectRuntimeKeysForCleanse(
            int[] runtimeKeys,
            System.Collections.Generic.HashSet<EEffectType> targetEffectTypes)
        {
            if (runtimeKeys == null ||
                runtimeKeys.Length == 0 ||
                targetEffectTypes == null ||
                targetEffectTypes.Count == 0)
            {
                return System.Array.Empty<int>();
            }

            System.Collections.Generic.List<int> matchedRuntimeKeys = new(runtimeKeys.Length);
            foreach (int runtimeKey in runtimeKeys)
            {
                if (!TryGetOwnedTemporalEffect(runtimeKey, out ITemporalEffect effect) ||
                    effect is not ATemporalEffect temporalEffect ||
                    !temporalEffect.TryGetPresentationEffectType(out EEffectType effectType) ||
                    !targetEffectTypes.Contains(effectType))
                {
                    continue;
                }

                matchedRuntimeKeys.Add(runtimeKey);
            }

            return matchedRuntimeKeys.ToArray();
        }

        /// <summary>
        /// 捕获可持久化的持续效果运行时状态。
        /// 只有同时具备展示状态和持久化状态的 effect 才会进入存档快照。
        /// </summary>
        private CharacterTemporalEffectRuntimeStateData CreateOwnedTemporalEffectRuntimeState(ITemporalEffect effect)
        {
            if (effect is ATemporalEffect temporalEffect &&
                temporalEffect.TryGetPresentationState(out _) &&
                effect is ITemporalEffectRuntimeStateCarrier runtimeStateCarrier &&
                runtimeStateCarrier.TryCapturePersistedState(out TemporalEffectPersistedState persistedState))
            {
                return CharacterTemporalEffectRuntimeStateData.Create(temporalEffect, persistedState);
            }

            return null;
        }

        /// <summary>
        /// 将角色运行时已拥有的正式能力规则同步到能力槽组件。
        /// 用于 ASC 初始化完成后，把读档或来源化能力恢复到可装备/可触发的角色层视图。
        /// </summary>
        private void SyncFormalAbilityRuleRosterFromRuntime()
        {
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet))
            {
                foreach (int formalGasAbilityCode in CreateOwnedFormalGasAbilityCodeSnapshot())
                {
                    abilitySet.RegisterFormalGasAbilityRule(formalGasAbilityCode);
                }

            }
        }
    }
}
