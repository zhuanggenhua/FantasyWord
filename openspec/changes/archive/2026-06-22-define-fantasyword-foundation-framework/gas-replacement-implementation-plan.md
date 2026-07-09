# GAS 替换实施提案

> 本文回答的不是“GAS 好不好”，而是“在当前仓库里，GAS 若作为正式胜者，应该怎么替换，才不会再造第二真相”。
> 本文只定义框架替换路线，不迁具体技能业务，不新增 `EXGASAdapter/GASFacade/StatsToAttributeWrapper`。

## 1. 当前事实

| 项 | 当前事实 |
| --- | --- |
| 当前属性真相 | 当前正式读取、资源写入口、属性通知、零血死亡判定与当前值存档已优先走 `CharacterBase + FormalGameplayAttributeSet + ASC`；旧 `AttributeBootstrapBuffer + Stats/currentStats` 只保留 bootstrap 缓冲、旧档导入、正式镜像回填和 `Awake` 期间一次性的 bootstrap 读取窗口 |
| 当前资源语义入口 | `CharacterBase.GetCurrentHealth/GetCurrentMana/ModifyCurrentHealth/ModifyCurrentMana/...` |
| 当前最小战斗读取口 | `CombatStatSnapshot` |
| 当前伤害来源合同 | `IDamageSource` |
| 当前门禁 | `Invoke-FoundationStaticGate.ps1` 当前要求“白名单外 GAS 运行时引用为 0”；允许文件现已追平到当前正式 GAS owner 边界，包括 `FormalGameplayAttributeSet.cs`、`FormalGameplayEffectDamageHelper.cs`、`CharacterBase.GASRuntime.cs`、`CharacterBase.Resources.cs`、`CharacterBase.StateApi.cs`、`CharacterAbilitySet.FormalRules.cs` 与现役 formal temporal effect builder / effect 文件，最新结果仍应解释为 `GameCoreGasRuntimeReferenceHitCount = 0` 代表白名单外 0 命中 |
| 当前 EX-GAS 真实形态 | 插件本体提供 `AbilitySystemComponent`、`AttributeSet`、`GameplayEffect`、`AbilityAsset`，并带一个内部全局调度器 `GameplayAbilitySystem.GAS` 与隐藏 `GasHost` |
| 当前第一刀已落地内容 | 已新增 `FormalGameplayAttributeSet`，并由 `CharacterBase.GASRuntime` 在角色实体内准备 ASC、初始化 AttributeSet，再把现有基础/当前属性快照同步进 ASC |
| 当前第二刀已落地内容 | `CharacterBase` 的 `GetStatValue/GetCurrentStatValue/GetCurrentHealth/GetCurrentMana/CreateCombatStatSnapshot` 等正式读取口，以及 `ModifyCurrentHealth/ModifyCurrentMana/ModifyCurrentStat` 这组正式资源/属性写入口，当前都已优先改到 ASC |
| 当前第三刀已落地内容 | `CharacterBase` 现已重新自己持有基础/当前属性通知、零血死亡判定与当前值存档/读档入口；UI、死亡链和当前值落盘不再依赖旧 `AttributeBootstrapBuffer` 的监听与写盘 API |
| 当前第三刀补强已落地内容 | 当时的回退路径已经收回 `CharacterBase` 正式通知与死亡链；`2026-06-21` 又继续把读取 fallback 收紧为仅限 `Awake` bootstrap 窗口；旧 `AttributeBootstrapBuffer` 已进一步压成“快照缓冲 + base->current 联动 + 正式镜像回填 + 启动窗口临时读取” |
| 当前生命周期补强已落地内容 | `Movable.OnDisable()` 现已开放为可覆写钩子；`CharacterBase` 禁用时会先收掉临时无敌、打断能力实例并清空项目侧持续效果 runtime；当前读档前的旧 live 效果回滚也已收回 `CharacterBase.Persistence.LoadOwnedTemporalEffects(...)`，避免对象池复用或重复读档残留旧动作锁与旧速度修饰 |
| 当前生命周期 spec 索引补强 | EX-GAS `AbilitySystemComponent.OnDisable()` 会清空插件侧 `GameplayEffectContainer`；`CharacterBase.CleanupOwnedTransientRuntimeState()` 现在同步清空项目侧 `m_formalTemporalGameplayEffectSpecs` 活动索引，避免对象池复用后继续持有已经不在 ASC 内的旧 `GameplayEffectSpec` 引用。这一步只清活动 spec 索引，不清从资产派生的规则缓存，也不改变能力 roster 所有权 |
| 当前读档恢复补强已落地内容 | 持续效果现已新增 `RestoreRuntimeState(...)` 恢复合同；控制类与速度类效果会在读档后重建运行时句柄；`CharacterBase.Persistence` 现在会在恢复正式 effect 句柄后，立即把对应 formal `GameplayEffectSpec` 重新挂回 ASC，并按 persisted `remainingDuration` 校正 spec 剩余时长；旧 `legacyLockedActions/legacySpeedModifiers` 兼容字段已删除，读档恢复只认正式 runtime state |
| 当前动作锁/移速句柄新增进展 | `CharacterActionStateRuntime` 现已新增按 `runtimeKey` 持有的持续效果动作锁与移速修饰字典；`TemporalControlEffect/TemporalSpeedModifierEffect` 也已改成通过 `CharacterBase.ApplyTemporalActionLockRule(...)`、`ApplyTemporalMoveSpeedRule(...)` 这组正式入口驱动恢复和移除，不再把不透明 handle key 私藏在 effect 自己的运行时字段里 |
| 当前存档协议新增进展 | `CharacterBaseDataBlock` 当前只保留 `abilityRuntimeStates` 与 `temporalEffectRuntimeStates` 这两条正式恢复快照；`legacyAbilityDataBlocks/legacyTemporalEffects/legacyLockedActions/legacySpeedModifiers` 兼容字段与对应导入分支已从正式协议中删除。角色能力与持续效果读档现在只认 formal runtime state，不再保留旧 payload 迁移入口 |
| 当前持续效果 persisted-state 新增进展 | `ITemporalEffect` 现已新增 `TemporalEffectPersistedState + ITemporalEffectRuntimeStateCarrier`；6 种现役持续效果都已改为“类型 + 最小 persisted state”恢复，`CharacterTemporalEffectRuntimeStateData` 顶层当前只保留 `effectTypeName + formalGameplayEffectAssetGuid/name + runtimeState` 这组编排元数据，`stackableEffectId/duration/remainingDuration` 等共享状态已收回 `TemporalEffectPersistedState`，不再保留旧 `ITemporalEffect[]` 迁移入口 |
| 当前能力 runtime-state 新增进展 | `CharacterAbilityRuntimeStateData` 现已只保留稳定能力表引用、对象状态、通用冷却、武器执行层最小持久状态和 `extraRuntimeState`；`hasActiveRuntimeState` 这类脱离 formal lifecycle 的历史布尔位已退场，formal runtime state 不再继续携带 `legacyRuntimeData`，旧 `legacyAbilityDataBlocks` 迁移入口也已删除。`2026-06-20` 本轮又继续把武器执行状态限制为“只保存弹匣余量这类可持续执行层事实”，并把 `WeaponExecutionData` 本身压成仅含 `currentAmmoLoaded`，不再让半段施法、半段换弹、输入缓冲或忙碌态字段继续挂在持久化协议上。 |
| 当前 GAS 映射协议现态 | `AbilitySheet` 现已直接持有 `formalAbilityAsset`，`ATemporalEffect` / `ITemporalEffect` 现已直接持有并公开 `TryGetFormalGameplayEffectAsset(...)`；持续效果 clone 共享状态也会一起复制正式映射，不再丢字段。`CharacterTemporalEffectRuntimeStateData` 当前也已把 `formalGameplayEffectAssetGuid + formalGameplayEffectAssetName` 真正接进恢复链：`ATemporalEffect.RestoreFormalRuntimeState(...)` 会优先按 GUID 恢复正式 `GameplayEffectAsset`，运行时拿不到 GUID 入口时再按资产名兼容回退，避免读档后 formal spec 因映射字段丢失而整条断开 |
| 当前 GAS 资产层现态 | 正式非业务模板链已经落在 `Assets/GameData/GameCore/GAS/`：`正式能力表模板.asset -> 正式时间轴能力模板.asset -> 正式持续效果模板.asset`，并且能力表中的模板持续效果已绑定正式 `GameplayEffectAsset`，效果资产也带 `effect.buff` 展示分类。`FormalGasMappingAudit` 已具备 Unity 内审计入口，本轮又把这条最小资产链纳入 `Invoke-FoundationStaticGate.ps1` 离线门禁；因此当前阻塞不再是“正式资产链为空”，而是后续真实 Ability/Effect 数据、live runtime、UI 读取口和旧档迁移协议继续收口。 |
| 当前剩余重复真相 | `CharacterAbilitySetRuntime` 仍持有能力实例集合、武器执行状态持久化与能力旧档导入；主动/被动能力投影查询、冷却快照读取和触发入口解析现已收回 `CharacterBase` 正式拥有者，但 formal `AbilityAsset` 规则 roster、已映射能力的冷却、激活标签前提、cost 检查/应用、active lifecycle，以及 `CancelAbilitiesWithTags -> 执行层中断` 这条取消链都已开始优先走 GAS。`CharacterTemporalEffectRuntime` 现已继续收成“持续效果执行壳注册表”，而持续效果写盘、旧档迁移导入、formal runtime state 重建编排和 loaded block 归一化都已收回 `CharacterBase.Persistence`，完成副作用、展示移除、formal spec 注销，以及每帧推进与完成裁决都已收回 `CharacterBase.StateApi`；与此同时 `GameplayEffectContainer` 也已经在插件侧维护持续时间、叠层、移除规则与读档后重新挂回的 formal spec。`2026-06-18` 这几刀又继续把重复持责往 GAS 收：先把“mapped formal effect 在 formal spec 缺席后还能靠旧容器残留存活”这层冲突缩掉，再把 mapped effect 的每帧剩余时长同步改成优先跟随 formal spec，把 control/speed 两类句柄时机收成更 formal-driven，让 `Cleanse` 对已映射 effect 改成 formal runtimeKey 命中优先、legacy fallback 只处理 unmapped 或无 ASC 回退，并把已映射 effect 的 stack/consume 裁决改成 formal stacking 优先，同时在 formal spec 已被容器移除时清掉项目侧脏缓存；本轮又继续把 mapped effect 写盘时的 `runtimeKey / duration / remainingDuration` 导出优先权收回 live formal spec，并在角色正式写盘前补一次即时对账，不再把 formal spec 已退场后的 stale mapped effect 写进存档。随后又把“formal runtime state 如何重建 effect 实例”“旧档 raw effect 如何优先归一回 formal runtime state”这两段恢复工厂职责收回 `ATemporalEffect.TryCreateFromFormalRuntimeState(...)`，并把最终恢复编排收回 `CharacterBase.Persistence`；`CharacterTemporalEffectRuntime` 不再直接反射建实例、手动恢复 runtime state 或把旧数据块归一化。当前 `m_temporalEffectExecutionShells` 也已从无结构 `List` 收成按 `runtimeKey` 排序的执行壳注册表，GAS 侧叠层命中不再线性扫描旧列表找 effect，而是直接按 formal spec 的 `runtimeKey` 命中注册表。本轮又继续把 fallback 展示聚合、legacy 净化筛选、formal 缺席回滚筛选，以及 stack 命中裁决都从 `CharacterTemporalEffectRuntime` 收回 `CharacterBase`，旧容器现在不再自己决定这些语义命中，只保留执行壳注册表增删与按 runtimeKey 查询。旧 effect 壳不再负责决定这些共享时序字段，角色容器也开始退出 effect 类型工厂职责。但 `m_temporalEffectExecutionShells` 本身仍未退场，所以这块依旧是当前最主要的重复持责点。按现役 6 种效果复核后，当前 `m_temporalEffectExecutionShells` 实际混着几种残余执行职责：真正需要逐帧 tick 的壳、只需要本地寿命推进的壳，以及叠加 formal-driven 句柄后果的壳；而且 `TemporalSpeedModifier` 是否需要 legacy tick 还取决于自定义曲线。当前这层差异现已写成 `TemporalEffectLegacyRuntimeTraits` 正式合同，所以下一步不能把它误删成“容器直接归零”，而是要继续把它从规则真相压成最小执行壳注册表。 |
| 当前最新补充 | `Cleanse` 的 mapped formal effect 回收继续从旧容器语义筛选里剥离：formal 规则移除返回的 `runtimeKey` 现在会先固定成 `int[]`，再交给 `CharacterTemporalEffectRuntime.RemoveEffectsByRuntimeKeySnapshot(...)` 摘执行壳；旧容器不再需要为了 mapped formal 清理先枚举整份 live 列表再判断命中。随后又把 legacy fallback 筛选口改成“只有无 formal 移除入口时才允许 mapped effect 回退旧分类”，不再把 formal 移除返回的 runtimeKey 重新混入 legacy 分类判断；同时执行壳注册表摘除也不再按对象引用反扫字典，只认 effect 自己的稳定 `runtimeKey`。本轮又把 formal 缺席回滚链同步压成 runtimeKey 定向：`ReconcileOwnedTemporalEffectsWithFormalRuntime()` 只收集 stale mapped effect 的 key 快照，再调用 `RemoveEffectsByRuntimeKeySnapshot(...)`，旧的 mapped effect 对象数组和 `Func<ITemporalEffect, bool>` 谓词退场。随后继续把 legacy cleanse 与每帧完成退场也改成只收集 `runtimeKey` 快照，并删除 `CharacterTemporalEffectRuntime.RemoveEffects(IEnumerable<ITemporalEffect>)` 对象数组移除口；再补 `GetExecutionShellRuntimeKeySnapshot()`，让 `GASRuntime` 的 legacy cleanse fallback 与 formal 缺席对账先拿 key 快照、再用 `TryGetExecutionShellByRuntimeKey(...)` 定向查询单个执行壳，不再直接消费整份 `ITemporalEffect[]`。后续又删除 `GetExecutionShellsSnapshot()` 本身，并把旧注册表的移除入口从 `IEnumerable` 改成数组快照：`RemoveEffectsByRuntimeKeySnapshot(int[])`。随后删除 `ClearEffects()`，角色禁用和读档前清理也改为 key 快照摘除。最新几刀已删除 `ContainsEffect(...)`、`RemoveEffectPrematurely(...)`、对象反查 helper、`CharacterBase.RemoveTemporalEffectPrematurely(...)` 和 `ReplaceExecutionShellSnapshot(ITemporalEffect[])` 这组对象式/整表式注册表 API；读档恢复由 `CharacterBase.Persistence` 按 `runtimeKey` 去重后逐个 `AddEffect(...)` 注册执行壳。`2026-06-21` 又继续把 legacy cleanse 对 fallback 合同的读取缩成最小分类口：`CharacterBase.GASRuntime.ShouldRemoveTemporalEffectDuringCleanse(...)` 现在只消费 `TryGetLegacyFallbackEffectType(...)`，不再为了判断 `Buff/Debuff` 先拼整份 `TemporalEffectLegacyFallbackState`。同日后续又继续把 fallback 共享合同本身缩成“只保留展示 payload”：`TemporalEffectLegacyFallbackState` 不再携带 `effectType`，UI 快照改为分别读取 `TryGetLegacyFallbackEffectType(...)` 和 `TryGetLegacyFallbackState(...)` 这两份最小合同；现役 9 个持续效果的 `BuildLegacyFallbackState()` 也不再顺手回答分类。这样 unmapped fallback 至少先退出了“分类 + 展示混在同一份共享对象”这层重复语义。随后又把 legacy 描述投影也压成单一出口：`ATemporalEffect.CreateLegacyFallbackDescription(...)` 现在统一承担名字/时长/细节拼装，`AbilitySheet` 经 `effect.GenerateDescription()` 和 `CharacterBase.StateApi` 的效果栏快照都复用同一条规则，不再各自再拼一份 fallback 文案。最新复核：`Invoke-FoundationStaticGate.ps1 -AsJson` 与 `npx openspec validate define-fantasyword-foundation-framework --strict` 继续通过；当前仍不是删除 `m_temporalEffectExecutionShells`，而是继续把它压成“单个注册、按 key 查询、按 key 摘除”的执行壳注册表。 |
| 当前最新补充 2 | mapped formal effect 的时序同步边界本轮又继续收口。[ATemporalEffect.SyncRuntimeTimingFromFormalRule(...)](/C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/ATemporalEffect.cs) 现在在 formal spec 已提供 `duration/remainingDuration` 的情况下，不再默认执行 legacy `OnUpdate()`；只有 `IFormalRuleDrivenTemporalEffectRuntime` 句柄型 effect 还会在这里刷新 formal runtime 后果。这样 `TemporalHeal/TemporalDamage/TemporalRestoreMana` 这类已映射 formal `GameplayEffectAsset` 的 effect，不会在 GAS 时序已经成为真相时再额外跑一份旧 tick 结算。当前仍不是删除 legacy fallback：`Update()` 里的 `AdvanceLegacyLifetime + OnUpdate()` 只保留给 unmapped 或未被 formal sync 接管的 legacy 路径。 |
| 当前最新补充 3 | `TemporalStatModifierEffect` 的 current-stat 直接改写口本轮也已继续让位给 formal 规则。不过这里真正成立的 owning-shape 不是“句柄型 runtime consequence”，而是“只要 formal 已映射且 ASC 存在，规则后果就不该再由 legacy 当前属性直改回答”。[ATemporalEffect.cs](/C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/ATemporalEffect.cs) 与 [CharacterBase.GASRuntime.cs](/C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.GASRuntime.cs) 因此新增了独立的 mapped-formal ownership helper；[TemporalStatModifierEffect.cs](/C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalStatModifierEffect.cs) 的 `OnApply()` 与 `OnCompleted()` 现在在这条 helper 命中时会直接跳过 legacy `ModifyCurrentHealth/ModifyCurrentMana/ModifyCurrentStat` 与撤销逻辑，因此已映射 formal `GameplayEffectAsset` 的属性增减不再由 GAS 和旧 effect 各改一遍。当前仍不是删除 `TemporalStatModifierEffect`：unmapped 或无 formal runtime 的 legacy 路径保留，资源裁剪与 fallback 语义也仍留在旧 effect 壳内。 |
| 当前最新补充 4 | formal spec 的 live 读取边界本轮又继续收成统一快照。[CharacterBase.GASRuntime.cs](/C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.GASRuntime.cs) 现已新增 `CreateLiveFormalTemporalEffectSpecSnapshot(...)` 与 `ContainsLiveFormalTemporalEffectSpec(...)`，让展示投影、spec 查找、写盘 runtimeKey 收集、formal 清理和叠层目标查找都先消费同一份 formal spec 快照，而不是在多个语义入口里各自直接枚举 `GameplayEffectContainer.GameplayEffects()`。这一步收掉的是“formal live truth 从哪读”的边界漂移，不是新增项目侧容器，也不是把 `m_formalTemporalGameplayEffectSpecs` 升格成第二真相。`2026-06-21` 本轮又继续把 detached formal effect 的双账本压成单一注册表：shell-less formal effect 的“UI 仍需认这个 runtimeKey”与“是否还要保留可选 runtime state 以刷新本地句柄后果”，现在统一落在 `m_detachedFormalTemporalRuntimeRegistry` 一处；不再拆成 `HashSet runtimeKey` + `Dictionary runtimeKey -> runtimeState` 两份主键所有权。同轮 formal effect 的 stack 刷新链也继续去对象化：`TryFindFormalTemporalStackTarget(...)` 现在只返回目标 `runtimeKey`，`RefreshFormalTemporalEffectRuleOnStack(...)` 与 detached formal 每帧后果同步统一复用 `RefreshOwnedFormalTemporalEffectRuntimeConsequences(...)`，按 `runtimeKey + live formal spec` 刷新时序与本地句柄后果，不再把 `ITemporalEffect` live 镜像对象继续往上传。 |
| 当前仍未切换的部分 | 旧 `AttributeBootstrapBuffer` 仍以镜像方式保留一份过渡快照；持续效果的 `Buff/Debuff` 分类净化、展示 payload 真相、能力触发规则、更高级执行态联动与对象池回收边界还没完全切到 GAS。换弹不再作为“必须切进 GAS 的规则缺口”表述：当前 `CharacterBase.ReloadAbility(...) -> ActiveAbilityBase.Reload() -> WeaponExecutionRuntime.RequestReload()` 只保存弹匣、换弹计时和执行状态，属于 TopDown 吸收后的动作执行层边界；它需要被文档和门禁保护，不能误升格为 GAS 规则真相。现役持续效果整对象 payload 已不再是正式协议，mapped effect 的 legacy 展示 fallback 现在也已被彻底关闭；同时，unmapped fallback 的展示和净化现在都已由 `CharacterBase` 直接消费 `TryGetLegacyFallbackState(...)` 返回的共享合同，不再让 `ATemporalEffect` 额外回答展示快照或第二个 matcher。`ITemporalEffect` 公共接口不再承诺 fallback 展示/净化 API，旧 `info` 展示口也已退场，容器外层不再需要独立 `effectType` 读取协议。能力授予 / 压制 / 替换 这三类持续效果的 apply/remove 现也已改成 `IFormalRuleDrivenTemporalEffectRuntime` 正式驱动，legacy `OnApply/OnCompleted` 只剩 formal 规则未接管时的回退职责；对应 detached formal runtime registry 现在也只让真正需要每帧刷新的 tracked runtime 继续进入 `SyncDetachedFormalTemporalRuntimeConsequences()`，能力型 detached effect 仅保留写盘和最终撤回追踪。现役持续效果现在只负责 `BuildLegacyFallbackState()`，而 fallback/snapshot/UI 之间传递的展示数据也已从整颗 `TermDefinition` 收成专用 `EffectPresentationInfo`；fallback 共享合同只按当前 effect 字段即时生成，不再写进 `TemporalEffectPersistedState` 或实例缓存。当前仍未切走的，是这份共享合同本身仍由旧 effect 字段生成，历史/未审计效果若继续沿用旧 payload 语义也仍需逐个专项清理；旧档兼容字段本体则已从 `CharacterBase.Contracts/Persistence` 正式协议删除。 |

