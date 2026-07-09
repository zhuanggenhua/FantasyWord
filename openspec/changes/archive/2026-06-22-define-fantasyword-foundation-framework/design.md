# Design: define-fantasyword-foundation-framework

> 状态：当前提案已收口。正式基线改为对齐成熟参考，不再采用旧 `Bootstrapper/RuntimeContext/ModuleInstaller/EventBus` 自造地基。

## Summary

边界补充：

- 本文里与 `uMMORPG` 相关的结论，只服务 `2D 移动与场景组织` 的 4 个一级缺口。
- 它不是把 `uMMORPG` 升格成第四个总框架候选。
- 开放世界模拟层仍是另一层长期架构任务，不被这 4 个一级缺口覆盖。

`FantasyWord` 的正式框架不再按“谁先接进来了就继续用谁”判断，而是固定按三项标准裁决：

- `设计模式`：职责是否清楚，行为是否靠组合和正式所有者表达，而不是靠第二套 manager 或隐式广播拼出来。
- `软件工程`：是否只有一个真相源，是否容易验证、维护序列化闭包、限制回归面。
- `易用`：策划和开发是否能通过 Inspector、Prefab、ScriptableObject 和少量代码稳定组装内容。

以下都不是正式理由：

- “当前已经接进仓库的是 `2DRPGEngine`，所以继续以它为总框架”
- “`TopDownEngine` 只是参考，不用和现有闭包正面对比”
- “`YokiFrame` 只是工具层，所以不需要参与地基裁决”
- “三边都不错，所以先都包着最稳”

正确口径是：

- 先识别职责类型，再决定谁赢；不是先选“总框架”，再要求所有系统一起跟着它走。
- 世界规则谁在三项标准上更强，就让谁做世界规则真相。
- 动作执行谁在三项标准上更强，就让谁正式替换薄实现。
- 工具层谁更强，就直接替换项目侧重复工具。
- 若不同维度由不同来源胜出，就做 `正式融合`，但融合后的正式入口仍只能有一套。
- 当前 change 的任务范围只到 `框架地基裁决、目录边界、正式入口、工具替换、参考缺口和门禁`。在这批前提没有锁定前，不得再用任何具体玩法、具体菜单、具体 HUD、具体商店、具体背包或具体死亡界面去做“顺手迁一段”的业务竖切样板。反过来，禁止业务竖切不代表禁止框架替换：UIKit 菜单运行时、GAS 属性/效果/能力规则、Yoki 工具和 TopDown 动作模式这些框架级系统必须按胜负裁决推进。

对应文档链路固定为：

- `docs/ai/框架最终裁决.md`：默认引用入口，先给最终结论。
- `docs/ai/框架三项判分矩阵.md`：回答“为什么选这边”。
- `docs/ai/框架正式动作清单.md`：回答“这个模块到底替换、融合还是冻结”。
- `docs/ai/框架实施阶段表.md`：回答“这些动作先做什么后做什么”。

按这三项复核后，当前正确框架是四层，而不是“以某个成熟框架整体接管”：

| 层 | 正式方向 | 选择理由 |
| --- | --- | --- |
| RPG 世界规则层 | `2DRPGEngine` 进入 `GameCore` 的数据、地图、存档、任务、对话、背包和角色数据闭包 | 它在 `设计模式` 上最清楚地表达“世界状态是什么”，在 `软件工程` 上最适合保持地图、任务、背包、角色和存档的一套真相，在 `易用` 上最适合 RPG 数据生产 |
| 俯视角动作表现层 | `TopDownEngine` 的角色能力、移动、武器、命中、受击、反馈和关卡表现样板，吸收到 `GameCore` 正式闭包 | 它在动作能力组合、武器状态机和 Inspector 调手感上明显更强，但不能把自己的 manager、输入和 UI 一起带进来制造第二生命周期 |
| 通用工具层 | `YokiFrame` 的对象池、存档文件底层、输入重绑定、资源/场景工具、UI 缓存和诊断工具 | 它在工具深度和开发效率上胜出，但它回答的是“怎么复用和承载”，不是“世界状态是什么”，因此只竞争工具层 |
| 开放世界模拟层 | `FantasyWord` 项目侧后续自行建立区域/Cell、队伍、派系、AI 日程、经济和局部模拟内核 | 这层是 `2DRPGEngine`、`TopDownEngine`、`YokiFrame` 都没有完整覆盖的目标能力，不能继续塞进 `GameManager.*` 或任何第三方 manager |

