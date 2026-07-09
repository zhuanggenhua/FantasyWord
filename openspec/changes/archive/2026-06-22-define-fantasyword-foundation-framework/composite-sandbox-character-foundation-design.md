# Design: composite-sandbox-character-foundation

## Summary

复合沙盒角色地基采用“长期数据、规则、执行、命令、表现”分层，而不是选择一个总框架。

当前裁决不是“2DRPGEngine 全面胜出”。`2DRPGEngine` 只在 RPG 世界规则和长期数据层胜出；`TopDownEngine` 在角色执行闭包上继续胜出，且价值不止背包和能力系统。本 change 的专项参考矩阵见 `character-closure-reference-matrix.md`。

| 层 | 正式方向 | 主要参考 | 不采用范围 |
| --- | --- | --- | --- |
| 世界规则与长期数据 | `GameCore` 对齐 2DRPGEngine | 数据库、地图、任务、对话、存档、RPG 数据语义 | 不让它继续独占动作角色和多角色背包模型 |
| 角色规则 | `CharacterBase + ASC + Formal*` | EX-GAS | 不新增项目级 GAS manager，不做 Stats/GAS 双真相 |
| 动作执行 | GameCore 吸收 TopDown 模式 | TopDown `Character/CharacterAbility/TopDownController2D/Weapon/Health/Feedbacks` | 不接 TopDown manager、输入根、GUI、Level 生命周期 |
| 库存归属 | 多 owner 库存模型 | TopDown `CharacterInventory` 的 owner 概念 + 2DRPG 数据/存档语义 | 不照搬 `FindObjectsOfType`、`PlayerID` 字符串、MMInventory 事件总线 |
| 命令链 | 正式命令入口 | RTS Starter Kit `Selection/Ordering/Order/Unit` | 不搬 3D NavMesh、静态全局 RTS GameController、采集/建造业务 |
| 联机边界 | 主机权威兼容边界 | FishNet 作为未来候选，只作为传输层 | 当前不接包、不写 RPC、不建网络对象 |

## TopDown Reference Scope Beyond This Refactor

本轮重构先处理角色、库存、能力和命令边界，但 TopDown 的长期参考范围还包括：

- 角色、控制、相机目标的 3C 组合方式。
- 武器开始、延迟、使用、间隔、停止、装弹、打断、后坐力和动作期间移动/瞄准限制。
- 受击、死亡、冲刺、跌落、拾取、交互和相机反馈编排。
- 关卡动作对象，例如按钮激活、触发区、移动区域、跌落洞、拾取物生命周期和地牢机关。
- 角色切换/角色交换流程，用于后续变形、感染、丧尸化、访客接管和 AI 接管的状态迁移参考。
- 单 Agent 感知与战斗样板；但世界级日程、派系、经济和区域外模拟仍由 FantasyWord 自建。

这些都只能吸收到 GameCore 或后续项目正式 owner 中，不能让 TopDown manager、输入根、GUI 或 Level 生命周期接管项目。

## Character Foundation

当前重构不能只改背包和能力系统；它实际影响整个角色闭包：

- 角色 prefab 必须区分控制器、角色身份、模型、能力执行组件、规则组件、表现组件和库存 owner。
- `CharacterBase` 不应继续膨胀成承载所有执行细节的大类；它应保留角色身份、规则入口、存档编排、状态/能力查询和正式拥有者职责。
- TopDown 的关键价值是组合式角色：`Character` 缓存能力，`CharacterAbility` 统一处理许可、输入、更新、动画和重置，`TopDownController2D` 处理动作/碰撞执行。
- FantasyWord 不应直接搬 TopDown `Character`，但应吸收“角色聚合能力组件并统一调度”的模式。

## Inventory Foundation

多角色队伍目标下，旧全局背包口径不再成立。

正式方向：

- `InventorySystem` 从“全局背包真相”转为“库存服务、转移服务、查询服务、事件出口和存档编排入口”。
- 角色、容器、尸体、地面物品堆、商店、制作站和队伍钱包都应有明确 owner。
- 角色背包、装备栏、快捷栏和能力来源进入角色存档。
- 队伍钱包可以共享，但共享钱包不等于共享物品背包。
- 拾取默认进入执行拾取角色的背包；转移必须显式指定来源 owner 和目标 owner。

## Ability And Status Foundation

能力系统拆成三层：

- GAS 规则层：属性、标签、冷却、消耗、持续效果、叠层、阻断、能力授予/移除。
- 动作执行层：移动、冲刺、武器、命中窗口、投射物、召唤、动画触点和反馈触点。
- 角色持久化层：能力来源、装备授予、变形/感染授予、运行态恢复和旧档迁移。

变形、感染、丧尸化和奇特状态效果必须能表达：

- 保留部分能力。
- 替换部分能力。
- 禁用部分装备。
- 保留、锁定、掉落或转移背包。
- 改变阵营、AI、控制权或交互权限。

## Command And Control Foundation

RTS 要素不应直接把 UI 变成世界真相。

正式方向：

- 本地玩家输入、AI 决策和未来远程访客输入都生成命令。
- 命令目标可以是单个角色、角色组、容器、地面物品、敌人、NPC、地点或工作对象。
- 命令由正式规则入口裁决，UI 只发请求和显示结果。
- 多选时可以批量下发，但每个角色独立裁决距离、状态、负重、能力权限、装备限制和目标合法性。

## Networking Boundary

本轮重构要带联机边界，但不带联机实现。

必须带上的边界：

- 输入来源：本地玩家、AI、未来远程访客。
- 控制权：谁能控制哪个角色，失控/掉线后如何回 AI 或房主。
- 对象归属：角色、物品、容器、掉落、商店、制作站、阵营、任务状态。
- 裁决入口：移动、攻击、施法、拾取、丢弃、装备、卸装、转移物品、伤害、状态变化、犯罪和派系变化。
- 存档写入：只有裁决后的世界结果写入正式存档。

禁止带上的实现：

- FishNet 包。
- `Networking` 目录。
- RPC、同步字段、NetworkObject、网络权限字段。
- 为了未来联机而出现的网络 SDK 抽象。

## Migration Strategy

第一阶段不追求一次性完成全部复杂系统，而是先让边界不可逆地变清楚：

1. 先改文档和 spec：明确不是全 2DRPGEngine，TopDown/GAS/RTS 都有正式参考范围。
2. 再改数据模型：库存 owner、角色背包、装备/快捷栏归属、能力来源。
3. 再改命令入口：拾取、转移、装备、使用物品、施法、移动、交互统一走规则入口。
4. 再改 UI：显示当前查看角色/控制组/容器，而不是全局玩家背包。
5. 最后做联机专项：当单机命令链稳定后再接 FishNet。
