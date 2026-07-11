# 2D移动与场景组织参考接入流程

日期：`2026-06-14`

## 目的

把后续新增 2D 移动与场景组织参考时的固定动作写成活跃 change 文档，避免：

- 直接跳到实现
- 先造空接口/空宿主/兼容层
- 同一个参考每次重讲一遍口径

本文件不是实现计划，只服务于**参考接入判断**。
它只处理 `2D 移动与场景组织` 的 4 个一级缺口，不处理开放世界模拟层本身。

## 适用范围

只适用于以下 4 个一级框架缺口：

1. 单机/本地 2D 导航 Provider
2. 2D 点击移动执行闭包
3. 单机/本地场景实例宿主参考
4. 单机/本地出生点分流宿主参考

二级缺口：

- 控制对象与世界穿越目标统一
- 超距后自动靠近再施法/交互
- 传送入口条件

不得绕过这 4 个一级缺口单独推进。

## 固定流程

### 1. 先判命中哪个一级缺口

任何新参考先回答：

- 它命中 4 个一级缺口里的哪一个
- 还是只是某个二级缺口的局部证据

如果连一级缺口都对不上，只能继续登记，不进入实现讨论。

### 2. 只采信直接源码证据

优先级：

1. 本地可读源码
2. 官方文档附带可复核代码
3. 成熟插件/样板工程中的可运行代码

不采信：

- 只有产品宣传
- 只有视频演示
- 只有口头描述
- 只有设计理念但没有闭包代码

### 3. 拆成“可直接搬”与“强绑定部分”

每个参考至少拆成两栏：

- 可直接搬：
  - 当前能直接进入 `GameCore` 正式闭包的方法、字段、合同、数据结构
- 强绑定部分：
  - 绑第三方生命周期
  - 绑网络框架
  - 绑 3D NavMesh / CharacterController
  - 绑 MMORPG/副本业务
  - 绑第二套 manager / UI / 输入 / 存档真相

如果“可直接搬”这一栏为空，就只能登记，不实施。

### 4. 明确正式落点

能吸收时，必须写清楚准备落到哪里：

- `Movable`
- `PlayerController`
- `MapSystem`
- `MapInfo`
- `Teleporter`
- 或其它已存在的 `GameCore` 正式闭包

不得新增：

- `NavigationProvider` 空壳
- `ClickMoveController`
- `InstanceHost`
- `SpawnRoutingHost`
- 以及其它只为了先占位的同职责类型

### 5. 明确验收口径

每次接入参考前先写清：

- 这次只是 `只登记`
- 还是已经达到 `可直接吸收`

若是 `可直接吸收`，还要补：

- 对应静态证据
- 必要的定向验证入口

若没有足够证据证明“可直接吸收”，默认回到“只登记”。

## 收到新参考后的最短操作顺序

后面真拿到一个新仓库或新源码时，固定按下面顺序处理：

1. 先对照 `.spec/knowledge/features/project/2D移动与场景组织现态速查表.md`
   - 先确认它是不是还在当前 4 个一级缺口范围内
   - 避免把本机已经排除过的 3D / Mirror / demo 类型再读一遍
   - 若只是想先确认“项目里是否已有正式移动闭包、当前是否该继续实现”，先读 `.spec/knowledge/features/project/2D移动与场景组织下一步入口.md`
2. 再对照 `.spec/knowledge/features/project/2D移动与场景组织找参考清单.md`
   - 快速筛掉只有视频、只有 README、只有传送门、只有出生点数组的来源
3. 如果还值得继续，再按下面的 intake 空白模板填 1 条记录
4. 填完后只做一个裁决：
   - `直接吸收`
   - `只登记`
   - `放弃`
5. 只有裁决已经达到 `直接吸收`，才允许继续讨论代码落点和验证

## 单条 intake 空白模板

> 后面收到任何一个外部新参考，都可以直接复制这一段来填。

