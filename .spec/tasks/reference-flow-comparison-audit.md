---
status: active
owner: main
---

# 参考流程对照审计表

## 目的

本表用于把 `2DRPGEngine` 的同职责流程和 FantasyWord 当前流程逐项摆在一起，再判断哪些差异是合理增强、当前项目必要适配、真实退步或仍待复核。

它不是代码修复清单，也不是“看到一个问题就改一个”的流水账。任何后续重构都必须先在本表补齐对照，再进入代码修改。

## 判定标准

每条流程都按同一组字段比较：

| 字段 | 要回答的问题 |
|------|--------------|
| 参考入口 | `2DRPGEngine` 中谁触发该流程。 |
| 参考 owner | 哪个对象拥有真实状态。 |
| 参考系统访问 | 参考是直读 `GameManager.Xxx`、角色对象、资产字段，还是其它入口。 |
| 参考失败语义 | 缺目标、缺配置、无资源时是暴露错误、自然失败，还是允许无效果。 |
| 参考保存/刷新 | 状态改变后在哪里刷新属性、背包、任务、地图或存档。 |
| FantasyWord 当前入口 | 当前项目对应入口。 |
| FantasyWord 差异 | 当前项目多了什么 owner、上下文、稳定 ID、异步、保存或表现约束。 |
| 判定 | 参考一致 / 必要适配 / 当前退步 / 待复核。 |
| 错误点 | 只有判为当前退步时才写；不得用“单例”“Try 查询”“DI”这类形式词作理由。 |
| 状态 | 已修 / 不改 / 待查。 |

## 当前业务证据分拣

本轮重整后，参考工程业务不能只因为代码存在就算 FantasyWord 当前业务。当前按“场景、Prefab、资产、菜单入口、正式调用链”分三类：

| 链路 | 当前证据 | 本轮口径 |
|------|----------|----------|
| 装备穿脱、初始装备、死亡装备转尸体 | `0_CharacterActor_Base.prefab` 挂 `CharacterEquipment` 和 `CharacterActor`，并配置基础布衣、长矛两个正式装备资产。 | 当前业务链路；允许保留库存/装备结果合同。 |
| 击杀奖励库存提交 | `CharacterActor.Kill -> GrantKillRewards -> InventorySystem.ExecuteLootReward` 是正式角色代码；但当前玩家配置 `m_potentialLoot: []`，样本内容未配置真实掉落。 | 当前框架链路；只能称为“奖励库存提交合同”，不能称为已有掉落玩法完成。 |
| 商店交易 | `User Interface.prefab` 登记 `UIShop`，`UIShop.prefab` 存在；但未找到 `Shop` 资产或 `OpenShopMenu` 命令资产引用。 | UI/代码框架链路；保留交易顺序合同，不宣称已有正式商店内容。 |
| 制作交易 | `User Interface.prefab` 登记 `UICraft`，`UICraft.prefab` 存在；但 `GameConfig.m_onTheGoCraftingStation` 为空，未找到 `CraftingStation` 或 `Recipe` 资产引用。 | UI/代码框架链路；保留制作顺序合同，不宣称已有正式制作内容。 |
| 宝箱首次掉落初始化 | `Chest` / `ChestLoot` 正式代码存在；未找到 `Chest` 脚本 GUID 的场景、Prefab 或资产引用。 | 未接入内容链；可作为框架合同保留，但不得当作当前场景业务成果。 |
| 拾取物、消耗品效果、物品效果派生类 | 代码存在；本轮未找到正式 `ItemPickable`、`MoneyPickable`、`PickableItem`、`Item` 资产或物品效果派生类的资产引用。 | 待接入/待复核；不新增内容结论。 |
| 旅店 / `InnInteraction` | `InnInteraction` 与 `Inn` 只在代码中存在，未找到场景、Prefab 或资产正式引用。 | 参考遗留；不纳入当前业务重构，不建决策或门禁。 |

## 框架级差异分拣（2026-07-17）

这轮重审对象不是单个“旅店”或单个库存补丁，而是当前 `Assets/Scripts/GameCore/Runtime` 相对 `C:\Gamedev\Unity\Engine\2DRPGEngine\Assets\Mythril2D\Core\Runtime\Scripts` 的整体框架差异。

本轮只把已经读过同职责参考和当前源码的项写入表格；未读完的额外文件继续留在 `待复核`，不得直接加入允许列表。