这意味着当前正式方向不是“继续用 2DRPG 当总框架”，而是：

- 世界规则真相以 `2DRPGEngine` 为主。
- 动作执行与手感以 `TopDownEngine` 为主。
- 底层通用工具以 `YokiFrame` 为主。
- 开放世界模拟由 `FantasyWord` 自己补。

同职责冲突时，动作只有三种：

- `直接替换`：当前薄实现退场，由胜出的参考模式成为正式实现。
- `正式融合`：不同维度由不同来源胜出，但融合后的正式入口只能保留一套。
- `暂不动`：现在动它只会制造第二真相、第二生命周期或提前拆层。

当前已经落进仓库的 `Database`、`ICommand`、`GameFlagSystem`、`MapInfo/Checkpoint`、`Persistable/PersistenceSystem`、`Entity` 变换持久化底座，以及 `2026-06-12` 起同步进入 `GameCore` 的 `SaveSystem`、玩家传送相关 `MapSystem/Teleporter`、`Interaction`、`Movable/Controller/PlayerSystem` 和相关 `Combat/Quest/UI` 闭包，只能视为“现态证据”。它们证明当前仓库已经施工到哪里，不反过来充当选择理由。

旧 `FantasyWordBootstrapper + FantasyWordRuntimeContext + FantasyWordModuleInstaller + FantasyWordServiceRegistry + FantasyWordEventBus + 五大 ModuleAsset` 没有成熟参考同职责依据，不再作为正式实现、验收口径或后续扩展前提。

当前存在的裁剪闭包不是新的框架设计。它们只允许表示三类情况：移除参考项目第三方依赖、适配当前 Unity/C# 编译语义、或者因为上游参考闭包尚未迁入而暂时禁止某些 API。每个裁剪点必须登记到 `docs/ai/foundation-reference-audit.md` 的“参考偏离台账”；没有登记的偏离不得作为正式实现保留。

本 change 的目标不是把多个成熟框架外面再包一层，而是选定单一真相源后直接落地。基础 RPG 数据、生命周期、地图、存档、命令、交互、物品、任务和 UI 闭包默认以 `2DRPGEngine` 为主；俯视角动作手感、能力组件、武器、拾取、机关、相机和 2D 地牢样板默认以 `TopDownEngine` 为局部参考；对象池、协程、资源/场景/文本强类型入口、本地化、日志和 UI 小工具由 `YokiFrame` 承担工具层。任何同职责冲突都必须在这三者中选一个当前真相源，不得通过 `Compatibility`、`Adapter`、`FoundationSupport` 或镜像包装层维持双轨。

这里再补一条任务范围约束：

- 当前阶段允许做的 UI 工作是 `运行时约束核对、目录位置裁决、资源加载链盘点、UIKit 原生用法审计、菜单入口边界收口、禁止项登记`。
- 当前阶段不允许做的 UI 工作包括 `拿某个具体菜单/面板做迁移样板`、`为了验证 UIKit 先补一套业务 Prefab/面板资源链`、`把具体玩法流程临时改成 UIPanel`。
- 也就是说，UIKit 不能做“具体业务落地”，但它已经是当前正式 UI 机制真相；后续专项的重点不再是“要不要让 UIKit 进来”，而是“项目侧还需要保留多薄的一层菜单入口”。该专项继续用非业务化空面板/框架测试面板验证打开、关闭、层级、焦点、缓存和资源链，而不是拿背包、商店或 HUD 当样板。
- 当前现态再补一条：这层菜单入口已经并回 `UIManager`，因此后续不允许再回长出新的 `MenuHost/UIKitFacade/UIPanelWrapper` 一类项目层第二入口。

