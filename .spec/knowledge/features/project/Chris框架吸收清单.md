---
name: Chris框架吸收清单
description: 项目知识：Chris框架吸收清单.md：Chris框架吸收清单。
metadata:
  type: doc
  status: 已交付
---

# Chris 框架吸收清单

本文记录 Chris 与当前 FantasyWord/YokiFrame 组合的代码级对照结论。结论只针对当前项目，不代表 Chris 或 YokiFrame 的通用优劣。

## 结论

Chris 不是全方面强于 YokiFrame，也不适合作为 FantasyWord 的整套底座替换。更合理的做法是保留当前 `GameManager + AGameSystem + DatabaseRegistry + GameRuntimeEvents + YokiFrame 工具层` 主线，只吸收 Chris 在外部资源、Mod 包、Addressables 工作流和少数编辑器工作流上的成熟实现。

当前已经值得直接搬入的是两块：

- `ResourceSystem / ResourceHandle / ResourceCache / SoftAssetReference`：补齐 Addressables 运行时加载、句柄释放、外部 catalog 加载和软地址引用。
- `ModAPI / ModLoader / ModInfo / ModConfig / ModState / ModValidator`：补齐本地 Mod 目录扫描、启停状态、版本校验、zip 解包和 catalog 加载入口。

当前不建议直接搬入的是 Chris 的宿主层：`ModuleLoader / GameWorld / WorldSubsystem / Actor`。这些模块有设计价值，但会和 FantasyWord 现有主线重叠，直接原版搬入会形成第二套运行时事实。

## 当前项目真相

当前正式运行时主线已经存在：

- 全局运行时入口：`Assets/Scripts/GameCore/Runtime/Game/GameManager.cs`
- 系统注册和生命周期：`Assets/Scripts/GameCore/Runtime/Game/GameManager.SystemRegistryRuntime.cs`、`Assets/Scripts/GameCore/Runtime/Game/GameManager.LifecycleRuntime.cs`
- 项目系统基类：`Assets/Scripts/GameCore/Runtime/Game/Systems/AGameSystem.cs`
- 世界/地图状态：`Assets/Scripts/GameCore/Runtime/Game/Systems/MapSystem.cs`
- 玩家和存档状态：`Assets/Scripts/GameCore/Runtime/Game/Systems/PlayerSystem.cs`、`Assets/Scripts/GameCore/Runtime/Game/Systems/SaveSystem.cs`、`Assets/Scripts/GameCore/Runtime/Game/Systems/PersistenceSystem.cs`
- 数据主轴：`Assets/Scripts/GameCore/Runtime/Database/DatabaseRegistry.cs`、`Assets/Scripts/GameCore/Runtime/Database/DatabaseEntryReference.cs`
- 事件发布入口：`Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.cs` 与同目录 partial 文件，底层派发用 Yoki `EventKit.Type`
- YokiFrame 工具层：`Assets/Plugins/YokiFrame/Core/Runtime/EventKit`、`Tools/SaveKit`、`Tools/UIKit`、`Core/Runtime/PoolKit`

这意味着 Chris 的宿主层不是“缺失基础设施”，而是“另一套基础设施”。只有当现有主线出现明确扩展瓶颈时，才应该按职责拆分吸收，而不是整包替换。

## 已吸收

### 资源层

落点：

- `Assets/Scripts/GameCore/Runtime/Resources/ResourceSystem.cs`
- `Assets/Scripts/GameCore/Runtime/Resources/ResourceHandle.cs`
- `Assets/Scripts/GameCore/Runtime/Resources/ResourceCache.cs`
- `Assets/Scripts/GameCore/Runtime/Resources/SoftAssetReference.cs`
- `Assets/Scripts/GameCore/Runtime/Resources/Annotations/AssetReferenceConstraintAttribute.cs`
- `Assets/Scripts/GameCore/Runtime/Resources/SparseArray.cs`

价值：

