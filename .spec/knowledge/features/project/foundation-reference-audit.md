---
name: foundation-reference-audit
description: 项目知识：foundation-reference-audit.md：foundation-reference-audit。
metadata:
  type: doc
  status: 已交付
---

# FantasyWord 地基参考审计

> 本文记录当前 foundation 迁移纠偏的参考矩阵和问题清单。
> 结论优先级：本地可复制源码证据 > 当前项目规范 > 成熟引擎公开架构范式 > 纯推测。

## 当前裁决

- `FantasyWordBootstrapper + FantasyWordRuntimeContext + FantasyWordModuleInstaller + FantasyWordServiceRegistry + FantasyWordEventBus + 五个 *ModuleAsset` 已撤出正式地基；后续不得恢复为完成口径。
- 上述结构没有命中 `dark-corridor` 文档要求的成熟参考同名同职责来源，也没有命中 `2DRPGEngine` 的可复制地基闭包，因此没有可信依据。
- `2DRPGEngine` 已有同职责成熟地基：`GameManager + AGameSystem`、`DatabaseRegistry + DatabaseEntry`、`SaveSystem + PersistenceSystem + Persistable`、`MapSystem`、`ICommand / IInteraction`、`Entity / Controller`。
- `TopDown Engine / Koala2D` 已纳入参考池，但当前裁决不是“整体替换地基”：`Koala2D` 只是 demo，真正可复用能力主要来自 `TopDownEngine/Common`。
- 对 `TopDown Engine` 的当前裁决是：角色控制、地牢机关、武器/拾取、2D 关卡样板可继续审查；总入口、库存事件流和整套 MoreMountains 运行时暂不整体替换 `2DRPGEngine` 地基。
- `uMMORPG` 当前不参与“谁是总地基来源”的胜负比较；它只作为 `2D 移动与场景组织` 的局部源码证据源存在。
- `Assets/Plugins/TopDownEngine` 当前已导入第一批正式候选子集：`Common`、`Koala2D`、`MMTools`、`MMInterface`、`InventoryEngine`、`MMFeedbacks` 主闭包；`ScriptsCinemachine`、`ScriptsPostProcessing` 和 `MMTools/Accessories/MMCinemachine` 已明确剔除。
- 当前已新增并收口 `Assets/Scripts/GameCore/Runtime/Game/Systems/AGameSystem.cs`、`Assets/Scripts/GameCore/Runtime/Game/GameManager.cs`、`Assets/Scripts/GameCore/Runtime/Game/GameConfig.cs` 与 `Assets/Tests/EditMode/GameCore/Game/GameManagerTests.cs`，作为替换旧自造地基的第一段最小闭包。
- `2026-06-12` 起，`2DRPGEngine` 的运行时与编辑器源码已按目录整段迁入 `Assets/Scripts/GameCore` 与 `Assets/Editor/GameCore`；当前正式落点不再只停留在最小闭包。
- `PlayerSystem / InventorySystem / SaveSystem / JournalSystem / Movable / Controller / CharacterBase / Hero / Teleporter / Interaction / Combat / Quest / UI` 现在已经进入正式迁移目录；旧“禁止这些文件出现”的阶段性判断已经失效。
- 当前 `GameCore` 的判断口径已切到“地基闭包是否成立”，不再把“业务闭环未接完”误写成“系统尚未迁入”或“正式闭包不存在”。当前真正未完成的是 Unity 导入编译复核、场景/Prefab/资源接线复核、测试收口，以及参考项目专属资产与当前项目业务之间的再分层。
- UE 只作为成熟引擎范式辅助证据：官方文档显示其核心分层围绕 `GameInstance / Subsystem`、`World`、`GameMode / GameState`、`Actor / Component`、`Pawn / Controller`、`GameFeature / ModularGameplay`，不是项目侧空模块列表。
- 当前第一步不作为正式入口保留第三方插件、参考工程随带素材、MiniFantasy 素材包自带场景/Prefab、测试素材和历史候选资产；只审计项目侧自造地基与文档。MiniFantasy 素材本体是正式美术来源，参考工程素材不进入正式美术口径。

## 模块来源简表

这张表是“当前主要参考来源与使用方式”的简表，不是把 `uMMORPG` 升格成第四个总框架候选的胜负表。

| 模块 | 当前主参考 | 使用方式 | 当前结论 |
| --- | --- | --- | --- |
| 地基总入口、系统生命周期、数据库、存档、地图 | `2DRPGEngine/Assets/Mythril2D/Core` | 整套替换 | 这是当前正式地基主参考，优先直接拷贝并保持闭包完整。 |
| 俯视角角色控制、能力组件、2D 地牢交互样板 | `TopDown Engine/Assets/TopDownEngine/Common` | 局部吸收 | 有明确价值，但依赖整套 MoreMountains 运行时；先按模块审查，不整套替换当前地基。 |
| 2D 地牢 demo 场景、Prefab 组合、机关接线 | `TopDown Engine/Assets/TopDownEngine/Demos/Koala2D` | 局部吸收 | 只作为样板参考，不单独作为框架来源。 |
| 换装/UV/装备表现模块 | `Assets/Scripts/Presentation/EquipmentSystem` + `MiniCharacterCreator-main/test` 留档证据 | 正式表现模块 | 属于当前项目装备表现能力，不是完整物品/背包规则地基。 |
| 移动合同、传送入口、实例宿主与出生点分流宿主证据 | `uMMORPG Remastered` | 局部复核 | 当前只把它当局部源码证据来源：停止半径、手动输入打断旧路径、失效保存位置回退和子碰撞体回溯正式玩家实体等规则，只作为合同/规则/健壮性补强融合到现有 `Movable / MapSystem / Teleporter`，不是重复搬运 `uMMORPG` 的同职责实现；实例宿主、出生点分流和清理策略继续只登记为场景组织证据，不迁它的 MMORPG 架构、Mirror 生命周期或 3D NavMesh 闭包。按 `2026-06-14` 对 `Assets/uMMORPG/Scripts` 的现态搜索，当前只明确看到 `PartySystem / GuildSystem / SafeZone` 这类网络/社交或局部区域脚本，没有发现 `World / Cell / Faction / Economy / Base / Settlement / Region` 这类开放世界模拟宿主闭包，因此它也不能补当前项目缺的世界模拟层。进一步按 `2026-06-17` 对 `SafeZone.cs / Entity.cs / Player.cs / Monster.cs / UIRespawn.cs` 的复核，`SafeZone` 本体只是区域标记脚本，运行时真正保存的是 `Entity.inSafeZone` 这类局部状态；`UIRespawn` 也只是死亡后显示复活按钮的界面壳，玩家复活写在 `Player.UpdateServer_DEAD()`，怪物自复活写在 `Monster` 自己的状态机里，没有统一 `Respawn` 宿主。因此它仍不能替代当前项目缺的实例宿主、出生点分流宿主或开放世界区域宿主。当前仍缺的 4 个一级框架参考位是：2D 导航 Provider、2D 点击移动执行闭包、单机/本地实例宿主，以及单机/本地出生点分流宿主；相关“控制对象与世界穿越目标统一”“超距后自动靠近再施法/交互”“传送入口条件”都只算二级缺口，不能绕过这 4 个一级缺口提前落代码。 |

