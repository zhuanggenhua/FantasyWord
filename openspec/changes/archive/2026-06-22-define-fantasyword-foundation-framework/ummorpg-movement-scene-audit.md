# uMMORPG 移动与场景组织专项复核

日期：`2026-06-14`

## 目标

只复核 `uMMORPG Remastered - MMORPG Engine [2.41]` 在以下两类上的参考价值：

- 2D/角色移动合同
- 场景入口、出生点、场景实例组织

规则：

- 只接受有源码闭包的直接参考
- 能直接落到当前正式 `GameCore` 的才实施
- 其余只登记，不造兼容层、不写半成品接口

## 一句话裁决

- `uMMORPG` 当前只算 `2D 移动与场景组织` 的局部源码证据源，不当整体替换运行时。
- 它看起来像“大世界/MMO”，是因为本地源码里确实有 `PartySystem / GuildSystem / SafeZone / Instance` 这类联机或局部场景组织脚本。
- 但按 `2026-06-14` 对 `Assets/uMMORPG/Scripts` 的源码搜索，当前没有发现 `World / Cell / Faction / Economy / Base / Settlement / Region / Schedule` 这类开放世界模拟宿主闭包。
- 所以它当前最多只能补移动合同、实例宿主职责和出生点分流职责证据，不能升格成当前项目的开放世界基线。

## 为什么它“看起来像开放世界”，但当前仍不是开放世界基线

| 看起来像什么 | 实际源码证据 | 当前判定 |
| --- | --- | --- |
| 有安全区，像区域系统 | `SafeZone.cs:3-22` 只有 `BoxCollider` gizmo；运行时真正使用的是 `Entity.cs:127` 的 `inSafeZone`，并由 `Entity.cs:323-331` 写入 | 只是局部区域状态标记，不是区域/世界宿主 |
| 有复活面板，像统一重生系统 | `UIRespawn.cs:6-22` 只负责显示按钮并调用 `CmdRespawn()` | 只是 UI 入口，不是重生宿主 |
| 有玩家复活和怪物自复活，像统一出生/重生系统 | 玩家复活在 `Player.cs:714-729`；怪物自复活在 `Monster.cs:454-472` | 只是两套局部状态机，不是统一出生点分流宿主 |
| 有传送门，像场景入口系统 | `Portal.cs:5-38` 只是 `requiredLevel + destination + Warp(...)` | 只是入口薄脚本，不是实例/世界宿主 |
| 有实例出生点，像实例内出生系统 | `InstanceSpawnPoint.cs:5-7` 本体只有一个 `NetworkIdentity prefab` 字段 | 只是实例创建时顺手生成网络 prefab 的标记，不是实例出生点宿主 |
| 有职业出生点，像正式出生点分流系统 | `NetworkManagerMMO.cs:341-368` 把 `GetStartPositionFor(...)` 直接挂在 `CreateCharacter(...)`；`World.unity` 里还能看到 `Respawn & Spawn for Warrior` 与 `Respawn & Spawn for Archer` | 这是 Mirror 角色创建流里的按职业出生点分流，不是当前项目单机地图入口/世界穿越宿主 |
| 有一张 World 场景，像大世界宿主 | `World.unity` 根对象是 `Respawn`、`Environment`、`PortalWithinRocks`、`Minimap Camera`、`RespawnPanel`、`Main Camera`、`Directional Light`、`NetworkManager`、`EventSystem`，并混放职业出生点对象 | 这是 MMO 产品型主场景组织，不是当前单机场景宿主替换参考 |

## 复核文件

- `Assets/uMMORPG/Scripts/Database.cs`
- `Assets/uMMORPG/Scripts/Instance.cs`
- `Assets/uMMORPG/Scripts/Movement.cs`
- `Assets/uMMORPG/Scripts/MovementSystems/NavMeshMovement.cs`
- `Assets/uMMORPG/Scripts/MovementSystems/RegularNavMeshMovement.cs`
- `Assets/uMMORPG/Scripts/MovementSystems/PlayerNavMeshMovement.cs`
- `Assets/uMMORPG/Scripts/PlayerSkills.cs`
- `Assets/uMMORPG/Scripts/Portal.cs`
- `Assets/uMMORPG/Scripts/PortalToInstance.cs`
- `Assets/uMMORPG/Scripts/InstanceSpawnPoint.cs`
- `Assets/uMMORPG/Scripts/Monster.cs`
- `Assets/uMMORPG/Scripts/NetworkManagerMMO.cs`
- `Assets/uMMORPG/Scripts/NetworkStartPositionForClass.cs`

## MovementSystems 目录分型

当前 `Assets/uMMORPG/Scripts/MovementSystems` 目录已经可以按源码直接分成 4 条线：

