# Task Plan: FantasyWorld 恢复并迁移到 FantasyWord

## Goal
在 `C:\Gamedev\Unity\Project\FantasyWord` 中恢复并迁移旧项目 `FantasyWorld` 的核心自研系统，优先保证自研脚本、框架逻辑和关键玩法链路可编译、可继续扩展，插件与素材损坏可后补。

## Current Phase
Phase 6

## Dressing Scope Correction 2026-03-13
- `Assets/Scenes/SampleScene.unity` 仍然是当前唯一保留的测试场景。
- 不能再把 `Assets/Database/Items/Gear/ITEM_Iron_Helmet.asset`、`Assets/Database/Items/Gear/ITEM_Iron_Plate.asset`、`Assets/Database/Items/Gear/ITEM_Iron_Boots.asset` 当成“可见换装素材”；它们只适合做装备功能占位验证。
- 当前主线要拆成两个里程碑：
- `装备功能可用`：玩家进场、背包起始装备、装备/卸下、槽位和属性变化。
- `装备显示可见`：需要一条真实可见的资源链，当前仓里还不存在。
- 目前已确认的显示链缺口：
- 当前仓里没有 `Assets/Sprite Libraries/Weapons/**`。
- 当前仓里没有与武器显示配套的能力 prefab 资源链。
- 旧备份 `E:\back\gameObject\project\FantasyWorld\Assets` 里也没有 `Database/Items`、`Sprite Libraries`、`Prefabs/Abilities` 可直接恢复。
- 下一步只能二选一：
- 方案 A：把 `SampleScene` 明确定义为“装备功能测试场景”，不再把它描述成已具备可见换装素材。
- 方案 B：先迁入参考工程的最小武器显示链，再继续做“可见换装”验收。

## Current Focus 2026-03-12 Dress-Up Scene
- 用户已明确本轮只保留 `Assets/Scenes/SampleScene.unity` 作为测试换装场景，不再继续推进 `Main Menu`、村庄或森林场景。
- 已完成 `Assets/Scripts/Game/GameManager.cs` 宿主修复：从静态类恢复为可挂载 `MonoBehaviour`，同时保留 `GameManager.Xxx` 静态快捷入口。
- 已补齐 `0_Entity_Base.prefab -> 0_Character_Base.prefab -> 0_Hero_Base.prefab -> Devon.prefab` 宿主链，并把 `0_Hero_Base.prefab` 的旧 `PixelPerfectCamera` GUID 改写到当前包 GUID。
- 已本地创建最小 `Assets/Database/Characters/Heroes/CS_Devon.asset`，并把 `Assets/Prefabs/Entities/Characters/Heroes/Devon.prefab` 的旧字段 `m_sheet` 改成当前字段 `m_characterSheet`。
- 已新增测试装备 `ITEM_Iron_Helmet` / `ITEM_Iron_Plate` / `ITEM_Iron_Boots`，并写入 `Assets/Scenes/SampleScene.unity` 的 `Inventory System.startingItems`。
- 静态验证结果：`Devon.prefab` 直连缺口归零；`0_Entity_Base.prefab` / `0_Character_Base.prefab` / `0_Hero_Base.prefab` 仅剩 Unity 内置材质 GUID；`SampleScene.unity` 仅剩 Unity 内置环境 GUID `0000000000000000e000000000000000`。
- 代码验证结果：Unity Roslyn 通过，但 `Assembly-CSharp.codex-validate.rsp` 仍需显式追加 `AudioChannel.cs` / `GameStateSystem.cs` / `NotificationSystem.cs` / `PersistenceSystem.cs` / `IUIMenu.cs` / `EItemTransferType.cs` / `AudioClipResolver.cs` 后才可信。
- 当前剩余真实风险是 Unity Editor 内的进入场景实测；现有测试装备先覆盖“可拾取/可装备/属性可流转”，未继续追整套外观替换资源。

## Dress-Up Scene Revalidation 2026-03-12
- 重新扫描 `Assets/Scenes/SampleScene.unity`、`Assets/Prefabs/Entities/0_Entity_Base.prefab`、`Assets/Prefabs/Entities/Characters/0_Character_Base.prefab`、`Assets/Prefabs/Entities/Characters/Heroes/0_Hero_Base.prefab`、`Assets/Prefabs/Entities/Characters/Heroes/Devon.prefab` 后，先前看似残留的 `0cd44...` / `dc427...` / `62899...` / `fe87...` / `30649...` / `3245...` / `59f814...` / `67db...` / `f468...` / `c29cff...` / `ed8b...` 全部可在当前 `Library/PackageCache` 解析到 `UGUI`、`InputSystem`、`2D Animation` 包组件，不属于真实缺失。
- `Assets/Scenes/SampleScene.unity` 已确认 `Inventory System.startingMoney = 250`，且 `startingItems` 直接绑定 `ITEM_Iron_Helmet`、`ITEM_Iron_Plate`、`ITEM_Iron_Boots`。
- `Assets/Scenes/SampleScene.unity` 已确认 `Player System.m_dummyPlayerPrefab` 指向当前项目内的 `Assets/Prefabs/Entities/Characters/Heroes/Devon.prefab`。
- 当前单场景目标的可信静态结论是：测试换装场景所需宿主、测试角色和起始装备都已就位；剩余风险只在 Unity Editor 内实际进场与装备显示行为。

## Long-Term Track 2026-03-12 Dress-Up Scene
- 用户修正后的范围定义是：场景数量只保留 `Assets/Scenes/SampleScene.unity` 这一个测试场景，但长期主线仍然包含运行验证、换装功能、换装显示、回归交接这几类工作，不等于“只剩一个任务”。
- 长期目标收敛为：把 `Assets/Scenes/SampleScene.unity` 做成一个可重复进入、可验证换装链路、可持续维护的单场景测试沙盒。
- 交付定义收敛为：`Devon` 能稳定生成，背包里自带 3 件测试装备，装备流转可验证，必要时外观变化可见或被明确记录为当前非目标。
- 明确不纳入本条长期线的事项：`Main Menu`、村庄/森林等多场景恢复，整棵旧角色数据库迁移，旧存档模板全量兼容。

### Milestone A: 运行时进场验证
- [ ] 在 Unity Editor 中打开 `Assets/Scenes/SampleScene.unity`
- [ ] 进入 Play Mode，确认 `Game Manager`、`Player System`、`UI System`、`Inventory System` 都能初始化
- [ ] 确认 `Devon` 实例实际生成，且没有阻断换装测试的 Missing Component / NullReference
- 已补充自动化抓手：`Assets/Scripts/_Editor/Playtest/DressUpSceneValidator.cs` 可用于单场景进场与换装闭环验证；当前已通过 Roslyn 复编，但在本沙箱里用 Unity `-batchmode -executeMethod` 运行时仍会被 `LocalLow/Unity` 权限和 UPM IPC 提前阻断。
- Exit Criteria: 场景能稳定进场，且不出现阻断测试的运行时错误

### Milestone B: 换装功能验证
- [ ] 确认起始背包中确实存在头盔、胸甲、靴子 3 件测试装备
- [ ] 确认装备/卸下会更新槽位占用、物品归属和角色属性
- [ ] 确认不会出现复制、吞物品或装备状态错乱
- Exit Criteria: 3 件测试装备都能稳定完成一次装备和卸下闭环

### Milestone C: 换装显示验证
- [ ] 追踪 `Wearable` -> 角色显示刷新 -> Sprite Library / visual override 链路
- [ ] 确认头盔、胸甲、靴子至少有一件能触发可见外观变化，或明确记录当前测试只验证数值/槽位流转
- [ ] 若显示链路有缺口，仅在 `SampleScene -> Devon.prefab` 这条链上做薄修复，不外扩到整套角色资源恢复
- 当前静态结论：`ITEM_Iron_Helmet` / `ITEM_Iron_Plate` / `ITEM_Iron_Boots` 的 `equippedSprite` 与 `visualOverride` 仍为空，且 `Devon.prefab` / `0_Hero_Base.prefab` 未挂 `EquipmentSpriteLibraryUpdater`；因此“换装可见”目前不能默认成立。
- Exit Criteria: “换装是否可见”有明确结论，且对应的技术边界被写入记录

### Milestone D: 回归与交接
- [ ] 固化一套最小验证流程：GUID 扫描口径 + Unity Roslyn 校验命令 + Unity Editor 手动 smoke test
- [ ] 把运行时结论、剩余风险和后续建议写回 `task_plan.md` / `findings.md` / `progress.md`
- [ ] 如场景已可用，整理一份只面向该测试场景的交接说明
- Exit Criteria: 下一个会话无需重新摸索即可继续推进或复验