| 框架链路 | 参考流程 | FantasyWord 当前流程 | 判定 | 后续动作 |
|------|----------|----------------------|------|----------|
| 系统宿主与生命周期 | `GameManager` 持有 `AGameSystem` 字典，通过 `NotificationSystem` 监听地图/存档生命周期，再逐个调用 `OnMapLoaded` / `OnSaveFileLoaded` 等钩子。 | 继续保留 `GameManager + AGameSystem`，但把旧通知中心替换为 `GameRuntimeEvents + EventKit.Type`；`AGameSystem` 钩子仍由 `GameManager.LifecycleRuntime` 分发。 | 必要适配。保留参考的系统生命周期内核，只替换事件派发机制。 | 不回退 `NotificationSystem`；参考一致性脚本应把 `GameRuntimeEvents` 视为已裁决适配，而不是未解释 extra。 |
| 系统自举与存档对象扫描 | 参考 `GameManager.FindSystems()` 在启动时扫描当前场景里的 `AGameSystem`，`PersistenceSystem` 在保存/地图生命周期里扫描 `Persistable` 来建立正式存档快照。 | 当前保留同职责扫描：`GameManager` 只收集项目级正式系统并在重复系统时抛出可定位异常；`PersistenceSystem` 继续扫描 `Persistable` 组装保存/卸载状态；`FormalSceneSingletonConflictDiagnostics` 用 `FindObjectsByType` 只做 EventSystem/AudioListener 数量诊断，不把结果当依赖注入或兜底配置。 | 参考一致 / 必要诊断适配。这里的扫描是自举、存档索引或错误取证，不是缺引用时随便找一个对象继续跑。 | 保留；门禁应继续禁止 UI、音频、换装、命令等正式依赖链使用全局查找兜底，但不能把 `GameManager` 系统收集、`PersistenceSystem` 存档扫描和诊断取证误判成同类问题。 |
| 地图、检查点与传送 | 参考 `MapSystem` 持有当前地图名和检查点栈，可直接加载/卸载或委托过场；玩家目标固定为 `GameManager.Player`。 | `MapSystem` 增加场景 `MapInfo` 登记、初始/Playtest 出生点、检查点顺序、重生延迟、主穿越角色和过场系统必需校验。 | 必要适配。地图真相仍在 `MapSystem`，增强来自当前项目的地图配置、出生点和多角色边界。 | 保留；但不得把“当前控制对象穿越”“实例宿主”“出生点分流”提前写进运行时，仍等 2D/场景组织参考补齐。 |
| 地形导航与元素地表反应 | 参考工程没有同职责地形元素系统；可继承的内核只有 `MapSystem` 拥有当前地图生命周期，规则数据由数据库/地图对象显式持有，表现层不反向拥有世界规则。 | 当前由 `TerrainNavigationTile` / `TerrainNavigationLayerSource` / `TerrainSurfaceLayerSource` 提供作者规则与地表语义，`TerrainNavigationMap` 持有地图实例导航图和地表运行时状态，`ElementReactionSystem` 从 `DatabaseRegistry` 读取 `ElementReactionDefinition` / `TerrainElementStateDefinition` 后执行元素规则，`TerrainSurfaceDamageSystem` 只消费燃烧状态施加接触伤害，`TerrainSurfacePresentation` 只订阅格子状态变化并刷新临时 Tile 或覆盖层透明度；`TerrainNavigationRuntimePathDebugView` 与 `TerrainNavigationMapEditor` 只消费导航结果做运行时/编辑器预览。 | 必要新增能力闭包。它不是从参考偏离出来的退步，也不能因为参考没有就删除；当前 owner 切分符合“地图实例状态、数据库规则、表现刷新”分层。 | 允许把已读地形/元素 extra 登记进参考一致性脚本；但持久地貌变更仍必须另走世界地形变更链，不能由临时运行时状态、路径调试对象或表现层透明度冒充。 |
| 玩家与输入目标 | 参考 `PlayerSystem` 运行时实例化唯一 `Hero`，`PlayerController` 直接驱动玩家。 | 当前改为预摆主玩家、`PlayerSystem` 持有主玩家长期真相、当前输入目标和控制组；`CharacterPlayerControl` / `PlayerControlGroup` 实现 `IPlayerInputTarget`。 | 必要适配，但仍是阶段性控制链。它服务多角色/指挥目标，不等于完整队伍系统完成。 | 需要补登记：`PlayerCommandRequest`、`PlayerOrderRequest`、`PlayerControlGroup` 是当前项目订单链，不属于 2DRPG 原版；参考一致性脚本不能长期把它们列为未解释 extra。 |
| 玩家命令与订单 | 参考输入控制器直接调用玩家移动、交互、能力和菜单入口。 | `InputSystem` 只生成 `PlayerCommandRequest`，`PlayerSystem.SubmitPlayerCommand/SubmitPlayerOrder` 再分发给单角色或控制组。 | 必要适配。它符合“输入只产生意图、世界/角色 owner 执行”的项目目标。 | 保留；但当前 2D 导航 Provider 仍未完整闭合，不能把点击移动链称为完整寻路系统。 |
| AI 控制与 ContextSteering2D 适配 | 参考 `AIController` 自己持有追敌目标、冷却、归位点和存档块，在 `FixedUpdate` 搜敌、追击、攻击并直接写 `CharacterBase.SetMovementDirection`；局部避障八方向评分也写在同一个控制器里。 | 当前 `AIController` 仍持有目标、冷却、归位点、攻击触发和保存块；`BehaviourRuntime` 只把原本内联的转向/避障求解委托给 `CharacterSteeringRuntime2D`，`CharacterSteeringPathCursor2D` 只保存 AI 追踪路径点进度；玩家点击移动仍走 `PlayerSystem -> IPlayerInputTarget/CharacterCommandExecutor -> CharacterMovement`。 | 必要适配。它不是新增玩家控制主链，也不是因为“插件更高级”而替换规则 owner；它保留参考的 AI 控制 owner，只把当前项目需要的 2D 地形导航和 ContextSteering2D 求解接进 AI 内部执行链。 | 允许登记 `CharacterSteeringRuntime2D` 与 `CharacterSteeringPathCursor2D`；但 ContextSteering 编辑器窗口、ClickMoveTest 验证器和性能 benchmark 仍需按“验证/调试工具层”单独审，不随本行一并放行。 |
| 角色闭包拆分 | 参考 `CharacterBase` 持有移动、属性、能力、持续效果；`Hero` 追加经验、装备、快捷能力槽；`Monster` 追加掉落和死亡奖励。 | 当前 `CharacterActor` 统一可成长、可装备、可奖励、可保存角色；`CharacterAbilitySet` 拥有 Formal GAS 能力实例和槽位；`CharacterEquipment` 拥有装备槽和装备属性/能力来源；`CharacterMovement` 和 `CharacterCommandExecutor` 只把玩家订单转成角色动作；`CharacterInventory` 只解析背包 owner；`CharacterHandleWeapon` 只提供武器/投射物挂点。 | 必要适配。当前项目需要玩家、NPC、敌人、队伍控制和尸体/容器 owner 共用同一角色闭包；这些组件拆分后仍没有第二个属性、装备或库存真相。 | 允许登记这些角色闭包 extra；继续检查 `CharacterBase` 旧属性/持续效果残留是否与 EX-GAS 双轨。 |
| 角色交互激活组件 | 参考 `PlayerController` 直接在输入响应里找交互对象并调用 `IInteractionTarget.OnInteract`，交互规则仍由目标对象和命令/对话系统承载。 | 当前 `CharacterButtonActivation` 只负责角色侧交互目标探测、方向过滤、交互音效请求和 `IInteractionReceiver.OnInteract` 分发；玩家命令仍由 `CharacterCommandExecutor` 执行，交互目标规则仍在目标对象和 `Interaction`/`Command` 闭包。 | 必要组件化适配。它把交互激活从玩家控制器拆到 prefab 可见角色组件，符合 TopDown 动作组件边界，但不引入 TopDown `ButtonActivated` 状态机或第二套交互真相。 | 允许登记 `CharacterButtonActivation`；后续交互距离、交互 UI 提示和移动靠近交互仍按 3C/交互专项验收，不因本文件存在就宣称完整。 |
| 通用角色任务与刷出器 | 参考 `KillMonsterTask` 监听怪物击杀事件并统计 `MonsterSheet`，`TalkToNPCTask` 保存 `NPCSheet + DialogueSequence`，`AMonsterSpawner/MonsterSpawner/MonsterAreaSpawner` 只实例化 `Monster` 并保存怪物运行时块。 | 当前把同一职责泛化为 `KillCharacterTask`、`TalkToCharacterTask` 和 `ACharacterSpawner/CharacterSpawner/CharacterAreaSpawner`：目标数据从 `MonsterSheet/NPCSheet` 改为 `CharacterSheet`，刷出对象从 `Monster` 改为 `CharacterActor`，死亡/任务事件通过 `CharacterKilledEvent` 和角色运行时状态保存；旧字段用 `FormerlySerializedAs` 迁移。 | 必要适配。它跟上一行的通用角色闭包一致，目的是让玩家、NPC、敌人和后续队伍角色共享同一角色资产/运行时状态，而不是搬入新业务。 | 允许登记已读的通用角色任务和刷出器 extra；但真实刷出内容是否接入场景仍要按场景/Prefab 证据另验，不能因为代码存在就宣称已有刷怪玩法完成。 |
| 资源与 Mod 工具层 | 2DRPG 官方内容使用数据库条目、Unity 序列化引用和存档数据库引用，不使用 Addressables/Mod catalog 作为官方数据真相。 | `ResourceSystem` / `ResourceHandle` / `ResourceCache` / `SoftAssetReference` 只管理 Addressables 地址、异步句柄、缓存和释放；`ModAPI` / `ModConfig` / `ModLoader` / `ModInfo` / `ModState` / `ModValidator` / `ZipArchiveExtractor` 只负责外部内容包发现、启停/删除状态、版本校验、解压和 catalog 加载；官方内容 owner 仍是 `DatabaseRegistry` / 稳定引用。 | 必要适配，前提是继续守住“工具层不接管官方资源身份”。 | 保留 `0002` 决策；允许登记已读资源/Mod 工具文件；继续让资源门禁阻止正式 GameCore 运行时代码绕过数据库直接依赖 ResourceSystem/FWRes。 |
| 正式资源路径、Yoki 和生成场景 key | 参考运行时资源主链用 `DatabaseEntryReference<T>`、`PrefabReference` 和序列化 `SpriteLibraryAsset`；编辑器可用 `AssetDatabase` 查询资产；主菜单加载和引擎场景名是配置/常量，不是 Addressables/Yoki 资源身份。 | 当前 EX-GAS Prefab/Icon 已改为 `PrefabGuid/IconGuid` 指向 `DatabaseRegistry`，`PrefabPath/IconPath` 只允许为空或后续 Addressables 地址；严格资源门禁显示 EX-GAS 源表和生成 JSON 的 `Assets/...` 债务为 0。`FormalGasAbilityResourceLoader.LoadRuntimeAddressSync` 会拒绝 `Assets/` 项目路径；`GameConfig.DefaultAssetPath` 与 `AssetDatabase.LoadAssetAtPath` 只在 `UNITY_EDITOR` 兜底/验证中使用；`FWRes` 为空，`FWScene.SampleScene` 虽生成了 1 个编辑器场景路径，但当前未被正式运行时代码调用。 | 必要适配 / 不改。当前没有证据表明官方资源身份被 Yoki/FWRes/FWScene 接管；把序列化引用或数据库 GUID 改成字符串 key 会比参考更差。 | 继续保留资源 owner 门禁的 `FWScene` 警告；若后续正式场景加载开始依赖 `FWScene` 且仍没有 Addressables/YooAsset 配置，才升级为资源 owner 问题。 |
| 框架常量和场景名 | 参考 `Constants` 持有引擎场景名 `M2DEngine`、主玩家持久化标识 `player`、等级范围、技能槽上限、碰撞偏移和默认音量；`GameConfig.mainMenuSceneName` 持有主菜单场景名。 | 当前保留这些同职责常量，并把主菜单场景名迁到 `GameConfig` 私有序列化字段兼容旧名；能力槽上限、等级范围、移动到达距离和主玩家稳定标识仍作为框架基线使用。 | 参考一致 / 不改。它们是框架合同或存档身份常量，不是资源路径硬编码；在没有多主玩家存档或可配置等级上限需求前，不应为了“看起来数据化”拆成第二套配置。 | 若后续要支持多个本地玩家、不同模式等级上限或可变技能槽，再按业务需求新建迁移决策；本轮不把参考同构常量列为退步。 |
| 数据库资源引用与装备表现桥 | 参考用 `PrefabReference` 把可实例化资源作为数据库条目保存，装备数据直接保存 `SpriteLibraryAsset visualOverride`。 | 当前 `SpriteReference` 是同类数据库条目，用于 EX-GAS 图标 GUID；`EquipmentVisualAsset` 是 GameCore 内的抽象表现引用，正式装备只持有类型安全的表现资产基类，具体 `EquipmentRenderData` 留在表现系统实现。 | 必要适配。资源身份仍走 `DatabaseRegistry` 稳定 GUID，装备规则不反向依赖具体换装渲染类；这比把运行时路径、Addressables key 或表现实现类直接塞进装备规则更稳。 | 允许登记 `SpriteReference` 与 `EquipmentVisualAsset`；继续由资源门禁保证官方 EX-GAS 图标/Prefab GUID 能解析到正式数据库条目。 |
| 装备视觉覆盖方式 | 参考 `EquipmentSpriteLibraryUpdater` 在攻击开始/结束时临时替换整套 `SpriteLibraryAsset`。 | 当前正式装备表现由 `CharacterEquipmentPresentation -> EquipmentRenderer` 和换装表现系统承担，规则层只持有 `EquipmentVisualAsset` 抽象引用；整套 SpriteLibrary 覆盖只作为参考能力和基础形态替换思路，不作为局部装备主链。 | 必要适配。参考视觉覆盖不能表达当前衣服、裤子、武器遮挡、UV 局部层和逐帧挂点，不应补回运行时主链。 | 排除参考 `EquipmentSpriteLibraryUpdater` 缺失；若后续做整套皮肤/形态替换，可另建清晰边界，不接回装备规则 owner。 |
| 换装生成设置与静态门禁 | 参考 Editor 工具可用 `AssetDatabase` 查询资产，但资源生产规则不应由多个工具各自维护一份路径真相；运行时仍靠序列化引用和数据库身份。 | 当前生成器已经把动画根目录、共享片段目录、方向库目录、Controller 文件和工作台目录收口到 `EquipmentSystemGenerationSettings`；旧 `Invoke-EquipmentSystemStaticGate.ps1` 曾手写同一套动画路径、目录名和 Controller 路径。 | 当前退步已修。它不是运行时资源硬编码；修复点是让生成器和门禁共享同一个生成设置 owner，避免“生成器按设置通过、门禁按旧路径失败/漏检”。 | 已修：静态门禁读取 `Assets/GameData/EquipmentSystem/Data/Workbench/换装动画生成设置.asset`，解析动画根、共享片段目录、方向库目录、Controller 和工作台目录；读不到设置资产时报告配置缺失。见 0067。 |
| 剩余命令假成功候选 | 参考命令系统本身是 `ICommand.Execute()` 无返回结果；命令对象作为交互、对话、任务、物品等作者数据的一部分被序列化引用。是否判错取决于具体命令是否承担正式结果写入，以及缺配置/写入失败是否会被当成成功。 | 当前已修的玩家结果、显式目标、地图、任务、库存、持久化、控制目标、交易、奖励、装备、能力持续效果等结果链分别见 0051-0066。2026-07-17 对 `Assets/Scripts/GameCore/Runtime/Commands` 全部脚本做 GUID 引用矩阵，`Assets/GameData`、`Assets/Prefabs`、`Assets/Scenes`、`Assets/Resources` 中命令脚本引用数均为 0；`CompleteTask`、`SetGameFlag`、`AddOrRemoveMoney` 等剩余样本与参考同构，当前没有正式资产命中它们。 | 不改 / 继续观察。不能因为 `Task.CompletedTask`、`Debug.Assert` 或 `return` 文本存在就继续改；也不能把没有正式资产引用的命令当成当前业务 bug。 | 若后续新增正式命令资产，必须先用命令 GUID 矩阵锁定具体资产，再按“参考入口、owner、失败语义、当前差异”补本表；没有资产证据时只保留为候选。 |
| 当前运行时状态保存的数据库引用 | 参考保存链在 `InventorySystem.CreateDataBlock`、`JournalSystem.CreateDataBlock`、`Hero.OnSave` 和 `QuestProgress.CreateDataBlock` 中直接调用 `GameManager.Database.CreateReference(...)`；数据库条目缺登记是作者数据/运行时状态错误，不是保存时可跳过的普通坏档输入。读档时从旧档加载坏 GUID 可以失败或暴露错误，但保存当前状态不应静默丢数据。 | 当前 `LoadDataBlock` 里跳过坏存档记录是必要容错；旧 `InventorySystem.CreateDataBlock`、`JournalSystem.CreateDataBlock`、`QuestProgress.CreateDataBlock`、`QuestTaskProgress.CreateDataBlock`、`CharacterEquippedItemLoadout.CreateSlotDataSnapshot` 和 `CharacterBase.CreateActiveAlterationRuleSnapshots` 曾在保存当前运行时状态时复用 `TryCreateReference + continue` 或过滤语义，会把未登记物品、任务、装备或变形规则从存档里静默丢掉。 | 当前退步已修。坏档输入容错不能复用到正式保存输出；保存当前运行时状态必须要么完整创建稳定数据库引用，要么失败暴露。 | 已修：`DatabaseRegistry.CreateReference<T>()` 缺登记时抛错；库存、任务日志、任务进度、任务子项、装备槽和活跃变形/感染规则保存都改为必需引用语义；读档路径继续保留坏 GUID 跳过/日志语义。见 0068。 |
| EX-GAS 主动能力规则桥 | 参考 `ActiveAbilityBase.Fire` 由旧 `AbilitySheet` 提供冷却、法力和动作锁，`MeleeAttackAbility` 触发 Animator、Collider2D 命中盒和 `EffectDispatcher.Apply`。 | 当前 `ActiveAbilityBase` 只保留本地输入门、缓冲、节奏和能力实例生命周期；`CharacterAbilitySet.FormalRules` 用 EX-GAS `AbilitySpec` 评估成本、冷却、标签和生命周期；`TimelineActiveAbility` 不再自己结算技能，只接 EX-GAS Timeline 执行配置。 | 必要适配。当前项目已裁决 EX-GAS 是属性/能力/效果规则主轴，这里是在替换旧 AbilitySheet 规则 owner，不是又造第二套规则。 | 允许登记 `TimelineActiveAbility`、`FormalAbilityInputGateRuntime/Settings`、`CharacterAbilitySet` Formal 规则桥和 `FormalAbilityRuntimeBootstrap`；但旧 `AEffect/TemporalEffect` 实现层仍是待清退项，不能因本行一起白名单。 |
| 旧 `AbilitySheet` 泛型能力壳 | 参考 `Ability<TSheet>`、`ActiveAbility<TSheet>`、`PassiveAbility<TSheet>` 把运行时能力实例绑定回旧能力表。 | 当前正式运行身份已由 `AbilityBase.InitFormalGasAbility(...)` 接收 EX-GAS Ability Code；`TimelineActiveAbility` 和 `MeleeAttackAbility` 直接继承 `ActiveAbilityBase`，全仓没有资产或 C# 类型再引用 `Ability`、`ActiveAbility`、`PassiveAbility`、`PassiveAbilityBase` 四个薄壳。 | 当前退步已修。保留空壳会让旧 AbilitySheet 入口继续像正式架构；删除比白名单更干净。 | 已删除四个空壳及 meta；参考一致性脚本把这些参考旧入口排除为 EX-GAS 替代，不再生成 FantasyWord 空包装类型。 |
| 旧技能表、旧具体技能和旧即时效果实现 | 参考 `AbilitySheet/ActiveAbilitySheet/PassiveAbilitySheet`、冲刺/投射物/召唤/接触伤害/周期能力、`EffectDispatcher`、`ObservableStats` 和即时伤害/治疗/回蓝效果共同构成旧技能效果主链。 | 当前正式技能身份、消耗、冷却、命中、伤害和表现已经由 EX-GAS Ability / Timeline / GameplayEffect / Cue、`CharacterAbilitySet`、`FormalGameplayEffectDamageBridge` 和 GameCore 角色 owner 承担；全仓搜索未发现这些旧具体类的正式资产或 C# 引用。 | 当前退步已修 / 必要清退。缺失这些文件是为了避免旧 AbilitySheet 与 EX-GAS 争夺同一技能真相，不是参考同步漏文件。 | 排除参考旧技能表、旧具体技能、`EffectDispatcher`、`ObservableStats`、即时效果和 `ApplyEffectsToPlayer` 缺失；后续新增冲刺/投射物/召唤必须走 EX-GAS 表和当前表现桥，不恢复旧能力族。 |
| EX-GAS 2D 目标捕获与正式伤害桥 | 参考近战命中通过 Ability 私有 Collider2D 收集 `CharacterBase`，再把旧 `IEffect` 列表逐个应用到目标。 | 当前 `Gas2DTargetCatchers` 把 EX-GAS TargetCatcher 转成 2D Physics 查询并返回 `AbilitySystemCell`；`FormalGameplayEffectDamageBridge/System/Helper` 把 EX-GAS GameplayEffect 载荷接回 `DamageSolver` 和 `CharacterBase.Damage`；`TaskApplyWorldElement` 只把 Timeline 参数提交给 `ElementReactionSystem`。 | 必要适配。命中时序、目标捕获和效果载荷进入 EX-GAS 主轴，角色伤害和地表状态仍回到 GameCore 正式 owner。 | 允许登记已读桥接文件；`ElementReactionSystem`、地形导航和持续效果存档仍需单独审，不用本行替它们背书。 |
| EX-GAS 数据解析、资源配置和技能槽 | 参考 `AbilitySheet` 资产直接持有名称、描述、图标、Prefab/能力类、冷却和法力等配置，玩家能力槽保存 Ability 资产/实例。 | 当前 EX-GAS 能力身份、运行时 Prefab/Icon、伤害描述和 Timeline 节奏由 Luban/EX-GAS 生成代码注册解析器；`CharacterEquippedAbilityLoadout` 只保存 Formal GAS ability code 槽位；`AbilityRuntimeExtraState` 只保存无法从配置重建的最小能力私有状态；`FormalAbilitySystemAttributeExtensions` 是对 EX-GAS 当前值写入缺口的项目侧适配；原 `FormalGasAbilityCodes` 手写快捷常量已删除，编辑器验证和 smoke 改为直接引用 `GAS.Runtime.XAbility` 生成常量。 | 必要适配。它把参考的 AbilitySheet 作者数据拆到 EX-GAS 表、GameCore 数据库引用和角色槽位 owner，不是运行时路径硬编码。 | 允许登记解析器、技能槽和 extra state 文件；后续新增核心能力编号必须来自 EX-GAS 生成代码或生成的 GameCore 访问入口，不得恢复手写编号表。 |
| Formal GAS 能力授予/替换/压制持续效果 | 参考旧效果系统可以用 `TemporalEffect` 持有持续状态并按 tick 更新，装备和状态可以改变角色能力集合。 | 当前 `TemporalAbilityGrant/Replacement/SuppressionEffect` 仍挂在旧 `ATemporalEffect` 生命周期上，但写入目标是 `CharacterAbilitySet` 的 Formal GAS ability source / suppression source，结束或读档恢复都按来源键撤销或重建。 | 迁移期必要壳，但不是最终干净架构。能力真相已回到 Formal GAS 编码和 `CharacterAbilitySet`，旧 `ATemporalEffect` 仍是待清退基础类。 | 允许登记三类 Formal 能力持续效果和共享 support；继续保留旧效果残留待审，不得新增同职责旧 `IEffect` 规则。 |
| 旧规则型持续效果残留 | 参考 `EffectDispatcher.Apply` 把 `IEffect[]` 作为技能、投射物和命令的正式效果链，`TemporalDamage/Heal/RestoreMana/StatModifier/SpeedModifier/ControlEffect` 可直接改角色生命、法力、属性、移速和动作锁。 | 当前旧 `EffectDispatcher`、旧即时效果和旧具体 AbilitySheet 已清退；主动能力和伤害已转到 EX-GAS `GameplayEffect/Timeline/FormalGameplayEffectDamageBridge`。代码中仍存在旧规则型持续效果类和 `CharacterTemporalEffectRuntimeStateData.effectTypeName` 反射恢复入口，但资产搜索未发现正式资产、Prefab、场景或动画资产引用这些旧规则型效果。 | 迁移期兼容壳需收窄。不能直接删除整条 `ITemporalEffect`，因为存档恢复、UI 展示快照、Cleanse 以及三类 Formal 能力持续壳仍依赖它；但旧伤害/治疗/回蓝/属性/速度/控制效果不得再成为正式作者入口。 | 已新增 `0062` 决策和能力门禁：正式资产不得引用旧规则型持续效果；后续若要持续伤害、治疗、回蓝、属性修饰、速度或控制，必须走 EX-GAS GameplayEffect/Timeline 或新裁决的正式状态规则，不恢复旧 `IEffect` 主链。 |
| 角色变化规则与激活状态 | 参考没有独立变形/感染规则资产；相近职责是 `ITemporalEffect` 列表改变属性、速度、治疗/伤害或能力，持续效果保存在角色运行时并由 UI/通知消费。 | 当前 `CharacterAlterationRule` 是变形/感染/失控等长期状态规则资产，按数据库稳定引用生成来源键；能力授予/压制写入 `CharacterAbilitySet` 的来源桶，动作锁、玩家控制锁、AI 接管、装备效果压制和阵营覆盖写回 `CharacterBase.StateApi`；存档时 `activeAlterationRules` 只恢复非能力状态，能力来源与压制仍由通用 `abilitySources/abilitySuppressions` 恢复，避免读档双重叠加。 | 必要新增能力闭包，但不是完整变形/感染玩法完成。它服务当前项目复杂角色状态目标，并且没有建立第二套能力真相；核心合同已补测试，不再只靠静态 pattern 门禁背书。 | 已补合同测试：`CharacterAlterationRuleRuntimeLoad_RestoresNonAbilityStateAndCanRevoke` 覆盖非能力状态保存、读档恢复和撤回；`CharacterAlterationRuleRuntimeLoad_DoesNotDuplicateAbilitySourceAndCanRevoke` 覆盖能力来源读档不重复、非能力状态恢复和撤回。2026-07-17 通过 AIBridge EditMode 运行，二者均进入 Test Runner 且 Passed。 |
| EX-GAS Cue 到 GameCore 表现桥 | 参考能力直接触发 Animator、音效字段或反馈表现；TopDown 的强项是动作/武器/命中/受击反馈触点，但不能把 TopDown manager 或 EX-GAS 内置通用 Cue 变成项目真相。 | 当前 `CuePlayGameCoreAnimator` 只解析目标对象树的 `ICharacterAnimationDriver`，`CuePlayGameCoreAudio` 只把 `AudioResolverGuid` 解析到 `AudioClipResolver` 并请求 `AudioSystem`，`CuePlayGameCoreFeedback` 只把 Cue kind 交给角色 `GameplayFeedbackSet`；`FlamethrowerCueVisual` 只是挂载 Prefab 的视觉组件，读取父级 `Movable` 朝向播放序列帧，不参与命中或地表结算。 | 必要桥接。它把 EX-GAS 时间轴、GameCore 音频/反馈/动画 owner 和具体表现资产隔开，避免技能资产重新持有 Animator 路径、音频路径或 MMFeedbacks 真相。 | 允许登记 `CuePlayGameCoreAnimator`、`CuePlayGameCoreAudio`、`CuePlayGameCoreFeedback`、`ICharacterAnimationDriver`、`FlamethrowerCueVisual`；继续用 Formal GAS/插件边界门禁防止 AnimatorNodePath、内置 Cue 或散落 MMFeedbacks 回流。 |
| Formal GameplayTag 到 GameCore 动作锁桥 | 参考没有 EX-GAS tag；旧动作锁来自能力/效果直接写角色状态。 | 当前 `FormalGameplayTagCatalog` 是 EX-GAS tag 到 `CharacterBase.Can/IsActionLocked` 的窄桥：攻击标签来自 EX-GAS 生成的 `Event.Attacking`，但 GameCore 不直接编译引用 `GAS.Runtime.XTag`，而是通过生成符号反射读取，避免生成程序集与 GameCore asmdef 形成循环依赖；控制类 tag 尚未在 EX-GAS 表中生成，因此保持 `0` 且运行时不会查询 `0` 标签。 | 必要适配，但不是新身份 owner。它把 Formal GAS 的激活标签投影到 GameCore 动作许可，不让旧效果壳长期镜像动作锁；未生成标签只能保持未接通，不能手填编号假装完成。 | 允许登记 `FormalGameplayTagCatalog`；后续新增控制 tag 必须由 EX-GAS 表/生成代码提供，并补动作锁合同测试；门禁必须阻止 GameCore 重新直接引用生成 `XTag`。 |
| 物品使用效果与来源 owner | 参考 `IItemEffect.TryUse(item, target, location)` 面向唯一玩家背包；`ItemAddAbilityEffect` 持有旧 `AbilitySheet`，`ItemStartQuestEffect` 直接 `StartQuest`。 | 当前 `IItemEffect/AItemEffect` 增加 `sourceOwner`，成功后从来源 owner 扣物品；`ItemAddAbilityEffect` 改为 Formal GAS Ability Code 并用物品数据库 GUID 做能力来源；`ItemStartQuestEffect` 把 source/target 转成 `GameCommandContext`；`ItemCleanseEffect` 只是跟随签名变化。 | 必要适配。它保留参考“效果成功才扣物品/反馈”的流程，同时适配多 owner 背包、EX-GAS 能力身份和任务上下文。 | 允许登记 `IItemEffect`、`ItemAddAbilityEffect`、`ItemCleanseEffect`、`ItemStartQuestEffect`；没有正式 Item 资产引用时不宣称已有消耗品内容完成。 |
| 旧玩家/怪物/NPC 继承闭包 | 参考以 `Character -> Hero/Monster/NPC`、`HeroSheet/MonsterSheet/NPCSheet`、`PlayerController`、`MonsterSpawner` 和怪物/NPC 专用任务作为正式分类。 | 当前以 `CharacterActor + CharacterSheet + CharacterEquipment/AbilitySet/Inventory` 统一角色 owner，玩家输入由 `PlayerSystem + IPlayerInputTarget/CharacterPlayerControl/PlayerControlGroup` 承担，怪物/NPC/玩家差异通过资产、AI、控制组和任务目标表达；UI 反馈也从 `UIPlayerControllerFeedback` 改为 `UIPlayerControlFeedback`。 | 必要适配。它减少旧继承分类和专用刷出/任务代码，不代表已完成所有刷怪/NPC 内容。 | 排除参考旧 `Hero/Monster/NPC`、旧专用 Sheet、旧 `PlayerController`、旧 Monster spawner/task 和旧玩家控制 UI 缺失；正式内容接入仍按场景、Prefab 和资产证据验收。 |
| ClickMoveTest 运行时诊断面板 | 参考没有同职责正式业务；相近职责是 Playtest/Editor 工具只服务验证流程，不拥有玩法状态。 | `ClickMoveTestControlPanel` 只被 `Assets/Scenes/ClickMoveTest.unity` 引用，用于显示当前点击移动模式、输入目标、最近点击和移动指令诊断；它读 `PlayerSystem/InputSystem` 状态但不持有玩家、输入、地图或订单真相。 | 验证/调试工具层必要适配。它不属于正式 GameCore 框架 owner，也不能当作点击移动业务完成证据。 | 允许登记为 runtime debug extra；若后续 ClickMoveTest 下线，应随测试场景迁移或删除，不进入正式 Prefab。 |
| Editor 验证、测试与作者工具层 | 参考 Editor 层主要提供数据库处理、文档窗口、属性绘制、Playtest 和 SceneUtil；它们只服务作者/验证流程，不拥有运行时世界状态。 | 当前新增 ClickMoveTest 验证桥、ContextSteering 调试/性能基准、EX-GAS 命中框 SceneView 辅助、统一 `CharacterSheet` 编辑器、正式能力资产验证和多组 EditMode 合同测试；这些工具只读当前场景/资产或写 `Temp` 验证结果，不替代 GameCore owner。 | 必要工具层适配。它们是当前项目新增框架的验证面和作者面，不是运行时业务 owner，也不能当作玩法完成证据。一次性场景迁移菜单不满足长期工具边界。 | 允许登记已审过的 Editor 验证/测试/工具 extra；已删除会保存场景的 `ClickMoveTestTerrainLayerMigration`，后续迁移必须进入明确任务脚本或专项流程。 |
| 旧 Editor 作者工具缺失 | 参考 `AbilitySheetEditor`、`HeroSheetEditor`、`MonsterSheetEditor`、`EditorPlayModeOverride` 和参考捕获桥服务旧数据/旧分类/旧 Playtest 流程。 | 当前正式作者面改为统一 `CharacterSheetEditor`、EX-GAS/Timeline/Cue 验证工具、当前场景验证桥和 `.spec` 文档证据；旧 AbilitySheet Inspector 和旧执行资产作者流已退出正式技能制作。 | 必要清退。补回旧编辑器会把已删除的 AbilitySheet/旧 Hero/Monster 分类重新变成作者入口。 | 排除这些参考 Editor 缺失；如果未来需要 Playtest override 或参考捕获，应按当前验证工具边界新建，不复活旧作者面。 |
| 命令上下文与异步执行 | 参考 `ICommand.Execute()` 已返回 `Task`，命令资产直接调用正式 owner；部分调用方仍同步丢弃任务。 | 当前保留命令资产驱动结果的内核，增加 `GameCommandContext`、`IContextualCommand`、显式后台执行异常上报、`UniTask.WaitForSeconds` 等异步合同；玩家结果命令、显式目标命令、地图命令和任务命令按参考同职责结果链收紧失败语义。 | 必要适配。差异不来自“更现代接口”，而是为了保留参考命令 owner 的同时支持当前项目的上下文来源、异步等待和可定位失败。 | 允许登记已由 0008、0024、0051、0052、0053、0054 覆盖的命令 patch；继续用命令门禁检查正式结果不得假成功、后台任务不得静默丢异常。 |
| 条件、交互与上下文命令 | 参考条件/交互多为单玩家语义，命令不携带执行者上下文。 | 条件和交互增加当前角色/owner 语义，命令升级为 `GameCommandContext`，但同职责分支、对话、宝箱、顺序交互仍和参考同构。 | 必要适配。已读到的 `ExecuteCommandIf`、`UnlockQuest`、`SetGameFlag`、`CommandInteraction`、`DialogueInteraction` 等没有新框架退步。 | 不按“和参考文本不一样”批量改；只查是否有正式结果被静默吞掉。 |
| UI 设置与按钮生命周期 | 参考 UI 按钮直接注册匿名回调。 | 当前保存 `UnityAction`，支持注销；菜单语义归 `UIManager + UIKit`，按钮只发布请求或调用正式 owner。 | 必要适配。它修的是生命周期和 UI owner，不是业务流程搬运。 | 可登记为允许 patch；继续禁止 UI 直接持有场景、背包、资源或存档真相。 |
| UI 展示组件与菜单只读条目 | 参考 UI 小组件直接显示图标、术语、能力、效果、事件日志、制作材料、装备槽和音量按钮。 | 当前同类组件仍只负责显示或按钮回调生命周期；能力显示从旧 `AbilitySheet` 变为 `CharacterEquippedAbilitySlotView`，效果显示从旧持续效果对象变为表现快照，制作材料和装备槽只读当前 owner/装备状态来刷新颜色和图标。 | 必要 UI 适配。它们不拥有库存、能力、效果、音频或存档真相；真实交易、能力、效果和音量改变仍由对应系统处理。 | 允许登记 UI 展示 patch；若 UI 条目开始直接写背包、存档、资源或正式能力状态，必须重新审计。 |
| 当前控制角色表现、相机和地表表现 | 参考相机/反馈较薄，TopDown 的相机目标、边界和动作 HUD 样板更强，但不能接管地图或输入生命周期。 | `PlayerCameraRig` 只从 `PlayerSystem` 取当前控制角色，从 `MapInfo` 取相机目标覆盖和地图边界，再写 Cinemachine；`UIPlayerControlFeedback` 只跟随当前控制角色的交互目标位置显示提示；`TerrainSpriteSheetAnimatedTile` 是 Tilemap 表现资产，只从纹理切序列帧，不拥有地形规则或地表状态。 | 必要表现层适配。它们分别服务相机、HUD 提示和地表动画表现，不改玩家、地图、交互或地表规则真相。 | 允许登记 `PlayerCameraRig`、`UIPlayerControlFeedback`、`TerrainSpriteSheetAnimatedTile`；不得把 ClickMoveTest 场景诊断 UI 也一起放行。 |
| 菜单上下文与菜单反馈文案 | 参考菜单默认围绕唯一玩家背包/角色；当前项目已区分当前控制角色、查看指定角色和来源/目标背包转移。 | `CharacterMenuContext` 与 `InventoryMenuContext` 只保存菜单打开上下文、命令来源和背包 owner handle，最终背包操作仍生成 `InventoryTransferRequest` 交给 `InventorySystem`；`IInventoryBagItemClickHandler` 只是子格子向父菜单回调点击；`MenuFeedbackPrompts` 只保存框架级菜单提示文本，不是任务/对话资产真相。 | 必要 UI 语义适配。它把菜单目标和转移目标显式化，避免 UI 子控件自己猜当前 Hero 或直接改库存。 | 允许登记这四个 UI helper；后续本地化/正式文案可另走文本系统，不能把这些英文 fallback 当最终剧情文本。 |
| 表现抖动与多方向 SpriteLibrary 策略 | 参考 `TransformShaker` 用 `GameManager.Instance` 承载局部抖动协程；`PolydirectionalAnimationStrategy` 按朝向切换 `SpriteLibraryAsset` 并可翻转 Sprite；控制器基础接口只负责初始化、启停、Update、Gizmos 和存档块。 | 当前 `TransformShaker` 改为由调用组件显式传入协程 owner；`PolydirectionalAnimationStrategy` 保持参考同构，只增加中文 Inspector 文案；`AController/IController` 保持同职责，只增加中文说明。 | 必要适配 / 参考一致。抖动协程 owner 是 0021 已裁决的生命周期修正；多方向策略和控制器基础合同不是新框架。 | 允许登记 `TransformShaker`、`PolydirectionalAnimationStrategy`、`AController`、`IController`；不得把它们升级成“需要替换动画/控制器架构”的证据。 |
| 数据库稳定身份与资产菜单分组 | 参考 `DatabaseEntry` 是数据库资产基类，`DatabaseEntryReference<T>` 在编辑器把资产引用同步为 GUID，运行时通过 GUID 解析；`AssetMenuIndexer` 只保存 `CreateAssetMenu` 分组常量。 | 当前保持同一身份流程，增加中文 Inspector/Tooltip，并按 0005 明确“运行时只依赖 GUID、编辑器引用只用于配置”；菜单品牌改为 FantasyWord 并增加 EX-GAS/Ability Execution 分组。 | 必要适配 / 参考一致。它强化了稳定身份说明，不引入运行时资源路径 owner。 | 允许登记 `DatabaseEntry`、`DatabaseEntryReference`、`AssetMenuIndexer`；资源路径问题继续由资源门禁检查。 |
| 命令资产内部命令 | 参考 `CommandHandler.Execute()` 直接执行序列化的内部命令，内部命令缺失会暴露配置错误。 | 当前保留命令资产 owner，并增加 `GameCommandContext`；内部命令为空时抛出可定位异常，不再把命令资产执行成成功无操作。 | 必要适配。差异来自 0052 的显式配置命令失败语义，不是因为 `Task` 或上下文形式本身更好。 | 允许登记 `Database\Utils\CommandHandler.cs`；继续由命令门禁保证缺内部命令不能静默成功。 |
| 掉落配置字段语义 | 参考 `Loot` 记录掉落条件、物品、数量、掉率、怪物等级和玩家等级。 | 当前 `Loot` 保留同一掉落配置职责，但把等级字段迁移为 defeated/receiver character level，并用 `FormerlySerializedAs` 兼容旧资产。 | 必要适配。它匹配当前通用 `CharacterActor` 奖励链，不表示已经接入正式掉落内容。 | 允许登记 `Loot.cs`；击杀奖励实际提交仍由 0060 的 `InventorySystem.ExecuteLootReward` 合同约束。 |
| 任务进度监听生命周期 | 参考 `QuestTaskProgress` 持有任务资产引用，初始化后开始监听任务事件，并用析构函数退订。 | 当前仍由具体任务进度持有监听职责，但改为显式 `StopTracking()` 幂等退订，完成前先停止监听，并按 0005/0006 用数据库引用保存任务资产。 | 必要适配。它修正监听生命周期和稳定存档身份，不改变 `JournalSystem/QuestProgress` 作为任务进度 owner 的流程。 | 允许登记 `QuestTaskProgress.cs`；坏档跳过只能作为读档容错，不能被正式任务结果链复用成吞错。 |
| `AssetMenuIndexer` 菜单常量 | 参考只保存 `CreateAssetMenu` 菜单分组常量。 | 当前品牌从 Mythril2D 改为 FantasyWord，并增加 EX-GAS/Ability Execution 菜单分组。 | 必要适配，不是运行时资源路径硬编码。 | 不作为资源路径问题处理；运行时资源路径继续由资源门禁检查。 |
| 参考一致性脚本治理 | 原脚本用于防止直拷地基长期漂移。 | 当前脚本仍保留运行时未裁决差异；已裁决的运行时 extra、Editor 验证/测试/工具层和必要 Editor patch 会被登记，未审差异继续暴露。 | 脚本状态落后于文档和代码时，不等于所有差异都是代码错误；但也不得把未审项批量白名单。 | 先继续分拣，再只把已裁决项加入允许列表；未审项不得白名单化。 |