| 文件 | 直接源码证据 | 当前分类 | 当前裁决 |
| --- | --- | --- | --- |
| `NavMeshMovement.cs` | `1-13` 明写 `NavMesh + NavMeshAgent movement` 且 `[RequireComponent(typeof(NavMeshAgent))]`；`56-59` 直接 `agent.destination = destination`；`64-74` 直接 `NavMesh.SamplePosition / agent.NearestValidDestination(...)` | `NavMesh + Mirror` 基类实现 | 只保留合同证据，不搬实现 |
| `RegularNavMeshMovement.cs` | `5-7` 直接 `[RequireComponent(typeof(NetworkNavMeshAgent))]`；`30-36` 的 `Warp(...)` 直接 `RpcWarp(destination)` | `NavMesh + NetworkNavMeshAgent` 同步分支 | 负证据，不再进入 2D 导航候选 |
| `PlayerNavMeshMovement.cs` | 仍是 `NavMeshMovement` 玩家线；价值主要在 `MoveWASD()` 的“直接输入先取消旧路径”和点击目标先过最近合法落点 | 玩家侧 `NavMesh + Rubberbanding` 规则证据 | 只保留局部规则，不搬整条点击移动实现 |
| `PlayerCharacterControllerMovement.cs` | `14-18` 直接要求 `CharacterController2k + AudioSource + NetworkTransformBase`；`191-199` 明确 `CanNavigate() = false`、`Navigate(...)` 空实现；`208-211` `NearestValidDestination(...)` 直接回原目标 | `Mirror + 3D CharacterController` 本地玩家线 | 明确判退，不再进入当前 2D 导航/点击移动讨论 |

进一步可确认：

- `CharacterController2k.cs:19-24` 写明这是 `capsule` 角色控制器，并强绑 `[RequireComponent(typeof(CapsuleCollider))]` 与 `[RequireComponent(typeof(Rigidbody))]`
- 它本体不是 2D 网格或 2D 导航器，而是另一条 3D 直立胶囊体运动体系

结论：

- 这 4 条实现线里，当前真正还能保留为局部证据源的，仍只有：
  - `Movement.cs`
  - `PlayerNavMeshMovement.cs`
- `NavMeshMovement.cs / RegularNavMeshMovement.cs`
  继续只算 `NavMesh + Mirror` 负证据
- `PlayerCharacterControllerMovement.cs + CharacterController2k.cs`
  继续只算 `Mirror + 3D CharacterController` 负证据

这代表：

- `uMMORPG` 的移动目录当前已经扫到边界
- 后续不应再把这 4 个文件重新当成“也许还能直接搬”的候选反复翻找

## 已确认可融合到现有正式闭包

### 1. Movement 合同里“传送/出生点合法性/最近合法落点”语义

源码证据：

- `Movement.cs:32-39`：`Reset / Warp`
- `Movement.cs:49-57`：`IsValidSpawnPoint / NearestValidDestination`

当前项目落点：

- `Assets/Scripts/GameCore/Runtime/Entities/Movable.cs`

当前现态：

- 已作为 `Movable` 的合同补强融合完成，不再新增动作。

## 本轮新增融合/补强

### 2. 手动方向驱动优先于旧导航路径

源码证据：

- `PlayerNavMeshMovement.cs:120-157`
- 核心动作是 `MoveWASD()` 内先 `agent.ResetMovement()`，然后再给直接方向速度与朝向。

当前项目落点：

- `Assets/Scripts/GameCore/Runtime/Entities/Movable.cs`

本轮融合：

- 当 `SetMovementDirection(...)` 收到非零方向时，若当前存在 `MoveOrder`，立即取消该 `MoveOrder`。
- 不在 `PlayerController` 里单独写分支，而是落回 `Movable` 正式真相源。

原因：

- 这是移动闭包本身的优先级规则，不是某个控制器特例。
- 这样未来无论是谁发出“直接方向驱动”，都会按同一移动规则先打断旧导航路径。

静态验证：

- 已补 `MovableMovementTests.SetMovementDirection_WithDirectInput_CancelsPendingMoveOrder()`

### 2.1 Navigate(destination, stoppingDistance) 的停止半径合同

源码证据：

- `Movement.cs` 的 `Navigate(Vector3 destination, float stoppingDistance)`
- `PlayerSkills.cs`、`Monster.cs` 等调用面都把“靠近到指定距离即算到达”当成正式合同，而不是要求精确踩到目标点。

当前项目落点：

- `Assets/Scripts/GameCore/Runtime/Entities/Movable.cs`

本轮融合：

- `MoveOrder` 增加 `stoppingDistance`
- `MoveTo(Vector2 destination, float stoppingDistance, float? speedOverride = null)` 成为正式重载
- `ExecuteMoveOrder()` 进入停止半径后即完成当前 `MoveOrder`