## UI Closure Update 2026-03-12
- [x] 对齐剩余 10 个 UI 脚本 meta GUID：`UIHUDAbilityBarEntry`、`UIStatBar`、`UIAbilityBarEntry`、`UINavigationCursorTarget`、`UIAbilityListEntry`、`UIIngredientEntry`、`UIRecipeEntry`、`UIJournalQuestEntry`、`UIShopEntry`、`UIEffectListEntry`
- [x] 迁入尾部 UI 资源闭包：`Ability.prefab`、`Effect List Entry.prefab`、`EffectIcon.prefab`、`Bag item Slot.prefab`、`Category Entry.prefab`、`Equipment Slot.prefab`、`ItemNavigationCursorStyle.asset`、`SPS_Armors.png`、`SPS_Effects.png`
- [x] 清理 `Dialogue.prefab` 两处孤儿 `m_HighlightedSprite` 引用；对应 `Button` 都是 `m_Transition = 1`
- [x] 将当前 `Library/PackageCache` 纳入 GUID 扫描，消除 `UGUI` / `TMP` / `InputSystem` 假阳性
- [x] 用 Unity Roslyn 重新验证 `Assembly-CSharp.codex-validate.rsp` + 11 个追加源码，退出码 `0`
- 当前参考宿主缺口：
  - `M2DEngine.unity`: `1`，仅剩 `0000000000000000e000000000000000`
  - `Main Menu.unity`: `3`，剩余 `0000000000000000e000000000000000`、`357186adf88f47441beed107c9dbbe69`、`6a160d838ff8b4b4693ac20007e008c7`
  - `User Interface.prefab`: `1`，仅剩 `0000000000000000f000000000000000`
- 当前 `Assets/Prefabs/UI/**/*.prefab` 内部扫描只剩 6 个 `0000000000000000f000000000000000` 占位 GUID

## Additional Decision 2026-03-12-10
| Decision | Rationale |
|----------|-----------|
| GUID 差集扫描必须把当前 `Library/PackageCache` 一起纳入索引 | 否则会把 `UGUI` / `TMP` / `InputSystem` 包内脚本和资源误判成当前项目缺口，导致 `User Interface.prefab` 和整批 UI prefab 出现大量假阳性 |
| 对于 `Selectable` 组件里 reference/旧工程都找不到宿主的 `SpriteState` 资源引用，若 `m_Transition != SpriteSwap`，优先清掉死引用而不是继续追不存在的资源 | `Dialogue.prefab` 的 `7a7a...` 只用于两个 `Button` 的 `m_HighlightedSprite`，而这两个按钮走的是 `ColorTint`，清零不改运行时行为 |
| 当参考宿主和当前 UI prefab 内部只剩 `0000000000000000e/f...` 这类占位 GUID 与已知外部孤儿 GUID 时，停止继续扩张资源闭包 | 当前继续追 `Main Menu.unity` 的 `357186...` 或旧版 `PixelPerfectCamera` GUID 收益很低，已经超出“恢复当前宿主可识别资源”的有效范围 |

## Additional Decision 2026-03-12-11
| Decision | Rationale |
|----------|-----------|
| 场景层后续只保留一个“测试换装”场景，不再继续迁移或装配其它地图/菜单场景 | 用户已明确收窄目标；当前项目内可直接落地的可写场景只有 `Assets/Scenes/SampleScene.unity`，继续推进多场景没有必要 |
| “测试换装场景”的当前目标承载定为 `Assets/Scenes/SampleScene.unity`，参考宿主定为 `Mythril2D/Demo/Scenes/M2DEngine.unity` | 当前仓没有别的 gameplay 场景可直接承接，而 `M2DEngine.unity` 已包含 `Inventory System`、`itemEquipped/itemUnequipped` 链和 `User Interface` 宿主，最适合作为换装测试装配参考 |

## Scene Host Update 2026-03-12
- [x] 将 `Assets/Scenes/SampleScene.unity` 替换为 `M2DEngine.unity` 宿主骨架
- [x] 保留 `SampleScene.unity.meta`，维持当前场景 GUID 与 build settings 绑定
- [x] 验证 `SampleScene.unity` 直连缺口仅剩 `0000000000000000e000000000000000`
- [x] 验证 `ProjectSettings/EditorBuildSettings.asset` 中唯一启用场景仍为 `Assets/Scenes/SampleScene.unity`
- [x] 验证关键换装宿主存在：`Inventory System`、`Player System`、`UI System`、`Game Manager`、`Save System`、`Input System`

## Error Addendum 2026-03-12-UI
- `Assets/Plugins/ZFrame/RunTime/Manager/AGameSystem.cs` 是错误宿主路径，实际文件在 `Assets/Scripts/Game/Systems/AGameSystem.cs`
- `rg --files Assets\\Scripts Assets\\Plugins | rg 'AGameSystem\\.cs$'` 在当前 PowerShell 环境下会超时；已知目标应优先用更窄目录或直接路径
- 直接为整个 reference 树建立 `.meta -> guid` 索引在 20-30 秒窗口内容易超时；更稳的做法是“先扫 current 差集，再对缺失 GUID 定点反查”

## Strategy Update 2026-03-12
- For damaged or missing files:
  - directly migrate the same-name reference implementation first
  - then apply only thin compatibility edits required by the current project
- For intact files:
  - compare the old project version against the current recovered version
  - prefer the old project implementation when it is more complete or higher-quality
- Current application of this rule:
  - `Entities/Chest.cs` was binary-damaged in the old project
  - `Interactions/ChestInteraction.cs` was binary-damaged in the old project
  - `Loot.cs` / `ChestLoot.cs` were missing from the old project backup path checked in this session
  - therefore this batch was reworked from the `Mythril2D` same-name files instead of continuing the earlier adapted version

## Phases

### Phase 1: 损坏调查与清理
- [x] 调查旧项目脚本/Shader/素材损坏范围
- [x] 确认恢复优先级：自研脚本 > 框架 > 玩法系统 > 插件素材
- [x] 清理新项目中的二进制污染脚本
- [x] 修复 `UniTask`
- **Status:** complete

### Phase 2: 背包与基础玩法恢复
- [x] 恢复背包/换装主链
- [x] 恢复商店主链
- [x] 恢复制作主链
- [x] 跑 Unity 批处理编译验证
- **Status:** complete

### Phase 3: 任务与日志恢复
- [x] 恢复 `Quest` / `JournalSystem`
- [x] 恢复日志菜单 UI
- [x] 恢复任务交互、条件、命令
- [x] 恢复基础命令与基础条件
- [x] 跑 Unity 批处理编译验证
- **Status:** complete

### Phase 4: 角色与控制器主链
- [x] 恢复 `Movable`
- [x] 恢复 `Character` / `Hero` / `Monster` / `NPC`
- [x] 恢复 `IController` / `AController`
- [x] 恢复 `PlayerController` / `AIController` / `PlayerInputBridge`
- [x] 补齐与战斗系统衔接所需字段和接口
- [x] 跑 Unity 批处理编译验证
- **Status:** complete

### Phase 5: 战斗伤害与效果基础
- [x] 按 `Mythril2D` 水准重审 `DamageDescriptor`
- [x] 按 `Mythril2D` 水准重审 `DamageSolver`
- [x] 按 `Mythril2D` 水准重审 `CombatSolver`
- [x] 按 `Mythril2D` 水准重审 `EffectDispatcher`
- [x] 打通 AbilitySheet / ActiveAbilitySheet / Effect 接入
- [x] 打通 CharacterBase / UIEffectList / Projectile 所需承载接口
- [x] 跑 Unity 批处理编译验证
- **Status:** complete

### Phase 6: 后续缺口批量补齐
- [x] 恢复 `Commands/CompleteTask.cs`
- [x] 恢复 `Commands/AddOrRemoveAbility.cs`
- [x] 恢复 `ProjectileAbilitySheet` / `ProjectileAbility` / `Projectile`
- [x] 恢复 `UIEffectList` / `UIEffectDescription` / `UIEffectListEntry`
- [x] 恢复 `AudioSystem` / `UISystem` / `InputSystem`
- [x] 恢复 `HeroSheet` / `GameConfig` / Ability 栏位与 Ability UI 基础
- [x] 恢复 `UICharacter` / `UICharacterStat` / `UIStatBar` / `UICharacterInfo`
- [x] 恢复 `UIGameMenu` / `UIGameMenuEntry` / `UISettings*`
- [x] 恢复 `UI/HUD/Dialogue/*` 并将 `DialogueChannel` 改为可队列推进
- [x] 恢复 `Game/Events/GameEvents.cs` / `UI/HUD/EventLog/*` / `UI/FloatingTexts/*`
- [x] 恢复 `AUIMenu` / `UIDeath` / `UIControllerButton*` / `UINavigation*` / `UIPlayerControllerFeedback`
- [ ] 继续恢复 Ability / Combat / Characters 周边脚本
- [ ] 按 `missing-scripts-after-journal.txt` 逐批缩小差集
- [ ] 维护恢复记录与交接文档
- **Status:** in_progress