## 参考矩阵

| 参考项 | 来源路径或 URL | 证据等级 | 关键能力 | FantasyWord 当前落点 | 当前差距 | 处理结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 2DRPGEngine 运行时入口 | `C:/Gamedev/Unity/Engine/2DRPGEngine/Assets/Mythril2D/Core/Runtime/Scripts/Game/GameManager.cs` | 本地源码，可复制 | 单例入口、系统收集、系统生命周期、静态系统访问、框架生命周期分发 | `Assets/Scripts/GameCore/Runtime/Game/GameManager.cs` | 已撤出自造 `Notify*` 第二入口，并把旧通知中心生命周期调用面收回到 `GameRuntimeEvents`；Unity 导入和 EditMode 验证仍待跑 | 继续以该闭包为正式地基入口 |
| 2DRPGEngine 系统基类 | `.../Game/Systems/AGameSystem.cs` | 本地源码，可复制 | `OnSystemInit/Start/Stop`，地图加载/卸载，存档加载回调 | `Assets/Scripts/GameCore/Runtime/Game/Systems/AGameSystem.cs` | 已替换旧 service/module/asset 生命周期；后续需接入具体系统 | 继续按 `AGameSystem` 建系统 |
| 2DRPGEngine 数据库 | `.../Database/DatabaseRegistry.cs`、`DatabaseEntry.cs`、`.../Save/DatabaseEntryReference.cs`、`.../Database/Save/PrefabReference.cs`、`.../Database/Game/GameConfig.cs` | 本地源码，可复制 | ScriptableObject 数据注册、条目基类、GUID 引用、GUID 迁移转换、Prefab 数据条目、数据库配置宿主 | `Assets/Scripts/GameCore/Runtime/Database`、`Assets/GameData/GameCore/DatabaseRegistry.asset`、`GameManager.Database` | `GameConfig` 已改为 `DatabaseEntry`，但数据库注册表正式外部入口已收口到 `GameManager.Database`，不再同时公开一份 `Config.databaseRegistry`；`DatabaseEntryReference.guid`、`DatabaseEntry.GetAssetGUID()`、`DatabaseRegistry.GUIDToDatabaseEntry/DatabaseEntryToGUID`、`PrefabReference.prefab` 已对齐字段和 API 形状；`MackySoft.SerializeReferenceExtensions` 与 `azixMcAze.SerializableDictionary` 已迁入，`DatabaseRegistry` 和 `persistentIdentifierMappings` 已回到参考字典形状；Unity 导入和 EditMode 验证仍待跑 | 继续以该闭包作为数据真相入口 |
| 2DRPGEngine 存档数据合同 | `.../Save/DataBlock.cs`、`IDataBlockHandler.cs`、`Persistable.cs` 中的数据类型 | 本地源码，可复制 | 数据块、数据处理接口、持久化信息、持久化对象状态 | `Assets/Scripts/GameCore/Runtime/Persistence` | 已建立 DataBlock、IDataBlockHandler、PersistableDataBlock 和持久化信息闭包；持久化信息类型已改回参考的公开字段 `identifier/prefab/map/info/state` | 保留为正式存档数据合同 |
| 2DRPGEngine 持久化对象/系统 | `.../Save/Persistable.cs`、`PersistableReference.cs`、`.../Game/Systems/PersistenceSystem.cs` | 本地源码，可复制 | 可持久化组件、稳定引用、预置/运行时对象快照、按地图恢复运行时对象、销毁生命周期处理 | `Assets/Scripts/GameCore/Runtime/Persistence/Persistable.cs`、`PersistableReference.cs`、`PersistenceSystem.cs`、`GameManager.PersistenceSystem` | 已迁入依赖 Map/PrefabReference 的闭包，销毁通知已继续收回 `Persistable -> PersistenceSystem` 正式入口；未迁 `SaveSystem` 聚合存档 | 保留为正式持久化系统入口 |
| 2DRPGEngine 游戏标记系统 | `.../Game/Systems/GameFlagSystem.cs` | 本地源码，可复制 | 字符串布尔标记集合、`GameFlagsDataBlock`、`gameFlagChanged` 通知 | `Assets/Scripts/GameCore/Runtime/Game/Systems/GameFlagSystem.cs`、`GameManager.GameFlagSystem`、`GameRuntimeEvents.GameFlagChangedEvent` | 已独立迁入；变化通知已收回 GameCore 强类型事件，不依赖 Player/Inventory/Journal | 保留为正式轻量状态系统入口 |
| 2DRPGEngine 存档聚合系统 | `.../Game/Systems/SaveSystem.cs`、`.../Database/Save/SaveFile.cs` | 本地源码，可复制 | 默认存档复制、Map/GameFlag/Inventory/Journal/Player/Persistence 聚合加载保存 | `Assets/Scripts/GameCore/Runtime/Game/Systems/SaveSystem.cs`、`Assets/Scripts/GameCore/Runtime/Database/Save/SaveFile.cs` | 世界状态聚合仍对齐 2DRPG；原始裸文件读写已替换为 YokiFrame SaveKit 槽位、版本、头部元数据和文件格式承载。若追求“可实际存档”，仍依赖 `InventorySystem`、`JournalSystem`、`PlayerSystem`、`Hero`、`SaveFile` 数据资产和场景接线 | 作为正式存档语义入口保留；SaveKit 只做文件层，不成为第二套世界状态模型 |
| 2DRPGEngine 地图信息/检查点 | `.../Maps/MapInfo.cs`、`.../Checkpoints/ICheckpoint.cs`、`SimpleCheckpoint.cs`、`CheckpointUtil.cs`、`Checkpoint.cs`、`PersistableCheckpoint.cs` | 本地源码，可复制，局部吸收 TopDown | 地图测试起点、检查点地图名和位置、空地图名解析、持久化检查点引用；TopDown 提供检查点顺序、强制覆盖、默认出生点、重生延迟、边界和相机目标样板 | `Assets/Scripts/GameCore/Runtime/Maps/MapInfo.cs`、`ICheckpoint.cs`、`SimpleCheckpoint.cs`、`CheckpointUtil.cs`、`Checkpoint.cs` | 已保留参考的 `map/position/UpdateMapName()` 与 `playtestCheckpoint` 合同；`MapInfo` 已新增默认出生点、重生延迟、地图边界和相机目标；`Checkpoint` 已新增顺序/强制覆盖和玩家进入触发保存；空地图名仍通过 `GameManager.MapSystem.GetCurrentMapName()` 解析；无资产实例、无运行时调用的 `GameObjectCheckpoint` 已删除 | 保留为正式地图数据入口，不接入 TopDown `LevelManager` |
| 2DRPGEngine 地图系统 | `.../Game/Systems/MapSystem.cs` | 本地源码，可复制，局部吸收 TopDown | 地图状态、场景切换、过渡委托、检查点栈、MapDataBlock、玩家传送和复活；TopDown 提供有序检查点和重生延迟样板 | `Assets/Scripts/GameCore/Runtime/Game/Systems/MapSystem.cs`、`GameManager.MapSystem`、`GameRuntimeEvents.MapTransitionDelegationRequestedEvent` | `TeleportTo`、`RespawnPlayer`、`TeleportToPlaytestStartPosition` 已在正式文件中；当前新增活动 `MapInfo` 缓存、有序检查点状态、默认出生点入口和按地图配置延迟重生；若要求真实可跑，仍依赖玩家实例、检查点资产和场景接线 | 保留为正式地图系统；进入业务阶段时再验证传送/复活链 |
| 2DRPGEngine 传送器 | `.../Maps/Teleporter.cs` | 本地源码，可复制 | 触发传送、方向限制、到达后保存检查点 | `Assets/Scripts/GameCore/Runtime/Maps/Teleporter.cs` | 代码闭包已迁入；当前正式世界穿越目标已显式收回 `PlayerSystem.PlayerInstance`，并吸收了 `uMMORPG Portal.cs` 的父级玩家解析规则。若要求真实可跑，仍依赖玩家死亡/移动方向/打断推力、音频事件，以及地图/检查点接线 | 保留为正式地图交互闭包；后续按玩法需求再验证场景接线 |
| 2DRPGEngine 命令 | `.../Commands/ICommand.cs` | 本地源码，可复制 | 异步命令执行合同 | `Assets/Scripts/GameCore/Runtime/Commands/ICommand.cs` | 已建立最小接口闭包；具体命令依赖 Player/Inventory/Map/UI/Dialogue，待对应闭包迁入后再复制 | 保留为正式命令合同 |
| 2DRPGEngine 命令数据/条件 | `.../Database/Utils/CommandHandler.cs`、`.../Commands/ExecuteCommandHandler.cs`、`ExecuteCommandIf.cs`、`.../Conditional/Conditions/ICondition.cs`、`ABaseCondition.cs`、`IsNot.cs`、`AreConditionsMet.cs` | 本地源码，可复制 | 命令资产包装、条件判断、条件命令执行 | `Assets/Scripts/GameCore/Runtime/Database/Utils`、`Assets/Scripts/GameCore/Runtime/Commands`、`Assets/Scripts/GameCore/Runtime/Conditional/Conditions` | 已迁入不依赖 Player/UI/Quest 的数据闭包；玩家长期真相相关命令入口现已显式收回 `PlayerSystem.PlayerInstance`，不再新增对旧静态玩家别名的依赖 | 保留为正式命令/条件数据闭包 |
| 已删除的 2DRPGEngine 通知系统 | `.../Game/Systems/NotificationSystem.cs` | 本地源码，可复制 | 旧 UnityEvent 通知中心，曾承接地图、存档、UI、战斗、音频等系统事件 | `Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.cs`、`GameManager` 生命周期分发、Yoki `EventKit.Type` | 旧通知中心文件、测试、场景对象与项目侧调用面都已删除；正式事件统一进入 GameCore 强类型事件结构 | 不保留旧通知系统；不得恢复任何等价大总线 |
| 2DRPGEngine 对话数据 | `.../Database/Dialogues/DialogueSequence.cs`、`.../Dialogue/DialogueNode.cs`、`DialogueTree.cs`、`DialogueUtils.cs`、`.../Miscellaneous/StringFormatter.cs` | 本地源码，可复制 | 对话序列资产、对话树节点、消息收集、术语替换 | `Assets/Scripts/GameCore/Runtime/Database/Dialogues`、`Assets/Scripts/GameCore/Runtime/Dialogue`、`Assets/Scripts/GameCore/Runtime/Miscellaneous/StringFormatter.cs` | 已迁入数据和树构建闭包；未迁 DialogueSystem、UI 播放、CharacterBase/NPC 交互执行层 | 保留为正式对话数据真相层，交互执行层继续后置 |
| 2DRPGEngine 交互 | `.../Interactions/IInteraction.cs`、`IInteractionTarget.cs`、`CommandInteraction.cs` | 本地源码，可复制 | 交互目标、交互执行、命令型交互 | `Assets/Scripts/GameCore/Runtime/Interactions` | 交互闭包已迁入；如果要求真实可跑，仍依赖 `CharacterBase`、对话播放链和角色/场景接线 | 保留为正式交互闭包；业务阶段再验证真实交互流程 |
| 2DRPGEngine 背包/物品 | `.../Game/Systems/InventorySystem.cs`、`.../Database/Items/Item.cs`、`Equipment.cs`、`ItemEffects/*.cs` | 本地源码，可复制 | 金钱、背包数量、装备/卸装、物品使用、物品效果、InventoryDataBlock | `Assets/Scripts/GameCore/Runtime/Game/Systems/InventorySystem.cs`、`Assets/Scripts/GameCore/Runtime/Database/Items` | 背包/物品闭包已迁入；`EquipmentSystem` 仍只是独立的换装表现候选，不等于正式背包玩法已接完 | 保留为正式物品地基闭包；玩法数据、UI 和角色联动留到业务阶段验证 |
| 2DRPGEngine 实体底座 | `.../Entities/Entity.cs` | 本地源码，可复制 | `EntityDataBlock`、位置/旋转/缩放持久化 | `Assets/Scripts/GameCore/Runtime/Entities/Entity.cs` | 已迁入不依赖 `IInteractionTarget`、`IInteraction`、Dialogue 和 UI 浮标的变换持久化闭包 | 保留为正式实体持久化底座 |
| 2DRPGEngine 移动/控制器/玩家 | `.../Entities/Movable.cs`、`.../Controllers/IController.cs`、`AController.cs`、`PlayerController.cs`、`.../Game/Systems/PlayerSystem.cs` | 本地源码，可复制 | 控制器数据块、控制器生命周期、移动实体、玩家输入宿主、玩家实例化/存档 | `Assets/Scripts/GameCore/Runtime/Entities/Movable.cs`、`Assets/Scripts/GameCore/Runtime/Controllers`、`Assets/Scripts/GameCore/Runtime/Game/Systems/PlayerSystem.cs` | 玩家与移动控制闭包已迁入；`Movable` 已明确吸收 TopDown `CharacterMovement.cs` 的方向模式、模拟输入、加减速、闲置阈值、移动禁止和上下文速度倍率；`PlayerController` 只额外补了 TopDown `Weapon/CharacterHandleWeapon` 风格所需的开火松开信号。若要求真实可跑，仍依赖 Rigidbody2D、动画策略、角色 Prefab、输入、死亡流程和场景接线 | 保留为正式玩家/控制器闭包；继续以 `Movable` 吸收 TopDown 手感和碰撞执行边界，不另起并行控制器 |
| UE 子系统范式 | Epic 官方文档 `USubsystem`、Gameplay Framework、ModularGameplay | 官方文档，辅助范式 | 系统有明确宿主和生命周期，Actor/Component/Pawn/Controller 是基础对象模型 | `RuntimeContext + EventBus + ModuleAsset` | 当前结构没有明确引擎宿主等价物，且不是 Unity/2DRPGEngine 可复制闭包 | 只能支持“不要空抽象”，不能作为当前实现合同 |
| EX-GAS 插件 | `Assets/Plugins/GAS` | 本地插件源码 | 已作为技能、属性、效果规则正式主轴 | 正式技能、属性和效果规则必须走 EX-GAS 正式链 | 项目侧第二收口已撤出；后续缺口优先在 GAS 主轴内补齐，不恢复旧 Ability/Effect/Stats 长期双轨 | 保留插件，正式接入和缺口修补都必须回到 EX-GAS 主轴验证 |
| BroAudio 插件 | UPM `com.ami.broaudio` | 包依赖 | 音频播放后端 | `Assets/Scripts/GameCore/Runtime/Audio`、`Assets/Scripts/GameCore/Runtime/Database/Audio`、`Assets/Plugins/BroAudio` | 当前已通过 `AudioClipResolver + AudioChannel + AudioSystem` 建立正式收口；旧 `AudioClip` 资产与 BroAudio `SoundID` 双轨共存 | 保留包、项目级配置和项目侧正式音频入口边界；业务层不得直调第三方 API |
| TopDownEngine Feedbacks | `Assets/Plugins/TopDownEngine/ThirdParty/MoreMountains/MMFeedbacks` | 本地插件源码，可配置 | 能力、武器、受击、死亡等表现反馈配置和播放 | `Assets/Scripts/GameCore/Runtime/Presentation/GameplayFeedbackSet.cs` | 当前已接入能力/武器生命周期、命中、受击、死亡、拾取和交互反馈；相机/屏幕反馈尚未补齐 | 保留为 GameCore 唯一 `MMFeedbacks` 配置入口边界；不接管生命、输入、伤害、玩家数据或 MoreMountains manager 生命周期 |
| EquipmentSystem | `Assets/Scripts/Presentation/EquipmentSystem` | 当前项目正式表现模块 | 换装/UV/像素装备表现 | `Assets/Scripts/Presentation/EquipmentSystem`、`Assets/GameData/EquipmentSystem`、`Assets/Scenes/EquipmentSystemDemo.unity` | 已脱离测试目录，但仍不是通用 Items 地基 | 保留为正式表现模块，不能通过 ItemsModule 强行升成完整物品系统 |
| TopDown Engine Common | `C:/Gamedev/Unity/Engine/TopDown Engine/TopDown Engine v4.1/Assets/TopDownEngine/Common/Scripts` | 本地源码，可复制但闭包很厚 | 俯视角控制器、角色能力组件、武器、拾取、机关、GUI、AI、管理器 | 当前未正式迁入 | 依赖 `MoreMountains.Tools`、`MoreMountains.InventoryEngine`、引擎级输入/事件/UI/manager 约定；若整套搬运会把当前地基从 `2DRPGEngine` 切到另一套范式 | 作为二级参考池，按模块逐段审查；仅在单模块明显优于现状时局部吸收 |
| TopDownEngine 导入子集 | `Assets/Plugins/TopDownEngine` | 当前项目已导入候选闭包 | 俯视角样板、MoreMountains 运行时、Koala2D demo 资源 | `Assets/Plugins/TopDownEngine` | 还没完成 Unity 导入编译核验，也还没裁决哪些模块升级成正式项目框架；随带 demo 美术资源只作参考，不进入正式美术口径 | 已进入工程，后续按模块做替换/吸收裁决；正式美术仍以 MiniFantasy 为基线 |
| Koala2D demo | `C:/Gamedev/Unity/Engine/TopDown Engine/TopDown Engine v4.1/Assets/TopDownEngine/Demos/Koala2D` | 本地样板资源 | 2D 地牢地图、门/传送门/推块/尖刺/钥匙门/武器拾取样板、Tilemap 组合 | 当前未正式迁入 | 自定义脚本只有 `DungeonDoor`、`DungeonPortal`、`WeightedRandomTile` 三个薄层；核心玩法依赖 `TopDownEngine/Common` | 不作为独立框架来源；后续只吸收样板场景和局部机关实现 |

