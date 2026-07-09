## ADDED Requirements

### Requirement: Skill Implementation Flow MUST Wait For Confirmed Build-Model Decisions

`FantasyWord` MUST treat unresolved skill-editing and character-build model questions as implementation gates rather than filling them with default formal content.

#### Scenario: Unconfirmed build-model questions block content-specific implementation

- **WHEN** 职业结构、技能树归属、技能分类、技能获取方式、技能目标类型、资源类型、冷却形态、技能栏槽位策略或 respec 规则尚未得到用户确认
- **THEN** 项目只能实现内容无关的数据合同、校验框架、运行时挂接点和技能实现流程地基
- **AND** 不得直接实现正式职业、正式技能树、正式技能内容或默认构筑模板
- **AND** 不得为了推进速度擅自补默认技能、默认职业或默认流派

### Requirement: Skill Infrastructure MUST Stay Content-Agnostic Before Answers

`FantasyWord` MUST separate content-agnostic skill infrastructure from content-specific build content until the user confirms the formal build model.

#### Scenario: Safe framework work remains independent from final class and skill content

- **WHEN** 当前阶段先实现技能系统地基
- **THEN** 允许实现稳定 ID、数据库登记、引用解析、校验报告、授予来源追踪和最小运行时挂接
- **AND** 这些实现不得把某个默认职业、默认技能树或默认技能内容写成正式真相
- **AND** 不得新造与正式 owner 并行的第二套兼容层或临时真相源

### Requirement: Sample Ability Assets MUST Only Serve Smoke And Migration

`FantasyWord` MUST allow sample ability assets to validate the implementation pipeline before formal skill content is approved, but MUST NOT present those samples as the formal authoring flow.

#### Scenario: Sample assets are used only for smoke

- **WHEN** 当前阶段需要验证创建、保存、加载、校验和运行时读取链路
- **THEN** 项目可以使用样例技能资产、样例执行资产或样例表现配置
- **AND** 这些资产必须明确标记为样例或 smoke 资产
- **AND** 样例资产通过验证不等于正式职业、正式技能树或正式技能内容已完成
- **AND** 样例资产不得长期挂进正式角色默认能力或正式数据库登记中

### Requirement: The First Formal Skill Slice MUST Start With GAS-Backed Basic Attack

`FantasyWord` MUST implement the first formal skill slice as basic attack with GAS-backed rules and evidence-based action execution before entering charged attack, backstab, or more complex skill families.

#### Scenario: First formal skill implementation stays within the confirmed slice

- **WHEN** 项目开始进入本 change 的第一批正式技能实现
- **THEN** 当前首批闭包必须先覆盖基础攻击、动画驱动、碰撞盒命中和最小属性系统
- **AND** GAS 推荐闭包必须作为评估基线，但不自动排斥“动作执行 + GAS 规则结算”的融合方案
- **AND** 蓄力攻击、背刺、火球术、陨石雨、闪电链、追踪剑、吸血、抽魂等技能不属于当前基础攻击闭包
- **AND** 第一批实现不得因为抢进度而跳过基础攻击闭包

#### Scenario: GAS extensions require a proven formal gap

- **WHEN** 实现基础攻击、蓄力攻击或下一小阶段复杂技能时发现 GAS 现有闭包无法合理表达正式需求
- **THEN** 项目可以扩展 GAS
- **AND** 扩展前必须先能说明具体缺口是什么、为什么不能直接用现有 GAS 正式闭包表达
- **AND** 不得因为“未来可能会复杂”就预先并行造第二套能力系统

### Requirement: Mixed Ability Execution MUST Beat The Recommended Baseline Before Becoming Formal

`FantasyWord` MUST allow mixed ability execution only when evidence shows that the mixed responsibility split is better than the recommended GAS baseline for the confirmed slice.

#### Scenario: Mixed GAS and action execution is accepted only with evidence

- **WHEN** 基础攻击、蓄力攻击、背刺或后续技能考虑采用“项目侧动作执行 + GAS 规则结算”的混合方案
- **THEN** 混合方案必须先与 EX-GAS 推荐闭包和已选参考动作闭包对照
- **AND** 推荐用法默认是首选基线而不是禁止混合的红线，混合也不是违规形态
- **AND** 证明责任在混合方案
- **AND** 只有当混合方案在策划编辑效率、动画/碰撞盒可视化、调试可追踪性、运行时稳定性、资产迁移成本或长期扩展性上被证明比推荐用法更适合当前项目时，才允许进入正式链路
- **AND** 如果混合方案只与推荐用法持平、证据不足或只是因为现状已经这样实现，则不得把混合方案升为正式方案
- **AND** 正式混合方案必须保留单一公开入口、单一目标快照和单一结算结果

### Requirement: Hitbox Authoring MUST Be Reference-Gated

`FantasyWord` MUST NOT treat plain asset inspectors, smoke checks, or diagnostic scripts as the formal hitbox authoring workflow.

#### Scenario: Formal hitbox editor work starts only after reference evidence exists

- **WHEN** 项目准备实现基础攻击、蓄力攻击、背刺或其它动画窗口命中盒的作者 UI、资产模型或编辑入口
- **THEN** 必须先记录参考证据、当前落点、差距和验证入口
- **AND** 当前已登记的外部参考至少包括 Kybernetik Platformer Game Kit 的 melee hit boxes 文档
- **AND** 未完成参考矩阵前，不得新增正式判定框 UI、正式判定框资产模型或让策划同时维护两套命中盒真相

#### Scenario: Diagnostics stay out of the skill-making flow