## Key Questions
1. 旧项目里哪些脚本还能直接作为参考，哪些必须重建？  
2. 哪些模块只需要“可编译主链”，哪些必须补到“可挂 Prefab 使用”？  
3. 角色/战斗层最小恢复边界放在哪里，才能继续往上补技能与怪物逻辑？  

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| 旧代码优先，坏文件重建 | 用户明确要求旧代码优先，但大量 `.cs` 已二进制污染 |
| 插件/素材损坏先不迁 | 用户允许后续重新导入，先抢救自研逻辑 |
| 以当前 `FantasyWord` 结构为主重建 | 新项目已建立可编译基线，盲目照搬旧结构风险更高 |
| 参考 `Mythril2D` / `JKFrame`，但不整包照搬 | 用户说明它们只是参考源 |
| 战斗基础旧文件内容损坏时，转用 `Mythril2D` 同职责实现做裁剪适配 | 旧项目 Combat 脚本文本已不可读，但文件职责和命名仍可沿用 |
| 每补一批主链就跑一次 Unity 批编译 | 降低大面积回归和定位成本 |
| `UISave*` / `UIMainMenu` 暂缓，优先做有现成宿主的死亡菜单与控制器 UI | 当前工程缺少可靠 save/load backend，但已有 `HeroKilled` / `DeathScreenRequested` / `InputSystem` / `EventSystem` 可承载这一组 |
| `ZFrame` 插件程序集内避免直接引用项目层 `GameManager` / `InputSystem` | 这类引用会在 `ZFrame.dll` 编译阶段失败；项目层输入分发应放在 `Assets/Scripts` 下的系统脚本里 |
| 先恢复高复用基础命令/条件 | 便于后续任务、菜单、交互、战斗模块复用 |

## Recovery Batch 15 Update 2026-03-12
- [x] 恢复 `Game/Systems/TransitionSystem.cs`
- [x] 恢复 `GamePlay/Maps/Teleporter.cs`
- [x] 恢复 `Interactions/InnInteraction.cs`
- [x] 将 `Game/Systems/MapSystem.cs` 从当前极简版升级为参考骨架版
- [x] 扩展 `ICheckpoint` / `SceneMgr` / `CharacterBase` / `Movable` 以承接地图切换与传送链
- [x] 跑 Unity 批处理编译验证（`unity-batch-compile-20260312-19.log`）
- 当前 `missing-scripts-after-journal-current.txt` 剩余差集：`19`

## Additional Decision 2026-03-12
| Decision | Rationale |
|----------|-----------|
| 对于旧工程缺失、当前工程虽完好但明显过薄的系统文件，可在确认没有更优旧版后按参考骨架替换当前简化版 | `MapSystem.cs` 在旧工程备份中缺失，当前实现只有 respawn，无法承接 `TransitionSystem` / `Teleporter` / checkpoint 链 |

## Recovery Batch 16 Update 2026-03-12
- [x] 恢复 `Combat/Stats.cs`（桥接到当前 `Stats` 实现）
- [x] 恢复 `Combat/ObservableStats.cs`
- [x] 恢复 `Game/Wearable.cs`（桥接到当前 `Equipment` 实现）
- [x] 跑 Unity 批处理编译验证（`unity-batch-compile-20260312-21.log`）
- 当前 `missing-scripts-after-journal-current.txt` 剩余差集：`16`

## Additional Decision 2026-03-12-2
| Decision | Rationale |
|----------|-----------|
| 对于“文件路径缺失但当前工程已有更完整同职责实现”的情况，优先做兼容桥接而不是复制第二套并行实现 | `Stats` 与 `Equipment` 当前已在项目里稳定使用；重新复制一套同名同责类型反而会制造分叉和冲突 |

## Recovery Batch 17 Update 2026-03-12
- [x] 恢复 `Game/Systems/PlayerSystem.cs`
- [x] 将 `GameManager` 接入 `PlayerSystem` 单例入口
- [x] 跑 Unity 批处理编译验证（`unity-batch-compile-20260312-22.log`）
- 当前 `missing-scripts-after-journal-current.txt` 剩余差集：`15`

## Additional Decision 2026-03-12-3
| Decision | Rationale |
|----------|-----------|
| `PlayerSystem` 先落“无 persistence 的真实宿主版”，不为了对齐参考而把整套存档/数据库引用硬搬进来 | 当前工程已经有 `Hero`、`GameManager.Player`、`PlayerEvents`、`UISystem`，足够支撑玩家实例管理与死亡清场；直接引入 `PersistenceSystem` 会把依赖面无谓放大 |

## Recovery Batch 18 Update 2026-03-12
- [x] 恢复 `Spawners/AMonsterSpawner.cs`
- [x] 恢复 `Spawners/MonsterSpawner.cs`
- [x] 恢复 `Spawners/MonsterAreaSpawner.cs`
- [x] 扩展 `CharacterBase.SetLevel(int)` 承接刷怪等级入口
- [x] 跑 Unity 批处理编译验证（`unity-batch-compile-20260312-23.log`）
- 当前 `missing-scripts-after-journal-current.txt` 剩余差集：`12`

## Additional Decision 2026-03-12-4
| Decision | Rationale |
|----------|-----------|
| 对参考脚本里“核心运行时完整，但只缺 persistence/save-load 宿主”的情况，优先保留参考骨架并删除存档分支，而不是重写成另一套简化流程 | `Spawners/*` 的刷怪字段、权重算法、预刷怪和数量限制都可直接沿用，当前工程真正缺的只是 `Persistable` / `PersistenceSystem` / `CharacterBaseDataBlock` 这条宿主链 |
| 当当前工程缺少怪物等级成长数据时，先补真实等级入口，不凭空捏造第二套成长系统 | 当前 `MonsterSheet` 只有奖励数据，没有参考工程那套按等级驱动的 stats 数据；因此 `SetLevel` 本批只负责等级同步，避免做错底层规则 |

## Recovery Batch 19 Update 2026-03-12
- [x] 恢复 `Combat/Abilities/Active/DashAbility.cs`
- [x] 恢复 `Combat/Abilities/Active/SummoningAbility.cs`
- [x] 扩展 `Movable` 补齐 `Push` / `IsPushed` / 运行时推力衰减
- [x] 扩展 `CharacterBase` / `Character` / `Monster` / `NPC` 补齐运行时阵营覆盖与 `Teleported` 事件
- [x] 扩展 `AIController` 增加 `SetTarget` / `SetMaster`
- [x] 跑 Unity 批处理编译验证（`unity-batch-compile-20260312-24.log`）
- 当前 `missing-scripts-after-journal-current.txt` 剩余差集：`10`

## Additional Decision 2026-03-12-5
| Decision | Rationale |
|----------|-----------|
| `SummoningAbility` 需要的阵营同步和跟随逻辑属于当前宿主缺口，应补到底座而不是塞进 ability 内部做一次性特判 | 运行时阵营覆盖、传送同步、AI 跟随入口都具备跨模块复用价值，而且这批正好有完整同名参考可对照落地 |
| 找不到可读同名参考的剩余文件先暂缓，不为了追数量回到拍脑袋重写 | `CharacterStateBase` / `CharacterAnimState` / `CharacterTriggerState` 在当前可访问参考集中没有同名实现；按用户策略，优先继续清还有完整参考的批次 |

## Recovery Batch 20 Update 2026-03-12
- [x] 恢复 `_Editor/DatabaseWindow/DatabaseWindow.cs`
- [x] 恢复 `_Editor/Playtest/EditorPlayModeOverride.cs`
- [x] 扩展 `SaveDataBlocks.MapDataBlock.playtest`
- [x] 扩展 `MapSystem.LoadDataBlock` 承接 editor playtest 地图传送
- [x] 跑 Unity 批处理编译验证（`unity-batch-compile-20260312-26.log`）
- 当前 `missing-scripts-after-journal-current.txt` 剩余差集：`5`

## Additional Decision 2026-03-12-6
| Decision | Rationale |
|----------|-----------|
| 扫剩余差集时必须把 `Mythril2D/Core/Editor` 也纳入同名参考搜索 | `DatabaseWindow.cs` / `EditorPlayModeOverride.cs` 实际存在可直接迁移的 editor 参考，不能过早归类为“无参考” |
| 当 editor 参考脚本依赖旧的 save API 时，优先把当前宿主补到可承接的数据块入口，而不是在 editor 脚本里硬编码废弃字段 | 通过补回 `MapDataBlock.playtest` 与 `MapSystem.LoadDataBlock` 的 playtest 分支，`EditorPlayModeOverride` 能沿当前 `SaveDataBlock` 链路工作 |