## 2. 最终裁决

| 职责 | 最终保留方 | 理由 |
| --- | --- | --- |
| 属性真相 | EX-GAS `AttributeSet + AbilitySystemComponent` | 复杂开放世界与卡牌模式都需要可扩展的属性、标签、叠层和冷却规则 |
| 效果规则真相 | EX-GAS `GameplayEffectContainer` | 持续时间、叠层、标签移除与激活态应由 GAS 统一回答；`CharacterBase` 最终只保留实体公开查询、净化语义、展示投影与表现触发，不再自持第二份 live 规则列表 |
| 能力规则真相 | EX-GAS `Ability/Cost/Cooldown/Tag` | 不能一边用 TopDown 权限，一边用旧 Stats 扣蓝和记冷却 |
| 动作执行与手感 | 继续保留 `GameCore` 已吸收的 TopDown 闭包 | 攻击输入、武器状态机、命中窗口、受击反馈的“怎么打”继续保留现有成熟实现 |
| 表现反馈 | `GameplayFeedbackSet + GameRuntimeEvents` | GAS 只负责规则结果，不拥有表现层 |

这意味着最终不是“TopDown vs GAS 二选一”，而是：

| 层 | 正式真相 |
| --- | --- |
| 规则层 | GAS |
| 执行层 | `GameCore` 已吸收的 TopDown 动作闭包 |
| 表现层 | `GameplayFeedbackSet` |

