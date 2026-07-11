## MODIFIED Requirements

### Requirement: Formal Ability Flow MUST Use One Formal Truth Path

`FantasyWord` MUST converge on one formal ability production path and MUST NOT expose patch-up steps or parallel truth paths as authoring.

#### Scenario: Formal ability creation follows EX-GAS as the only ability owner

- **WHEN** 制作或迁移一个正式能力
- **THEN** 技能身份、图标、输入、执行配置、授予、装备、保存、规则和作者入口必须由 `EX-GAS Ability Code`、`exgas.abilityGameCore`、Timeline、GameplayEffect 和 Cue 承担
- **AND** 项目侧 `AbilitySheet`、`ActiveAbilitySheet`、`PassiveAbilitySheet` 和 `MeleeAttackAbilitySheet` 类型不得作为正式入口、兼容壳或反序列化入口保留
- **AND** 旧存档或旧资产兼容必须迁移到 EX-GAS Ability Code 或明确的迁移数据，不能继续依赖旧能力表对象身份

### Requirement: First Formal Slice MUST Stay On Foundational Attacks

`FantasyWord` MUST finish the foundational melee attack slice before expanding into complex spell families.

#### Scenario: First slice stays on basic attack, charged attack, and backstab hit flow

- **WHEN** 项目进入第一批正式能力作者流重构
- **THEN** 首批正式作者流必须先覆盖基础攻击、蓄力攻击、背刺、动画驱动和碰撞盒命中
- **AND** 三者必须收口到同一套 EX-GAS Ability / Timeline / GameplayEffect / Cue 数据模型
- **AND** 当前不进入火球、陨石雨、闪电链、追踪剑、吸血、抽魂等复杂法术闭包

### Requirement: Hitbox Authoring MUST Use One GAS Timeline Truth

`FantasyWord` MUST base formal melee hitbox authoring on the EX-GAS timeline and target catcher pipeline.

#### Scenario: Formal melee hitbox authoring edits GAS timeline data

- **WHEN** 项目实现正式近战命中框作者面
- **THEN** 该作者面必须优先收口到 EX-GAS `AbilityTimelineEditor + XParamTimeline + TaskApplyEffects + TargetCatcher`
- **AND** `2DRPGEngine/CLineActionEditor` 只能作为时间轴易用性验收参考
- **AND** Kybernetik 只能作为动画帧命中框体验验收参考
- **AND** 不得把项目自造第二时间轴、工作台、测试链路或静态 Inspector 冒充成正式作者流
- **AND** Excel/Luban 只允许作为 EX-GAS 数据持久化/导表层，不得成为与 Unity 时间轴并行的人工配置入口

### Requirement: Melee Runtime MUST Keep One Execution Truth

`FantasyWord` MUST keep one melee execution truth source for hit timing and hitbox data.

#### Scenario: Melee runtime consumes one execution truth

- **WHEN** 基础攻击、蓄力攻击或背刺在运行时执行
- **THEN** 近战命中窗口、命中框数据和命中结果配置必须来自同一份正式 GAS 时间轴数据
- **AND** `AbilityExecutionAsset`、`MeleeAbilityExecutionAsset` 和旧能力表类型不得在项目侧保留为同职责兼容壳
- **AND** 动画事件、场景对象层级、临时编辑器缓存、项目自造时间轴或测试接线不得成为并行命中真相
- **AND** 多方向动画素材不得扩展成多方向 GAS 配置；GAS 只触发动作键，Animator / 装备动画系统解析方向变体，TargetCatcher 只保存一份本地形状并按命中帧施法者的当前位置与当前朝向变换
- **AND** 激活上下文中的可选输入瞄准方向不得自动覆盖 Timeline 后续任务的最终执行姿态
- **AND** 激活上下文中的方向必须是可选运行数据；无方向能力不得被强制要求方向，方向型 TargetCatcher 缺方向时必须明确报错并拒绝命中
- **AND** 命中后的伤害、状态和属性结算仍必须交给 EX-GAS 正式规则链