## Recovery Batch 21 Update 2026-03-12
- [x] 恢复 `Entities/Characters/States/CharacterStateBase.cs`
- [x] 恢复 `Entities/Characters/States/CharacterAnimState.cs`
- [x] 恢复 `Entities/Characters/States/CharacterTriggerState.cs`
- [x] 恢复 `GameSystem/Input/InputSystemGenerator.cs`
- [x] 恢复 `MultiTrack.cs`
- [x] 扩展 `CharacterBase.SetMode(CharacterMode)` 承接 Animator 状态切换
- [x] 改造 `InputSystem.cs` / `PlayerController.cs`，改由 `InputSystemGenerator` 解析实际 action map 与 action alias
- [x] 重算 `missing-scripts-after-journal-current.txt`，当前差集 `0`
- [x] 记录 Unity batch compile 环境阻塞（`unity-batch-compile-20260312-29.log` / `unity-batch-compile-20260312-30.log`）
- [x] 使用 Unity Roslyn + `Assembly-CSharp.codex-validate.rsp` 复放 `Assembly-CSharp` 编译并通过

## Additional Decision 2026-03-12-7
| Decision | Rationale |
|----------|-----------|
| 对于旧工程源码已损坏、当前可访问参考树也不存在同名实现的剩余脚本，按当前宿主恢复“可复用底座”，而不是补最小占位空壳 | `CharacterStateBase` / `CharacterAnimState` / `CharacterTriggerState` / `InputSystemGenerator` / `MultiTrack` 都属于这类文件；继续等待参考源码不会推进差集清零 |
| 当 Unity batch compile 在当前沙箱里被 `LocalLow/Unity` 权限与 UPM IPC 卡死时，不把它误判成脚本编译失败，而是改用 Unity 自带 Roslyn 重放 `Assembly-CSharp.rsp` 做源码校验 | `unity-batch-compile-20260312-29.log` / `unity-batch-compile-20260312-30.log` 没有出现 `error CS`，但稳定出现 `Could not establish a connection with the Unity Package Manager local server process`；Roslyn 校验退出码为 `0` |

## Validation Addendum 2026-03-12
- [x] 修正 `InputSystemGenerator`：fallback 成功时不再提前写入误导性的 `Missing action` 告警
- [x] 再次运行 Unity Roslyn 校验，确认改动后仍通过
- [x] 审计 `InputSystem_Actions.inputactions`，确认当前只有 `Player` / `UI` 两个 map，且 `Player` map 没有 `OpenGameMenu`
- [x] 审计可见场景与资源绑定，确认最后恢复的状态类 / Timeline 轨道当前尚无资源侧引用；仓内可见场景仍是模板级场景，不足以做 gameplay 宿主实测

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `UniTask` 多个 `.cs` 实为二进制文件 | 1 | 用官方 `2.5.10` 整包替换并备份坏包 |
| 新项目迁入后出现二进制污染 `.cs` | 1 | 改成字节级检测，隔离污染脚本 |
| `UIMgr` / `UniTask` 局部 API 不兼容 | 1 | 按当前项目实际 API 适配 |
| 大范围恢复时旧文件名存在但文件本体损坏 | 1 | 按当前上下文 + 参考项目重建同职责脚本 |
| 直接按中文路径读取交接文档失败 | 1 | 改为先枚举文件，再用 UTF-8 读取 |
| 沙箱内启动 Unity 批编译未生成日志 | 1 | 申请提权后重新执行，日志写入 `RecoveryNotes/unity-batch-compile-20260311-4.log` |
| Codex shell 中直接执行 Unity 批编译返回 `0` 但未生成日志 | 1 | 对 Unity 批编译统一改用提权执行，并在完成后立即校验日志文件 |
| `EventHub.Subscribe/Unsubscribe` 对 payload 重载未自动推断，首轮 `unity-batch-compile-20260311-12.log` 失败 | 1 | 对 `UIEventLog` / `CombatTextDisplay` 改用显式泛型订阅后重跑，同一日志转绿 |
| `ZFrame` 插件程序集内直接引用 `GameManager` / `UnityEngine.InputSystem`，首轮 `unity-batch-compile-20260311-13.log` 失败 | 1 | `UIMgr` 只保留选中态兜底，`ui.cancel` 分发下沉到 `UISystem` 后重跑转绿 |

## Phase 6 Update 2026-03-12
- Chest / Loot batch complete:
  - restored `Entities/Chest.cs`
  - restored `GamePlay/Loot/Loot.cs`
  - restored `GamePlay/Loot/ChestLoot.cs`
  - restored `Interactions/ChestInteraction.cs`
- Utility batch complete:
  - restored `Miscellaneous/CoroutineHelpers.cs`
  - restored `Miscellaneous/DisplayNameUtils.cs`
  - migrated `CommandTrigger` frame-delay execution to `CoroutineHelpers`
- Host adaptations:
  - generalized `PlayerController` interaction target resolution from hard-coded NPC/character lookup to generic `IInteractionTarget` discovery
  - chest now supports open-state animation, loot icon reveal, dialogue publishing, reward payout, and gameplay SFX
- Static gap count updated from `28` to `22`
- Additional decision:
  - prefer broadening existing host entry points such as `IInteractionTarget` discovery when it unlocks multiple remaining recoveries (`Chest`, `Inn`, `Teleporter`) instead of hard-coding one type at a time
- Additional error:
  - recomputing `missing-scripts-after-journal-current.txt` without normalizing escaped backslashes and slash direction produced a false count; current comparison must normalize both sides to `/`
- Batch compile verification:
  - `RecoveryNotes/unity-batch-compile-20260312-16.log`
  - `RecoveryNotes/unity-batch-compile-20260312-17.log`

## Phase 6 Update 2026-03-11
- Animation batch complete:
  - restored `AnimationUtils` / `CameraShake` / `FollowTargetDirection` / `TransformShaker` / `Animation/Strategies/*`
  - adapted `CharacterBase.targetDirectionChangedEvent`, `Movable` animation strategy hooks, and `GameConfig.cameraShakeSources`
  - static gap count updated from `43` to `28`
- Additional decision:
  - when a reference script depends on a missing serialization helper such as `SerializableDictionary`, prefer converting it to native array/list bindings instead of adding a new dependency
- Additional error:
  - first pass of `unity-batch-compile-20260311-15.log` failed because `PolydirectionalAnimationStrategy` referenced a missing `SerializableDictionary`; resolved by switching to array bindings and fixing `EAnimationDirection` accessibility
- 已完成这组 UI / 输入链路：
  - `AUIMenu`
  - `UIDeath`
  - `UIControllerButton` / `UIControllerButtonManager`
  - `UINavigationCursor` / `UINavigationCursorTarget` / `UINavigationTarget`
  - `UIPlayerControllerFeedback`
- 同时补齐的宿主边界：
  - `PlayerController` 的 `interactionTarget` / 交互检测 / 暂停菜单请求发布
  - `UISystem` 对 `GameMenuRequested` / `DeathScreenRequested` / `HeroKilled` 的消费
  - `GameConfig.interactionLayer`
- 批编译验证：`RecoveryNotes/unity-batch-compile-20260311-13.log`
- 差异清单剩余：`43`
## Host Assembly Compatibility Update 2026-03-12
- [x] 定点审计参考 `M2DEngine.unity` / `Main Menu.unity` / `User Interface.prefab` 的直接依赖
- [x] 新增宿主兼容层：`AudioChannel.cs` / `GameStateSystem.cs` / `NotificationSystem.cs` / `IUIMenu.cs` / `EItemTransferType.cs`
- [x] 将一批 gameplay / UI 宿主脚本 GUID 对齐到参考 / 旧工程
- [x] 用 Unity Roslyn + 追加新源码方式复放 `Assembly-CSharp.codex-validate.rsp`
- 直接依赖缺口现状：
  - `M2DEngine.unity`：`21 -> 8`
  - `Main Menu.unity`：`22 -> 12`
  - `User Interface.prefab`：`35 -> 20`

## Additional Decision 2026-03-12-8
| Decision | Rationale |
|----------|-----------|
| 在资源层几乎空仓时，优先恢复“参考场景可识别的宿主脚本 GUID + 序列化兼容宿主”，再决定搬哪些 prefab / asset | 先把问题从 `Missing Script` 收缩成真实资产缺口，否则迁参考场景时会同时混入 GUID 失配和资源缺失两类噪音 |
| `AudioSystem` 优先改成兼容参考 `m_audioChannels.m_keys / m_values` 的序列化形状，而不是继续只保留当前 `List<AudioChannelBinding>` | `M2DEngine.unity` 的 `Audio System` 组件就是按这个结构写入的，单改 GUID 不足以承接参考场景 |
| `PersistenceSystem.cs` 本轮不硬迁 | 该系统依赖 `Persistable` / `PersistableDataBlock` / 自动持久化链，超出当前“最小宿主兼容”范围 |

