# Proposal: composite-sandbox-character-foundation

## Why

当前地基不能再按“2DRPGEngine 整体更好”来理解。`FantasyWord` 的长期目标已经明确为受 Kenshi、博德之门和 ToME4 影响的复合沙盒 RPG：它需要多角色队伍、角色私有背包、RTS 命令链、复杂能力/状态变化、失败继续、Mod 扩展和未来有限人数主机权威合作。

这类游戏的核心风险不是某个框架是否强，而是同一职责出现多套真相：

- 角色长期数据、背包和存档在一套系统里。
- 动作执行、武器、受击和反馈在另一套系统里。
- GAS 又拥有属性、标签、冷却、消耗和状态规则。
- RTS 命令链还要求输入不再等同于“当前单主角直接操作”。

因此本提案的目的不是证明“全选 2DRPGEngine”。当前结论恰好相反：TopDownEngine 在当前重构之外仍有多个更好的参考面，尤其是 3C 闭包、武器状态机、受击/死亡/反馈、角色切换/变形样板、关卡动作对象和单 Agent 战斗样板。详细矩阵见 `character-closure-reference-matrix.md`。

本提案要明确分层：

- `2DRPGEngine / GameCore` 继续负责世界规则、数据库、地图、任务、对话、存档和 RPG 数据语义。
- `TopDownEngine` 继续作为角色闭包、能力组件、动作执行、武器、受击、反馈、角色切换和角色库存模式的重要参考。
- `EX-GAS` 作为属性、标签、冷却、消耗、能力授予/移除和状态效果的规则真相方向。
- `RTS Starter Kit` 只作为选择、订单、群组、阵型和批量命令链参考。
- `FantasyWord` 自己建立复合角色系统和开放世界模拟层，不把三方任何一边误升格成总框架。

## What Changes

- 修正“地基全是 2DRPGEngine 更好”的误读：2DRPGEngine 只赢世界规则和长期数据层，不赢动作角色闭包和复杂角色执行层。
- 扩大 TopDown 参考范围：不再只看移动手感或武器，而是把 `Character + TopDownController2D + CharacterAbility + CharacterInventory + CharacterPersistence + CharacterSwitch/Swap` 纳入角色闭包参考。
- 增加当前重构外的 TopDown 参考面：相机目标和切换刷新、动作反馈、武器状态机、交互/机关/拾取生命周期、跌落/区域动作对象和 AI 战斗样板。
- 将背包从“全局玩家背包真相”重判为“库存服务 + 多 owner 库存模型”：角色、容器、尸体、商店、地面物品和队伍钱包必须分清归属。
- 将能力系统明确拆成规则层和执行层：GAS 管规则，GameCore/TopDown 吸收闭包管动作执行，角色存档管能力来源和恢复。
- 将 RTS 要素纳入命令入口：本地玩家、AI、未来远程访客都应通过同一套正式命令/裁决入口改变世界。
- 将联机纳入边界、不纳入实现：本轮重构必须预留控制权、对象归属、物品归属、输入来源、房主裁决和存档写入边界，但不得接入 FishNet、RPC、同步字段或网络对象空壳。

## Non-Goals

- 不接入 ECS / DOTS。
- 不接入 FishNet、Mirror、NGO 或任何网络 SDK。
- 不创建 `Assets/Scripts/Networking`、RPC、同步字段、网络对象、网络权限或联机空壳。
- 不整体接管 TopDown manager、InputManager、GUIManager、LevelManager 或 InventoryEngine。
- 不把 2DRPGEngine 的全局 `InventorySystem.items/money` 继续当作最终多角色背包模型。
- 不照搬 Kenshi、博德之门、ToME4 的具体系统数据、规则文本、数值、职业、技能树、剧情、UI 或 IP 内容。

## Open Questions

- 多角色背包当前是否只覆盖队伍角色、容器和地面物品，还是同时覆盖商店、制作站、尸体和仓库。
- 角色变形/感染时，背包、装备和快捷栏的默认保留规则是否按效果单独配置，还是先提供项目默认策略。
- 队伍钱包是否从一开始独立于角色背包，还是随多角色背包当前一起迁出全局 `InventorySystem.money`。
- RTS 多选当前是否只覆盖移动/交互/拾取命令，还是直接纳入攻击、施法、工作和搬运。

## Acceptance Direction

- 后续实现提案和任务不得再把“2DRPGEngine 地基”解释成全系统优先 2DRPGEngine。
- 所有改变世界的动作必须能回答：谁发起、谁拥有、谁裁决、结果写到哪里。
- 背包、装备、能力、命令和状态变更必须保留未来主机权威裁决所需的边界，但不出现网络框架实现。