```md
参考名：

仓库路径 / URL：

分支 / tag / commit（如果有）：

命中的一级缺口：
- 单机/本地 2D 导航 Provider
- 2D 点击移动执行闭包
- 单机/本地场景实例宿主参考
- 单机/本地出生点分流宿主参考

证据文件：
- 
- 

关键证据定位（尽量带行号）：
- 
- 

可直接搬部分：
- 
- 

强绑定部分：
- 
- 

这是运行时代码还是只编辑器工具：

它是玩家专用、NPC 专用，还是两者共用：

当前裁决：
- 直接吸收
- 只登记
- 放弃

正式落点：

验收：
```

## 快速判退规则

出现下面任一情况，默认先判 `只登记` 或 `放弃`，不进入实现讨论：

- 只有视频，没有源码
- 只有 README，没有运行时代码
- 强绑 `Mirror`
- 强绑 `NavMeshAgent` / `CharacterController`
- 只有 3D 鼠标点地 demo
- 只有传送门，没有实例宿主
- 只有出生点数组，没有分流宿主
- 只有安全区 trigger / 区域 gizmo / `inSafeZone` 这类局部状态标记
- 只有死亡后显示复活按钮的 UI
- 只有怪物/NPC 自己的 `startPosition + respawnTime` 自复活状态机
- 只有一张产品型 `World.unity` 大场景，但看不到实例宿主、区域宿主或出生点分流宿主源码
- 只有接口，没有运行时闭包
- 命中的是二级缺口，但一级缺口本身还没补齐

补充：

- 证据如果不带源码定位，默认可信度下降一档
- 只有类名没有文件位置时，优先停在 `只登记`

## 最小 intake 记录模板

| 项 | 要填什么 |
| --- | --- |
| 参考名 | 工程名 / 插件名 / 文档名 |
| 命中缺口 | 4 个一级缺口里的哪一个 |
| 证据文件 | 直接命中的源码文件 |
| 可直接搬部分 | 可直接进入 `GameCore` 的闭包 |
| 强绑定部分 | 为什么当前不能整体搬 |
| 当前裁决 | `直接吸收` / `只登记` / `放弃` |
| 正式落点 | 若吸收，落到哪个现有正式闭包 |
| 验收 | 静态证据 / 定向验证 / 继续登记 |

## 当前候选参考预填 intake

> 这些是当前已经进入视野的候选项，先按同一模板预填。
> 这里的“当前裁决”是**当前证据下**的裁决，不代表永远不再变化。