## Additional Decision 2026-03-12-9
| Decision | Rationale |
|----------|-----------|
| `Assets/Plugins/ZFrame/RunTime/Manager/Save/Data/SaveFile.cs` 不再直接持有 `SaveDataBlock`，而是改成跨程序集安全的 JSON 模板字符串桥接 | `SaveFile` 归属 `ZFrame.asmdef`，直接引用 `Assembly-CSharp` 里的 `SaveDataBlock` 会让 `ZFrame.rsp` 在 Roslyn 下稳定报 `CS0246`；默认开局模板如果后续需要，仍可通过 `SaveSystem.ExtractSaveDataFromJson(...)` 解析 |
| Unity Roslyn 校验必须按真实程序集边界分两段执行：先 `ZFrame.rsp`，再 `Assembly-CSharp.codex-validate.rsp` | 把插件源码直接塞进 `Assembly-CSharp` 会出现类型冲突告警，且会掩盖 `ZFrame.ref.dll` 是否真被刷新；正确做法是先编依赖程序集，再编主程序集 |
| `Main Menu.unity` 剩余的 3 个 GUID 先不继续硬追 | `0000000000000000e000000000000000` 属于内置占位 GUID，`357186adf88f47441beed107c9dbbe69` 在参考树中找不到任何 `.meta`，`6a160d838ff8b4b4693ac20007e008c7` 来自旧版 `com.unity.2d.pixel-perfect` 包缓存；这三项都不适合继续按当前项目资源闭包直接恢复 |
| `User Interface.prefab` 这一链暂不进入“薄宿主兼容”硬接 | 当前项目菜单宿主以 `UIMgr` / `UISystem` 为主，参考版 `UIMenuManager` 依赖整套 `IUIMenu` 菜单栈；继续推进应按完整 UI prefab 链批量迁移，而不是再补单个脚本 |

## Host Resource Closure Update 2026-03-12
- [x] 用 Unity Roslyn 真验证 `ZFrame.rsp`，暴露并修复 `SaveFile -> SaveDataBlock` 跨程序集依赖
- [x] 将 `SaveFile.m_content` 改为 JSON 模板字符串，并在 `SaveSystem` 中新增 `ExtractSaveDataFromJson(...)`
- [x] 重新验证 `ZFrame.rsp` 通过
- [x] 用 `Assembly-CSharp.codex-validate.rsp` + 追加新增 `Assets/Scripts` 源文件的方式重新验证主程序集通过
- [x] 新增最小资源资产：`SF_Knight` / `SF_Wizard` / `SF_Archer` / `AUDIO_ISFX_Quest_Started` / `AUDIO_ISFX_Quest_Completed` / `AUDIO_BGM_Title`
- [x] 对齐 UI 宿主相关脚本 GUID：`UINavigationTarget` / `UIControllerButtonManager` / `UISettingsChannelVolume` / `UISettingsMasterVolume`
- [x] 迁入一批低依赖资源闭包：`RPGSystem SDF.asset`、`SPS_GUI.png`、`Base Menu.prefab`、`Button.prefab`、`Settings Menu.prefab`、`UI Controller Button Manager.prefab`、控制器 sprite libraries / sprites、`User Interface.prefab`、`Devon.prefab`
- 参考宿主缺口现状：
  - `M2DEngine.unity`: `5 -> 3 -> 1`
  - `Main Menu.unity`: `12 -> 8 -> 3`
  - `User Interface.prefab`: `20 -> 17`
- 当前剩余高价值差集已经收敛为：
  - `M2DEngine.unity`：仅剩 1 个内置未知 GUID
  - `Main Menu.unity`：仅剩 3 个非本地可直接修复的未知 GUID
  - `User Interface.prefab`：仍是完整 UI prefab 链与 `UIManager.cs` / `UIMenuManager.cs` 宿主分叉问题

## MiniFantasy UV Dressing Correction 2026-03-13
- 本节结论覆盖前面所有把 `Assets/Scenes/SampleScene.unity` 视为“真实换装环境”的表述。
- 用户已明确目标不是 `Mythril2D` 的 `EquipmentSpriteLibraryUpdater + 武器 sprite library` 可见装备链，而是 `MiniFantasy` 场景里的自研 `UV` 换装测试流。
- 用户记忆的交互口径已固定为：点击角色，然后有测试按钮切换装备。
- 因此当前 `SampleScene` 应降级为“当前仓内可用的装备功能宿主”，不再作为“真实 UV 换装测试环境”结论。
- 当前真正主线不再是“等用户验证 `SampleScene`”，而是先定位/恢复正确的 `MiniFantasy UV` 场景宿主。

## MiniFantasy Candidate Intake 2026-03-13
- [x] 已迁入 `Assets/ArtRes/KrishnaPalacio/MINIFANTASY - Crafting and Professions I`
- [x] 已迁入 `Assets/ArtRes/KrishnaPalacio/MINIFANTASY - True Heroes`
- [x] 已迁入 `Assets/ArtRes/KrishnaPalacio/MINIFANTASY - User Interface`
- 体量复核：
  - `MINIFANTASY - Crafting and Professions I`: `1049` files, `11288343` bytes
  - `MINIFANTASY - True Heroes`: `395` files, `1027998` bytes
  - `MINIFANTASY - User Interface`: `285` files, `3777237` bytes
- 当前仓内首选候选：
  - `Assets/ArtRes/KrishnaPalacio/MINIFANTASY - Crafting and Professions I/Scenes/Demo - True Heroes Animations.unity`
  - `Assets/ArtRes/KrishnaPalacio/MINIFANTASY - Crafting and Professions I/Scenes/Demo - Charcter Animations.unity`
  - `Assets/ArtRes/KrishnaPalacio/MINIFANTASY - Crafting and Professions I/Scripts/TH_DemoManager.cs`
- 旧源第二候选：
  - `E:\back\gameObject\project\2DARPGEngine\Assets\KrishnaPalacio\MINIFANTASY - Dungeon\Scenes\Demo - Animated Characters.unity`
  - `E:\back\gameObject\project\2DARPGEngine\Assets\KrishnaPalacio\MINIFANTASY - Dungeon\Scripts\DUN_AnimatedCharacterSelection.cs`

## MiniFantasy Candidate Assessment 2026-03-13
- [x] 已确认当前仓内 `Demo - True Heroes Animations.unity.meta` 与 `TH_DemoManager.cs.meta` 都存在
- [x] 已确认当前仓与旧源中的候选 `MiniFantasy` 场景/脚本文件都不是可读文本源
- 代表样本：
  - `TH_DemoManager.cs`: `size=3616`, `nulls=10`, `printable_ratio=0.368`
  - `Demo - True Heroes Animations.unity`: `size=486746`, `nulls=15`, `printable_ratio=0.378`
  - `DUN_AnimatedCharacterSelection.cs`: `size=1770`, `nulls=6`, `printable_ratio=0.379`
  - `Demo - Animated Characters.unity`: `size=122822`, `nulls=16`, `printable_ratio=0.389`
- 结论：
  - 这批候选可以继续当素材源或黑盒 Unity 资产
  - 但不能再当“可直接读源码/改 YAML”的恢复主线
  - 当前无法继续沿“迁入同名场景/脚本再做薄适配”的方式恢复 `MiniFantasy` 交互逻辑

### Milestone A0: 原始 UV 场景定位
- [x] 迁入 `MiniFantasy` 候选素材包
- [x] 核对首选候选场景与脚本路径存在
- [x] 判定当前可访问候选 `MiniFantasy` 场景/脚本不适合当可读逻辑源
- [x] 确认旧 `FantasyWorld` 项目里唯一的用户场景文件是 `E:\back\gameObject\project\FantasyWorld\Assets\Scenes\MainScene.unity`
- [ ] 继续定位当前仓或可访问旧源里是否还有可读的自研 `UV` 换装宿主/脚本
- [ ] 若找不到可读源，则基于已迁入 `MiniFantasy` 资源重建一个最小“点击角色 + 测试按钮”的换装沙盒
- Exit Criteria: 当前仓内有且仅有一个 `MiniFantasy` 风格测试场景，且其用途与用户记忆的 `UV` 换装验证一致

## Active Blocker 2026-03-13
- 当前阻塞点不是 `SampleScene` 的 GUID，也不是“等用户来验证”。
- 当前阻塞点是：真实目标已经切到 `MiniFantasy + 自研 UV 换装`，但当前能找到的候选交互脚本与场景都来自损坏备份，不能作为可靠逻辑源。
- 所以下一步优先级应是“找回或重建正确场景宿主”，而不是继续在 `SampleScene` 或 `EquipmentSpriteLibraryUpdater` 上打补丁。

## MiniFantasy Compile Safety Update 2026-03-13
- [x] 已用 Roslyn 直测确认 `TH_DemoManager.cs` 会触发大量 `CS1056` / `CS1002`
- [x] 已用 Roslyn 直测确认 `TH_Projectile.cs` 被判定为“二进制文件而非文本文件”
- [x] 已将 `Assets/ArtRes/KrishnaPalacio/MINIFANTASY - Crafting and Professions I/Scripts` 下 `13` 个损坏 `.cs` 及其 `.meta` 移到 `MigrationStaging/MiniFantasyCorruptedScripts/...`
- [x] 已确认 `Assets/ArtRes/KrishnaPalacio` 下不再有会参与 Unity 编译的 `.cs`
- 说明：
  - `MiniFantasy` 场景资产仍保留在 `Assets/ArtRes/KrishnaPalacio/.../Scenes`
  - 这些场景现在只能当黑盒候选资产，不应再假设其交互脚本可直接工作

