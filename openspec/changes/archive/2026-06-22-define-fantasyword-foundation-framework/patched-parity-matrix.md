# Patched Parity Matrix

> 记录当前 `GameCore` 相对 `2DRPGEngine` 参考仍保留的运行时代码补丁。
> 目标不是长期接受这些偏离，而是把它们分成“必须暂留”“可直接拷回参考”“待继续取证”三类，避免重复迁移。

## 当前基线

- 本文件按时间顺序记录历史补丁与删除补登记；上面的“当前基线”永远以最新脚本结果为准，下面的数值递减条目只表示当时那一轮的历史状态。
- 最近一次 `scripts/Test-FoundationReferenceParity.ps1`
  - `Runtime missing: 0`
  - `Runtime unexpected mismatch: 0`
  - `Runtime unexpected extra: 0`
  - `Editor unexpected mismatch: 0`
  - `Editor unexpected extra: 0`
- `Runtime allowed patched: 185`
- `Runtime allowed extra: 86`
  - `Editor allowed patched: 15`
  - `Editor allowed extra: 8`

## 2026-06-18 GAS 与持续效果恢复补登记

`scripts/Test-FoundationReferenceParity.ps1 -AsJson` 最新回包已经重新回到 `unexpected = 0`，并把当前允许偏离更新为 `runtimeAllowedPatchedCount = 185`、`runtimeAllowedExtraCount = 86`。这轮不是新增第二套框架，而是把前面已经落地、但台账没追平的 3 个正式偏离补进白名单：

- `Combat/Effects/Temporal/ITemporalEffect.cs` 现已正式承接 `RestoreRuntimeState(...)` 读档恢复合同，因此从“意外 mismatch”补登记为 `runtime allowed patched`。
- `Combat/FormalGameplayAttributeSet.cs` 是实体级 GAS 第一刀的正式 AttributeSet 形状，因此补登记为 `runtime allowed extra`。
- `Entities/Characters/CharacterBase.GASRuntime.cs` 是角色实体级 ASC 正式挂点与属性镜像同步闭包，因此补登记为 `runtime allowed extra`。

## 2026-06-17 最新补登记

`scripts/Test-FoundationReferenceParity.ps1 -AsJson` 最新回包已把 `runtimeAllowedExtraCount` 收到 `84`。这对应 `CharacterAbilityTriggerRuntime` 与 `CharacterAbilityLifecycleRuntime` 两个单拥有者 helper 的最后撤回；更早的 `102 / 97 / 92 / 88 / 86` 只保留为历史递减记录，不再代表当前现态。

## 2026-06-17 MapTraversalRuntime 与 PersistenceLifecycleRuntime 删除补登记

本轮继续对单拥有者 helper 做 deletion test，又确认 `MapTraversalRuntime` 与 `PersistenceLifecycleRuntime` 都不拥有独立真相，只是把 `MapSystem` / `PersistenceSystem` 的正式生命周期语义拆成门面，因此直接把实现收回正式宿主。

当前影响：

- 过场、传送、重生和读档后的出生点修复编排重新回到 `MapSystem` 这一处正式宿主。
- 数据块装配、地图加载恢复、销毁后回写和存档前快照重新回到 `PersistenceSystem` 这一处正式宿主。
- `Runtime allowed extra` 因此从 `104` 再收缩到 `102`。

## 2026-06-17 JournalQuestRuntime 与 JournalQueryRuntime 删除补登记

本轮继续对单拥有者 helper 做 deletion test，又确认 `JournalQuestRuntime` 与 `JournalQueryRuntime` 都不拥有独立真相，只是把 `JournalSystem` 的正式任务语义拆成两个门面，因此直接把实现收回 `JournalSystem`。

当前影响：

- 任务可接取刷新、任务实例创建/恢复、完成流转、序列化装配、NPC/任务查询和前置等级判定重新回到 `JournalSystem` 这一处正式宿主。
- `OnSaveFileLoaded()` 触发的任务可用性刷新继续保留在 `JournalSystem`，任务等级判断仍绑定长期玩家 `Hero`，没有分裂到第二套任务或玩家真相。
- `Runtime allowed extra` 因此从 `106` 再收缩到 `104`。

## 2026-06-17 CharacterRegistrySystem 删除补登记

本轮在 `SaveWorldStateRuntime` 之后继续做 deletion test，又确认 `CharacterRegistrySystem` 只是没有真实调用者的预留系统，因此直接从正式闭包删除，而不是把它继续登记成长期允许 extra。

当前影响：

- `CharacterBase` 不再承担 live runtime 角色注册/反注册接线。
- `CharacterBaseSignalRuntime` 已在 `2026-06-17` 的 deletion test 中撤回，`provoked / levelUp` 两组对外信号重新直接回到 `CharacterBase.StateApi.cs`。
- `SampleScene` 与 `ClickMoveTest` 都不再摆 `Character Registry System` 场景对象。
- `Runtime allowed extra` 因此从 `110` 再收缩到 `109`。

## 2026-06-17 InventoryStorageRuntime 删除补登记

本轮继续对单拥有者 helper 做 deletion test，又确认 `InventoryStorageRuntime` 实际握着钱、物品、序列化和事件派发这组背包正式真相，而 `InventorySystem` 反而退化成转发层，因此直接把实现收回 `InventorySystem`。

当前影响：

- 钱、物品、序列化和事件派发重新回到 `InventorySystem` 这一处正式宿主。
- “装备目标跟随当前受控 Hero”的裁决继续保留在 `InventorySystem`，没有分裂到第二套背包拥有者。
- `Runtime allowed extra` 因此从 `109` 再收缩到 `108`。

## 2026-06-17 PlayerControlTargetRuntime 与 MapStateRuntime 删除补登记

本轮继续对单拥有者 helper 做 deletion test，又确认 `PlayerControlTargetRuntime` 与 `MapStateRuntime` 都实际握着各自系统的正式状态，而宿主系统外面主要在做转发，因此直接把实现分别收回 `PlayerSystem` 与 `MapSystem`。

当前影响：

- 当前输入落点、当前控制角色、监听派发和销毁后回退重新回到 `PlayerSystem` 这一处正式宿主。
- 当前地图名、检查点栈、有序检查点状态、活动 `MapInfo` 缓存和 `MapDataBlock` 序列化装配重新回到 `MapSystem` 这一处正式宿主。
- `Runtime allowed extra` 因此从 `108` 再收缩到 `106`。

## 2026-06-16 CharacterBase partial 补登记

本轮把已经进入正式 `CharacterBase` 闭包、但先前还没进 parity 台账的 5 个并列 partial 也正式补进来。它们只是同一个角色闭包的内部实现分拆，不是第二套角色系统、属性系统或能力入口。

新增或补登记为 `runtime allowed extra`：

- `Entities/Characters/CharacterBase.Abilities.cs`
- `Entities/Characters/CharacterBase.Contracts.cs`
- `Entities/Characters/CharacterBase.Persistence.cs`
- `Entities/Characters/CharacterBase.Resources.cs`
- `Entities/Characters/CharacterBase.StateApi.cs`

当前判断：

- `CharacterBase.cs` 主文件继续只保留角色生命周期和规则拥有权。
- 这 5 个文件分别承接能力、合同、持久化、资源和状态 API 的实现拆分，不引入第二套真相。

## 2026-06-16 UIKit 菜单 seam 与属性 seam 登记补齐

本轮不是为了“把数字清零”强行回退正式实现，而是把已经成为当前框架真相的新增闭包正式写进 parity 台账。共同原因有两类：

- `UIKit` 菜单 seam 已经并回 `UIManager`，因此 `UI/MenuPanels/*`、`UI/UIManager.Menu*.cs`、`UI/UIKitSmoke/*` 与对应 editor 侧 `UIKitSmokeValidator`、`UIKitMenuPanelTypeReferencePropertyDrawer` 不再是未登记试验物，而是正式 UI 基础设施。
- 属性/GAS seam 已经从“禁止整份 Stats 外借”继续推进到“正式属性目录 + 属性运行时 + 最小战斗快照 + 资源语义入口”，因此 `CombatStatSnapshot.cs`、`FormalAttributeCatalog.cs`、`CharacterBase.AttributeBootstrapBuffer.cs`、`StatsPropertyDrawer.cs`，以及直接消费这些新入口的 `CombatSolver.cs`、`ItemHealEffect.cs`、`ItemRestoreManaEffect.cs` 都属于当前正式偏离。

新增或补登记为 `runtime allowed patched`：

- `Combat/CombatSolver.cs`
- `Database/Items/ItemEffects/ItemHealEffect.cs`
- `Database/Items/ItemEffects/ItemRestoreManaEffect.cs`
- `UI/Menus/Settings/UISettings.cs`

新增或补登记为 `runtime allowed extra`：

- `Combat/CombatStatSnapshot.cs`
- `Combat/FormalAttributeCatalog.cs`
- `Entities/Characters/CharacterBase.AttributeBootstrapBuffer.cs`
- `UI/MenuPanels/UIKitDeathPanel.cs`
- `UI/MenuPanels/UIKitMenuOpenData.cs`
- `UI/MenuPanels/UIKitMenuPanelBase.cs`
- `UI/MenuPanels/UIKitMenuPanelTypeReference.cs`
- `UI/UIKitSmoke/UIKitSmokePanelBase.cs`
- `UI/UIKitSmoke/UIKitSmokePrimaryPanel.cs`
- `UI/UIKitSmoke/UIKitSmokeSecondaryPanel.cs`

新增或补登记为 `editor allowed patched/extra`：

- `PropertyDrawers/StatsPropertyDrawer.cs`
- `Bridge/UIKitSmoke/UIKitSmokeValidator.cs`
- `PropertyDrawers/UIKitMenuPanelTypeReferencePropertyDrawer.cs`

当前结论：

- parity 再次回到 `unexpected = 0`，证明当前新增框架闭包已经和 change 台账对齐。
- 这不代表 `UIKit`、属性/GAS 或四层所有权已经做完，只代表这些重构成果已经从“未登记异常”升级成“正式承认的当前偏离”。

## 2026-06-16 正式镜头入口偏离补登记

本轮没有新改 [MoveCamera.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Commands/MoveCamera.cs) 的业务语义，但 parity 复核把它重新点亮成未登记 mismatch。当前正式偏离是：镜头移动命令不再依赖参考里的 `Camera.main`，而是统一走 `GameManager.MainCamera` 这条项目级正式玩法相机入口；同时在相机缺失时给出显式错误，而不是继续静默假设场景里一定存在可用主相机。

新增或补登记为 `runtime allowed patched`：

- `Commands/MoveCamera.cs`

当前判断：

- 这不是新的相机系统，也不是第二套镜头真相；它只是把镜头命令从 Unity 全局查找收回项目级正式入口。
- 这条偏离与当前 `GameManager.MainCamera` 单一入口口径一致，应当保留为正式登记项，而不是继续作为 parity 异常漂着。

## 2026-06-16 音频、控制器 helper 与 CharacterBase/Input bridge 补登记

本轮一方面把已经进入正式运行时闭包的 `AudioChannel` 内部 helper 正式补回 parity 台账，另一方面继续把 `CharacterBase` 的对外信号与角色注册桥接从主类正文里收走。它们共同点是：都属于“同一正式闭包的内部实现收口”，不是新增第二套系统。

新增或补登记为 `runtime allowed extra`：

- `Audio/AudioChannel.FallbackPoolRuntime.cs`
- `Audio/AudioChannel.PlaybackRuntime.cs`
- `Controllers/AIController.BehaviourRuntime.cs`
- `Controllers/PlayerController.InteractionRuntime.cs`
- `Controllers/PlayerController.NavigationRuntime.cs`
- `Game/Systems/InputActionCatalogRuntime.cs`
- `Game/Systems/InputLifecycleRuntime.cs`

补充现态：

- 上面这组 `InputActionCatalogRuntime / InputLifecycleRuntime` 只代表 `2026-06-16` 当轮曾进入 `runtime allowed extra`。
- `2026-06-17` 再做 deletion test 后，它们都已经撤回并删除；当前正式输入边界同样以 `InputSystem.cs + InputSystem.Contracts.cs` 为准，不再保留这些中间 helper。

当前判断：

- `AudioChannel.FallbackPoolRuntime.cs` 与 `AudioChannel.PlaybackRuntime.cs` 只是把 `AudioChannel` 的 fallback 池和播放编排实现从顶层入口里压回 helper，不改变 `AudioSystem -> AudioChannel` 的正式音频链。
- `AIController.BehaviourRuntime.cs` 只是把正式 `AIController` 的视野检测、追敌裁决、转向数组和避障执行拆进 partial helper，不改变 `AIController` 作为唯一正式 AI 控制器闭包的地位。
- `PlayerController.InteractionRuntime.cs` 与 `PlayerController.NavigationRuntime.cs` 只是把正式 `PlayerController` 的交互与导航实现拆进 partial helper，不改变 `PlayerController` 作为唯一玩家控制器闭包的地位。
- `InputActionCatalogRuntime.cs` 与 `InputLifecycleRuntime.cs` 这条历史态说明，只用于记录它们当时为什么能进入 parity 台账；当前现态仍以“它们已撤回并删除”为准，不改变 `InputSystem` 作为唯一输入根和正式输入边界的地位。

## 2026-06-16 GameRuntimeEvents partial 拆分补登记

本轮 `GameRuntimeEvents` 不再把全部事件类型和全部领域入口堆在一个大文件里，而是按生命周期、表现、成长/背包/任务、UI 请求四个域拆成并列 partial 文件。这里补登记的是文件级实现拆分，不是事件边界回退。

新增或补登记为 `runtime allowed extra`：

- `Events/GameRuntimeEvents.Lifecycle.cs`
- `Events/GameRuntimeEvents.Presentation.cs`
- `Events/GameRuntimeEvents.Progression.cs`
- `Events/GameRuntimeEvents.Ui.cs`

当前判断：

- 这 4 个文件继续复用 `GameRuntimeEvents.cs` 作为唯一正式发布入口，`EventKit.Type.Send(...)` 也仍只允许留在入口文件，不会散到玩法调用点。
- `Lifecycle` 只承接地图加载/卸载与存档载入等框架生命周期事件；`Presentation` 只承接受击、恢复、掉落、交互等表现广播；`Progression` 只承接成长、背包、能力和任务相关事件；`Ui` 只承接菜单、商店、制作和详情请求。
- 因此它们是“同一正式事件系统的分域实现文件”，不是新的通知中心、第二套 UI 运行时或第二套生命周期系统。