## 参考偏离台账

<!-- FOUNDATION_DEVIATION_LEDGER -->
<!-- FOUNDATION_DEVIATION_RULES_ONLY -->
<!-- FOUNDATION_ITEMS_CANDIDATE_NOT_OFFICIAL -->

> 这里记录“不是直接照搬参考源码”的点。偏离只能是依赖剥离、语言/Unity 版本适配、缺失依赖闭包导致的临时裁剪，不能解释成新的框架设计。

| 当前落点 | 参考形状 | 当前偏离 | 偏离性质 | 当前处理 |
| --- | --- | --- | --- | --- |
| `GameManager` | `GameManager` 使用 `m_config`、`m_systems`、系统静态访问和内部生命周期分发 | 增加 `sealed`、`DisallowMultipleComponent`、`DefaultExecutionOrder`、中文 Inspector 文案；缺系统/重复系统时抛异常而不是只 `Debug.Assert`；生命周期事件已经收回 `GameRuntimeEvents`，不再转发旧通知中心 | Unity 组件安全和失败显式化，不是新架构 | 保留；这是工程性增强，不得继续扩展成第二生命周期入口 |
| `GameConfig` | `GameConfig : DatabaseEntry`，包含 RPG/战斗/UI/术语字段和 `SerializableDictionary` | 当前仍只保留地基必需字段；`persistentIdentifierMappings` 已回到参考字典形状，同时 `databaseRegistry/playtestSaveFile` 两条原始资产口子已经收回成拥有者方法 | 业务闭包裁剪 + 正式读取口收口 | 保留为正式配置真相宿主；当前缺的是后续业务配置继续按参考逐项回补，不是架构待定，不得用自造配置字段替代参考字段 |
| `DatabaseRegistry` | 使用第三方 `SerializableDictionary<string, DatabaseEntry>` 和 `SerializableDictionary<string, string>` | 当前已迁入参考第三方依赖并回到字典形状；未回补的是自动扫描/更大业务闭包，不是数据容器形状 | 已收敛依赖偏离 | 保留为正式数据库真相层；后续优先在此基础上继续照搬相关数据库资产 |
| 已删除的 `NotificationSystem` | 参考文件一次性包含 Gameplay、UI、Audio、Quest、Inventory、Player 等业务事件 | 当前已整体移除，并用门禁禁止其任何文件、场景对象或调用面回归 | 旧大总线职责已被 `GameRuntimeEvents + EventKit.Type` 取代 | 已收口；后续只继续精炼强类型事件边界 |
| `MapSystem` | 完整包含 `RespawnPlayer`、`TeleportTo`、`TeleportToPlaytestStartPosition` 和玩家检查点恢复 | 当前已恢复参考里的传送/复活入口，并把世界穿越目标显式收回 `PlayerSystem.PlayerInstance`；额外补了 `MapInfo` 正式注册缓存、按地图配置延迟重生，以及失效保存位置回退到初始出生点的健壮性规则 | 参考回补 + 单一真相收口 | 保留；当前不再是“半 MapSystem”，后续只继续深化实例宿主/出生点分流之外的地图表现链 |
| `Persistable.Destroy()` | 参考直接调用 `m_executeOnDeath?.Execute()` | 当前仍直接调用 `m_executeOnDeath?.Execute()`；`ICommand.Execute()` 返回 `Task`，但销毁点继续保持 fire-and-forget 语义 | C# 异步命令调用的语言适配 | 保留；当前行为已经和参考销毁链同形，不代表新增异步执行框架，后续若接入命令调度器必须另建参考矩阵 |
| `PersistenceSystem.GetActualIdentifier()` | 直接访问 `GameManager.Config.persistentIdentifierMappings` 字典 | 当前仍通过 `GameConfig.GetActualPersistentIdentifier()` 包装读取，但底层数据已回到参考字典形状 | 轻量 API 包装 | 保留；这是 `PersistenceSystem` 内部薄 helper，用来把系统层读取统一收回 `GameConfig` 显式 API，不允许扩展成第二套存档映射系统 |
| `EquipmentSystem` | 不属于 `2DRPGEngine` 的正式 Inventory/Item/Equipment 闭包 | 当前作为 MiniFantasy UV/换装表现模块保留 | 当前项目正式表现模块，不是基础物品规则框架 | 保留；不得包装成 `ItemsModule` 或宣称物品系统完成 |
| `Assets/Editor/GameCore/Bridge/BridgePollerRecovery.cs` | `2DRPGEngine` 编辑器参考里没有该文件 | AIBridge domain reload 轮询恢复钩子已并回正式 `Editor/GameCore` 目录 | GameCore 编辑器正式入口 | 保留；这是当前项目自动化链的正式恢复钩子，不再挂在过渡目录 |
| `Assets/Plugins/YokiFrame/Core/Editor/Kits/ResKit/CodeGen/AddressablesCodeGenerator.cs` | `2DRPGEngine` 编辑器参考里没有该文件 | 强类型资源/场景/文本入口生成器已并入 `YokiFrame` 本体，生成 `FWRes/FWScene/FWText` 到 `Assets/Scripts/GameCore/Runtime/Resources/Generated` | YokiFrame 本体吸收 | 保留；这是确认比原 `YokiFrame` 更强且有明确收益的能力 |
| `FoundationSupport runtime helpers` | `2DRPGEngine` 运行时参考里没有 `RuntimeLogOverlay`、`FWRes/FWScene/FWText`、`UIPointerUtility`、`UITipsService` 等文件 | 原过渡目录已清空；其中按 owner 绑定协程 / 强类型 Key / 组件事件桥接 / GameObject 池能力已归入 `YokiFrame` 本体；参考自带的通用 `CoroutineHelpers` 已从正式运行时排除，`CommandTrigger` 的可配置帧延迟只保留为组件内部协程；UI 小工具 / 日志叠层 / 生成产物已归入正式 `GameCore` 目录 | 历史过渡目录 | 已收敛完成；不再作为当前仓库有效代码承载层 |
| `Combat/Weapons/WeaponExecutionRuntime.cs`、`WeaponExecutionSettings.cs`、`WeaponHitWindowRuntime.cs` | `2DRPGEngine` 主动能力没有独立武器执行状态机；TopDown `Weapon/CharacterHandleWeapon` 提供更成熟的攻击节奏、输入缓冲、连发、弹匣和换弹模式；TopDown `MeleeWeapon/DamageOnTouch` 提供短时命中区域、忽略 owner、重复命中控制、击退和受击保护参数 | 当前在 `GameCore` 正式代码内吸收 TopDown 武器执行模式，`ActiveAbilityBase` 管状态机、资源消耗、冷却和行动锁，具体能力只执行一次真实出手；近战命中由 `WeaponHitWindowRuntime` 管命中窗口和每目标冷却；击退模式、击退强度、阻力和短暂无敌沿 `EffectImpactSettings -> CharacterBase.Damage` 传递；不依赖 MoreMountains manager、GUI、InputManager 或 Health | TopDown 动作执行层正式吸收 | 保留；这是当前正式动作执行闭包。伤害、生命、阵营、存档和效果仍回到 2DRPG RPG 规则真相；投射物持久化池化规则只属于后续深化，不再算同职责裁决未定。 |
| `Combat/Abilities/AbilityPermissionSettings.cs`、`Combat/Abilities/AbilityBase.cs` | `2DRPGEngine` 主动能力权限分散在 `CanFire()`、角色动作锁和具体能力子类；TopDown `CharacterAbility` 有统一许可、移动/条件/武器状态阻断和动画更新触点 | 当前在 `GameCore` 正式代码内吸收 TopDown 权限模式，`ActiveAbilitySheet` 持有权限配置，`ActiveAbilityBase.CanFire()` 统一调用，`CharacterBase` 只提供 GameCore 自己的其它能力武器状态查询，`AbilityBase.UpdateAnimationState()` 提供动画状态更新触点；不依赖 TopDown `Character`、`Health`、`InputManager` 或 MoreMountains 状态机 | TopDown 能力权限正式吸收 | 保留；这是动作地基第一段收口，不是兼容层。后续具体能力只扩展这条权限配置，不在控制器或能力子类里继续散落重复阻断。 |
| `Presentation/GameplayFeedbackSet.cs` | `2DRPGEngine` 没有同等级反馈配置入口边界；TopDown/MoreMountains 的 `MMFeedbacks` 提供成熟的 Inspector 反馈组合和播放入口 | 当前只允许该文件直接持有 `MMFeedbacks` 并调用 `PlayFeedbacks`，服务能力开始/停止、武器开始/使用/停止和换弹/打断、命中、受击、死亡、拾取和交互反馈；其它业务类不得散落 `MMFeedbacks` 字段 | TopDown 表现反馈层正式吸收 | 保留；这是表现入口边界，不是生命周期或规则真相。相机/屏幕反馈继续沿该入口边界或同等级正式边界扩展。 |
| `Runtime patched paths` | `2DRPGEngine` 参考原文件被直接改造：`AudioChannel.cs`、`AudioClipResolver.cs`、`ActiveAbilityBase.cs`、`MeleeAttackAbility.cs`、`SelfCastAbility.cs`、`EffectDispatcher.cs`、`AEffect.cs`、`ImmediateDamageEffect.cs`、`TemporalDamageEffect.cs`、`PerTargetCooldown.cs`、`ActiveAbilitySheet.cs`、`PlayerController.cs`、`CharacterBase.cs`、`Movable.cs`、`AudioSystem.cs`、`InputSystem.cs`、`SaveSystem.cs`、`FloatingText.cs`、`FloatingTextPool.cs`、`UICharacterInfo.cs`、`UIEffectList.cs`、`UIEventLog.cs`、`UIAbilities.cs`、`UIHUDEffectBar.cs`、`UICraft.cs`、`UIJournal.cs`、`UIShop.cs` 等；旧 `DashAbility.cs`、`ProjectileAbility.cs`、`SummoningAbility.cs` 已从当前项目侧运行时退场 | 当前改动曾把参考运行时接到池化、指针工具、音频补强，以及现已收回 `YokiFrame.ActionKit.CoroutineKit` 的低 GC helper / owner 协程能力上；`FloatingText.cs`、`FloatingTextPool.cs`、`UIHUDEffectBar.cs`、`UICharacterInfo.cs`、`UIEffectList.cs`、`UIEventLog.cs`、`UIAbilities.cs`、`UICraft.cs`、`UIJournal.cs`、`UIShop.cs` 已进一步收敛到 YokiFrame `GameObjectPoolService`，不再维护项目侧 `InstancePool`、浮字数组池、自管裸实例或 UI 列表反复销毁重建；`Movable.cs` 保留 2DRPG 实体/控制器/存档语义，同时吸收 TopDown `CharacterMovement` 的方向模式、模拟输入、加速、减速、闲置阈值、移动禁止和上下文速度倍率；`SaveSystem.cs` 保留 2DRPG `SaveDataBlock` 世界状态聚合，文件槽位/版本/元数据承载改用 YokiFrame SaveKit；`InputSystem.cs` 保留 2DRPG Gameplay/UI action 语义、`PlayerInput` 生命周期和地图切换锁输入，绑定导出/导入、保存/加载、重置、显示名和冲突查询改用 YokiFrame InputKit；项目侧旧冲刺、投射物和召唤主动能力族不再作为当前能力系统运行时补丁保留，后续同类能力必须用 EX-GAS Ability / Timeline / GameplayEffect / Cue 重新表达 | 历史参考补丁 + 已确认工具层/动作执行层吸收 + GAS 能力重构清退 | 保留剩余仍有效的基础运行时补丁；`Sync-2DRPGFoundation.ps1` 与 `Test-FoundationReferenceParity.ps1` 已移除旧 `DashAbility` / `ProjectileAbility` / `SummoningAbility` 和对应旧表清单，避免参考同步把已清退旧能力族重新拉回当前工程。后续只有在进入真实玩法阶段时，才继续评估通用 `Projectile` 实体、投射物池化、玩家移动碰撞边界和真实存档场景接线这些深化项。 |
| `2026-06-13 GameCore / Editor 目录对照` | `2DRPGEngine/Assets/Mythril2D/Core/Runtime/Scripts` 与 `.../Core/Editor/Scripts` | `Assets/Scripts/GameCore/Runtime` 与 `Assets/Editor/GameCore` 已按参考整段同步；项目侧额外保留 `AudioChannelFallbackPlayer`、运行时日志叠层、`FWRes/FWScene/FWText` 生成产物、UI 指针与 Tips 小工具、AIBridge 轮询恢复钩子；当前已登记参考补丁包含音频入口边界、TopDown 风格移动参数、浮字池化、角色状态图标、效果列表池化、事件日志行池化、能力列表池化、制作配方/材料条目池化、任务日志条目池化、商店条目池化、HUD 效果栏池化、对话框指针修正，以及 `PersistableProcessor` 无弹窗编辑期自动修复等路径；`Pooling/InstancePool.cs` 已明确从当前正式地基排除。 | 参考同步 + 已登记项目扩展 | 目录落点合理；已把这些扩展写入 `Test-FoundationReferenceParity.ps1` 与 `Sync-2DRPGFoundation.ps1` 的保留/排除名单，避免后续对齐参考时误删、误回写、误恢复旧池、误恢复阻塞式编辑器弹窗或误回退移动吸收。 |