### 本轮已撤回的错误口径

- 不再把 `GameManager.XxxSystem` 当成单例违规。
- 不再把 `TryGetSystem<T>()` 当成天然更规范。
- 不再把“参考工程有旅店/商店/制作代码”直接升级成当前业务。
- 不再把 `AssetMenuIndexer` 菜单分组常量误判成运行时资源路径。
- 不再把 `PlayerControlGroup` 视为“参考没有所以错”；它是当前产品目标的必要增强，但必须登记 owner 和未完成边界。

## 已确认错误

### 变形/感染规则能力编号配置

| 项目 | 内容 |
|------|------|
| 参考入口 | 参考没有独立 `CharacterAlterationRule`，相近职责是装备、命令或持续效果改变角色能力集合。 |
| 参考 owner | `CharacterBase/Hero` 拥有能力集合；作者数据直接保存 `AbilitySheet` 资产引用。 |
| 参考系统访问 | 装备、命令或效果把真实能力资产交给角色 owner，加/移除能力实例。 |
| 参考失败语义 | 空数组可以表示“不改能力”；但一旦作者配置了能力项，它必须是真实能力资产，不能把坏引用当作没有配置。 |
| 参考保存/刷新 | 角色能力集合和运行时能力实例立即更新，并保存为数据库稳定引用。 |
| FantasyWord 当前入口 | `CharacterAlterationRule` 用 Formal GAS 技能编号数组授予或压制能力，同时还可能改变动作锁、玩家控制锁、AI 接管、装备效果压制和阵营覆盖。 |
| FantasyWord 差异 | 用整数编号替代参考的 `AbilitySheet` 资产引用是 EX-GAS 适配；因此编号数组必须承担“资产引用是否有效”的作者配置校验职责。 |
| 判定 | 当前退步。 |
| 错误点 | 旧流程通过 `TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(...)` 过滤小于等于 0 的编号，可能把“配置了坏能力编号”的变形/感染规则执行成“没有能力变化”，甚至先移除互斥规则或应用非能力状态。 |
| 状态 | 已修：`CharacterAlterationRule.EnsureFormalGasAbilityCodeConfiguration()` 在状态应用前校验编号；空数组仍合法；新增测试和 Foundation 门禁覆盖该合同；见 0063。 |

