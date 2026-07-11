# Proposal: complete-composite-sandbox-character-runtime

## Why

`define-fantasyword-foundation-framework` 归档时，为了先收口地基门禁，把一批仍然明显属于框架层、且已经有正式参考来源的事项降成了“归档后续事项”。

用户现已明确纠正这条范围：

- `控制组进阶` 不是可选玩法 embellishment，而是多角色开放世界框架的一部分。
- `RTS 命令链` 不是以后再加的业务层 UI，而是输入、裁决、所有权和世界状态写入口的正式框架。
- `GAS 完整合同` 不是可以长期停留在“部分接入、部分 archived”状态的候选，而是复杂开放世界角色规则层必须完成的正式替换。

因此这三块不能继续留在“foundation 已完成，未来再说”的口径里。它们都已经有明确参考面：

- `TopDownEngine`：角色执行闭包、能力组件调度、武器/反馈/动作阻断模式。
- `EX-GAS`：属性、标签、冷却、消耗、持续效果和能力授予/撤回规则真相。
- `RTS Starter Kit`：选择、控制组、订单、停止、队列和批量命令链思路。

这次 change 的目的不是重开整个 foundation，也不是加入具体玩法内容，而是把这些已经被认定为“必须存在的框架层能力”重新升格成当前正式实现目标。

## What Changes

- 把 `控制组进阶` 从“当前只支持最小控制组输入目标”推进到正式多成员控制组运行时。
- 把 `RTS 命令链` 从“已有命令上下文和局部命令入口”推进到正式订单链：选择、批量下发、停止、追加/覆盖、队列与队形落点语义。
- 把 `GAS 完整合同` 从“属性读取已优先走 ASC，但仍有 archived 过渡壳”推进到明确替换边界：属性、能力规则、持续效果和存读档恢复不再长期维持双轨。
- 维持原有总裁决不变：世界规则仍归 `GameCore/2DRPGEngine` 基线，动作执行仍吸收 `TopDownEngine`，工具层仍优先 `YokiFrame`，不引入新兼容层。

## Scope

本 change 只覆盖下列框架层事项：

- 控制组正式运行时、控制权和成员命令分发。
- RTS 风格正式命令入口、订单结构、停止/队列/批量语义。
- GAS 规则层与 archived 属性/效果/能力闭包的最终替换边界。
- 与以上三块直接相关的存档、读档恢复、静态门禁和必要 smoke。

本 change 不覆盖：

- 开放世界模拟层本体，例如区域、Cell、派系、日程、经济和基地。
- FishNet、RPC、同步字段、网络对象或任何联机实现。
- 具体职业、具体技能树、具体物品业务、具体商店流程或正式 HUD 演出。
- 把 TopDown、RTS 或 GAS 的 manager / lifecycle 直接并入项目总生命周期。

## Source Baseline

- 控制组与命令链参考基线：`archive/2026-06-22-define-fantasyword-foundation-framework/character-closure-reference-matrix.md`
- GAS 所有权与替换基线：`archive/2026-06-22-define-fantasyword-foundation-framework/attribute-gas-ownership-matrix.md`
- 复合角色分层基线：`archive/2026-06-22-define-fantasyword-foundation-framework/composite-sandbox-character-foundation-design.md`

## Acceptance Direction

- 不能再把这三块写成“foundation 之外的后续玩法扩展项”。
- 控制组、RTS 命令链和 GAS 替换都必须有单一真相，不允许靠兼容层或长期双轨维持。
- 完成证据必须落到正式运行时代码、正式 spec、静态门禁和必要 smoke，而不是只留矩阵或口头结论。
