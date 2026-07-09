# ability-authoring-foundation Specification

## Purpose
定义 FantasyWord 正式能力制作地基：优先验证 `EX-GAS` 原生能力、时间轴、TargetCatcher 与 GameplayEffect/GameplayCue 是否能直接承担正式技能主轴；若存在缺口，必须先在 `GAS` 主轴内补齐，而不是继续扩大项目侧同职责壳。

## Requirements
### Requirement: Ability Content MUST Wait For Confirmed Build Decisions

`FantasyWord` MUST treat unresolved build-model decisions as hard gates for content-specific implementation.

#### Scenario: Unconfirmed build decisions block formal content

- **WHEN** 职业结构、技能树归属、技能分类、技能获取方式、目标类型、资源类型、冷却形态、技能栏策略或 respec 规则尚未确认
- **THEN** 项目只能实现内容无关的数据合同、校验、运行时挂接点和作者链路地基
- **AND** 不得直接实现正式职业、正式技能树、正式技能内容或默认构筑模板

### Requirement: Formal Ability Flow MUST Use One Formal Truth Path

`FantasyWord` MUST converge on one formal ability production path and MUST NOT expose patch-up steps or parallel truth paths as authoring.

#### Scenario: Formal ability creation follows the single path

- **WHEN** 制作一个正式能力
- **THEN** 流程必须先以 `EX-GAS Ability/TimelineAbility/GameplayEffect/GameplayCue/TargetCatcher` 作为正式主轴候选
- **AND** 若当前能力可由 `EX-GAS` 原生闭包表达，则不得再为同一职责保留项目侧并行时间轴、并行命中框真相或并行规则结算壳
- **AND** 若 `EX-GAS` 当前闭包存在明确缺口，则必须先在 `GAS` 主轴内补齐缺口，再决定是否仍需要项目侧薄层
- **AND** 不得把测试场景修补、准备链路、修复接线、内部菜单或开发诊断写进正式制作步骤

### Requirement: Multi-Reference Adoption MUST Be Responsibility-Sliced

`FantasyWord` MUST treat multiple references as a responsibility-sliced selection process, not as permission to mix all sources into one chain.

#### Scenario: Multiple references are adopted by responsibility, not by accumulation

- **WHEN** 能力系统同时参考 `EX-GAS`、`2DRPGEngine`、`duolafashi`、Kybernetik 或其它成熟来源
- **THEN** 必须先按“规则真相”“表现反馈”“编辑器可视化”“运行时执行宿主”等职责切片后再裁决
- **AND** 同一职责只能保留一个正式 owner
- **AND** 其它来源只能作为 `仅观察`、局部证据或待迁移候选，不得在同一职责里并排落成正式链路

### Requirement: First Formal Slice MUST Stay On Foundational Attacks

`FantasyWord` MUST finish the foundational attack slice before expanding into complex spell families.

#### Scenario: First slice stays on basic attack, charged attack, and backstab hit flow

- **WHEN** 项目进入第一批正式能力实现
- **THEN** 首批闭包必须先覆盖基础攻击、蓄力攻击、背刺、动画驱动和碰撞盒命中
- **AND** 当前不进入火球、陨石雨、闪电链、追踪剑、吸血、抽魂等复杂法术闭包
- **AND** 若 EX-GAS 现有闭包不足，必须先证明具体缺口，再在 GAS 主轴内扩展正式实现

### Requirement: Rule Truth MUST Stay In EX-GAS

`FantasyWord` MUST keep gameplay rule resolution in EX-GAS instead of parallel local rule systems.

#### Scenario: Ability rules are resolved by EX-GAS

- **WHEN** 能力需要处理资源消耗、冷却、属性变化、标签、持续状态、伤害、治疗或授予/移除能力
- **THEN** 这些规则结果必须由 EX-GAS 正式规则资产和运行时承担
- **AND** 不得长期保留与 EX-GAS 同职责的并行项目侧规则真相

### Requirement: GAS Gaps MUST Be Closed In GAS First

`FantasyWord` MUST treat a missing GAS capability as a reason to extend GAS-side formal support first, not as default permission to expand project-side parallel shells.

#### Scenario: GAS lacks a needed 2D authoring or execution feature

- **WHEN** 正式技能作者流缺少 2D 命中框预览、2D TargetCatcher、时间轴预览能力或其它明确 GAS 缺口
- **THEN** 默认动作必须是先补 `EX-GAS` 主轴中的对应正式能力
- **AND** 不得把项目侧临时 ScriptableObject、场景碰撞体或运行时特判壳扩写成长期并行真相

### Requirement: Project Feedback MUST Have One Truth Source

`FantasyWord` MUST keep project-side presentation feedback in one formal truth source.

#### Scenario: Feedback stays in GameplayFeedbackSet

- **WHEN** 能力需要播放项目侧动画、音效、特效、震屏、飘字或其它反馈
- **THEN** 项目侧反馈必须收口到 `GameplayFeedbackSet` 或其唯一正式替代者
- **AND** EX-GAS `GameplayCue` 只允许作为表现触发器，不得演变为第二套反馈或规则系统

### Requirement: Hitbox Authoring MUST Be Reference-Gated

`FantasyWord` MUST NOT present raw inspector data or diagnostics as the formal hitbox authoring workflow.

#### Scenario: Hitbox editing waits for reference-backed authoring surface

- **WHEN** 项目准备实现近战命中框作者面
- **THEN** 必须先记录参考证据、当前落点、差距和验证入口
- **AND** 当前至少对齐 Kybernetik Platformer Game Kit 的动画窗口/命中框参考
- **AND** 在正式可视化作者面落地前，不得把静态预览、只读检查或盲填数据汇报成“策划可直接开工”

### Requirement: Sample Assets MUST Stay Explicitly Non-Formal

`FantasyWord` MUST allow sample assets for smoke, but MUST NOT treat them as formal content.

#### Scenario: Sample assets validate the chain without becoming formal defaults

- **WHEN** 当前阶段使用空白或样例能力资产验证创建、保存、加载、校验和运行时读取链路
- **THEN** 这些资产必须明确标记为样例或 smoke
- **AND** 不得默认挂进正式角色能力、正式职业构筑或正式数据库内容集