原因：

- 这是移动闭包本身的到达判定规则，不是点击移动业务特例。
- 当前仍保持 `Rigidbody2D + MoveOrder` 真相源，只融合“停止半径”合同，不引入 NavMesh、路径搜索或第二套控制器。

验证：

- 已补 `MovableMovementTests.MoveTo_WithStoppingDistance_CompletesWhenEnteringStopRadius()`
- `2026-06-14` 通过 AIBridge `script-execute` 直接运行正式 `Movable.MoveTo(..., 0.75f)` 链路取证：`completed=true`、`result=true`、`hasMoveOrder=false`、`finalDistance=0.64`、`steps=17`
- 当前 AIBridge `tests-run` 对该方法的结果回包仍不稳定，因此本轮不把“Test Runner 已稳定回绿”写成证据

### 3. 读档恢复时，若保存位置已对当前地图失效，就回退到正式出生点

源码证据：

- `Database.cs:544-559`
- 关键动作是：保存位置对当前 movement provider 不再合法时，不继续沿旧位置进图，而是回退到正式 start position 再 `Warp(...)`。

当前项目落点：

- `Assets/Scripts/GameCore/Runtime/Game/Systems/MapSystem.cs`

本轮融合：

- `MapSystem.LoadDataBlock(...)` 在恢复 `block.currentMap` 后，会额外校验当前穿越 Hero 的保存位置对当前活动地图是否仍合法。
- 若该位置已被当前 2D 碰撞闭包判为无效，则回退到 `MapInfo.initialSpawnCheckpoint`，并同步把这个正式出生点压回当前检查点栈顶部。

原因：

- 这是出生点/场景组织健壮性，不是点击移动业务。
- 当前项目的正式 start position 真相不是 `NetworkManager` 的 start position 列表，而是 `MapInfo.initialSpawnCheckpoint`；因此这里只把健壮性规则融合回 `MapSystem + MapInfo + Movable` 正式闭包。
- 这样不会把“角色先在失效位置进图，再靠后续更新碰运气脱墙”当成正式行为。

验证：

- 已补 `MapSystemTests.EnsureTraversalHeroValidSpawnOnActiveMap_InvalidSavedPositionFallsBackToInitialSpawn()`

### 4. 传送入口应向父级解析真正的玩家实体

源码证据：

- `Portal.cs:14-18`
- 关键动作是 `co.GetComponentInParent<Player>()`

当前项目落点：

- `Assets/Scripts/GameCore/Runtime/Maps/Teleporter.cs`

本轮融合：

- `Teleporter.OnTriggerStay2D(...)` 不再要求“碰到的 collider 自己就是玩家根对象”。
- 现在改为 `collision.GetComponentInParent<Hero>()`，再与 `PlayerSystem.GetPlayerInstance()` 对齐。

原因：

- 这条规则已经和当前 `Checkpoint` 的正式入口一致。
- 它能覆盖子碰撞体、骨骼碰撞体或角色子节点触发传送门的情况，不会因为碰到的是子 collider 就漏掉正式穿越目标。

验证：

- 已补 `TeleporterTests.OnTriggerStay2D_ChildColliderOfPlayer_TeleportsResolvedHero()`

## 明确不直接搬

### 1. Movement Provider 抽象的其余部分

源码证据：

- `Movement.cs:17-30`：`GetVelocity / IsMoving / SetSpeed / LookAtY`
- `Movement.cs:41-47`：`CanNavigate / Navigate`
- `Movement.cs:59-63`：`DoCombatLookAt`
- `NavMeshMovement.cs:51-77`
- `RegularNavMeshMovement.cs:5-35`

结论：

- `IsMoving()` 当前正式 `Movable` 已有。
- `SetSpeed / Navigate / CanNavigate / DoCombatLookAt` 在当前项目里还没有对应的 2D 导航 Provider 真相源。
- `LookAtY` 是 3D Y 轴转身，不适合当前 2D 俯视角 Sprite 闭包。

裁决：

- 不新增空接口、不写默认返回值、不造 `NavigationProvider` 占位类型。
- 等拿到 2D 导航参考闭包后再落正式实现。

补充：

- `RegularNavMeshMovement.cs` 当前只是 `NavMeshMovement` 的另一条同步分支，额外强绑 `NetworkNavMeshAgent` 与 `RpcWarp(...)`。
- 它只进一步证明 `uMMORPG` 这条导航实现线建立在 `NavMesh + Mirror` 上，不会补出新的 2D 导航真相。

### 2. 点击移动本身

源码证据：

- `PlayerNavMeshMovement.cs:166-199`
- 关键链路：点击命中地面 -> `NearestValidDestination(hit.point)` -> `Navigate(bestDestination, 0)`

结论：

