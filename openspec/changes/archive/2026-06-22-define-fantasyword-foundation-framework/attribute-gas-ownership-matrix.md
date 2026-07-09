# 属性与 GAS 专项矩阵

> 本文件只裁决属性、能力和效果规则的真相边界。
> 当前不迁移具体技能或状态效果，不创建项目侧 GAS 兼容入口层。
> 但 GAS 不是可有可无候选；复杂开放世界的属性、能力和状态效果需要下一阶段专项裁决，胜出后替换同职责旧入口。

## 当前结论

| 项 | 结论 |
| --- | --- |
| 当前属性真相 | 当前正式读取、资源写入口、属性通知、零血死亡判定和当前值存档已优先走 `CharacterBase + ASC`；旧 `Stats/currentStats + AttributeBootstrapBuffer` 只保留旧属性缓冲、旧档导入、正式镜像回填和 `Awake` 期间一次性的 bootstrap 读取窗口 |
| 当前能力/效果真相 | 替换前暂由 `Ability/Effect/Stats` 2DRPG 闭包，加上已登记的 TopDown 能力权限和武器执行吸收承载 |
| EX-GAS 当前角色 | 下一阶段属性/效果/能力规则替换候选；复杂叠层、标签、冷却和组合规则必须正面对比 |
| 当前门禁 | `Invoke-FoundationStaticGate.ps1` 当前改为“白名单外禁止引用 GAS 运行时类型”；最新结果仍是 `GameCoreGasRuntimeReferenceHitCount = 0`，含义是白名单外 0 命中，不再是整个 `GameCore` 完全 0 引用 GAS |
| 当前动作 | 先禁止双真相；`2026-06-16` 已补 `attribute-field-mapping.md` 与 `FormalAttributeCatalog`，先把正式属性稳定 ID、显示名和当前真相入口收成一处；同日又把 `CharacterBase` 内部的 `Stats/currentStats` 运行时细节收进旧属性缓冲，避免角色本体继续同时承担属性存储、资源语义、上下限联动和通知细节；`2026-06-18` 先后落了三刀并补了一轮回退修复：第一刀用 `FormalGameplayAttributeSet + CharacterBase.GASRuntime` 固定实体级 ASC 所有权、正式属性字段形状和旧 Stats 快照回填路径；第二刀又把 `CharacterBase` 的正式读取口、资源写入口和最小战斗快照优先切到 ASC；第三刀继续把属性通知、零血死亡判定与当前值存档/读档收回 `CharacterBase` 正式拥有者，并把当时的回退路径也收回同一正式拥有者。`2026-06-21` 本轮又继续把读取 fallback 从“`m_isFormalAbilitySystemReady` 未就绪就一直宽容”收紧成“只允许 `Awake` 期间 bootstrap 窗口临时借用旧快照”，避免正式运行态继续默默吃 legacy 读口。当前旧 `AttributeBootstrapBuffer` 已降到“快照缓冲 + 旧档导入缓冲 + 正式镜像回填 + 启动窗口临时读取”，下一阶段继续按实施提案替换，不允许把这层过渡镜像误报成最终完成 |

## 取舍

| 维度 | 当前 `Stats/currentStats` | EX-GAS `AttributeSet/AbilitySystemComponent/GameplayEffectAsset` | 当前判断 |
| --- | --- | --- | --- |
| 设计模式 | 与 2DRPG 角色、装备、效果、存档和 UI 已绑定，语义直接 | GAS 在属性集、效果叠层、标签、冷却和可扩展效果上更系统 | 当前不并行；GAS 若接入必须替换同职责 |
| 软件工程 | 当前代码闭包可搜索、可静态门禁、无插件运行时耦合 | 接入后需要生成代码、资产配置、初始化生命周期和对象池复用边界 | “白名单外 0 命中”只是防双轨门禁，不是冻结理由；专项必须裁决替换路径 |
| 易用 | 适合现有 RPG 数值和菜单生产 | 适合复杂技能、持续效果、标签和组合规则 | 复杂能力是开放世界地基的一部分，不能推迟到具体技能业务后才想 |

## 职责拆分

