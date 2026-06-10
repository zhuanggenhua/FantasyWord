# Findings & Decisions

## Dressing Scope Correction 2026-03-13
- 已确认 `Assets/Database/Items/Gear/ITEM_Iron_Helmet.asset`、`Assets/Database/Items/Gear/ITEM_Iron_Plate.asset`、`Assets/Database/Items/Gear/ITEM_Iron_Boots.asset` 的 `equippedSprite` 与 `visualOverride` 都是空。
- 已确认参考工程 `Mythril2D` 里的同名铁甲资源同样不是可见换装素材；我之前把它们理解成“可见换装”是错误判断。
- 已确认参考工程里真正的可见装备示例是“武器外观切换”，不是头/身/脚整套外观切换。
- 这条参考链至少包含：
- `ITEM_Iron_Sword` / `ITEM_Lucky_Sword`
- `Sprite Libraries/Weapons/Swords/*.spriteLib`
- `Default_Melee_Attack.prefab`
- `EquipmentSpriteLibraryUpdater`
- 已确认当前仓里没有 `Assets/Sprite Libraries/Weapons/**`，也没有参考版那条武器显示资源链。
- 已确认 `Assets/Scripts/Animation/EquipmentSpriteLibraryUpdater.cs` 现在只是源码存在；当前仓里没有 prefab/asset 在使用它。
- 已确认旧备份 `E:\back\gameObject\project\FantasyWorld\Assets` 不存在 `Database/Items`、`Database/Abilities`、`Sprite Libraries`、`Prefabs/Abilities` 目录，因此没有可直接恢复的“项目自有换装素材链”。
- 结论：当前 `SampleScene` 最多只能承担“装备功能验证”，还不能视为“可见换装场景”。

## Dressing Scene Focus 2026-03-12
- 用户范围已收缩为“只保留测试换装场景”；继续恢复 `Main Menu` 或其它地图会偏离当前目标。
- `SampleScene` 当前真正的运行时阻塞不是场景 GUID，而是 `GameManager` 被改成静态类后，场景里的 `Game Manager` 组件失去合法 MonoBehaviour 宿主；已改回 `MonoBehaviour`。
- `Assets/Prefabs/Entities/Characters/Heroes/Devon.prefab` 单独迁入并不够，它本质上是指向 `0_Hero_Base.prefab` 的 prefab variant；必须把 `0_Entity_Base -> 0_Character_Base -> 0_Hero_Base` 一起补齐，`Devon.prefab` 才算可用。
- 旧版 `CS_Devon.asset` 不适合直接迁入：它在当前仓里有 `21` 个缺失 GUID，会把测试场景重新拖回整棵角色数据库恢复。
- 更稳的方案是本地新建最小 `HeroSheet`，再把 `Devon.prefab` 的旧字段 `m_sheet` 改成当前字段 `m_characterSheet`。
- `0_Hero_Base.prefab` 里的旧 `PixelPerfectCamera` GUID `6a160d838ff8b4b4693ac20007e008c7` 可以直接改写为当前包 GUID `c88f5cead0c0b2a4eb05b5900433f8d1`，不需要追旧版包缓存。
- 测试换装场景的起始物品应直接写入 `InventorySystem.startingItems`，不应依赖当前仍为空模板的 `SF_Devon.asset`。
- 旧工程 gear asset 的字段形状与当前 `Item/Equipment` 代码不兼容，因此测试装备必须按当前项目格式新建，而不是直接复制旧 `.asset`。

## Dressing Scene Revalidation 2026-03-12
- `SampleScene.unity` 二次 GUID 扫描如果纳入 `Library/PackageCache`，先前残留的 `0cd44...` / `dc427...` / `62899...` 实际分别是 `CanvasScaler`、`GraphicRaycaster`、`PlayerInput`，不能再按缺失脚本处理。
- `0_Character_Base.prefab` 中先前残留的 `fe87...` / `67db...` / `f468...` / `30649...` / `3245...` / `59f814...` / `c29cff...` / `ed8b...` 分别落在 `Image`、`Slider`、`TextMeshProUGUI`、`HorizontalLayoutGroup`、`ContentSizeFitter`、`VerticalLayoutGroup`、`SpriteLibrary`、`SpriteResolver`，也都属于现有 Unity 包组件。
- `Inventory System.startingItems` 已明确写死 3 件当前格式 gear，说明测试换装入口不依赖旧 `SF_Devon.asset`、旧存档模板或整棵旧角色数据库。
- `Player System.m_dummyPlayerPrefab` 直接指向当前 `Devon.prefab`，所以换装测试链路已经固定为 `SampleScene -> PlayerSystem -> Devon.prefab -> CS_Devon.asset`。

## Long-Term Planning Assumptions 2026-03-12
- 用户补充纠正：限制的是“场景只保留一个”，不是“长期主线只剩一个任务”；因此计划仍应保留分阶段里程碑，而不是压成单点待办。
- 用户当前要的是“测试换装场景”，不是继续扩大到主菜单、村庄、森林或整套地图回归。
- 现阶段最高价值的不确定性已经从“静态宿主是否存在”转成“Unity Editor 里是否能实际进场并完成换装闭环”。
- “换装可见”与“换装可用”要分开对待：前者是显示链路问题，后者是背包/装备/属性/槽位链路问题，验证顺序应先功能后外观。
- 若后续需要补显示链路，应限定在 `SampleScene -> Devon.prefab -> 当前测试装备` 这条闭包里，不应重新拉起整棵旧角色资源恢复。

## Dress-Up Validator Update 2026-03-13
- 已新增 `Assets/Scripts/_Editor/Playtest/DressUpSceneValidator.cs`，目标是给 `SampleScene` 固化一个可重复执行的进场与换装闭环验证入口。
- 该验证器已通过 Unity Roslyn 复编，说明新增 Editor 脚本本身没有编译问题。
- 但在当前 Codex 沙箱里，`Unity.exe -batchmode -executeMethod DressUpSceneValidator.RunBatchValidation` 仍会先卡死在 `LocalLow/Unity` 权限和 `UPM IPC`，验证器本身没有机会执行；因此这条自动验证入口目前只能作为“本机 Unity Editor / 非沙箱环境”的运行抓手。
- 静态检查已经确认：3 件测试装备的 `equippedSprite` 和 `visualOverride` 都是空；同时 `EquipmentSpriteLibraryUpdater` 只存在于源码里，当前 `Devon.prefab` / `0_Hero_Base.prefab` 没有挂接点。
- 因此当前最准确的主线口径是：`换装可用` 仍待运行时验证，`换装可见` 则额外缺显示配置，不能默认视为同一问题。

## UI Closure Addendum 2026-03-12
- `UIEffectListEntry.cs.meta` 旧 GUID `292fb448a51f61f4b89fb93f44caff11` 在当前非 meta 资源里 `0 hits`，可安全对齐到 reference 的 `9ec17e2ffd525874bbaaf560ece45098`；不对齐时 `Assets/Prefabs/UI/Menus/Game Menu/Effect List Entry.prefab` 会持续残留 `Missing Script`
- `EffectIcon.prefab` 的唯一真实缺口是 `d1c8e0eaf60c6b84bb4a7d47f400c8d1`，对应 `Mythril2D/Demo/Sprites/SPS_Effects.png`
- `Dialogue.prefab` 的 `7a7a06017d45ec84f9010d833ee328cb` 只出现在两个 `Button` 的 `SpriteState.m_HighlightedSprite`
- reference 与旧项目都找不到 `7a7a...` 对应 `.meta`；它不是当前仓可恢复的真实资产
- 这两个 `Button` 的 `m_Transition = 1`，运行时走 `ColorTint`，`SpriteState` 不参与显示；清零该字段不会改行为，但能去掉孤儿缺口
- GUID 扫描如果不纳入当前 `Library/PackageCache`，会把 `CanvasScaler`、`Image`、`Button`、`GraphicRaycaster`、`ContentSizeFitter`、`TextMeshProUGUI`、`InputSystemUIInputModule`、`PlayerInput` 等包内宿主误判为缺口
- 这一轮收口后，参考宿主差集稳定为：
  - `M2DEngine.unity`: `0000000000000000e000000000000000`
  - `Main Menu.unity`: `0000000000000000e000000000000000`、`357186adf88f47441beed107c9dbbe69`、`6a160d838ff8b4b4693ac20007e008c7`
  - `User Interface.prefab`: `0000000000000000f000000000000000`
- 当前 `Assets/Prefabs/UI/**/*.prefab` 内部扫描只剩 6 个 `0000000000000000f000000000000000` 占位 GUID，已不再存在真实缺失脚本、prefab 或 sprite
- 场景范围已被用户收窄为“只要测试换装场景”
- 当前项目内可直接装配的场景只有 `Assets/Scenes/SampleScene.unity` 与模板 `Assets/Settings/Scenes/URP2DSceneTemplate.unity`
- 参考树中最适合做换装测试宿主的是 `Mythril2D/Demo/Scenes/M2DEngine.unity`：
  - 它包含 `Inventory System`
  - 场景文本里有 `itemEquipped` / `itemUnequipped` 事件宿主
  - 它对应的 `User Interface` / `Inventory Menu` / `Character Menu` 资源闭包已基本收口
- 因此后续场景装配应只围绕 `Assets/Scenes/SampleScene.unity <- M2DEngine.unity` 这一条，不再继续扩散到 `Eldham_Village` / `Brusselia_Forest` / `Main Menu`
- `Assets/Scenes/SampleScene.unity` 已直接替换为 `M2DEngine.unity` 宿主内容，并保留原 scene meta
- 当前 `SampleScene.unity` 直连缺口只有 `0000000000000000e000000000000000`
- `SampleScene.unity` 中 `Player System.m_dummyPlayerPrefab` 已指向 `Devon.prefab`
- `SampleScene.unity` 中 `UI System.m_uiPrefab` 已指向 `User Interface.prefab`
- `ProjectSettings/EditorBuildSettings.asset` 当前唯一启用场景仍是 `Assets/Scenes/SampleScene.unity`

## Requirements
- 用户要把 `FantasyWorld` 的核心自研系统恢复并迁移到 `C:\Gamedev\Unity\Project\FantasyWord`
- 全程中文
- 不使用 `git reset` / `git revert` / 强制 checkout 到旧提交
- 插件、素材、Shader 损坏可以后补，但自研脚本尽量恢复
- `JKFrame` / `Mythril2D` 只是参考，旧代码优先
- 重点包括：
  - ZFrame
  - 背包
  - 换装
  - Shader 支持相关逻辑
  - 日志/任务
  - 商店/制作
  - 后续角色/战斗系统

## Key Discoveries
- 旧项目 `FantasyWorld` 大量 `.cs` 文件已经二进制污染，不能直接修语法
- 新项目 `FantasyWord` 已建立可编译恢复基线
- `UniTask` 原包损坏，已用官方 `2.5.10` 修复
- 商店、制作、日志、任务这几条主链已经重建并通过批编译
- 角色与控制器主链已经与战斗基础衔接完成，并通过新一轮 Unity 批处理编译
- 战斗基础这批采用“旧项目命名 + `Mythril2D` 同职责最小适配”的恢复方式
- 当前最重要的下一步是：
  1. 继续恢复 `Commands/CompleteTask.cs`
  2. 继续恢复 `Commands/AddOrRemoveAbility.cs`
  3. 进入 `Projectile` / Ability 周边缺口收缩

## Important File Paths
- 新项目：`C:\Gamedev\Unity\Project\FantasyWord`
- 旧项目：`E:\back\gameObject\project\FantasyWorld`
- 参考项目：`C:\Gamedev\Unity\Engine\2DRPGEngine\Assets\Mythril2D`
- 参考项目：`C:\Gamedev\Unity\Engine\2DRPGEngine\Assets\JKFrame`
- 恢复记录：`C:\Gamedev\Unity\Project\FantasyWord\RecoveryNotes`

