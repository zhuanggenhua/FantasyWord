# 主流能力/法术体系裁决：配置型规则模型优先

本文记录 `define-skill-authoring-workbench` 的主流参考裁决。当前目标不是“先做编辑器”，而是先定义以 WoW、Pathfinder、D20 系 CRPG 等成熟结构为参考的配置型能力规则模型。这里强调的是结构参考，不是照搬 D&D 或任何现成规则文本。编辑器只是后续录入和校验这些配置的工具。

## 参考来源

本轮只把下列来源作为结构参考，不照搬规则文本、数值、IP 内容或数据库：

- SimulationCraft SpellData：公开说明 WoW spell 通常由 spell data、effect data、可选 power data 组成；spell data 保存名字、施法时间、冷却、描述等，effect data 保存治疗、光环、伤害、创建对象、召唤等实际行为。
- AzerothCore Spell System：公开说明 spell effect 是影响施法者或目标的小操作；一个 spell 可以有多个 effect，每个 effect 可以有自己的目标列表。
- AzerothCore `spell_proc` / `spell_linked_spell`：公开说明触发型能力用独立触发表描述事件、条件、概率、内置冷却和触发结果，而不是把所有逻辑塞进单个技能脚本。
- Pathfinder / D20 公开规则参考：法术描述结构包含施法时间、距离、目标/区域、持续、豁免、法术抗力等；规则层要能表达豁免、法抗、动作、专长、职业能力、每日次数和持续效果。
- EX-GAS：当前项目已接入的能力、属性、标签、GameplayEffect、Cue、Cost、Cooldown 和 TimelineAbility 候选底座。
- EX-GAS `GameplayCue` Wiki：明确 Cue 是播放游戏提示的类，例如特效、音效，并且原则上不应该修改属性、Buff 或玩法结果。
- GameCore `GameplayFeedbackSet`：当前项目已经落地的表现反馈闭包，承接能力、武器、命中、受伤、死亡、拾取和交互反馈；它是当前 GameCore 内唯一允许直接持有 `MMFeedbacks` 的边界。
- Kybernetik Platformer Game Kit：作为动画驱动技能作者流程参考，覆盖攻击过渡、每帧命中数据、Inspector/Preview 可视化、命中触发器、作者体验和时序预览；不作为整体能力规则模型参考。

## 裁决结论

FantasyWord 需要的是配置型规则模型，不是单个“技能编辑器”或“节点编辑器”。

正式顶层模型应从具体火球/陨石/投射物抽象，收口为：

```text
AbilityDefinition
CastDefinition
CostDefinition
TargetDefinition
EffectDefinition
TriggerDefinition / ProcDefinition
ResolutionDefinition
```

其中 `Projectile`、`Impact`、`Area`、`Summon`、`Aura`、`Damage`、`Heal` 都只是 `EffectDefinition` 或执行/表现子类型，不是顶层架构。

表现不再作为与规则并列的顶层模型。正式规则模型只记录表现引用，例如动画、音效、特效、`GameplayFeedbackSet` 槽位或 EX-GAS `GameplayCue` 引用；表现引用只响应规则结果，不拥有伤害、治疗、位移、状态、豁免、法抗、触发或存档真相。

这里的“顶层模型”首先指同一份技能/法术配置里的逻辑区块，不是默认要拆成 7 份独立 ScriptableObject。对大多数技能，`Ability / Cast / Cost / Target / Effect / Trigger / Resolution` 应优先作为一份能力配置中的分段字段存在，避免为了“模块化”把一个技能拆成过多小资产，增加策划录入、排错和引用维护成本。

只有在确实存在复用收益时，才值得把其中一部分抽成可复用子资产，例如：

- 某个效果模块会被多个技能重复使用。
- 某个触发或条件组合会被多个技能或玩家配方重复使用。
- 某个投射物、区域或召唤行为本身有独立寿命、独立调试和独立表现闭包。
- 某个规则片段需要被玩家配方、Mod 白名单或编辑器模板单独引用。

拆分标准不是“概念上能拆”，而是“拆开后能减少重复、降低维护成本、提高复用和审计效率”。

## 模型职责

### AbilityDefinition

能力身份和公共元数据：

- 稳定 ID、名字、图标、描述、分类、标签。
- 来源类型：职业、法术书、专长、装备、物品、状态、剧情、玩家炼金配方。
- 等级、环位、稀有度或其它项目侧进度门槛。
- 可用条件和授予条件引用。

### CastDefinition

发动方式：

- 动作类型：普通动作、移动动作、迅捷/附赠动作、反应、持续维持、整轮动作等。
- 施法/出手时间、是否可打断、集中或维持要求。
- 距离、最小/最大射程、触碰/射线/地面点/单位目标。
- 组件或前置要求：武器、姿态、材料、法器、空手、视线、声音等。

### CostDefinition

资源消耗：

- 法力、耐力、怒气、充能、冷却、物品消耗。
- 法术位、每日次数、职业资源、装备次数。
- 成本随等级、升环、超魔、配方模块变化的规则。

### TargetDefinition

目标模板：

- 自身、单体单位、队友、敌人、地面点。
- 圆形、锥形、线形、射线、触碰、区域、全局范围。
- 目标过滤：阵营、标签、状态、体型、是否可见、是否有路径/视线。