- 提供统一 Addressables 加载入口，避免业务代码直接散落 `Addressables.LoadAssetAsync` 和释放逻辑。
- `ResourceHandle` 把加载、实例化和释放做成可追踪句柄，适合 Mod 包、临时特效、远端内容和按需资源。
- 外部 catalog 加载是 Mod 必须能力。当前 `ResourceSystem.LoadCatalogAsync` 已经能把 Mod 目录中的 catalog 加入 Addressables 定位器。
- `SoftAssetReference` 只用地址作为运行时标识，适合外部内容包，不强迫使用 Unity `AssetReference` 的 GUID 语义。

边界：

- 它不替代 `DatabaseRegistry`。玩法数据、存档引用、稳定 ID 仍以 `DatabaseEntryReference` 和项目数据库为主。
- Unity 6 + Addressables 2.7 下，二进制 catalog 的 `{DYNAMIC_LOCAL_PATH}` 路径重写不能原样使用 Chris 的内部 API。当前实现通过公开的 `Addressables.LoadContentCatalogAsync(path, true)` 加载二进制 catalog；如果二进制 catalog 里仍包含动态占位符，需要导出时写成实际路径，或后续单独评估反射/导出器改造。

### Mod 层

落点：

- `Assets/Scripts/GameCore/Runtime/Mods/ModAPI.cs`
- `Assets/Scripts/GameCore/Runtime/Mods/ModLoader.cs`
- `Assets/Scripts/GameCore/Runtime/Mods/ModInfo.cs`
- `Assets/Scripts/GameCore/Runtime/Mods/ModConfig.cs`
- `Assets/Scripts/GameCore/Runtime/Mods/ModState.cs`
- `Assets/Scripts/GameCore/Runtime/Mods/ModValidator.cs`
- `Assets/Scripts/GameCore/Runtime/Utilities/ZipWrapper.cs`

价值：

- 直接对应“必须支持 Mod”的长期目标：扫描 `Mods` 目录、解压 zip、读取 `.cfg`、校验 API 版本、记录启用/禁用/删除状态、加载启用 Mod 的 catalog。
- 与当前项目主线耦合较低，只接入资源 catalog，不强行接管玩法系统、数据表或事件总线。
- `ModConfig` 已改成项目侧 JSON 文件，默认保存到 `Application.persistentDataPath/FantasyWordModConfig.json`，避免为了 Mod 引入 Chris 全套 Config 框架。

后续需要补的不是再搬 Chris 宿主层，而是定义 FantasyWord 自己的 Mod 合同：

- Mod 包目录格式和 `.cfg` 字段规范。
- 官方内容与 Mod 内容的稳定 ID 冲突处理。
- Mod 数据如何进入 `DatabaseRegistry` 或后续外部数据表。
- 资源依赖、加载顺序、禁用后的存档兼容策略。

## 可局部吸收

### DataDriven / DataTable

Chris 价值：

- `DataTable` 用 `SerializedObject<IDataTableRow>` 支持多态行数据，编辑器窗口比普通 ScriptableObject 列表更适合大量表格内容。
- `DataTableManager` 与 `ResourceSystem` 联动，适合把外部内容表通过 Addressables/Mod catalog 加进游戏。

当前项目已有：

- `DatabaseRegistry`、`DatabaseEntry`、`DatabaseEntryReference` 已经承担官方玩法数据主轴。
- 现阶段内容数据还在 ScriptableObject/项目数据库形态，不缺一个全局表格运行时。

建议：

- 不直接替换 `DatabaseRegistry`。
- 当 Mod 需要追加物品、配方、任务、怪物、地图入口时，吸收 Chris 的“外部 DataTable + 行类型 + 加载器”思想。
- 落地形态应是 `ModDataRegistry` 或“外部数据源导入到 DatabaseRegistry 扩展层”，而不是把官方数据也整体迁到 Chris DataTable。

触发条件：

- Mod 需要新增而不是只覆盖资源。
- 数据需要跨包合并、校验、冲突报告。
- 官方内容量大到 Inspector 列表编辑明显低效。

### Serialization

Chris 价值：