对 `uMMORPG Remastered - MMORPG Engine [2.41]` 的裁决也按同一原则执行：它当前不是整体运行时来源，只是 2D 移动与场景组织的局部源码证据源。当前已证实有价值的是 6 条源码证据：`Movement.Reset/Warp/IsValidSpawnPoint/NearestValidDestination` 这组移动合同、`Navigate(destination, stoppingDistance)` 的停止半径合同、手动输入打断旧导航路径、失效保存位置回退到正式出生点、传送入口回溯正式玩家实体，以及“实例宿主/出生点分流宿主应显式存在”这条场景组织判断。这里要分清：前 5 条移动/传送/读档入口规则已经分别作为合同、规则或健壮性补强融合到 `Movable / MapSystem / Teleporter` 正式闭包，不是重复搬运 `uMMORPG` 的同职责实现；第 6 条“实例宿主/出生点分流宿主应显式存在”仍只是职责证据，不等于当前项目已经有可直接搬运的单机/本地实现。进一步按当前目录级复核，`Assets/uMMORPG/Scripts/MovementSystems` 也已经扫到边界：`NavMeshMovement.cs / RegularNavMeshMovement.cs` 只算 `NavMesh + Mirror` 负证据，`PlayerCharacterControllerMovement.cs + CharacterController2k.cs` 只算 `Mirror + 3D CharacterController` 负证据；真正还保留局部移动参考价值的只剩 `Movement.cs` 与 `PlayerNavMeshMovement.cs`。当前仍缺的一级框架参考位只有 4 个：单机/本地 2D 导航 Provider、2D 点击移动执行闭包、单机/本地场景实例宿主参考和单机/本地出生点分流宿主参考。没有这些参考前，不得把点击移动、控制组穿越、实例入口或出生点分流实现成项目侧临时过渡层。

<!-- FOUNDATION_DEVIATION_NOT_NEW_DESIGN -->
<!-- FOUNDATION_UNREGISTERED_DEVIATION_FORBIDDEN -->

## Key Decisions

### 真相所有权冲突提案

当前不是把所有全局入口都视为坏设计。`GameManager.XxxSystem` 的优点是实现快、调用直观、符合当前 2DRPG 参考闭包；只要它指向的是当前项目级或 RPG 基线唯一系统，就可以暂时保留。真正要治理的是“同职责第二真相”和“局部状态伪装成全局状态”。

补充裁决见 `game-manager-static-access-policy.md`。本项目不把“任何代码能通过 `GameManager` 拿系统”当成单独罪名；快速实现本身没有问题。问题发生在调用者跨过正式所有者直接改状态，或者把世界级、模式级、实体级状态都伪装成项目全局状态。更符合软件工程的方案不是新造一层服务定位器，而是把系统归到 `Project / World / Mode / Entity` 四层所有权：项目级服务可由当前 `GameManager + AGameSystem` 承载，开放世界状态归后续世界运行时，卡牌自走棋单局状态归模式运行时，角色和卡牌单位等局部状态归实体自身。