## Restored Modules
- 已恢复：
  - `UniTask`
  - 背包 / 换装
  - 商店
  - 制作
  - 日志 / 任务
  - 基础命令
  - 基础条件
  - 角色 / 控制器
  - 战斗伤害 / 效果基础
- 进行中：
  - Ability / Projectile / 更多 Combat 缺口
- 待恢复：
  - `Commands/CompleteTask.cs`
  - `Commands/AddOrRemoveAbility.cs`
  - `Entities/Projectile.cs`
  - 更多 Ability / Combat 缺口

## Reference Decisions
- 优先使用旧项目里的“职责和命名”，不是直接照抄参考引擎
- 重建代码以当前 `FantasyWord` 的 `InventorySystem`、`DialogueSystem`、`ZFrame.UIMgr` 为中心
- 先恢复“代码主链可编译”，Prefab / 素材 / 插件引用后补

## Existing Recovery Notes
- `C:\Gamedev\Unity\Project\FantasyWord\RecoveryNotes\脚本恢复与隔离清单-2026-03-10.md`
- `C:\Gamedev\Unity\Project\FantasyWord\RecoveryNotes\UniTask修复-2026-03-10.md`
- `C:\Gamedev\Unity\Project\FantasyWord\RecoveryNotes\商店与制作恢复-2026-03-10.md`
- `C:\Gamedev\Unity\Project\FantasyWord\RecoveryNotes\窗口切换交接-2026-03-10-2.md`

## Multimodal / Search Findings
- 本地存在 `planning-with-files` 技能：
  - `C:\Users\zhuagenbao\.codex\skills\planning-with-files\SKILL.md`
- 该技能要求在项目目录保存：
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 之前本次恢复没有按该技能流程执行，主要使用的是内置 `update_plan` 和 `RecoveryNotes` 文档；现在已补齐三份规划文件

## Session Continuation 2026-03-10（新窗口）
- 已将外部维护的 `task_plan.md` / `findings.md` / `progress.md` 同步到当前项目根目录
- 交接文档确认：本窗口优先级是 `MonsterSheet` 奖励字段 -> 战斗基础文件 -> Unity 批处理编译
- 当前项目里 `Assets/Scripts/Database/Characters/MonsterSheet.cs` 已存在，但缺少：
  - `experienceReward`
  - `moneyReward`
  - `guaranteedLoot`
- 当前项目里缺失的战斗基础文件包括：
  - `Assets/Scripts/Combat/CombatSolver.cs`
  - `Assets/Scripts/Combat/DamageDescriptor.cs`
  - `Assets/Scripts/Combat/DamageSolver.cs`
  - `Assets/Scripts/Combat/EffectDispatcher.cs`
  - `Assets/Scripts/Combat/Effects/IEffect.cs`
  - `Assets/Scripts/Combat/Effects/Temporal/*`
- 旧项目 `FantasyWorld` 中对应 Combat 脚本文件名仍可参考，但文件内容已经二进制损坏，不适合直接迁入
- 可用的最近参考来源是：
  - `C:\Gamedev\Unity\Engine\2DRPGEngine\Assets\Mythril2D\Core\Runtime\Scripts\Combat\*`
  - `C:\Gamedev\Unity\Engine\2DRPGEngine\Assets\Mythril2D\Core\Runtime\Scripts\Database\Characters\MonsterSheet.cs`

## Validation Update 2026-03-10
- 新增并恢复的关键文件包括：
  - `Assets/Scripts/Combat/CombatSolver.cs`
  - `Assets/Scripts/Combat/DamageDescriptor.cs`
  - `Assets/Scripts/Combat/DamageSolver.cs`
  - `Assets/Scripts/Combat/EffectDispatcher.cs`
  - `Assets/Scripts/Combat/Effects/IEffect.cs`
  - `Assets/Scripts/Combat/Effects/Immediate/*`
  - `Assets/Scripts/Combat/Effects/Temporal/*`
- 同时补齐了：
  - `Assets/Scripts/Database/Characters/MonsterSheet.cs` 奖励字段
  - `CharacterBase` 的持续效果、动作锁与基础承载能力
  - `Movable` 的移速倍率基础
- Unity 批处理编译已通过：
  - `RecoveryNotes/unity-batch-compile-20260310-15.log`

## User Correction 2026-03-11
- 用户明确指出：`最小可编译实现` 不是目标
- 用户要求下限至少达到 `2DRPGEngine/Mythril2D` 的框架水准
- 因此当前 Combat / Effect 这批实现虽然可编译，但只能视为：
  - 过渡版
  - 用于摸清缺口和编译边界
  - 不能作为阶段完成标准
- 需要重做/加强的方向：
  - `AbilitySheet` / `ActiveAbilitySheet` 的 `IEffect` 数据接入
  - `AbilityBase` 层对 `EffectDispatcher.Apply` 的正式封装
  - `Projectile` / `ProjectileAbility` 与 effect 流的接入
  - `UIEffectList` / `UIEffectDescription` / `UIEffectListEntry` 对 temporal effect 元数据的消费
  - `CharacterBase` 上 effect 查询、移除、堆叠与宿主能力的完整化

## User Approval 2026-03-11
- 用户明确允许：对于损坏的同名文件，可直接对照参考同名文件恢复
- 因此本轮恢复策略改为：
  - 优先对照 `Mythril2D` 同名文件的结构和职责
  - 只在当前工程底座不同的地方做必要适配
  - 不再以“最小可编译”作为完成标准

## Recovery Update 2026-03-11
- 已按同名参考文件思路升级：
  - `AbilitySheet` / `ActiveAbilitySheet` / `ProjectileAbilitySheet`
  - `AbilityBase` / `ActiveAbilityBase`
  - `CharacterBase` 的能力容器、触发能力入口、动作控制兼容接口
  - `UIEffectList` / `UIEffectListEntry` / `UIEffectDescription`
  - `ProjectileAbility` / `Projectile`
  - `Commands/AddOrRemoveAbility.cs`
  - `Commands/CompleteTask.cs`
- 当前能力层已不再是纯占位：
  - `AbilitySheet.prefab` 已接入到 `CharacterBase` 的能力实例化流程
  - `AddBonusAbility` / `RemoveBonusAbility` / `FireAbility` 已落地到角色层
  - `ProjectileAbility` 与 `Projectile` 已能通过 effect 流驱动碰撞与爆炸
- 2026-03-11 的批处理编译日志：
  - `RecoveryNotes/unity-batch-compile-20260311-1.log`
  - `RecoveryNotes/unity-batch-compile-20260311-2.log`
  - `RecoveryNotes/unity-batch-compile-20260311-3.log`

## Recovery Batch 2 2026-03-11
- 本轮继续按同名参考文件补齐了可闭环的 Ability 批次：
  - `Animation/StateMessageDispatcher.cs`
  - `Combat/PerTargetCooldown.cs`
  - `Commands/ApplyEffectsToPlayer.cs`
  - `Conditional/Conditions/IsAbilityUnlocked.cs`
  - `Combat/Abilities/Active/MeleeAttackAbility.cs`
  - `Combat/Abilities/Active/SelfCastAbility.cs`
  - `Combat/Abilities/Passive/ContactDamageAbility.cs`
  - `Combat/Abilities/Passive/TickingAbility.cs`
  - `Database/Abilities/Passive/ContactDamageAbilitySheet.cs`
  - `Database/Abilities/Passive/TickingAbilitySheet.cs`
  - `Database/Abilities/Active/DashAbilitySheet.cs`
  - `Database/Abilities/Active/SummoningAbilitySheet.cs`
- 本轮明确跳过：
  - `DashAbility.cs`
  - `SummoningAbility.cs`
  - 原因是当前工程仍缺推挤、持久化与召唤物数据链等底座
- `missing-scripts-after-journal.txt` 对比结果：
  - 本轮前剩余 `112`
  - 本轮后剩余 `100`
- 本轮正式批处理编译日志：
  - `RecoveryNotes/unity-batch-compile-20260311-4.log`

## Recovery Batch 3 2026-03-11
- 本轮继续补齐了控制命令与条件激活器链路：
  - `Conditional/StateMachines/AConditionalActivator.cs`
  - `Conditional/StateMachines/ConditionalChildrenActivator.cs`
  - `Conditional/StateMachines/ConditionalReferencesActivator.cs`
  - `Commands/ExecuteCommandWithActionLock.cs`
  - `Commands/ToggleController.cs`
  - `Commands/MoveCamera.cs`
  - `Commands/PlayAudioClip.cs`
  - `Commands/Mono/CommandTrigger.cs`
- 这批按当前工程底座做了适配：
  - `ToggleController` 改为直接操作 `Character.controller`
  - `ExecuteCommandWithActionLock` 直接复用 `CharacterBase.LockActions/UnlockActions`
  - `MoveCamera` 改为基于 `Camera.main` 的 `UniTask` 位移策略
  - `PlayAudioClip` 改为直接用 `AudioSource.PlayClipAtPoint`
  - `CommandTrigger` 保留触发型事件，`OnConditionStateChanged` 改为显式通知入口
- `missing-scripts-after-journal.txt` 对比结果：
  - 本轮前剩余 `100`
  - 本轮后剩余 `92`
- 本轮正式批处理编译日志：
  - `RecoveryNotes/unity-batch-compile-20260311-5.log`

## Recovery Batch 4 2026-03-11
- 本轮继续补齐了交互链中当前可闭环的几类：
  - `Interactions/CommandInteraction.cs`
  - `Interactions/ConditionalInteraction.cs`
  - `Interactions/SequentialInteraction.cs`
  - `Interactions/DialogueInteraction.cs`
- 本轮明确暂缓：
  - `Interactions/InnInteraction.cs`
  - 原因是当前工程还没有参考工程那种“对话选择接受/拒绝”宿主接口
- `DialogueInteraction` 按当前工程做了适配：
  - 直接向 `DialogueSystem.Instance.Main` 或指定 `DialogueChannel` 发布 `DialogueSequence`
- `missing-scripts-after-journal.txt` 对比结果：
  - 本轮前剩余 `92`
  - 本轮后剩余 `88`
- 本轮正式批处理编译日志：
  - `RecoveryNotes/unity-batch-compile-20260311-6.log`

## Recovery Batch 5 2026-03-11
- 本轮补齐了系统层最直接会被当前链路消费的三项：
  - `Game/Systems/AudioSystem.cs`
  - `Game/Systems/UISystem.cs`
  - `Game/Systems/InputSystem.cs`
- 同时适配了系统入口与消费点：
  - `Game/GameManager.cs` 增加系统访问入口
  - `Game/Constants.cs` 补齐系统常量
  - `Commands/PlayAudioClip.cs` 优先走 `AudioSystem`
  - `Combat/Abilities/Active/ActiveAbilityBase.cs` 在触发时消费 `abilitySheet.fireAudio`
- 编译执行结论：
  - 直接在 Codex shell 里跑 Unity 批编译，命令可能返回 `0` 但不会生成 `-logFile`
  - 重新以提权方式执行后，`RecoveryNotes/unity-batch-compile-20260311-7.log` 正常生成且编译通过
- `missing-scripts-after-journal.txt` 对比结果：
  - 本轮前剩余：`88`
  - 本轮后剩余：`85`
- 下一批优先候选：
  - `Database/Characters/HeroSheet.cs`
  - `Database/Game/GameConfig.cs`
  - 后续再推进 `UI/Menus/Abilities/*` 与 `UI/HUD/Abilities/*`

## Recovery Batch 6 2026-03-11
- 本轮补齐了能力栏与角色技能配置底座：
  - `Database/Characters/HeroSheet.cs`
  - `Database/Game/GameConfig.cs`
  - `Utils/Scaling/LevelScaledInteger.cs`
  - `Database/Abilities/EAbilityType.cs`