- **WHEN** 项目提供只读检查、smoke 编排、资产完整性扫描或自动修复入口
- **THEN** 这些入口必须标记为开发诊断、自动化或样例链路维护
- **AND** 不得出现在策划“制作/修改技能”的主步骤中充当编辑器
- **AND** 不得把“诊断通过”汇报成“正式技能编辑器完成”或“判定框可视化编辑完成”

### Requirement: Ability Rules MUST Be Configuration-First And Reference-Grounded

`FantasyWord` MUST model skills, spells, feats, class abilities, item abilities, and player-crafted recipes as configuration-first rules before building large editor tooling.

#### Scenario: Formal ability rules use mainstream-inspired data layers

- **WHEN** 项目设计正式能力、法术、专长或物品能力系统
- **THEN** it MUST first define configuration contracts equivalent to ability identity, cast/action rules, costs, targets, effects, triggers/procs, and resolution rules
- **AND** those contracts MUST cite mainstream or local mature references before being treated as formal architecture
- **AND** projectile, area, summon, aura, damage, heal, and impact MUST be modeled as effect or execution/presentation subtypes rather than top-level architecture layers
- **AND** presentation references MUST remain subordinate to rule results instead of becoming a top-level rule truth
- **AND** large editor UI MUST be treated as a later authoring surface over the configuration contracts, not as the source of the data model

### Requirement: Skill Definition MUST Flow Through One Formal Path

`FantasyWord` MUST converge on one formal skill implementation path rather than human-visible patch-up steps.

#### Scenario: Skill creation follows a single formal path

- **WHEN** 策划或开发制作一个正式技能
- **THEN** 流程必须收口到 `AbilitySheet -> AbilityExecutionAsset -> 通用运行时壳 -> GAS 规则 -> GameplayFeedbackSet / GameplayCue 表现`
- **AND** `AbilitySheet` 负责技能身份、授予来源、目标入口、成本/冷却/GAS 映射和执行资产引用
- **AND** `AbilityExecutionAsset` 负责动画时序、命中框窗口、投射物/区域/召唤生成、命中反应、触发链和表现挂点
- **AND** 时间轴编辑与节点图编辑如果未来共存，也只能作为同一执行语义的不同编辑面
- **AND** 不得把测试场景修补、准备链路、修复接线或内部菜单写进正式技能制作步骤

### Requirement: Presentation Feedback MUST Have One Project Truth Source

`FantasyWord` MUST keep project-side presentation feedback in one formal truth source and MUST NOT use EX-GAS `GameplayCue` as a competing gameplay or feedback system.

#### Scenario: Project-side feedback resolves through GameplayFeedbackSet

- **WHEN** 技能、武器、命中、受伤、投射物命中、区域效果或法术配方需要播放项目侧动画、音效、特效、震屏、飘字或 MMFeedbacks 反馈
- **THEN** 项目侧反馈引用必须收口到现有 `GameplayFeedbackSet` 边界或其正式替代者
- **AND** 业务脚本不得为同一职责引入第二套项目侧反馈字段集或分发器
- **AND** EX-GAS `GameplayCue` 只允许触发或转发表现事件，不得形成第二套反馈真相

#### Scenario: GameplayCue does not own rule resolution

- **WHEN** `GameplayEffect`、`Ability`、`TimelineAbility` 或配方模块触发 EX-GAS `GameplayCue`
- **THEN** Cue 只能被视为表现触发器
- **AND** 它不得负责伤害、治疗、资源变化、状态变化、强制位移、目标选择、豁免结果、法抗结果、冷却变化、成本支付或持久化结果
- **AND** 这些规则结果必须由 `GameplayEffect`、`EffectDefinition`、`ResolutionDefinition` 或其它正式规则执行器负责

### Requirement: New Skill Flow MUST Reproduce The Current 2DRPG Skill Families

`FantasyWord` MUST be able to reproduce the current `2DRPGEngine` skill families with the new framework before claiming that the new flow is better.

#### Scenario: Runtime parity covers current 2DRPG skill families

- **WHEN** 项目将新框架与本地 `2DRPGEngine` 技能基线对照
- **THEN** it MUST account for the current local skill families `Melee`, `Projectile`, `Dash`, `SelfCast`, `Summoning`, `ContactDamage`, and `Ticking`
- **AND** 比较必须基于真实本地 `2DRPGEngine` 源码与编辑入口职责，而不是记忆或想象中的特性列表
- **AND** `FantasyWord` 必须保持一条正式能力资产流，能表达这些技能族，而不引入并行运行时真相

### Requirement: Player Spell Recipes MUST Support Triggers And Reactions

`FantasyWord` MUST treat player alchemy-style spell configuration as recipes over the same ability/effect/trigger/cost rule model, not only numeric modifiers.

#### Scenario: Spell recipe expresses event-driven reactions

- **WHEN** 玩家配置火球、法阵、投射物或其它可组合法术
- **THEN** 配方必须能编译或解释为与正式技能共用的 ability、effect、trigger/proc、target、cost 和 presentation 配置合同
- **AND** 配方必须能表达 cast、spawn、hit unit、hit ground、enter area、tick、expire、killed target、hit by element 等触发入口
- **AND** 配方必须能附加条件模块与效果模块，而不是只改数值
- **AND** 运行时必须保存稳定模块 ID 与参数，而不是给每个玩家法术复制一份 Unity `ScriptableObject`

#### Scenario: Node graph is an advanced UI, not the first runtime truth

- **WHEN** 后续玩家或 Mod 法术配方编辑需要大量分支、数据流链接、循环或可视化编排
- **THEN** 节点图可以作为高级编辑 UI 候选
- **AND** 节点图不得引入与正式配方系统行为不同的第二套运行时解释器
- **AND** 内部作者、玩家编辑与 Mod 编辑必须共享同一套运行时语义，只开放不同权限子集