## 3. 必须避免的错误路线

| 禁止项 | 原因 |
| --- | --- |
| `GameManager.GasSystem`、`GameManager.AbilitySystem` | 会把实体级属性真相伪装成项目级静态入口 |
| `EXGASAdapter/GASFacade/StatsToAttributeWrapper` | 会把旧 Stats 和新 GAS 永久并行 |
| 只让新技能走 GAS，旧技能继续扣 `currentStats` | 同一角色会出现双扣蓝、双冷却、双效果 |
| UI 继续一半读 `AttributeBootstrapBuffer`、一半读 ASC | 玩家看到的就不是单一真相 |
| 存档同时落 `currentStats` 和 GAS 原值 | 读档会出现谁覆盖谁的问题 |
| 把插件内部 `GasHost` 当项目正式生命周期宿主 | 正式生命周期仍必须由 `GameManager + CharacterBase` 持有 |

## 4. 生命周期裁决

### 4.1 正式拥有者

| 对象 | 正式拥有者 |
| --- | --- |
| `AbilitySystemComponent` 组件引用 | 角色实体自身，优先落在 `CharacterBase` 正式闭包 |
| ASC 初始化参数 | `CharacterBase/Hero/Monster` 当前正式数据与装备/成长结果 |
| ASC 启用/停用/清理时机 | 跟随角色实体启用、禁用、销毁和对象池复用 |
| GAS Tick | 插件内部 `GameplayAbilitySystem.GAS` 继续承担，但不升格为项目真相源 |