- `SerializedType<T>` 适合在 Inspector 中选择某个接口/基类实现类型。
- `SerializedObject<T>` 适合保存无 UnityEngine.Object 引用的多态配置对象。
- `FormerlySerializedTypeAttribute` 这类类型重定向对长期 Mod/存档兼容有价值。

当前项目已有：

- 已接入 `MackySoft.SerializeReferenceExtensions`，可解决部分 `[SerializeReference]` 编辑器体验。
- 项目数据大量依赖 Unity Object、ScriptableObject 和现有数据库引用。

建议：

- 不整套搬 Chris Serialization。
- 优先吸收类型重定向、接口实现选择器、纯 C# 多态配置这三类能力。
- 避免和 MackySoft 形成两套多态编辑器入口；后续只在 MackySoft 无法覆盖的地方补。

触发条件：

- Buff/AI/条件/任务效果开始大量使用纯 C# 策略对象。
- 需要对 Mod 暴露“选择一个实现类型并保存参数”的编辑器能力。
- 需要处理类型改名后的外部数据兼容。

### Schedulers

Chris 价值：

- 零分配计时器/帧计数器，适合大量短周期延迟和帧等待。
- 带调试器，能查定时任务来源。

当前项目已有：

- UniTask、协程、Unity 生命周期已经足够覆盖普通异步和延迟。
- 当前未看到大量高频定时器成为性能瓶颈。

建议：

- 暂不搬。
- 如果战斗、状态效果、AI 感知、特效生命周期出现大量延迟任务，再吸收一个项目侧 `SchedulerService`，而不是让业务直接依赖 Chris 静态 Scheduler。

触发条件：

- Profiler 显示协程/UniTask/闭包延迟造成明显 GC。
- 同一帧有大量状态效果或 AI 计时任务。

### Pool

Chris 价值：

- `PooledGameObject` / `PooledComponent` 提供统一的零分配对象池封装。

当前项目已有：

- YokiFrame 已有 `PoolKit`。
- 项目侧已有 `FloatingTextPool`、`AudioChannel` fallback pool 等具体池化使用点。

建议：

- 不直接搬 Chris Pool，避免和 Yoki PoolKit 并存。
- 可以吸收它的“Disposable 归还语义”和性能基准做法，用于收口 Yoki PoolKit 的项目使用规范。

触发条件：

- Yoki PoolKit 无法满足 Addressables 实例池、组件池或回收生命周期。
- 需要统一所有特效、浮字、投射物、音频实例的池化 API。

### AnimationProxy

Chris 价值：

- 用 Playables 封装 Animator，可直接播放 montage/sequence，支持多层、过渡和事件订阅。
- 对技能、采集、交互动作链比直接堆 Animator 参数更可控。

当前项目已有：

- 现有 `AAnimationStrategy`、`PolydirectionalAnimationStrategy`、角色/装备 Sprite 动画主线。
- 当前是 2D 像素俯视角，动画问题主要是方向、装备层、帧数据和动作状态，不是复杂 3D montage。

建议：

- 不现在搬。
- 后续做技能连段、采集职业动作、装备层同步时，只吸收“脚本化动作片段播放 + 事件点”的设计，不照搬 Ceres/Flow 集成部分。

触发条件：

- Animator 参数和状态机开始难以维护动作链。
- 需要在同一角色上组合基础移动、武器动作、受击、施法和采集动作。

### Capture

Chris 价值：

- `ScreenshotTool` 对截图流程做了运行时/编辑器封装，可隐藏 UI、选择相机、超采样、异步截图。

当前项目已有：

- AIBridge 是 AI 验证和出图入口。
- 游戏内玩家截图不是当前核心玩法目标。

建议：

- 暂不搬。
- 若后续需要头像生成、存档缩略图、分享截图或自动化视觉回归，可参考它做项目侧截图服务。

### AI EQS

Chris 价值：

- FieldView 和 PostQuery 是面向复杂 AI 感知/掩体点位选择的查询系统。

当前项目已有：

- 俯视角开放世界 AI 还没进入复杂战术层。

建议：

- 暂不搬。
- 后续怪物 AI 需要视野锥、听觉、巡逻兴趣点、掩体/岗位选择时，按需求吸收查询模型。