| 冲突面 | 当前裁决 | 实施动作 |
| --- | --- | --- |
| `GameManager` 13 个静态 system 快捷入口 | 保留为现有 2DRPG 基线快速访问面 | 不拆现有入口；禁止新增开放世界、卡牌模式、GAS、UIKit、TopDown manager 等新快捷入口；跨域调用后续逐步改为明确所有者、上下文或事件 |
| 已删除的 `NotificationSystem` vs Yoki `EventKit` | 事件派发机制选 Yoki `EventKit.Type`；领域事件类型留在 GameCore | 旧通知中心已从运行时、测试和场景正式移除；新增和既有正式事件统一进入 GameCore 强类型事件结构 + `EventKit.Type` |
| `AUIMenu/UIMenuManager` vs Yoki `UIKit` | Yoki `UIKit` 原生模型已经是正式 UI 机制真相；项目侧只允许保留承接菜单请求的单一运行时入口，当前已并回 `UIManager`。旧 `AUIMenu` 只保留已被吸收到 `UIKitMenuPanelBase` 的菜单语义，不再保留旧入口 | 不做 adapter 双栈；不再额外挂历史独立菜单组件或任何等价第二入口去复制 panel lifecycle/stack/cache；不允许同一菜单同时有 `AUIMenu` 和 `UIPanel` 两套真相；未来纯工具或非菜单 panel 允许直接按 `UIPanel + UIKit.OpenPanel<T>/PushPanel/PopPanel` 实施 |
| `Stats/currentStats` vs GAS `AttributeSet` | GAS 在复杂属性集、效果叠层、标签、冷却和能力规则上是正式替换候选；当前正式读取、通知、死亡判定与当前值存档已优先走 `CharacterBase + ASC`，旧 `Stats/currentStats` 只剩过渡缓冲 | 未完成专项矩阵前，GAS 不并行接管生命、法力、攻击、防御等同一数值；若 GAS 胜出，必须替换对应职责，而不是并行显示/结算/存档 |
| `GameCore InputSystem` vs Yoki `InputKit` vs TopDown `InputManager` | 玩法输入语义保 GameCore；Yoki 做重绑定工具；TopDown 输入根不接 | 卡牌模式后续需要模式输入上下文，但不新增 `GameManager.CardInputSystem`；不让每个控制器自行订阅全局输入 |
| `SaveSystem/PersistenceSystem` vs Yoki `SaveKit` | 世界/角色/背包/任务语义保 GameCore 数据块；文件读写、版本迁移和底层存储可由 Yoki SaveKit 承担 | 不建第二套存档真相；SaveKit 只能替换文件层工具，不拥有世界语义 |
| `MapSystem` vs 开放世界 `WorldRuntime` | `MapSystem` 保地图加载、检查点、传送；开放世界区域/派系/AI 日程/经济另归世界运行时 | 不把区域、Cell、派系、经济、局部模拟继续塞进 `MapSystem` 或 `GameManager.XxxSystem` |
| `InventorySystem` vs 角色/队伍/容器所有权 | 背包系统是框架模块；长期玩家物品集合可保留，装备/使用目标跟随当前正式控制对象或队伍语义 | 不把具体物品/商店/UI 当框架；也不把“全局背包”硬解释成所有容器和队伍背包 |
| 游戏内卡牌自走棋模式 | 它是本游戏的一部分，可依赖玩家长期数据和项目级服务；单局牌局状态独立 | 卡牌收藏/卡组/奖励接存档和背包；牌局棋盘、自动回合、单位状态、模式输入不得依赖开放世界当前地图/当前角色/移动输入 |
| TopDown manager 链 | 不接管总框架 | 只吸收动作执行、受击反馈、重生/边界样板；禁止 `LevelManager/InputManager/GUIManager/GameManager` 进入正式生命周期 |
| Yoki 工具层 | 工具胜出时直接用，不再复制薄工具 | `PoolKit/EventKit/SaveKit/InputKit/UIKit` 按职责接入；但 `SingletonKit/Architecture` 不接管玩法生命周期 |

这张表是后续实施的优先入口。没有登记在这里或对应专项矩阵里的真相冲突，不得靠“先能跑”默认保留两边。

### 三方裁决总则

- `2DRPGEngine` 胜出的前提不是“当前已经接入”，而是它在 RPG 世界规则、地图、存档、任务、背包、对话和角色数据这些系统上，更符合单一真相源和长期内容生产。
- `TopDownEngine` 胜出的前提不是“功能多”，而是它在角色能力组合、移动手感、武器状态机、命中窗口、受击反馈和关卡表现样板上，同时满足更清楚的职责分离和更高的可调性。
- `YokiFrame` 胜出的前提不是“工具库很全”，而是它在对象池、文件存储、输入重绑定、资源句柄和 UI 缓存等工具位上，能直接替换项目侧重复工具实现，同时不争夺玩法真相。
- 当同一系统在三项标准上由不同来源胜出时，只允许“正式融合”，不允许双轨共存；融合后的公开入口必须继续落在 `GameCore` 正式闭包或第三方稳定工具入口。
- 当某个模块暂时没有明确胜者，或现在实施只会制造第二生命周期、第二输入根、第二 UI 根或第二存档真相时，结论是 `暂不动`，不是先造兼容层。

### 运行时入口对齐 GameManager

运行时入口采用 `GameManager + AGameSystem`：