## 业务闭环依赖拆解

| 参考文件 | 可直接迁入程度 | 直接依赖 | 当前结论 |
| --- | --- | --- | --- |
| `Maps/Teleporter.cs` | 代码可存在，但单文件不等于功能闭环 | `PlayerSystem.PlayerInstance`、`Hero.dead`、`IsMovingUp/Down/Left/Right()`、`InterruptPush()`、`GameRuntimeEvents.RequestAudioPlayback(...)`、`MapSystem.TeleportTo()`，以及来自 `uMMORPG Portal.cs` 的 `GetComponentInParent<Hero>()` 入口解析规则 | 当前已作为正式闭包存在；只有在玩家实例、音频事件、检查点和场景接线都补齐时，才能把它当成真实可用传送链 |
| `MapSystem.TeleportTo/RespawnPlayer/TeleportToPlaytestStartPosition` | 代码可存在，但单 API 不等于功能闭环 | `PlayerSystem.PlayerInstance.Revive()`、`PlayerSystem.PlayerInstance.TeleportTo()`、有效检查点栈、`MapInfo.playtestCheckpoint`、`MapInfo.initialSpawnCheckpoint` | 当前 API 已存在；只有在玩家实例与检查点资产接线真实存在时，才能把它们当成真实传送/复活链 |
| `Controllers/IController.cs` | 不能脱离 Movable 单独迁 | `Initialize(Movable movable)`、控制器数据块 `IControllerDataBlock`、`IDataBlockHandler` | 当前禁止控制器接口空壳；迁入时必须连同 Movable 数据块和生命周期一起对齐 |
| `Controllers/AController.cs` | 不能脱离 Movable 单独迁 | `AController<T> where T : Movable`、运行状态、生命周期、数据块保存/加载 | 当前禁止抽象控制器空壳；不能把它改成泛用服务或输入模块 |
| `Controllers/PlayerController.cs` | 不能直接把“类已存在”当成“俯视角玩家控制器已定稿”，但它已经是当前正式控制器入口之一 | `CharacterBase`、参考 InputSystem actions、Interaction、Ability、Audio、UI 菜单事件、当前受控 `Hero.equippedAbilities`；当前额外补丁只对应 TopDown `Weapon/CharacterHandleWeapon` 的 release/stop-fire 语义，以及 `IPlayerInputTarget` 正式输入目标合同 | 正式闭包已存在；后续应直接在该文件上继续对齐参考与补验证，不得再新开并行 test 控制器路线 |
| `Entities/Movable.cs` | 代码可存在，但组件链未接完时不能当成真实移动玩法；同时它已经是当前正式控制器入口之一 | `Rigidbody2D`、`IAnimationStrategy`、`IController`、碰撞派发、伤害/推力、音频、`GameConfig` 碰撞/战斗字段；当前动作执行层额外字段和行为明确对齐 TopDown `CharacterMovement.cs`；已新增 `MovableMovementTests` 验证速度上下文、移动禁止和推力生命周期。该测试只保护已登记的 TopDown 参考吸收，不构成追加项目侧自写移动逻辑的依据。 | 当前已作为正式移动闭包存在；只有在组件与参数接线完成时，才把它当成真实移动系统，但验证也必须围绕它本身进行，不得另起并行试做控制器 |
| `Entities/Characters/CharacterBase.cs` / `Hero.cs` | 代码可存在，但不能把“角色类存在”误说成“玩家流程可玩” | Stats、Ability、TemporalEffect、Damage、Equipment、Audio、Notification、Database、Inventory、HeroDataBlock | 当前已作为正式闭包存在；后续按业务目标决定要接到多深 |
| `Game/Systems/PlayerSystem.cs` | 代码可存在，但单系统不等于真实玩家链；不过它现在已经承担“玩家 Hero 真相”和“当前输入目标切换”两件正式职责 | `Hero`、`PrefabReference`、`PersistenceSystem.InstantiateCustom`、`Constants.UniquePlayerIdentifier`、死亡流程、Dialogue/UI 关闭事件、`GameConfig.toExecuteOnPlayerDeath`，以及 `IPlayerInputTarget/currentInputTarget/currentControlledCharacter` | 当前已作为正式玩家闭包的一部分存在；输入目标接口当前已落地，但玩家 Prefab、死亡动作、场景接线和世界层大量“长期玩家 Hero / 当前控制对象”语义仍未继续向控制组和世界层收口前，仍不能把它说成完整玩家闭环 |