### LevelSystem

Chris 价值：

- 提供场景/关卡加载、进度聚合和 Addressables 关卡资源入口。

当前项目已有：

- `MapSystem`、`MapInfo`、`Checkpoint`、`PersistableCheckpoint` 已承担地图和出生点主线。

建议：

- 不直接搬。
- 只在开放世界切图、分区流式加载、Mod 地图包接入时，参考它的“异步加载进度聚合”和“关卡资源表”。

## 暂不吸收

### ModuleLoader

Chris 机制：

- 在 `RuntimeInitializeOnLoadMethod(BeforeSceneLoad)` 自动扫描继承 `RuntimeModule` 的类型。
- 按 `Order` 排序后初始化，也可以从 `ModuleConfig` 指定模块列表。

为什么暂不搬：

- 当前项目已经有 `GameManager.FindSystems()` 收集场景中的 `AGameSystem`，并按 `OnSystemInit/Start/Stop` 运行。
- 自动反射模块会绕过场景接线和项目文档里已经确定的入口，出现“代码里自动启动一套，场景里又有一套”的双入口。
- Chris 原版 ModuleLoader 还依赖 Configs/SerializedType，原样搬会继续扩大依赖。

可吸收的点：

- “显式有序初始化”这个思想可以保留，但应体现在 `AGameSystem` 的优先级或启动配置上。
- 如果确实需要模块化插件启动，应该做 `GameSystemStartupOrder` 或 `IModRuntimeExtension`，挂到当前 `GameManager` 主线下。

触发条件：

- 系统初始化顺序开始依赖不稳定。
- Mod 需要注册运行时扩展，而不是只加载资源和数据。
- 场景内系统不再适合承载所有长期服务。

### GameWorld / WorldSubsystem / Actor

Chris 机制：

- `GameWorld` 是运行时世界容器，自动创建当前世界，维护 `Actor` 列表和 `ActorHandle`。
- `WorldSubsystem` 是绑定到 `GameWorld` 的非 MonoBehaviour 系统，可自动创建、Tick/FixedTick，并能访问世界内 Actor。
- `Actor` 是世界实体基类，注册到 `GameWorld`，可绑定控制器、ActorComponent，并能接 Ceres Flow 热更新逻辑。

为什么暂不搬：

- FantasyWord 已经有 `GameManager` 管系统、`MapSystem` 管地图、`Entity/Movable/CharacterBase/Hero/Monster/NPC` 管实体、`PersistenceSystem` 管持久化引用。
- 直接搬入 Chris `Actor` 会要求实体继承体系重排，影响 Prefab、序列化字段、GAS/装备/存档闭包，收益不够抵消风险。
- `WorldSubsystem` 的实际价值是“世界内非 MonoBehaviour 服务 + Actor 查询缓存”。当前还没有足够复杂的世界查询需求。

可吸收的点：

- `ActorHandle` 的版本化句柄思想，可用于后续稳定运行时实体引用，避免对象销毁后旧引用误命中。
- `WorldSubsystem` 的非 MonoBehaviour 服务思想，可用于 AI 感知、空间查询、世界事件索引，但应挂在当前 `MapSystem` 或未来 `WorldRuntimeContext` 下。
- `ActorQuerySystem` 的“实体集合变更后标 dirty，再重建查询缓存”值得后续参考。

触发条件：

- 需要跨场景/地图分区追踪大量运行时实体。
- AI、任务、互动、存档都开始依赖统一实体查询。
- 现有 `Entity/CharacterBase` 体系需要稳定运行时句柄，而不是直接保存 Unity 对象引用。

### EventSystem

Chris 价值：

- 借鉴 UIElements 的事件模型，有 `Target`、`CurrentTarget`、冒泡/捕获、默认动作、事件池、调试器和指定帧派发。
- 用户提到的“自动指定 target”来自 `EventDispatcher`：如果事件没有传播路径，它会把 target 补成 coordinator 的回调处理器；有传播路径时则按路径设置 target/currentTarget。

为什么暂不搬：