## 2026-06-16 GameConfig partial 拆分补登记

本轮 `GameConfig` 也不再把配置类型声明、术语查询、Playtest 快照和持久化标识映射继续堆在主文件里，而是拆成并列 partial 文件。这里补登记的是同一正式配置入口的实现收口，不是新增配置真相。

新增或补登记为 `runtime allowed extra`：

- `Game/GameConfig.Contracts.cs`
- `Game/GameConfig.Persistence.cs`
- `Game/GameConfig.Terms.cs`

当前判断：

- `GameConfig.Contracts.cs` 只承接配置相关 enum / struct 类型声明，继续复用 `GameConfig.cs` 作为唯一正式配置入口。
- `GameConfig.Terms.cs` 只承接术语字典、默认术语和 `GetTermDefinition(...)` 查询，不引入第二套术语系统。
- `GameConfig.Persistence.cs` 只承接 Playtest 快照、玩家死亡动作和持久化标识映射的实现，不引入第二套存档或配置入口。

## 2026-06-16 UIManager 菜单 partial 拆分补登记

本轮继续沿“正式拥有者不再混装多段实现”推进，但没有改菜单请求语义：菜单 seam 已经并回 `UIManager`，只是把生命周期、注册、请求路由和运行时栈会话从主文件继续拆开。

新增或补登记为 `runtime allowed extra`：

- `UI/UIManager.MenuRuntime.cs`
- `UI/UIManager.MenuRegistrationRuntime.cs`
- `UI/UIManager.MenuRequestRoutingRuntime.cs`
- `UI/UIManager.MenuStackRuntime.cs`

当前判断：

- `UIManager.MenuRuntime.cs` 只负责菜单 seam 生命周期，继续复用 `UIManager` 作为唯一正式菜单语义入口。
- `UIManager.MenuRegistrationRuntime.cs` 只负责菜单绑定、类型校验和正式注册重建，不承担请求路由或面板栈编排。
- `UIManager.MenuRequestRoutingRuntime.cs` 只负责正式输入和正式事件到菜单 seam 的请求路由，不承担菜单声明或面板栈编排。
- `UIManager.MenuStackRuntime.cs` 只负责打开/关闭会话、close task、栈深和 `GameState.Menu` 生命周期编排，不引入第二套 UI 运行时或第二套路由。

## 2026-06-16 GameRuntimeEvents.Progression 再拆分补登记

本轮继续沿“正式事件 partial 不再继续混装多个子域”推进，但没有改事件语义：`GameRuntimeEvents` 仍是唯一正式事件入口，只是把 `Progression` 域里的背包/能力和任务事件再拆开。

新增或补登记为 `runtime allowed extra`：

- `Events/GameRuntimeEvents.Progression.Inventory.cs`
- `Events/GameRuntimeEvents.Progression.Quests.cs`

当前判断：

- `GameRuntimeEvents.Progression.cs` 现在只负责怪物击杀、经验和升级这组成长事件。
- `GameRuntimeEvents.Progression.Inventory.cs` 只负责金钱、物品和能力变化事件，不引入第二套背包或能力通知系统。
- `GameRuntimeEvents.Progression.Quests.cs` 只负责任务日志、可用性和完成事件，不引入第二套任务通知入口。
- 这 3 个文件继续复用 `GameRuntimeEvents.cs` 作为唯一正式发布入口，`EventKit.Type.Send(...)` 也仍只允许留在入口文件。

## 2026-06-16 MapSystem 状态容器补登记

本轮继续沿“外提实现编排，不转移正式真相拥有权”的方向推进，但目标换成了 `MapSystem`。当前地图名、检查点栈、有序检查点状态、`MapInfo` 注册缓存和 `MapDataBlock` 序列化装配，已经明确属于地图系统自己的状态容器实现，而不是应该继续堆在主类正文里的规则入口。

新增或补登记为 `runtime allowed extra`：

- `Game/Systems/MapSystem.Contracts.cs`

当前判断：

- `MapSystem.Contracts.cs` 只承接地图过场委托参数和 `MapDataBlock` 数据块定义，不引入第二套地图系统、存档系统或过场宿主。
- `2026-06-17` 已通过 deletion test 撤回 `MapStateRuntime`。当前地图名、检查点栈、有序检查点状态、`MapInfo` 注册缓存和 `MapDataBlock` 序列化装配现在都直接回到 `MapSystem`。
- `MapSystem` 仍然持有地图、检查点、传送、重生和当前 tracked scene 选择的正式入口；外提的是“状态怎么存、怎么装、怎么恢复”，不是新的地图系统。

## 2026-06-16 SaveSystem 世界装配补登记

本轮继续沿“外提实现编排，不转移正式真相拥有权”的方向推进，目标换成了 `SaveSystem`。存档标题生成、世界数据块组装和恢复顺序已经明确属于世界存档装配实现，不应该继续和文件入口、SaveKit 桥接一起堆在主类正文里。

新增或补登记为 `runtime allowed extra`：

- `Game/Systems/SaveSystem.Contracts.cs`
- `Persistence/Persistable.Contracts.cs`
- `Persistence/Persistable.DataBlocks.cs`

当前判断：

- `SaveSystem.Contracts.cs` 只承接 `SaveDataBlock` 世界聚合形状，不引入第二套世界存档模型或文件层入口。
- `Persistable.Contracts.cs` 与 `Persistable.DataBlocks.cs` 只是把 `Persistable` 的持久化 handler/ownership 合同、数据块类型和销毁快照拆回同闭包并列文件，不改变 `Persistable -> PersistenceSystem` 作为唯一正式持久化链的地位。
- `SaveSystem` 仍然持有文件加载/写入入口与 `SaveKit` 文件层桥接；`2026-06-17` 已把 deletion test 不通过的 `SaveWorldStateRuntime` 删除并收回 `SaveSystem`，不再额外保留世界状态组装 helper。

## 2026-06-16 Projectile 同闭包拆分补登记

本轮继续沿“正式宿主只保留规则入口，碰撞/爆炸/持久化实现外提”的方向推进，目标换成了 `Projectile`。这 3 个文件都属于同一个投射物正式闭包的内部拆分，不是新的战斗系统、AoE 系统或存档真相。

新增或补登记为 `runtime allowed extra`：

- `Entities/Projectile.CollisionRuntime.cs`
- `Entities/Projectile.ExplosionRuntime.cs`
- `Entities/Projectile.Persistence.cs`

当前判断：

- `Projectile.CollisionRuntime.cs` 只负责命中判定、碰撞入口和终止时机，不引入第二套命中窗口或伤害派发入口。
- `Projectile.ExplosionRuntime.cs` 只负责爆炸半径内目标收集与附加效果结算，继续复用 `Projectile` 当前正式配置，不引入第二套 AoE 真相。
- `Projectile.Persistence.cs` 只负责 `ProjectileDataBlock` 与保存/恢复编排，继续复用 `Persistable -> PersistenceSystem` 正式持久化链，不引入第二套投射物存档系统。
- `Projectile.cs` 主文件继续只保留运行时生命周期、正式配置字段、投射启动和销毁入口。

## 2026-06-16 InputSystem 合同外提补登记

本轮继续沿“正式输入根只保留宿主、生命周期和对外 API”的方向推进，目标换成了 `InputSystem`。当前 `Gameplay/UI` 动作引用和输入枚举这组公开合同，已经明确属于输入根的对外形状，不应该继续混在主文件顶部。

新增或补登记为 `runtime allowed extra`：

- `Game/Systems/InputSystem.Contracts.cs`

当前判断：

- `InputSystem.Contracts.cs` 只承接 `GameplayActions`、`UIActions`、`EActionMap`、`EGameplayInputAction`、`EUIInputAction` 与 `EInputActionPhase` 这组正式输入合同，不引入第二套输入根、模式输入系统或绑定工具层。
- `InputSystem.cs` 主文件继续只保留正式输入根、生命周期桥接和对外 API；输入合同定义外提后，主文件更聚焦，但行为语义不变。

## 2026-06-16 GameManager 宿主拆分补登记

本轮继续沿“正式宿主主文件只保留入口与拥有权，注册和生命周期分发实现外提”的方向推进，目标换成了 `GameManager`。这 2 个文件都属于同一个项目级正式宿主的内部拆分，不是第二套生命周期系统或新的服务定位器。

新增或补登记为 `runtime allowed extra`：

- `Game/GameManager.LifecycleRuntime.cs`
- `Game/GameManager.SystemRegistryRuntime.cs`

当前判断：

- `GameManager.SystemRegistryRuntime.cs` 只负责 `FindSystems()`、`InitializeSystems()`、`StartSystems()`、`StopSystems()` 和 `HasSystem/TryGetSystem/GetSystem` 这组系统注册与查找实现，不新增第二套系统容器。
- `GameManager.LifecycleRuntime.cs` 只负责地图/存档生命周期回调和 `Dispatch*Lifecycle()` 分发口，继续复用 `GameRuntimeEvents` 作为正式事件发布入口，不回归旧通知中心。
- `GameManager.cs` 主文件继续只保留静态快捷入口、`GameConfig` 宿主字段和 Unity 根节点启停，不改变现有 13 个正式系统快捷入口边界。

## 2026-06-16 Hero 内部职责拆分补齐

本轮继续往“单一职责优先、代码可读性优先”的方向推进，但没有改业务语义：一方面把 [Hero.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/Hero.cs) 内部已经明确属于“装配/槽位实现细节”的三块 helper 抽成独立运行时文件；另一方面把 [CharacterBase.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.cs) 里的“能力集合容器细节”“动作锁/速度修饰容器细节”和“持续效果容器细节”分别收进 `CharacterAbilitySetRuntime`、`CharacterActionStateRuntime` 与 `CharacterTemporalEffectRuntime`，能力 prefab 的根节点选择、默认启停和实例创建/销毁这组实现当前已经直接并回 [CharacterBase.Abilities.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Abilities.cs)，不再额外保留 `CharacterAbilityInstanceHost` 壳层；`2026-06-18` 又继续把这三块真容器的文件级所有权收成 [CharacterBase.AbilitySetRuntime.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.AbilitySetRuntime.cs)、[CharacterBase.ActionStateRuntime.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.ActionStateRuntime.cs) 与 [CharacterBase.TemporalEffectRuntime.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.TemporalEffectRuntime.cs) 这组 `CharacterBase` 内部 helper；再把 [UISystem.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Game/Systems/UISystem.cs) 的正式场景唯一节点冲突取证入口和 [FormalSceneSingletonConflictDiagnostics.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Diagnostics/FormalSceneSingletonConflictDiagnostics.cs) 一起纳入当前正式闭包，让 `CharacterBase` 和 `UISystem` 都更聚焦规则与宿主，而不是把诊断和容器细节继续堆在主类里。

新增 `runtime allowed extra`：

- `Entities/Characters/CharacterBase.ActionStateRuntime.cs`
- `Entities/Characters/CharacterBase.AbilitySetRuntime.cs`
- `Entities/Characters/CharacterBase.TemporalEffectRuntime.cs`
- `Entities/Characters/HeroEquippedAbilityLoadout.cs`
- `Entities/Characters/HeroEquippedItemLoadout.cs`
- `Entities/Characters/HeroEquipmentSlotChange.cs`
- `Entities/Movable.MotionRuntime.cs`
- `Diagnostics/FormalSceneSingletonConflictDiagnostics.cs`
- `Game/Systems/InputBindingRuntime.cs`
- `Game/Systems/InputGameplayRoutingRuntime.cs`
- `Game/Systems/InputUiRuntime.cs`
- `Game/Systems/PersistenceSystem.Contracts.cs`
- `Game/Systems/PersistenceSystem.InstantiationRuntime.cs`
- `Game/Systems/SaveFileStorageRuntime.cs`

补充现态：

- 上面这组 `InputBindingRuntime / InputGameplayRoutingRuntime / InputUiRuntime` 只代表 `2026-06-16` 当轮曾进入 `runtime allowed extra`。
- `2026-06-17` 再做 deletion test 后，它们都已经撤回并删除；当前正式输入边界以 `InputSystem.cs + InputSystem.Contracts.cs` 为准，不再保留这些中间 helper。

新增或补登记为 `runtime allowed patched`：

- `Game/Systems/UISystem.cs`

当前判断：