- 同时扩展了运行时宿主链路：
  - `Game/GameManager.cs` 增加 `Config`
  - `Entities/Characters/CharacterBase.cs` 增加技能槽、装备/卸下、技能失败事件、技能栏变化事件
  - `Controllers/PlayerController.cs` 接入 `InputSystem` 的技能槽触发
- Ability UI 基础已补齐：
  - `UI/Generic/UIAbility.cs`
  - `UI/Generic/UITerm.cs`
  - `UI/Menus/Abilities/UIAbilities.cs`
  - `UI/Menus/Abilities/UIAbilityBar.cs`
  - `UI/Menus/Abilities/UIAbilityBarEntry.cs`
  - `UI/Menus/Abilities/UIAbilityCategory.cs`
  - `UI/Menus/Abilities/UIAbilityListEntry.cs`
  - `UI/HUD/Abilities/UIHUDAbilityBar.cs`
  - `UI/HUD/Abilities/UIHUDAbilityBarEntry.cs`
  - `UI/HUD/Abilities/UIHUDAbilityMessage.cs`
- 当前效果：
  - `CharacterBase` 不再只有“拥有技能实例”，而是具备可装备的主动技能槽
  - `PlayerController` 已能通过 `InputSystem` 的 `FireAbility1-5` 触发对应技能槽
  - `UIAbilities` / `UIHUDAbilityBar` / `UIHUDAbilityMessage` 已有可直接消费的运行时接口
- `missing-scripts-after-journal.txt` 对比结果：
  - 本轮前剩余：`85`
  - 本轮后剩余：`72`
- 本轮正式批处理编译日志：
  - `RecoveryNotes/unity-batch-compile-20260311-8.log`
- 下一批优先候选：
  - `UI/Menus/Character/UICharacter.cs`
  - `UI/Menus/Character/UICharacterStat.cs`
  - `UI/HUD/Stats/UIStatBar.cs`
  - `UI/UICharacterInfo.cs`

## Recovery Batch 7 2026-03-11
- 本轮继续补齐角色属性与状态展示 UI：
  - `UI/Menus/Character/UICharacter.cs`
  - `UI/Menus/Character/UICharacterStat.cs`
  - `UI/HUD/Stats/UIStatBar.cs`
  - `UI/UICharacterInfo.cs`
- 同时补了这批 UI 依赖的运行时接口：
  - `Hero.cs` 增加 `availablePoints` / `usedPoints` / `customStats` / `AddCustomStats`
  - `CharacterBase.cs` 增加 `NextLevelExperience` / `ExperienceToNextLevel`
  - `GameManager.cs` 增加 `InventorySystem`
  - `OpenMenu.cs` 将 `Character` / `Abilities` 改为走 `UIMgr.PushPanel`
  - `UIAbilities.cs` 改为 `BasePanel + IStackable`，避免关闭后无法再次打开
- `missing-scripts-after-journal.txt` 对比结果：
  - 本轮前剩余：`72`
  - 本轮后剩余：`68`
- 本轮正式批处理编译日志：
  - `RecoveryNotes/unity-batch-compile-20260311-9.log`
- 下一批优先候选：
  - `UI/Menus/UIGameMenu.cs`
  - `UI/Menus/UIGameMenuEntry.cs`
  - `UI/Menus/Settings/UISettings.cs`
  - `UI/Menus/Settings/UISettingsVolume.cs`
  - `UI/Menus/Settings/UISettingsMasterVolume.cs`
  - `UI/Menus/Settings/UISettingsChannelVolume.cs`

## Recovery Batch 8 2026-03-11
- 本轮继续补齐暂停/设置菜单链路：
  - `UI/Menus/UIGameMenu.cs`
  - `UI/Menus/UIGameMenuEntry.cs`
  - `UI/Menus/Settings/UISettings.cs`
  - `UI/Menus/Settings/UISettingsVolume.cs`
  - `UI/Menus/Settings/UISettingsMasterVolume.cs`
  - `UI/Menus/Settings/UISettingsChannelVolume.cs`
- 同时扩展了菜单链运行时入口：
  - `GameConfig.cs` 增加 `mainMenuSceneName` / `onTheGoCraftingStation`
  - `OpenMenu.cs` 将 `Pause` / `Settings` 改为走 `UIMgr.PushPanel`
- 当前效果：
  - 暂停菜单、设置菜单都已切到可重复打开的 `BasePanel + IStackable`
  - 设置菜单已直接接上当前工程的 `AudioSystem`
  - 暂停菜单入口可继续跳转到 Inventory / Journal / Character / Abilities / Settings / Craft
- `missing-scripts-after-journal.txt` 对比结果：
  - 本轮前剩余：`68`
  - 本轮后剩余：`62`
- 本轮正式批处理编译日志：
  - `RecoveryNotes/unity-batch-compile-20260311-10.log`
- 下一批优先候选：
  - `UI/HUD/Dialogue/UIDialogue.cs`
  - `UI/HUD/Dialogue/UIDialogueMessageBox.cs`
  - `UI/HUD/Dialogue/UIDialogueChoiceBox.cs`
  - `UI/HUD/Dialogue/UIDialogueOption.cs`
  - `UI/HUD/Dialogue/UIDialogueSpeakerBox.cs`

## Recovery Batch 9 2026-03-11
- 本轮补齐了对话 HUD 链路：
  - `UI/HUD/Dialogue/UIDialogue.cs`
  - `UI/HUD/Dialogue/UIDialogueMessageBox.cs`
  - `UI/HUD/Dialogue/UIDialogueChoiceBox.cs`
  - `UI/HUD/Dialogue/UIDialogueOption.cs`
  - `UI/HUD/Dialogue/UIDialogueSpeakerBox.cs`
- 同时扩展了对话发布逻辑：
  - `GameSystem/Dialogue/DialogueChannel.cs` 从“同步一次性发完整段”改成“队列顺序推进”，新增 `TryAdvance()`
  - 现有 `DialogueInteraction` / `PlayDialogueSequence` 等发布方无需改调用方，即可按句逐步显示
- 当前效果：
  - `UIDialogue` 可监听 `LinePublished` / `Cleared`
  - 对话消息框可使用当前工程 `InputSystem` 的 `submit` / `cancel` / `click` 做跳字或下一句
  - 选项框目前先保留基础壳，以兼容当前尚未恢复完整的 choice flow
- `missing-scripts-after-journal.txt` 对比结果：
  - 本轮前剩余：`62`
  - 本轮后剩余：`57`
- 本轮正式批处理编译日志：
  - `RecoveryNotes/unity-batch-compile-20260311-11.log`
- 下一批优先候选：
  - `UI/HUD/EventLog/UIEventLog.cs`
  - `UI/HUD/EventLog/UIEventLogLine.cs`
  - `UI/FloatingTexts/CombatTextDisplay.cs`
  - `UI/FloatingTexts/FloatingText.cs`
  - `UI/FloatingTexts/FloatingTextPool.cs`

## Recovery Batch 10 2026-03-11
- 本轮补齐了事件日志与飘字链路：
  - `Game/Events/GameEvents.cs`
  - `UI/HUD/EventLog/UIEventLog.cs`
  - `UI/HUD/EventLog/UIEventLogLine.cs`
  - `UI/FloatingTexts/CombatTextDisplay.cs`
  - `UI/FloatingTexts/FloatingText.cs`
  - `UI/FloatingTexts/FloatingTextPool.cs`
- 同时补了事件载荷与发布点：
  - `CharacterBase` 现在会为经验、升级、技能增删、伤害、治疗、法力变化、持续效果施加发布 payload
  - `InventorySystem` / `JournalSystem` 现在会为金钱、物品、任务状态变化发布 payload
  - `Immediate*` / `Temporal*` 效果与 `HealOrDamagePlayer` / `AddOrRemoveMana` 已改为复用角色层统一事件出口
- 当前效果：
  - `UIEventLog` 可直接消费经验、升级、金钱、物品、技能、任务的事件载荷
  - `CombatTextDisplay` 可直接消费伤害、Miss、治疗、法力变化、持续效果施加的事件载荷
  - 飘字与事件日志不再依赖参考工程里的 `NotificationSystem`
- 过程中遇到一次编译问题：
  - `EventHub.Subscribe/Unsubscribe` 对 payload 重载不会自动把方法组推断成 `Action<T>`
  - 处理方式：改成显式泛型订阅；重跑 `unity-batch-compile-20260311-12.log` 后通过
- `missing-scripts-after-journal.txt` 对比结果：
  - 本轮前剩余：`57`
  - 本轮后剩余：`51`
- 本轮正式批处理编译日志：
  - `RecoveryNotes/unity-batch-compile-20260311-12.log`
- 下一批优先候选：
  - `UI/Menus/AUIMenu.cs`
  - `UI/Menus/UIMainMenu.cs`
  - `UI/Menus/Death/UIDeath.cs`
  - `UI/Menus/Save/UISave.cs`
  - `UI/Menus/Save/UISaveFile.cs`

## Recovery Batch 11 Planning 2026-03-11
- 本轮先不碰 `UISave*` / `UIMainMenu`：
  - 当前工程缺少可落地的存档读写宿主，强补会退化成假 UI
- 改为优先补齐这组更容易闭环的 UI / 输入脚本：
  - `UI/Menus/AUIMenu.cs`
  - `UI/Menus/Death/UIDeath.cs`
  - `UI/UIControllerButton.cs`
  - `UI/UIControllerButtonManager.cs`
  - `UI/UINavigationCursor.cs`
  - `UI/UINavigationCursorTarget.cs`
  - `UI/UINavigationTarget.cs`
  - `UI/UIPlayerControllerFeedback.cs`
- 当前工程里已确认的宿主缺口：
  - `PlayerController` 还没有 `interactionTarget`、交互检测和暂停菜单触发入口
  - `UISystem` 还没有消费 `MenuRequestEvents.GameMenuRequested` / `MenuRequestEvents.DeathScreenRequested`
  - `UIMgr` 还没有统一分发 `ui.cancel` 到栈顶面板
- 当前工程里已确认的可复用底座：
  - 已存在 `NavigationCursorStyle`，无需再补数据库类型
  - `GameManager.EventSystem` 已可作为导航光标与选中态查询入口
  - `GameConfig` 当前已有导航/提交音效字段，但还缺参考工程里的 `interactionLayer`
- 实现约束：
  - `UIControllerButtonManager` 不能照搬参考里的 `SerializableDictionary` 方案，因为当前工程未接入对应序列化字典依赖

## Recovery Batch 11 2026-03-11
- 本轮补齐了死亡菜单与控制器 UI 这一组：
  - `UI/Menus/AUIMenu.cs`
  - `UI/Menus/Death/UIDeath.cs`
  - `UI/UIControllerButton.cs`
  - `UI/UIControllerButtonManager.cs`
  - `UI/UINavigationCursor.cs`
  - `UI/UINavigationCursorTarget.cs`
  - `UI/UINavigationTarget.cs`
  - `UI/UIPlayerControllerFeedback.cs`
- 同时补齐了当前工程的宿主入口：
  - `PlayerController` 现在有 `interactionTarget`、附近交互目标检索、交互触发、暂停菜单请求发布
  - `UISystem` 现在会消费 `MenuRequestEvents.GameMenuRequested` / `MenuRequestEvents.DeathScreenRequested` 与 `PlayerEvents.HeroKilled`
  - `GameConfig` 现在补回 `interactionLayer`
- 这批里确认了一个程序集边界约束：
  - `Assets/Plugins/ZFrame/RunTime/Manager/UI/UIMgr.cs` 所在的 `ZFrame.dll` 不能直接依赖项目层 `GameManager` 或 `UnityEngine.InputSystem`
  - 因此最终做法是：`UIMgr` 只保留栈顶选中态兜底，`ui.cancel` 输入分发放在项目层 `UISystem`
- `missing-scripts-after-journal.txt` 对比结果：
  - 本轮前剩余：`51`
  - 本轮后剩余：`43`