- FantasyWord 已经明确选择 Yoki `EventKit.Type + GameRuntimeEvents`。当前事件多数是领域广播，不需要 UIElements 风格的树形传播和默认动作。
- Chris EventSystem 能力更强，但概念更重。把它用于所有领域事件，会让简单事件也承担 target/传播/池化/默认动作语义。
- Yoki EventKit 有运行时监控和代码扫描，已和项目事件入口绑定。

可吸收的点：

- 事件调试视图、事件记录/重放、指定帧派发可以作为 Yoki EventKit 的增强方向。
- 如果后续 UI、交互目标、技能命中链需要“事件沿对象链传播”，可局部引入 target 语义，不替换全局事件总线。

触发条件：

- 出现明确的层级事件需求：例如目标对象先处理，父级区域再处理，全局系统最后处理。
- 需要默认动作、阻止传播、事件重放或跨帧事件排队。

### Configs

Chris 价值：

- `Config<T>`、多 provider、Streaming/Persistent 合并、ConsoleVariable 都成熟。

为什么暂不搬：

- 项目已有 `GameConfig`、Unity ProjectSettings、ScriptableObject 数据资产和 SaveKit/项目存档。
- 为了 Mod 配置引入整套 Config 框架会扩大依赖，还会和现有配置来源并列。

可吸收的点：

- `ConsoleVariable` 适合未来调试控制台。
- Streaming 默认配置 + Persistent 覆盖配置的模式可用于玩家设置。

触发条件：

- 玩家设置、开发者调试变量、Mod 全局配置开始变多，并且需要运行时修改与持久化。

### Tasks

Chris 价值：

- 有前置依赖、状态、事件完成通知和池化任务，适合复杂异步流程编排。

为什么暂不搬：

- 当前项目有 UniTask、系统生命周期、任务/剧情/条件各自模型，暂时不缺通用 TaskRunner。
- 引入后容易把剧情任务、异步任务、AI 行为任务混成一套抽象。

可吸收的点：

- “前置依赖 + 完成事件 + 可取消状态”的任务图思想，可用于剧情/制作/建造等确实需要流程编排的系统。

触发条件：

- 游戏内长期行为需要可暂停、可恢复、可存档的任务编排。
- 普通 UniTask 已经无法表达依赖和状态。

### Ceres / Flow 热更新链

Chris 价值：

- Actor 与 FlowGraph、DataTable、Addressables 结合，可以实现外部更新行为图。

为什么暂不搬：

- 当前项目没有决定引入 Ceres。
- 行为热更新会直接影响 Mod 安全边界、调试方式、存档兼容和平台限制。

建议：

- 先只支持资源和数据 Mod。
- 行为 Mod 等脚本安全方案明确后，再评估 Lua、C# 热更、可视化脚本或受限 DSL。

## 重构优先级

1. 先把已搬入的 `ResourceSystem` 和 `ModAPI` 接成最小 Mod smoke：空目录、zip 解包、禁用状态、版本不匹配、加载 catalog 失败日志。
2. 设计 FantasyWord Mod 数据合同：物品、配方、任务、怪物、地图、音频、Sprite/Prefab 的稳定 ID 和冲突策略。
3. 需要外部数据新增时，再吸收 Chris DataDriven 的表格/行模型。
4. 需要大量运行时实体查询时，再做项目侧 `WorldRuntimeContext`，只吸收 `ActorHandle` 和 `WorldSubsystem` 思想，不改现有实体继承。
5. 需要层级事件、事件重放或跨帧派发时，再增强 Yoki EventKit，不切换到 Chris EventSystem。

## 最终判断

Chris 更适合补 FantasyWord 的 Mod 和外部资源能力，不适合直接替换当前项目底座。它强在“外部内容包 + Addressables + 可选热更新工作流”，YokiFrame 和当前 GameCore 强在“项目已接入、工具层轻、事件/存档/UI 已经有正式调用点”。当前最稳的路线是：

保留当前项目主线，吸收 Chris 的资源和 Mod 能力；其他模块只在触发条件出现时按职责拆出来吸收。