### Formal GAS 能力持续效果编号配置

| 项目 | 内容 |
|------|------|
| 参考入口 | `EffectDispatcher.Apply` 调用旧 `IEffect` / `ITemporalEffect`；持续效果 `ATemporalEffect.Apply` 成功后才进入角色持续效果列表；能力变化最终回到 `CharacterBase.AddBonusAbility` / `RemoveBonusAbility` 这类角色能力集合入口。 |
| 参考 owner | `CharacterBase/Hero` 拥有能力集合和持续效果列表；作者数据直接保存真实 `AbilitySheet` 资产引用。 |
| 参考系统访问 | 效果把真实能力资产交给角色 owner；持续效果只有在实际应用成功后才登记到角色运行时持续效果。 |
| 参考失败语义 | 空能力数组可以表示“没有能力变化”，但不应形成一个成功的能力型持续效果；一旦作者配置了能力项，它必须是真实能力资产，不能把坏引用当作没有配置。 |
| 参考保存/刷新 | 成功应用后，角色能力集合和持续效果运行时列表一起更新；保存时记录仍需恢复的持续效果状态。 |
| FantasyWord 当前入口 | `TemporalAbilityGrantEffect`、`TemporalAbilitySuppressionEffect`、`TemporalAbilityReplacementEffect` 使用 Formal GAS 技能编号数组，通过状态效果来源键写入 `CharacterAbilitySet` 的临时能力授予或压制。 |
| FantasyWord 差异 | 用 Formal GAS 整数编号和状态效果来源键替代旧 `AbilitySheet` 引用是 EX-GAS 迁移期必要适配；因此编号数组必须承担旧资产引用的作者配置校验职责。 |
| 判定 | 当前退步。 |
| 错误点 | 旧 helper 会过滤小于等于 0 的编号；全坏数组可能被当成成功 no-op 并登记持续效果，替换效果还可能先授予有效能力、再因为压制编号坏而留下半完成状态。 |
| 状态 | 已修：三类能力持续效果在应用前先校验 Formal GAS 编号；空配置返回 `false`，不登记成功持续效果；替换效果先校验授予和压制两边再写角色能力；新增 EditMode 测试和 Foundation 门禁覆盖该合同；见 0064。 |