- 这个实现证明了“点击目标先修正到最近合法落点”是对的。
- 但它依赖 `NavMeshAgent`、3D 射线、Mirror 玩家、本地相机和 `pendingDestination` 状态。

裁决：

- `uMMORPG` 这条线当前不直接提供可搬的点击移动正式闭包。
- 只保留两条规则作为以后找参考与复核当前基础点击移动链路的验收基线：
  1. 点击目标必须先过“最近合法落点”修正。
  2. 手动方向输入必须能取消旧点击路径。

补充现态：

- 当前项目自己的第一阶段基础点击移动链路已经落在现有 `Movable / PlayerController / IPlayerInputTarget` 闭包里。
- 这条链路现在只承诺“点地后按当前 2D 碰撞闭包直线靠近，并使用 `stoppingDistance` 判到达”，不能冒充完整 2D 导航 Provider。

### 2.1 进入施法/交互距离再执行动作

源码证据：

- `PlayerSkills.cs:59-80`
- `Monster.cs:153-158`、`259-264`
- `Monster.cs:467-472`

结论：

- `uMMORPG` 的正式做法不是“超距就失败”，而是先算目标最近有效接近点，再按 `castRange * ratio` 或 `interactionRange` 移动到可执行距离。
- 这里隐含了三条合同：
  1. 技能/交互的目标距离应按目标碰撞体最近点算，不按 pivot 中心点硬算。
  2. 靠近距离不是固定 0，而是“施法/交互可接受半径”。
  3. 靠近完成后要自动续接原动作。

当前裁决：

- 只登记，不实施。
- 原因不是“这条规则不好”，而是它已经进入技能、怪物 AI、交互与点击移动业务闭包，需要当前项目先有正式 2D 导航 Provider、目标最近点工具和“移动后续接动作”的正式入口，才能直接搬。
- 当前项目虽然已经吸收了 `stoppingDistance`，但还没有正式的“超距后自动靠近再施放/交互”闭包；现在硬做会越过“框架先于业务”的边界。

### 2.2 PlayerCharacterControllerMovement / CharacterController2k 不是当前 2D 参考

源码证据：

- `PlayerCharacterControllerMovement.cs:13-16`
- `PlayerCharacterControllerMovement.cs:191-209`
- `CharacterController2k.cs:19-24`
- `CharacterController2k.cs` 大量 `Physics.Raycast / CapsuleCast / CheckCapsule`

可确认的事实：

- `PlayerCharacterControllerMovement` 直接要求：
  - `CharacterController2k`
  - `AudioSource`
  - `NetworkTransformBase`
- 它自己的 `Movement` 覆写也已经把边界写死了：
  - `CanNavigate()` 返回 `false`
  - `Navigate(...)` 空实现
  - `NearestValidDestination(...)` 直接返回原目标
- `CharacterController2k` 本体是 3D 直立胶囊体运动与碰撞闭包，核心依赖 `CapsuleCollider + Rigidbody`，并大量使用 `Physics.Raycast / Physics.CapsuleCast / Physics.CheckCapsule`。

结论：

- 这套源码不是“另一种可选 2D 导航 Provider”。
- 它也不是“点击移动只差补一点逻辑就能搬”的半成品。
- 它本质上是 Mirror 本地玩家 + 3D CharacterController 运动体系；和当前项目 `Rigidbody2D + 俯视角 Sprite` 正式闭包不是一类东西。

裁决：

- 只登记为负证据，不实施。
- 后续若再看 `uMMORPG` 的移动源码，`Movement.cs / PlayerNavMeshMovement.cs` 继续是局部证据源；`PlayerCharacterControllerMovement / CharacterController2k` 不再进入“可能直接搬”的讨论。

### 2.3 MovementSystems 目录已经分类完毕

按 `2026-06-14` 对 `Assets/uMMORPG/Scripts/MovementSystems` 的完整复核，当前目录里共有 4 条实现线：

1. `NavMeshMovement.cs`
   - `NavMeshAgent` 基类实现
2. `RegularNavMeshMovement.cs`
   - `NavMeshMovement + NetworkNavMeshAgent`
3. `PlayerNavMeshMovement.cs`
   - `NavMeshMovement + NetworkNavMeshAgentRubberbanding + 点击/WASD 玩家链`
4. `PlayerCharacterControllerMovement.cs`
   - `CharacterController2k + NetworkTransformBase` 本地玩家链

当前结论：

- 这 4 条线里，没有一条能直接补当前项目缺的“单机/本地 2D 导航 Provider”或“2D 点击移动正式闭包”。
- 其中真正还能保留为局部证据源的，仍只有：
  - `Movement.cs`
  - `PlayerNavMeshMovement.cs`
- `NavMeshMovement.cs / RegularNavMeshMovement.cs`
  继续只算 `NavMesh + Mirror` 负证据；
