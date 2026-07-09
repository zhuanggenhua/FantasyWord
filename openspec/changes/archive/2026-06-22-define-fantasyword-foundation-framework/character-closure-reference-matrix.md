# Character Closure Reference Matrix

## Conclusion

当前结论不是“地基全选 2DRPGEngine”。更准确的判断是：

- `2DRPGEngine / GameCore` 是 RPG 世界规则和长期数据基线。
- `TopDownEngine` 在角色执行闭包上明显更完整，且价值不止本轮背包/能力重构。
- `EX-GAS` 负责能力规则、标签、冷却、消耗和状态效果真相。
- `RTS Starter Kit` 只竞争选择、订单、群组和批量命令链。
- `FantasyWord` 必须自建复合沙盒角色层与开放世界模拟层。

因此本轮提案不能写成“全迁 2DRPGEngine”。它必须写成分层吸收：长期数据归 GameCore，角色动作执行优先吸收 TopDown，复杂能力规则归 GAS，队伍命令入口吸收 RTS 思路。

## Evidence: Koala Prefab

`Assets/TopDownEngine/Demos/Koala2D/Prefabs/PlayableCharacters/Koala.prefab` 的本地等价落点为 `Assets/Plugins/TopDownEngine/Demos/Koala2D/Prefabs/PlayableCharacters/Koala.prefab`。该预制体不是单脚本角色，它同时装配了：

| Component | Meaning For FantasyWord |
| --- | --- |
| `TopDownController2D` | 2D 碰撞、移动、受力和动作执行参考。 |
| `Character` | 角色聚合根：缓存能力、统一调度 Early/Process/Late、驱动动画、处理状态和重生。 |
| `CharacterMovement` | 移动能力作为组件，而不是写死到角色大类。 |
| `CharacterOrientation2D` | 朝向和模型翻转作为独立能力。 |
| `CharacterDash2D` | 冲刺作为独立能力，带阻断与反馈。 |
| `CharacterRun` | 跑步作为独立能力。 |
| `CharacterPause` | 暂停/冻结类能力作为角色能力参与调度。 |
| `CharacterFallDownHoles2D` | 地形失败/跌落作为动作能力接入。 |
| `CharacterButtonActivation` | 按钮/交互触发能力。 |
| `CharacterHandleWeapon` | 武器使用作为能力组件，连接武器状态机与角色。 |
| `CharacterInventory` | 角色库存 owner、主背包、武器背包、快捷栏和自动装备参考。 |
| `Health` | 生命、受击、死亡、复活和反馈参考。 |
| `MMConeOfVision2D` | 感知/视野表现参考。 |
| 多个 `MMF_Player` | 跳跃、冲刺、受击、跌落、死亡等反馈编排参考。 |

这证明 TopDown 的参考范围必须包括“角色由多个能力组件组成，并由角色根统一调度”的模式；不能再把它缩写成移动手感或单脚本玩家控制器。

## Ownership Matrix