- 这组文件不是新的业务系统，也不是第二套真相；它们只是把原来藏在 `Hero`、`CharacterBase` 和 `UISystem` 内部的容器、诊断或宿主细节显式化。
- `Hero` 仍然是装备槽和能力槽规则的正式拥有者；`CharacterBase` 仍然是角色能力生命周期和动作编排的正式拥有者；`UISystem` 仍然是正式 UI 场景宿主。外提的是容器或诊断实现，不是领域真相。
- 同轮又继续把能力实例的更新、重置、中断、显式动作中断通知和能力存档遍历，从 `CharacterBase` 收回现有 `CharacterAbilitySetRuntime`；能力根节点选择、默认启停和实例创建/销毁这组实现当前已经直接并回 `CharacterBase.Abilities.cs`。这一步没有改业务真相，只是把实现细节继续从角色主类剥离出去，同时删掉了只服务单点调用的 `CharacterAbilityInstanceHost` 壳层；`2026-06-18` 又继续把对应文件归属收成 `CharacterBase.AbilitySetRuntime.cs` 的内部 helper 形态，不再保留“看起来像独立角色 runtime”的文件语义。
- 同轮曾新增 `CharacterAbilityTriggerRuntime`，把主动能力的解析、开火/停火/换弹执行、自动启停、开火转向与动作中断通知从 `CharacterBase` 主类收进实现 helper；但 `2026-06-17` 再做 deletion test 后已撤回，当前这组触发执行编排直接回到 `CharacterBase.Abilities.cs`。
- 同轮曾新增 `CharacterAbilityLifecycleRuntime`，把能力实例创建/销毁、初始解锁、加成能力注册和升级解锁编排从 `CharacterBase` 主类收进实现 helper；但 `2026-06-17` 再做 deletion test 后已撤回，当前这组生命周期编排直接回到 `CharacterBase.Abilities.cs`。
- 同轮曾新增 `CharacterResourceFlowRuntime`，把伤害、治疗、法力恢复与法力消耗这组资源流转和表现派发，从 `CharacterBase` 主类收进实现 helper；但 `2026-06-17` 再做 deletion test 后已撤回，当前这组资源流转直接回到 `CharacterBase.Resources.cs`。
- 同轮曾新增 `CharacterLevelRuntime`，把升级后的资源恢复、能力解锁和等级事件派发，从 `CharacterBase` 主类收进实现 helper；但 `2026-06-17` 再做 deletion test 后已撤回，当前这组升级编排直接回到 `CharacterBase.Resources.cs`。
- 同轮曾新增 `CharacterSurvivabilityRuntime`，把死亡动画结束门闩、复活后状态复位和临时无敌计时，从 `CharacterBase` 主类收进实现 helper；但 `2026-06-17` 再做 deletion test 后已撤回，当前这组生存状态实现直接回到 `CharacterBase` 本体。
- 同轮曾新增 `CharacterBaseSignalRuntime`，把 `provoked / levelUp` 两组对外信号，从 `CharacterBase` 主类收进实现 helper；但 `2026-06-17` 再做 deletion test 后已撤回，当前事件对象与监听 API 直接回到 `CharacterBase.StateApi.cs`。
- 同轮曾新增 `MonsterRewardRuntime`，把怪物死亡后的掉落判定、经验/金钱发放和奖励表现派发，从 `Monster` 主类收进实现 helper；但 `2026-06-17` 再做 deletion test 后已撤回，当前奖励编排直接回到 `Monster` 本体。
- 同轮又新增 `Movable.MotionRuntime`，把碰撞探测、MoveOrder、输入平滑、推力执行和上下文速度倍率栈，从 `Movable` 主类收进内部 partial helper。当前 `Movable` 仍保留生命周期、移动语义、朝向规则和正式公开入口；外提的是纯动作执行实现，不是第二套移动器。
- `2026-06-17` 再做 deletion test 后，已撤回 `PlayerControlTargetRuntime`。当前输入落点、当前控制角色、监听派发和销毁后回退直接回到 `PlayerSystem`，避免继续保留一个只有单拥有者却实际握着当前控制真相的浅 seam。
- 同轮又新增 `InputBindingRuntime`，把 InputKit 绑定导出/导入、保存/加载、重置、显示名和冲突查询，从 `InputSystem` 主类收进新的实现 helper。当前 `InputSystem` 仍保留 Gameplay/UI 输入语义、ActionMap 生命周期和玩家输入路由真相；外提的是工具层编排，不是新的输入根。
- 同轮又把既有 `InputUiRuntime` 与 `InputGameplayRoutingRuntime` 正式接回 `InputSystem`。`InputUiRuntime` 只负责 action map 切换、共享输入释放门禁、UI 模块启停和指针焦点同步；`InputGameplayRoutingRuntime` 只负责 Gameplay 输入回调绑定和当前正式输入目标转发。当前 `InputSystem` 仍保留 `PlayerInput` 正式入口、地图切换锁输入和对外 API；外提的是输入编排实现，不是新的输入根、UI 宿主或控制器生命周期。
- `2026-06-17` 再做 deletion test 后，已撤回 `InventoryStorageRuntime`。钱、物品、序列化和事件派发直接回到 `InventorySystem`，避免继续保留一个只有单拥有者却实际握着背包真相的浅 seam。
- `2026-06-17` 再做 deletion test 后，已撤回 `JournalQuestRuntime` 与 `JournalQueryRuntime`。任务可接取刷新、任务实例创建/恢复、完成流转、序列化装配、NPC/任务查询和前置等级判定直接回到 `JournalSystem`，避免继续保留两个只有单拥有者却把正式任务语义拆成门面的浅 seam。
- `2026-06-17` 再做 deletion test 后，已撤回 `MapStateRuntime`。当前地图名、检查点栈、有序检查点状态、`MapInfo` 注册缓存和 `MapDataBlock` 序列化装配直接回到 `MapSystem`，避免继续保留一个只有单拥有者却实际握着地图状态真相的浅 seam。
- `2026-06-17` 再做 deletion test 后，已撤回 `MapTraversalRuntime`。过场、传送、重生和读档后的出生点修复编排直接回到 `MapSystem`，避免继续保留一个只有单拥有者却把正式地图 traversal 语义拆成门面的浅 seam。
- 同轮又新增 `PersistenceSystem.Contracts.cs`，把 `PersistenceDataBlock` 从 `PersistenceSystem` 主类收回同闭包合同文件。当前 `PersistenceSystem` 仍保留正式持久化入口、对象解析和稳定标识映射；外提的是数据块形状，不是新的持久化入口。
- 同轮又新增 `PersistenceSystem.InstantiationRuntime.cs`，把 prefab 实例化、运行时实例登记和自定义实例登记，从 `PersistenceSystem` 主类收进并列 partial。当前 `PersistenceSystem` 仍保留持久化字典真相和正式 API；外提的是实例化实现，不是第二套持久化或生成系统。
- `2026-06-17` 再做 deletion test 后，已撤回 `PersistenceLifecycleRuntime`。数据块装配、地图加载恢复、销毁后回写和存档前快照直接回到 `PersistenceSystem`，避免继续保留一个只有单拥有者却把正式持久化生命周期拆成门面的浅 seam。
- 同轮又新增 `SaveFileStorageRuntime`，把 SaveKit 的槽位、路径、版本、文件格式和稳定槽位映射，从 `SaveSystem` 主类收进新的实现 helper。当前 `SaveSystem` 仍保留 `SaveDataBlock` 世界状态聚合与恢复真相；外提的是文件层实现，不是新的世界存档真相。
- `2026-06-17` 再次对存档模块做 deletion test 后，已删掉 `SaveWorldStateRuntime`：这层只有单拥有者 `SaveSystem`，却需要 14 个委托把世界装配事实重新暴露出去，属于浅模块。当前改为由 `SaveSystem` 直接承接存档标题生成、`SaveDataBlock` 世界组装和恢复顺序；正式文件层仍只由 `SaveFileStorageRuntime` 承接，不引入第二套世界状态模型。
- 同轮曾把 `CharacterBase.OnSave/OnLoad` 里的持久化编排收进 `CharacterBasePersistenceRuntime`；但 `2026-06-17` 再做 deletion test 后已撤回，当前属性、加成能力、动作锁、速度修饰、持续效果和能力数据块的保存/恢复编排直接回到 `CharacterBase.Persistence.cs`。
- 本轮曾把 `Hero` 的经验、已用点数、自定义属性以及 Hero 自己的数据块写回，从主类收进 `HeroProgressionRuntime`；但 `2026-06-17` 再做 deletion test 后已撤回，当前这组成长状态存储与 Hero 自己的数据块编排直接回到 `Hero` 本体。
- 同轮曾新增 `HeroResolvedStatsRuntime`，把 `Hero` 的“基础属性 + 自定义属性 + 装备加成”重算编排，从主类收进实现 helper；但 `2026-06-17` 再做 deletion test 后已撤回，当前重算编排直接回到 `Hero` 本体。
- 同轮曾新增 `HeroPersistenceRuntime`，把 `Hero` 自己的成长、装备和技能槽在 `OnSave/OnLoad` 前后的恢复时序，从主类收进实现 helper；但 `2026-06-17` 再做 deletion test 后已撤回，当前恢复时序直接回到 `Hero` 本体。
- 同轮又继续把 `Hero.OnSave/OnLoad` 里的装备槽/技能槽 reference snapshot 与 restore 编排，从主类收进既有 `HeroEquippedItemLoadout` 与 `HeroEquippedAbilityLoadout`。当前 `Hero` 仍保留槽位规则、资源校验、重算与通知真相；外提的是“如何创建 `DatabaseEntryReference` 快照、如何按槽位恢复”的存档实现细节，因此不增加新的 extra 文件，只是补充这两个既有 helper 的正式职责边界。
- 同轮曾新增 `HeroEquipmentRuntime`，把装备槽位变化预演、资源合法性映射、正式应用和已装备物品快照从 `Hero` 主类收进实现 helper；但 `2026-06-17` 再做 deletion test 后已撤回，当前这组槽位编排直接回到 `Hero` 本体，正式边界保留 `Hero + HeroEquippedItemLoadout + HeroEquipmentSlotChange`。
- 同轮曾新增 `HeroEquippedAbilityRuntime`，把主动技能槽的校验、自动落槽、按槽位装卸和引用恢复从 `Hero` 主类收进实现 helper；但 `2026-06-17` 再做 deletion test 后已撤回，当前这组技能槽编排直接回到 `Hero` 本体，正式边界保留 `Hero + HeroEquippedAbilityLoadout`。

同轮补登记 editor 偏离：

- `EditorWindows/DatabaseWindow.cs`
- `Utils/FormalDataAssetCache.cs`

当前判断：

- `DatabaseWindow.cs` 当前不再直接全项目扫 ScriptableObject，而是切到 `FormalDataAssetCache` 这条正式数据缓存入口；这是编辑器正式数据浏览器的工程化偏离，不改变运行时数据库真相。
- `FormalDataAssetCache.cs` 只服务 `Assets/GameData` 正式目录下的编辑器数据缓存与脏标记回收，不参与运行时地基真相；它属于当前项目正式编辑器工具边界，因此应登记为 `editor allowed extra`。

## 2026-06-15 所有权与编辑器偏离登记补齐

本轮没有改运行时代码，只把已经由静态门禁和专项矩阵承认的偏离补进 `scripts/Test-FoundationReferenceParity.ps1`。补登记的共同原因不是“偏离参考就默认保留”，而是这些文件已经承担当前项目的正式边界：资产 API 收口、live 容器快照、对话通道封装、默认存档模板快照、持久化引用显式解析、表现事件强类型派发、UI 内部显式父级回调，以及编辑器无弹窗自动化流程。

新增或补登记为 `runtime allowed patched` 的主要分组：

- 资产与数据库 API 收口：`Database/DatabaseRegistry.cs`、`Database/Save/SaveFile.cs`、`Database/Save/PrefabReference.cs`、`Database/Abilities/*`、`Database/Characters/*`、`Database/Crafting/*`、`Database/Dialogues/DialogueSequence.cs`、`Database/Items/*`、`Database/Quest/*`、`Database/Shops/Shop.cs`、`Database/UI/NavigationCursorStyle.cs`、`Game/GameConfig.cs`。
- 属性、伤害和效果快照：`Combat/Stats.cs`、`Combat/ObservableStats.cs`、`Combat/DamageDescriptor.cs`、`Combat/DamageSolver.cs`、`Combat/Effects/Immediate/*`、`Combat/Effects/Temporal/*`。
- 对话、任务、持久化和命令所有权：`Game/Systems/DialogueSystem.cs`、`Dialogue/DialogueChannel.cs`、`Dialogue/DialogueNode.cs`、`Dialogue/DialogueTree.cs`、`Dialogue/DialogueUtils.cs`、`Commands/CompleteTask.cs`、`Commands/PlayDialogueLine.cs`、`Commands/PlayDialogueSequence.cs`、`Commands/ToggleController.cs`、`Persistence/PersistableReference.cs`、`Maps/PersistableCheckpoint.cs`。
- 表现与 UI 显式合同：`Animation/EquipmentSpriteLibraryUpdater.cs`、`Animation/FollowTargetDirection.cs`、`Loot/ChestLoot.cs`、`Spawners/AMonsterSpawner.cs`、`UI/UIControllerButton.cs`、`UI/UINavigationCursor.cs`、`UI/UINavigationCursorTarget.cs`、`UI/Menus/Journal/UIJournalQuestDescription.cs`。

新增 `runtime allowed extra`：

- `Database/DatabaseRegistry.Editor.cs`：把编辑器写入口从运行时主文件拆出，运行时 `DatabaseRegistry` 只暴露查询和 GUID 解析。

新增或补登记为 `editor allowed patched`：

- `Database/DatabaseEntryProcessor.cs`、`Database/DatabaseRegistryExtensions.cs`、`Editors/DatabaseEntryEditor.cs`、`Editors/DatabaseRegistryEditor.cs`、`Editors/HeroSheetEditor.cs`、`Editors/MonsterSheetEditor.cs`、`Editors/QuestEditor.cs`、`Persistence/PersistanceUtil.cs`、`PropertyDrawers/PersistableCheckpointPropertyDrawer.cs`、`PropertyDrawers/PersistableReferencePropertyDrawer.cs`。

这些编辑器偏离服务于当前资产 API 收口、自动化导入和 Inspector 可读性，不改变运行时真相源。

## 2026-06-14 时序补丁与通用帧延迟退场偏离

本轮继续收口旧时间补丁：正式运行时不再保留项目级 `CoroutineHelpers` 通用帧延迟工具，参考侧 `Miscellaneous/CoroutineHelpers.cs` 已从正式对齐范围排除；`CommandTrigger.cs` 的 `m_frameDelay` 只作为该组件自己的可配置延迟语义存在，由组件内部协程承载，不再向项目其它代码提供“一帧后再做”的公共补丁入口。

新增 `runtime allowed extra`：

- `UI/InputActionReleaseGate.cs`：正式输入释放门禁，用“共享输入必须先松开再放行”替代 action map 切换后一帧延迟。

新增或继续登记为 `runtime allowed patched`：

- `Game/Systems/GameStateSystem.cs`：不再延后一帧切 action map，改为依赖输入释放门禁。
- `Game/Systems/InputSystem.cs`：接入 `InputActionReleaseGate`，并按 UI map 激活状态启停 `BaseInputModule`。
- `UI/Menus/UIMenuManager.cs`：显示菜单后立即强制刷新 Canvas/Layout，再同步导航选中对象。
- `UI/HUD/Stats/UIStatBar.cs`：以“同一绑定目标已显示过正式值”为震动前提，不再靠首帧时间补丁。
- `UI/HUD/Dialogue/UIDialogueMessageBox.cs`：持有当前跳字协程句柄，跳过、切句或关闭时显式终止旧协程。
- `UI/UIControllerButtonManager.cs` 与 `UI/UIManager.cs`：登记为当前输入/UI 宿主融合的正式偏离，不恢复旧帧延迟接线。

新增或继续登记为 `editor allowed patched/extra`：

- `Persistence/PersistableProcessor.cs`：编辑器自动为 `Persistable` 补唯一标识；项目侧取消参考版阻塞对话框，改为无弹窗修复并标脏当前场景，同时避免 Play Mode 切换期间处理编辑期对象。
- `Playtest/EditorPlayModeOverride.cs`：编辑器 playtest 入口作为当前项目正式编辑器偏离登记，不再用“workaround”口径解释。

## 2026-06-14 音频事件迁移偏离

本轮新增偏离的共同原因是：项目侧音频请求已从已删除的 `NotificationSystem.audioPlaybackRequested` 调用面收回到 `GameCore` 强类型事件 `AudioPlaybackRequestedEvent`，由 Yoki `EventKit.Type` 派发并由 `AudioSystem` 监听。