### Formal GAS 能力持续效果读档恢复

| 项目 | 内容 |
|------|------|
| 参考入口 | `CharacterBase.OnLoad` 直接恢复角色持续效果数组；参考效果必须先通过 `ATemporalEffect.Apply` 成功进入角色列表，保存时才会写入 `temporalEffects`。 |
| 参考 owner | `CharacterBase` 拥有持续效果列表；旧能力变化来自真实 `AbilitySheet` 引用和已成功应用的 live effect。 |
| 参考系统访问 | 读档恢复的是已经在存档中的持续效果对象；能力引用本身是数据库引用，不会在恢复时把坏编号过滤成空效果。 |
| 参考失败语义 | 坏档输入可以被跳过或报警，但不能恢复成一个“仍登记着、却没有任何能力变化”的成功持续效果。 |
| 参考保存/刷新 | 正常保存只来自当前角色已登记的持续效果；读档后角色持续效果列表和能力集合应保持一致。 |
| FantasyWord 当前入口 | `CharacterTemporalEffectRuntimeStateData.TryCreateRuntimeEffect -> ITemporalEffectRuntimeStateCarrier.TryRestorePersistedState -> CharacterBase.RestoreLoadedTemporalEffects -> ITemporalEffect.RestoreRuntimeState(owner)`。 |
| FantasyWord 差异 | 当前把持续效果存成最小 runtime state，并用 Formal GAS 编号重建能力授予/压制来源，这是 EX-GAS 迁移期必要适配；因为不再直接保存 live effect 对象，读档时还必须把当前角色重新绑定成 live owner。 |
| 判定 | 当前退步。 |
| 错误点 | 正常 `Apply()` 已校验编号和空配置，但读档恢复路径直接 `RestorePersistedState()` 后登记 effect；坏保存记录里的小于等于 0 编号会被后续能力写入过滤成 no-op，导致角色登记了一个没有真实能力变化的持续效果。有效保存记录还可能只恢复持久引用、不恢复运行时目标引用，导致恢复回调拿不到当前角色，能力来源、动作锁或速度规则没有真正重建。 |
| 状态 | 已修：`ITemporalEffectRuntimeStateCarrier` 的恢复入口改为 `TryRestorePersistedState`；坏保存记录只跳过该持续效果，不中断其它读档记录；正常有效记录恢复时先绑定当前角色 live owner，再恢复能力来源和持续效果登记；新增 EditMode 测试和 Foundation 门禁覆盖该合同；见 0065。 |