### 4.2 具体约束

| 场景 | 要求 |
| --- | --- |
| 角色生成 | 正式角色 prefab 直接挂 `AbilitySystemComponent`，不额外造项目包装组件 |
| 角色启用 | `CharacterBase` 在自身生命周期里准备 ASC 所需 AttributeSet、BaseTags、BaseAbilities |
| 角色禁用 | 必须清理 GameplayEffect、取消能力；项目侧仍保留的持续效果、动作锁、速度修饰和临时无敌也要同步收尾，避免对象池复用把上一个实体状态带到下一个实体 |
| 角色销毁 | 仍由角色拥有者负责，不把 GAS host 当成销毁入口 |
| 场景切换 | 允许插件内部 `GasHost` 常驻，但不允许项目代码改为依赖它来判断“当前角色/当前世界” |

## 5. 替换顺序

### 阶段 A：先把读取口固定住，再切真相

| 动作 | 当前落点 | 结果 |
| --- | --- | --- |
| 保持 `FormalAttributeCatalog` 稳定 ID | `FormalAttributeCatalog.cs` | 调用方不直接猜 GAS 字段名 |
| 保持资源语义入口 | `CharacterBase.Resources.cs` | 外部继续只读 `GetCurrentHealth/GetCurrentMana/...` |
| 保持最小战斗快照 | `CombatStatSnapshot` | 伤害和命中读取口不直接碰 ASC 细节 |
| 保持伤害来源合同 | `IDamageSource` | 规则层替换时不影响战斗消费方边界 |
| 已落实体级 ASC 挂点 | `CharacterBase.GASRuntime.cs` | 角色实体成为正式 ASC 拥有者，不需要 `GameManager.GasSystem` 或项目包装层 |
| 已落正式 AttributeSet 形状 | `FormalGameplayAttributeSet.cs` | `core.health/core.mana/...` 已有明确 GAS 字段落点 |

### 阶段 B：属性真相切换

| 动作 | 说明 |
| --- | --- |
| 建立正式 AttributeSet | 以 `attribute-field-mapping.md` 的稳定 ID 为准，覆盖生命、法力、物攻、法攻、物防、法防、敏捷、幸运 |
| `CharacterBase` 公开读取口改为读 ASC | `GetStatValue/GetCurrentStatValue/GetCurrentHealth/...` 继续保留，但内部改到 ASC |
| `CombatStatSnapshot` 改由 ASC 生成 | 快照保留，底层来源替换 |
| UI 不改调用面，只改内部来源 | 避免全仓 UI 同时碰 GAS 细节 |

这一步完成后：

- `AttributeBootstrapBuffer` 不再是正式属性真相。
- 它最多只允许保留为旧档导入、正式镜像回填和 `Awake` 期间一次性的 bootstrap 缓冲，而不是继续承担读取、通知或存档拥有权。
- 一旦最终旧档迁移和无 ASC 过渡都退出，就应退场，而不是长期共存。

### 阶段 C：效果真相切换

| 动作 | 说明 |
| --- | --- |
| 已映射持续效果的规则真相迁到 GAS | 周期、叠层、标签移除、持续时间统一走 `GameplayEffect` |
| `CharacterTemporalEffectRuntime` 先退成实体公开投影 | 不再自己维护 `m_effects` 作为规则真相；只允许保留 `Cleanse/展示快照/表现触发/读档挂回` 这组角色公开入口，直到这些入口也能直接投影自 GAS |
| 速度/控制类效果的运行时句柄恢复并入正式效果生命周期 | 当前已先把句柄主键收回 `CharacterBase`，由持续效果 `runtimeKey` 直接驱动动作锁和速度修饰；`2026-06-18` 最新又把 control/speed 这两类 effect 的 apply/restore/refresh/remove 时机继续往 formal 规则链收口：formal rule 已接上时，旧 effect 不再自己决定这些句柄时机，而改由 `CharacterBase.GASRuntime` 在 formal 规则挂接、叠层刷新与时长同步时触发对应运行时后果；同轮 mapped effect 的叠层消费也已改成 formal stacking 优先，不再先走 legacy `stackableEffectId`。当前仍未完成的部分是 `m_effects` live 集合本体、`Cleanse` 计数和 unmapped fallback |
| 表现仍从 `GameplayFeedbackSet` 发 | GAS 只给“发生了什么”，不直接播表现 |

### 阶段 C 当前不能硬删的 4 个缺口