## 不应继续作为正式地基的部分

| 当前对象 | 当前问题 | 证据 | 建议 |
| --- | --- | --- | --- |
| `FantasyWordBootstrapper.cs` | 自造入口，未对齐 `GameManager` | `2DRPGEngine` 已有 `GameManager` 同职责源码 | 替换为 `GameManager` 风格入口，或暂时标待决 |
| `FantasyWordRuntimeContext.cs` | 自造上下文容器，未证明必要 | `2DRPGEngine` 用 `GameManager` 静态入口和系统表，UE 用明确生命周期宿主的 Subsystem | 撤出正式合同 |
| `FantasyWordServiceRegistry.cs` | 自造服务注册表 | 参考侧未用项目级 IOC/ServiceRegistry 承担基础地基 | 删除或降级为实验，先不用它定义架构 |
| `FantasyWordEventBus.cs` | 自造跨模块事件总线 | 当前正式事件机制已固定为 `GameRuntimeEvents + EventKit.Type`，不再需要第二套总线 | 不作为地基入口；若未来新增事件，只能进入正式强类型事件结构 |
| `FantasyWordModuleAsset.cs` / `IFantasyWordModule.cs` | 自造模块资产模型 | `2DRPGEngine` 用 `AGameSystem` 场景组件，不用 ScriptableObject 模块安装器 | 撤出正式链路 |
| `FantasyWordModuleInstaller.cs` | 自造模块安装器 | 没有成熟参考；当前测试只证明它自己能跑 | 删除正式要求，场景改回参考风格系统挂载 |
| `CharactersModuleAsset` | 空模块式角色合同 | 未对齐 `Entity/Controller/CharacterSheet` | 降级，后续按角色闭包重建 |
| `WorldModuleAsset` | 抽象世界意图队列 | 未对齐 `MapSystem/MapInfo/Teleporter/IInteraction` | 降级，后续按地图/交互闭包重建 |
| `ItemsModuleAsset` | 抽象物品请求队列 | 未对齐 `InventorySystem/Item/Equipment/ItemEffect` | 降级，保留 EquipmentSystem 候选但不升正式 |
| `CombatModuleAsset` | 抽象战斗请求队列 | 未对齐 2DRPGEngine ability/effect，也未正式接入 EX-GAS | 降级，后续以 EX-GAS 或 2DRPGEngine ability/effect 为基线 |
| `PresentationModuleAsset` | 抽象表现事件队列 | 未对齐成熟表现系统；当前正式音频入口边界已收口到 `GameCore`，不再需要它代管 BroAudio | 降级，不得再作为音频正式入口 |
| `Assets/GameData/GameCore/Modules/*.asset` | 为自造模块提供资产真相 | 它们反向固化了不可信模块链，当前已撤出 | 不得重新作为正式验收对象 |
| `scripts/Invoke-FoundationStaticGate.ps1` | 已改为保护新闭包 | 当前脚本检查 `GameManager + AGameSystem + GameConfig`、`SampleScene` 新接线并拒绝旧 Bootstrapper/Installer 场景残留 | 后续继续扩展到 Database/Map/Persistence/Command 闭包 |
| `Assets/Tests/EditMode/GameCore/Foundation/*` | 测试保护了自造 Registry/Context/EventBus/Installer | 测试对象就是被质疑结构，当前已撤出 | 不得恢复为完成证据 |
| `Assets/Tests/EditMode/RuntimeContracts/ModuleContracts/*` | 旧测试保护五大模块和事件队列 | 测试让“空模块能安装”变成完成证据，当前只保留 EquipmentSystem 候选测试 | 后续新增测试必须保护参考闭包 |
| `openspec/changes/define-fantasyword-foundation-framework/*` | 旧 change 把自造方案写成正式规格 | design/spec/tasks 已改为 `GameManager + AGameSystem` 基线 | 后续继续补 Database/Map/Persistence 等闭包 |
| `.spec/knowledge/features/project/代码参考矩阵.md` 中 `REF-FW-GAMECORE-FOUNDATION` | 自证循环，不是成熟参考 | 来源只指向 FantasyWord 自己的文档和 OpenSpec | 改为 `REF-2DRPG-FOUNDATION` 等外部参考 |
| `.spec/knowledge/features/project/框架与运行时入口.md` 中四条事件链 | 把自造事件总线升为默认协作方式 | 未对齐 `ICommand/IInteraction/GameRuntimeEvents` | 改为待决或移除 |