### 玩家/角色结果型命令

| 项目 | 内容 |
|------|------|
| 参考入口 | `AddExperience`、`AddOrRemoveAbility`、`AddOrRemoveItem`、`AddOrRemoveMana`、`HealOrDamagePlayer`、`RevivePlayer`。 |
| 参考 owner | 正式玩家 `GameManager.Player` 和正式背包 `GameManager.InventorySystem`。 |
| 参考系统访问 | 直接访问 `GameManager.Player` / `GameManager.InventorySystem`，不是可失败查询。 |
| 参考失败语义 | 命令目标是正式玩家或正式背包；目标缺失属于配置/运行时错误，不是成功 no-op。 |
| 参考保存/刷新 | 角色经验、生命、法力、能力和背包由对应 owner 立即写入。 |
| FantasyWord 当前入口 | 上下文命令通过 `GameCommandContext` 支持脚本、AI、当前受控角色和显式目标。 |
| FantasyWord 差异 | 上下文是合理增强，但结果型命令仍必须真的作用到一个角色或 owner。 |
| 判定 | 当前退步。 |
| 错误点 | 旧流程把缺角色、空 Formal GAS 编码、移除物品失败等正式结果失败吞成命令成功。 |
| 状态 | 已修：`ResolveRequiredActorOrCurrentControlledCharacter`、技能编码校验、物品移除失败抛错；见 0051。 |

### 显式目标/策略/命令资产

| 项目 | 内容 |
|------|------|
| 参考入口 | `DestroyEntity`、`ToggleController`、`MoveCharacterBase`、`MoveCamera`、`PlayDialogueSequence`、`ExecuteCommandHandler`、`ExecuteCommandList`。 |
| 参考 owner | 命令资产上的显式字段和被配置的目标对象。 |
| 参考系统访问 | 直接使用配置字段；目标对象为空会暴露配置问题。 |
| 参考失败语义 | 缺显式目标、缺策略、缺子命令不是成功无操作。 |
| 参考保存/刷新 | 由目标命令实际执行销毁、移动、对话、控制器切换或子命令执行。 |
| FantasyWord 当前入口 | 同名或同职责命令，加了 `GameCommandContext` 和异步 `Task`。 |
| FantasyWord 差异 | 异步和上下文是合理增强，但不改变显式配置必须存在。 |
| 判定 | 当前退步。 |
| 错误点 | 旧流程用 `?.`、空目标 `return` 或 `Task.CompletedTask` 把漏配目标/策略/子命令吞成成功。 |
| 状态 | 已修；见 0052。 |

### 地图结果链

| 项目 | 内容 |
|------|------|
| 参考入口 | `SaveCheckpoint`、`TeleportTo`、`RespawnPlayer`、读档进入地图。 |
| 参考 owner | `MapSystem`、正式检查点、正式玩家。 |
| 参考系统访问 | `GameManager.MapSystem`、`GameManager.Player`。 |
| 参考失败语义 | 检查点、玩家或地图流程缺失不是可跳过查询。 |
| 参考保存/刷新 | `MapSystem` 保存当前检查点、切图后移动玩家、重生后复活玩家。 |
| FantasyWord 当前入口 | `MapSystem` 增加初始出生点、Playtest 出生点、检查点顺序、过场委托和主穿越角色。 |
| FantasyWord 差异 | 这些是当前项目必要适配。 |
| 判定 | 当前退步。 |
| 错误点 | 旧流程在缺检查点、缺主穿越角色或缺 `TransitionSystem` 时只断言或返回，会吞掉保存检查点、传送、重生和读档位置恢复。 |
| 状态 | 已修；见 0053。 |

### 任务日志结果链

| 项目 | 内容 |
|------|------|
| 参考入口 | `JournalSystem.StartQuest`、`CompleteQuest`、`UnlockQuest`、`ItemStartQuestEffect`。 |
| 参考 owner | `JournalSystem` 和正式任务资产 `Quest`。 |
| 参考系统访问 | 直接传入任务资产并推进任务状态。 |
| 参考失败语义 | 已经决定开始/完成/解锁某任务时，任务资产缺失不是成功。 |
| 参考保存/刷新 | `JournalSystem` 写任务进度、通知 UI，并执行任务完成命令。 |
| FantasyWord 当前入口 | 增加 `GameCommandContext`、可等待完成命令、稳定数据库引用和监听释放。 |
| FantasyWord 差异 | 都是必要适配，但不改变任务资产必需性。 |
| 判定 | 当前退步。 |
| 错误点 | 旧流程对缺任务资产只记录错误后返回；物品使用可能显示成功但任务没有开始。 |
| 状态 | 已修；见 0054。 |