| 缺口 | 当前现态 | 为什么阻塞直接删容器 |
| --- | --- | --- |
| `Buff/Debuff` 净化语义 | 项目侧现已新增 `FormalGameplayTagCatalog`，并把 `effect.buff / effect.debuff` 固定成正式标签；`CharacterBase.Cleanse(IEnumerable<EEffectType>)` 当前会先把 `EEffectType` 投影成这组标签并调用 `RemoveGameplayEffectWithAnyTags(...)`，再按 formal runtimeKey 命中回收已映射 effect 的旧执行壳，最后只让真正的 unmapped fallback 或无 ASC 回退继续走旧容器类型净化 | 这一步已经不再是“纯旧容器计数”，但还没证明所有正式 `GameplayEffectAsset` 都已正确挂上这组标签，也还没把净化返回值、旧档迁移回退与 live truth 完全切到 GAS |
| UI 展示快照 | `CharacterTemporalEffectPresentationSnapshot` 当前已会优先直接枚举并投影 `GameplayEffectSpec`，旧容器只补 unmapped fallback；本轮又把 HUD/角色面板的新增/移除展示事件从 `CharacterTemporalEffectRuntime` 收回到 `CharacterBase + formal spec`。其中已映射 formal `GameplayEffectAsset` 的效果，`displayName/details/icon` 现已只由正式资产种进 spec；`semanticId` 的写入端现在也只认 `PresentationSemanticId` 和 formal tag，不再在种 spec 时借旧 effect 分类，而且 formal spec 的展示 seed 现在若拿不到正式 `GameplayEffectAsset` 会直接拒绝回退旧 fallback snapshot。formal 展示读取口若拿不到分类，也会直接暴露 formal 资产缺口，不再回退旧 effect 分类。同时正式持续效果模板脚手架已补上 `effect.buff` 分类，资产审计也会直接报告“formal `GameplayEffectAsset` 缺展示分类”的缺口。同轮 `CharacterTemporalEffectRuntime` 的 fallback 展示口又继续收窄成“只为无法投影 formal snapshot 的 effect 生成 legacy fallback”，不再替 mapped effect 重新回答一遍展示快照 | 当前虽然已不再是“完全没有 spec 投影”，也不再是“效果栏初始枚举还只能靠旧容器”，而且展示事件来源也已先切回正式拥有者；但 unmapped fallback 仍会回读旧 effect payload，所以还不能宣称展示真相已经完全脱离旧 effect |
| 运行时句柄恢复 | 当前 `TemporalControlEffect/TemporalSpeedModifierEffect` 的动作锁与速度倍率句柄主键已经收回 `CharacterBase`，并直接绑定到持续效果 `runtimeKey`；旧 effect 已不再自持私有 handle key。`2026-06-18` 最新又补了“formal spec 缺席即回滚 mapped legacy effect”的每帧对账、“mapped effect 的每帧时长优先跟随 formal spec”的同步口，以及 control/speed 两类句柄型 effect 的 formal-driven apply/restore/refresh/remove 时机收口；因此至少不会再出现 formal 规则已经移除、formal 时长已刷新，但旧动作锁/移速句柄还按第二套时机各算各的双真相 | 这一步先收掉了“句柄 key 私藏在旧 effect 里”的重复所有权，也把 mapped effect 的残留收尾优先权、时长优先权和 control/speed 两类句柄时机进一步收回了 formal 规则链；但 `m_effects` live 集合、`Cleanse` 计数、旧档迁移回退和 unmapped fallback 仍未退场，所以还不能宣称这条线已经完全切到 GAS |
| 稳定运行时键 | 旧 `GetHashCode(effect)` 已退场；当前 `ATemporalEffect` 与 `GameplayEffectSpec` 都已正式持有 `RuntimeKey/runtimeKey`，HUD 继续通过 `CharacterTemporalEffectPresentationSnapshot.RuntimeKey` 读这份稳定键 | 这先收掉了“对象哈希不稳定”问题，也补齐了 GAS 侧实例键前置条件；但正式 `GameplayEffectSpec -> CharacterTemporalEffectPresentationSnapshot` 投影仍没接上，所以彻底删旧容器前还得把展示查询口切过去 |

### 阶段 D：能力规则切换

| 动作 | 说明 |
| --- | --- |
| 冷却/消耗/标签阻断改由 GAS 回答 | `ActiveAbilityBase` 继续做动作执行，但不再自己判断旧 `Stats` 冷却或蓝耗 |
| TopDown 权限模型只保留动作状态门 | 例如“当前被击退”“当前武器占用”这类执行层阻断 |
| 旧 `Ability/Effect/Stats` 规则入口退场 | 不保留双判断 |

当前阶段 D 的现态不是“还没动”，而是：

- 对已映射 `formalAbilityAsset` 的能力，`ActiveAbilityBase` 的冷却查询、施加、清理，以及存档恢复，现已优先走 `CharacterBase.GASRuntime + ASC`。
- 对已映射 `formalAbilityAsset` 的能力，formal rule roster 现也已同步进 `ASC AbilityContainer`；`ActiveAbilityBase.CanFire()` 会先问 formal `AbilitySpec.CanActivate()` 的激活前提，`ConsumeMana()` 也已优先改成应用 formal cost，武器执行开始/结束/中断时还会同步 formal active lifecycle，以驱动 `ActivationOwnedTags/BlockAbilitiesWithTags`。
- 未映射正式 `AbilityAsset` 的能力，当前仍会回退到旧 `ActiveAbilityBase` 内部 timer。
- 当前 `CharacterBase.ReloadAbility(...)`、`ActiveAbilityBase.Reload()` 与 `WeaponExecutionRuntime.RequestReload()` 仍主要是执行层入口，还没有新的正式规则调用者；因此下一步不能为了“看起来完整”硬把 reload 语义塞进 GAS，而要先锁定真实调用链。
- 因此这一步现在是“冷却、激活前提、cost、active lifecycle 与 `CancelAbilitiesWithTags -> 执行层中断` 已切第一刀；触发规则还要继续接 GAS，换弹则明确留在武器执行层，武器执行状态持久化与更多执行态联动还没完全收口”，不能再把整条阶段 D 简化成“尚未开始”。

### 阶段 C / D 的前置门槛

在继续切持续效果和能力规则前，必须先锁死下面 4 个前提；否则只会把当前双真相从代码层搬到胶水层：

| 前提 | 当前现态 | 为什么必须先锁 |
| --- | --- | --- |
| 正式 GAS 能力资产链 | 当前 `AbilitySheet -> AbilityAsset` 的正式字段与查询口已经落代码，但还没有完成实际资产绑定与运行时消费迁移 | 没有资产绑定，后续仍会被迫在运行时临时拼 `AbilityAsset` 或写 wrapper，直接违反“不得造包装层” |
| 正式 GAS 效果资产链 | 当前 `ITemporalEffect -> GameplayEffectAsset` 的正式字段、查询口和 clone 保真已落代码，但还没有完成实际资产绑定与运行时消费迁移 | 没有资产绑定，`CharacterTemporalEffectRuntime` 就没法真正退场，只能继续当 live 集合真相 |
| 存档协议迁移面 | 当前角色存档顶层正式协议已只保留 `abilityRuntimeStates` 与 `temporalEffectRuntimeStates`；`legacyAbilityDataBlocks / legacyTemporalEffects / legacyLockedActions / legacySpeedModifiers` 兼容字段与对应导入分支已从 `CharacterBase` 正式协议删除 | 如果 change 台账还把这批已删除兼容层写成现役迁移入口，后续阶段 C / D 就会继续围着不存在的旧档回退做假任务，偏离 live runtime 与 fallback 收口主线 |
| UI / 表现读取口 | 当前浮字与表现事件仍建立在 `ITemporalEffect` 项目侧实例上；但 HUD 冷却、能力菜单、效果栏与角色信息这批 UI 读取口已开始收口到 `CharacterBase` 的正式展示快照 | 不把剩余读取口继续收回正式查询口，切完规则后仍会残留项目侧实例依赖，形成新旧两套只读真相 |

### 当前阶段 C / D 剩余冲突的源码落点

| 冲突面 | 当前文件 | 仍未切掉的旧真相 |
| --- | --- | --- |
| 能力 live 集合 | `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.AbilitySetRuntime.cs` | `m_instances` 仍是能力实例仓库、武器执行状态恢复和能力 DataBlock 恢复来源；主动/被动能力投影查询、冷却快照读取和触发入口解析已回到 `CharacterBase` 正式拥有者。formal `AbilityAsset` roster 已开始改由 `CharacterBase.GASRuntime + ASC AbilityContainer` 持有，已映射能力的冷却/激活前提/cost/active lifecycle 与 `CancelAbilitiesWithTags -> 执行层中断` 都已开始走 GAS。触发规则还要继续收 GAS，换弹已经明确归武器执行层；武器执行状态持久化仍留在执行层 runtime |
| 效果 live 集合 | `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.TemporalEffectRuntime.cs` | `m_effects` 仍是效果栏、效果分发、`Cleanse(EEffectType)`、运行时键与持续效果恢复后的 live 真相；而 `GameplayEffectContainer` 也已经在插件侧维护持续时间、叠层与移除规则。当前除了“已映射 formal asset 的 effect 若找不到对应 spec，就不能继续靠旧容器残留存活”这层收尾对账外，mapped effect 的每帧 `remainingDuration` 也已开始优先从 formal spec 同步，不再先由旧容器自己扣；同轮 mapped effect 的 stack/consume 也已先改成 formal stacking 优先，且 formal spec 若已被容器移除，不再允许项目侧缓存继续把它当成 live 规则；本轮 mapped effect 的写盘共享时序字段也已开始优先从 formal spec 导出，而不是继续信旧 effect timer；但这仍不能据此误报 `m_effects` 已退场 |