- 本轮正式批处理编译日志：
  - `RecoveryNotes/unity-batch-compile-20260311-13.log`

## Strategy Correction 2026-03-12
- 用户纠正本轮恢复策略：
  - 损坏文件直接迁移同名参考文件，再做必要修改
  - 完好文件先对比旧工程与当前工程，择优选用
  - 一般情况下，完好的旧工程实现优先级更高
- `Chest / Loot` 这一批的重新判定结果：
  - `E:\back\gameObject\project\FantasyWorld\Assets\Scripts\Entities\Chest.cs` 为二进制损坏文件
  - `E:\back\gameObject\project\FantasyWorld\Assets\Scripts\Interactions\ChestInteraction.cs` 为二进制损坏文件
  - `E:\back\gameObject\project\FantasyWorld\Assets\Scripts\Loot\ChestLoot.cs` 缺失
  - `E:\back\gameObject\project\FantasyWorld\Assets\Scripts\Loot\Loot.cs` 缺失
- 结论：
  - 这 4 个文件应按 `Mythril2D` 同名文件直接迁移
  - 当前工程只补最薄的宿主差异，例如：
    - `GameConfig.GetTermDefinition(string)`
    - `AudioClipResolver -> AudioClip`
    - `Dialogue queue API -> 当前 DialogueChannel 发布流程`

## Recovery Batch 14 2026-03-12
- 已将上一版 `Chest / Loot` 本地裁剪实现回退为“参考骨架优先”的重做版：
  - `Assets/Scripts/Entities/Chest.cs`
  - `Assets/Scripts/GamePlay/Loot/ChestLoot.cs`
  - `Assets/Scripts/GamePlay/Loot/Loot.cs`
  - `Assets/Scripts/Interactions/ChestInteraction.cs`
- 这次不是沿现有实现继续修补，而是按参考文件的字段/方法形状重新落地
- 额外薄适配只发生在当前工程明确缺失的宿主接口上：
  - `Assets/Scripts/Database/Game/GameConfig.cs` 新增 `GetTermDefinition(string)`
- 2026-03-12 重做后的批处理编译日志：
  - `RecoveryNotes/unity-batch-compile-20260312-18.log`

## Recovery Batch 15 2026-03-12
- 本批按用户纠正后的策略处理：
  - `Game/Systems/TransitionSystem.cs`：旧工程文件损坏，直接按 `Mythril2D` 同名文件迁移并改成当前 `EventHub` 宿主
  - `GamePlay/Maps/Teleporter.cs`：旧工程缺失，直接按参考同名文件迁移
  - `Interactions/InnInteraction.cs`：旧工程文件损坏，直接按参考同名文件迁移
- `Game/Systems/MapSystem.cs` 的判定与处理：
  - 旧工程备份路径下缺失，无法拿到更优旧版
  - 当前工程虽有文件，但只有 `RespawnPlayer`，不足以承接地图切换/委托过场/checkpoint/teleporter
  - 因此本轮择优采用参考 `MapSystem` 骨架替换当前极简版，而不是继续在现有薄实现上打补丁
- 为承接这批参考骨架，补了最薄宿主差异：
  - 扩展 `Assets/Plugins/ZFrame/RunTime/Manager/Scene/Checkpoints/ICheckpoint.cs`
  - 扩展 `Assets/Plugins/ZFrame/RunTime/Manager/Scene/SceneMgr.cs` 增加 `TryPopCheckpoint`
  - 扩展 `Assets/Scripts/Entities/Characters/CharacterBase.cs` 增加 `TeleportTo` / 方向判断 / `InterruptPush`
  - 扩展 `Assets/Scripts/Entities/Movable.cs` 接入真实移动方向判断
  - 调整 `Assets/Scripts/Database/Inns/Inn.cs`，将治疗音效改为可直接由当前 `AudioSystem` 播放的 `AudioClip`
  - 新增 `Assets/Scripts/GamePlay/Maps/Checkpoint.cs` 承接当前项目的 checkpoint 数据形状
- 当前地图过场链路具备：
  - `MapSystem.RequestTransition`
  - `MapSystem.TeleportTo`
  - `TransitionSystem` 订阅 `MapTransitionDelegationRequested`
  - `Teleporter` 触发方向判定、过场委托、到达后存 checkpoint
  - `InnInteraction` 完成付费、治疗、回蓝、对话和音效
- 2026-03-12 本批编译日志：
  - `RecoveryNotes/unity-batch-compile-20260312-19.log`
- 重算差集后，`missing-scripts-after-journal-current.txt` 已从 `22` 缩到 `19`

## Recovery Batch 16 2026-03-12
- 本批处理的是“缺路径，但当前工程已有更优同职责实现”的文件：
  - `Combat/Stats.cs`
  - `Combat/ObservableStats.cs`
  - `Game/Wearable.cs`
- 判定结果：
  - 当前工程已有 `Assets/Scripts/Entities/Stats.cs`，且已被战斗、UI、角色层广泛使用
  - 当前工程已有完整 `Equipment` 体系，职责上已覆盖 `Wearable`
  - 因此不再复制第二套并行 `Stats` / `Wearable` 主实现，而是做兼容桥接
- 具体落地：
  - 将 `Assets/Scripts/Entities/Stats.cs` 改为 `partial`
  - 新增 `Assets/Scripts/Combat/Stats.cs` 作为路径桥接文件
  - 新增 `Assets/Scripts/Combat/ObservableStats.cs`，按参考职责提供可观察 stats 容器
  - 新增 `Assets/Scripts/Game/Wearable.cs`，桥接到当前 `Equipment`
- 这批遵循的是用户策略里的“完好文件先择优”分支，而不是“损坏文件直接迁参考”分支
- 2026-03-12 本批编译日志：
  - `RecoveryNotes/unity-batch-compile-20260312-21.log`
- 重算差集后，`missing-scripts-after-journal-current.txt` 已从 `19` 缩到 `16`

## Recovery Batch 17 2026-03-12
- `Game/Systems/PlayerSystem.cs` 的恢复策略：
  - 旧工程文件损坏，无法直接复用
  - 参考文件完整，但强依赖 `PersistenceSystem` / `NotificationSystem`
  - 当前工程已具备 `Hero`、`GameManager.Player`、`PlayerEvents`、`MenuRequestEvents`、`DialogueSystem`
  - 因此落地为“保留参考职责、去掉 persistence 依赖”的当前宿主版
- 本批 `PlayerSystem` 已承担：
  - 发现当前场景里的 `Hero`
  - 必要时用 dummy prefab 实例化玩家
  - 维护当前 `PlayerInstance`
  - 在玩家死亡时清空对话并请求关闭菜单栈
- 同步扩展：
  - `Assets/Scripts/Game/GameManager.cs` 增加 `PlayerSystem` 入口
- 2026-03-12 本批编译日志：
  - `RecoveryNotes/unity-batch-compile-20260312-22.log`
- 重算差集后，`missing-scripts-after-journal-current.txt` 已从 `16` 缩到 `15`

## Recovery Batch 13 2026-03-12
- 已恢复宝箱与掉落闭环：
  - `Assets/Scripts/Entities/Chest.cs`
  - `Assets/Scripts/GamePlay/Loot/Loot.cs`
  - `Assets/Scripts/GamePlay/Loot/ChestLoot.cs`
  - `Assets/Scripts/Interactions/ChestInteraction.cs`
- 当前实现不是占位：
  - `Chest` 直接实现 `IInteractionTarget`
  - 可响应 `OnInteract`
  - 支持一次性开启、奖励发放、对话消息、内容图标轮播和开启音效
- 已顺带补齐通用宿主/工具：
  - `Assets/Scripts/Controllers/PlayerController.cs` 现可发现任意 `IInteractionTarget`
  - `Assets/Scripts/Miscellaneous/CoroutineHelpers.cs`
  - `Assets/Scripts/Miscellaneous/DisplayNameUtils.cs`
  - `Assets/Scripts/Commands/Mono/CommandTrigger.cs` 已改用 `CoroutineHelpers`
- 2026-03-12 批处理编译日志：
  - `RecoveryNotes/unity-batch-compile-20260312-16.log`
  - `RecoveryNotes/unity-batch-compile-20260312-17.log`
- 以 `missing-scripts-after-journal.txt` 重算后，剩余差集已从 `28` 缩到 `22`

## Path Normalization Note 2026-03-12
- `RecoveryNotes/missing-scripts-after-journal.txt` 的路径分隔符与转义形式不稳定：
  - 有的批次写成 `\\`
  - 有的批次写成 `/`
- 重算当前差集时必须先把参考清单和当前 `Assets/Scripts` 枚举结果统一归一化到同一种分隔符
- 本轮统一按 `/` 归一化后，`RecoveryNotes/missing-scripts-after-journal-current.txt` 已修正为真实剩余 `22`

## Recovery Batch 12 2026-03-12
- 鏈疆琛ラ綈浜嗗姩鐢诲簳搴э細
  - `AnimationUtils`
  - `CameraShake`
  - `FollowTargetDirection`
  - `TransformShaker`
  - `Animation/Strategies/*`
- 鍚屾椂鎵╁睍浜嗗綋鍓嶅伐绋嬬殑瀹夸富鍏ュ彛锛?
  - `CharacterBase` 澧炲姞 `targetDirectionChangedEvent`
  - `Movable` 鎺ュ叆鍔ㄧ敾绛栫暐銆佹柟鍚戝箍鎾€佹浜″姩鐢昏Е鍙戙€佸姩鐢绘秷鎭浆鍙?
  - `Character` 鏄惧紡缁х画 `Movable.OnEnable/OnDisable`
  - `GameConfig` 澧炲姞 `ECameraShakeSources` / `cameraShakeSources`
- 杩囩▼涓‘璁や簡涓€涓€傞厤绾︽潫锛?
  - 褰撳墠宸ョ▼娌℃湁 `azixMcAze.SerializableDictionary`
  - 鍥犳 `PolydirectionalAnimationStrategy` 鏀逛负鏁扮粍缁戝畾锛岃€屼笉鏄负鍗曚釜鑴氭湰鍐嶅紩鍏ユ柊渚濊禆
- 鏃ч」鐩?`DiagonalAnimationStrategy.cs` / `CharacterStateBase.cs` / `CharacterAnimState.cs` / `CharacterTriggerState.cs` 鏂囦欢鍚嶄粛鍦紝浣嗘枃浠跺唴瀹逛粛鏄簩杩涘埗鎹熷潖锛屾湰杞病鏈夌洿鎺ュ彲鐢ㄦ枃鏈彲杩佺Щ
- `missing-scripts-after-journal.txt` 瀵规瘮缁撴灉锛?
  - 鏈疆鍓嶅墿浣欙細`43`
  - 鏈疆鍚庡墿浣欙細`28`
- 鏈疆姝ｅ紡鎵瑰鐞嗙紪璇戞棩蹇楋細
  - `RecoveryNotes/unity-batch-compile-20260311-15.log`

## Recovery Batch 18 Update 2026-03-12
- `Spawners/*` 的判定结果：
  - 旧工程同名文件存在，但文件内容已损坏，不可直接复用
  - `Mythril2D` 参考同名文件完整，可直接按骨架迁移
  - 当前工程缺失的是 persistence/save-load 宿主，而不是刷怪主流程
- 因此本批采用：
  - 直接迁移 `AMonsterSpawner` / `MonsterSpawner` / `MonsterAreaSpawner`
  - 删除 `PersistableDataBlock` / `OnSave` / `OnLoad` / `PersistenceSystem.InstantiateCustom`
  - 保留参考版的权重刷怪、预刷怪、数量上限、区域随机出生点等主逻辑
- 为承接参考版的 `monster.SetLevel(...)` 调用：
  - 给 `CharacterBase` 增加了 `SetLevel(int)` 入口
  - 但没有引入参考工程的整套怪物成长数据，因为当前 `MonsterSheet` 不具备该数据面