- `GameManager` 挂在场景运行时根节点。
- `GameManager` 在 `Awake` 收集当前场景中的 `AGameSystem`。
- `GameManager` 驱动 `OnSystemInit`、`OnSystemStart`、`OnSystemStop`。
- 地图加载、地图卸载和存档加载等框架生命周期由 `GameRuntimeEvents.NotifyMapLoading/NotifyMapLoaded/NotifyMapUnloading/NotifyMapUnloaded/NotifySaveFileLoaded` 进入正式链路。
- `GameManager` 只承担已收集 `AGameSystem` 的生命周期分发，并在系统回调之后发布 Yoki `EventKit.Type` 强类型事件；不得恢复 `NotificationSystem` 或任何等价旧通知壳作为这些生命周期的项目侧调用入口，也不得新增公开 `GameManager.Notify*` 主动通知入口。
- `GameManager` 可以保留现有 2DRPG 地基系统快捷入口来服务快速实现；但它不承载角色、世界、物品、战斗、UI、卡牌模式或开放世界模拟规则本身。
- 新增领域若只是为了“调用方便”想挂成 `GameManager.XxxSystem`，必须先证明它是项目级唯一服务，而不是世界级、模式级、实体级或工具层职责。
- 现有跨系统调用不做一次性大拆；只有当某个调用点正在制造第二真相、绕过正式拥有者、或阻碍 `World/Mode/Entity` 所有权收口时，才随对应模块重构迁出。

### 系统不是空模块资产

正式系统优先表现为可运行的 `AGameSystem` 组件，而不是 ScriptableObject 空模块安装链。

允许存在 ScriptableObject 配置和数据库条目，但它们必须服务于明确系统闭包，例如 Database、Inventory、Map 或 Persistence。不得用 `*ModuleAsset` 先占位定义角色、世界、物品、战斗、表现五大模块。

### 数据真相层后置但必须对齐参考

当前已建立 `DatabaseRegistry + DatabaseEntry + DatabaseEntryReference + PrefabReference` 最小闭包。该闭包优先对齐 `2DRPGEngine` 的：

- `DatabaseRegistry`
- `DatabaseEntry`
- `DatabaseEntryReference`
- `PrefabReference`
- 相关编辑器索引和验证入口

当前已迁入参考项目使用的 `azixMcAze.SerializableDictionary` 与 `MackySoft.SerializeReferenceExtensions`。`DatabaseRegistry` 的 GUID 映射和 `GameConfig.persistentIdentifierMappings` 已回到参考字典形状；这类底层依赖补齐后，后续相关闭包默认继续按参考原形迁入，而不是保留临时列表替代层。不得用自造服务容器或事件总线替代数据真相层。

### 地图、交互和存档按成熟闭包补齐

俯视角开放世界的地基不是抽象事件队列，而是可运行的地图、交互和持久化闭包。后续正式方向：

- 旧 `NotificationSystem`：已从正式运行时、测试与场景彻底移除。事件派发机制统一以 Yoki `EventKit.Type` 为准，领域事件定义统一留在 GameCore。
- GameFlagSystem：当前已对齐参考中的字符串布尔标记集合、`GameFlagsDataBlock` 和 `gameFlagChanged` 事件；这是独立轻量状态闭包，不再和完整 SaveSystem 一起后置。
- MapInfo/Checkpoint：当前已对齐 `MapInfo`、`ICheckpoint`、`SimpleCheckpoint` 和 `CheckpointUtil` 的命名与字段合同；空地图名通过 `GameManager.MapSystem.GetCurrentMapName()` 解析。
- MapSystem：以 2DRPG 的地图名、场景切换、过渡委托、检查点栈、玩家传送、重生入口和 `MapDataBlock` 作为地图真相源。
- Teleporter/玩家传送：当前随 PlayerSystem/Movable/Controller 和音频事件闭包进入正式 `GameCore`；后续只在这条正式闭包上补接线和验证，不另建测试传送器。
- 地图表现配置：吸收 TopDown `LevelManager/CheckPoint` 的关卡边界、默认出生点、检查点顺序、重生延迟、相机目标和场景对象重生样板；不得接入 TopDown `LevelManager`、`GameManager`、`GUIManager`、`Health` 或 MoreMountains 场景加载流程作为第二生命周期。
- Command：当前已对齐 `ICommand`。
- Interaction：待角色/对话依赖可用后对齐 `IInteraction`、`IInteractionTarget`、`CommandInteraction`。
- Persistence 数据合同：当前已对齐 `DataBlock`、`IDataBlockHandler`、`PersistableDataBlock` 和持久化信息类型。
- Persistable/PersistenceSystem：当前已对齐 `Persistable`、`PersistableReference`、`PersistenceSystem` 中依赖 Notification、Map、PrefabReference 的闭包。
- SaveSystem：待 Inventory/Journal/Player 数据块和 SaveFile 依赖明确后，对齐 `SaveSystem` 和 `SaveFile`；当前不得造空系统数据块。
- Entity：当前已对齐 `EntityDataBlock` 和 transform 持久化；交互、对话和 UI 浮标不在当前闭包。
- Movable/Controller/PlayerSystem：当前正式闭包已经在 `GameCore` 落地，后续动作应是继续对齐参考、补接线和补验证；不得因为“想先快速跑通”就在 `Assets/Scripts/test` 或测试场景中再开一套并行玩家控制器。只有当现有正式闭包与参考之间存在无法直接对齐的明确缺口时，才允许考虑临时试做；但在创建这类代码或场景前，必须先补流程理由文档，写清参考缺口、不能直接复用正式闭包的原因、拟新增对象和退出条件，并先向用户上报批准。