### 2026-06-18 当前新增进展

- `UIHUDAbilityBarEntry` 已切到 `CharacterBase.TryGetActiveAbilityCooldownSnapshot(...)`，不再让 HUD 直接读旧冷却查询口。
- `UIAbilities` 已切到 `GetActiveAbilitySheetSnapshots()/GetPassiveAbilitySheetSnapshots()`，不再按内部能力实例集合做菜单填充。
- `CharacterBase.Abilities` 现已把主动/被动能力投影查询、冷却快照读取和触发入口解析收回正式拥有者；`CharacterAbilitySetRuntime` 同轮撤掉了 `m_triggerables` 与对应投影/查找 API，进一步收成“实例仓库 + 更新/重置/中断 + bonus ability 计数”；能力 runtime state 的创建/恢复编排则已收回 `CharacterBase.Persistence`。
- `AbilityBase` 现已新增 `CreateFormalRuntimeState(...) / RestoreFormalRuntimeState(...)`；`ActiveAbilityBase` 现也已把通用冷却与 `WeaponExecutionData` 的 formal runtime state 写入/恢复收回主动能力自己。[CharacterBase.Persistence.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Persistence.cs) 当前已不再直接识别 `ActiveAbilityBaseDataBlock` 或拆 `remainingCooldownTimer / weaponExecution` 字段，而只保留角色顶层列表编排。`2026-06-20` 本轮又进一步裁定：读档恢复时不再假恢复半段武器忙碌态，只恢复冷却与执行层最小持久状态；否则会产生“武器状态机看似仍在动作中，但 formal active lifecycle、动作锁和结束回调并未同步恢复”的双真相。
- `ITemporalEffect` 现已新增 `CreateFormalRuntimeState() / RestoreFormalRuntimeState(...)`；`ATemporalEffect` 当前已把 `CharacterTemporalEffectRuntimeStateData` 的导出和 `TemporalEffectPersistedState` 的恢复收回效果自己。[CharacterBase.TemporalEffectRuntime.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.TemporalEffectRuntime.cs) 当前已不再自己拼 persisted-state 或判断 `ITemporalEffectRuntimeStateCarrier`，而只保留 live 集合编排、类型实例化与 `RestoreRuntimeState(owner)` 挂回角色。
- `CharacterTemporalEffectRuntimeStateData` 顶层当前又继续删掉了重复共享字段：`stackableEffectId/duration/remainingDuration/effectType` 已不再和 `TemporalEffectPersistedState` 双存一份；正式角色级编排现在只保留“恢复哪种 effect 实例 + 对应哪张 formal 资产 + 私有 persisted-state 载荷”这层元数据。
- `UIHUDEffectBar`、`UIEffectList`、`UICharacterInfo` 已切到 `CharacterTemporalEffectPresentationSnapshot` 与 `GetTemporalEffectPresentationSnapshots()`，不再直接枚举 `character.temporalEffects`。
- `EffectDispatcher` 已切到 `CharacterBase.TryConsumeTemporalEffect(...)`，规则消费方不再旁路角色正式拥有者去扫 `target.temporalEffects`。
- `CharacterBase.Persistence` 已切到 `abilityRuntimeStates / temporalEffectRuntimeStates` 这两条顶层正式恢复快照；其中能力快照当前只保留稳定 `AbilitySheet` 引用、对象状态、通用冷却/武器执行状态和 `extraRuntimeState`，旧 `AbilityBaseDataBlock[]` 仅保留在 `legacyAbilityDataBlocks` 旧档迁移入口，而且读档后会立即归一回 `abilityRuntimeStates`；持续效果快照当前也已包进正式元数据壳，不再让 `ITemporalEffect[]` 直接占顶层真相。
- `ITemporalEffect` 已新增 `TemporalEffectPersistedState + ITemporalEffectRuntimeStateCarrier`，`TemporalHeal/TemporalDamage/TemporalRestoreMana/TemporalControl/TemporalSpeedModifier/TemporalStatModifier` 这 6 种现役持续效果都已能按“类型 + 最小 persisted state”恢复，不再默认把整对象效果 payload 写进角色存档；formal runtime state 也已不再继续携带 `legacyRuntimeEffect`。
- `TemporalEffectPersistedState` 当前又继续删掉了 `legacyFallbackState` 这份影子字段。`ATemporalEffect` 现在也不再缓存一份 `m_legacyFallbackState`；读档恢复后若仍需要 legacy fallback 展示/净化语义，就按 effect 自己已经恢复好的正式字段即时重算，而不是再从存档里恢复一份 fallback 描述副本或让实例缓存继续充当第二份真相。这样持续效果 persisted-state 继续只保留执行壳恢复所需状态，不再让 fallback 语义形成第二份存档真相。
- `CharacterBase.GASRuntime` 已新增 formal ability cooldown 查询/施加/清理闭包，`CharacterBase.Abilities` 现把能力规则冷却入口统一转发到这里；`ActiveAbilityBase.CanFire()/StartCooldown()/OnSave()/OnLoad()/Reset()` 也已对已映射 `formalAbilityAsset` 的能力优先采用 GAS 冷却真相，旧 timer 只保留未映射能力的回退职责。
- `CharacterBase.GASRuntime` 现已把当前执行层能力集合中声明了 formal `AbilityAsset` 的项同步进 `ASC AbilityContainer`，作为正式 ability rule roster；`ActiveAbilityBase.CanFire()` 现在会先问 formal `AbilitySpec.CanActivate()` 的标签前提、cost 与 cooldown，`ConsumeMana()` 也已优先应用 formal cost，旧蓝耗只保留为未映射或无 formal cost 的回退。
- `FormalAbilityRuleProxySpec.CancelAbility()` 现已把 formal `CancelAbilitiesWithTags` 回流到 `CharacterBase.InterruptFormalAbilityExecutionsByRuleKey(...)`；已映射能力若因 GAS 规则层取消，会同步中断正在运行的执行层武器状态机，而不是只撤 tags 不停动作。
- `CharacterBase.Cleanse(...)` 当前也已建立正式 GAS 侧净化入口：项目侧 `FormalGameplayTagCatalog` 固定 `effect.buff / effect.debuff`，`Cleanse` 会先按这组标签清 formal `GameplayEffect`，再按 formal runtimeKey 命中回收 mapped effect 的旧执行壳，最后只让真正的 unmapped fallback 或无 ASC 回退继续走旧容器类型净化。当前这还不是“持续效果已切成单一真相”，因为 `m_effects` live 集合、旧档迁移回退与展示/恢复残留仍在旧容器侧。
- `ATemporalEffect` 现已正式持有并持久化 `runtimeKey`，`CharacterTemporalEffectPresentationSnapshot.RuntimeKey` 也已不再依赖临时 `GetHashCode(effect)`；同轮 `GameplayEffectSpec` 也已补上正式 `RuntimeKey` 与 `PresentationSemanticId`。这意味着当前 HUD/角色信息至少已经不再把“对象实例地址”当正式效果键，效果栏初始枚举也已可直接从 formal spec 出发；剩下没切完的是展示 payload 本身，而不是“键从哪里来”或“初始枚举从哪里来”。
- `CharacterBase.Persistence.LoadOwnedTemporalEffects(...)` 现已在 `RestoreRuntimeState(owner)` 后继续调用 `RestoreFormalTemporalEffectRule(...)`，把读档恢复出来的 formal spec 重新挂回 ASC，并按 persisted `remainingDuration` 校正 GAS spec 时序。这说明当前缺口已经不再是“读档后 formal spec 全丢”，而是“spec 的展示 payload 仍依赖旧 effect 种子化”和“速度/控制类运行时句柄仍依赖旧 effect 自己恢复”。
- `CharacterActionStateRuntime` 现又新增 `runtimeKey -> 动作锁/移速修饰` 这组正式容器；`TemporalControlEffect/TemporalSpeedModifierEffect` 已不再保存 `unlockKey/key` 这类私有运行时句柄字段，而是直接通过 `CharacterBase` 的正式 effect-rule API 施加、更新与移除派生状态。这说明当前缺口已进一步从“句柄谁持有”收缩成“句柄生命周期何时完全交给 formal spec”。
- `ATemporalEffect.RestoreFormalRuntimeState(...)` 现已先消费 `formalGameplayEffectAssetGuid + formalGameplayEffectAssetName`，并优先按 GUID 恢复 `m_formalGameplayEffectAsset`；只有当前运行环境拿不到 GUID 解析入口时，才会退回已加载资产名恢复。当前工作区静态复核只有 1 张正式持续效果资产 `[正式持续效果模板.asset](/C:/Gamedev/Unity/Project/FantasyWord/Assets/GameData/GameCore/GAS/GameplayEffects/%E6%AD%A3%E5%BC%8F%E6%8C%81%E7%BB%AD%E6%95%88%E6%9E%9C%E6%A8%A1%E6%9D%BF.asset)`，因此现态也没有同名冲突；但这仍不是“所有运行环境都已有 formal 效果注册表”的最终形态，名字兼容回退当前仍保留。
- `CharacterBase.StateApi` 现已新增角色自己持有的 `m_temporalEffectPresentationAdded/Removed` 事件，并在 `AddTemporalEffect(...)` / `CharacterTemporalEffectRuntime` 的移除路径里直接按 `CreateTemporalEffectPresentationSnapshot(...)` 发出。这样当前 HUD 与角色面板的持续效果新增/移除通知已不再依赖旧容器内部的 presentation event；旧容器剩下的展示职责进一步收缩到“初始 fallback 枚举”和“live effect 生命周期编排”。
- `TemporalEffectPresentationContext` 现也已从“直传整颗 `ITemporalEffect` 实例”收成“`CharacterTemporalEffectPresentationSnapshot + visualFlags` 的纯表现只读上下文”；`CombatTextDisplay` 当前已不再从表现事件回读旧 effect 实例。与此同时，`CharacterBase` 那组未被任何代码消费的 `AddTemporalEffectAddedListener/RemovedListener` raw effect 监听口也已退场，旧容器因此又收掉一层对外 live 对象暴露面。
- `CharacterBase.GASRuntime.SeedFormalTemporalEffectPresentation(...)` 当前又继续把展示 seed 往 formal `GameplayEffectAsset` 收口：已映射 formal asset 的效果不再回读旧 `effect.info/GenerateDescription()` 来回答名称、描述和图标，而是只认正式资产字段；`semanticId` 也只认 `PresentationSemanticId` 与 formal tag。与此同时，这条 spec seed 链现在若拿不到正式 `GameplayEffectAsset` 会直接拒绝回退旧 fallback snapshot，不再让 formal spec 悄悄借旧 payload 兜底；`CharacterTemporalEffectRuntime.EnumerateEffects()` 这类已无调用者的旧容器暴露面也已删除。
- `CharacterBase.StateApi.GetTemporalEffectPresentationSnapshots()` 与 `CharacterTemporalEffectRuntime` 当前又继续把 fallback 枚举边界压窄：旧容器现在只会通过 `CreateLegacyFallbackPresentationSnapshots()` 生成真正缺 formal snapshot 的 legacy fallback，不再先对 mapped effect 生成一遍 formal-first 快照再靠 runtimeKey 去重。
- `CharacterBase.Update()` 现在会先走 [CharacterBase.StateApi.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.StateApi.cs) 的 `AdvanceOwnedTemporalEffects()`，再执行 `ReconcileOwnedTemporalEffectsWithFormalRuntime()`；这一步会按 runtimeKey 对账 ASC 里的 `GameplayEffectSpec`，一旦某个已映射 `formalGameplayEffectAsset` 的 effect 已经没有对应 formal spec，就立即回滚旧 effect 的动作锁、移速句柄和展示残留。当前这不是“live truth 已切到 GAS”，但它已经把“formal 规则没了，旧容器还在挂着 mapped effect”这层双真相继续缩掉。
- `ITemporalEffect/ATemporalEffect` 现已新增 `SyncRuntimeTimingFromFormalRule(...)`，而 mapped effect 的 formal timing advance 回调也已经从旧 helper 收回 [CharacterBase.StateApi.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.StateApi.cs) 的 `AdvanceOwnedTemporalEffects()`。[CharacterBase.Update()](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.cs) 当前会先让 [CharacterBase.GASRuntime.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.GASRuntime.cs) 的 `TryAdvanceMappedTemporalEffectWithFormalRule(...)` 对已映射 formal `GameplayEffectAsset` 的 effect 同步 spec 的 `Duration/DurationRemaining()`，找不到 formal spec 时才回退 `TemporalEffectLegacyRuntimeTraits` 对应的 legacy 壳推进。这样 mapped effect 的时长真相已进一步收回 formal spec；旧 effect 继续只保留执行态句柄、恢复钩子和 unmapped fallback 这类剩余职责。
- 这版 owning-shape 当前也已追进 foundation 静态门禁：`CharacterTemporalEffectRuntime` 只保留 `TryGetExecutionShellByRuntimeKey(...)` 这类 key 化查询口，`ContainsEffect(...)`、`RemoveEffectPrematurely(...)`、`UpdateEffects(...)` 与 `AdvanceLegacyRuntimeShell(...)` 都已被列为回归违规；与此同时 `CharacterBase.StateApi` 也必须保留 `AdvanceOwnedTemporalEffects()` 与 `AdvanceOwnedLegacyTemporalEffect(...)` 这组正式推进入口。这样下一轮收口不需要靠口头记忆判断“对象式注册表 API 或推进权是不是又塞回 helper 了”。
- 现役 temporal effect 的默认描述生成本轮又继续收回 `ATemporalEffect`：`GenerateDescription()` 现在直接消费 `TryGetLegacyFallbackState(...)` 这份共享合同来回答名称和 details，不再要求每个 effect 各自再维护一份平行描述拼装；`TemporalControlEffect` 的控制说明文案也已并回 fallback 合同本身，避免“菜单描述”和“fallback 合同”各说一套。这还不是把 fallback 真相切到 formal 资产，但它继续削掉了 effect 本地展示回答口的重复持责。
- 当前因此关闭的是“UI/表现 直读旧容器形状”“旧 runtime payload 直接占顶层角色存档真相”“现役持续效果整对象写盘”“读档后 formal spec 整条恢复链缺失”“效果栏初始枚举仍只能靠旧 `m_effects` 容器”“formal ability runtime state 继续背旧能力 DataBlock”“formal temporal-effect runtime state 继续背旧效果对象”，以及“已映射 effect 的名称/描述/图标仍回读旧 payload”“已映射 effect 在 formal snapshot 缺席时继续回退旧展示 payload”“mapped formal effect 的分类仍由旧独立 `effectType` 协议兜底”“formal spec 展示 seed 在缺 formal asset 时继续回退旧 fallback snapshot”“fallback 展示/净化语义继续以影子字段写进 persisted-state”“实例缓存继续充当 fallback 第二真相”和“`CharacterBase` 正式协议仍保留旧档兼容字段/导入分支”这十四层暴露面。还没关闭的是“unmapped fallback 仍会回读旧 effect payload”“`TemporalEffectLegacyFallbackState` 共享合同仍由旧 effect 字段生成”以及“角色内部 live runtime 仍然存在”。