新增 `runtime allowed extra`：

- `Events/GameRuntimeEvents.cs`：承载 `AudioPlaybackRequestedEvent` 与 `GameRuntimeEvents.RequestAudioPlayback(...)`，同时继续承载地图/存档生命周期强类型事件。
- `Events/GameRuntimeEvents.Lifecycle.cs`：承载地图加载、地图卸载和存档载入等框架生命周期事件的 partial 实现。
- `Events/GameRuntimeEvents.Presentation.cs`：承载受击、恢复、死亡、掉落、拾取和交互等表现事件的 partial 实现。
- `Events/GameRuntimeEvents.Progression.cs`：承载成长、背包、能力和任务相关事件的 partial 实现。
- `Events/GameRuntimeEvents.Progression.Inventory.cs`：承载金钱、物品和能力变化事件的 partial 实现。
- `Events/GameRuntimeEvents.Progression.Quests.cs`：承载任务日志、可用性和完成事件的 partial 实现。
- `Events/GameRuntimeEvents.Ui.cs`：承载菜单、商店、制作和详情请求等 UI 事件的 partial 实现。
- `Game/GameConfig.Contracts.cs`：承载配置相关 enum / struct 类型声明的 partial 实现。
- `Game/GameConfig.Persistence.cs`：承载 Playtest 快照、玩家死亡动作和持久化标识映射的 partial 实现。
- `Game/GameConfig.Terms.cs`：承载术语字典和 `GetTermDefinition(...)` 查询的 partial 实现。
- `UI/UIManager.MenuRuntime.cs`：承载菜单 seam 生命周期的 partial 实现。
- `UI/UIManager.MenuRegistrationRuntime.cs`：承载菜单绑定、类型校验和正式注册重建的 partial 实现。
- `UI/UIManager.MenuRequestRoutingRuntime.cs`：承载取消键和菜单/商店/制作请求路由的 partial 实现。
- `UI/UIManager.MenuStackRuntime.cs`：承载打开/关闭会话、栈深、close task 和 `GameState.Menu` 生命周期编排的 partial 实现。

新增 `runtime allowed patched`：

- `Commands/PlayAudioClip.cs`
- `Database/Items/ItemEffects/AItemEffect.cs`
- `Database/Items/ItemEffects/ItemEquipOrUnequip.cs`
- `Entities/Chest.cs`
- `Entities/Projectile.cs`
- `Entities/Characters/Hero.cs`
- `Game/GameManager.cs`
- `UI/UINavigationTarget.cs`

这些偏离不改变对应系统的业务真相，只把音频表现请求从旧 `NotificationSystem` 直接调用面迁到 `GameRuntimeEvents.RequestAudioPlayback(...)`。`AudioSystem.cs` 既是原有音频入口边界补丁，也是本轮事件迁移的消费者；正式音频请求路径只剩 `GameCore` 强类型事件。

同轮继续收口地图/存档生命周期事件：`MapSystem.cs` 不再直接触发 `NotificationSystem.mapLoading/mapLoaded/mapUnloading/mapUnloaded`，`SaveSystem.cs` 不再直接触发 `NotificationSystem.saveFileLoaded`；正式入口改为 `GameRuntimeEvents.NotifyMapLoading/NotifyMapLoaded/NotifyMapUnloading/NotifyMapUnloaded/NotifySaveFileLoaded`。`GameManager.cs` 不再订阅旧 UnityEvent，而是保留内部生命周期分发入口，确保 `AGameSystem` 回调先执行，外部 `EventKit.Type` 强类型事件后发布。这三份文件此前已经属于 `runtime allowed patched`，因此本项不增加新的 parity 路径计数，只更新偏离原因。

同轮继续收口地图切换输入锁定事件：`MapSystem.cs` 不再直接触发 `NotificationSystem.mapTransitionStarted/mapTransitionCompleted`，而是发送 `MapTransitionStartedEvent/MapTransitionCompletedEvent`；`InputSystem.cs` 不再订阅旧 UnityEvent，而是监听 Yoki `EventKit.Type` 强类型事件。这两份文件此前已经属于 `runtime allowed patched`，因此本项不增加新的 parity 路径计数，只更新偏离原因。

同轮继续收口地图过渡委托事件：`MapSystem.cs` 不再直接触发 `NotificationSystem.mapTransitionDelegationRequested`，而是发送 `MapTransitionDelegationRequestedEvent`；`TransitionSystem.cs` 不再订阅旧 UnityEvent，而是监听 Yoki `EventKit.Type` 强类型事件。这两份文件此前已经属于 `runtime allowed patched`，因此本项不增加新的 parity 路径计数，只更新偏离原因。

同轮继续收口地图过场宿主：`MapSystem.cs` 不再保留 `m_delegateTransitionResponsability` 开关和 `ExecuteTransition(...)` 直切图 fallback，正式过场宿主只剩 `TransitionSystem.cs`。这两份文件此前已经属于 `runtime allowed patched`，因此本项不增加新的 parity 路径计数，只更新偏离原因。

同轮继续收口动画消息旧传播模式：`Animation/StateMessageDispatcher.cs` 已经只承认 `RequireExplicitReceiver = 3`，并要求所有已登记消息命中显式接口接收者；静态门禁进一步禁止正式动画控制器再出现 `propagationMode: 0/1/2`。这一项不增加新的 parity 路径计数，只补充当前偏离理由和回归门禁。

同轮继续收口持久化对象销毁入口：`Persistable.cs` 不再直接触发 `NotificationSystem.persistableDestroyed`，而是把 `PersistableDestructionSnapshot` 直接交给 `PersistenceSystem`；`PersistenceSystem.cs` 不再订阅旧 UnityEvent，也不再依赖项目级事件总线。这两份文件新增为 `runtime allowed patched`，偏离原因是把持久化生命周期从迁移期通知面收回正式拥有者，不改变持久化数据模型。

同轮继续收口轻量世界标记变化事件：`GameFlagSystem.cs` 不再直接触发 `NotificationSystem.gameFlagChanged`，而是发送 `GameFlagChangedEvent`；`Conditional/Conditions/IsGameFlagSet.cs` 与 `Database/Quest/Tasks/GameFlagTask.cs` 不再订阅旧 UnityEvent，而是监听 Yoki `EventKit.Type` 强类型事件。这三份文件新增为 `runtime allowed patched`，偏离原因是把轻量世界状态变化从迁移期通知面迁入 GameCore 强类型事件，不改变 `GameFlagsDataBlock` 保存模型或任务条件语义。

同轮继续收口玩家能力释放失败提示事件：`PlayerController.cs` 不再直接触发 `NotificationSystem.playerFireFailed`，而是发送 `PlayerAbilityFireFailedEvent`；`UI/HUD/Abilities/UIHUDAbilityMessage.cs` 不再订阅旧 UnityEvent，而是监听 Yoki `EventKit.Type` 强类型事件。这两份文件此前已经属于 `runtime allowed patched`，因此本项不增加新的 parity 路径计数，只更新偏离原因。

同轮继续收口 AI 目标发现通知：`AIController.cs` 不再直接触发 `NotificationSystem.targetDetected`，也不再保留 `AITargetDetectedEvent` 空壳。该文件新增为 `runtime allowed patched`，偏离原因是把 AI 感知通知从迁移期通知面收回局部真相，不改变 AI 追踪、仇恨、寻路或攻击规则。

同轮继续收口怪物死亡进度事件：`Monster.cs` 不再直接触发 `NotificationSystem.monsterKilled`，而是发送 `MonsterKilledEvent`；`Database/Quest/Tasks/KillMonsterTask.cs` 不再订阅旧 UnityEvent，而是监听 Yoki `EventKit.Type` 强类型事件。`Monster.cs` 此前已经属于 `runtime allowed patched`，`KillMonsterTask.cs` 新增为 `runtime allowed patched`；偏离原因是把怪物死亡通知从迁移期通知面迁入 GameCore 强类型事件，不改变怪物奖励、经验、掉落、任务计数或保存语义。

同轮继续收口玩家生命周期入口：`PlayerSystem.cs` 不再直接触发 `NotificationSystem.playerSpawned` 或订阅 `NotificationSystem.heroKilled`；`Hero.cs` 不再直接触发 `NotificationSystem.heroKilled`，而是直接回调 `PlayerSystem`。玩家生成广播已删除，玩家死亡不再经过项目级事件壳。这两份文件此前已经属于 `runtime allowed patched`，因此本项不增加新的 parity 路径计数，只更新偏离原因。玩家死亡菜单、死亡命令、存档和复活语义不变。

同轮继续收口玩家成长事件：`Hero.cs` 不再直接触发 `NotificationSystem.experienceGained/levelUp`，而是发送 `HeroExperienceGainedEvent/HeroLevelUpEvent`；`JournalSystem.cs`、`Conditional/Conditions/IsQuestInState.cs` 与 `UI/HUD/EventLog/UIEventLog.cs` 不再订阅旧成长 UnityEvent，而是监听 Yoki `EventKit.Type` 强类型事件。这些文件此前已经属于 `runtime allowed patched`，因此本项不增加新的 parity 路径计数，只更新偏离原因。经验数值、升级规则、任务可用性和事件日志文案语义不变。

同轮继续收口背包、能力与任务事件：`Game/Systems/InventorySystem.cs`、`Entities/Characters/Hero.cs`、`Game/Systems/JournalSystem.cs` 与 `Quest/QuestProgress.cs` 不再直接触发旧 `NotificationSystem` 的背包、能力和任务 UnityEvent，而是发送 `InventoryMoney* / InventoryItem* / Equipment* / HeroAbility* / Quest*Event`；`Conditional/Conditions/IsItemInInventory.cs`、`Conditional/Conditions/IsAbilityUnlocked.cs`、`Conditional/Conditions/IsQuestInState.cs`、`Conditional/Conditions/IsQuestTaskActive.cs`、`Conditional/Conditions/IsQuestTaskInState.cs`、`Database/Quest/Tasks/ItemTask.cs`、`Entities/Characters/NPC.cs` 与 `UI/HUD/EventLog/UIEventLog.cs` 改为监听 Yoki `EventKit.Type` 强类型事件。这批文件新增为 `runtime allowed patched` 或继续沿用已登记补丁路径；它们不改变背包真相、任务状态真相、装备规则或日志文案，只把事件派发从旧迁移面收回 GameCore 强类型事件。
- 当前仍在补丁名单中的路径：
  - `Animation/StateMessageDispatcher.cs`
  - `Animation/Strategies/AAnimationStrategy.cs`
  - `Animation/Strategies/IAnimationStrategy.cs`
- `Animation/CameraShake.cs`
- `Animation/DamageScreenFlash.cs`
  - `Audio/AudioChannel.cs`
  - `Audio/AudioRegion.cs`
  - `Commands/AddExperience.cs`
  - `Commands/AddOrRemoveAbility.cs`
  - `Commands/AddOrRemoveMana.cs`
  - `Commands/ApplyEffectsToPlayer.cs`
  - `Commands/ExecuteCommandList.cs`
  - `Commands/HealOrDamagePlayer.cs`
  - `Commands/MovePlayer.cs`
  - `Commands/RevivePlayer.cs`
  - `Controllers/AIController.cs`
  - `Combat/Abilities/AbilityBase.cs`
  - `Combat/Abilities/Active/ActiveAbilityBase.cs`
  - `Combat/Abilities/Active/DashAbility.cs`
  - `Combat/Abilities/Active/MeleeAttackAbility.cs`
  - `Combat/Abilities/Active/ProjectileAbility.cs`
  - `Combat/Abilities/Active/SelfCastAbility.cs`
  - `Combat/Abilities/Active/SummoningAbility.cs`
  - `Combat/EffectDispatcher.cs`
  - `Combat/Effects/AEffect.cs`
  - `Combat/Effects/Immediate/ImmediateDamageEffect.cs`
  - `Combat/Effects/Temporal/TemporalDamageEffect.cs`
  - `Combat/PerTargetCooldown.cs`
  - `Controllers/PlayerController.cs`
  - `Database/Characters/CharacterSheet.cs`
  - `Entities/Entity.cs`
  - `Conditional/Conditions/IsAbilityUnlocked.cs`
  - `Conditional/Conditions/IsGameFlagSet.cs`
  - `Database/Abilities/Active/ActiveAbilitySheet.cs`
  - `Database/Audio/AudioClipResolver.cs`
  - `Entities/Characters/CharacterBase.cs`
  - `Database/Quest/Tasks/GameFlagTask.cs`
  - `Database/Quest/Tasks/KillMonsterTask.cs`
  - `Entities/Characters/Monster.cs`
  - `Entities/Characters/NPC.cs`
  - `Entities/Movable.cs`
  - `Game/Systems/AudioSystem.cs`
  - `Game/Systems/GameFlagSystem.cs`
  - `Game/Systems/InputSystem.cs`
  - `Game/Systems/InventorySystem.cs`
  - `Game/Systems/JournalSystem.cs`
  - `Game/Systems/MapSystem.cs`
  - `Game/Systems/PlayerSystem.cs`
  - `Game/Systems/SaveSystem.cs`
  - `Game/Systems/TransitionSystem.cs`
  - `Interactions/IInteractionTarget.cs`
  - `Interactions/InnInteraction.cs`
  - `Maps/Checkpoint.cs`
  - `Maps/CheckpointUtil.cs`
  - `Maps/ICheckpoint.cs`
  - `Maps/MapInfo.cs`
  - `Maps/Teleporter.cs`
  - `Miscellaneous/CommandTrigger.cs`
  - `Physics/CollisionDispatcher.cs`
  - `UI/UICharacterInfo.cs`
  - `UI/Effects/UIEffectList.cs`
  - `UI/FloatingTexts/CombatTextDisplay.cs`
  - `UI/FloatingTexts/FloatingText.cs`
  - `UI/FloatingTexts/FloatingTextPool.cs`
  - `UI/HUD/Abilities/UIHUDAbilityMessage.cs`
  - `UI/Effects/UIEffectListEntry.cs`
  - `UI/HUD/Abilities/UIHUDAbilityBar.cs`
  - `UI/HUD/Abilities/UIHUDAbilityBarEntry.cs`
  - `UI/HUD/Dialogue/UIDialogue.cs`
  - `UI/HUD/Dialogue/UIDialogueMessageBox.cs`
  - `UI/HUD/Dialogue/UIDialogueOption.cs`
  - `UI/HUD/EventLog/UIEventLog.cs`
  - `UI/HUD/Effects/UIHUDEffectBar.cs`
  - `UI/HUD/ItemDetails/UIItemDetails.cs`
  - `UI/HUD/Stats/UIStatBar.cs`
  - `UI/Menus/Abilities/UIAbilities.cs`
  - `UI/Menus/Abilities/UIAbilityBar.cs`
  - `UI/Menus/Abilities/UIAbilityBarEntry.cs`
  - `UI/Menus/Abilities/UIAbilityCategory.cs`
  - `UI/Menus/Abilities/UIAbilityListEntry.cs`
  - `UI/Menus/Character/UICharacter.cs`
  - `UI/Menus/Craft/UICraft.cs`
  - `UI/Menus/Craft/UIRecipeEntry.cs`
  - `UI/Menus/Inventory/UIInventory.cs`
  - `UI/Menus/Inventory/UIInventoryBag.cs`
  - `UI/Menus/Inventory/UIInventoryBagCategory.cs`
  - `UI/Menus/Inventory/UIInventoryBagSlot.cs`
  - `UI/Menus/Inventory/UIInventoryEquipmentSlot.cs`
  - `UI/Menus/Inventory/UIInventoryStats.cs`
  - `UI/Menus/Journal/UIJournal.cs`
  - `UI/Menus/Journal/UIJournalQuestEntry.cs`
  - `UI/Menus/Save/UISave.cs`
  - `UI/Menus/Save/UISaveFile.cs`
  - `UI/Menus/Shop/UIShop.cs`
  - `UI/Menus/Shop/UIShopEntry.cs`
  - `UI/Menus/UIGameMenu.cs`
  - `UI/Menus/UIGameMenuEntry.cs`
  - `UI/Menus/UIMainMenu.cs`
  - `UI/UIPlayerControllerFeedback.cs`