- 当前 `Spawners` 运行时追踪方案：
  - 用 `List<SpawnedMonster>` 跟踪已刷出的怪
  - 每帧清理 `null` 或 `IsDead` 的条目，替代参考版依赖的 `destroyedEvent`
- 2026-03-12 本批编译日志：
  - `RecoveryNotes/unity-batch-compile-20260312-23.log`
- 重算差集后，`missing-scripts-after-journal-current.txt` 已从 `15` 缩到 `12`
- 当前剩余差集：
  - `_Editor/DatabaseWindow/DatabaseWindow.cs`
  - `_Editor/Playtest/EditorPlayModeOverride.cs`
  - `Combat/Abilities/Active/DashAbility.cs`
  - `Combat/Abilities/Active/SummoningAbility.cs`
  - `Entities/Characters/States/CharacterAnimState.cs`
  - `Entities/Characters/States/CharacterStateBase.cs`
  - `Entities/Characters/States/CharacterTriggerState.cs`
  - `GameSystem/Input/InputSystemGenerator.cs`
  - `MultiTrack.cs`
  - `UI/Menus/Save/UISave.cs`
  - `UI/Menus/Save/UISaveFile.cs`
  - `UI/Menus/UIMainMenu.cs`

## Recovery Batch 19 Update 2026-03-12
- `DashAbility` / `SummoningAbility` 的判定结果：
  - `Mythril2D` 同名运行时代码完整，可直接对照迁移
  - 当前项目已具备 `DashAbilitySheet` / `SummoningAbilitySheet`、`ActiveAbilityBase`、`AIController`、`CharacterBase` 等主要宿主
  - 缺口集中在推力系统、运行时阵营覆盖、传送通知与 AI 跟随入口
- 因此本批采用：
  - 直接迁移 `DashAbility.cs` / `SummoningAbility.cs` 的主流程
  - 在当前工程补齐 `Movable.Push` / `IsPushed`
  - 在当前工程补齐 `CharacterBase.Teleported` 与 `SetAlignmentOverride`
  - 在当前工程补齐 `AIController.SetTarget` / `SetMaster`
- `SummoningAbility` 的有意裁剪：
  - 不引入 persistence/data block 存档链
  - 不引入参考版的 `matchSummonerInvincibilityOnHit`
  - 不引入参考版的 `FlagAsSummoned` / `destroyedEvent`
  - 以上裁剪都对应当前工程明确不存在的宿主能力
- `Character States` 三个剩余脚本的现状：
  - 旧工程同名文件已损坏
  - 当前可访问参考集中未找到可读同名实现
  - 因此本轮不硬写，先继续清还有同名参考的剩余批次
- 2026-03-12 本批编译日志：
  - `RecoveryNotes/unity-batch-compile-20260312-24.log`
- 重算差集后，`missing-scripts-after-journal-current.txt` 已从 `12` 缩到 `10`

## Recovery Batch 20 Update 2026-03-12
- `DatabaseWindow.cs` / `EditorPlayModeOverride.cs` 在 `Mythril2D/Core/Editor` 中实际存在可读同名参考，之前把它们归到“无参考”分支的判断已失效
- 已直接迁移：
  - `Assets/Scripts/_Editor/DatabaseWindow/DatabaseWindow.cs`
  - `Assets/Scripts/_Editor/Playtest/EditorPlayModeOverride.cs`
- `DatabaseWindow` 的薄适配：
  - 去掉当前工程不存在的 `AudioClipResolver` / `CommandHandler` 标签类型
  - `PrefabReference` 仅在 `ODIN_INSPECTOR` 条件下加入
  - 菜单路径改为 `Window/FantasyWord/Database`
- `EditorPlayModeOverride` 的薄适配：
  - 改用当前工程可用的 boot scene 搜索，而不是依赖 `Constants.M2DEngineSceneName`
  - 改用 `SaveDataBlock -> MapDataBlock(playtest) -> MapSystem.LoadDataBlock` 入口，不再依赖失效的 `SaveFile.content`
- 为承接 editor playtest 链路，已补齐：
  - `Assets/Scripts/Game/Systems/SaveDataBlocks.cs` 中的 `MapDataBlock.playtest`
  - `Assets/Scripts/Game/Systems/MapSystem.cs` 中的 playtest checkpoint 传送分支
- `RecoveryNotes/unity-batch-compile-20260312-26.log` 已通过，差集从 `7` 缩到 `5`
- 当前剩余 5 个文件：
  - `Entities/Characters/States/CharacterAnimState.cs`
  - `Entities/Characters/States/CharacterStateBase.cs`
  - `Entities/Characters/States/CharacterTriggerState.cs`
  - `GameSystem/Input/InputSystemGenerator.cs`
  - `MultiTrack.cs`
- 当前工程中对这 5 个类名没有任何代码引用；它们已不属于继续沿现有主链平推的高优先级批次
- 额外搜索仅在其他项目里发现了无关的 `CharacterTriggerState.cs`，架构不同，不应作为当前批次的同名直接迁移参考

## Remaining Batch Assessment 2026-03-12
- `UISave.cs` / `UISaveFile.cs` / `UIMainMenu.cs`
  - 有完整同名参考
  - 但当前工程没有 `SaveSystem`
  - 当前工程也没有运行时数据库检索入口，无法可靠把 `entryID -> Item/Quest/SaveFile` 反解回来
  - 如果继续做这批，就需要先补：
    - 可运行的 `SaveSystem`
    - 至少一套当前工程可用的 save data schema
    - 运行时数据库索引/检索机制
- `CharacterStateBase` / `CharacterAnimState` / `CharacterTriggerState`
  - 旧工程文件损坏
  - 当前可访问参考集中未找到可读同名实现
- `InputSystemGenerator.cs` / `MultiTrack.cs`
  - 旧工程文件损坏
  - 当前可访问参考集中未找到可读同名实现
- `_Editor/DatabaseWindow/DatabaseWindow.cs` / `_Editor/Playtest/EditorPlayModeOverride.cs`
  - 旧工程文件损坏
  - 当前可访问参考集中未找到可读同名实现
- 结论：
  - 剩余 10 个文件已不再是“继续按现有节奏一批批平推”问题
  - 下一步最合理的路线是：先决定是否立项补 `SaveSystem`，否则就只能转入“无参考文件的自主设计恢复”分支
## Recovery Batch 21 2026-03-12
- 最后剩余的 `CharacterStateBase.cs` / `CharacterAnimState.cs` / `CharacterTriggerState.cs` / `InputSystemGenerator.cs` / `MultiTrack.cs`，在旧工程中源码已损坏，在当前可访问参考树中也找不到可直接迁移的同名实现
- 因此本批不再等待参考源码，而是按当前宿主恢复成可复用底座，不做占位空壳：
  - `CharacterStateBase`：落成真正可挂在 Animator State 上的 `StateMachineBehaviour`，负责角色查找、模式切换、动作锁和进出状态停移动
  - `CharacterAnimState`：复用当前工程已有的 `MessageData` / `IAnimationMessageReceiver`，支持 enter / exit / threshold 消息分发
  - `CharacterTriggerState`：在进入/退出状态时统一设置和重置 animator triggers / bools
  - `InputSystemGenerator`：把运行时代码从写死 `Gameplay` / `UI` 切到按实际 `.inputactions` 资产解析，并补 action alias 映射
  - `MultiTrack`：恢复成可用 Timeline 轨道，可向绑定对象派发 enter / exit `MessageData`
- 为承接这批底座，补了宿主对齐：
  - `CharacterBase` 增加 `SetMode(CharacterMode)`
  - `InputSystem` 改由 `InputSystemGenerator` 查找真实 action map / action
  - `PlayerController` 打开菜单改走 `InputSystemGenerator.WasOpenGameMenuPressed(...)`，并保留 `Keyboard.escape` / `Gamepad.startButton` 兜底
- `missing-scripts-after-journal-current.txt` 已重算为空文件，路径差集从 `5` 归零到 `0`
- `unity-batch-compile-20260312-29.log` / `unity-batch-compile-20260312-30.log` 的失败原因已确认不是脚本错误，而是当前沙箱里的 `LocalLow/Unity` 权限失败与 UPM IPC 连接失败
- 作为替代验证，使用 Unity 自带 Roslyn 复放 `Library/Bee/artifacts/1900b0aEDbg.dag/Assembly-CSharp.codex-validate.rsp`，`csc.dll` 退出码为 `0`

## Final Gap Assessment 2026-03-12
- 之前 `Remaining Batch Assessment 2026-03-12` 中“仍有 10 个/5 个缺口”的判断已失效；当前路径差集已清零
- 这轮恢复后的剩余风险不再是“缺脚本”，而是运行时实测：
  - Animator 状态 enter / exit / threshold 消息是否与现有控制器配置完全对齐
  - `InputSystemGenerator` 的 alias 是否覆盖所有场景里的输入调用
  - `MultiTrack` 在实际 Timeline 资产中的 binding / 消息接收对象是否齐全

## Static Validation Addendum 2026-03-12
- 已清理 `InputSystemGenerator` 的一个误导性日志源：当 `OpenGameMenu` / `Point` 这类 action 通过后备候选成功解析时，不再提前写入“Missing action”假警告
- 复查 `Assets/InputSystem_Actions.inputactions` 后确认：
  - map 只有 `Player` 与 `UI`
  - `Player` map 没有 `OpenGameMenu`
  - 因此当前 gameplay 状态下的开菜单仍主要依赖 `Escape` / `startButton` 这类原始兜底，而不是明确的 gameplay action
- 复查资产绑定后确认：
  - `CharacterStateBase` / `CharacterAnimState` / `CharacterTriggerState` / `MultiTrack` 目前在可见 `.unity` / `.prefab` / `.asset` 中还没有 GUID 引用
  - 仓内当前可见场景只有 `SampleScene.unity` 与 `URP2DSceneTemplate.unity` 这类模板场景，尚不足以验证真实 gameplay 宿主挂载
- 结论：
  - 当前源码层和路径层已经收口
  - 下一阶段如果继续推进，优先级应该从“补脚本”切到“装配运行时宿主与资源绑定”

## Host Compatibility Follow-up 2026-03-12
- `SaveFile.cs` 的真实编译边界已经确认：它属于 `Assets/Plugins/ZFrame/ZFrame.asmdef`，不能直接引用 `Assembly-CSharp` 里的 `SaveDataBlock`
- 首次用 `ZFrame.rsp` 复编时，`SaveFile.cs` 因 `SaveDataBlock` 依赖直接报 `CS0246`；这证明先前“把 `SaveFile.cs` 追加到 `Assembly-CSharp.codex-validate.rsp` 里”只能绕过问题，不能代表真实程序集可编译
- 稳妥解法是把 `SaveFile.m_content` 改成 JSON 字符串桥接：
  - `ZFrame` 侧只负责持有 `slotID + contentJson`
  - `SaveSystem` 侧通过 `ExtractSaveDataFromJson(...)` 在 `Assembly-CSharp` 内部解析 `SaveDataBlock`
- `Assembly-CSharp.codex-validate.rsp` 当前仍会漏掉本轮新增的 `Assets/Scripts` 源文件；要得到可信结论，必须显式追加：
  - `Audio/AudioChannel.cs`
  - `Game/Systems/GameStateSystem.cs`
  - `Game/Systems/NotificationSystem.cs`
  - `Game/Systems/PersistenceSystem.cs`
  - `UI/Menus/IUIMenu.cs`
  - `Database/Items/EItemTransferType.cs`
  - `Database/Audio/AudioClipResolver.cs`