### 阶段 C / D 当前正确推进顺序

1. 先保持 `FormalGasAssetTemplateBootstrap + FormalGasMappingAudit` 这条正式资产链入口可重复执行，确保 Ability/Effect 资产不再为空。
2. 再把“`CharacterBase` 正式协议已只认 formal runtime state”这件事固定进 change 台账、门禁和后续实现判断，避免文档或脚本继续把已删除的 `legacyAbilityDataBlocks/legacyTemporalEffects` 误记成现役迁移入口。
3. 然后把 HUD、能力菜单、效果栏和规则消费口改成正式查询口，而不是继续直读项目侧 live 实例集合。
4. 最后才允许删除 `CharacterAbilitySetRuntime` 与 `CharacterTemporalEffectRuntime` 的 live truth 职责。

这 4 项的正确处理顺序是：

1. 先把正式资产映射协议落代码并完成实际资产绑定。
2. 再定义存档迁移协议。
3. 然后把 UI / 表现读取口改成正式查询口。
4. 最后才删除项目侧 live 集合和规则判断。

这里有一条硬约束：不允许用“运行时临时生成 GAS 资产”“按 `sheet.name` 猜测对应 GAS asset”“额外建 `GASAdapter` 映射表脚本组件”来跳过这一步。

### 阶段 C / D 的资产落点裁决