## 分类矩阵

### Runtime patched

| 路径 | 当前偏离主题 | 当前判断 | 下一步 |
| --- | --- | --- | --- |
| `Animation/StateMessageDispatcher.cs` | 已登记状态机消息改为强制命中正式接口合同 | 保留 | 当前仓库里真正使用的状态机消息只有角色无敌/死亡、过场淡入淡出完成和浮字动画结束三类固定语义，而且资产配置里也只剩这 7 条已登记消息；因此分发器现在对这些消息直接要求命中 `ICharacterAnimationStateReceiver/ITransitionAnimationStateReceiver/IFloatingTextAnimationStateReceiver`，若缺接收者就视为动画接线错误；旧 `BroadcastMessage/SendMessage/SendMessageUpwards` 传播分支也已从正式运行时移除，静态门禁也已禁止动画控制器回到 `propagationMode: 0/1/2` |
| `Animation/Strategies/AAnimationStrategy.cs` | 角色动画状态改为显式回调主路径 | 保留 | 无敌播放标记和死亡开始/结束事件现在有正式方法入口；旧 `OnMessageReceived(string)` 只保留为兼容 fallback，不再是主路径 |
| `Animation/Strategies/IAnimationStrategy.cs` | 动画策略接口显式暴露已登记状态机语义 | 保留 | 当前正式登记的角色状态机消息不再只是“传来一个字符串”，而是 `OnInvincibleAnimationStart/Stop` 与 `OnDeathAnimationStart/Stop` 这些可审计合同 |
| `Animation/CameraShake.cs` | 镜头受击震屏跟随当前控制角色 | 保留 | 旧实现把“玩家”硬绑到 `GameManager.Player`；当前改为读取 `PlayerSystem.currentControlledCharacterOrPlayerInstance` 正式回退入口，因此切换当前控制对象后，镜头受击震屏不需要再复制第二套摄像机逻辑 |
| `Animation/DamageScreenFlash.cs` | 受击屏幕闪屏正式入口 | 保留 | 与 `CameraShake` 同级，统一消费 `GameplayFeedbackSet.damageTakenFeedbackPlayed` 的正式上下文；它只负责全屏 UI 表现，不回读 NotificationSystem，也不复用过场黑幕的 Animator 生命周期 |
| `Audio/AudioChannel.cs` | BroAudio / 项目音频吸收层 | 保留 | 已形成正式音频入口边界，负责 BroAudio 优先、旧 `AudioClip` fallback、定点/跟随播放与完成回调；后续只在旧 `AudioClip` 资产完全退出后再评估是否可削薄 |
| `Audio/AudioRegion.cs` | 区域音频跟随当前控制角色 | 保留 | 旧实现把“玩家进入区域”硬绑到固定 `GameManager.Player`；当前统一走 `PlayerSystem.currentControlledCharacterOrPlayerInstance`，这样切控制对象时区域音频不会再丢失正式触发目标 |
| `Commands/AddExperience.cs` | 经验命令默认目标改为“显式 Hero actor 或真实当前受控 Hero” | 保留 | `AddExperience` 现在走 `GameCommandContext.ResolveHeroOrCurrentControlledHero()`；有 `Hero actor` 时命中该 `Hero`，actor 不是 `Hero` 时返回 `null`，只有完全无 actor 时才读取真实当前受控 `Hero`，不再假转给玩家长期主角 |
| `Commands/AddOrRemoveAbility.cs` | 能力增减命令默认目标改为当前受控角色 | 保留 | 能力命令现在走 `GameCommandContext.ResolveActorOrCurrentControlledCharacter()`；显式 actor 优先，无 actor 时命中当前受控角色，不再把默认目标写死为玩家长期主角 |
| `Commands/AddOrRemoveMana.cs` | 法力命令默认目标改为当前受控角色 | 保留 | 资源变化命令已统一消费当前命令上下文；默认目标是当前受控角色，而不是长期玩家实例 |
| `Commands/ApplyEffectsToPlayer.cs` | 效果命令默认目标改为当前受控角色 | 保留 | 施加效果的运行时目标现在由命令上下文解析；只有上下文拿到的角色才会被施加效果，不再回退静态玩家别名 |
| `Commands/ExecuteCommandList.cs` | 命令列表动作锁跟随当前命令上下文目标 | 保留 | `m_disabledActions` 的加锁/解锁现在命中当前命令上下文解析出的角色；命令列表不再默认锁住长期玩家主角 |
| `Commands/HealOrDamagePlayer.cs` | 生命命令默认目标改为当前受控角色 | 保留 | 治疗/伤害命令已和其它上下文化命令对齐；默认目标由当前命令上下文决定，而不是固定玩家长期实例 |
| `Commands/MovePlayer.cs` | 移动命令默认目标改为当前受控角色 | 保留 | `MovePlayer` 的上下文化解析现在返回 `context.ResolveActorOrCurrentControlledCharacter()`；无 actor 时移动当前受控角色，不再把“玩家”偷等同于长期玩家主角 |
| `Commands/RevivePlayer.cs` | 复活命令默认目标改为当前受控角色 | 保留 | 复活命令已统一走当前命令上下文目标；不再把无 actor 复活命令固定转发给长期玩家实例 |
| `Combat/Abilities/AbilityBase.cs` | TopDown `CharacterAbility.UpdateAnimator()` 风格动画更新触点 | 保留 | 只提供 `UpdateAnimationState()` 正式触点，让能力能在 GameCore 生命周期内更新动画状态；不复制 TopDown Animator 参数注册系统 |
| `Combat/Abilities/Active/ActiveAbilityBase.cs` | TopDown `CharacterAbility` 权限模型与 `Weapon.cs` 风格武器执行状态机接入 | 保留 | 保持 RPG Ability/Effect 规则真相；`CanFire()` 统一走 `AbilityPermissionSettings`，状态机只管理输入、前摇、后摇、连发、弹匣和换弹 |
| `Combat/Abilities/Active/DashAbility.cs` | 主动能力出手契约改为 `ExecuteAbilityUse` | 保留 | 由武器状态机决定出手时机，冲刺只执行一次位移 |
| `Combat/Abilities/Active/MeleeAttackAbility.cs` | 近战攻击接入统一武器执行时机和命中窗口 | 保留 | 已吸收 TopDown `MeleeWeapon/DamageOnTouch` 的初始延迟、持续命中窗口、忽略 owner、持续扫描和每目标冷却；伤害仍走 RPG Effect |
| `Combat/Abilities/Active/ProjectileAbility.cs` | 投射物攻击接入统一武器执行时机 | 保留 | 当前正式收口只覆盖统一出手时机；投射物池化仍等持久化生命周期规则锁定后再决定是否深化 |
| `Combat/Abilities/Active/SelfCastAbility.cs` | 自施法能力接入统一武器执行时机 | 保留 | 动画事件仍可触发实际效果，状态机负责输入节奏 |
| `Combat/Abilities/Active/SummoningAbility.cs` | 召唤能力接入统一武器执行时机 | 保留 | 保留召唤物存档和 RPG 阵营语义 |
| `Combat/EffectDispatcher.cs` | 效果命中参数增加动作表现数据 | 保留 | 让武器命中窗口把击退模式、击退强度、阻力和受击保护时间沿 RPG Effect 链路传递，不绕开规则层 |
| `Combat/Effects/AEffect.cs` | 效果实例缓存命中表现参数 | 保留 | 保持 Immediate/Temporal 效果共用同一命中参数来源，避免每个效果自造字段 |
| `Combat/Effects/Immediate/ImmediateDamageEffect.cs` | 即时伤害转发命中表现参数 | 保留 | 伤害数值仍由 `DamageSolver` 决定，只把动作表现参数传给 `CharacterBase.Damage` |
| `Combat/Effects/Temporal/TemporalDamageEffect.cs` | 持续伤害转发命中表现参数 | 保留 | 保持持续伤害与即时伤害的击退/受击保护入口一致 |
| `Combat/PerTargetCooldown.cs` | 每目标冷却支持显式 deltaTime | 保留 | 让武器命中窗口和 EditMode 测试复用同一冷却实现，不依赖 `Time.deltaTime` 隐式全局时间 |
| `Controllers/PlayerController.cs` | 输入消费侧改为正式 `IPlayerInputTarget` 实现，并把交互入口改成显式接口分发 | 保留 | 主体仍是 `2DRPGEngine` `PlayerController` 闭包，但不再自己订阅 `InputAction`；它只消费 `HandleMove/HandleFireAbility/HandleStopFireAbility` 等语义输入，并且只在自己是当前输入目标时更新交互目标和朝向。玩家交互也不再依赖 `SendMessageUpwards("OnInteract")` 字符串广播，而是只通知显式实现 `IInteractionReceiver` 的父级组件，避免未来切控制对象时复制一套订阅逻辑 |
| `Controllers/AIController.cs` | AI 目标发现通知收回局部真相 | 保留 | AI 的目标查找、激怒、追踪、攻击和保存语义仍保持 2DRPG 参考闭包；这里只把 `targetDetected` 通知从 `NotificationSystem` 收回 AIController 自身，不再引入项目级事件壳 |
| `Conditional/Conditions/IsAbilityUnlocked.cs` | 玩家能力条件显式回到 `PlayerSystem` 真相 | 保留 | 条件语义仍是“玩家长期 Hero 是否已解锁该能力”，暂不提升成“当前控制角色是否已解锁”；这里只把查询入口改成 `PlayerSystem.GetPlayerInstance()`，避免条件系统继续依赖静态玩家别名 |
| `Conditional/Conditions/IsQuestInState.cs` | 任务状态条件监听迁到 GameCore 强类型事件 | 保留 | 任务状态条件现在统一监听 `QuestAvailabilityChangedEvent + HeroLevelUpEvent + EventKit.Type`，不再依赖旧迁移期 UnityEvent；这样任务可用性刷新和等级变化都走正式强类型事件入口，不再扩张旧通知面 |
| `Database/Abilities/Active/ActiveAbilitySheet.cs` | Ability 数据资产增加武器执行参数 | 保留 | Inspector 直接配置前摇、后摇、缓冲、连发、弹匣和换弹 |
| `Database/Audio/AudioClipResolver.cs` | `SoundID + AudioClip` 双轨解析 | 保留 | 已成为正式资源入口，兼容旧 `AudioClip` 资产并支持 BroAudio `SoundID` 逐步替换；`AudioClipResolverTests` 已覆盖双轨行为 |
| `Database/Characters/CharacterSheet.cs` | 角色表增加生命/掉落反馈配置 | 保留 | 只让角色资产持有 `GameplayFeedbackSet`，用于受击、死亡和奖励表现；角色数值、经验、掉落和存档真相仍归 2DRPG/GameCore |
| `Database/Quest/Tasks/KillMonsterTask.cs` | 怪物死亡任务进度监听迁到 GameCore 强类型事件 | 保留 | 击杀计数、目标怪物表和任务进度保存语义仍保持 2DRPG 参考闭包；这里只把监听入口从 `NotificationSystem.monsterKilled` 迁到 `MonsterKilledEvent + EventKit.Type`，不改变任务规则 |
| `Entities/Entity.cs` | 交互成功/拒绝反馈接入，并继续作为正式交互接收者 | 保留 | 交互规则仍由 `IInteraction/ICommand` 执行，`GameplayFeedbackSet` 只播放成功或拒绝表现；当前通过 `IInteractionTarget : IInteractionReceiver` 显式声明交互入口，不再让玩家控制器靠字符串方法名扫父级层级 |
| `Entities/Characters/CharacterBase.cs` | 角色能力入口增加停止开火/换弹 | 保留 | 角色数据、生命、装备和存档真相仍保留在 2DRPG 语义内；受击/死亡反馈只走 `GameplayFeedbackSet`。`2026-06-17` 已删掉没有真实调用者的 `CharacterRegistrySystem`，因此 `CharacterBase` 不再承担 live runtime 注册/反注册接线 |
| `Entities/Characters/Hero.cs` | 玩家死亡、经验获得、升级入口继续收口 | 保留 | 玩家 Hero 仍是 RPG 数据、装备、经验、能力和存档真相；这里只把 `heroKilled` 通知从 `NotificationSystem` 收回 `PlayerSystem`，`experienceGained/levelUp` 继续走 `HeroExperienceGainedEvent/HeroLevelUpEvent + EventKit.Type`，并继续通过正式音频事件请求升级音效，不改变经验累加、升级规则、死亡暂停、死亡菜单、复活或存档规则 |
| `Entities/Characters/Monster.cs` | 怪物奖励反馈接入，并发送 GameCore 强类型怪物死亡事件 | 保留 | 掉落、金钱和经验仍由 2DRPG 背包/玩家系统结算，反馈只在奖励实际发放后播放；怪物死亡通知已从 `NotificationSystem.monsterKilled` 迁到 `MonsterKilledEvent + EventKit.Type`，不改变奖励或死亡规则 |
| `Entities/Characters/Monster.cs` | 怪物奖励编排直接回到正式拥有者 | 保留 | `2026-06-17` 已通过 deletion test 撤回 `MonsterRewardRuntime`，当前掉落判定、经验/金钱发放和奖励表现派发都直接回到 `Monster` 本体；继续复用 `MonsterSheet` 奖励规则、`InventorySystem` 背包真相和 `Hero` 成长真相，不引入第二套掉落、奖励或任务系统 |
| `Entities/Characters/NPC.cs` | NPC 任务提示监听生命周期收口 | 保留 | 参考原件在销毁时误把任务可用性变化监听再次 `AddListener`；当前改为对称 `RemoveListener`，避免 NPC 销毁后继续滞留监听。任务提示图标现在只依赖正式 `JournalSystem + QuestAvailabilityChangedEvent`，不再回读旧通知中心 |
| `Entities/Movable.cs` | TopDown 风格移动参数、输入模式和上下文速度倍率融合 + uMMORPG 停止半径合同补强 | 保留 | `git diff --no-index` 复核确认主体仍是 `2DRPGEngine` `Movable`；当前把 TopDown `CharacterMovement` 的方向模式、模拟输入、加减速、闲置阈值、普通移动禁止、速度倍率/上限和上下文速度倍率栈融合进现有移动闭包，并把 `uMMORPG Movement.Navigate(destination, stoppingDistance)` 的停止半径到达判定作为补强融合进现有移动闭包。命中表现参数下的击退覆盖入口已单独登记到战斗补丁，不构成第二套玩家移动实现；当前不需要另行重写控制器 |
| `Entities/Movable.MotionRuntime.cs` | `Movable` 内部动作执行 helper | 保留 | 当前已证明不是迁移残留。它只负责碰撞探测、MoveOrder、输入平滑、推力执行和上下文速度倍率栈，继续复用 `Movable` 的生命周期、朝向语义、击退规则和正式公开入口；不引入第二套移动器或第二套角色生命周期 |
| `Game/Systems/AudioSystem.cs` | BroAudio 接入 | 保留 | 已成为正式统一调用入口；负责通道路由、完成回调、定点/跟随播放与通道级停止/暂停/恢复，业务层不得绕过它直接调用第三方 API |
| `Game/Systems/InputSystem.cs` | YokiFrame InputKit 绑定工具融合 + 正式输入根收口 | 保留 | 2DRPG `InputSystem` 继续负责 Gameplay/UI action 语义、`PlayerInput` 生命周期和地图切换锁输入；InputKit 只登记当前 `PlayerInput.actions`，提供绑定导出/导入、保存/加载、重置、显示名和冲突查询，不启用/禁用 ActionMap，不引入 TopDown `InputManager`。`2026-06-17` 再做 deletion test 后，`InputActionCatalogRuntime`、`InputBindingRuntime`、`InputLifecycleRuntime`、`InputUiRuntime` 与 `InputGameplayRoutingRuntime` 已全部撤回并并回本体；动作引用装配、输入路由、UI 门禁和绑定工具接线现在都直接由 `InputSystem` 持有，正式输入闭包不再保留中间 helper 真相 |
| `Game/Systems/InventorySystem.cs` | 全局背包真相保留，但装备目标切到当前控制 Hero | 保留 | 当前已证明是正式真相，不是遗留。物品袋、金钱、序列化和事件派发现在都直接回到 `InventorySystem` 这一处正式宿主；`GetEquipment/TryEquip/TryUnequip` 也不再硬绑 `GameManager.Player`，而是统一走 `PlayerSystem.currentControlledHeroOrPlayerInstance`，把“穿戴到谁”收回当前前台操作目标 |
| `Events/GameRuntimeEvents.Lifecycle.cs` | 生命周期事件 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责地图加载/卸载、存档载入等框架生命周期事件定义与入口实现，继续复用 `GameRuntimeEvents.cs` 作为唯一正式发布入口；不引入第二套生命周期系统 |
| `Events/GameRuntimeEvents.Presentation.cs` | 表现事件 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责受击、恢复、死亡、掉落、拾取和交互等表现广播定义与入口实现，继续复用 `GameRuntimeEvents.cs` 作为唯一正式发布入口；不引入第二套表现事件系统 |
| `Events/GameRuntimeEvents.Progression.cs` | 成长事件 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责怪物击杀、经验和升级相关事件定义与入口实现，继续复用 `GameRuntimeEvents.cs` 作为唯一正式发布入口；不引入第二套成长通知系统 |
| `Events/GameRuntimeEvents.Progression.Inventory.cs` | 背包/能力事件 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责金钱、物品和能力变化事件定义与入口实现，继续复用 `GameRuntimeEvents.cs` 作为唯一正式发布入口；不引入第二套背包或能力通知系统 |
| `Events/GameRuntimeEvents.Progression.Quests.cs` | 任务事件 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责任务日志、可用性和完成事件定义与入口实现，继续复用 `GameRuntimeEvents.cs` 作为唯一正式发布入口；不引入第二套任务通知入口 |
| `Events/GameRuntimeEvents.Ui.cs` | UI 请求事件 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责菜单、商店、制作和详情请求等 UI 事件定义与入口实现，继续复用 `GameRuntimeEvents.cs` 作为唯一正式发布入口；不引入第二套 UI 运行时或请求路径 |
| `Game/GameConfig.Contracts.cs` | 配置类型声明 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责配置相关 enum / struct 类型声明，继续复用 `GameConfig.cs` 作为唯一正式配置入口；不引入第二套配置系统 |
| `Game/GameConfig.Persistence.cs` | 配置持久化/Playtest partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责 Playtest 快照、玩家死亡动作和持久化标识映射实现，继续复用 `GameConfig.cs` 作为唯一正式配置入口；不引入第二套存档或配置入口 |
| `Game/GameConfig.Terms.cs` | 配置术语查询 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责术语字典和 `GetTermDefinition(...)` 查询实现，继续复用 `GameConfig.cs` 作为唯一正式配置入口；不引入第二套术语系统 |
| `UI/UIManager.MenuRuntime.cs` | UIManager 菜单 seam 生命周期 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责菜单 seam 生命周期，继续复用 `UIManager.cs` 作为唯一正式菜单语义入口；不引入第二套菜单运行时 |
| `UI/UIManager.MenuRegistrationRuntime.cs` | UIManager 菜单注册 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责菜单绑定、类型校验和正式注册重建，继续复用 `UIManager.cs` 作为唯一正式菜单语义入口；不引入第二套菜单运行时 |
| `UI/UIManager.MenuRequestRoutingRuntime.cs` | UIManager 菜单请求路由 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责取消键和菜单/商店/制作请求路由，继续复用 `UIManager.cs` 作为唯一正式菜单语义入口；不引入第二套输入路由或 UI 宿主 |
| `UI/UIManager.MenuStackRuntime.cs` | UIManager 菜单运行时会话 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责打开/关闭会话、close task、栈深和 `GameState.Menu` 生命周期编排，继续复用 `UIManager.cs` 作为唯一正式菜单语义入口；不引入第二套 UI 运行时或路由系统 |
| `Game/Systems/JournalSystem.cs` | 任务真相、查询与编排重新合一 | 保留 | 当前已证明是正式真相，不是遗留。任务可接取等级仍然绑定玩家长期存档 Hero，而不是当前控制对象；`2026-06-17` 已通过 deletion test 撤回 `JournalQuestRuntime` 与 `JournalQueryRuntime`，把任务可接取刷新、任务实例创建/恢复、完成流转、序列化装配、NPC/任务查询和前置等级判定全部收回 `JournalSystem`。监听周期继续收回 `OnSystemStart/OnSystemStop`，并在 `OnSaveFileLoaded()` 再刷新一次任务可用性，避免继续依赖“先载任务、后载玩家”的顺序偶然正确。 |
| `Game/Systems/MapSystem.cs` | 地图真相与 traversal 生命周期重新合一 | 保留 | 当前已证明是正式真相，不是遗留。`MapSystem` 继续负责地图名、场景切换、检查点栈、传送、复活和 `MapDataBlock`；`2026-06-17` 已通过 deletion test 先撤回 `MapStateRuntime`，随后又撤回 `MapTraversalRuntime`，把活动 `MapInfo` 正式缓存、有序检查点状态、默认出生点入口、按地图配置延迟重生、过场、传送、重生和读档后的出生点修复编排全部收回同一正式宿主。当前 `MapInfo` 通过正式注册表进入系统，再由 `MapSystem` 按当前 tracked scene 选出唯一 `activeMapInfo`，不再依赖场景扫描；同时不接入 TopDown `LevelManager`、`GUIManager`、`MMCameraEvent` 或 MoreMountains 场景加载 |
| `Game/Systems/PersistenceSystem.Contracts.cs` | 持久化数据块合同 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责 `PersistenceDataBlock` 聚合形状，继续复用 `PersistenceSystem` 作为唯一正式持久化入口；不引入第二套持久化入口或世界存档语义 |
| `Game/Systems/PersistenceSystem.InstantiationRuntime.cs` | 持久化实例化/登记 partial | 保留 | 当前已证明是正式拆分，不是遗留。它只负责 prefab 实例化、运行时实例标记和自定义实例登记，继续复用 `PersistenceSystem` 的持久化字典真相、正式 API 和稳定标识映射；不引入第二套生成或持久化系统 |
| `Game/Systems/PersistenceSystem.cs` | 持久化真相与生命周期编排重新合一 | 保留 | 当前已证明是正式真相，不是遗留。`PersistenceSystem` 继续负责持久化字典真相、持久化对象解析、正式生命周期和稳定标识映射；当前把 `PersistenceDataBlock` 收进 `PersistenceSystem.Contracts.cs`，把实例化/登记实现收进 `PersistenceSystem.InstantiationRuntime.cs`，并通过 deletion test 再把数据块装配、地图加载恢复、销毁后回写和存档前快照从 `PersistenceLifecycleRuntime` 收回 `PersistenceSystem`。不引入第二套持久化模型，也不替代 SaveSystem 的世界聚合语义 |
| `Game/Systems/PlayerSystem.cs` | 玩家 Hero 与“当前输入目标”分离，并沉淀前台角色正式回退 API；玩家生成/死亡入口继续收口 | 保留 | 当前已证明是正式真相，不是遗留。玩家 Hero 仍是 RPG 数据和存档真相，但当前接玩家输入的对象改为 `currentInputTarget/currentControlledCharacter`；同时新增 `GetPlayerInstance()`、`currentControlledCharacterOrPlayerInstance/currentControlledHeroOrPlayerInstance` 和 `currentControlledHeroChanged`，把“长期玩家实例该从哪拿”“当前前台角色为空时如何回退、Hero 菜单何时切换、当前控制对象销毁后正式回退到谁”都收回系统真相，避免 UI、表现和交互层各自散落 `?? GetPlayerInstance()` 规则或手写角色转型。玩家生成广播已删，玩家死亡入口回到 `Hero -> PlayerSystem`，但死亡处理仍留在 PlayerSystem |
| `Game/Systems/SaveFileStorageRuntime.cs` | SaveKit 文件层编排 helper | 保留 | 当前已证明不是浅 seam。它只负责 SaveKit 的槽位、路径、版本、文件格式和稳定槽位映射，继续复用 `SaveSystem` 的 `SaveDataBlock` 世界状态聚合与恢复真相；不引入第二套世界存档模型 |
| `Game/Systems/SaveSystem.cs` | YokiFrame SaveKit 文件层融合 | 保留 | 2DRPG `SaveSystem` 继续负责 `SaveDataBlock` 世界状态聚合、默认存档复制和加载顺序；SaveKit 只负责槽位、版本、头部元数据、文件格式和删除，不引入第二套世界状态模型 |
| `Game/Systems/TransitionSystem.cs` | 过场完成事件改为显式动画状态接口入口 | 保留 | `OnFadeInCompleted/OnFadeOutCompleted` 现在通过 `ITransitionAnimationStateReceiver` 进入正式过场链；对当前已登记的过场动画消息，若没有命中这里，就应视为动画接线错误，而不是继续依赖字符串兜底 |
| `Interactions/IInteractionTarget.cs` | 交互目标接口显式接入玩家交互接收合同 | 保留 | `IInteractionTarget` 继续表达“可对话/可作为交互规则目标”的 RPG 语义，但现在显式继承 `IInteractionReceiver`，把“玩家可以直接对它发起交互”收回类型系统，不再依赖字符串上行消息 |
| `Interactions/InnInteraction.cs` | 旅店治疗和回蓝作用于交互发起者 | 保留 | 旧实现把接受治疗的目标硬绑到 `GameManager.Player`；当前改为直接使用 `TryExecute(source, target)` 传进来的 `source as Hero`，这样交互结果跟真实发起者一致，不再偷用固定主角 |
| `Maps/Checkpoint.cs` | TopDown 检查点顺序和强制覆盖规则吸收 | 保留 | 保留 2DRPG `PersistableCheckpoint` 存档语义，同时让场景检查点可按顺序推进或强制覆盖当前重生点；不引入 TopDown `CheckPointEvent` 或 `LevelManager` |
| `Maps/CheckpointUtil.cs` | 检查点工具已收回单一职责 | 保留 | 当前只保留“空地图名回退当前地图”这一条正式职责；无资产实例、无运行时调用的 `GameObjectCheckpoint` 与对象名解析后门已删除，不再让检查点工具兼任场景对象查找器 |
| `Maps/ICheckpoint.cs` | 检查点合同中文说明 | 保留 | 只补合同注释，明确空地图名保存前由 `MapSystem` 解析；无额外运行时分支 |
| `Maps/MapInfo.cs` | TopDown 地图表现配置吸收 | 保留 | 保留 2DRPG `playtestCheckpoint`，新增默认出生点、重生延迟、地图边界和相机目标 Inspector 配置；并在启用/禁用时把自己登记到 `MapSystem`，让地图闭包不再到处全局扫 `MapInfo`。它只承载场景表现数据，不绑定 Cinemachine 或 TopDown 事件系统 |
| `Maps/Teleporter.cs` | 世界穿越入口显式绑定玩家存档 Hero，并向父级解析真正传送目标 | 保留 | 传送器现在显式从 `PlayerSystem.GetPlayerInstance()` 读取世界穿越目标，而不是继续散落依赖 `GameManager.Player`；同时把 `uMMORPG Portal.cs` 的 `GetComponentInParent<Player>()` 入口规则作为入口鲁棒性补强融合进来，允许子碰撞体/骨骼碰撞体回溯到正式 `Hero`。原因不是“当前只能单主角”，而是 `MapSystem.TeleportTo/RespawnPlayer` 仍只对玩家存档 Hero 建模。若先把触发器改到 `currentControlledCharacter`，会造成“谁触发”和“谁被传送”分离成两套真相 |
| `Miscellaneous/CommandTrigger.cs` | 玩家触发器跟随当前控制角色，并显式声明交互接收合同 | 保留 | 旧实现把进入触发区、交互命令和玩家碰撞硬绑到唯一 `GameManager.Player`，且玩家交互依赖 `OnInteract` 字符串消息；当前统一读取 `PlayerSystem.currentControlledCharacterOrPlayerInstance`，并通过 `IInteractionReceiver` 显式接收玩家交互，让正式触发入口可以跟随当前受控角色，而不是未来再复制第二套触发器 |
| `Physics/CollisionDispatcher.cs` | Movable 碰撞通知不再走字符串消息 | 保留 | 保留参考里的“由 Movable 统一转发碰撞通知”职责，但把 `SendMessage("OnMovableCollision")` 改成显式 `IMovableCollisionReceiver` 接口调用，只通知真正声明了碰撞合同的组件 |
| `UI/UICharacterInfo.cs` | YokiFrame 角色状态图标池化 | 保留 | 替换 2DRPG 局部实例管理，统一容量、预热和诊断入口 |
| `UI/Effects/UIEffectListEntry.cs` | 效果列表条目不再用字符串上行消息通知列表宿主 | 保留 | 条目选中和取消选中现在直接调用父级 `UIEffectList` 的显式方法，而不是靠 `SendMessageUpwards("OnEffectHovered/OnEffectNotHovered")` 在层级树里碰运气命中接收者；条目被池化复用时会在 `SetEffect(...)` 重新解析当前父级宿主 |
| `UI/Effects/UIEffectList.cs` | 效果列表跟随当前控制角色，并使用 YokiFrame 池化条目 | 保留 | 默认效果列表不再只显示固定 `GameManager.Player` 的效果，而是可显式指定目标或默认走 `PlayerSystem.currentControlledCharacterOrPlayerInstance`；同时它现在直接承接 `UIEffectListEntry` 的显式悬浮/取消悬浮调用，并用 `GameObjectPoolService` 租还 buff/debuff 条目，不再每次显示时 `Destroy/Instantiate` 重建列表 |
| `UI/FloatingTexts/CombatTextDisplay.cs` | 浮字入口收回正式表现入口边界 | 保留 | `CombatTextDisplay` 现在统一消费 `GameplayFeedbackSet` 广播出的正式表现上下文；伤害、治疗、法力和持续效果浮字都不再直接监听全局通知，纯表现层不需要再从 NotificationSystem 反推显示语义 |
| `UI/FloatingTexts/FloatingText.cs` | YokiFrame 浮字回池生命周期 | 保留 | 动画结束直接归还统一对象池，避免浮字实例脱离池诊断 |
| `UI/FloatingTexts/FloatingTextPool.cs` | YokiFrame 浮字出租、预热和容量管理 | 保留 | 旧数组池只能查空闲实例，不能统一诊断、容量上限和场景释放 |
| `UI/HUD/Abilities/UIHUDAbilityMessage.cs` | HUD 提示监听周期对齐 UI 生命周期，并监听 GameCore 强类型能力失败事件 | 保留 | 仍然使用能力释放失败原因作为 HUD 提示来源，但事件入口已从 `NotificationSystem.playerFireFailed` 迁到 `PlayerAbilityFireFailedEvent + EventKit.Type`；订阅保持 `OnEnable/OnDisable` 对称收口，避免 HUD 被隐藏或复用后继续保留全局失败提示监听 |
| `UI/HUD/Abilities/UIHUDAbilityBar.cs` | HUD 技能栏跟随当前控制 Hero | 保留 | HUD 技能栏不再默认订阅唯一 `GameManager.Player` 的技能槽变化，而是直接根据 `PlayerSystem.currentControlledHeroChanged` 重新绑定当前受控 Hero；这样未来控制对象切换时，表现层不需要再复制一套技能栏入口，也不需要自己从角色事件里再做 Hero 转型 |
| `UI/HUD/Abilities/UIHUDAbilityBarEntry.cs` | HUD 技能冷却读数跟随当前控制 Hero | 保留 | 冷却显示不再从固定 `GameManager.Player` 读能力实例，而是统一读取 `PlayerSystem.currentControlledHeroOrPlayerInstance`；没有可用 Hero 或当前 Hero 没有该能力时，条目回到安全空态 |
| `UI/HUD/Dialogue/UIDialogue.cs` | 对话 HUD 宿主改为显式接收消息框与选项事件 | 保留 | `UIDialogue` 现在通过 `IDialogueHudEventReceiver` 正式接收“文本动画结束”和“选项点击”事件，不再让子组件依赖 `SendMessageUpwards` 命中父级私有方法；这样对话 HUD 内部职责关系回到类型系统，仍保持原有 RPG 对话主流程真相 |
| `UI/HUD/Dialogue/UIDialogueMessageBox.cs` | 对话消息框动画结束不再走字符串上行消息 | 保留 | 文本逐字播放结束后现在显式调用 `IDialogueHudEventReceiver.HandleMessageBoxTextAnimationFinished()`，因此选项框展示时机不再靠层级广播和方法名约定碰运气命中 |
| `UI/HUD/Dialogue/UIDialogueOption.cs` | 对话选项点击不再走字符串上行消息 | 保留 | 选项按钮点击后现在显式调用 `IDialogueHudEventReceiver.HandleDialogueOptionClicked(...)`，因此选项选择入口不再依赖 `SendMessageUpwards` 扫父级层级 |
| `UI/HUD/EventLog/UIEventLog.cs` | 事件日志监听周期对齐 UI 生命周期，监听 GameCore 强类型事件，并使用 YokiFrame 池化日志行 | 保留 | 事件日志仍读取经验、升级、金钱、物品、能力和任务等正式业务通知；这些通知已从旧 `NotificationSystem` 迁到 `GameRuntimeEvents + EventKit.Type`。订阅继续保持 `OnEnable/OnDisable` 对称收口，日志行生命周期统一交给 `GameObjectPoolService` 预热、租用和归还，避免 UI 层另保一套实例池 |
| `UI/HUD/Effects/UIHUDEffectBar.cs` | YokiFrame HUD 状态图标池化 | 保留 | 替换 2DRPG `InstancePool`，保持 UI 语义但统一工具层 |
| `UI/HUD/ItemDetails/UIItemDetails.cs` | 物品详情框监听周期对齐 UI 生命周期 | 保留 | 物品详情框仍使用 `itemDetailsOpened/itemDetailsClosed` 作为正式打开/关闭入口，但订阅改为 `OnEnable/OnDisable` 对称收口，避免场景切换或 UI 复用后保留脏监听 |
| `UI/HUD/Stats/UIStatBar.cs` | HUD 数值条跟随当前控制角色 | 保留 | 数值条不再硬绑唯一 `GameManager.Player`，而是可选固定目标或默认跟随 `currentControlledCharacter`；这样控制对象切换时，血条/蓝条等 HUD 可复用同一正式闭包 |
| `UI/Menus/Abilities/UIAbilities.cs` | 能力菜单跟随当前控制 Hero，并使用 YokiFrame 池化能力列表 | 保留 | 能力列表、分类计数和装备/卸装操作不再硬绑唯一 `GameManager.Player`，而是统一读 `PlayerSystem.currentControlledHeroOrPlayerInstance`，并直接订阅 `currentControlledHeroChanged`；能力列表条目生命周期现在由 `GameObjectPoolService` 统一租还，不再每次切分类时销毁重建 |
| `UI/Menus/Abilities/UIAbilityBar.cs` | 菜单内技能栏跟随当前控制 Hero | 保留 | 菜单中的技能槽不再长期订阅固定 Hero 的 `equippedAbilitiesChanged`，而是随 `PlayerSystem.currentControlledHeroChanged` 重新绑定；这样切控制对象时，菜单内的装备技能位和 HUD 一样只走一个正式入口，也不再自己做 Hero 转型 |
| `UI/Menus/Abilities/UIAbilityBarEntry.cs` | 能力栏条目不再用字符串上行消息通知菜单宿主 | 保留 | 技能栏点击与悬浮现在显式依赖 `IAbilityMenuEventReceiver`，而不是靠 `SendMessageUpwards("OnAbilityClicked/OnAbilityHovered")` 在父级树里碰运气命中接收者；这样能力菜单闭包内部的职责更清楚，也更容易静态检查 |
| `UI/Menus/Abilities/UIAbilityCategory.cs` | 能力分类条目不再用字符串上行消息通知菜单宿主 | 保留 | 分类切换与悬浮说明现在通过 `IAbilityMenuEventReceiver` 显式进入 `UIAbilities`，不再让菜单树内部靠方法名约定通信 |
| `UI/Menus/Abilities/UIAbilityListEntry.cs` | 能力列表条目不再用字符串上行消息通知菜单宿主 | 保留 | 列表条目的悬浮与选择入口现在显式走 `IAbilityMenuEventReceiver`，这样“谁负责装备模式切换、谁负责描述展示”回到正式菜单合同，而不是层级广播；条目被池化复用时会在 `Initialize(...)` 重新解析当前菜单宿主 |
| `UI/Menus/Character/UICharacter.cs` | 角色菜单跟随当前控制 Hero | 保留 | 角色等级、经验、可分配点数和属性加点入口不再硬绑唯一 `GameManager.Player`，而是改为当前受控 Hero，并直接订阅 `PlayerSystem.currentControlledHeroChanged`；但货币仍继续读 `InventorySystem.money`，因为它当前仍属于玩家长期背包真相，而不是任意受控角色私有资源 |
| `UI/Menus/Craft/UICraft.cs` | YokiFrame 制作菜单列表池化，并显式承接配方条目事件 | 保留 | 制作菜单语义仍归 2DRPG UI，配方条目和材料条目生命周期都归 `GameObjectPoolService` 统一租还；同时 `UICraft` 现在直接承接 `UIRecipeEntry` 的选中、取消选中和点击事件，不再靠父级字符串消息驱动配方详情和制作入口 |
| `UI/Menus/Craft/UIRecipeEntry.cs` | 配方条目不再用字符串上行消息通知宿主 | 保留 | 条目选中、取消选中和点击现在直接调用父级 `UICraft` 的正式方法，而不是靠 `SendMessageUpwards("OnRecipeEntrySelected/OnRecipeEntryDeselected/OnRecipeEntryClicked")` 在层级树里碰运气命中接收者；条目被池化复用时会在 `Initialize(...)` 重新解析当前制作菜单宿主 |
| `UI/Menus/Inventory/UIInventory.cs` | 物品使用目标跟随当前控制 Hero，并显式承接背包/装备条目事件 | 保留 | 背包格子和金钱仍来自全局背包，但点击物品后的 `item.Use(...)` 不再默认打到固定 `GameManager.Player`，而是作用于 `PlayerSystem.currentControlledHeroOrPlayerInstance`；同时它现在直接承接背包条目与装备栏条目的点击事件，不再靠父级字符串消息驱动使用和卸装入口 |
| `UI/Menus/Inventory/UIInventoryBag.cs` | 背包分类宿主显式承接分类按钮事件 | 保留 | 背包分类切换现在直接回到 `UIInventoryBag` 正式方法，而不是靠 `SendMessageUpwards("OnBagCategorySelected")` 扫父级层级；这样“当前背包显示的是哪一类”继续留在唯一正式宿主里 |
| `UI/Menus/Inventory/UIInventoryBagCategory.cs` | 背包分类按钮不再用字符串上行消息通知宿主 | 保留 | 分类按钮点击后现在直接调用父级 `UIInventoryBag` 的正式方法，而不是靠层级广播和方法名约定命中接收者 |
| `UI/Menus/Inventory/UIInventoryBagSlot.cs` | 背包格子不再用字符串上行消息通知宿主 | 保留 | 背包格子点击后现在直接调用父级 `UIInventory` 的正式方法，而不是靠 `SendMessageUpwards("OnBagItemClicked")` 在层级树里碰运气命中接收者 |
| `UI/Menus/Inventory/UIInventoryEquipmentSlot.cs` | 装备栏格子不再用字符串上行消息通知宿主 | 保留 | 装备栏点击后现在直接调用父级 `UIInventory` 的正式方法，而不是靠 `SendMessageUpwards("OnEquipmentItemClicked")` 在层级树里碰运气命中接收者 |
| `UI/Menus/Inventory/UIInventoryStats.cs` | 物品菜单属性栏跟随当前控制 Hero | 保留 | 背包菜单里的属性栏不再硬绑唯一主角，而是显示 `PlayerSystem.currentControlledHeroOrPlayerInstance` 的属性；这让同一套全局背包 UI 能服务多 Hero 前台查看，而不提前改掉全局背包与货币真相 |
| `UI/Menus/Journal/UIJournal.cs` | 日志菜单显式承接任务条目选中事件，并使用 YokiFrame 池化条目 | 保留 | `UIJournal` 现在直接承接 `UIJournalQuestEntry` 的选中事件，不再依赖 `SendMessageUpwards("UpdateQuestDescription")` 扫父级层级；任务条目生命周期统一交给 `GameObjectPoolService` 预热、租用和归还，不再在菜单初始化时自管一批裸实例 |
| `UI/Menus/Journal/UIJournalQuestEntry.cs` | 日志任务条目不再用字符串上行消息通知宿主 | 保留 | 条目选中后现在直接调用父级 `UIJournal` 的正式方法，而不是靠层级广播和方法名约定碰运气命中接收者；条目被池化复用时会在 `SetTargetQuest(...)` 重新解析当前日志菜单宿主 |
| `UI/Menus/Save/UISave.cs` | 存档菜单显式承接存档文件点击事件 | 保留 | `UISave` 现在通过正式方法承接 `UISaveFile` 的点击事件，不再依赖 `SendMessageUpwards("OnSaveFileClicked")` 扫父级层级；这样存档写入入口继续保持在现有菜单闭包内，职责更清楚 |
| `UI/Menus/Save/UISaveFile.cs` | 存档文件条目不再用字符串上行消息通知宿主 | 保留 | 条目点击现在通过 `ISaveFileEventReceiver` 显式通知父级菜单，而不是靠 `SendMessageUpwards` 命中 `UISave` 或 `UIMainMenu`；这保留了同一存档条目可被不同宿主复用的现有结构，同时把接收关系拉回类型系统 |
| `UI/Menus/Shop/UIShop.cs` | 商店菜单显式承接商店条目点击事件，并使用 YokiFrame 池化条目 | 保留 | `UIShop` 现在直接承接 `UIShopEntry` 的点击事件，不再依赖 `SendMessageUpwards("OnShopSlotClicked")` 扫父级层级；商店条目生命周期统一交给 `GameObjectPoolService` 租还，不再每次刷新时 `Destroy/Instantiate` 重建列表 |
| `UI/Menus/Shop/UIShopEntry.cs` | 商店条目不再用字符串上行消息通知宿主 | 保留 | 条目点击现在直接调用父级 `UIShop` 的正式方法，而不是靠 `SendMessageUpwards` 在层级树里碰运气命中接收者；条目被池化复用时会在 `Initialize(...)` 重新解析当前商店菜单宿主 |
| `UI/Menus/UIGameMenu.cs` | 游戏菜单显式承接条目选中事件 | 保留 | `UIGameMenu` 现在直接承接 `UIGameMenuEntry` 的选中通知，不再依赖父级字符串消息保存当前选中按钮；这样暂停菜单的选择状态仍留在唯一正式宿主里 |
| `UI/Menus/UIGameMenuEntry.cs` | 游戏菜单条目不再用字符串上行消息通知宿主 | 保留 | 条目选中时现在直接调用父级 `UIGameMenu` 的正式方法，而不是靠 `SendMessageUpwards("OnGameMenuEntrySelected")` 在层级树里碰运气命中接收者 |
| `UI/Menus/UIMainMenu.cs` | 主菜单显式承接存档文件点击事件 | 保留 | `UIMainMenu` 现在通过 `ISaveFileEventReceiver` 正式承接存档条目点击事件，不再依赖 `SendMessageUpwards`；这样主菜单加载存档的入口关系和 `UISave` 一样回到可静态检查的合同上 |
| `UI/UIPlayerControllerFeedback.cs` | UI 反馈目标改为监听当前控制角色 | 保留 | 交互按钮提示不再硬绑 `GameManager.Player.controller`；它监听 `PlayerSystem.currentControlledCharacterChanged`，因此未来切控制对象时 UI 不需要再单独换一套反馈脚本 |