- `Main Menu.unity` 里剩余的 `357186adf88f47441beed107c9dbbe69` 只在场景文本里出现，参考工程 `Assets` 与 `Library/PackageCache` 中都找不到对应 `.meta`，应视为参考场景遗留的孤儿引用，而不是当前项目缺失的可恢复资源
- `6a160d838ff8b4b4693ac20007e008c7` 对应参考引擎 `Library/PackageCache/com.unity.2d.pixel-perfect@09d99455b901/Runtime/PixelPerfectCamera.cs.meta`；当前项目没有这条旧包缓存 GUID，因此它不应继续按“缺失本地资源”处理
- 经过最小资源资产 + 低依赖 prefab / sprite / font 闭包推进后，参考宿主扫描结果已更新为：
  - `M2DEngine.unity`: 仅剩 1 个未知内置 GUID
  - `Main Menu.unity`: 仅剩 3 个未知/外部 GUID
  - `User Interface.prefab`: 仍剩 17 个，且大部分属于完整 UI prefab 链
- `User Interface.prefab` 的剩余项说明当前阻塞已从“脚本缺失”切换成“整套 UI prefab 宿主装配”；其中 `UIManager.cs` / `UIMenuManager.cs` 不是薄适配量级，后续应整批评估而非继续零碎补点

## MiniFantasy UV Dressing Correction 2026-03-13
- 用户已明确纠正目标：不是 `Mythril2D` 的可见武器切换链，也不是当前 `SampleScene` 铁甲三件套。
- 真实目标是 `MiniFantasy` 场景里的自研 `UV` 换装测试环境，用户记忆的交互是“点击角色，然后有测试按钮切换装备”。
- 因此此前所有把 `SampleScene` 视为“真实换装场景”的说法都应降级为“当前仓内的装备功能宿主”。
- 当前仓内 `EquipmentSpriteLibraryUpdater` / `Equipment.equippedSprite` / `Equipment.visualOverride` 这条链仍然是 `Sprite Library` 外观替换，不是用户描述的自研 `UV` 换装实现。
- `Wearable.cs` 在当前仓与旧备份里都只是空壳，不能证明 `UV` 换装逻辑已被恢复。

## MiniFantasy Candidate Intake 2026-03-13
- 已迁入以下候选素材包：
  - `Assets/ArtRes/KrishnaPalacio/MINIFANTASY - Crafting and Professions I`
  - `Assets/ArtRes/KrishnaPalacio/MINIFANTASY - True Heroes`
  - `Assets/ArtRes/KrishnaPalacio/MINIFANTASY - User Interface`
- 体量复核：
  - `MINIFANTASY - Crafting and Professions I`: `1049` files, `11288343` bytes
  - `MINIFANTASY - True Heroes`: `395` files, `1027998` bytes
  - `MINIFANTASY - User Interface`: `285` files, `3777237` bytes
- 当前仓内存在的关键候选：
  - `Assets/ArtRes/KrishnaPalacio/MINIFANTASY - Crafting and Professions I/Scenes/Demo - True Heroes Animations.unity`
  - `Assets/ArtRes/KrishnaPalacio/MINIFANTASY - Crafting and Professions I/Scenes/Demo - Charcter Animations.unity`
  - `Assets/ArtRes/KrishnaPalacio/MINIFANTASY - Crafting and Professions I/Scripts/TH_DemoManager.cs`
- 旧源中的第二候选：
  - `E:\back\gameObject\project\2DARPGEngine\Assets\KrishnaPalacio\MINIFANTASY - Dungeon\Scenes\Demo - Animated Characters.unity`
  - `E:\back\gameObject\project\2DARPGEngine\Assets\KrishnaPalacio\MINIFANTASY - Dungeon\Scripts\DUN_AnimatedCharacterSelection.cs`

## MiniFantasy Candidate Assessment 2026-03-13
- 当前仓内 `Demo - True Heroes Animations.unity.meta` 与 `TH_DemoManager.cs.meta` 已存在，说明候选资产路径落进了项目。
- 旧 `FantasyWorld` 项目 `Assets/Scenes` 下目前只发现一个用户场景：`E:\back\gameObject\project\FantasyWorld\Assets\Scenes\MainScene.unity`，`size=36400`，同样是非文本二进制场景；它应被视为比包自带 demo 更接近“原始项目宿主”的候选。
- 但对候选文件做二进制抽样后，当前仓与旧源里的场景/脚本都呈现明显的非文本特征：
  - `TH_DemoManager.cs`: `size=3616`, `nulls=10`, `printable_ratio=0.368`
  - `Demo - True Heroes Animations.unity`: `size=486746`, `nulls=15`, `printable_ratio=0.378`
  - `DUN_AnimatedCharacterSelection.cs`: `size=1770`, `nulls=6`, `printable_ratio=0.379`
  - `Demo - Animated Characters.unity`: `size=122822`, `nulls=16`, `printable_ratio=0.389`
- 这意味着：
  - `.cs` 级别上，这些候选不能当成可读源码恢复依据
  - `.unity` 级别上，它们最多还能被视为黑盒 Unity 资产，不能继续按“读 YAML / 改序列化文本”方式工作
- 当前最稳妥的推论是：真正的 `MiniFantasy + UV` 换装逻辑并没有在当前恢复出的可读脚本里落地，极可能仍埋在已损坏源里，或原本就是场景装配级实现。
- `MainScene.unity` 的存在说明：后续如果要从“包 demo”切到“用户原场景”路线，优先级应先看这个用户项目场景，而不是继续假设 `True Heroes` 一定就是目标。
- 因此主线阻塞已经从“用户是否来验证 `SampleScene`”切换成“如何找回或重建正确的 `MiniFantasy UV` 测试宿主”。

## Decision Update 2026-03-13
- 不再把 `SampleScene` 当成用户真正要的 `MiniFantasy UV` 换装场景。
- 不再继续沿 `EquipmentSpriteLibraryUpdater` 这条参考工程链推断用户的换装实现。
- 已迁入的 `MiniFantasy` 包暂时只作为素材源与黑盒候选场景，不再作为可直接迁脚本逻辑源。
- 下一步应优先二选一：
  - 继续在可访问旧源里找可读的自研 `UV` 换装宿主
  - 如果仍找不到，就基于已迁入的 `MiniFantasy` 资源自行重建一个最小测试场景与交互宿主

## MiniFantasy Compile Safety Update 2026-03-13
- Roslyn 直测已确认：
  - `TH_DemoManager.cs` 会触发大量 `CS1056` / `CS1002`
  - `TH_Projectile.cs` 会直接报 `CS2015`，被判定为二进制文件而非文本文件
- 因此这批 `Crafting and Professions I/Scripts/*.cs` 不能继续留在 `Assets`，否则会污染 Unity 编译。
- 已执行的工程防线动作：
  - 将该目录下 `13` 个损坏 `.cs` 及其 `.meta` 迁到 `MigrationStaging/MiniFantasyCorruptedScripts/...`
  - 保留 `Scenes/*.unity` 在 `Assets/ArtRes/KrishnaPalacio/.../Scenes`，继续作为黑盒候选资产
- 当前仓内 `Assets/ArtRes/KrishnaPalacio` 已无可参与编译的 `.cs`，因此这批候选不再阻断当前项目的 C# 编译链。
## Old Host Audit Update 2026-03-13
- 鎸夌収 `Window Handoff 2026-03-13` 缁х画鎺掓煡鏃?`FantasyWorld` 椤圭洰瀹夸富鍊欓€夛紝鏈疆鐩存寚 `MainScene.unity` 鍜?`PlayerInputHolder.prefab`
- 鏃ч」鐩笌褰撳墠椤圭洰鐨?GUID 瀵规瘮锛?
  - `Wearable.cs.meta`: 鏃?`ee6f1d4944725e742b2915aa8e9ab568`锛屾柊 `fd3300bb90a4cc44e9f2d96bd420dd17`
  - `HeroSheet.cs.meta`: 鏃?`ce1e0d9b1096041349779168632f7939`锛屾柊 `8ec2a3931c90c5c4eb53662c006dd576`
- 缁撹锛氬嵆浣挎棫鍦烘櫙鐪熺殑寮曠敤浜?`Wearable` / `HeroSheet`锛屼篃涓嶈兘鎶婂綋鍓?GUID 宸紓褰撴垚鍙互鐩存帴蹇界暐鐨勭粏鑺傦紝鍚庣画濡傛灉璧板吋瀹硅矾绾垮繀椤婚澶栧仛鏄犲皠鎴栧榻?
- 瀵规棫 `MainScene.unity` 鍜?`PlayerInputHolder.prefab` 鍋氫簡 ASCII 绾у埆鎶芥牱鎺掓煡锛岀粨鏋滄槸锛?
  - 鏈彁鍙栧埌 `Wearable` / `HeroSheet` / `PlayerInputHolder` 瀛楃涓?
  - 涔熸湭鎻愬彇鍒颁笂杩?4 涓?GUID 鐨?ASCII 蹇収
- 杩欒繘涓€姝ヨ鏄庯細褰撳墠鍙闂殑鏃?`MainScene` 鍜?`PlayerInputHolder` 鏇村儚榛戠洅 Unity 浜岃繘鍒惰祫浜э紝涓嶉€傚悎缁х画鎸夆€滆鍑哄彲瑙嗘枃鏈?YAML / 鐩存帴鍙嶆煡寮曠敤鈥濈殑鎬濊矾鎺ㄨ繘
- 瑙勫垝鍚箟鏇存柊锛?
  - `MainScene.unity` 鐩墠鍙兘浣滀负鈥滅敤鎴峰師瀹夸富榛戠洅鍊欓€夆€濓紝涓嶆槸鈥滃彲鐩存帴淇?GUID 鍗冲彲澶嶆椿鐨勫彲璇诲満鏅€?
  - 涓嬩竴姝ュ簲浼樺厛鎵╁ぇ鏃ф簮鎼滅储锛岀湅鏄惁杩樻湁鍙鐨?`UV` 鎹㈣鑴氭湰 / prefab / editor 宸ュ叿
  - 濡傛灉浠嶇劧鍙兘鎵惧埌榛戠洅鍦烘櫙锛屽垯涓荤嚎搴旇浆涓衡€滃熀浜?MiniFantasy 绱犳潗閲嶅缓鏈€灏忔祴璇曞涓衡€?
## Old Source Readability Sweep 2026-03-13
- 鏈疆瀵?`E:\back\gameObject\project\FantasyWorld\Assets` 鍋氫簡涓€杞?filename 绾у埆鎼滅储锛屽叧閿瓧鍖呮嫭 `uv` / `wear` / `equip` / `dress` / `hero` / `playerinputholder` / `characterselect` / `button`
- 鎼滅储鍒扮殑鍚嶅瓧绾х嚎绱㈤噷锛屼粛鐒舵渶鍊煎緱鍏虫敞鐨勫彧鏈夎繖鍑犵被锛?
  - `PlayerInputHolder.prefab`
  - `Wearable.cs` / `HeroSheet.cs`
  - `UIControllerButtonManager.cs` / `UIControllerButton.cs`
  - `EquipmentSpriteLibraryUpdater.cs`
  - `DUN_AnimatedCharacterSelection.cs`
- 浣嗙户缁悜鍐呭眰楠岃瘉鍚庯紝缁撹鏇村姞鏄庣‘锛?
  - 针对 `UIControllerButtonManager.cs` / `UIControllerButton.cs` / `PlayerInputBridge.cs` 的直接读取结果仍是损坏的二进制噪声，而不是可读 C# 文本
  - 鍓嶉潰宸茬粡鏍稿疄杩囩殑 `TH_DemoManager.cs` / `DUN_AnimatedCharacterSelection.cs` 涔熷悓鏍蜂笉鍏峰鍙洿鎺ヨ皟鐮佷环鍊?
  - 鏈疆瀵瑰綋鍓嶄粨鍐呭啀鎼?`PlayerInputHolder` / `UV` / `CharacterSelection` 绛夊叧閿瓧锛屾病鏈夊嚭鐜版柊鐨勫彲璇?MiniFantasy UV 瀹夸富