## 可保留但必须降级的部分

- `Assets/Scripts/Presentation/EquipmentSystem`：当前项目正式装备/换装表现模块。当前不能把它直接说成正式 `Items` 物品/背包规则地基。
- EX-GAS 不得再预留项目侧第二收口路径。第三方 GAS 当然不能散落到玩法层，但这不等于要再造一层 `Combat/EXGAS` 包装；后续若 EX-GAS 胜出，应直接把正式所有权接回 `GameCore` 对应闭包，并让旧 `Stats/Effect/Ability` 同职责入口退场。
- BroAudio 已经不是纯候选：当前正式入口是 `AudioClipResolver + AudioChannel + AudioSystem`。后续若扩展更大表现层，也必须在这套正式入口边界之上演进，不能再回到散落直调第三方 API。
- 旧 `Assets/GameData/Combat/Definitions`、`Assets/GameData/Presentation/Audio`、`Assets/GameData/Items/Equipment` 当前不作为正式样例资产目录；若后续需要，应按新矩阵重建。

## 下一步实施顺序

1. 当前地基阶段已完成代码闭包迁入；下一步不再以“文件是否存在”作为问题，而是区分“闭包成立”与“业务闭环是否接线完成”。
2. `SaveSystem`、`PlayerSystem`、`Teleporter`、`MapSystem`、`InventorySystem`、`Interaction`、`Movable/Controller` 后续按是否要进入真实玩法链来决定接线深度，而不是再讨论是否应当迁入。
3. 每次进入真实玩法或真实场景接线前，再补对应的资产、Prefab、场景、组件和测试证据；不要把“业务未接线”回写成“正式闭包不存在”。
4. 每轮对齐参考或补闭包后，同步更新参考矩阵、静态门禁和验证记录，避免活文档再残留旧阶段判断。