## Window Handoff 2026-03-13
- 当前真实目标：
  - 不是继续修 `SampleScene`
  - 不是继续追 `EquipmentSpriteLibraryUpdater` 的 sprite-library 可见装备链
  - 而是对照旧 `FantasyWorld` 项目，找回或重建“MiniFantasy 风格、点击角色后出现测试按钮”的自研 `UV` 换装测试宿主
- 下一窗口首要顺序：
  1. 以 `E:\back\gameObject\project\FantasyWorld\Assets\Scenes\MainScene.unity` 作为“原始项目宿主候选 1 号”继续排查
  2. 对照旧/新项目里与该宿主最相关的小集合资产：`PlayerInputHolder.prefab`、`Wearable.cs.meta`、`HeroSheet.cs.meta`
  3. 先做“是否值得 GUID 对齐”的兼容性表，再决定是否实际改 GUID 或迁宿主
  4. 如果旧源仍不给出可读逻辑，则停止继续读损坏 demo 正文，转为基于已迁入 `MiniFantasy` 资源重建最小测试宿主
- 当前最小高价值对照项：
  - `E:\back\gameObject\project\FantasyWorld\Assets\Scenes\MainScene.unity`
  - `E:\back\gameObject\project\FantasyWorld\Assets\Prefabs\Player\PlayerInputHolder.prefab`
  - `E:\back\gameObject\project\FantasyWorld\Assets\Scripts\Game\Wearable.cs.meta`
  - `E:\back\gameObject\project\FantasyWorld\Assets\Scripts\Database\Characters\HeroSheet.cs.meta`
  - `C:\Gamedev\Unity\Project\FantasyWord\Assets\Scripts\Game\Wearable.cs.meta`
  - `C:\Gamedev\Unity\Project\FantasyWord\Assets\Scripts\Database\Characters\HeroSheet.cs.meta`
- 已知可直接复用的结论：
  - 旧 `FantasyWorld` 项目 `Assets/Scenes` 下当前只暴露出一个用户场景 `MainScene.unity`
  - `Wearable.cs` 在旧/新项目里都是空壳，不能把它误当成换装逻辑本体
  - `HeroSheet` 的当前使用面极窄，已知只直连到当前项目的 `CS_Devon.asset`
  - `PlayerSystem.cs.meta`、`InventorySystem.cs.meta`、`UICharacter.cs.meta`、`UIInventoryEquipment.cs.meta`、`UIInventoryEquipmentSlot.cs.meta`、`Hero.cs.meta` 已与旧项目一致，不是当前优先改动点
- 下一窗口禁止回退的路线：
  - 不再把 `SampleScene` 当真实 UV 场景
  - 不再把包自带 `True Heroes` / `Animated Characters` demo 默认当用户原始场景
  - 不再把损坏 `.unity` / `.cs` 当可读源码来反复全文解析
## Old Host Audit Update 2026-03-13
- 宸插畬鎴愮涓€杞?`MainScene.unity` + `PlayerInputHolder.prefab` 鐨勫畾鐐规帓鏌ワ細
  - 鏃?`Wearable` / `HeroSheet` GUID 涓庡綋鍓嶉」鐩笉涓€鑷?
  - 浣嗘棫鍦烘櫙涓庨鍒朵欢鐨?ASCII 鎶芥牱涓病鏈夌洿鎺ユ彁鍙栧埌绫诲悕鎴?GUID 绾跨储
- 杩欐剰鍛崇潃褰撳墠杩樹笉鍊煎緱杩涘叆鈥滅洿鎺?GUID 瀵归綈鈥濇墽琛岄樁娈碉紝鍚﹀垯椋庨櫓楂樹簬淇℃伅澧為噺
- `Milestone A0` 鐨勪紭鍏堢骇缁嗗寲涓猴細
  1. 鎵╁ぇ鏃ф簮涓彲璇?`UV` 鎹㈣鐩稿叧鑴氭湰 / prefab / editor 宸ュ叿鎼滅储
  2. 鍙湁鍦ㄦ壘鍒板彲璇荤嚎绱㈠悗锛屾墠鍥炲埌鈥滄槸鍚﹀仛 GUID 瀵归綈 / 瀹夸富杩佺Щ鈥濈殑鍐冲畾
  3. 鑻ヤ粛鏃犲彲璇荤嚎绱紝鍒欑洿鎺ヨ浆鍏モ€滃熀浜?MiniFantasy 绱犳潗閲嶅缓鐐瑰嚮瑙掕壊 + 娴嬭瘯鎸夐挳 + UV 鎹㈣鏈€灏忔祴璇曞涓衡€?
- 鏈槦鍒楅槻鍥炶建绾跨户缁湁鏁堬細
  - 涓嶅洖鍒?`SampleScene`
  - 涓嶆妸鎹熷潖 demo 脚本褰撲綔鍙閫昏緫婧?
  - 涓嶅湪缂轰箯鍙傜収璇佹嵁鐨勬儏鍐典笅鐩存帴鏀?GUID
## Search Boundary Update 2026-03-13
- 鏃ф簮涓凡缁忓畬鎴愪竴杞?filename 绾у埆鐨?`UV` / 鎹㈣ / `PlayerInputHolder` / `CharacterSelection` 鎼滅储
- 缁撴灉鏄細鍚嶅瓧绾跨储浠嶅湪锛屼絾鍏抽敭鑴氭湰鍐呭澶氭暟宸叉崯鍧忥紝鍖呮嫭 `UIControllerButtonManager.cs` / `UIControllerButton.cs` / `PlayerInputBridge.cs`
- 鍥犳 `Milestone A0` 鍚庣画瑕佸姞涓€鏉￠檺鍒讹細
  - 鍙啀鍋氫竴杞畾鐐规悳绱紙浼樺厛 `.meta`銆乷xt`銆乥oc`銆乪ditor 瀹夸富鎻忚堪锛?
  - 濡傛灉浠嶇劧鎵句笉鍒板彲璇诲師濮?`UV` 宿主锛屽垯鍋滄缁х画璁?old host锛岀洿鎺ヨ浆鍏ラ噸寤?
- 杩欐潯闄愬埗鐨勭洰鐨勬槸閬垮厤鍦ㄢ€滃凡鐭ヨ剼鏈崯鍧忊€濈殑鏉′欢涓嬪弽澶嶅湪鏃ф簮閲屽仛浣庢敹鐩婂父瑙勬悳绱?
## Decision Gate Update 2026-03-13
- 宸插畬鎴愨€滄枃鏈被绾跨储鏈€鍚庝竴杞?probe鈥濓細缁撴灉浠嶆病鏈夋壘鍒板彲璇?`MiniFantasy UV` 宿主
- 鍥犳 `Milestone A0` 鐨勫喅绛栭棬鎰忓懗鍙樻洿鏄庣‘锛?
  - 鑻ョ敤鎴锋病鏈夋柊鐨勫浠借矾寰勬垨鍏朵粬鍘熷涓绘簮锛屽垯涓嬩竴闃舵鐩存帴杩涘叆鈥滃熀浜?MiniFantasy 绱犳潗閲嶅缓鏈€灏忔祴璇曞涓衡€?
  - 鍙湁鍦ㄥ嚭鐜版柊鐨勫彲璇昏剼鏈?scene / prefab / doc 鏃讹紝鎵嶅啀鍥炲埌鈥滄棫瀹夸富鎭㈠鈥濊矾绾?
## Rebuild Execution Draft 2026-03-13
- `Milestone A0` 鐜板湪鍙互鍚庣画鍒囨崲鍒伴噸寤鸿矾绾匡細褰撳墠浠撳唴宸茬粡鏈夎冻澶熺殑鍙 gameplay / UI 宿主锛屼笉闇€鍐嶅洖鍒?old host 鎼滅储涓婚摼
- 鏈€灏忛噸寤洪」鐨勯『搴忔敹绐勪负锛?
  1. 鍦烘櫙鍐崇瓥锛氫互 `Assets/Scenes/SampleScene.unity` 浣滀负鍞竴鍦烘櫙璺緞锛屼絾閲嶅缓鍏跺唴瀹逛负 `MiniFantasy UV` 娴嬭瘯瀹夸富
  2. 瑙嗚鍐崇瓥锛氫粠 `Barbarian` / `Druid` / `Rogue` 涓€夊畾 1 涓鑹蹭綔涓虹涓€鐗堟祴璇曚富瑙?
  3. 鎵胯浇鍐崇瓥锛氬鐢?`User Interface.prefab` + `UI Controller Button Manager.prefab` + 褰撳墠 `UISystem`
  4. 浜や簰鍐崇瓥锛氭柊澧炰竴灞傚緢钖勭殑鈥滅偣鍑昏鑹插悗璁剧疆褰撳墠娴嬭瘯鐩爣鈥濋€昏緫
  5. 楠岃瘉鍐崇瓥锛氭祴璇曟寜閽渶鑷冲皯鑳藉畬鎴?1 娆?UV / 绱犳潗鍒囨崲闂幆