- 鏂版帹璁猴細
  - 鏃у浠戒腑鈥滅偣鍑昏鑹插悗鍑虹幇鎸夐挳鈥濈殑浜や簰鍙兘纭疄瀛樺湪杩囷紝浣嗗綋鍓嶅彲璁块棶鐨勮剼鏈眰宸茬粡涓嶅叿澶囧彲鎭㈠鎬?
  - 鍥犳瑙勫垝涓婂簲鎶娾€滄壘鍥炲彲璇?UV 宿主鈥濊涓轰竴涓湁闄愭悳绱㈤樁娈碉紝涓嶈鍐嶆妸瀹冨綋浣滈粯璁ゅ彲琛岀殑涓荤嚎
  - 濡傛灉涓嬩竴杞畾鐐规悳绱㈤噷浠嶆病鏈夊彲璇绘湰鏂囩嚎绱紝灏卞簲鐩存帴杞叆鈥滃熀浜?MiniFantasy 绱犳潗閲嶅缓鏈€灏忔祴璇曞涓衡€?
## Final Text-Only Probe 2026-03-13
- 鏈疆鍙拡瀵规枃鏈被鏂囦欢鍋氭渶鍚庝竴杞畾鐐规帰娴嬶細`.meta` / `.txt` / `.md` / `.asset`
- 鐩存帴缁撴灉锛?
  - `PlayerInputHolder.prefab.meta` 鍙兘鎷垮埌 prefab 自韬?GUID锛?`ee62267556711834bb16d2f7aed28855`
  - `.meta` 鏂囦欢閲岃兘绋冲畾鍛戒腑鐨勪篃鍙湁宸茬煡鐨?`Wearable` / `HeroSheet` GUID
  - `TH Documentation.txt` 鐩存帴璇诲彇浠嶆槸浜岃繘鍒跺櫔闊筹紝涓嶆槸鍙璇存槑鏂囨。 
  - 缂╁皬鍒?`Scripts` / `Prefabs` / `ArtRes\\KrishnaPalacio` 鐨勬枃鏈悳绱紝涔熸病鏈夊嚭鐜?`MiniFantasy UV` 宿主鐨勬柊鏂囨湰绾跨储
- 缁撹锛氬綋鍓嶅彲璁块棶鏃ф簮宸茬粡涓嶅お鍙兘鍐嶆彁渚涘彲璇荤殑 `MiniFantasy UV` 宿主鎭㈠渚濇嵁锛岄櫎闈炶繕鏈夋湭鎻愰湶鐨勫叾浠栧浠藉湴鐐?
## Rebuild Route Draft 2026-03-13
- 鍩轰簬褰撳墠浠撳唴鍙璧勪骇鍐嶆锛岄噸寤鸿矾绾跨幇鍦ㄥ凡鏈夎冻澶熺殑鈥滃彲澶嶇敤鎵撳簳浠垛€濓細
  - `Assets/Scripts/UI/UIControllerButtonManager.cs` 鍜?`Assets/Scripts/UI/UIControllerButton.cs` 鍧囦负鍙涓旂粨鏋勫畬鏁寸殑鎸夐挳鏄剧ず閾?
  - `Assets/Prefabs/UI/UI Controller Button Manager.prefab` 宸茬粡閰嶅ソ 3 绉?controller sprite libraries
  - `Assets/Prefabs/UI/User Interface.prefab` 鍐呴儴宸叉寕 `Interaction Button Feedback`锛屽苟涓?`UIPlayerControllerFeedback` + `UIControllerButton` 鐩存帴璺熼殢 `PlayerController.interactionTarget`
  - `Assets/Scripts/UI/UIPlayerControllerFeedback.cs` 鏄庣‘璇佹槑锛氬綋鍓嶆寜閽嚭鐜伴€昏緫鏄€滃熀浜?playerController.interactionTarget 鐨勪笘鐣岀┖闂村弽棣堚€濓紝鑰屼笉鏄?old MiniFantasy 宿主涓凡绂诲け鐨勯粦鐩掕剼鏈?
- 褰撳墠鍙敤鐨?MiniFantasy 绱犳潗鍩虹嚎锛?
  - 瑙掕壊鍚?`Barbarian` / `Druid` / `Rogue`
  - 鍖呰璧勬簮鍚?`MINIFANTASY - True Heroes/Animations/Characters/*`
  - 鍚屾牱鍙敤鐨勭簿鐏靛浘闆?`MINIFANTASY - Crafting and Professions I/Sprites/{Barbarian,Druid,Rogue}`
  - UI 绱犳潗涓?`MINIFANTASY - User Interface` 锛屽綋鍓嶈兘纭鐨?prefab 鍙湁 `Slot.prefab` / `Slot Shadow.prefab` / `Pixel Grid Alignment Sprite.prefab`
- 鏂扮殑鍏抽敭缁撹锛?
  - 褰撳墠浠撳唴鐨?MiniFantasy 脚本/doc 杩欐潯绾块噷锛?`UI Documentation.txt` 涔熸槸鎹熷潖鍐呭锛屼笉鑳戒綔涓洪噸寤鸿鏄庝緷鎹?
  - 鎵€浠ラ噸寤洪渶瑕佷緷璧?鈥滃綋鍓嶅彲璇?gameplay / UI 宿主鈥?+ 鈥淢iniFantasy 缇庢湳璧勬簮鈥?锛岃€屼笉鑳藉啀绛夊寘鍐呮枃妗ｆ垨绀轰緥鑴氭湰
  - 褰撳墠鍙鐢ㄧ殑浜や簰閫昏緫鏄?鈥滈潬杩戦€夌洰鏍?+ Interact 鍑烘寜閽弽棣堚€濓紝浣嗙敤鎴疯蹇嗙殑鏄?鈥滅偣瑙掕壊鍚庡嚭娴嬭瘯鎸夐挳鈥濓紝杩欐剰鍛崇潃杩樿鏂板涓€灞傝杽鐨?click-to-select 宿主閫昏緫
- 鏈€绋冲Ε鐨勯噸寤哄喅绛栨槸锛?
  - 鍦烘櫙璺緞浼樺厛缁х画浣跨敤 `Assets/Scenes/SampleScene.unity`锛屼絾鍏惰涔夎浠庘€滅幇鏈夋崲瑁呭姛鑳芥矙鐩掆€濆崌绾т负鈥滈噸寤哄悗鐨?MiniFantasy 鍗曞満鏅祴璇曞涓烩€?
  - 杩欐槸鈥滃嶇敤鍞竴鍦烘櫙璺緞 + 淇濈暀 build settings + 鎹㈡帀鍦烘櫙鍐呭鈥濈殑璺嚎锛屾瘮鏂板鍦烘櫙鍐嶅垏 build settings 鏇寸ǔ
  - 鍔熻兘灞備紭鍏堝畾涔変负 3 灞傦細
    - `MiniFantasy` 瑙嗚鎵胯浇锛氳鑹层€佽儗鏅垨鎿嶄綔鍖鸿瑙夋浛鎹?
    - 鐐瑰嚮閫夋嫨灞傦細鐐瑰嚮瑙掕壊鍚庤褰曞綋鍓嶆祴璇曠洰鏍?
    - 娴嬭瘯鎸夐挳灞傦細鍑虹幇 1 缁?3 涓敤浜?UV / 绱犳潗鍒囨崲鐨勬寜閽?
## First Character Candidate Decision 2026-03-13
- 褰撳墠 3 涓?MiniFantasy 瑙掕壊鍊欓€夌殑璧勬簮閲忓姣旂粨鏋滐細
  - `Barbarian`: `Sprites=104`, `Animations=92`
  - `Druid`: `Sprites=163`, `Animations=172`
  - `Rogue`: `Sprites=77`, `Animations=78`
- 鏂扮殑鍐冲畾锛氱涓€鐗堥噸寤哄涓荤殑涓昏浼樺厛閫?`Rogue`
- 鐞嗙敱锛?
  - 璧勬簮閲忔渶灏忥紝鏈€閫傚悎鍏堟妸鈥滅偣瑙掕壊 -> 鍑烘寜閽?-> 鍒囨崲鍙缁撴灉鈥濇墦閫?
  - 鍔ㄤ綔闆嗕粛鐒跺畬鏁达紝鍖呭惈 `Idle / Walk / Attack / Jump / Dmg / Die / ThrowBomb / Shurikens`锛屼笉鏄函鏈€灏戞潗璐ㄧ殑鈥滃崰浣嶈鑹测€?
  - 鐩告瘮 `Druid`锛屽彲閬垮紑鍙樿韩鍒嗘敮甯︽潵鐨勯噸寤鸿寖鍥存墿澶?
  - 鐩告瘮 `Barbarian`锛屾洿绠€鐭殑璧勬簮闂寘鏇撮€傚悎鐢ㄤ綔绗竴杞祴璇曞涓?
- 鏈喅绛栫殑鍚箟鏄細鍚庣画 `B2` 鍜?`B4` 閮藉簲浠?`Rogue` 浣滀负榛樿宸ヤ綔鍩哄噯锛屽叾浠栬鑹叉殏涓嶇撼鍏ョ涓€杞?
## Readable UV Runtime Assessment 2026-03-13
- 已确认 `C:\Users\zhuagenbao\Desktop\MiniCharacterCreator-main\test\Assets\Scripts\EquipmentSystem` 不是零散 demo，而是完整可读的 `UV` 换装系统：
  - `EquipmentRenderer.cs` 负责运行时装备渲染与材质参数下发
  - `EquipmentDemoExtension.cs` 提供测试面板、装备切换、动画切换目标绑定
  - `AnimationController.cs` 负责 Animator Bool/方向切换与阴影开关
  - `DualUVMapGenerator.cs` 负责离线生成 `bodyUVMap/headUVMap`
  - `EquipmentUV.shader` 负责最终的 `UV` 映射、层级、武器、描边、肤色映射
- 结论：
  - 这是当前已找到的第一条“真实可读”的 `MiniFantasy UV` 实现来源
  - 相比损坏的 `FantasyWorld` 旧项目，这条线索的恢复价值明显更高
  - 后续若进入实现，应优先从这套 `EquipmentSystem` 迁移或裁剪，而不是继续从损坏旧脚本猜逻辑

## EquipmentSystem Host Topology 2026-03-13
- 在 `C:\Users\zhuagenbao\Desktop\MiniCharacterCreator-main\test\Assets\_Recovery\0.unity` 中确认到以下宿主骨架：
  - `EquipmentDemoExtension` 已经挂在场景对象上，并持有 `availableEquipments`
  - `EquipmentRenderer` 已经挂在角色对象上，并绑定 `frameData` / `overrideShader`
  - 多个 UI Button 事件绑定到：
    - `MyCharacterSelection.ToggleCharacter`
    - `Creatures_AnimatedCharacterSelection.ToggleAnimation`
    - `Creatures_AnimatedCharacterSelection.TurnOffCurrentParameter`
- 推断：
  - 角色选择不是 `EquipmentDemoExtension` 自己做的
  - `EquipmentDemoExtension` 更像是“当前目标角色的测试面板”
  - 真实宿主分为三层：
    - 角色选择层
    - 动画测试层
    - `UV` 装备测试层

## Rogue Prefab Assessment 2026-03-13
- `C:\Users\zhuagenbao\Desktop\MiniCharacterCreator-main\test\Assets\Art\MINIFANTASY - Crafting and Professions I\Prefabs\Characters\Rogue.prefab`
  当前可读内容显示：
  - 带有 `SpriteRenderer`
  - 带有 `Animator`
  - 带有一个 projectile 相关脚本
  - 当前 prefab 文本里未直接看到 `EquipmentRenderer` / `AnimationController`
- 推断：
  - 可运行的 `UV` 宿主不一定直接写死在角色 prefab 里
  - 更可能是场景层或恢复场景实例上再挂 `EquipmentRenderer`
  - 因此后续实现不应假设“把 `Rogue.prefab` 直接拖进来就自带 `UV` 换装”