### Runtime extra

| 路径 | 当前主题 | 当前判断 | 依据 |
| --- | --- | --- | --- |
| `AssemblyInfo.cs` | 历史测试程序集 internal 可见性 | 保留 | 只对历史 `FantasyWord.GameCore.Tests` 开放内部测试钩子，避免为了测试 SaveKit 槽位映射把运行时辅助方法改成公开 API；当前工作区 `Assets/Tests` 不存在，本项不代表当前有可复跑测试程序集 |
| `Audio/AudioChannelFallbackPlayer.cs` | 旧 `AudioClip` fallback 播放器 | 保留 | 已成为正式音频入口边界的一部分，负责旧 `AudioClip` 资产的定点/跟随播放、暂停/恢复、完成回调和池内复用；历史 `AudioChannelTests` 曾覆盖核心行为，当前以静态门禁、资源刷新和 Console 检查为主 |
| `Combat/Abilities/AbilityPermissionSettings.cs` | TopDown `CharacterAbility` 风格能力权限配置 | 保留 | 正式承接能力许可、角色条件阻断、移动阻断和其它能力武器状态阻断；权限真相仍使用 GameCore `CharacterBase/ActiveAbilityBase/WeaponExecutionRuntime`，不依赖 TopDown `Character`、`Health`、`InputManager` 或 MoreMountains 状态机 |
| `Combat/Abilities/IActionInterruptReceiver.cs` | 角色动作打断正式接口 | 保留 | 当前项目侧新增的显式合同，用来替代 `CharacterBase` 上对 `BroadcastMessage("OnActionInterrupted")` 的隐式层级扫描；后续只有真正需要处理中断收尾的能力或组件才实现它 |
| `Controllers/IPlayerInputTarget.cs` | 正式玩家输入目标接口 | 保留 | 输入订阅者和输入消费者分离后的正式合同；当前先由 `PlayerController` 实现，后续控制组或编队也应实现同一接口，而不是再复制一套 `InputAction` 订阅逻辑 |
| `Combat/Weapons/WeaponExecutionRuntime.cs` | TopDown `Weapon.cs` 风格武器执行状态机 | 保留 | 正式吸收攻击节奏、输入释放、连发、弹匣和换弹；不依赖 MoreMountains manager、GUI 或 Health |
| `Combat/Weapons/WeaponExecutionSettings.cs` | 武器执行参数数据 | 保留 | 让策划/开发者通过 Ability Sheet Inspector 配置动作执行，不新建第二套武器真相；来源对应 TopDown `Weapon.cs` 的触发模式、延迟、连发、弹匣与换弹字段 |
| `Combat/Weapons/WeaponHitWindowRuntime.cs` | TopDown `MeleeWeapon/DamageOnTouch` 风格命中窗口 | 保留 | 正式吸收初始延迟、短时启用伤害区域、忽略 owner 和每目标重复命中控制；不依赖 TopDown Health，目标效果仍交给 RPG Effect |
| `Entities/Characters/CharacterBase.AbilitySetRuntime.cs` | 角色能力集合真容器 | 保留 | 当前明确不是浅门面。它统一持有已解锁能力集合、加成能力计数、能力实例字典、触发能力集合，以及能力更新/重置/中断和存档遍历；`CharacterBase` 只保留规则入口和拥有权，且文件级所有权已继续收成 `CharacterBase` 私有 helper |
| `Diagnostics/RuntimeLogOverlay.cs` | 运行时诊断叠层 | 保留 | 工程诊断工具，不参与玩法地基真相源 |
| `Diagnostics/RuntimeLogOverlayBootstrap.cs` | 运行时诊断叠层启动 | 保留 | 与 `RuntimeLogOverlay` 成组，属于诊断工具边界 |
| `Diagnostics/FormalSceneSingletonConflictDiagnostics.cs` | 正式场景唯一节点冲突取证 | 保留 | 只负责正式场景里 `EventSystem/AudioListener` 数量异常取证，不自动创建、删除或修正对象；属于诊断工具边界，不是玩法宿主或兼容层 |
| `Animation/AnimationStateMessageContracts.cs` | 已登记状态机动画消息与接收接口合同 | 保留 | 当前项目把真正进入正式范围的状态机消息名集中到一个地方，并用显式接口承接角色、过场和浮字三类语义，避免未来继续把 Animator 字符串当成散落魔法值 |
| `Interactions/IInteractionReceiver.cs` | 正式玩家交互接收接口 | 保留 | 这是项目侧新增的显式合同，用来替代 `PlayerController` 上对 `SendMessageUpwards("OnInteract")` 的字符串分发；后续只有真正需要响应玩家交互的组件才实现它 |
| `UI/HUD/Dialogue/IDialogueHudEventReceiver.cs` | 对话 HUD 宿主事件正式接口 | 保留 | 这是对话 HUD 内部的显式 UI 合同，用来替代 `UIDialogueMessageBox/UIDialogueOption` 到 `UIDialogue` 的字符串上行消息；它不改变 RPG 对话树语义，只把消息框与选项组件和宿主之间的职责关系拉回类型系统 |
| `UI/Menus/Abilities/IAbilityMenuEventReceiver.cs` | 能力菜单宿主事件正式接口 | 保留 | 这是能力菜单内部的显式 UI 合同，用来替代 `UIAbilityBarEntry/UIAbilityCategory/UIAbilityListEntry` 到 `UIAbilities` 的 `SendMessageUpwards` 字符串通信；它不改变 RPG 菜单语义，只把宿主关系拉回类型系统 |
| `Loot/ItemPickable.cs` | 物品拾取正式入口 | 保留 | 由 `PickableItem` 负责拾取条件和禁用流程，成功后只把结果交给 `InventorySystem.AddToBag`，不引入 TopDown InventoryEngine 或第二套物品真相 |
| `Loot/MoneyPickable.cs` | 金钱拾取正式入口 | 保留 | 与 `ItemPickable` 同组，成功后只把结果交给 `InventorySystem.AddMoney`，不引入第二套背包/货币系统 |
| `Loot/PickableItem.cs` | TopDown `PickableItem` 拾取生命周期吸收 | 保留 | 正式承接拾取条件、碰撞触发、成功后禁用对象/碰撞体/模型的生命周期；拾取结果仍回到 2DRPG/GameCore 的物品和货币真相 |
| `Miscellaneous/MovementZone.cs` | TopDown 风格移动区域样板吸收 | 保留 | 它只为正式 `Movable` 提供区域内速度倍率与移动限制样板，不引入 TopDown `CharacterMovement`、`LevelManager` 或第二套移动器 |
| `Physics/IMovableCollisionReceiver.cs` | Movable 碰撞通知正式接口 | 保留 | 当前项目侧新增的显式合同，用来替代 `CollisionDispatcher` 上对 `SendMessage("OnMovableCollision")` 的字符串分发；后续只有真正需要消费碰撞通知的组件才实现它 |
| `Presentation/GameplayFeedbackSet.cs` | TopDown `MMFeedbacks` 生命周期表现入口边界 | 保留 | 作为 GameCore 唯一允许直接持有 `MMFeedbacks` 的反馈配置边界，只播放能力/武器生命周期反馈；生命、输入、伤害和玩家数据仍归 GameCore RPG 闭包 |
| `Resources/Generated/FWRes.g.cs` | 强类型资源入口生成物 | 保留 | YokiFrame 资源生成能力结果，避免业务散落裸字符串 |
| `Resources/Generated/FWScene.g.cs` | 强类型场景入口生成物 | 保留 | YokiFrame 场景入口生成结果 |
| `Resources/Generated/FWText.g.cs` | 强类型本地化文本入口生成物 | 保留 | YokiFrame 本地化链路生成物 |
| `UI/UIPointerUtility.cs` | UI 指针判断小工具 | 保留 | 项目侧 UI 工具，避免恢复旧 UI 系统 |
| `UI/UITipsItem.cs` | 轻量提示项 | 保留 | 项目侧 UI 提示能力，避免恢复旧 UI 系统 |
| `UI/UITipsService.cs` | 轻量提示服务 | 保留 | 与 `UITipsItem` 成组，作为项目侧小工具 |