- 鏈疆璁″垝鍚庣殑鍔熻兘鍒嗚В锛?
  - `B1`: 纭畾鍗曞満鏅噸寤哄湪 `SampleScene` 璺緞涓嬭繘琛?
  - `B2`: 纭畾绗竴涓?MiniFantasy 娴嬭瘯瑙掕壊鍜屽叾鍥惧儚/鍔ㄧ敾鏉愭簮
  - `B3`: 瀹氫箟鈥滅偣瑙掕壊 -> 鍑烘祴璇曟寜閽€濈殑鏈€灏忚剼鏈亴璐ｅ垎灞?
  - `B4`: 瀹氫箟鈥淯V 鎹㈣鈥濈涓€鐗堥獙璇佸彛寰勶紙鍙互鏄?material / sprite renderer / shader property 鐨勫垏鎹紝浣嗗繀椤诲彲瑙?
  - `B5`: 鍐欐竻妤氱涓€杞疄瑁呬笉鍋氱殑浜嬫儏锛堜笉杩藉畬鏁翠粨搴擄紝涓嶈拷鏃у涓荤瓑浠峰鍒伙級
- Decision:
  - 濡傛棤鏂扮殑澶囦唤璺緞杩涘満锛屼粠涓嬩竴杞紑濮嬶紝planning 涓婚摼灏辨槸鎶?`MiniFantasy UV` 测试宿主重建拆成 `B1-B5`锛岃€屼笉鍐嶆槸 `A0 old host` 鎼滅储
## B2 Candidate Lock 2026-03-13
- `B2` 褰撳墠宸叉敹绐勶細绗竴涓?MiniFantasy 娴嬭瘯瑙掕壊鍥哄畾涓?`Rogue`
- 鏀拺鏁版嵁锛?
  - `Rogue`: `Sprites=77`, `Animations=78`
  - `Barbarian`: `Sprites=104`, `Animations=92`
  - `Druid`: `Sprites=163`, `Animations=172`
- 鍐冲畾鍚庣殑鎵ц鍚箟锛?
  - 涓嬩竴杞鍒掑彲浠ョ洿鎺ョ粫鐫?`Rogue` 鐨勭簿鐏靛浘 / 鍔ㄧ敾 / 娴嬭瘯鎸夐挳鍒囨崲鍙ｅ緞鍐欏疄瑁呭瓙浠诲姟
  - 绗竴杞笉鍐嶅仛鈥滄槸鍚﹂€夊摢涓?MiniFantasy 瑙掕壊鈥濈殑鍙嶅鎽囨憜

## Thin Runtime Layer Draft 2026-03-13
- 涓轰簡鎶婇噸寤鸿矾绾胯浆鎴愪笅涓€杞彲瀹炶鐨勪换鍔★紝褰撳墠鍏堟妸鍙兘鏂板鐨勮杽 runtime 灞傛敹绐勪负 4 绫伙細
  - `Selection Target`: 鐐瑰嚮 `Rogue` 鍚庢姄鍙栧綋鍓嶆祴璇曠洰鏍?
  - `Selection State`: 鎸佹湁褰撳墠琚€変腑鐨?MiniFantasy 瑙掕壊锛屽彧鐢ㄤ簬娴嬭瘯瀹夸富锛屼笉鎵╁埌鏁翠綋 gameplay
  - `Test Button Panel`: 鍦ㄨ鑹茶韩杈规垨灞忓箷涓婂脊鍑?1-3 涓祴璇曟寜閽?
  - `UV Presenter`: 鎶娾€滄寜閽涓衡€濇槧灏勫埌鍏蜂綋鐨?UV / material / sprite renderer 鍒囨崲
- 娉ㄦ剰锛氳繖鏄綋鍓嶇殑 planning 绾ц崏妗堬紝杩樹笉鏄凡瀹炶鑴氭湰鍚?
## Readable UV Runtime Source Intake 2026-03-13
- 已确认新的首选技术来源不是损坏的 `FantasyWorld` 旧宿主，而是可读项目：
  - `C:\Users\zhuagenbao\Desktop\MiniCharacterCreator-main\test`
- 该项目内 `Assets/Scripts/EquipmentSystem` 提供了完整且可读的 `UV` 换装实现链：
  - `README.md`
  - `Runtime/EquipmentRenderer.cs`
  - `Runtime/EquipmentDemoExtension.cs`
  - `Runtime/AnimationController.cs`
  - `Data/Appearance/CharacterAppearance.cs`
  - `Data/Appearance/EquipmentRenderData.cs`
  - `Data/Appearance/EquipTypeConfig.cs`
  - `Editor/Utilities/DualUVMapGenerator.cs`
  - `Shaders/EquipmentUV.shader`
- 这条链已经覆盖：
  - `Dual UV Map` 数据生成
  - `EquipmentRenderer` 运行时装备渲染
  - `EquipmentDemoExtension` 测试面板
  - `AnimationController` 动画切换
  - `EquipmentUV.shader` 材质采样与 `UV` 合成
- 判断：
  - 这不是 `FantasyWorld` 旧损坏项目本体里的可读源码
  - 但它已经比旧备份更接近“真实 `UV` 换装运行时实现”
  - 后续 `plan` 应把它视为 `UV` 真实实现来源，而不是只当灵感参考

## Recovered Host Topology Update 2026-03-13
- 已在
  - `C:\Users\zhuagenbao\Desktop\MiniCharacterCreator-main\test\Assets\_Recovery\0.unity`
  中确认到宿主层骨架：
  - `EquipmentSystem::EquipmentSystem.Runtime.EquipmentDemoExtension`
  - `EquipmentSystem::EquipmentSystem.Runtime.EquipmentRenderer`
  - UI Button 事件绑定到 `MyCharacterSelection.ToggleCharacter`
  - UI Button 事件绑定到 `Creatures_AnimatedCharacterSelection.ToggleAnimation`
  - UI Button 事件绑定到 `Creatures_AnimatedCharacterSelection.TurnOffCurrentParameter`
- 这说明“角色选择”和“测试按钮面板”在原宿主里是分层的：
  - 一层负责切换/选中角色
  - 一层负责动画按钮
  - 一层负责 `EquipmentDemoExtension` 的装备测试面板
- 虽然 `MyCharacterSelection` / `Creatures_AnimatedCharacterSelection` 源码当前未找回，但宿主职责已经足够明确，可用于薄层重建

## Decision Update 2026-03-13-UVSource
- 决策收敛为：
  - 不再继续把“对照损坏的 `FantasyWorld` 旧项目逐字恢复 `UV` 逻辑”当主线
  - 若没有新的可读旧源码出现，后续实现路线改为：
    - 用 `MiniCharacterCreator-main\\test\\Assets\\Scripts\\EquipmentSystem` 作为 `UV` runtime 真实来源
    - 再在当前项目里重建一层最小宿主，满足“点角色 -> 出测试按钮 -> 验证 `UV` 换装”
- 旧 `FantasyWorld` 线索保留为：
  - 只用于确认用户记忆中的宿主交互目标
  - 不再作为必须逐字对照恢复的唯一来源

## Next Steps Update 2026-03-13
- `N1`: 将 `MiniCharacterCreator-main\\test` 的 `EquipmentSystem` 认定为后续实现阶段的首选迁移源
- `N2`: 继续从 `_Recovery/0.unity` 提炼最小宿主结构，重点是：
  - 角色选择入口
  - 动画按钮面板
  - `EquipmentDemoExtension.SetTarget(...)` 目标切换
- `N3`: 进入实现阶段时，第一版只做：
  - 单角色 `Rogue`
  - 最小角色选择/选中状态
  - 最小测试按钮面板
  - 最小 `UV` 换装验证链

## Execution Update 2026-03-13 MiniFantasy UV Human Host
- [x] 已迁入 `Assets/ThirdParty/MiniFantasyUV/Scripts/EquipmentSystem`
- [x] 已迁入 `Assets/ThirdParty/MiniFantasyUV/Data/{AnimationType,Appearance,Equip,FrameData}`
- [x] 已按 `uv_guid_source_map.csv` 补齐缺失资源到 `Assets/ThirdParty/MiniFantasyUV/ImportedSource`
- [x] 已确认当前 `MiniFantasyUV` 数据资产缺失 GUID 为 `0`
- [x] 已补运行时薄层：
  - `Assets/Scripts/MiniFantasyUV/MiniFantasyUVSelectable.cs`
  - `Assets/Scripts/MiniFantasyUV/MiniFantasyUVSelectionHost.cs`
- [x] 已补 Editor 生成器：
  - `Assets/Scripts/_Editor/MiniFantasyUV/MiniFantasyUVSceneBuilder.cs`
- [x] 已补 `EquipmentDemoExtension` 宿主开关，支持未选中不显示面板、禁用自动拾取
- [ ] 待在 Unity Editor 中执行菜单 `Tools/MiniFantasy UV/Create Or Update Test Scene`
- [ ] 待打开 `Assets/Scenes/MiniFantasyUVTest.unity` 做人工 smoke test