- `PlayerCharacterControllerMovement.cs + CharacterController2k.cs`
  继续只算 `Mirror + 3D CharacterController` 负证据。
- 目录级裁决已经在上面的“MovementSystems 目录分型”固定；后续若没有新的 `uMMORPG` 文件进入视野，不再重复把这组实现线当作候选重新讨论。

### 3. Portal / PortalToInstance / InstanceSpawnPoint / NetworkStartPositionForClass

源码证据：

- `Portal.cs:7-34`
- `PortalToInstance.cs:8-68`
- `InstanceSpawnPoint.cs:5-7`
- `NetworkStartPositionForClass.cs:5-7`

结论：

- `Portal.cs` 的可用价值一共有两条：`入口校验与移动层 Warp 分离`，以及 `向父级解析真正玩家实体`。
- `PortalToInstance.cs` 是 Mirror 队伍副本业务，不是当前单机开放世界正式运行时入口。
- `InstanceSpawnPoint.cs` 与 `NetworkStartPositionForClass.cs` 都直接绑 Mirror 网络出生点体系。
- 进一步按 `2026-06-17` 复核，`InstanceSpawnPoint.cs` 本体只有一个 `NetworkIdentity prefab` 字段；它只是“创建实例时要顺手生成哪些网络 prefab”的标记，不是单机实例内出生点逻辑宿主。

裁决：

- 当前不搬。
- 继续使用现有 `Teleporter + MapSystem + Checkpoint` 正式闭包。

补充边界：

- `PortalToInstance.cs` 明确要求“只让根 collider 触发一次”，所以它故意用 `GetComponent<Player>()` 而不是 `GetComponentInParent<Player>()`。
- 当前项目 `Teleporter` 已反向裁决为“允许子碰撞体回溯正式 Hero”，因为当前更需要解决 2D 角色子碰撞体漏触发问题；重复触发则由 `Teleporter._teleportationInProgress` 收口。
- 这两条不是谁绝对更对，而是服务的正式闭包不同；因此这里不做源码替换，只保留差异记录。

### 3.0 Portal 入口条件

源码证据：

- `Portal.cs:7-29`

可确认的价值：

- 传送入口不只是“碰到就传”，还可以带正式入口条件；
- `uMMORPG` 当前给出的最小例子是 `requiredLevel`；
- 条件不满足时，入口本身负责拒绝这次穿越，而不是把玩家先传过去再回滚。

当前项目对照：

- 当前 `Teleporter` 只有：
  - 目标检查点
  - 到达后是否保存检查点
  - 必须的水平/垂直移动方向
- 当前项目已经有通用 `ICondition` 闭包，但还没有现成的“玩家等级至少多少”条件；
- 当前 `Teleporter` 也没有正式的拒绝提示真相源，不能直接照着 `Portal.cs` 补一条 UI 文案就算完成。

裁决：

- 只登记，不实施。
- 这条规则本身有价值，但当前若直接抄成 `requiredLevel` 字段，会把入口条件硬编码进 `Teleporter`，而不是回到已经存在的项目条件系统。
- 后续如果要补这条，优先方向应是“Teleporter 允许挂正式 `ICondition`”，再由专门条件实现去表达等级/任务/旗标等入口约束；但在拿到更完整参考前，本轮不落代码。

### 3.1 Instance 宿主的场景组织信息

源码证据：

- `Instance.cs:10-24`
- `Instance.cs:52-68`
- `Instance.cs:100-170`
- `Instance.cs:185-238`
- `NetworkManagerMMO.cs:GetStartPositionFor(...)`

可确认的价值：

- `Instance` 把“实例模板”建成显式宿主，至少包含：
  - `entry`：实例入口
  - `bounds`：实例边界
  - `spawnPoints`：实例内网络出生点缓存
  - `instanceLimit`：模板实例数量上限
  - `partyId`：实例归属
- 实例生命周期也有明确宿主规则：
  - 模板与运行时实例分离
  - 运行时实例的创建入口集中在 `Instance.CreateInstance(...)`
  - 运行时实例通过 `spawnPoints` 缓存批量生成实例内实体
  - 实例销毁时需要清理其边界内的网络实体
  - 非实例成员进入实例边界后要被踢回正式出生点
- 运行时实例的位置不是随便找空位，而是按模板 `bounds` 和 `partyId` 计算稳定偏移量；这证明“实例宿主必须自己掌握边界和实例定位规则”，不能只靠一个传送门脚本硬跳。

当前项目对照：

- 当前项目正式 `MapInfo` 只承载：
  - `initialSpawnCheckpoint`
  - `playtestCheckpoint`
  - `respawnDelay`
  - `levelBounds`
  - `cameraTarget`