| Duty | Better Reference | Formal FantasyWord Owner | Why |
| --- | --- | --- | --- |
| 游戏启动、系统生命周期 | `2DRPGEngine` | `GameManager + AGameSystem` | 已有成熟 RPG 系统闭包，适合世界规则入口。 |
| 数据库、稳定引用、内容数据 | `2DRPGEngine` | `DatabaseRegistry` / GameCore 数据库 | 更适合 Mod、存档和长期内容审计。 |
| 存档聚合、地图、任务、对话 | `2DRPGEngine` | GameCore 对应系统 | RPG 长期数据语义完整。 |
| 角色预制体组合方式 | `TopDownEngine` | `CharacterBase/Hero` 吸收后的项目角色闭包 | Koala 证明控制器、角色身份、能力、武器、库存、反馈应拆成组件协作。 |
| 角色能力调度 | `TopDownEngine` | GameCore 能力执行闭包 | `Character` 统一调度多个 `CharacterAbility` 的输入、更新、动画和重置，这比单一大类可扩展。 |
| 2D 动作执行、冲刺、朝向、跌落 | `TopDownEngine` | `Movable` / 能力执行组件 | 这些是动作层，不应由 RPG 数据层硬写。 |
| 武器状态机、攻击节奏、装弹、打断、后坐力 | `TopDownEngine` | `WeaponExecutionRuntime` 等 GameCore 战斗执行层 | TopDown `Weapon` 的状态机和反馈触点比 2DRPG 基础 RPG 能力更完整。 |
| 命中、受击、死亡、无敌帧、反馈 | `TopDownEngine` + GameCore 数据 | GameCore Combat/Presentation | TopDown 强在动作表现与反馈，数值和状态仍归 GameCore/GAS。 |
| 角色库存 owner、武器栏、快捷栏 | TopDown 模式 + 2DRPG 存档语义 | `InventorySystem` 改为多 owner 库存服务 | TopDown 证明库存应挂到角色上下文；2DRPG 提供长期数据和存档方式。 |
| 装备授予能力、状态授予能力、变形保留/替换能力 | `EX-GAS` + TopDown 执行模式 | 角色持有 ASC，GameCore 执行动作 | GAS 负责规则，TopDown 模式负责执行组件化。 |
| 多选、订单队列、阵型、追加/停止命令 | `RTS Starter Kit` | 正式命令入口 | RTS 参考命令链，不搬 3D NavMesh 和静态全局 RTS 控制器。 |
| 相机跟随、相机目标、角色切换刷新 | `TopDownEngine` 模式 + GameCore 地图边界 | `PlayerCameraRig` / MapInfo 边界 | TopDown 对角色目标和事件刷新更完整，地图边界仍由 GameCore 提供。 |
| 出生点、检查点、重生表现 | 2DRPG 地图真相 + TopDown 表现样板 | `MapSystem/MapInfo/ICheckpoint` | TopDown 可吸收表现和重生流程，不接管 LevelManager。 |
| 世界区域、Cell、队伍、派系、AI 日程、经济/基地 | FantasyWord 自建 | 后续 World runtime owner | 2DRPG/TopDown 都不完整覆盖 Kenshi/Skyrim 级开放世界模拟。 |

## TopDown Wins Outside The Current Refactor

本轮最先动的是角色、背包、能力和命令边界，但 TopDown 在下列当前重构外的部分仍有参考优势：

- `3C 闭包`：角色、控制、相机目标必须一起裁决；TopDown 的角色目标、相机刷新事件和能力驱动动画值得继续吸收。
- `动作表现反馈`：受击、死亡、冲刺、跌落、武器使用、拾取和相机震动/停帧反馈应继续沿 `GameplayFeedbackSet` 或同级正式闭包吸收。
- `武器与命中节奏`：攻击开始、延迟、使用、间隔、停止、装弹、打断、后坐力和动作期间移动限制，TopDown 比 2DRPG 的 RPG 能力语义更完整。
- `关卡动作对象`：按钮激活、自动触发区、移动区域、跌落洞、拾取物生命周期和地牢机关，TopDown 比 2DRPG 更接近俯视角动作玩法。
- `角色切换/变形样板`：`CharacterSwitchManager` 和 `CharacterSwapManager` 不能整体接管，但“切换整套角色闭包、保留部分状态、刷新相机/输入/表现”的问题正对应变形、感染、丧尸化和访客接管。
- `AI 战斗样板`：TopDown 的单 Agent 行为、感知和战斗表现可作为 NPC 战斗参考；但世界级日程、派系、经济和区域外模拟不能由它接管。

## TopDown Non-Goals

以下部分不进入正式地基：

- 不接管 TopDown `GameManager`、`LevelManager`、`InputManager`、`GUIManager`。
- 不把 TopDown `Health`、`Weapon`、`CharacterAbility` 直接作为玩法真相源散落到项目侧。
- 不照搬 InventoryEngine 的 `FindObjectsOfType`、`PlayerID` 字符串匹配和全局事件总线。
- 不用 TopDown demo 场景或素材替代 MiniFantasy 正式美术基线。
- 不把 TopDown 的场景生命周期当成开放世界 Cell/区域/派系/日程模拟答案。

## Implementation Direction

第一阶段应先改 owner 和命令边界，而不是重写整个角色系统：

1. `InventorySystem` 先从全局背包扩展为显式 owner 库存服务，保留旧接口作为兼容入口。
2. 拾取、奖励、装备、使用物品和 UI 查询逐步改为显式 owner。
3. `CharacterBase` 保持角色长期身份、存档和规则入口，动作执行继续吸收 TopDown 的组件调度模式。
4. GAS 只接规则真相，不二次执行动作。
5. 未来联机只把远程输入送进同一正式命令入口，不创建网络空壳。