## 当前未完成

- 本文只是第一轮审计留档，不代表迁移完成。
- 已开始实施参考对齐代码闭包，场景接线已改为 `GameManager`，旧 `Bootstrapper/RuntimeContext/ModuleInstaller/EventBus` 链路已从正式代码和测试中撤出，Database/PrefabReference 最小闭包已接入 `GameConfig` 和 `GameManager.Database`，`ICommand` 已作为命令最小合同迁入，旧 `NotificationSystem` 已彻底删除并由 `GameRuntimeEvents + EventKit.Type` 取代，`GameFlagSystem` 已作为轻量状态系统迁入，`ICheckpoint/SimpleCheckpoint/CheckpointUtil/MapInfo/Checkpoint/MapSystem` 已作为不依赖 Player 的地图闭包迁入，`Persistable/PersistableReference/PersistenceSystem` 已迁入，`Entity` 变换持久化底座已迁入，SaveSystem 聚合存档仍待上层系统闭包。
- `2026-06-14` 已重新复核通过的是 parity、静态门禁、WorkspacePreflight、PluginFacadeBoundaryGate、EquipmentSystemStaticGate 与 OpenSpec strict，以及 `verification-notes.md` 中记录的 AIBridge 冒烟与资产合同测试结果；后续若工作区继续大改，仍需按最新状态重跑。
- 当前未完成的是基于最新工作区状态的 Unity 导入编译、场景/Prefab/资源接线全量收口，以及把历史 Unity 验证结果按最新工作区状态再跑一轮。
- `2026-06-14` 复跑 `scripts/Invoke-WorkspacePreflight.ps1` 的当前结果为通过：`PendingEmptyDirCount = 0`、`ContractPlaceholderCount = 9`；其中 `YokiFrame` 下的结构占位目录继续只作留档，不作为待清理垃圾，也不再构成 `pending empty dirs`。
- 尚未下载 UE 源码；当前 UE 仅使用官方文档作为辅助范式证据，直接实现合同仍以本地 `2DRPGEngine` 为准。