- 也就是说，当前项目**只有地图表现配置宿主**，还没有：
  - 单机/本地实例模板宿主
  - 实例归属字段
  - 实例入口字段
  - 实例内出生点缓存
  - 实例离场清理策略

裁决：

- 只登记，不实施。
- 原因是 `Instance.cs` 的有效部分已经跨进 Mirror 副本、队伍归属、网络实体清理与 3D 边界检测闭包，不能直接塞回当前单机 `MapSystem + MapInfo + Teleporter` 正式真相。
- 但它证明了一件事：以后如果要做单机/小队区域实例，不能只靠 `MapInfo.initialSpawnCheckpoint`；必须有一个更明确的“实例宿主”来承载入口、归属、边界和实例内出生点。
- 当前真正缺的不是“再抄一个 `PortalToInstance`”，而是**单机/本地、非 3D NavMesh 的实例宿主参考**。没有这类参考前，不得在 `MapSystem`、`MapInfo` 或 `Teleporter` 上脑补出一套 `InstanceHost` 空壳。

### 3.2 类/模板出生点分流宿主

源码证据：

- `NetworkManagerMMO.cs:GetStartPositionFor(...)`
- `NetworkStartPositionForClass.cs:5-7`

可确认的价值：

- `uMMORPG` 没把“新角色出生到哪”散落写进传送门、地图脚本或角色 Prefab；
- 它把“按类名路由到显式出生点，找不到时再回退到普通 start position”的规则，集中放在正式出生点宿主里；
- 这说明“出生点分流”本身也是一类正式场景组织能力，不应靠临时 if/else 散落在入口脚本里。

当前项目对照：

- 当前项目正式出生点真相只有 `MapInfo.initialSpawnCheckpoint`；
- 还没有“按角色模板/控制组/世界入口条件分流到不同出生点”的正式宿主；
- 如果现在直接把这类分流逻辑塞进 `Teleporter`、`MapSystem.LoadDataBlock(...)` 或 `MapInfo` 字段，会先把单机地图入口、实例入口和未来多角色入口混成一层。
- 进一步按 `2026-06-17` 复核，`NetworkManagerMMO.GetStartPositionFor(...)` 的直接调用点就在 `CreateCharacter(...) -> player.transform.position = GetStartPositionFor(player.className).position` 这条角色创建链上；`World.unity` 里也明确摆着 `Respawn & Spawn for Warrior` 与 `Respawn & Spawn for Archer` 这类职业出生点根对象。也就是说，它当前证明的是“Mirror 角色创建流里的按职业出生点分流”，不是当前项目单机地图入口或世界穿越入口的通用宿主。

裁决：

- 只登记，不实施。
- 这条证据能说明“出生点分流应该归正式宿主”，但它当前仍强绑 Mirror `NetworkStartPosition` 和职业/玩家模板创建流程，不能直接搬进 `GameCore`。
- 当前缺的不是再抄一份 `GetStartPositionFor(...)`，而是**单机/本地出生点分流宿主参考**。没有这类参考前，不得把类出生点分流硬编码进 `Teleporter`、`MapInfo` 或 `PlayerSystem`。

### 3.3 它不是开放世界模拟层参考

源码证据：

- `Assets/uMMORPG/Scripts/PartySystem.cs`
- `Assets/uMMORPG/Scripts/GuildSystem.cs`
- `Assets/uMMORPG/Scripts/SafeZone.cs`
- `2026-06-14` 对 `Assets/uMMORPG/Scripts` 搜索 `World / Cell / Faction / Economy / Base / Settlement / Region / Schedule`

可确认的价值：

- 当前本地源码里确实有：
  - 队伍：`PartySystem`
  - 公会：`GuildSystem`
  - 局部安全区：`SafeZone`
- 这说明它有联机 RPG 常见的局部组织与社交脚本，不是只有移动和传送。

当前项目对照：

- 当前目标按 `Skyrim + Kenshi` 复核后，真正缺的是开放世界模拟层：
  - 区域 / Cell
  - 队伍控制权
  - 派系关系
  - AI 日程
  - 经济 / 基地生产
  - 区域外局部模拟
- 这次源码搜索没有发现 `World / Cell / Faction / Economy / Base / Settlement / Region` 这类正式宿主闭包；`SafeZone` 也只证明局部区域规则，不等于区域流送或世界状态宿主。

裁决：

- 只登记，不实施。
- `uMMORPG` 当前最多只能补“移动合同 + 局部场景组织职责”的证据，不能补当前项目真正缺的开放世界模拟层。
- 因此后续若讨论“它是不是更像开放世界地基”，正式口径应是：**不是**；它更像带副本/出生点分流/联机社交脚本的 MMORPG 局部组织参考。

## 现在缺什么参考

以下缺口这次只登记，不实现。为避免把“框架缺口”和“业务待做”混在一起，这里分成两层：