| 职责 | 当前所有者 | GAS 可否替换 | 禁止双真相 |
| --- | --- | --- | --- |
| 最大生命、当前生命 | 当前正式读取口、通知、死亡判定与当前值存档都已回到 `CharacterBase + ASC`；旧 `AttributeBootstrapBuffer` 只作镜像/导入缓冲 | 可以，但必须替换显示、结算、存档来源 | 不能同时从 `currentStats` 和 `AttributeSet` 读写 |
| 最大法力、当前法力 | 当前正式读取口与当前值存档已优先走 ASC；旧 `AttributeBootstrapBuffer` 只作镜像/导入缓冲 | 可以，同上 | 不能一边 GAS 扣蓝，一边 Stats 存档 |
| 攻击、防御、速度等基础数值 | 当前正式读取口已优先走 ASC；基础/当前值仍保留旧 runtime 镜像快照作过渡兜底 | 可以，但必须明确装备、Buff 和存档映射 | 不能 UI 显示 Stats、战斗结算 GAS |
| 技能冷却、消耗、阻断 | `ActiveAbilityBase + AbilityPermissionSettings` | 可以替换或吸收 GAS 规则 | 不能两边同时判定能否释放 |
| 状态效果叠层/周期 | 当前 Effect 闭包 | GAS 可能更强 | 不能两边都修改同一属性 |
| 表现反馈 | `GameplayFeedbackSet` | 不应由 GAS 拥有 | GAS 只能发事件或结果，不拥有表现入口边界 |

## GAS 接入前置条件

| 条件 | 必须证明 |
| --- | --- |
| 属性映射 | 每个正式属性有唯一 ID、存档字段和 UI 读取来源 |
| 生命周期 | `AbilitySystemComponent` 初始化、禁用、销毁和对象池复用边界明确 |
| 存档兼容 | 旧 `Stats/currentStats` 存档如何读入新属性真相有迁移方案 |
| 装备与 Buff | 装备、被动效果、临时效果的叠加顺序明确 |
| 门禁更新 | 若 GAS 胜出，旧 Stats 对应职责必须退场，不能只放宽当前 GAS 禁止门禁 |

## 禁止项

| 禁止项 | 理由 |
| --- | --- |
| 在 `GameCore` 直接引用 `AbilitySystemComponent`、`AttributeSet`、`GameplayEffectAsset` | 会绕过专项矩阵，形成第二属性真相 |
| 新增 `EXGASAdapter`、`GASFacade`、`StatsToAttributeWrapper` | 兼容层会掩盖同一数值有两套来源 |
| 只把 GAS 用在新技能上，旧技能继续改 Stats | 技能效果会并行修改同一角色状态 |
| UI 同时显示 Stats 与 GAS 属性 | 玩家看到的属性真相会分裂 |
| 存档同时保存 Stats 和 GAS 属性 | 读档冲突不可维护 |

## 后续动作

| 顺序 | 动作 |
| --- | --- |
| 1 | 保持当前门禁：专项推进期间只允许已经明确成为正式 owner 的 GAS 边界文件接触运行时类型，当前至少包括 `FormalGameplayAttributeSet.cs`、`FormalGameplayEffectDamageHelper.cs`、`CharacterBase.GASRuntime.cs`、`CharacterBase.Resources.cs`、`CharacterBase.StateApi.cs`、`CharacterAbilitySet.FormalRules.cs` 与现役 formal temporal effect builder / effect 文件；白名单外继续保持 0 命中，避免双真相 |
| 2 | 已建立属性字段映射表：见 `attribute-field-mapping.md`，并已在代码侧落 `FormalAttributeCatalog` 作为正式属性目录 |
| 3 | 已落 GAS 第一刀：固定 `FormalGameplayAttributeSet` 字段形状、`CharacterBase` 的实体级 ASC 持有边界，以及从旧 Stats 快照初始化 ASC 的代码落点 |
| 4 | 已落 GAS 第二刀：`CharacterBase` 正式读取口、资源写入口和 `CombatStatSnapshot` 已优先转到 ASC；旧 `AttributeBootstrapBuffer` 当前只保留镜像/导入缓冲 |
| 5 | 已落 GAS 第三刀：`CharacterBase` 现已直接持有属性通知、零血死亡判定和当前值存档/读档入口，UI 与死亡链不再依赖旧 runtime 监听 |
| 6 | 裁决 GAS 是否替换属性层、效果层和能力规则层；如果只替换一部分，必须写清旧入口退场边界 |
| 7 | 设计 `AbilitySystemComponent` 初始化、禁用、销毁和对象池复用边界 |
| 8 | 下一步继续把旧 runtime 压到只剩旧档导入、正式镜像回填和启动窗口 fallback，再接能力/效果运行时与对象池清理边界 |