### 库存基础写入

| 项目 | 内容 |
|------|------|
| 参考入口 | 命令奖励、箱子掉落、怪物奖励、制作产出、商店交易。 |
| 参考 owner | 唯一玩家背包 `InventorySystem.items` 和钱。 |
| 参考系统访问 | 直接 `GameManager.InventorySystem.AddToBag/RemoveFromBag/AddMoney/RemoveMoney`。 |
| 参考失败语义 | 参考工程单背包且写入较宽松；没有多 owner 目标失效面。 |
| 参考保存/刷新 | `InventorySystem` 写字典并发送物品/钱变化通知。 |
| FantasyWord 当前入口 | 多 owner 背包，owner 可为队伍、角色、容器、尸体、商店、制作台。 |
| FantasyWord 差异 | 多 owner 是必要增强，因此坏 item、坏数量、无效 owner 会变成真实失败面。 |
| 判定 | 当前退步。 |
| 错误点 | 旧 `AddToBag/RemoveFromBag` 对空物品和非正数量静默返回，可能让奖励、箱子、制作或击杀结果假成功。 |
| 状态 | 已修；见 0055。 |

### 商店买入/卖出

| 项目 | 内容 |
|------|------|
| 参考入口 | 参考商店 UI 直接从唯一玩家背包买卖。 |
| 参考 owner | 唯一玩家背包和全局金钱。 |
| 参考系统访问 | `GameManager.InventorySystem.RemoveMoney/AddToBag/RemoveFromBag/AddMoney`。 |
| 参考失败语义 | 参考没有当前交易 owner 解析失败，也没有多 owner 切换。 |
| 参考保存/刷新 | 交易成功后刷新 UI 和播放交易反馈。 |
| FantasyWord 当前入口 | `UIShop` 通过 `GameCommandContext` 解析当前交易 owner。 |
| FantasyWord 差异 | 多 owner 是必要增强。 |
| 判定 | 当前退步。 |
| 错误点 | 买入旧流程可能先扣钱再发现物品写入 owner 无效；卖出旧流程可能物品没删却加钱。 |
| 状态 | 已修；见 0055。 |

### 制作结果链

| 项目 | 内容 |
|------|------|
| 参考入口 | `CanCraft -> 成功提示 -> Craft`。 |
| 参考 owner | `InventorySystem` 钱、材料和产物。 |
| 参考系统访问 | `Craft` 直接扣钱、扣材料、写产物。 |
| 参考失败语义 | 参考依赖单背包和宽松写入；坏配方没有被建成当前项目的可定位异常链。 |
| 参考保存/刷新 | `InventorySystem` 写入后刷新背包状态。 |
| FantasyWord 当前入口 | `Recipe`、`CraftingStation`、多 owner 背包。 |
| FantasyWord 差异 | 坏产物、坏材料、额外产物和当前 owner 可制作性都可能失败。 |
| 判定 | 当前退步。 |
| 错误点 | 旧流程可能先提示成功，再在扣钱/扣料/产出阶段失败。 |
| 状态 | 已修；见 0055。 |

### 击杀奖励库存写入

| 项目 | 内容 |
|------|------|
| 参考入口 | `Monster.Kill()` 在怪物死亡后遍历 `potentialLoot`，满足等级、条件和掉率后直接加到玩家背包，再加经验和金钱。 |
| 参考 owner | `InventorySystem` 拥有背包和金钱，`GameManager.Player` 拥有经验。 |
| 参考系统访问 | 直接访问 `GameManager.InventorySystem` 和 `GameManager.Player`。 |
| 参考失败语义 | 参考工程是唯一玩家背包，库存写入较宽松；坏掉落配置没有被建成整体验证合同。 |
| 参考保存/刷新 | 背包和金钱由 `InventorySystem` 写入并通知，经验由玩家对象写入。 |
| FantasyWord 当前入口 | `CharacterActor.Kill -> GrantKillRewards`，奖励接收者可能是最后有效伤害来源或主玩家角色。 |
| FantasyWord 差异 | 当前项目背包 owner 可变，库存写入会拒绝空物品和非法数量；一次击杀可能命中多个掉落并同时给金钱。 |
| 判定 | 当前退步。 |
| 错误点 | 旧流程逐条写入掉落，若后续命中掉落配置无效，前面有效物品可能已经写入，金钱、经验和死亡命令也可能停在半完成状态。 |
| 状态 | 已修：`CharacterActor` 先解析本次命中掉落，再请求 `InventorySystem.ExecuteLootReward` 整体验证并提交库存奖励；经验仍由角色写入；见 0060。 |

### 消耗型物品使用

| 项目 | 内容 |
|------|------|
| 参考入口 | `AItemEffect.TryUse` 和派生物品效果。 |
| 参考 owner | 唯一玩家背包和目标角色。 |
| 参考系统访问 | 效果成功后从背包扣除物品。 |
| 参考失败语义 | 参考没有多 owner 和可失效 UI 来源。 |
| 参考保存/刷新 | 效果成功后扣物品、播放反馈。 |
| FantasyWord 当前入口 | `AItemEffect.TryUse` 增加 source owner、target、location。 |
| FantasyWord 差异 | 多 owner 和 UI 可失效是必要适配。 |
| 判定 | 当前退步。 |
| 错误点 | 旧流程可能先应用效果和成功反馈，再忽略扣除失败，导致效果生效但物品未消耗。 |
| 状态 | 已修；见 0055。 |

### 装备穿脱与回包

| 项目 | 内容 |
|------|------|
| 参考入口 | `InventorySystem.TryEquip/TryUnequip -> Hero.TryEquip/TryUnequip`。 |
| 参考 owner | `Hero.equipments` 和唯一玩家背包。 |
| 参考系统访问 | `GameManager.Player` 和 `InventorySystem` 直接协作。 |
| 参考失败语义 | 唯一玩家背包存在，卸下后回同一个背包。 |
| 参考保存/刷新 | `Hero.Equip/Unequip` 刷属性并通知装备事件；`InventorySystem` 调整背包。 |
| FantasyWord 当前入口 | `InventorySystem.TryEquip/TryUnequip` 接受 source/destination owner 和 `CharacterEquipment`。 |
| FantasyWord 差异 | 多角色、多 owner 是必要增强。 |
| 判定 | 当前退步。 |
| 错误点 | 旧卸下流程先改变角色装备状态，再发现回包 owner 无效，可能装备消失但未回包。 |
| 状态 | 已修；见 0055。 |

### 装备附加能力来源

| 项目 | 内容 |
|------|------|
| 参考入口 | `Hero.Equip/Unequip` 中遍历 `equipment.bonusAbilities`。 |
| 参考 owner | `Hero` 的能力集合和装备资产。 |
| 参考系统访问 | 装备资产直接持有能力资产引用，穿脱时同步加/移除。 |
| 参考失败语义 | 没有单独“能力来源 ID 创建失败”这个失败面。 |
| 参考保存/刷新 | 能力和装备状态随 `Hero` 保存/恢复。 |
| FantasyWord 当前入口 | `CharacterEquipment.ApplyEquipmentSlotChange` 使用 Formal GAS 编码和 `CharacterAbilitySourceKey`。 |
| FantasyWord 差异 | 用 `DatabaseRegistry` 稳定装备引用作为能力来源，是当前存档/来源叠加的必要适配。 |
| 判定 | 当前退步。 |
| 错误点 | 旧流程若槽位改变后才发现装备未登记，会记录错误后继续，形成装备状态与附加能力来源不一致。 |
| 状态 | 已修：槽位改变前准备来源；普通无附加能力装备不受影响。 |

### 角色读档装备与快捷槽覆盖

| 项目 | 内容 |
|------|------|
| 参考入口 | `Hero.OnLoad` 恢复 `equipments` 和 `equippedAbilities`。 |
| 参考 owner | `Hero.equipments` 和 `Hero.equippedAbilities`。 |
| 参考系统访问 | 装备和技能引用通过 `GameManager.Database.LoadFromReference(...)` 恢复。 |
| 参考失败语义 | 读档时先重建装备字典和快捷槽；存档没有某个槽位时，该槽位就是空，不沿用 Prefab 或读档前运行时槽位。 |
| 参考保存/刷新 | 装备恢复后统一 `UpdateStats()`；快捷槽恢复后通知能力槽变化。 |
| FantasyWord 当前入口 | `CharacterActor.LoadActorRuntimeState/OnLoad -> CharacterEquipment.RestoreFromSlotData` 与 `CharacterAbilitySet.RestoreEquippedAbilitiesFromSlotData`。 |
| FantasyWord 差异 | 装备槽拆到 `CharacterEquipment`，快捷槽保存 Formal GAS 技能编号；这是多角色与 EX-GAS 迁移的必要适配。 |
| 判定 | 当前退步。 |
| 错误点 | 旧恢复函数在 `equipmentSlots` 或 `quickAbilitySlots` 为 `null`/空数组时直接返回，不清空当前槽位，可能把 Prefab 初始装备、读档前装备或旧快捷槽误带进新档。 |
| 状态 | 已修：装备槽和快捷槽恢复都先用存档状态覆盖当前槽位；`null`/空数组表示空槽；新增 EditMode 测试覆盖两条路径；2026-07-17 精确两项读档覆盖测试通过，`MeleeAttackAbilityEditModeTests` 通过，完整 `FantasyWord.GameCore.EditModeTests` 通过，`spec-lint`、Foundation 静态门禁和参考差异门禁通过；见 0066。 |