## Current UV Deliverable
- 第一版交付目标已从 `Rogue` 调整为 `Human`
- 当前交付物不是直接修改主链 `SampleScene`，而是独立 `MiniFantasyUVTest.unity`
- 当前独立场景的目标行为是：
  - 点击 `Human` 角色
  - 出现 `EquipmentDemoExtension` 测试面板
  - 可切换装备、外观、动画和方向

## UV Runtime Fix Update 2026-03-13
- [x] ȷ�� `HumanFramData.asset raw=(null)` �ĸ����� `ScriptableObject` �ű� GUID �� Unity ��ǰ `AssetDatabase` ��¼��һ��
- [x] ���뵱ǰ��Ŀ�е� MiniFantasy UV �ؼ��ű� GUID ӳ�䣺
  - `CharacterFrameData.cs.meta -> fc994bebc35494f46b10ca9a0616cd5a`
  - `CharacterAppearance.cs.meta -> 32449d36b72aacb4e988367415303414`
  - `AnimationTypeDatabase.cs.meta -> 4692367c505d8e544ba5049f0e52fc1a`
  - `AnimationTypeItem.cs.meta -> 3b5d855e7426ae84f933be6c0f0ed3ee`
  - `EquipmentRenderData.cs.meta -> f10408a33f0220f4689aca3a3e8c63de`
- [x] ͬ���������������ʲ�ͷ�� `m_Script guid`
  - `Assets/ThirdParty/MiniFantasyUV/Data/FrameData/*.asset`
  - `Assets/ThirdParty/MiniFantasyUV/Data/Appearance/*.asset`
  - `Assets/ThirdParty/MiniFantasyUV/Data/AnimationType/*.asset`
  - `Assets/ThirdParty/MiniFantasyUV/Data/Equip/*.asset`
- [x] ���� `Assets/Editor/MiniFantasyUV/MiniFantasyUVSceneBuilder.cs` �� `EnsureClickCollider()`
- [x] �� batch ���̳ɹ�ִ�� `FantasyWord.EditorTools.MiniFantasyUV.MiniFantasyUVSceneBuilder.CreateOrUpdateScene`
- [x] �ɹ����ɲ��ؿ���
  - `Assets/Scenes/MiniFantasyUVTest.unity`
  - `Assets/Scenes/MiniFantasyUVTest.unity.meta`
- [ ] �����������Ѵ򿪵� Unity Editor �����˹� smoke test��
  - �� `Assets/Scenes/MiniFantasyUVTest.unity`
  - ��� `Human`
  - ȷ��������ʾ�Ҷ���/����/װ���л���ʵ�ʷ���

## AIBridge Screenshot Track 2026-03-13
- Goal: �ڵ�ǰ�������ȶ�ʹ�� AIBridge ִ�г����������ͼ�����γɿɸ��õĲ������̡�
- Scope: ������ `Assets/Scenes/MiniFantasyUVTest.unity` �ļ��ء���ͼ����־�ؿ�������չ��ҵ���߼��޸ġ�

### Milestone P1: ������·��ͨ
- [x] `cn.lys.aibridge` �Ѽ��� `Packages/manifest.json`
- [x] `AIBridgeCLI.exe` ������ Unity (`EditorCommand_GetState` �ɹ�)
- [x] �ܼ��� `Assets/Scenes/MiniFantasyUVTest.unity`
- [x] ��ִ�� `ScreenshotCommand_Image` ������ PNG
- Status: complete

### Milestone P2: �ȶ����������
- [ ] ����ͼ�������Ϊ��Ŀ�ű����� `Tools/` �� `RecoveryNotes` �����嵥��
- [ ] ��¼��ʱ���ԣ���������Ĭ��ʹ�� `--timeout 60000`����ͼĬ�� `--timeout 20000`
- [ ] ��ѡ���� AIBridge ����Ϊ Embedded �� Fork������ PackageCache �����ڸ��º�ʧ
- Status: in_progress

### Milestone P3: �������
- [ ] ����ִ�� 3 �Σ����س��� -> ��ͼ -> У���ļ�����
- [ ] У���ͼĿ¼������ʱ���һ���� (`AIBridgeCache/screenshots`)
- [ ] ��ʧ�ܣ���¼���������Բ��Ե� `progress.md`
- Status: pending

## AIBridge Track Closure Update 2026-03-13
- [x] 已固化截图回归脚本：`Tools/AIBridge/run-mini-fantasy-uv-smoke.ps1`
- [x] 已固化操作清单：`RecoveryNotes/aibridge-smoke-workflow-2026-03-13.md`
- [x] 已将默认超时写入脚本：连接 `60000ms`、场景加载 `60000ms`、截图 `20000ms`
- [x] 已完成 3 轮回归（`SceneCommand_Load -> ScreenshotCommand_Image`）
- [x] 已验证截图目录稳定输出：`AIBridgeCache/screenshots`
- Milestone P2 Status: complete
- Milestone P3 Status: complete
- 复跑命令：`powershell -ExecutionPolicy Bypass -File .\Tools\AIBridge\run-mini-fantasy-uv-smoke.ps1 -Rounds 3`

## MiniFantasyUV Scene Integrity Update 2026-03-13
- [x] 已修复 `Assets/Scenes/MiniFantasyUVTest.unity` 的 9 个缺失 Prefab GUID 问题。
- [x] 已补齐角色 prefab 资产并完成强制重导入，场景重载不再出现 `Missing Prefab Asset`。

## MiniFantasyUV Final Recheck 2026-03-14
- [x] `SceneCommand_Load --raw --scenePath Assets/Scenes/MiniFantasyUVTest.unity` 复检通过。
- [x] 场景加载日志中 `Failed to load *_AnimatorOverrideController` 未再出现。
- [x] 场景加载日志中 `Animator is not playing an AnimatorController` 未再出现。
- [x] `AssetDatabaseCommand_Refresh --forceUpdate true` 后无编译错误日志。
- Status: complete

## Material Migration Completion 2026-03-14
- [x] 审计源项目素材覆盖率（`Assets/Art`、`Assets/Minifantasy_NPCs_Assets`）。
- [x] 采用低风险同步策略：已存在 `.meta` 不覆盖，缺失文件补齐，非 `.meta` 内容按哈希对齐。
- [x] `Assets/Art -> Assets/ArtRes/KrishnaPalacio` 已对齐至 `missing=0`。
- [x] `Assets/Minifantasy_NPCs_Assets -> Assets/ArtRes/KrishnaPalacio/Minifantasy_NPCs_Assets` 已完整迁移。
- [x] AIBridge 复检：`AssetDatabaseCommand_Refresh` 与 `MiniFantasyUVTest` 场景加载均 `ERRORS=0`。
- Status: complete

## Source Layout Re-Migration 2026-03-14
- [x] 按源项目原路径重新迁移：`test/Assets/{Art,Data,Editor,Minifantasy_NPCs_Assets,Plugins,Resources,Scenes,Scripts,Settings,_Recovery}`。
- [x] 已将旧迁移布局移出 `Assets`：`Assets/ThirdParty/MiniFantasyUV`、`Assets/ArtRes/KrishnaPalacio`。
- [x] `Assets/Scenes/SampleScene.unity` 已与源项目文件哈希一致。
- [x] 目录级完整性校验通过（10 个目录 `missing=0, size_diff=0`）。
- [x] 刷新编译日志无错误（`REFRESH_ERRORS=0`）。
- Status: complete

## Current Mainline Plan 2026-03-14 (Source Scene Baseline)
- Context: 现已切换为源项目原路径布局，基线场景为 `Assets/Scenes/SampleScene.unity`。

### M1 Baseline Integrity
- [x] 同步 `test/Assets` 到当前项目同名目录。
- [x] `SampleScene.unity` 与源项目哈希一致。
- [x] 目录完整性校验通过（10 个根目录 `missing=0`）。
- [x] 资源刷新编译无错误（`REFRESH_ERRORS=0`）。
- Status: complete

### M2 Runtime Validation (Source Scene)
- [ ] 在已打开 Unity Editor 中加载 `Assets/Scenes/SampleScene.unity`。
- [ ] 运行 PlayMode，确认场景可进入且无关键 Error。
- [ ] 采集一轮日志与截图归档到 `AIBridgeCache/results` 与 `AIBridgeCache/screenshots`。
- Status: pending

### M3 Cleanup & Handover
- [ ] 归档旧迁移目录备份说明与保留周期。
- [ ] 标注“禁止再次把可编译脚本复制到 ImportedSource 的 Art 镜像目录”。
- [ ] 输出最终迁移说明（源路径、目标路径、验证命令、风险点）。
- Status: pending

### Blocker
- AIBridge 场景加载命令依赖已启动的 Unity Editor 进程；当前若仅有 Unity Hub，CLI 会超时。