在当前仓库里，正式 GAS 资产链不是“随便放到能扫到的目录就行”，而是必须和现有自动化闭包对齐：

| 资产 | 正式目录裁决 | 是否进入 `DatabaseRegistry` | 理由 |
| --- | --- | --- | --- |
| `AbilitySheet` | 当前 foundation 阶段先落 `Assets/GameData/GameCore/GAS/AbilitySheets/` | 是 | `AbilitySheet` 继承 `DatabaseEntry`，而当前 `FormalDataAssetCache` 与 `DatabaseEntryProcessor` 只自动认 `Assets/GameData`；若现在把正式 sheet 直接放进 `Assets/Database`，自动登记与编辑器正式缓存都不会稳定命中 |
| `AbilityAsset` | `Assets/GameData/GameCore/GAS/AbilityAssets/` | 否 | `AbilityAsset` 是 GAS 规则资产，不是项目数据库条目；它应由 `AbilitySheet.formalAbilityAsset` 单点引用，而不是再进第二张注册表 |
| `GameplayEffectAsset` | `Assets/GameData/GameCore/GAS/GameplayEffects/` | 否 | `GameplayEffectAsset` 同样是规则资产；它应由 `ATemporalEffect/ITemporalEffect` 自己声明并引用，不应再靠外部映射表或注册表转一道 |

这条裁决有一个当前必须显式记录的仓库事实：

- `FormalGasMappingAudit` 当前审计根是 `Assets/GameData + Assets/Database`，因为历史正式数据库资产仍有一部分留在 `Assets/Database`。
- 但编辑器正式缓存与自动登记链 `FormalDataAssetCache + DatabaseEntryProcessor` 当前只认 `Assets/GameData`。
- 所以这轮不能一边说“正式能力资产链要开始建立”，一边又把第一批正式 `AbilitySheet` 放进 `Assets/Database`，否则审计能看见、自动化却不稳定认，等于再造一层目录语义冲突。

因此当前正确动作不是直接放宽自动化去吃全项目，也不是继续让两套目录都算“同样正式”，而是：

1. foundation 阶段的正式 GAS 资产链统一先落 `Assets/GameData/GameCore/GAS/`。
2. `AbilitySheet` 继续作为 `DatabaseEntry` 参与正式注册；`AbilityAsset` 与 `GameplayEffectAsset` 只通过字段引用进入闭包。
3. 等未来需要把更大范围内容数据库系统性迁回 `Assets/Database` 时，再单独立 change 处理 `FormalDataAssetCache / DatabaseEntryProcessor / DatabaseWindow` 的正式根裁决，而不是在 GAS 迁移过程中顺手混根。

## 6. 存档裁决

| 项 | 最终要求 |
| --- | --- |
| 属性落盘 | 继续按 `FormalAttributeCatalog` 稳定 ID 落盘，不直接把插件内部字段名当存档协议 |
| 当前值落盘 | 由 GAS 当前值写回正式数据块 |
| 持续效果落盘 | 只保存正式需要恢复的效果资产 ID、层数、剩余时间等最小数据 |
| 派生动作锁/速度修饰 | 不再作为第二份真相单独落盘；若它们来自持续效果，就只允许由持续效果恢复流程重建 |
| 能力落盘 | 继续保存正式能力资产引用与已解锁/已装备状态，不保存临时运行时对象引用 |
| 旧档迁移 | 只允许 `Stats/currentStats -> GAS` 单向迁移；迁完后不再双写 |

## 7. 与对象池的关系

| 场景 | 要求 |
| --- | --- |
| 怪物/NPC/召唤物复用 | 禁止把上一实例的 GameplayEffect、Tag、Cooldown 残留到下一实例 |
| 角色重新启用 | 必须重新按正式拥有者数据初始化 ASC |
| 池化回收 | 回收前清理 effect、取消 ability、复位 tags |

## 8. 代码落点原则

| 原则 | 说明 |
| --- | --- |
| 不新造项目侧 GAS 包装层 | 直接在 `CharacterBase/Hero/Monster` 正式闭包内接 ASC |
| 不让 UI 知道 GAS 细节 | UI 继续只调 `CharacterBase` 正式查询口 |
| 不让 `GameManager` 变成 GAS 宿主 | ASC 属于实体，不属于项目级系统 |
| 不让插件内部 host 成为项目规范 | `GasHost` 只是插件内部 tick 设施 |

## 9. 本轮后的正式下一步

1. 继续扩写“属性到 AttributeSet 的正式映射表”，把 `FormalGameplayAttributeSet` 字段、资源属性约束和稳定 ID 一起锁死。
2. `ActiveAbilitySheet -> AbilityAsset`、`ITemporalEffect -> GameplayEffectAsset` 的正式映射协议已经落代码，最小非业务 GAS 模板资产链也已经进入 `Assets/GameData/GameCore/GAS/` 并被静态门禁保护；下一步不再是“先让审计目标不为空”，而是继续把真实 Ability/Effect 数据接进同一正式闭包，再用 `FormalGasMappingAudit` 锁定真实映射缺口。
3. `OnDisable` 生命周期边界已先补到“项目侧持续效果 runtime 跟随 ASC 一起收尾”；下一步继续核对 `Hero/Monster` 侧还有没有对象池复用会残留的项目状态。
4. 第三刀代码替换已完成到“通知、死亡链和当前值存档回到 CharacterBase 正式拥有者，旧 runtime 不再是这些链路的现役真相”。
5. 下一步继续把旧 `AttributeBootstrapBuffer` 压到“只剩旧档导入、正式镜像回填和启动窗口 fallback”，并在映射协议锁定后再收持续效果 live 集合与能力规则，不同时切具体技能业务。
6. 持续效果线的下一刀按 3 个子目标推进：
   - 先把 `m_effects` 从“规则列表”继续压成“执行壳注册表”，当前已先沿 `TemporalEffectLegacyRuntimeTraits` 区分“要不要本地寿命推进、要不要 legacy tick callbacks”，并把 fallback 展示聚合、legacy 净化筛选、formal 缺席回滚筛选、stack 命中裁决，以及每帧推进与完成退场都收回 `CharacterBase`；下一步继续减少旧容器在剩余恢复编排和注册表之外的语义持责，避免把仍需逐帧执行的效果和已经只剩寿命/句柄后果的效果混成一类。
   - 再继续把 unmapped fallback 从“效果自己回答最小快照”推进到“`TemporalEffectLegacyFallbackState` 共享合同”，再进一步减少这份合同对旧 effect 私有字段的依赖，避免 `info / GenerateDescription / effectType` 长期继续作为 fallback 的隐性第二协议。
   - 旧 `legacyTemporalEffects` 字段本体与 `ImportLegacyTemporalEffects(...)` 导入链已经删除；当前不再讨论“字段何时退场”，而是继续复核 change 台账、门禁和恢复链，确保没有任何文档或代码继续把这条已不存在的兼容层误记成现役入口。