| 参考名 | 命中缺口 | 证据文件 | 可直接搬部分 | 强绑定部分 | 当前裁决 | 正式落点 | 验收 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `uMMORPG Movement.cs` | 单机/本地 2D 导航 Provider | `Assets/uMMORPG/Scripts/Movement.cs` | `Reset / Warp / IsValidSpawnPoint / NearestValidDestination`，以及 `Navigate(destination, stoppingDistance)` 的停止半径合同 | `CanNavigate / Navigate / SetSpeed / DoCombatLookAt` 仍缺单机/本地 2D 导航真相；原实现体系服务于 NavMesh/网络角色移动合同 | 只登记 | 已融合到 `Movable` 的合同继续留在 `Movable`；其余未定 | 现有融合项以 `Movable` 静态证据和定向验证为准；未融合项继续登记 |
| `uMMORPG RegularNavMeshMovement.cs` | 单机/本地 2D 导航 Provider | `Assets/uMMORPG/Scripts/MovementSystems/RegularNavMeshMovement.cs` | 当前无 | 只是 `NavMeshMovement + NetworkNavMeshAgent` 的 Mirror 同步分支，额外强绑 `RpcWarp(...)`；不会补出新的 2D 导航真相 | 放弃 | 无 | 作为本机负证据保留，和 `NavMeshMovement.cs` 视为同一条 `NavMesh + Mirror` 实现线 |
| `uMMORPG PlayerNavMeshMovement.cs` | 2D 点击移动执行闭包 | `Assets/uMMORPG/Scripts/MovementSystems/PlayerNavMeshMovement.cs` | `MoveWASD()` 的“直接方向输入先取消旧路径”规则；点击目标先修正到最近合法落点这条思路 | 强绑 `NavMeshAgent`、3D 射线、本地相机、Mirror 玩家与 pending destination 状态 | 只登记 | 已融合到 `Movable.SetMovementDirection(...)` 的规则继续保留；点击移动未定 | 已融合项看 `MovableMovementTests`；点击移动继续登记 |
| `uMMORPG PlayerCharacterControllerMovement.cs + CharacterController2k.cs` | 单机/本地 2D 导航 Provider / 2D 点击移动执行闭包 | `Assets/uMMORPG/Scripts/MovementSystems/PlayerCharacterControllerMovement.cs`、`Assets/uMMORPG/Scripts/CharacterController2k/CharacterController2k.cs` | 当前无 | 强绑 `NetworkTransformBase`、`CharacterController2k`、`CapsuleCollider + Rigidbody` 与 3D `Physics.Raycast/CapsuleCast`；而且 `CanNavigate()` 返回 `false`、`Navigate(...)` 空实现、`NearestValidDestination(...)` 直接回原目标 | 放弃 | 无 | 作为本机负证据保留，后续不再把它当 2D 导航或点击移动候选 |
| `uMMORPG Instance.cs` | 单机/本地场景实例宿主参考 | `Assets/uMMORPG/Scripts/Instance.cs` | 只证明“实例宿主必须显式承载入口、归属、边界、实例内出生点和清理策略”，以及实例运行时位置应由宿主统一稳定决定 | 强绑 Mirror 队伍副本、网络实体清理、3D 边界、按 `partyId` 定位实例与副本业务 | 只登记 | 无；不得先落新宿主类型 | 继续登记到专项审计，不进入代码 |
| `uMMORPG PortalToInstance.cs` | 单机/本地场景实例宿主参考 | `Assets/uMMORPG/Scripts/PortalToInstance.cs` | 只证明“副本入口脚本”最多负责查找/创建实例，并把玩家送到实例宿主给出的 `entry` | 强绑 Mirror 队伍副本、`partyId`、实例模板字典、等级限制和服务器权威传送；它不是实例宿主本身 | 只登记 | 无；不得把入口脚本误当成实例宿主 | 继续登记到专项审计，不进入代码 |
| `uMMORPG GetStartPositionFor(...) + NetworkStartPositionForClass.cs` | 单机/本地出生点分流宿主参考 | `Assets/uMMORPG/Scripts/NetworkManagerMMO.cs`、`Assets/uMMORPG/Scripts/NetworkStartPositionForClass.cs` | 只证明“出生点分流应归正式宿主，而不是散在入口脚本里”，且找不到专用入口时要回退到默认出生点 | 强绑 Mirror 出生点与角色创建流程 | 只登记 | 无；不得先落新分流宿主 | 继续登记到专项审计，不进入代码 |
| `Assets/Plugins/AStar 2D Grid Pathfinding` | 单机/本地 2D 导航 Provider | `Assets/Plugins/AStar 2D Grid Pathfinding/AStar/Needed Scripts/AStarPathfinding.cs`、`AStarBoolMap.cs`、`AStarCostMap.cs`、`AStar/Example 1/Scripts/DemoGrid.cs`、`AStar/Example 1/Scripts/randomPather.cs`、`AStar/Example 2/Scripts/Grid/GridManager.cs`、`AStar/Example 2/Scripts/PathFindTest.cs` | 可直接复用的只有 2D 网格 A* 算法入口、bool/cost map 输入形状，以及示例里的 world/grid 映射与路径点跟随思路 | 缺正式导航状态、取消、停止半径、UI 遮挡和 `Movable / PlayerController` 共用运行时；现有 world/grid 映射仍是 demo 单例；`PathFindTest` 也只是“点两格画路径”，不是正式玩家点击移动闭包 | 只登记 | 无；后续若吸收，也只能落到现有 `Movable / PlayerController / IPlayerInputTarget` | 作为新的本地源码证据保留；当前结论仍是不足以直接关闭导航 Provider 缺口 |
| `Unity 2D/Tilemap 导航方案` | 单机/本地 2D 导航 Provider | 当前只有来源映射登记，没有具体方案源码 | 当前无 | 当前只是类别，不是可搬闭包 | 只登记 | 无 | 等锁定具体实现来源后再复核 |
| `2DRPGEngine NodeCanvas Pathfinding` | 单机/本地 2D 导航 Provider | `Assets/ParadoxNotion/NodeCanvas/Tasks/Actions/Movement/Pathfinding/MoveToPosition.cs`、`MoveToGameObject.cs`、`Patrol.cs`、`Wander.cs`、`Flee.cs` | 最多只证明 `stoppingDistance`、`SetDestination` 与 `ResetPath` 是常见路径任务写法 | 全部强绑 `UnityEngine.AI.NavMeshAgent` 与 `NavMesh.SamplePosition`；它是 3D NavMesh 任务包装，不是 2D 导航真相 | 只登记 | 无 | 作为本机负证据保留，后续不再重复排查这组源码 |
| `TopDown CharacterGridMovement.cs + GridManager.cs` | 单机/本地 2D 导航 Provider | `Assets/TopDownEngine/Common/Scripts/Characters/CharacterAbilities/CharacterGridMovement.cs`、`Assets/TopDownEngine/Common/Scripts/Managers/GridManager.cs` | 最多只证明 `world <-> cell` 换算、占格、输入缓冲和单格推进可以形成正式网格步进闭包 | 强绑 `GridManager.Instance`、`CellIsOccupied / OccupyCell / FreeCell`、格子中心点目标和 `TopDownController` 障碍射线；它是占格步进移动，不是自由 2D 导航 Provider，也没有点击寻路闭包 | 只登记 | 无 | 作为网格步进/占格系统样板和负证据保留，后续不升格为当前一级缺口解法 |
| `TopDown CharacterPathfindToMouse3D.cs + CharacterPathfinder3D.cs` | 2D 点击移动执行闭包 | `Assets/TopDownEngine/Common/Scripts/Characters/CharacterAbilities/CharacterPathfindToMouse3D.cs`、`CharacterPathfinder3D.cs` | 最多只证明“点击输入裁决 -> 目标对象 -> 路径能力执行 -> UI 可阻断输入”这条职责链 | 强绑 3D `Plane`、`InputManager.Instance.MousePosition`、旧 `Input.GetMouseButtonDown` 与 `CharacterPathfinder3D`；仍是 3D 玩家点击寻路样板 | 只登记 | 无 | 作为玩家侧 3D 点击寻路负证据保留 |
| `TopDown MouseDrivenPathfinderAI3D.cs + CharacterPathfinder3D.cs` | 2D 点击移动执行闭包 | `Assets/TopDownEngine/Common/Scripts/Characters/AI/Automation/MouseDrivenPathfinderAI3D.cs`、`Assets/TopDownEngine/Common/Scripts/Characters/CharacterAbilities/CharacterPathfinder3D.cs` | 当前无直接可搬 2D 闭包；只能证明“鼠标点地面 -> 设置目标 -> 最近可行点/路径阈值/路径刷新”这类职责应集中在正式路径执行层 | 强绑 `NavMesh`、`InputManager.Instance.MousePosition`、3D 平面射线和 `CharacterAbility` 路径器；本地源码也没有 `CharacterPathfinder2D` 或 `MouseDrivenPathfinderAI2D` | 只登记 | 无 | 等拿到真正 2D 点击移动闭包或可直接映射的样板后再复核 |
| `TopDown AutoRespawn.cs + Respawnable.cs + CharacterSelector.cs` | 单机/本地出生点分流宿主参考 | `Assets/TopDownEngine/Common/Scripts/Spawn/AutoRespawn.cs`、`Respawnable.cs`、`CharacterSelector.cs` | 最多只证明对象可响应玩家重生，以及 demo 里可先存选角再切场 | 不承接地图入口、默认回退、世界穿越或实例归属；`AutoRespawn` 只做对象自恢复，`CharacterSelector` 只做选角 demo | 只登记 | 无 | 作为局部重生/选角样板和假阳性负证据保留 |
| `TopDown GoToLevelEntryPoint.cs + GameManager.StorePointsOfEntry(...) + LevelManager.cs` | 单机/本地出生点分流宿主参考 | `Assets/TopDownEngine/Common/Scripts/Spawn/GoToLevelEntryPoint.cs`、`Assets/TopDownEngine/Common/Scripts/Managers/GameManager.cs`、`Assets/TopDownEngine/Common/Scripts/Managers/LevelManager.cs` | 只证明“跨场景入口索引”最好先存到正式宿主，再在目标场景按入口点解析 | 强绑 `GameManager.Instance`、场景切换、`PointsOfEntry` 存储和单玩家出生流程；不能表达当前项目要的通用出生点分流宿主 | 只登记 | 无 | 继续作为局部场景组织样板，不进入运行时代码 |
| `RTS Starter Kit` 当前路径 | 2D 点击移动执行闭包 / 未来队伍命令；不关闭 2D 导航 Provider | `Assets/InsaneSystems/RTSStarterKit/Scripts/Controls/InputHandler.cs`、`Controls/Ordering.cs`、`Controls/Selection.cs`、`Order.cs`、`Units/Unit.cs`、`Units/Movable.cs`、`UnitsFormations.cs`、`AI/UnitsGroup.cs` | 当前无可直接搬的完整移动闭包；只能摘“输入/选择 -> 订单对象 -> 单位订单队列 -> 移动模块执行”这条职责链，以及 `isAdditive` 追加命令、`EndCurrentOrder()` 停止命令、`sqrDistanceFineToStop` 到达半径、组下发和阵型落点这些局部证据 | 移动执行强绑 3D `NavMeshAgent`、3D `Physics.Raycast`、旧 `Input`、`GameController/Selection` 静态全局状态和 RTS 采集/建造/生产/战斗业务；不能整体搬，也不能替换当前 2D `Movable` | 只登记 | 若后续只吸收职责链，也必须继续落在现有 `Movable / PlayerController / IPlayerInputTarget`；不得新增并行 `ClickMoveController` 或 RTS 控制器 | 当前只作为职责证据与架构样板保留；不能据此宣称完整寻路闭包完成，也不能单凭这组源码进入实现 |
| `RTS SpawnController.cs + PlayerStartPoint.cs + GameController.cs + MapSettings.cs` | 单机/本地出生点分流宿主参考 | `Assets/InsaneSystems/RTSStarterKit/Scripts/SpawnController.cs`、`PlayerStartPoint.cs`、`GameController.cs`、`Storing/MapSettings.cs` | 最多只证明“专用起始点优先，找不到则回退其它点”的路由规则可以集中到正式生成宿主 | 强绑 RTS 对局初始化、`MatchSettings`、玩家阵营基地 prefab 和开局地图加载；它服务的是开局基地生成，不是地图入口/世界穿越出生点宿主 | 只登记 | 无 | 作为对局开局生成样板保留，不进入当前运行时代码 |

## 与当前文档的关系

- 总缺口表：`.spec/knowledge/features/project/2D移动与场景组织缺口矩阵.md`
- 现态速查：`.spec/knowledge/features/project/2D移动与场景组织现态速查表.md`
- 下一步入口：`.spec/knowledge/features/project/2D移动与场景组织下一步入口.md`
- 快速筛选单：`.spec/knowledge/features/project/2D移动与场景组织找参考清单.md`
- `uMMORPG` 专项取证：`ummorpg-movement-scene-audit.md`
- 正式规格约束：`specs/foundation-runtime/spec.md`
- 当前任务口径：`tasks.md`

## 当前结论

截至 `2026-06-14`：

- `uMMORPG` 仍只算局部源码证据源
- 4 个一级缺口仍未补齐正式参考
- 本机现有参考池也已经复核到当前边界；后续若没有新的源码参考，不应继续在本机旧参考上反复翻找
- 因此当前正确动作仍是：**继续登记新参考，不进入实现态**