### A. 当前 2D 移动与场景组织的 4 个一级框架缺口

1. 2D 导航 Provider 正式参考
   - 要能支撑点击移动、NPC 日程移动、队伍命令共用同一导航真相。
   - 不能绑定 Mirror、3D NavMeshAgent、CharacterController 或 MMORPG 状态机。

2. 2D 点击移动执行闭包
   - 要有目标修正、路径取消、停止距离、被 UI 遮挡时不落地等完整规则。

3. 单机/本地场景实例宿主参考
   - 要回答单机/未来小队模式下，区域实例或副本入口怎么组织。
   - 至少要能回答实例宿主字段放在哪：入口、归属、边界、实例内出生点、离场清理策略分别归谁管。
   - 最好还能回答实例定位规则是否稳定可重建，例如 `uMMORPG Instance.CreateInstance(...)` 那样由宿主统一决定实例偏移/定位，而不是把运行时实例位置散落在传送入口脚本里。

4. 单机/本地出生点分流宿主参考
   - 要回答单机/未来小队模式下，地图入口、角色模板入口或未来控制组入口的出生点该如何分流。
   - 至少要能回答出生点分流规则挂在哪个正式宿主上，而不是散落在 `Teleporter`、`MapInfo` 或 `PlayerSystem` 的局部 if/else 里。
   - 最好还能回答分流失败时的正式回退规则，例如找不到专用出生点时是否回落到默认出生点宿主。

### B. 从上述一级缺口继续展开的 3 个二级框架缺口

5. 当前控制对象与世界穿越目标的统一参考
   - 当前 `MapSystem/Teleporter` 仍只对玩家存档 Hero 建模。
   - 后续若要让控制组或队友参与穿越，需要新的正式参考，不应从 `uMMORPG` 的 Mirror 玩家入口硬译。

6. “超距后自动靠近再施法/交互”的正式 2D 参考
   - 要同时覆盖目标最近点、停止半径、靠近完成后的续接动作，以及玩家/NPC 共用的导航真相。
   - 不能依赖 Mirror `pendingSkill/useSkillWhenCloser`、3D NavMeshAgent 或 MMORPG 状态机字符串。

7. 传送入口条件的正式参考
   - 当前 `Portal.requiredLevel` 只证明“入口可以有条件”，不足以直接裁决当前项目到底应做成硬编码字段还是通用 `ICondition` 宿主。
   - 需要能同时回答：入口条件挂载点、拒绝时的正式提示/反馈真相，以及条件变化时是否需要编辑器可见状态联动。

## 当前结论

`uMMORPG` 对当前项目真正有价值的，当前共有六条源码证据：

- 移动合同拆分
- 手动输入如何打断旧导航路径
- 停止半径如何作为正式到达判定
- 读档恢复时如何把失效保存位置回退到正式出生点
- 传送入口如何从子碰撞体回溯到真正的玩家实体
- 场景组织最好把“实例宿主”和“出生点分流宿主”显式建成正式宿主，而不是散落在入口脚本里

其中要分清两类：

- 前 5 条移动/传送/读档入口规则，已经分别作为合同、规则或健壮性补强融合到 `Movable / MapSystem / Teleporter` 正式闭包；这不是重复搬运 `uMMORPG` 的同职责实现。
- 第 6 条“实例宿主 / 出生点分流宿主应显式存在”当前仍只是职责证据，不等于当前项目已经有可直接搬运的单机/本地实现。

它不能作为当前 2D 移动实现、开放世界场景组织、联机框架或副本体系的整体替换源。

## 2026-06-15 新增场景组织负证据

### `World.unity` 不是当前单机场景组织替换参考

源码/资源证据：

- `Assets/uMMORPG/Scenes/World.unity`

本机复核到的事实：

- 当前工程只看到这一张主场景。
- 根对象是 `NetworkManager`、`Environment`、`Main Camera`、`Minimap Camera`、`Directional Light`、`EventSystem`、多个 `Portal/Respawn` 入口和一组 UI 根对象混放。
- 这张场景里还直接出现了 `Respawn & Spawn for Warrior`、`Respawn & Spawn for Archer` 这类职业出生点对象名，进一步说明它的出生点组织依附在 Mirror 角色创建/复活链路里，而不是当前项目要的单机通用出生点宿主。
- 本轮补充更精确的 YAML 证据：`World.unity` 内当前可直接命中的对象名包括 `Respawn:14116`、`Environment:16636`、`PortalWithinRocks:18538`、`Minimap Camera:22431`、`RespawnPanel:25396`、`Main Camera:27894`、`Directional Light:33530`、`Respawn & Spawn for Warrior:41880`、`Respawn:44312`、`NetworkManager:47940`、`EventSystem:66480`、`Respawn & Spawn for Archer:67270`。