### 死亡装备转尸体

| 项目 | 内容 |
|------|------|
| 参考入口 | 参考怪物死亡奖励直接写玩家背包；没有 FantasyWord 的尸体装备背包 owner。 |
| 参考 owner | 死亡奖励由正式背包系统持有。 |
| 参考系统访问 | `GameManager.InventorySystem` 直接写入。 |
| 参考失败语义 | 死亡结果不是表现层查询，不能静默跳过。 |
| 参考保存/刷新 | 背包系统写入死亡奖励。 |
| FantasyWord 当前入口 | `CharacterBase.Kill -> TransferOwnedEquipmentToCorpseOwner -> InventorySystem.TransferCharacterEquipmentToCorpse`。 |
| FantasyWord 差异 | 尸体背包 owner 依赖角色稳定持久化标识，是当前项目必要适配。 |
| 判定 | 当前退步。 |
| 错误点 | 旧流程先强制卸装，再写尸体背包；尸体 owner 无效时装备可能从角色消失但没进尸体背包。 |
| 状态 | 已修：强制卸装前验证尸体 owner；见 0047。 |

### 持久化实例化

| 项目 | 内容 |
|------|------|
| 参考入口 | `PersistenceSystem.InstantiateRuntime/InstantiateCustom/RegisterCustomInstancedPersistable`。 |
| 参考 owner | `PersistenceSystem` 持有运行时对象登记字典。 |
| 参考系统访问 | 调用方通过持久化系统统一实例化/登记。 |
| 参考失败语义 | 坏 prefab、缺 `Persistable`、类型错误是配置错误，不是可跳过查询。 |
| 参考保存/刷新 | 实例化后登记到持久化字典，保存时写引用。 |
| FantasyWord 当前入口 | 增加稳定数据库引用、运行时 prefab GUID、类型约束和读档容错。 |
| FantasyWord 差异 | 当前项目必要适配。 |
| 判定 | 当前退步。 |
| 错误点 | 旧流程可能断言后继续登记空对象、错误类型对象或空标识。 |
| 状态 | 已修；见 0056。 |

### 主玩家控制目标配置

| 项目 | 内容 |
|------|------|
| 参考入口 | `PlayerSystem` 创建正式玩家，`Movable` 通过序列化 controller 接收输入。 |
| 参考 owner | `PlayerSystem` 和玩家角色控制器。 |
| 参考系统访问 | 正式玩家闭包，不是可有可无表现附件。 |
| 参考失败语义 | 主玩家控制配置缺失是场景/Prefab 错误。 |
| 参考保存/刷新 | 玩家系统启动和读档后恢复玩家控制。 |
| FantasyWord 当前入口 | `IPlayerInputTarget`、当前受控角色、控制组、`CharacterPlayerControl`。 |
| FantasyWord 差异 | 当前项目必要适配。 |
| 判定 | 当前退步。 |
| 错误点 | 旧流程主玩家缺正式输入目标时进入等待恢复，吞掉场景/Prefab 配置错误。 |
| 状态 | 已修；见 0057。 |

## 已确认不应按形式改动

| 流程 | 对照结论 | 状态 |
|------|----------|------|
| `GameManager.XxxSystem` / `GameManager.Player` 正式结果链访问 | 参考同职责流程大量直读正式系统和玩家；访问形式本身不是问题。 | 不改；见 0050。 |
| `AddOrRemoveMoney` 显式增减金钱命令 | 参考同职责命令也是直接 `AddMoney/RemoveMoney`；当前命令表达的是脚本奖励/惩罚，不是用户确认付款，不应为了参考旅店流程新增付款业务入口。 | 不改。 |
| 旅店 / `InnInteraction` | 当前只找到代码遗留，未找到场景、Prefab 或资产正式引用；参考工程旅店流程不能在没有当前业务入口证据时纳入重构成果。 | 不纳入当前业务重构；不建决策或门禁。 |
| UI 菜单上下文、条件、HUD、表现反馈中的可失败查询 | 当前项目需要“系统未就绪时不改变正式结果”的查询语义；这些不是正式结果写入。 | 不按文本批量改。 |
| `CommandTrigger` 等触发器在玩家系统未就绪时跳过 | 参考同职责触发器允许未就绪时不改变正式结果。 | 不改。 |
| 保存/旗标链 | 参考和当前都由保存系统组装正式数据块；文件层失败不改世界状态。 | 暂不判错。 |
| `SetGameFlag` 命令 | 参考和当前都是把配置的 flag 字符串直接交给 `GameFlagSystem.Set`；当前未找到正式资产引用，不把空字符串策略升级成本轮结果链修复。 | 不改；若后续正式接入 flag 作者数据，再按 flag 命名规范单独审。 |
| `CompleteTask` 命令 | 参考和当前都是遍历当前进行中任务并强制完成匹配子任务；当前未找到正式资产引用，不把“没有匹配任务”解释成假成功结果链。 | 不改。 |
| `ItemPickable` / `MoneyPickable` / `PickableItem` | 参考工程没有同名拾取物；当前工程也没有场景、Prefab 或资产引用这些脚本。 | 不纳入当前业务修复；后续接入拾取物内容时再按库存 owner 与拾取成功反馈顺序补合同。 |
| 对话、死亡、任务完成后的可选生命周期命令 | `DialogueNode`、`Persistable`、`CharacterSheet`、`Quest` 这类入口里的空命令表示“没有额外动作”；它们不是被玩家确认的独立结果命令。正式命令资产本体 `CommandHandler` 和命令列表缺子命令仍会报错。 | 不把通用空命令辅助入口一刀切改成异常；只在正式命令资产或已决定执行的分支缺配置时判错。 |
| 输入图切换 | 参考用“先切 None、一帧后切目标图”避免按键穿透；当前用 `InputActionReleaseGate` 更明确地阻止共用按键直到释放。 | 必要适配，不回退。 |
| `ItemAddAbilityEffect` 学技能失败 | 当前返回失败时不会扣物品、不会播放成功反馈；属于交互失败，不是正式结果假成功。 | 暂不改。 |
| 装备穿戴成功后再从背包移除 | 参考也是先 `Hero.TryEquip` 成功后调整背包；FantasyWord 先检查来源背包持有物品。 | 当前同构，不改。 |

## 目标重构合同

### 库存多步交易

| 项目 | 内容 |
|------|------|
| 参考流程 | `2DRPGEngine` 在商店 UI、制作站和宝箱实体里直接写唯一玩家背包：买入是扣钱后加物，卖出是删物后加钱，制作是扣钱、扣材料、加产物，宝箱首次开启是逐条给物品并加钱。 |
| 参考成立前提 | 唯一玩家背包、较宽松库存写入、没有当前交易 owner 失效或多目标背包切换面。 |
| FantasyWord 当前约束 | 多 owner 背包、可失效 UI 上下文、制作材料/产物配置会被正式库存写入拒绝；宝箱物品进入容器 owner，金钱进入队伍钱包，坏掉落不能导致前面条目已写但箱子未打开。 |
| 判定 | 参考职责内核是“库存系统是真相源”，不是“UI/实体应拥有交易顺序”。FantasyWord 继续让 UI/制作站/宝箱手写多步库存写入属于浅 Module 和低 locality。 |
| 正式 owner | `InventorySystem`。 |
| 正式接口 | 商店买入、商店卖出、制作、宝箱首次掉落初始化和背包转移由库存系统执行完整库存写入；`InventoryTransferRequest` / `InventoryTransferResult` / `InventoryOperationResult` 只是不拥有状态的请求/结果值对象。调用方只请求交易/初始化/转移并处理结果或配置异常。 |
| 不采用 | 不新增第二套交易系统、不用 DI/service 包装层替代 `GameManager.InventorySystem`、不把所有库存写入都改成同一种通用请求。 |
| 状态 | 已重构：见 0058；击杀奖励库存提交见 0060。 |

## 本轮收口结论

以下是第 55 项收口时的剩余候选分流；它们不是新的已判错项：

- 角色奖励、箱子、制作、商店、消耗品、装备回包、死亡装备转尸体和击杀奖励等库存结果链已按 0055、0058、0060 收口；`ItemPickable`、`MoneyPickable`、`PickableItem` 当前没有正式场景、Prefab 或资产引用，后续接入拾取物内容时再按库存 owner 与拾取成功反馈顺序补合同。
- 状态效果授予/压制 Formal GAS 能力的应用前编号配置已由 0064 收口；保存恢复的坏档跳过、有效记录恢复和 live owner 绑定已由 0065 收口；角色变化规则读档后的非能力状态恢复和能力来源不重复叠加已补合同测试。
- 存档恢复中的“跳过坏记录”仍只作为坏档输入容错；保存当前运行时状态的数据库引用必需性已由 0068 收口，保存链缺正式数据库引用会暴露配置错误，不再被当作可跳过坏记录。
- 地图、任务、背包、角色控制以外的正式结果命令已按当前资产证据分流：2026-07-17 命令脚本 GUID 矩阵显示当前正式资源引用为 0；命令门禁通过且 `RawCommandTaskDropCount=0`。后续出现具体命令资产时，必须先按资产逐项补本表再判断是否修。

## 当前执行规则

1. 先补本表，再改代码。
2. 每个判错项必须列出参考流程、当前流程、差异性质和最小修复。
3. 门禁只能检查具体合同，不检查“必须 TryGetSystem”或“禁止 GameManager.XxxSystem”。
4. 若只是当前项目必要适配，应写明为什么不回退到参考表面实现。
5. 若只是交互失败或表现查询，不升级成正式结果异常。