### EffectDefinition

可执行效果单元：

- 伤害、治疗、护盾、资源变化、属性修改。
- 添加/移除状态、光环、控制、变形、隐身、免疫、抗性、易伤。
- 创建对象、创建区域、创建投射物、召唤单位、移动/传送、驱散、复活。
- 效果可引用 GAS GameplayEffect，但不等于所有效果都直接由 GAS 原生 Timeline 执行。

### TriggerDefinition / ProcDefinition

触发型规则：

- 触发事件：施放、命中、被命中、造成伤害、击杀、进入区域、离开区域、tick、状态添加/移除、回合开始/结束等。
- 条件：目标标签、来源标签、伤害类型、区域类型、资源状态、概率、内置冷却。
- 结果：触发一个 Ability、Effect、Aura 或脚本化规则执行器。

### ResolutionDefinition

结算规则：

- 攻击检定、豁免、法术抗力/抵抗、命中/未命中。
- 半伤、无效、部分效果、免疫、抗性、易伤。
- 加值类型、叠加规则、持续时间、集中/打断、上限和等级缩放。

### 表现引用

- 施法动画、起手音效、起手特效。
- 投射物外观、拖尾、飞行循环音效。
- 命中特效、落地特效、爆炸、震屏、地面区域表现。
- GameCore `GameplayFeedbackSet` 槽位和 EX-GAS `GameplayCue` 引用。

表现引用不得成为规则真相；它只响应规则或执行结果。当前表现反馈的项目侧首选真相源是 GameCore `GameplayFeedbackSet`。EX-GAS `GameplayCue` 可以作为 GameplayEffect 或 TimelineAbility 的表现触发入口，但不得自己成为第二套反馈闭包，更不得负责伤害、治疗、资源变化或状态结算。

基础攻击此前曾存在 `GameplayEffectAsset.CueOnExecute -> FormalInstantDamageCue -> CharacterBase.Damage(...)` 这条迁移期偏离链路。`2026-06-26` 已收口到 `GameplayEffectAsset.Executions -> FormalInstantDamageExecution -> CharacterBase.Damage(...)`；因此当前结论不再是“继续允许 Cue 扣血”，而是“后续技能必须沿正式规则执行器扩展，Cue 只保留表现触发”。

## 与 GAS 的关系

EX-GAS 是底座，不是整个 WoW / D20 规则系统。

GAS 适合承担：

- Attribute、GameplayTag、GameplayEffect。
- Cost、Cooldown。
- GameplayCue 只作为表现触发入口，不作为规则结算入口。
- 持续状态和部分规则结果应用。

FantasyWord 自己必须承担：

- 动作经济、法术位/每日次数、准备/自发施法、升环/超魔。
- 职业能力、专长、先决条件、来源追踪和授予/撤回。
- 目标模板、触发器、Proc、豁免、法抗、免疫/抗性/易伤。
- 效果列表解释、叠加规则、持续/集中和存档。

正式调用方向应是：

```text
FantasyWord Rules Engine 解释 Ability/Effect/Trigger/Resolution 配置
-> 调用 GAS 应用属性、标签和 GameplayEffect
-> 由 GameCore GameplayFeedbackSet 播放项目侧表现
-> 必要时由 EX-GAS GameplayCue 触发 GAS 侧表现，但不得修改规则结果
```

## 玩家炼金式配置

玩家炼金式法术配置不是“给火球改几个数值”，而是生成一种受限的 `AbilityDefinition` 变体或 `RecipeAbility`：

- 玩家配方选择核心、载体、目标模板、触发事件、效果模块和代价模块。
- 系统把配方编译/解释为 Ability + Effect + Trigger + Cost 的组合。
- 存档保存稳定模块 ID 和参数，不保存运行时 ScriptableObject 实例。
- 第一版 UI 可以是槽位式或链式；自由节点图只是未来高级 UI，不是规则模型本体。

## 编辑器策略

当前不先做大型编辑器。当前只需要配置资产和校验门禁：

- 能创建/读取/校验 AbilityDefinition、EffectDefinition、TriggerDefinition、ResolutionDefinition。
- 能检查 ID、引用、目标模板、资源消耗、触发循环和重复结算。
- 能把 GAS 资产引用纳入同一份校验报告。
- 能用少量测试资产验证规则链路，不定义正式职业、正式法术内容或默认流派。

后续编辑器只是在这些配置合同上增加更好的录入体验。不得为了做编辑器而反过来发明无参考的资产模型。

## 禁止项

- 不把 `ProjectileDefinition / ImpactReaction` 当顶层架构；它们最多是 Effect/Presentation 的子类型。
- 不把基础攻击、火球、陨石这类单技能案例倒推成总体能力系统。
- 不把节点图作为当前规则系统地基；节点只可能是配方/触发的高级可视化 UI。
- 不用 EX-GAS 原生 Timeline 代替完整规则引擎。
- 不把 EX-GAS `GameplayCue` 当伤害、治疗、资源、状态或位移结算入口。
- 不新增与 `GameplayFeedbackSet` 并行的第二套项目侧反馈系统。
- 不在没有主流参考记录的情况下发明正式架构层级。