结论：

- 这是一种 MMO 产品型单大场景组织，不是当前单机 `Game Manager + 场景级系统对象平铺 + 预摆玩家角色` 的更优替换参考。
- 它最多只能作为负证据，说明 `uMMORPG` 的场景组织重心在 `NetworkManager` 主导的产品入口，而不是当前项目需要的单机系统平铺宿主。
- 因此本轮仍不改当前正式场景组织裁决，只把这条事实补进留档，防止后续再把 `World.unity` 误读成当前应照搬的场景结构。

## 2026-06-17 新增安全区与复活边界证据

### `SafeZone` 不是世界宿主，只是局部区域标记

源码证据：

- `Assets/uMMORPG/Scripts/SafeZone.cs`
- `Assets/uMMORPG/Scripts/Entity.cs:127`
- `Assets/uMMORPG/Scripts/Entity.cs:257`
- `Assets/uMMORPG/Scripts/Entity.cs:323-331`
- `Assets/uMMORPG/Scripts/Monster.cs:122-123`

可确认的事实：

- `SafeZone.cs` 本体只有 `BoxCollider` gizmo 绘制，没有区域管理、实例管理、出生点路由或世界状态宿主逻辑。
- 真正进入运行时真相的是 `Entity.inSafeZone` 这个布尔状态。
- 这个状态由 `Entity.OnTriggerEnter/OnTriggerExit` 在碰到 `SafeZone` trigger 时写入。
- 怪物侧只是读取 `target.inSafeZone`，把它当成“目标进安全区后的仇恨/反风筝规则”条件。

结论：

- `SafeZone` 只能证明“局部区域规则可以靠场景触发器给实体打状态标记”。
- 它不能证明 `uMMORPG` 已经有 `World / Cell / Region` 这类开放世界区域宿主。
- 它也不能补当前项目缺的单机/本地实例宿主或出生点分流宿主。

裁决：

- 只登记，不实施。
- 后续若要做区域规则或安全区，最多参考“区域 trigger -> 实体状态标记 -> 战斗/AI 自己读取”这条局部思路；当前不把它升格成世界层参考。

### `UIRespawn` 不是重生宿主，玩家与怪物复活规则分散在各自状态机里

源码证据：

- `Assets/uMMORPG/Scripts/_UI/UIRespawn.cs`
- `Assets/uMMORPG/Scripts/Player.cs:291`
- `Assets/uMMORPG/Scripts/Player.cs:UpdateServer_DEAD()`
- `Assets/uMMORPG/Scripts/Monster.cs:57-61`
- `Assets/uMMORPG/Scripts/Monster.cs:454-472`

可确认的事实：

- `UIRespawn.cs` 只负责“玩家死亡时显示按钮，并在点击后发 `CmdRespawn()`”。
- 玩家真正的复活逻辑在 `Player.UpdateServer_DEAD()`：
  - 调 `NetworkManagerMMO.GetNearestStartPosition(transform.position)`
  - 再 `movement.Warp(start.position)`
  - 再 `Revive(0.5f)`
- 怪物没有单独 `Respawn` 宿主；它把 `respawn / respawnTime / startPosition / respawnTimeEnd` 都留在 `Monster` 自己的状态机里，自行回到起始位置复活。

结论：

- `uMMORPG` 当前没有“统一重生宿主”可供当前项目直接搬运。
- 它提供的是两类局部证据：
  1. 玩家复活可以回到最近正式出生点；
  2. 怪物自复活可以是“实体自持 startPosition + respawnTime”的局部行为。
- 这两类规则都没有形成当前项目要的“单机/本地出生点分流宿主”或“单机/本地场景实例宿主”。

裁决：

- 只登记，不实施。
- 当前项目继续维持“出生点分流宿主仍缺参考”的结论，不因为 `UIRespawn` 或 `Monster` 自复活就误判为这条缺口已关闭。

## 2026-06-14 本轮结论

- 本轮重新按源码复核后，没有发现新的“可直接搬进当前 GameCore 且不引入 Mirror/3D NavMesh/MMORPG 业务”的场景组织代码。
- 因此本轮不改运行时代码，只补强证据留档：
  - `Database.cs` 继续只支撑“失效保存位置回退到正式出生点”；
  - `Instance.cs + PortalToInstance.cs + InstanceSpawnPoint.cs + NetworkStartPositionForClass.cs` 继续只作为“实例宿主至少要显式承载入口/归属/边界/实例内出生点/清理策略”的参考证据；
  - `NetworkManagerMMO.GetStartPositionFor(...) + NetworkStartPositionForClass.cs` 继续只作为“出生点分流本身也应有正式宿主”的参考证据；
  - 当前待补的是新的参考，不是新的兼容层。