### 有限联机候选，不生成网络架构

联机方向已更新为长期候选：FishNet 主机权威的有限人数合作。当前 foundation change 仍不接入 FishNet 包、不创建网络 SDK 抽象、网络模块资产或联机上下文容器。当前只要求关键规则避免写死在 UI 回调或单个场景对象里；这是单机复杂开放世界、Mod 兼容和未来有限联机共同需要的维护边界。具体产品边界、Mod 清单握手和类昆特牌局内对战边界见 `docs/ai/联机与Mod边界.md`。

### 第三方和候选资产保护

第三方插件和参考工程自带 demo 场景、Prefab、脚本、素材不得因为“不在当前正式闭包”而删除。MiniFantasy 素材包是正式美术来源，其自带 demo 场景、Prefab 和示例脚本只作为来源证据与接线参考；未进入正式玩法链路的内容先记录为候选或参考来源，后续由参考矩阵决定是否迁入。

### 可读性和注释是交付条件

本项目由 AI 主导实现，但代码必须适合人长期维护。新增或改造项目侧系统、工具、ScriptableObject、编辑器入口、验证脚本和 Inspector 暴露字段时，必须补足中文注释或中文 Inspector 说明，解释职责、调用契约、边界和取舍；不得用无注释的“能跑代码”作为完成状态，也不得用复述代码表面行为的废话注释凑数。

## Rejected Design

以下旧设计已撤出正式地基：

- `FantasyWordBootstrapper`
- `FantasyWordRuntimeContext`
- `IFantasyWordService`
- `FantasyWordServiceRegistry`
- `FantasyWordEventBus`
- `FantasyWordModuleAsset`
- `FantasyWordModuleInstaller`
- `CharactersModuleAsset`
- `WorldModuleAsset`
- `ItemsModuleAsset`
- `CombatModuleAsset`
- `PresentationModuleAsset`

撤出原因：它们不是当前正式参考源、EX-GAS、BroAudio、Unity 官方 API 或 UE 成熟范式的同职责可复制设计，现有测试只证明自造结构自身能运行，不能证明它适合作为项目地基。

## Verification Direction

本 change 的最低验证方向：

- 静态门禁确认 `GameManager + AGameSystem + GameConfig` 存在。
- 静态门禁确认 `SampleScene` 不再接线旧 Bootstrapper/Installer/ModuleAsset。
- 必要端到端 smoke 覆盖当前正式启动闭包能被 Unity 导入、刷新和测试程序集加载；若没有运行时代码或场景行为变化，不为文档、目录和门禁调整新增 Unity 测试。
- 关键合同测试只保护跨系统生命周期、存档/序列化、资源引用闭包和已登记的高风险参考吸收点；不得把每个 helper、简单 API、入口转发或目录整理都拆成同粒度测试。
- OpenSpec 不再把旧自造地基列为正式 requirement。
- 参考矩阵记录每个后续地基闭包的参考路径、当前落点、差距和验证入口。