### Editor extra

| 路径 | 当前主题 | 当前判断 | 依据 |
| --- | --- | --- | --- |
| `Persistence/PersistableProcessor.cs` | 编辑期 Persistable 标识自动修复 | 保留 | 参考版在缺失标识时弹阻塞对话框；当前项目为了 AI/自动化和批量导入流程，改为仅在非播放、非即将切换播放模式时无弹窗修复并标脏当前场景，不改变运行时保存数据模型 |
| `Bridge/FormalSceneInputRootAutomation.cs` | 正式场景显式输入根节点自动化入口 | 保留 | 这是 `AutomationOnly` 的编辑器取证/修复入口，只服务 `SampleScene/ClickMoveTest` 的显式 `EventSystem + InputSystemUIInputModule` 检查与确定性补建；当前已拆成 `InspectOpenFormalScene / EnsureOpenFormalSceneInputRoot / EnsureOpenFormalSceneInputRootAllowDirtyFormalScene` 三层入口，并通过 `RepairBlockedByDirtyScene + RecommendedRepairMethod` 向外层自动化返回结构化分支建议；不自动执行，也不替用户保存正式场景 |
| `scripts/Inspect-FormalSceneInputRoots.ps1` | 正式场景输入根节点静态回退检查 | 保留 | 当 AIBridge 超时或 Unity 主线程阻塞时，用于直接从 `SampleScene.unity / ClickMoveTest.unity` 的磁盘 YAML 读取 `EventSystem / InputSystemUIInputModule / StandaloneInputModule` 标记、缺失根节点模式和缺失动作引用模式；这是工作区静态证据工具，不参与运行时地基真相 |
| `Overlays/SceneSelectorOverlay.cs` | 场景选择器从旧 Overlay 改为 Unity 6 工具栏下拉入口 | 保留 | 参考原件只提供 `SceneView Overlay` 按钮列表；项目侧改成 `ToolbarZonePlayMode` 下拉，可直接显示当前场景并按路径切换，更符合当前 Unity 版本与项目编辑器使用方式 |
| `Utils/SceneUtil.cs` | 场景选择工具扩展为结构化条目与排序规则 | 保留 | 为配合工具栏下拉，需要补 `SceneEntry`、Build Settings 优先级和菜单路径排序；这是与 `SceneSelectorOverlay.cs` 成组的编辑器增强，不参与运行时地基真相 |
| `Bridge/BridgePollerRecovery.cs` | AIBridge 导入/轮询恢复辅助 | 保留 | 编辑器自动化工具边界，不参与玩法运行时地基 |