## Clarified Answer To The Old-Project Question 2026-03-13
- 对“是不是对照损坏的旧项目实现的 `UV` 换装”这个问题，当前最准确的结论是：
  - 不是继续直接对照 `FantasyWorld` 那份损坏旧源码做逐字恢复
  - 旧项目目前只负责提供目标交互记忆和边界
  - 真正可读、可复用的 `UV` 技术实现来源，已经转移到 `MiniCharacterCreator-main\\test\\Assets\\Scripts\\EquipmentSystem`
- 如果后续进入实现阶段，实际落地方案会是：
  - 用这个可读 `EquipmentSystem` 还原 `UV` 换装能力
  - 再在当前项目里补出“点角色 -> 出测试按钮”的宿主薄层
## Execution Findings 2026-03-13 MiniFantasy UV Human Host
- 已实际迁入 `EquipmentSystem` 源码：
  - `Assets/ThirdParty/MiniFantasyUV/Scripts/EquipmentSystem`
- 已实际迁入可直接引用的数据资产：
  - `Assets/ThirdParty/MiniFantasyUV/Data/AnimationType`
  - `Assets/ThirdParty/MiniFantasyUV/Data/Appearance`
  - `Assets/ThirdParty/MiniFantasyUV/Data/Equip`
  - `Assets/ThirdParty/MiniFantasyUV/Data/FrameData`
- 已按 `uv_guid_source_map.csv` 将依赖资源镜像到：
  - `Assets/ThirdParty/MiniFantasyUV/ImportedSource`
- 这轮复制后重新扫描，`Assets/ThirdParty/MiniFantasyUV/Data/**/*.asset` 的缺失 GUID 已收敛为 `0`
- `EquipmentDemoExtension` 已补两个宿主开关：
  - `autoPickActiveRenderer`
  - `showPanelWithoutSelection`
- 因此当前可以用独立宿主实现用户记忆中的交互顺序：
  - 先点击角色
  - 再出现换装测试面板
- 当前最稳的宿主构建方式不是手写 scene YAML，而是用 Editor 生成器在 Unity 内生成：
  - `Assets/Scripts/_Editor/MiniFantasyUV/MiniFantasyUVSceneBuilder.cs`
- 生成器目标输出场景：
  - `Assets/Scenes/MiniFantasyUVTest.unity`
- 生成器会自动完成这些装配：
  - 实例化当前项目内的 `Human.prefab`
  - 挂 `EquipmentRenderer`
  - 挂 `AnimationController`
  - 绑定 `HumanFramData.asset`
  - 绑定 `CharacterAppearance.asset`
  - 绑定 `AnimationTypeDatabase.asset`
  - 绑定 `EquipmentUV.shader`
  - 挂点击选择宿主和可选中标记

## GUID Drift Findings 2026-03-13
- `HumanFramData.asset` ����� Unity �б���Ϊ��
  - `mainType=(null)`
  - `rawAsset=(null)`
  - `typedAsset=(null)`
- ͨ���½�����ʲ�ȷ�ϣ�
  - `CharacterFrameData` �ű������ɴ������ɱ��桢�����¶���
  - ���ⲻ���ඨ�壬���ھ��ʲ��Խű� GUID �İ�
- batch ������ Unity ��ǰʵ�ʼ�¼�Ľű� GUID ����� `.meta` ԭʼ GUID ��һ�£���ʵ��ӳ�����£�
  - `CharacterFrameData.cs`: `992a... -> fc994bebc35494f46b10ca9a0616cd5a`
  - `CharacterAppearance.cs`: `8f3a... -> 32449d36b72aacb4e988367415303414`
  - `AnimationTypeDatabase.cs`: `ccfe... -> 4692367c505d8e544ba5049f0e52fc1a`
  - `AnimationTypeItem.cs`: `7c90... -> 3b5d855e7426ae84f933be6c0f0ed3ee`
  - `EquipmentRenderData.cs`: `a743... -> f10408a33f0220f4689aca3a3e8c63de`
- ���ۣ�
  - ��ǰ MiniFantasy UV ���������ĺ��Ĳ��ǡ�asset ���廵�ˡ������ǡ��ű� meta GUID Ư�ƺ󣬸��ƹ����� ScriptableObject �ʲ��԰󶨾� GUID��
  - ��ȷ�޷��Ƕ��뵱ǰ������ʵ GUID��������������Ӱ���ʲ�ͷ��
- ������֤�����
  - `FrameData / Appearance / AnimationDatabase / AnimationTypeItem / EquipSample` ������������
  - `CreateOrUpdateScene` �� batch �������������ߵ� `Scene saved: Assets/Scenes/MiniFantasyUVTest.unity`

## AIBridge Findings 2026-03-13
- Unity ����װ��ʽ�Ѷ��� README��`"cn.lys.aibridge": "https://github.com/wang-er-s/AIBridge.git"`��
- ���� `[AIBridge] SKILL.md path not found ... Packages/AIBridge/Skill~/SKILL.md` �ĸ����ǰ���·��д�� `Packages/AIBridge`���� git ���� `cn.lys.aibridge` ��һ�¡�
- ��ǰ��ʱ�޸�λ�� `Library/PackageCache/.../AIBridgeSettingsWindow.cs`�����õ����ڰ��ؽ����ʧЧ��
- CLI �ؼ�������Ч��`--raw`��`--timeout <ms>`��Ĭ�� 5000ms �Գ�������ƫ�̡�
- ʵ�������������`SceneCommand_Load --timeout 60000` + `ScreenshotCommand_Image --timeout 20000`��
- ʵ���ͼ���Ŀ¼��`AIBridgeCache/screenshots`��

## AIBridge Automation Findings 2026-03-13
- 已确认自动化链路可稳定复现：`SceneCommand_Load --raw --timeout 60000` + `ScreenshotCommand_Image --raw --timeout 20000`。
- 回归脚本首轮失败根因有两个：
  - PowerShell 参数名使用 `$Args` 与自动变量冲突，导致 CLI 实际未收到命令参数。
  - `SceneCommand_Load` 未带 `--raw` 时输出非 JSON 文本（例如 `loaded: true`），会导致 JSON 解析失败。
- 修复后结果：
  - `AIBridgeCache/results/aibridge-smoke-20260313-214030.json` 显示 `pass=3, fail=0`。
  - 三轮截图产物分别为：
    - `AIBridgeCache/screenshots/game_20260313_214034_de45721c.png`
    - `AIBridgeCache/screenshots/game_20260313_214043_b076cacf.png`
    - `AIBridgeCache/screenshots/game_20260313_214047_6b4552e5.png`
- 结论：AIBridge 截图链路已达到“可脚本化 + 可重复回归”的稳定状态。

## MiniFantasyUV Missing Prefab Fix 2026-03-13
- 已复现用户报错：`MiniFantasyUVTest.unity` 打开时报 9 个角色 Prefab 缺失（按 GUID）。
- 根因拆分：
  - 6 个角色（Human/Goblin/Orc/Elf/Halfling/Dwarf）在当前项目中存在 `.meta` 但 `.prefab` 内容曾损坏。
  - 3 个角色（Skeleton/HumanAmazon/HumanTownsfolk）原先未在当前工程路径中落地对应 Prefab 资产。
  - 覆盖文件后若时间戳和长度与旧文件接近，Unity 可能未立即重导入，导致仍读旧缓存。
- 修复动作：
  - 从 `MiniCharacterCreator-main/test` 可读源补齐并覆盖 9 个 prefab + meta。
  - 通过 AIBridge 对这 9 个 prefab 执行 `AssetDatabaseCommand_Import --forceUpdate true` 强制重导入。
- 验证结果：
  - `AssetDatabaseCommand_GetPath` 已能解析全部 9 个 GUID 到有效 prefab 路径。
  - 场景重载日志捕获 `captured=1` 且 `missing_related=0`，`Missing Prefab Asset` 报错消失。

## MiniFantasyUV AnimatorOverrideController Corruption Fix 2026-03-13
- 用户反馈的核心报错是 `Failed to load ... *_AnimatorOverrideController.overrideController`，涉及 `Dwarf/Elf/Orc/Goblin/Halfling`。
- 定位结果：当前项目这批 `.overrideController` 文件本体是二进制噪声（含 `null bytes`，不可读 YAML），与可读源版本不一致。
- 修复动作：
  - 从 `C:\Users\zhuagenbao\Desktop\MiniCharacterCreator-main\test\Assets\Art\MINIFANTASY - Crafting and Professions I\Animations\Humanoids` 全量覆盖到当前项目同路径（含 `.meta`）。
  - 对 5 个报错控制器执行 `AssetDatabaseCommand_Import --forceUpdate true`，并执行 `AssetDatabaseCommand_Refresh --forceUpdate true`。
- 同步修复运行时报错：
  - `AnimationController.cs` 增加 `runtimeAnimatorController == null` 保护，避免 `Animator is not playing an AnimatorController` 日志。
- 复检结论：
  - 仅加载 `MiniFantasyUVTest.unity` 时，日志捕获 `captured=0`，无上述报错。
  - 场景切换 `SampleScene -> MiniFantasyUVTest` 后，`BAD_COUNT=0`（针对本次 5 类报错过滤）。

## MiniFantasyUV Final Verification 2026-03-14
- After replacing corrupted humanoid animation override assets and reimporting, the previous load failures are no longer reproducible.
- `AnimationController.cs` null-controller guard prevents runtime `Animator.SetFloat` spam when controller is temporarily missing.
- AIBridge validation now passes in both checks:
  - Scene load check: `ERRORS=0`
  - Refresh/compile check: `ERRORS=0`

## Material Migration Audit 2026-03-14
- Source-to-target gap existed before sync:
  - `Assets/Art`: `3017` files total, `1975` missing in target mapping.
  - `Assets/Minifantasy_NPCs_Assets`: `3555` files total, target root absent.
- Applied safe sync policy to avoid GUID churn:
  - keep existing `.meta` files unchanged;
  - copy missing files and missing `.meta`;
  - overwrite non-`.meta` files only when content differs.
- Sync outcome:
  - Art: `CopiedMissing=936`, `CopiedMissingMeta=1039`, `UpdatedSizeDiff=3`, `UpdatedHashDiff=238`, `Failed=0`.
  - NPC assets: `CopiedMissing=1687`, `CopiedMissingMeta=1868`, `Failed=0`.
- Post-check:
  - Art mapping parity: `missing=0`.
  - NPC mapping parity: `missing=0`.
  - Unity verification: Refresh and scene load both `ERRORS=0`.

## Source Layout Migration Findings 2026-03-14
- Previous migration used re-homed paths (`ArtRes`/`ThirdParty`) and introduced script duplication risk.
- Re-migration switched to source-native layout under `Assets/*`, matching source directory structure exactly.
- Backup safety:
  - `MigrationStaging/source-layout-remigration-20260314_083335`
  - `MigrationStaging/before-source-layout-sync-20260314_083405`
- Verification:
  - `SampleScene.unity` SHA256 matches source (`6D7F750B...F5097`).
  - Directory parity check across 10 roots: all `MISSING=0`, `SIZE_DIFF=0`.
  - Unity refresh compile check: `REFRESH_ERRORS=0`.

## Plan Refresh 2026-03-14
- Decision: 主线已从 `MiniFantasyUVTest` 切换为源项目 `SampleScene` 直接运行验证。
- Verified facts:
  - 源目录 `C:\Users\zhuagenbao\Desktop\MiniCharacterCreator-main\test\Assets` 已按原结构同步到当前项目 `Assets/*`。
  - `Assets/Scenes/SampleScene.unity` 与源文件 SHA256 完全一致。
  - 编译刷新检查通过（无 Error）。
- Remaining risk:
  - 若 Unity Editor 未实际打开，AIBridge `SceneCommand_Load` 会超时，不能代表资源损坏。