## 迁移原则

- 当前用户目标优先级是“参考主体先完整搬过来，再把项目吸收层压到最小”。
- 没有成熟引擎或正式项目硬约束支持的 UI 小池补丁，默认不保留。
- 若某个补丁只是把参考里的局部 `Instantiate/Destroy` 统一改成项目对象池，但没有跨模块硬约束、没有性能证据、也不是正式框架合同，则默认按“可直接拷回参考”处理。
- 当前 `FloatingText/UICharacterInfo/UIHUDEffectBar/UIEffectList/UIAbilities/UICraft/UIEventLog/UIJournal/UIShop` 的池化不再按“小补丁”处理，因为三方裁决已确认 YokiFrame `GameObjectPoolService` 在设计模式、软件工程和易用性上优于 2DRPG 局部池或反复销毁重建列表。
- 若某个补丁已经承载了对象回池生命周期、持久化兼容或项目正式工具边界，应基于证据判断是“正式保留”还是“继续暂留”；不要为了追求零 diff 先把项目已吸收的底层能力拆坏。

## 下一批建议顺序

1. 相机/屏幕反馈：继续沿 `GameplayFeedbackSet` 或同等级 GameCore 正式入口边界扩展，不散落 `MMFeedbacks`；当前第一段镜头震屏与受击闪屏都已收回正式表现链。
2. 控制对象/控制组：点击移动、WASD、摇杆前，继续收缩表现层和交互层里直接依赖 `GameManager.Player` 的入口，再把输入目标从唯一 `Hero` 约束推进到当前控制对象/控制组接口。
