---
status: active
owner: main
---

# 全范围模块审计重构

## 目标

按模块串行审计并重构 FantasyWord 当前业务链路，优先清理硬编码、双 owner、隐式查找、资源身份混用和无法验收的流程；每个模块完成前必须有当前证据，不用相邻测试或历史结论冒充完成。

## 全局前提

- 问题对象：当前 FantasyWord 工程内已进入正式或准正式链路的业务模块。
- 真相来源：当前工作区源码、`.spec` 规范、正式数据资产、Unity 可验证状态、用户明确指定的外部参考工程。
- 目标环境：`C:\Gamedev\Unity\Project\FantasyWord`，不自动创建分支、worktree、tag，不擅自加载或保存用户正在编辑的场景。
- 验收口径：每个模块必须回到自己的正式入口验证；静态门禁只证明它覆盖的结构，不证明未运行的 PlayMode 或场景交互。
- 2026-07-16 审计口径修正：`GameManager + AGameSystem` 是当前从 `2DRPGEngine` 吸收的正式世界规则宿主，既有 `GameManager.XSystem / GetSystem<T>()` 快捷入口本身不是违规项。后续审计按 `0046-参考流程优先的 GameManager 系统访问审计边界` 先逐项对照参考同职责流程，再判断当前差异是否是必要增强、业务适配或误改；“改成 TryGetSystem”“禁止单例直读”“必需/可选依赖分类”都不能单独作为重构结论。

## 模块队列

1. [completed] EX-GAS / 能力资源链
   - 文件集：`Assets/Scripts/GameCore/Runtime/Database/Abilities/`、`Assets/Scripts/Gen/FormalGasAbilityDescriptionGeneratedRuntime.cs`、`Assets/Editor/GameCore/Utils/FormalAbilityAssetValidation.cs`、`Assets/DataGenerated/Luban/Json/GAS/`、`Assets/Plugins/GAS/` 的项目接入点、`scripts/Invoke-FormalGasResourceStaticGate.ps1`。
   - 当前结果：能力 Prefab、图标和 Cue 挂载 Prefab 的 `Assets/...` 文本路径债务已从 EX-GAS 源表和 Luban 生成物清零；Unity 已在当前工程重新编译，Console 近 10 分钟错误为 0。当前项目仍没有 Addressables 配置资产，`FWRes` 也是空索引，所以本轮不把 Yoki/Addressables 当正式资源 owner。
   - 裁决标准：参考 2DRPGEngine 的职责内核，运行时正式资源身份不能依赖编辑器路径；若采用 Addressables/Yoki，必须先有真实配置和地址索引；若采用数据库稳定引用，必须让 EX-GAS 文本表只保存稳定业务身份而非 Unity 项目路径。
   - 验收标准：
     - [x] 运行时资源 owner 裁决写入对应规范或决策记录。
     - [x] EX-GAS 资源地址债务有门禁可见，严格模式能阻止新债务。
     - [x] 当前代码不把 `Assets/...` 当玩家构建可用地址。
     - [x] 当前 7 个 EX-GAS 资源身份债务已改为 GameCore 数据库引用，严格资源门禁 0 债务。
     - [x] Unity 编译通过；若自动化不可用，明确标为未验证。

2. [completed] Workspace hygiene / 恢复产物
   - 文件集：`Assets/_Recovery*`。
   - 当前结果：经用户授权后已删除 `Assets/_Recovery`、`Assets/_Recovery.meta`、`Assets/_Recovery/0.unity`、`Assets/_Recovery/0.unity.meta` 这 4 个禁入产物；Unity 资源数据库已刷新，当前不在播放/编译状态。
   - 验收标准：在用户明确授权删除或保留后，`scripts/Invoke-WorkspacePreflight.ps1` 不再被恢复产物阻塞。

3. [completed] 换装工作台 UI 与生成器接线
   - 文件集：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/UI/`、`Assets/Scripts/Presentation/EquipmentSystem/Editor/Utilities/`、`.spec/skills/equipment-system-workflow/`。
   - 当前结果：工作台启动器不再全场景查找 `EquipmentWorkbenchRuntimeUI`，也不再用 `Resources` 路径加载工作台 UI；必须显式绑定 `runtimeUi` 或 `runtimeUiPrefab`。动画生成器缺正式 `EquipmentSystemGenerationSettings` 时直接失败，不再退到临时默认设置。门禁已覆盖这些回退；生成器执行前后 `EquipmentSystemDemo`、`ClickMoveTest` 和基础角色 Prefab 哈希一致。
   - 验收标准：工作台不依赖隐藏场景 owner 或旧生成设置；生成器只产出派生资产，不写场景或 Prefab。

4. [completed] 动作 key / AnimationType owner
   - 文件集：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/CharacterActionAnimatorDriver.cs`、`Assets/Scripts/Presentation/EquipmentSystem/Data/`、GameCore 动作触发接入点。
   - 当前结果：默认动作和受击动作不再由 `CharacterActionAnimatorDriver` 的硬编码常量代持，改为角色动画控制组件的显式配置；GameCore Cue 不再知道 `Idle` 这类具体动作名，只通过 `ICharacterAnimationDriver.TryRestoreDefaultAnimation` 请求恢复默认动作。换装静态门禁已覆盖旧硬编码恢复入口，Unity 已在 2026-07-15 16:12 重新生成 `Assembly-CSharp*.dll`，最近 Console 无本轮错误。
   - 验收标准：动作身份、方向变体、Animator 状态和 SpriteLibrary 变体 owner 不再互相代持。

5. [completed] TerrainNavigationMap / 地形导航闭包
   - 文件集：`Assets/Scripts/GameCore/Runtime/Maps/`、相关 Editor 测试。
   - 当前结果：`TerrainNavigationMap` 不再直接持有或创建运行时调试绘制对象，LineRenderer/TextMesh/调试材质与对象名收口到 `TerrainNavigationRuntimePathDebugView`；导航图构建、地表运行时状态和路径调试显示的职责边界更清楚。`Assets/Scripts/GameCore/Runtime/Maps` 对运行时查找、Resources、场景名和 `Assets/...` 路径的扫描无命中。`TerrainNavigationMapEditModeTests` 已通过，过滤运行该类 30 个测试、失败 0；测试期 3 条地形导航错误日志是 `LogAssert.Expect` 覆盖的预期错误上报。
   - 验收标准：导航图构建、Tile 状态、运行时更新和测试入口 owner 清楚，无场景名或路径硬编码进入正式运行链路。

6. [completed] GameCore 必需引用与运行时断言
   - 文件集：`Assets/Scripts/GameCore/Runtime/Entities/`、`Assets/Scripts/GameCore/Runtime/Game/Systems/`、`Assets/Editor/GameCore/Bridge/`。
   - 当前结果：`CharacterActor` 不再直接提交 `Idle`、`Dmg`、`SpinDie` 这类具体动作 key，改为通过 `ICharacterAnimationDriver` 的默认、受击、死亡语义入口请求表现；具体动作 key 继续归 `CharacterActionAnimatorDriver` 的显式配置字段。正式运行代码对 `Entities` / `Game/Systems` 的全局查找扫描只剩 `PersistenceSystem` 按职责扫描 `Persistable` 建立存档快照，没有发现缺引用时随便找对象或 Resources 路径兜底。`MeleeAttackAbilityEditModeTests` 已通过，过滤运行 62 个测试、失败 0；换装静态门禁、`.spec` 结构检查和 Unity 最近 Console 均通过。
   - 验收标准：正式链路缺引用时直接暴露可定位错误，不用运行时搜索或静默兜底继续执行。

7. [completed] Mod / ResourceSystem / 资源索引
   - 文件集：`Assets/Scripts/GameCore/Runtime/Resources/`、YokiFrame ResKit 接入、Addressables/YooAsset 配置。
   - 当前结果：ResourceSystem 仍定位为 Addressables 动态加载和外部 Mod catalog 入口，不替代官方 DatabaseRegistry / 序列化引用真相；`SoftAssetReference` 只代表 Addressables 地址引用，已增加显式释放入口。Addressables 查询和 catalog 加载产生的 handle 已统一释放；JSON catalog 临时路径替换失败时也会恢复原文件。新增决策 `0002-ResourceSystem 资源 owner 边界` 和门禁 `scripts/Invoke-ResourceOwnerStaticGate.ps1`。当前工程没有 `Assets/AddressableAssetsData`、没有 YooAsset 正式配置、`FWRes` 资源索引为 0；正式 GameCore 运行时代码没有绕过数据库直接依赖 ResourceSystem/FWRes。`FWScene` 仍有 1 个编辑器场景路径生成项，但未被升级为正式资源 owner。
   - 验收标准：资源系统、Mod catalog、Yoki 生成索引和 Addressables/YooAsset 不互相冒充正式 owner。

8. [completed] UI 菜单 / 按钮绑定 / UIKit owner
   - 文件集：`Assets/Scripts/GameCore/Runtime/UI/`、YokiFrame UIKit 项目接入。
   - 当前结果：`UIManager` 继续作为 UIKit 菜单注册、请求路由、菜单栈和关闭任务 owner；菜单条目和死亡面板不再直接同步加载主菜单场景，而是发布 `GameRuntimeEvents.RequestReturnToMainMenu()`，由 `GameStateSystem` 恢复时间缩放并加载配置中的主菜单。`Button.onClick` 监听已补生命周期注销，带参数闭包改为保存包装后的 `UnityAction`；新增决策 `0003-UI 菜单与按钮 owner 边界`。UI 静态门禁已覆盖 Resources、全局查找、transform 路径查找、输入设备签名解析、FWRes 直用、同步直接 LoadScene 和按钮监听生命周期。当前保留 `UIMainMenu -> M2DEngine` 异步加载作为主菜单启动游戏入口，不把它外推为 gameplay UI 场景加载权限。
   - 验收标准：UI 常驻入口、菜单绑定、按钮事件和数据展示 owner 明确，无按名字找控件的正式链路。

9. [completed] Audio / BroAudio 闭包
   - 文件集：`Assets/Scripts/GameCore/Runtime/Database/Audio/`、`Assets/Scripts/GameCore/Runtime/Audio/`、`Assets/Scripts/GameCore/Runtime/Game/Systems/AudioSystem.cs`、BroAudio 接入。
   - 当前结果：保留参考工程的 `AudioClipResolver -> 音频请求事件 -> AudioSystem -> AudioChannel` 主链，BroAudio 只作为 `AudioChannel` 内部执行层；其它 UI、技能、地图和实体仍只发布 `GameRuntimeEvents.RequestAudioPlayback()`。`AudioClipResolver` 修复 PingPong 单片段越界；`AudioChannel` 不再运行时自动添加 AudioSource，改为显式必需组件；`AudioSystem` 对缺失通道报错；`AudioRegion` 缺 resolver 时直接报错，不再空引用。新增决策 `0004-音频运行时 owner 边界` 和门禁 `scripts/Invoke-AudioRuntimeStaticGate.ps1`。本轮未新增音频素材、未改 shared/generated registry、未改现有 AudioClipResolver 资产绑定。
   - 验收标准：音频资源身份、播放 owner、UI/技能/世界事件触发路径单一。

10. [completed] Persistence / Database 稳定引用
    - 文件集：`Assets/Scripts/GameCore/Runtime/Persistence/`、`Assets/Scripts/GameCore/Runtime/Database/`、保存相关测试。
    - 当前结果：运行时实例化对象的 prefab 来源改为保存 `DatabaseEntryReference<PrefabReference>`，读档时通过 `DatabaseRegistry.LoadFromReference()` 恢复；`InventoryOwnerHandle` 不再使用 `scene:{scene.handle}:{GetInstanceID()}` 或 `kind:default` 这类临时身份；背包、装备槽、任务进度、角色变身/感染规则和物品/装备授予能力来源都改为通过 `DatabaseRegistry.TryCreateReference()` 写入稳定 GUID，无法解析或未登记时跳过并报错；`DatabaseRegistry` 对空引用和未登记资产不再静默生成可写入存档的空 GUID。新增决策 `0005-存档与数据库稳定身份边界` 和门禁 `scripts/Invoke-PersistenceRuntimeStaticGate.ps1`。
    - 验收标准：存档只保存稳定业务身份或数据库引用，不保存临时对象、编辑器路径或派生表现状态。


11. [completed] Quest / Journal 任务进度生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/Quest/`、`Assets/Scripts/GameCore/Runtime/Database/Quest/`、`Assets/Scripts/GameCore/Runtime/Game/Systems/JournalSystem.cs`、相关命令和对话任务入口。
    - 当前结果：任务进度不再依赖析构函数注销事件监听；`IQuestTaskProgress.StopTracking()` 成为显式释放合同。`QuestProgress` 在子任务自然完成、强制完成和任务达成迁移时都会停止当前子任务监听；`JournalSystem` 在读档清空、系统停止和任务达成迁移时释放 active quest 监听。任务日志存档写入改为 `TryCreateReference()`，坏档中的空任务块、无法解析任务 GUID 和未登记任务会跳过并报错。新增决策 `0006-任务日志进度生命周期 owner 边界` 和门禁 `scripts/Invoke-QuestRuntimeStaticGate.ps1`。
    - 验收标准：任务进度的事件监听、完成迁移、强制完成、读档恢复和 UI 通知 owner 明确；不得依赖析构函数注销事件，不得让已完成或跳过的任务继续持有运行时监听。

12. [completed] Conditional / Interaction 条件监听生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/Conditional/`、`Assets/Scripts/GameCore/Runtime/Interactions/ConditionalInteraction.cs`。
    - 当前结果：条件基类监听启停改为幂等，停止后事件通知安全忽略；组合条件空列表不再空引用，`All` 为空视为满足、`Any` 为空视为不满足；条件状态机改为 `OnEnable/OnDisable` 启停监听，并保留销毁兜底；条件交互缺少目标交互时明确报错并返回失败。新增决策 `0007-条件监听生命周期 owner 边界` 和门禁 `scripts/Invoke-ConditionalRuntimeStaticGate.ps1`。临时 Unity 探针确认重复监听只保留最新回调、重复停止安全、空组合条件语义正确。
    - 验收标准：条件监听启停跟随对象启用状态且幂等；组合条件空列表不崩溃；条件变更通知停止后不会空引用；条件交互缺少目标交互时明确失败并报错；不得沿用参考工程中 Start/OnDestroy 和非幂等监听的隐式生命周期。

13. [completed] Command / Interaction 异步执行边界
    - 文件集：`Assets/Scripts/GameCore/Runtime/Commands/`、`Assets/Scripts/GameCore/Runtime/Database/Quest/Quest.cs`、`Assets/Scripts/GameCore/Runtime/Game/Systems/JournalSystem.cs`、`Assets/Scripts/GameCore/Runtime/Interactions/QuestInteraction.cs`、`Assets/Scripts/GameCore/Runtime/Dialogue/`、死亡和触发器命令入口。
    - 当前结果：任务完成奖励已成为可等待流程，`Quest.ExecuteOnQuestCompletion()` 与 `JournalSystem.CompleteQuest()` 都返回 `Task`，`QuestInteraction` 在任务完成对话结束后等待完成命令。对话节点、触发器、持久化对象死亡、角色死亡奖励和玩家死亡收口这类事件入口改为显式 `ExecuteFireAndReport()`，后台命令异常会进入 Console；`Entity.OnInteract()` 的异步交互启动也增加异常报告包装。新增决策 `0008-命令异步执行 owner 边界` 和门禁 `scripts/Invoke-CommandRuntimeStaticGate.ps1`。
    - 验收标准：任务完成链返回并等待 `Task`；裸 fire-and-forget 命令调用被静态门禁禁止；允许后台执行的入口必须通过命名 helper 报告异常；参考工程的旧同步/半异步命令入口只作为来源证据，不作为当前 Task 合同的完成口径。

14. [completed] UI 菜单异步按钮入口
    - 文件集：`Assets/Scripts/GameCore/Runtime/UI/MenuPanels/UIKitMenuPanelBase.cs`、`Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventory.cs`、`Assets/Scripts/GameCore/Runtime/UI/Menus/Craft/UICraft.cs`、`Assets/Scripts/GameCore/Runtime/UI/Menus/Shop/UIShop.cs`、`scripts/Invoke-UIRuntimeStaticGate.ps1`。
    - 当前结果：背包、制作和商店菜单不再用异步 void 方法承载按钮业务流程；公开点击入口保持同步签名，真实异步体收进私有 `Task` 方法，并通过 `UIKitMenuPanelBase.RunPanelTaskAndReport()` 统一上报异常。新增决策 `0009-UI 菜单异步按钮 owner 边界`，UI 门禁已覆盖异步 void 回流和菜单基类异常报告入口。
    - 验收标准：正式 UI 运行时代码不再出现异步 void 方法；菜单按钮异步流程统一通过 `RunPanelTaskAndReport()` 报告异常；既有 UI 静态门禁继续通过；Unity 编译和 Console 无本轮错误。

15. [completed] CharacterActor 任务浮标事件监听生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterActor.Quest.cs`、`scripts/Invoke-CharacterActorRuntimeStaticGate.ps1`。
    - 当前结果：角色任务浮标事件监听不再使用 `Start/OnDestroy` 作为主要生命周期，改为 `OnEnable/OnDisable` 幂等启停；销毁只保留兜底停止。`UpdateFloatingIcon()` 在 GameManager 或 JournalSystem 未就绪时安全返回，避免启用时序空引用。新增决策 `0010-角色任务浮标监听生命周期 owner 边界` 和门禁 `scripts/Invoke-CharacterActorRuntimeStaticGate.ps1`。2026-07-15 18:30 复验：角色门禁 0 违规，`spec-lint` 通过，AIBridge foundation smoke 通过，Console 近 200 条 Error/Exception/Assert 为 0。
    - 验收标准：禁用的角色不继续响应任务事件；重复启用不重复注册；销毁兜底注销；启动早期 JournalSystem 未就绪不空引用；不得沿用参考工程中 Start/OnDestroy 的隐式任务浮标监听生命周期。

16. [completed] 换装表现层运行时资源 owner
    - 文件集：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/UI/EquipmentWorkbenchBootstrap.cs`、`Assets/Scripts/Presentation/EquipmentSystem/Runtime/UI/EquipmentWorkbenchRuntimeUI.cs`、`Assets/Scripts/Presentation/EquipmentSystem/Runtime/HQ4xRendererFeature.cs`、`Assets/Resources/Art/UIPrefab/UIEquipmentWorkbench.prefab`、`scripts/Invoke-EquipmentPresentationResourceStaticGate.ps1`。
    - 当前结果：工作台字体和 HQ4x LUT 已从运行时 `Resources.Load` 字符串路径兜底迁到显式序列化引用；新增决策 `0011-换装表现资源 owner 边界`，并更新换装动画与资源流程对照。2026-07-15 18:35 复验：换装表现资源门禁 0 违规，换装系统门禁 0 违规，`spec-lint` 通过，Unity 编译完成，`Assembly-CSharp.dll` / `Assembly-CSharp-Editor.dll` 已刷新，Console 近 200 条 Error/Exception/Assert 为 0；Unity 资产探针确认 `UIEquipmentWorkbench.prefab` 绑定 `Silver SDF`，`Renderer2D.asset` 绑定 `hq4x` LUT。
    - 验收标准：换装表现运行时代码不再出现 `Resources.Load`；工作台 UI 预制体显式绑定 TMP 字体；Renderer2D 的 HQ4x Feature 显式绑定 LUT；新增资源门禁、换装门禁、spec-lint、Unity 编译和 Console 复查通过。

17. [completed] UI 控制器按键提示生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/UI/UIControllerButtonManager.cs`、`Assets/Scripts/GameCore/Runtime/UI/UIControllerButton.cs`、`scripts/Invoke-UIRuntimeStaticGate.ps1`。
    - 当前结果：按键提示管理器和按钮已从 `Start/OnDestroy` 注册改为启用/禁用生命周期；新增决策 `0012-UI 控制器按键提示生命周期 owner 边界`。控制器图标库缺失时改为可定位错误，不再用字典索引抛异常。2026-07-15 18:40 复验：UI 门禁 0 违规，`spec-lint` 通过，Unity 编译完成，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Console 近 200 条 Error/Exception/Assert 为 0。
    - 验收标准：按钮启用即注册、禁用即注销且幂等；管理器启用订阅输入设备变化、禁用退订且幂等；缺少控制器图标库时报错不中断 UI；UI 门禁、spec-lint、Unity 编译和 Console 复查通过。

18. [completed] HUD 当前控制角色监听生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/UI/UIPlayerControlFeedback.cs`、`Assets/Scripts/GameCore/Runtime/UI/HUD/Stats/UIStatBar.cs`、`Assets/Scripts/GameCore/Runtime/UI/HUD/Effects/UIHUDEffectBar.cs`、`Assets/Scripts/GameCore/Runtime/UI/HUD/Abilities/UIHUDAbilityBar.cs`、`scripts/Invoke-UIRuntimeStaticGate.ps1`。
    - 当前结果：HUD 跟随当前控制角色的组件已从 `Start/OnDestroy` 监听改为启用/禁用生命周期；新增决策 `0013-HUD 当前控制角色监听生命周期 owner 边界`。禁用 HUD 时会退订 PlayerSystem，并解绑角色属性、状态效果或能力槽事件。2026-07-15 18:45 复验：UI 门禁 0 违规，`spec-lint` 通过，Unity 编译完成，`FantasyWord.GameCore.dll` 已刷新，Console 近 200 条 Error/Exception/Assert 为 0。
    - 验收标准：四个 HUD 组件启用时监听当前控制角色、禁用时退订并解绑角色二级事件；监听具备幂等和 GameManager/PlayerSystem 就绪保护；UI 门禁、spec-lint、Unity 编译和 Console 复查通过。

19. [completed] UI 菜单当前控制角色监听生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/UI/Menus/Character/UICharacter.cs`、`Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventory.cs`、`Assets/Scripts/GameCore/Runtime/UI/Menus/Abilities/UIAbilities.cs`、`Assets/Scripts/GameCore/Runtime/UI/Menus/Abilities/UIAbilityBar.cs`、`scripts/Invoke-UIRuntimeStaticGate.ps1`。
    - 当前结果：角色、背包和能力菜单不再在 `OnPanelInit` 长驻监听当前控制角色，改为只在 `OnPanelShown` 且菜单上下文确实跟随当前控制角色时注册，`OnPanelHidden` 和销毁时退订；显式角色上下文不注册监听。`UIAbilityBar` 不再自己订阅 `PlayerSystem`，只作为父面板传入角色的能力槽呈现控件。新增决策 `0014-UI 菜单当前控制角色监听生命周期 owner 边界`。2026-07-15 18:54 复验：UI 门禁 0 违规，`spec-lint` 通过，Unity 编译完成，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Foundation bridge smoke 通过，Console 近 200 条 Error/Exception/Assert 为 0。
    - 验收标准：菜单面板只在显示期监听当前控制角色；隐藏或销毁时退订并清理临时显示状态；能力条子控件不直接持有当前控制角色真相；UI 门禁、spec-lint、Unity 编译、基础桥和 Console 复查通过。

20. [completed] 对话 HUD 监听生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/UI/HUD/Dialogue/UIDialogue.cs`、`Assets/Scripts/GameCore/Runtime/Dialogue/DialogueChannel.cs`、`Assets/Scripts/GameCore/Runtime/Game/Systems/DialogueSystem.cs`、`scripts/Invoke-UIRuntimeStaticGate.ps1`。
    - 当前结果：`UIDialogue` 不再在 `Start` 长驻注册对话事件和 UI 跳过输入，改为启用时注册、禁用和销毁时退订并清空跳过输入门禁；禁用时隐藏对话 HUD 并只移除自己压入的 Dialogue 状态层。`DialogueSystem` / `DialogueChannel` 新增只读当前播放状态查询，HUD 重新启用时可以同步当前对话树和节点。新增决策 `0015-对话 HUD 监听生命周期 owner 边界`。2026-07-15 18:59 复验：UI 门禁 0 违规，`spec-lint` 通过，Unity 编译完成，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Foundation bridge smoke 通过，Console 近 200 条 Error/Exception/Assert 为 0。
    - 验收标准：对话 HUD 启用时监听、禁用时退订；禁用后不继续消费 Submit/Cancel/Click；重新启用可从对话系统同步当前播放状态；UI 门禁、spec-lint、Unity 编译、基础桥和 Console 复查通过。

21. [completed] 朝向跟随表现监听生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/Animation/FollowTargetDirection.cs`、`scripts/Invoke-AnimationRuntimeStaticGate.ps1`。
    - 当前结果：`FollowTargetDirection` 不再在 `Awake` 注册角色目标朝向事件，改为启用时注册、禁用和销毁时退订，并用幂等标记避免重复注册；成功绑定后立即读取并应用当前目标朝向，避免启用后等下一次方向变化才同步。新增决策 `0016-朝向跟随表现监听生命周期 owner 边界` 和动画运行时门禁。2026-07-15 19:04 复验：动画门禁 0 违规，`spec-lint` 通过，Unity 编译完成，`FantasyWord.GameCore.dll` 已刷新，Foundation bridge smoke 通过，Console 近 200 条 Error/Exception/Assert 为 0。
    - 验收标准：朝向跟随表现只在启用期监听目标朝向；禁用或销毁时退订；启用时立即同步当前方向；动画门禁、spec-lint、Unity 编译、基础桥和 Console 复查通过。

22. [completed] 固定目标角色信息面板监听生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/UI/UICharacterInfo.cs`、`scripts/Invoke-UIRuntimeStaticGate.ps1`。
    - 当前结果：`UICharacterInfo` 不再在 `Awake` 注册目标角色属性、状态效果和升级事件，改为启用时注册、禁用和销毁时退订，并用幂等标记避免重复注册；禁用或销毁时会归还当前租用的状态效果图标。资源条和名字等级刷新增加空目标保护。新增决策 `0017-角色信息面板监听生命周期 owner 边界`，UI 门禁已覆盖该生命周期合同。2026-07-15 19:06 复验：UI 门禁 0 违规，Unity 编译完成，`FantasyWord.GameCore.dll` 已刷新，Foundation bridge smoke 通过，Console 近 200 条 Error/Exception/Assert 为 0。
    - 验收标准：固定目标角色信息面板只在启用期监听目标角色；禁用或销毁时退订并归还状态图标；空目标刷新不抛异常；UI 门禁、spec-lint、Unity 编译、基础桥和 Console 复查通过。

23. [completed] EX-GAS 动画 Cue 驱动 owner
    - 文件集：`Assets/Scripts/GameCore/Runtime/Presentation/CuePlayGameCoreAnimator.cs`、`scripts/Invoke-FormalGasResourceStaticGate.ps1`。
    - 当前结果：`CuePlayGameCoreAnimator` 不再读取插件通用的 `AnimatorNodePath`，也不再使用 `transform.Find()` 按层级字符串定位正式动画节点；正式动画 Cue 只从目标对象树解析 `ICharacterAnimationDriver`。EX-GAS 严格资源门禁已扩展检查非空 `AnimatorNodePath` 和正式 Cue 路径解析回流。新增决策 `0018-EX-GAS 动画 Cue 驱动 owner 边界`。当前生成时间轴数据中 4 个 `CuePlayGameCoreAnimator` 的节点路径均为空。2026-07-15 19:13 复验：Formal GAS 严格门禁 0 违规，`spec-lint` 通过，`FantasyWord.GameCore.dll` 已刷新到 19:13，Foundation bridge smoke 通过，Editor.log 尾部无 C# 编译错误；当前文件桥未暴露可用 Console 读取工具，因此未把 Console 近 200 条复查列为本模块证据。
    - 验收标准：正式 EX-GAS 动画 Cue 不依赖层级路径字符串；非空 `AnimatorNodePath` 会被严格门禁拦截；Formal GAS 严格门禁、spec-lint、Unity 编译和基础桥复查通过。

24. [completed] 主菜单 Cancel 输入监听生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/UI/Menus/UIMainMenu.cs`、`scripts/Invoke-UIRuntimeStaticGate.ps1`。
    - 当前结果：`UIMainMenu` 不再在 `Start` 长驻注册 Cancel 输入，改为启用时注册、禁用和销毁时退订，并用幂等标记和 `GameManager` / `InputSystem` 就绪检查避免重复注册或启动时序空引用。新增决策 `0019-主菜单 Cancel 输入监听生命周期 owner 边界`，UI 门禁已覆盖该生命周期合同。2026-07-15 19:19 复验：UI 门禁 0 违规，`spec-lint` 通过，`FantasyWord.GameCore.dll` 已刷新到 19:19，Foundation bridge smoke 通过，Editor.log 尾部无 C# 编译错误。
    - 验收标准：主菜单只在启用期消费 Cancel 输入；禁用或销毁时退订；UI 门禁、spec-lint、Unity 编译和基础桥复查通过。

25. [completed] 换装表现桥接显式渲染器 owner
    - 文件集：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/CharacterEquipmentPresentation.cs`、`scripts/Invoke-EquipmentSystemStaticGate.ps1`。
    - 当前结果：`CharacterEquipmentPresentation` 不再用 `GetComponentInChildren<EquipmentRenderer>(true)` 自动查找子级换装渲染器；同对象 `CharacterEquipment` 仍由 `RequireComponent` 和 `GetComponent<CharacterEquipment>()` 解析。基础角色 Prefab 已有显式 `equipmentRenderer` 引用，换装门禁已覆盖源码回流和基础 Prefab 显式绑定。新增决策 `0020-换装表现桥接显式渲染器 owner 边界`。2026-07-15 19:28 复验：换装门禁 0 违规，`spec-lint` 通过，`Assembly-CSharp.dll` 已刷新到 19:28，Foundation bridge smoke 通过，Editor.log 尾部无 C# 编译错误。
    - 验收标准：换装表现桥接不依赖运行时子级搜索；基础角色 Prefab 显式绑定换装渲染器；换装门禁、spec-lint、Unity 编译和基础桥复查通过。

26. [completed] Transform 抖动协程 owner
    - 文件集：`Assets/Scripts/GameCore/Runtime/Animation/TransformShaker.cs`、`Assets/Scripts/GameCore/Runtime/Animation/CameraShake.cs`、`Assets/Scripts/GameCore/Runtime/UI/HUD/Stats/UIStatBar.cs`、`scripts/Invoke-AnimationRuntimeStaticGate.ps1`。
    - 当前结果：`TransformShaker` 不再通过 `GameManager.Instance` 承载表现协程，改为由调用组件显式传入 `MonoBehaviour owner`；`CameraShake` 和 `UIStatBar` 在禁用时停止当前抖动并复位，`UIStatBar` 在销毁时也兜底停止。抖动协程在目标 Transform 被销毁时安全退出。新增决策 `0021-Transform 抖动协程 owner 边界`，动画门禁已覆盖显式 owner 和调用点清理合同。2026-07-15 19:32 复验：动画门禁 0 违规，UI 门禁 0 违规，`spec-lint` 通过，`FantasyWord.GameCore.dll` 已刷新到 19:32，Foundation bridge smoke 通过，Editor.log 尾部无 C# 编译错误。
    - 验收标准：抖动协程不依赖全局 GameManager；调用组件禁用/销毁时停止抖动；动画门禁、UI 门禁、spec-lint、Unity 编译和基础桥复查通过。
27. [completed] 对话消息框跳字协程生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/UI/HUD/Dialogue/UIDialogueMessageBox.cs`、`scripts/Invoke-UIRuntimeStaticGate.ps1`。
    - 当前结果：`UIDialogueMessageBox` 不再只依赖父级 HUD 调用 `Hide()` 来结束跳字；消息框组件禁用或销毁时会主动终止当前跳字协程、清空跳字队列并隐藏箭头。隐藏、替换文本和跳过仍保留旧协程清理。新增决策 `0022-对话消息框跳字协程生命周期 owner 边界`，UI 门禁已覆盖隐藏、替换、跳过、禁用和销毁清理合同。2026-07-15 19:36 / 19:41 复验：UI 门禁 0 违规，`spec-lint` 通过，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Foundation bridge smoke 通过，Editor.log 尾部无 C# 编译错误。
    - 验收标准：禁用或销毁对话消息框不会留下后台跳字协程；UI 门禁、spec-lint、Unity 编译和基础桥复查通过。
28. [completed] Mod 配置状态 owner
    - 文件集：`Assets/Scripts/GameCore/Runtime/Mods/ModConfig.cs`、`Assets/Scripts/GameCore/Runtime/Mods/ModLoader.cs`、`scripts/Invoke-ModRuntimeStaticGate.ps1`。
    - 当前结果：`ModConfig.GetModState()` 不再在查询状态时创建默认记录或移除删除记录；扫描到真实 Mod 时由 `ModLoader` 显式调用 `EnsureModState()` 登记默认状态；处理完磁盘删除后再调用 `ConsumeDeletedModState()` 消费删除标记。新增决策 `0023-Mod 配置状态 owner 边界` 和 Mod 运行时门禁。2026-07-15 19:41 复验：Mod 门禁 0 违规，资源 owner 门禁 0 违规但保留 1 条已知 FWScene 警告，`spec-lint` 通过，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Foundation bridge smoke 通过，Editor.log 尾部无 C# 编译错误。
    - 验收标准：Mod 状态查询、默认登记、启停写入和删除状态消费入口分离；Mod 门禁、资源 owner 门禁、spec-lint、Unity 编译和基础桥复查通过。
29. [completed] Wait 命令延迟 owner
    - 文件集：`Assets/Scripts/GameCore/Runtime/Commands/Wait.cs`、`scripts/Invoke-CommandRuntimeStaticGate.ps1`。
    - 当前结果：`Wait` 命令不再通过 `GameManager.Instance` 启动等待协程，也不再用 `TaskCompletionSource` 桥接协程；延迟改为项目已安装 UniTask 的 Unity PlayerLoop 等待，并继续返回到命令 `Task` 链。新增决策 `0024-等待命令延迟 owner 边界`，命令门禁新增 `WaitCommandUsesPlayerLoopDelay` 防止回退到全局协程 owner。2026-07-15 19:47 / 19:48 复验：命令门禁 0 违规，`WaitCommandUsesPlayerLoopDelay=true`，`spec-lint` 通过，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Foundation bridge smoke 通过，Editor.log 尾部无 C# 编译错误。
    - 验收标准：等待命令不依赖全局 `GameManager` 或任意 `MonoBehaviour` 协程 owner；命令门禁、spec-lint、Unity 编译和基础桥复查通过。
30. [completed] 临时 UI 动画协程生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/UI/UITipsItem.cs`、`Assets/Scripts/GameCore/Runtime/UI/HUD/EventLog/UIEventLogLine.cs`、`scripts/Invoke-UIRuntimeStaticGate.ps1`。
    - 当前结果：`UITipsItem` 和 `UIEventLogLine` 不再只依赖动画自然结束来清理协程；替换内容、禁用和销毁时都会停止自身动画协程并置空字段，禁用时会清理池化可见状态。新增决策 `0025-临时 UI 动画协程生命周期 owner 边界`，UI 门禁新增 `TransientUiCoroutineLifecycleBound` 防止回退。2026-07-15 19:52 复验：UI 门禁 0 违规，`TransientUiCoroutineLifecycleBound=true`，命令门禁 0 违规，`spec-lint` 通过，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Foundation bridge smoke 通过，Editor.log 尾部无 C# 编译错误。
    - 验收标准：临时提示和事件日志行被池化回收、父级 UI 隐藏或外部禁用时不留下旧协程或旧文本；UI 门禁、spec-lint、Unity 编译和基础桥复查通过。
31. [completed] 音频播放生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/Audio/AudioChannel.cs`、`Assets/Scripts/GameCore/Runtime/Audio/AudioChannelFallbackPlayer.cs`、`scripts/Invoke-AudioRuntimeStaticGate.ps1`。
    - 当前结果：`AudioChannel` 禁用时会停止当前播放运行时；fallback 播放器的公开停止、禁用和销毁都走统一清理函数，停止播放协程、清空 AudioSource clip、跟随目标、完成回调、剩余时长和暂停状态。新增决策 `0026-音频播放生命周期 owner 边界`，音频门禁新增 `AudioChannelStopsPlaybackOnDisable` 和 `FallbackPlayerLifecycleBound` 防止回退。2026-07-15 19:55 复验：音频门禁 0 违规，`AudioChannelStopsPlaybackOnDisable=true`，`FallbackPlayerLifecycleBound=true`，UI 门禁 0 违规，命令门禁 0 违规，`spec-lint` 通过，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Foundation bridge smoke 通过，Editor.log 尾部无 C# 编译错误。
    - 验收标准：禁用音频通道或 fallback 播放器不会留下后台播放协程、旧回调或旧 AudioClip；音频门禁、spec-lint、Unity 编译和基础桥复查通过。
32. [completed] 宝箱首次开启防重入
    - 文件集：`Assets/Scripts/GameCore/Runtime/Entities/Chest.cs`、`scripts/Invoke-ChestRuntimeStaticGate.ps1`。
    - 当前结果：`Chest.TryOpen()` 首次开启期间新增 `m_opening` 守卫，重复交互会直接返回 false，不再重复初始化掉落、加钱或排入对话；首次开启在等待对话播放前提交 `m_opened = true`，读档时重置 opening 状态。内容揭示轮播协程改为显式记录，并在重新播放、禁用、销毁和读档时停止。新增决策 `0027-宝箱首次开启防重入边界` 和宝箱专项门禁。2026-07-15 20:01 复验：宝箱门禁 0 违规，`FirstOpenReentryGuarded=true`，`ContentRevealCoroutineLifecycleBound=true`，持久化门禁 0 违规，命令门禁 0 违规，`spec-lint` 通过，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Foundation bridge smoke 通过，Editor.log 尾部无 C# 编译错误。
    - 验收标准：宝箱首次开启对话未完成时重复交互不会重复发放首次掉落；内容揭示协程禁用/销毁/读档可清理；宝箱门禁、spec-lint、Unity 编译和基础桥复查通过。
33. [completed] 换装工作台按钮监听 owner
    - 文件集：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/UI/EquipmentWorkbenchIconSlotView.cs`、`Assets/Scripts/Presentation/EquipmentSystem/Runtime/UI/EquipmentWorkbenchChipButtonView.cs`、`scripts/Invoke-EquipmentSystemStaticGate.ps1`。
    - 当前结果：工作台按钮 View 不再使用 `RemoveAllListeners()` 清空整个 Button；组件保存自己注册的 `UnityAction`，重新绑定、禁用和销毁时只移除自身监听。新增决策 `0028-换装工作台按钮监听 owner 边界`，换装门禁已禁止 `RemoveAllListeners()` 回流。2026-07-15 20:05 复验：换装门禁 0 违规，UI 门禁 0 违规，`spec-lint` 通过，`Assembly-CSharp.dll` 已刷新，Foundation bridge smoke 通过，Editor.log 尾部无 C# 编译错误。
    - 验收标准：工作台按钮复用不会误删外部监听；换装门禁、spec-lint、Unity 编译和基础桥复查通过。
34. [completed] HUD 能力失败提示生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/UI/HUD/Abilities/UIHUDAbilityMessage.cs`、`scripts/Invoke-UIRuntimeStaticGate.ps1`。
    - 当前结果：`UIHUDAbilityMessage` 显示新提示前会停止旧隐藏协程；禁用和销毁时会隐藏提示、停止协程并清空文本、透明度和可见状态；淡出结束时直接清理协程字段和 UI 状态，不再从协程内部反向停止自身协程。新增决策 `0029-HUD 能力失败提示生命周期 owner 边界`，UI 门禁新增 `AbilityMessageLifecycleBound` 防止回退。2026-07-15 20:17 复验：UI 门禁 0 违规，`AbilityMessageLifecycleBound=true`，`spec-lint` 通过，Foundation bridge smoke 通过，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Editor.log 尾部无 C# 编译错误。
    - 验收标准：HUD 能力/命令失败提示被禁用、销毁或快速替换时不会留下旧隐藏协程、旧文本或旧透明度；UI 门禁、spec-lint、Unity 编译和基础桥复查通过。
35. [completed] 主动能力 Animator Trigger 死入口
    - 文件集：`Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/ActiveAbilityBase.cs`、`scripts/Invoke-AbilityRuntimeStaticGate.ps1`。
    - 当前结果：`ActiveAbilityBase` 删除未被任何能力子类调用的角色 Animator 缓存、子级 Animator 自动查找和 Trigger 写入辅助方法；主动能力基类不再具备直接遍历 Animator 参数或写 Trigger 的表现权限。新增决策 `0030-主动能力动画驱动 owner 边界`，新增能力运行时门禁 `ActiveAbilityBaseAnimatorTriggerPathRemoved` 和 `ActiveAbilityRuntimeNoDirectAnimatorTrigger` 防止回退。2026-07-15 20:17 复验：能力门禁 0 违规，两项检查均为 true，`spec-lint` 通过，Foundation bridge smoke 通过，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Editor.log 尾部无 C# 编译错误。
    - 验收标准：主动能力规则层不再直连 Animator Trigger；需要角色动作时走 `ICharacterAnimationDriver` 或正式 Gameplay Cue；能力门禁、spec-lint、Unity 编译和基础桥复查通过。
36. [completed] 对话通道等待任务生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/Dialogue/DialogueChannel.cs`、`scripts/Invoke-DialogueRuntimeStaticGate.ps1`。
    - 当前结果：`DialogueChannel` 对空对话树、无入口节点、禁用和销毁都明确完成等待任务并返回 false；正常播放结束返回 true；队列清理和当前对话取消都改用幂等 `TrySetResult`。新增决策 `0031-对话通道等待任务生命周期 owner 边界`，新增对话运行时门禁 `DialogueChannelAwaitTasksLifecycleBound` 防止悬空等待和非幂等 `SetResult` 回流。2026-07-15 20:17 复验：对话门禁 0 违规，检查项为 true；命令门禁 0 违规，`spec-lint` 通过，Foundation bridge smoke 通过，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Editor.log 尾部无 C# 编译错误。
    - 验收标准：对话播放等待方在成功、坏数据、通道禁用或销毁时都有明确完成结果；对话门禁、spec-lint、Unity 编译和基础桥复查通过。
37. [completed] 地图复活延迟协程生命周期
    - 文件集：`Assets/Scripts/GameCore/Runtime/Game/Systems/MapSystem.cs`、`scripts/Invoke-MapRuntimeStaticGate.ps1`。
    - 当前结果：`MapSystem` 在系统停止、组件禁用和销毁时都会停止当前复活延迟协程并清空句柄；协程自然完成、缺少有效检查点或缺少穿越角色时仍继续清空句柄。新增决策 `0032-地图复活延迟协程生命周期 owner 边界`，新增地图运行时门禁 `MapRespawnCoroutineLifecycleBound` 防止回退。2026-07-15 20:21 复验：地图门禁 0 违规，检查项为 true；对话/能力/UI 门禁仍通过，`spec-lint` 通过，Foundation bridge smoke 通过，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Editor.log 尾部无 C# 编译错误。
    - 验收标准：地图系统停止或对象生命周期结束后不会留下旧复活延迟继续触发传送/复活；地图门禁、spec-lint、Unity 编译和基础桥复查通过。
38. [completed] CharacterActionAnimatorDriver 显式 Animator / Shadow owner
    - 文件集：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/CharacterActionAnimatorDriver.cs`、`Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab`、`scripts/Invoke-EquipmentSystemStaticGate.ps1`。
    - 当前结果：`CharacterActionAnimatorDriver` 已新增显式 `characterAnimator` 和 `shadowObject` 依赖，删除子级 Animator 扫描、UI 名称排除和 `transform.Find("Shadow")`；基础角色 Prefab 已绑定 Body Animator 和源 Prefab 的 `Blob Shadow`；新增决策 `0033-CharacterActionAnimatorDriver 显式依赖 owner 边界`，换装门禁已扩展覆盖隐式查找和基础 Prefab 显式绑定。2026-07-15 21:50 复验：换装门禁 0 违规，`spec-lint` 通过，Foundation bridge smoke 通过，`Assembly-CSharp.dll` / `Assembly-CSharp-Editor.dll` 已刷新，Editor.log 尾部无 C# 编译错误。
    - 验收标准：动作控制器不再通过子级扫描、UI 名称过滤或硬编码子物体名猜依赖；基础角色 Prefab 显式绑定 Animator 与阴影；换装门禁、spec-lint、Unity 编译和基础桥复查通过。
39. [completed] EquipmentRenderer 显式 CharacterActionAnimatorDriver / Animator owner
    - 文件集：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/EquipmentRenderer.cs`、`Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab`、`scripts/Invoke-EquipmentSystemStaticGate.ps1`。
    - 当前结果：`EquipmentRenderer` 已新增显式 `animationController` 和 `characterAnimator` 依赖，删除父级 `CharacterActionAnimatorDriver` 查找、子级 Animator 扫描和 UI 名称候选过滤；基础角色 Prefab 已绑定动作控制器和 Body Animator；新增决策 `0034-EquipmentRenderer 显式动画依赖 owner 边界`，换装门禁已覆盖该合同。2026-07-15 21:50 复验：换装门禁 0 违规，`spec-lint` 通过，Foundation bridge smoke 通过，`Assembly-CSharp.dll` / `Assembly-CSharp-Editor.dll` 已刷新，Editor.log 尾部无 C# 编译错误。
    - 验收标准：换装渲染器不再向父级或子级搜索动作依赖；基础角色 Prefab 显式绑定动作控制器和 Animator；换装门禁、spec-lint、Unity 编译和基础桥复查通过。
40. [completed] 拾取物延迟禁用 owner
    - 文件集：`Assets/Scripts/GameCore/Runtime/Loot/PickableItem.cs`、`scripts/Invoke-LootRuntimeStaticGate.ps1`。
    - 当前结果：`PickableItem` 的延迟禁用不再依赖拾取物自身协程；当前对象和目标对象的延迟禁用改为 UniTask PlayerLoop 延迟，并用拾取物销毁令牌作为取消边界。目标对象会在启动延迟时捕获引用，并在延迟结束后重新判空；因此拾取物自身被立即禁用时，不会导致目标对象延迟禁用流程丢失。新增决策 `0035-拾取物延迟禁用 owner 边界` 和 Loot 运行时门禁。2026-07-15 21:57 复验：Loot 门禁 0 违规，命令门禁 0 违规，`spec-lint` 通过，Foundation bridge smoke 通过，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Editor.log 最新尾部无 C# 编译错误。
    - 验收标准：拾取物延迟禁用不回退到 `StartCoroutine` / `WaitForSeconds`；目标延迟禁用捕获并判空目标对象；Loot 门禁、spec-lint、Unity 编译和基础桥复查通过。
41. [completed] CommandTrigger 帧延迟 owner
    - 文件集：`Assets/Scripts/GameCore/Runtime/Miscellaneous/CommandTrigger.cs`、`scripts/Invoke-CommandRuntimeStaticGate.ps1`。
    - 当前结果：`CommandTrigger` 的 `m_frameDelay` 不再由触发器自身协程承载，改为 UniTask PlayerLoop 的帧等待，并用触发器销毁令牌作为取消边界；后台执行仍通过 `ExecuteFireAndReport()` 上报异常。新增决策 `0036-场景命令触发器帧延迟 owner 边界`，命令门禁新增 `CommandTriggerFrameDelayUsesPlayerLoop` 防止回退。2026-07-15 22:01 复验：命令门禁 0 违规且 `CommandTriggerFrameDelayUsesPlayerLoop=true`，Loot 门禁 0 违规，`spec-lint` 通过，Foundation bridge smoke 通过，`FantasyWord.GameCore.dll` / `Assembly-CSharp*.dll` 已刷新，Editor.log 最新尾部无 C# 编译错误。
    - 验收标准：CommandTrigger 帧延迟不回退到 `StartCoroutine` / `yield return null`；命令门禁、spec-lint、Unity 编译和基础桥复查通过。
42. [completed] 水面倒影反射来源显式 owner
    - 文件集：`Assets/Scripts/Presentation/WaterReflection/Runtime/WaterReflectionCaster2D.cs`、`Assets/Scripts/Presentation/WaterReflection/Editor/ClickMoveTestWaterReflectionInstaller.cs`、`scripts/Invoke-WaterReflectionRuntimeStaticGate.ps1`。
    - 当前结果：`WaterReflectionCaster2D` 运行时不再自动从子级查找 `EquipmentRenderer` 或批量收集 `SpriteRenderer`；必须显式绑定换装渲染器或 SpriteRenderer 来源，缺少来源时直接报错并禁用该投射器。编辑器安装器仍可在锁定的 ClickMoveTest 场景中做确定性查找并写入显式引用，但不再写回已删除的子级自动收集字段。新增决策 `0037-水面倒影显式反射来源 owner 边界` 和水面倒影运行时门禁。本轮没有加载、保存或重写用户当前场景。2026-07-15 22:10 复验：水面倒影门禁 0 违规，插件边界门禁 0 违规，`spec-lint` 通过，Foundation bridge smoke 通过，`Assembly-CSharp.dll` / `Assembly-CSharp-Editor.dll` 已刷新，Editor.log 最新尾部无 C# 编译错误。
    - 验收标准：水面倒影运行时代码不回退到子级自动查找/收集；安装器不写旧自动收集字段；水面倒影门禁、插件边界门禁、spec-lint、Unity 编译和基础桥复查通过。
43. [completed] 受击表现监听者系统就绪边界
    - 文件集：`Assets/Scripts/GameCore/Runtime/Animation/CameraShake.cs`、`Assets/Scripts/GameCore/Runtime/Animation/DamageScreenFlash.cs`、`scripts/Invoke-AnimationRuntimeStaticGate.ps1`。
    - 当前结果：代码静态门禁已验证表现监听者读取当前控制角色和相机震动设置前有就绪保护；这只证明本项当前实现具备失败保护，不证明“TryGetSystem 比快捷入口更规范”。参考流程差异已由 51 复核。
    - 验收标准：受击表现监听者具备就绪保护，不做运行时兜底查找或替代状态；后续补齐参考同职责流程对照、动画门禁、spec-lint、Unity 编译和基础桥复查。
44. [completed] 区域音频系统就绪边界
    - 文件集：`Assets/Scripts/GameCore/Runtime/Audio/AudioRegion.cs`、`scripts/Invoke-AudioRuntimeStaticGate.ps1`。
    - 当前结果：`AudioRegion` 作为触发器入口保留玩家识别和音频系统就绪保护；缺 `AudioClipResolver` 或 `AudioSystem` 时给出可定位错误并跳过本次区域音频切换。该结论需要在 51 中对照 2DRPGEngine 音频触发流程后确认是否属于当前项目必要增强。
    - 验收标准：区域音频切换前能确认当前控制角色、解析器和音频系统；后续补齐参考同职责流程对照、音频门禁、spec-lint、Unity 编译和基础桥复查。
45. [completed] MovementZone 玩家系统就绪边界
    - 文件集：`Assets/Scripts/GameCore/Runtime/Miscellaneous/MovementZone.cs`、`scripts/Invoke-MovementRuntimeStaticGate.ps1`。
    - 当前结果：`MovementZone` 的“只影响当前控制角色”过滤在施加倍率前确认当前控制角色；禁用区域时仍清理已施加倍率。该门禁只覆盖区域触发器过滤和清理合同，不再把现有 `GameManager.PlayerSystem` 快捷入口视为违规。
    - 验收标准：MovementZone 当前玩家过滤具备明确失败语义；禁用区域仍清理已施加倍率；后续补齐参考同职责流程对照、Movement 门禁、spec-lint、Unity 编译和基础桥复查。
46. [completed] 命令上下文玩家系统就绪边界
    - 文件集：`Assets/Scripts/GameCore/Runtime/Commands/GameCommandContext.cs`、`Assets/Scripts/GameCore/Runtime/Commands/MovePlayer.cs`、`scripts/Invoke-CommandRuntimeStaticGate.ps1`。
    - 当前结果：`GameCommandContext` 的“无上下文角色时回退当前受控角色”继续用非抛错查询；`MovePlayer` 已回到参考同职责流程的项目适配版，通过 `GameManager.PlayerSystem.GetPrimaryPlayerCharacter()` 取得正式玩家目标，不再把缺玩家系统吞成空目标。命令门禁字段改为 `MovePlayerMatchesReferencePlayerShortcut`。
    - 验收标准：命令上下文 fallback 与 `MovePlayer` 都写清参考流程、当前差异和失败语义；命令门禁、spec-lint、Unity 编译和基础桥复查通过。
47. [completed] GameManager 系统注册表查询失败语义边界
    - 文件集：`Assets/Scripts/GameCore/Runtime/Game/GameManager.SystemRegistryRuntime.cs`、`scripts/Invoke-GameManagerRuntimeStaticGate.ps1`。
    - 当前结果：`HasSystem<T>()` 和 `TryGetSystem<T>()` 保留空实例/空字典保护；`GetSystem<T>()` 复用该查询路径，但正式系统缺失时抛出可定位异常，不再只断言后返回 null；同类型系统重复注册也会抛异常。0042 只定义查询 API 和正式入口失败语义，不表示所有调用点都应改成 Try 查询。2026-07-16 复验：GameManager 门禁 0 违规，`GetSystemThrowsOnMissingSystem=true`，`DuplicateSystemsThrow=true`，`spec-lint` 通过，Unity 日志显示程序集已成功重载且无 C# 编译错误。
    - 验收标准：HasSystem/TryGetSystem 在 GameManager 未就绪时不抛空引用；GetSystem 缺正式系统时中断并报出系统类型；重复系统中断；GameManager 门禁、spec-lint、Unity 编译和基础桥复查通过。
48. [completed] 条件当前角色与背包系统就绪边界
    - 文件集：`Assets/Scripts/GameCore/Runtime/Conditional/Conditions/IsAbilityUnlocked.cs`、`Assets/Scripts/GameCore/Runtime/Conditional/Conditions/IsItemInInventory.cs`、`scripts/Invoke-ConditionalRuntimeStaticGate.ps1`。
    - 当前结果：能力解锁条件和物品背包条件是被动查询节点，系统或当前受控角色未就绪时返回 false；当前角色背包查询失败不会退回默认队伍背包。此处和参考 `IsItemInInventory -> GameManager.InventorySystem.HasItemInBag()` 已有差异，必须在 51 中说明差异来自当前项目 owner/当前控制角色语义，还是误改。
    - 验收标准：条件节点失败语义清楚；当前角色查询失败不按队伍背包误判；补齐参考条件流程对照、条件门禁、spec-lint、Unity 编译和基础桥复查。
49. [completed] AddExperience 命令目标解析边界
    - 文件集：`Assets/Scripts/GameCore/Runtime/Commands/AddExperience.cs`、`scripts/Invoke-CommandRuntimeStaticGate.ps1`。
    - 当前结果：目标解析规则仍收口到 `GameCommandContext`，但 2026-07-16 参考流程复核后已撤回“解析不到就跳过”的结论。`AddExperience` 现在通过 `ResolveRequiredActorOrCurrentControlledCharacter(nameof(AddExperience))` 取得必需目标；缺角色或解析到非 `CharacterActor` 时抛可定位异常。该项问题不是“单例直读违规”，而是玩家结果命令不能静默吞掉参考流程中的正式结果写入。
    - 验收标准：AddExperience 通过命令上下文解析必需目标；不复制当前角色 fallback 逻辑；缺目标或目标类型错误时暴露配置错误；命令门禁、Foundation 门禁、spec-lint、Unity 编译和基础桥复查通过。
50. [completed] UI 菜单上下文系统就绪边界
    - 文件集：`Assets/Scripts/GameCore/Runtime/UI/Menus/Character/CharacterMenuContext.cs`、`Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/InventoryMenuContext.cs`、`scripts/Invoke-UIRuntimeStaticGate.ps1`。
    - 当前结果：角色菜单上下文和背包菜单上下文作为 UI 请求数据解析入口，继续使用非抛错查询并在系统或角色未就绪时返回空角色或无效 owner；当前角色背包失败不误退成默认队伍背包。门禁只验证菜单上下文失败语义，不再判定既有 GameManager 系统快捷入口本身违规。
    - 验收标准：菜单上下文失败语义清楚；当前角色查询失败不按队伍背包误判；补齐参考 UI/Inventory 流程对照、UI 门禁、spec-lint、Unity 编译和基础桥复查。
51. [completed] 43-50 参考流程复核与误改回收
    - 文件集：43-50 已列文件、`C:\Gamedev\Unity\Engine\2DRPGEngine\Assets\Mythril2D\Core\Runtime\Scripts\` 同职责源码、相关静态门禁。
    - 当前结果：已确认上一版“改成 TryGetSystem 安全查询 / 必需可选分类”不能作为主审计标准。2DRPGEngine 同职责流程中，`MovePlayer`、`AddExperience`、`IsAbilityUnlocked`、`IsItemInInventory`、`AudioRegion`、`CameraShake` 都直接通过 `GameManager.Player / InventorySystem / AudioSystem` 读取正式入口；FantasyWord 只在当前控制角色、多背包 owner、UIKit 菜单上下文、表现未就绪跳过等新增职责处保留非抛错查询。实际回收改动：`MovePlayer` 保留参考玩家入口；命令门禁字段改为 `MovePlayerMatchesReferencePlayerShortcut`；`GetSystem` 和重复系统注册改为抛异常，解决真实的正式系统缺失失败语义问题；43-50 相关门禁已移除“必须出现 `GameManager.TryGetSystem`”这类访问形式判定，改为检查非抛错 owner 解析、参考玩家入口和正式系统缺失异常；命令和音频门禁文案也已从 optional/required 依赖分类改回具体流程语义。0042 的标题也已从“安全查询边界”收紧为“查询失败语义边界”，避免被误读为调用点迁移建议。
    - 验收标准：每项结论都引用同职责参考流程或说明无同职责参考；门禁文案绑定具体流程合同而非访问形式；2026-07-16 复验：Command、Audio、Movement、Conditional、UI、Animation、GameManager 门禁全部 0 违规，脚本层搜索只剩 GameManager 查询 API 自身门禁提到 `TryGetSystem`，`spec-lint` 通过，Unity 最新日志显示程序集成功重载且无 C# 编译错误；追加复验中 Command、Audio 门禁与 `spec-lint` 仍通过。
52. [completed] CharacterBase 死亡尸体背包转移参考流程回收
    - 文件集：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.cs`、`Assets/Scripts/GameCore/Runtime/Game/Systems/InventorySystem.cs`、`scripts/Invoke-FoundationStaticGate.ps1`、`C:\Gamedev\Unity\Engine\2DRPGEngine\Assets\Mythril2D\Core\Runtime\Scripts\Entities\Characters\Monster.cs`。
    - 当前结果：已确认 2DRPGEngine 同职责死亡掉落流程在 `Monster.Kill()` 中直接通过 `GameManager.InventorySystem` 写入正式背包真相，不是未就绪可跳过流程。FantasyWord 的尸体背包/装备转移是死亡和复活规则结果，不能在缺 `InventorySystem` 时静默 return。`TransferOwnedInventoryToCorpseOwner()`、`TransferOwnedEquipmentToCorpseOwner()`、`TransferCorpseInventoryToOwnedInventory()` 已改为直用 `GameManager.InventorySystem`；尸体点击打开转移菜单的 `TryRequestCorpseInventory(...)` 仍保留可失败查询语义。新增决策 `0047-角色死亡尸体背包转移参考流程边界`。
    - 验收标准：自动死亡/复活尸体转移缺正式 `InventorySystem` 时暴露配置错误，不吞掉背包或装备转移；尸体交互菜单仍可失败；Foundation 门禁覆盖自动转移不得回退 `TryGetSystem/GameManager.Exists/return`，`InventoryCorpseOwnershipMissingPatternCount=0`，`InventoryCorpseLootInteractionMissingPatternCount=0`，`spec-lint` 通过；AIBridge Foundation refresh 成功，`FantasyWord.GameCore.dll` 已在 `CharacterBase.cs` 修改时间之后刷新。
53. [completed] Persistable 销毁存档通知参考流程回收
    - 文件集：`Assets/Scripts/GameCore/Runtime/Persistence/Persistable.cs`、`Assets/Scripts/GameCore/Runtime/Game/Systems/PersistenceSystem.cs`、`scripts/Invoke-FoundationStaticGate.ps1`、`C:\Gamedev\Unity\Engine\2DRPGEngine\Assets\Mythril2D\Core\Runtime\Scripts\Save\Persistable.cs`。
    - 当前结果：已确认 2DRPGEngine 同职责持久化对象销毁流程不会把存档通知当成可失败查询；FantasyWord 的 `PersistableDestructionSnapshot` 是合理适配，但 `NotifyPersistenceSystemAboutDestruction()` 不能在缺 `PersistenceSystem` 时静默 return。该方法已改为直用 `GameManager.PersistenceSystem.NotifyPersistableDestroyed(...)`；保存引用解析 `PersistableReference<T>.TryResolve(...)` 仍保留可失败查询语义，因为它只是活对象引用解析。
    - 验收标准：自动持久化对象销毁缺正式 `PersistenceSystem` 时暴露配置错误，不吞掉销毁状态；Foundation 门禁覆盖销毁通知不得回退 `TryGetSystem/GameManager.Exists/return`，`PersistableDestroyPersistenceSystemMissingPatternCount=0`，`PersistableDestroyPersistenceSystemDisallowedPatternCount=0`，`spec-lint` 和 Unity 编译复查通过。
54. [completed] 角色死亡与控制重算 PlayerSystem 参考流程回收
    - 文件集：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.cs`、`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Alterations.cs`、`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterActor.cs`、`scripts/Invoke-FoundationStaticGate.ps1`、`C:\Gamedev\Unity\Engine\2DRPGEngine\Assets\Mythril2D\Core\Runtime\Scripts\Entities\Characters\Hero.cs`。
    - 当前结果：已确认 2DRPGEngine 同职责玩家死亡流程不是可失败查询；FantasyWord 的 `PlayerSystem.NotifyCharacterKilled/Died/Revived` 和当前控制目标重算是合理项目适配，但不能在缺 `PlayerSystem` 时静默跳过。`CharacterActor.OnDeath()`、`CharacterBase.NotifyPlayerSystemAboutDeath()`、`NotifyPlayerSystemAboutRevive()`、`RevalidatePlayerControlEligibility()` 已改为直用 `GameManager.PlayerSystem`；UI/HUD/镜头等显示层监听仍保留就绪查询。
    - 验收标准：玩家死亡动作、当前控制目标死亡/复活回退、变身/感染后的控制资格重算缺正式 `PlayerSystem` 时暴露配置错误；Foundation 门禁覆盖这四个规则入口不得回退 `TryGetSystem/GameManager.Exists/return`，`CharacterPlayerSystemNotificationMissingPatternCount=0`，`CharacterPlayerSystemNotificationDisallowedPatternCount=0`，`spec-lint` 和 Unity 编译复查通过。
55. [completed] 正式结果写入链参考流程审计
    - 文件集：优先覆盖保存、背包、任务推进、地图切换、奖励、销毁、死亡/复活和正式角色控制结果链；不按 `TryGetSystem` 或 `GameManager.XxxSystem` 文本命中批量改代码。
    - 对照入口：已新增 `.spec/tasks/reference-flow-comparison-audit.md`，作为第 55 项后续审计的主工作表。后续新增判断必须先在该表补齐参考入口、参考 owner、参考失败语义、FantasyWord 当前差异、判定和状态，再决定是否修改代码。
    - 当前结果：新增决策 `0050-参考流程审计结论纠偏边界`，明确 `TryGetSystem<T>()` 不是默认更规范，`GameManager.XxxSystem / GetSystem<T>()` 也不是单例违规；后续只按参考同职责流程和失败语义判断是否需要改。已复核 `CommandTrigger`：2DRPGEngine 同职责触发器本身就在 PlayerSystem 未就绪时跳过，当前保留该行为不是本轮误改。已复核现存 `TryGetSystem` 调用点：表现反馈、条件/菜单解析、导航降级、活对象引用解析、MapInfo 生命周期注册、元素/地表系统失败返回均不是“正式结果写入成功但被吞掉”的链路，不能按文本命中继续改。已复核保存和旗标链：参考与当前都由 SaveSystem 直接组装/恢复 Map、GameFlag、Inventory、Journal、Player、Persistence 正式数据块，保存文件失败只报告文件层失败，不改写世界状态，当前暂不作为退步。已复核 GameState 输入图切换：参考用“先切 None、一帧后切目标图”避免同一按键穿透；当前 InputSystem 已有 `InputActionReleaseGate`，在切到 Gameplay/UI 时阻止共用按键直到释放，属于更明确的项目适配，不需要回退到参考协程。已复核世界元素和地表伤害链：施加世界元素缺 ElementReactionSystem 会报错返回失败；地表伤害缺 MapSystem 或 TerrainNavigationMap 会在绑定入口报错，角色目标还会主动注册到伤害系统。已发现并回收七个真实退步：玩家/角色结果型命令沿用了可失败目标解析，导致奖励、物品、能力、法力、治疗/伤害和复活可能静默 no-op；显式目标/策略/命令资产 `DestroyEntity`、`ToggleController`、`MoveCharacterBase`、`MoveCamera`、`PlayDialogueSequence`、`ExecuteCommandHandler`、`CommandHandler`、`ExecuteCommandList` 把缺目标、缺策略、缺对话序列、缺内部命令或缺子命令配置吞成 no-op；地图结果链 `SaveCheckpoint`、`TeleportTo`、初始/Playtest 出生点、重生和过场委托在缺检查点、缺主穿越角色或缺 TransitionSystem 时只断言后返回，可能吞掉检查点保存、传送、重生和读档位置恢复；任务日志结果链 `StartQuest` 和 `CompleteQuest` 对缺任务资产只记录错误后返回，`ItemStartQuestEffect` 可能表现为物品使用成功但任务没有开始；库存结果链 `AddToBag/RemoveFromBag` 对空物品或非法数量静默返回，可能让命令、制作产出、箱子首次初始化或击杀奖励表现为执行成功但没有写入库存；持久化实例化链在 prefab 为空、缺 `Persistable`、目标类型不匹配、注册对象为空或标识符为空白时只靠断言/后续空引用，可能把坏实例写入持久化字典或让刷怪/玩家登记链表现为已执行；主玩家控制链在缺正式 `CharacterPlayerControl` 配置时进入等待恢复，可能把场景/Prefab 配置错误吞成无输入目标。已新增 `0051-玩家结果型命令必需目标边界`、`0052-显式目标与策略命令必需配置边界`、`0053-地图结果链必需配置参考流程边界`、`0054-任务日志结果链必需任务资产参考流程边界`、`0055-背包结果写入参考流程边界`、`0056-持久化实例化必需配置参考流程边界`、`0057-主玩家控制目标必需配置参考流程边界`，并做最小代码修复。又回收了 `Audio/Animation/Conditional/Movement/UI` 五个运行时门禁中的访问形式残留：门禁继续检查区域触发、受击表现、条件查询、速度区域和菜单上下文的失败语义，但不再用 `GameManager.XSystem` 文本出现与否判定好坏。
    - 追加复核：`SetCurrentControlledCharacter`、`TryAddCurrentControlGroupMember`、`TryRemoveCurrentControlGroupMember` 和 `TrySetCurrentControlGroupPrimaryMember` 在正式运行时代码中只由 `PlayerSystem` 闭包内部调用；外部命中仅为编辑器测试和 smoke 验证桥，且 bridge 会把 bool 结果写入验证报告。因此当前没有发现“正式业务调用控制组操作但忽略失败”的结果链退步，不按 public/void/try 形式继续误改。
    - 追加复核：奖励技能命令同职责流程已对照 2DRPGEngine。参考 `AddOrRemoveAbility` 直接给正式玩家添加/移除配置的能力资产；FantasyWord 迁移为 Formal GAS 技能编码后，编码小于等于 0 代表没有真实能力配置，旧流程会把“奖励技能”吞成成功 no-op。已最小修复 `AddOrRemoveAbility`：执行前验证 Formal GAS 技能编码大于 0，否则抛出可定位异常；命令门禁新增 `AddOrRemoveAbilityRejectsInvalidCode`。该结论来自参考结果命令必须有真实能力配置，不是因为接口形式或单例问题。
    - 追加复核：商店买入同职责流程已对照 2DRPGEngine。参考工程在唯一玩家背包中先扣钱再加物品成立；FantasyWord 的多 owner 背包新增了当前交易 owner 失效面，旧流程可能先扣钱再让物品写入失败。已最小修复 `UIShop`：买入前验证 owner 有效，无效时在扣钱前抛出可定位异常；库存门禁新增 `ShopBuyValidatesOwnerBeforeMoneyRemoval`。该结论来自多 owner 适配，不是访问形式重构。
    - 追加复核：商店卖出同职责流程已对照 2DRPGEngine。参考工程直接从唯一玩家背包删物品后加钱成立；FantasyWord 的多 owner 背包是必要增强，但商店卖出必须确认当前交易 owner 删除成功后才加钱。已最小修复 `UIShop` 并补库存门禁；该结论不是“单例违规”或“Try 查询更规范”。
    - 追加复核：制作同职责流程已对照 2DRPGEngine。参考流程是 `CanCraft -> 成功提示 -> Craft`，`Craft` 直接扣钱、扣材料、写产物；FantasyWord 保留这条流程，但因为当前库存写入会拒绝坏物品/坏数量，配方必须在制作写入前验证产物、材料和额外产物配置，`CraftingStation.Craft` 也必须重新确认当前 owner 仍可制作。已最小修复 `Recipe` / `CraftingStation` 并补库存门禁 `CraftingValidatesRecipeBeforeWrites`。
    - 追加重构：商店买入、商店卖出、制作和宝箱首次掉落初始化已经从调用点 guard 升级为库存多步交易合同。新增 `0058-库存多步交易合同边界`；`InventorySystem` 统一执行 `ExecuteShopPurchase`、`ExecuteShopSale`、`ExecuteCraftRecipe`、`ExecuteChestLootInitialization`，`UIShop`、`UICraft`、`CraftingStation`、`Chest` 不再手写扣钱、扣物、加物和加钱顺序；库存门禁改为检查 `ShopTradingUsesInventoryTransaction`、`CraftingUsesValidatedInventoryTransaction` 和宝箱库存初始化事务。
    - 追加验证：新增并扩展 `InventorySystemTransactionEditModeTests`，覆盖买入失败不扣钱、卖出失败不加钱、负制作费用不扣钱/扣料/给产物、制作失败不扣钱/扣料/给产物、制作成功一次性扣钱扣料给产物、坏宝箱掉落不写入前面有效条目、有效宝箱掉落一次性写入物品和金钱、坏击杀奖励不写入前面有效掉落或金钱、有效击杀奖励一次性写入物品和金钱；撤出无正式入口证据的旅店付款测试，不再把参考旅店业务当作当前重构成果。2026-07-16 重整复验：`InventorySystemTransactionEditModeTests` 新程序集定向 EditMode 通过，`passedTests=18`、`failedTests=0`；库存门禁、`spec-lint`、diff 空白检查通过；Console 当前 `Error/Exception/Assert=0`；当前仍只打开 `Assets/Scenes/ClickMoveTest.unity` 且 `isDirty=false`。
    - 追加复核：击杀奖励库存写入同职责流程已对照 2DRPGEngine。参考 `Monster.Kill()` 逐条给玩家背包掉落并加钱，在单背包和宽松写入下成立；FantasyWord 的奖励接收者 owner 可变，且库存写入会拒绝空物品/非法数量，旧流程可能先写入前面命中的掉落，再因后续坏掉落中断。已新增 `0060-库存奖励写入合同边界`，由 `InventorySystem.ExecuteLootReward` 先整体验证本次实际命中的掉落和金钱奖励，再统一提交；经验仍由角色写入。该结论来自多 owner 与严格库存写入适配，不是访问形式重构。
    - 追加复核：背包菜单同职责流程已对照 2DRPGEngine。参考工程的背包 UI 只显示唯一玩家背包；FantasyWord 的多 owner 菜单上下文为了避免误读默认队伍背包，会在当前控制角色或 InventorySystem 未就绪时返回无效 owner。此前 `UIInventoryBag.UpdateSlots` 仍会继续读取该无效 owner 并让视图层抛异常。已最小修复为：无效 owner 或库存系统未就绪时清空槽位并停止显示；UI 门禁新增 `InventoryBagKeepsInvalidOwnerEmpty`，该结论不是“TryGetSystem 更规范”，而是多 owner UI 失败语义必须完整。
    - 追加复核：消耗型物品使用同职责流程已对照 2DRPGEngine。参考工程在效果成功后从唯一玩家背包扣物品；FantasyWord 继承后新增多 owner 与可失效 UI，如果仍先应用效果和成功反馈、再忽略扣除失败，会出现“效果已生效但来源背包没扣物品”的结果链退步。已最小修复 `AItemEffect`：消耗型物品先确认来源 owner 仍持有物品，效果成功后先扣除再播放成功音效/提示；库存门禁新增 `ConsumableUseRequiresInventoryItem`。该结论不是“安全查询更规范”，而是参考单背包流程在当前多 owner 项目里的必要适配。
    - 追加复核：物品移除命令同职责流程已对照 2DRPGEngine。参考 `AddOrRemoveItem` 直接移除唯一玩家背包物品；FantasyWord 的 `AddOrRemoveItem` 是上下文结果型命令，已经要求必需目标，但 Remove 分支仍忽略 `RemoveFromBag` 失败，可能把“移除指定 owner 物品”吞成成功。已最小修复为移除失败抛出可定位异常；命令门禁新增 `AddOrRemoveItemRejectsMissingRemoval`。该结论不是因为参考用了或没用单例，而是当前多 owner 结果命令不能假成功。
    - 追加复核：装备卸下同职责流程已对照 2DRPGEngine。参考 `InventorySystem.TryUnequip -> Hero.TryUnequip -> AddToBag` 在唯一玩家背包下成立；FantasyWord 的多 owner 背包让回包目标可能无效，旧流程会先改变角色装备状态，再在回包时暴露无效 owner，形成“装备消失但未回包”的半完成状态。已最小修复 `InventorySystem.TryUnequip`：目标 owner 无效时在调用 `CharacterEquipment.TryUnequip` 前抛出可定位异常；库存门禁新增 `EquipmentUnequipValidatesDestinationBeforeStateChange`。该结论来自当前多 owner 适配，不是因为访问形式或单例问题。
    - 追加复核：装备附加能力同职责流程已对照 2DRPGEngine。参考 `Hero.Equip/Unequip` 直接用装备资产里的能力引用同步加/移除能力；FantasyWord 改为 Formal GAS 编码后，还必须把装备数据库稳定引用作为能力来源。旧流程若在槽位改变后才发现装备未登记，会记录错误并继续，可能形成“装备已穿/已卸，但附加能力来源丢失”的半完成状态。已最小修复 `CharacterEquipment`：带附加能力的装备在槽位改变前准备数据库来源，来源无效直接抛出可定位异常；库存门禁新增 `EquipmentAbilitySourcePreparedBeforeSlotChange`。该结论来自当前稳定来源身份适配，不是因为 `GameManager.Database` 访问形式问题。
    - 追加复核：死亡装备转尸体同职责流程已对照 2DRPGEngine 和当前多 owner 适配。参考没有尸体 owner 这个失败面；FantasyWord 的尸体背包依赖角色稳定持久化标识，旧流程会先 `ForceUnequipAllEquipmentForLifecycle()`，再把装备写进尸体背包，若 corpse owner 无效就会形成“死亡时装备从角色消失但没进尸体背包”的半完成状态。已最小修复 `InventorySystem.TransferCharacterEquipmentToCorpse`：在强制卸装前验证 corpse owner；库存门禁新增 `EquipmentCorpseTransferValidatesOwnerBeforeForceUnequip`。该结论来自当前尸体背包 owner 适配，不是因为 `GameManager.InventorySystem` 访问形式问题。
    - 追加复核：旧规则型持续效果同职责流程已对照 2DRPGEngine。参考 `EffectDispatcher.Apply` 把旧 `IEffect[]` 作为正式技能/投射物/命令效果链；FantasyWord 当前已删除旧 `EffectDispatcher`、旧即时效果和旧 AbilitySheet 主链，主动能力和伤害由 EX-GAS Ability / Timeline / GameplayEffect / Cue 承担。当前代码仍保留 `ITemporalEffect/ATemporalEffect`、读档反射恢复、UI 展示快照、Cleanse 和三类 Formal 能力持续壳，因此不能直接删除整条持续效果运行时；但本轮资产搜索没有发现正式资产、Prefab、场景或动画资产引用旧伤害/治疗/回蓝/属性/速度/控制效果。已新增 `0062-旧规则型持续效果边界`，并在能力门禁中禁止正式资产重新引用这些旧规则型持续效果。该结论不是把参考旧效果链搬回来，也不是粗暴删除旧存档兼容壳。
    - 追加复核：变形/感染规则授予/压制 Formal GAS 能力同职责流程已对照 2DRPGEngine。参考没有独立 `CharacterAlterationRule`，但装备、命令和持续效果改变能力集合时使用真实 `AbilitySheet` 资产引用；FantasyWord 用 Formal GAS 技能编号替代旧资产引用后，数组中的小于等于 0 编号不能继续被过滤成“没有能力变化”。已新增 `0063-变形感染规则 Formal GAS 编号校验边界`，并最小修复 `CharacterAlterationRule` / `CharacterBase.Alterations`：规则正式应用前先校验能力编号配置，空数组仍允许纯动作锁、玩家控制锁、AI 接管、装备压制或阵营覆盖规则生效。该结论来自能力作者配置语义，不是接口形式或单例问题。
    - 追加复核：Formal GAS 能力授予/压制/替换持续效果同职责流程已对照 2DRPGEngine。参考持续效果应用成功后才登记到角色持续效果列表，能力项来自真实 `AbilitySheet` 引用；FantasyWord 用 Formal GAS 编号和状态效果来源键替代旧资产引用后，编号小于等于 0 不能继续被过滤成成功 no-op，空能力列表也不能登记成成功能力持续效果。已新增 `0064-能力持续效果 Formal GAS 编号校验边界`，并最小修复 `TemporalAbilityGrantEffect`、`TemporalAbilitySuppressionEffect`、`TemporalAbilityReplacementEffect`：应用前校验编号，空配置返回 false，替换效果先校验授予和压制两边再写角色能力。该结论来自能力作者配置语义和持续效果登记合同，不是访问形式或单例问题。
    - 追加复核：Formal GAS 能力持续效果读档恢复同职责流程已对照 2DRPGEngine。参考持续效果只有成功应用后才进入角色持续效果列表，读档恢复的是已在角色 live 列表里的效果对象；FantasyWord 的读档恢复路径此前绕过 `Apply()` 校验，可能把坏保存记录里的无效能力编号过滤成空 no-op 后仍登记持续效果，并且最小 runtime state 重建后只写持久引用、不绑定当前角色 live owner，会导致有效记录恢复回调拿不到目标角色。已新增 `0065-能力持续效果读档恢复校验边界`，并最小修复 `ITemporalEffectRuntimeStateCarrier` / 三类能力持续效果 / `CharacterTemporalEffectRuntimeStateData` / `AEffect` / `ATemporalEffect`：恢复入口改为可失败合同，坏保存记录只跳过该效果，有效记录恢复时绑定当前角色 live owner，再恢复能力来源和持续效果登记。该结论来自保存恢复合同，不是访问形式重构。
    - 追加验证：2026-07-17 修复两处旧测试合同残留：`ItemAddAbilityEffect_UsesFormalGasAbilityCodeWithoutLegacySheetReference` 改用已登记 `Item` 作为物品能力来源，`FlamethrowerGeneratedTimeline_UsesPresentationOnlyMountCue` 改验 `CueMountPrefab.PrefabPath` 中的 `PrefabReference` 数据库 GUID 而非旧 `Assets/...` 文本路径。AIBridge 精确运行两项测试均通过；随后完整 `FantasyWord.GameCore.EditModeTests` 通过，`failedTests=0`。
    - 追加验证：2026-07-17 Formal GAS 能力持续效果编号校验收口：`spec-lint` 通过；`Invoke-FoundationStaticGate.ps1 -AsJson` 中 `TemporalAbilityEffectSupportMissingPatternCount=0`、三类 `TemporalAbility*EffectMissingPatternCount=0`；`Test-FoundationReferenceParity.ps1 -AsJson` 无 unexpected mismatch/extra；AIBridge 精确运行 `TemporalAbilityGrantEffect_InvalidFormalGasAbilityCode_ThrowsBeforeRuntimeRegistration` 通过；`MeleeAttackAbilityEditModeTests` 类通过，`passedTests=207`、`failedTests=0`；完整 `FantasyWord.GameCore.EditModeTests` 通过，`failedTests=0`。Editor 复查为 `isPlaying=false`、`isCompiling=false`，当前打开 `Assets/Scenes/ClickMoveTest.unity` 且 `isDirty=false`。
    - 追加验证：2026-07-17 Formal GAS 能力持续效果读档恢复收口：AIBridge 精确运行 `TemporalAbilityGrantEffect_ValidPersistedState_RestoresAbilityAndRuntimeRegistration` 通过，精确运行 `TemporalAbilityGrantEffect_InvalidPersistedState_IsSkippedOnLoad` 通过；`MeleeAttackAbilityEditModeTests` 按 `testClass` 运行通过，`passedTests=213`、`failedTests=0`；完整 `FantasyWord.GameCore.EditModeTests` 通过，`failedTests=0`、`passedTests=664`；`spec-lint` 通过；`Invoke-FoundationStaticGate.ps1 -AsJson` 通过；`Test-FoundationReferenceParity.ps1 -AsJson` 无 unexpected mismatch/extra。
    - 追加复核：角色读档装备槽和快捷槽同职责流程已对照 2DRPGEngine。参考 `Hero.OnLoad` 会先重建装备字典和快捷能力槽，再按存档内容覆盖；FantasyWord 拆成 `CharacterEquipment` 和 Formal GAS 快捷槽后，旧恢复函数在 `equipmentSlots` / `quickAbilitySlots` 为 `null` 或空数组时直接返回，可能留下 Prefab 初始装备、读档前装备或旧快捷槽。已新增 `0066-角色读档槽位覆盖边界`，并最小修复 `CharacterEquippedItemLoadout` / `CharacterEquippedAbilityLoadout`：空/缺失槽位数据也会先清空当前槽位；新增两项 EditMode 测试覆盖装备槽和快捷槽读档覆盖。该结论来自参考读档覆盖语义，不是访问形式重构。
    - 追加验证：2026-07-17 角色读档槽位覆盖收口：AIBridge 精确运行 `CharacterActorRuntimeLoad_MissingQuickSlots_ClearsExistingQuickSlot` 通过，精确运行 `CharacterActorRuntimeLoad_MissingEquipmentSlots_ClearsExistingEquipment` 通过；`MeleeAttackAbilityEditModeTests` 按 `testClass` 运行通过，`failedTests=0`；完整 `FantasyWord.GameCore.EditModeTests` 通过，`failedTests=0`；`spec-lint` 通过；`Invoke-FoundationStaticGate.ps1 -AsJson` 通过；`Test-FoundationReferenceParity.ps1 -AsJson` 无 unexpected mismatch/extra。
    - 追加复核：库存/命令剩余候选已按当前业务证据筛过。`ItemPickable`、`MoneyPickable`、`PickableItem` 没有场景、Prefab 或资产引用，暂不纳入当前业务重构；`CompleteTask` 与参考同构且无正式资产引用，不把“无匹配任务”升级成结果链假成功；`SetGameFlag` 与参考同构且无正式资产引用，空 flag 策略后续等正式 flag 作者数据接入再按命名规范审。该结论来自当前业务证据分拣，不是因为这些代码形式天然正确。
    - 追加复核：运行时资源路径、Yoki/FWRes/FWScene 已按参考流程补到 `.spec/tasks/reference-flow-comparison-audit.md`。参考工程正式资源主链是 `DatabaseEntryReference<T>`、`PrefabReference` 和序列化资产引用；FantasyWord 当前 EX-GAS 严格资源门禁显示源表和生成 JSON 的 `Assets/...` 债务为 0，`FWRes` 为空，`FWScene.SampleScene` 只有 1 条未被正式业务调用的生成场景路径警告。因此本轮不把 Yoki/Addressables/FWScene 升级成官方内容 owner，也不把稳定数据库 GUID 或序列化引用改成字符串 key。
    - 追加复核：框架常量、主菜单/引擎场景名、系统自举扫描和存档对象扫描已补到对照表。`Constants.M2DEngineSceneName`、`Constants.UniquePlayerIdentifier`、等级范围、技能槽上限和 `GameConfig.mainMenuSceneName` 均为参考同职责框架合同；`GameManager.FindSystems()` 和 `PersistenceSystem` 的 `FindObjectsByType` 也是参考同构的自举/存档索引，不是缺引用兜底。`FormalSceneSingletonConflictDiagnostics` 的全局扫描只做 EventSystem/AudioListener 数量取证，不提供依赖引用。
    - 追加修复：换装生成设置与静态门禁同职责流程已对照参考工程。生成器已有 `EquipmentSystemGenerationSettings` 作为动画根、共享片段目录、方向库目录、Controller 和工作台目录的正式 owner；旧门禁脚本重复维护同一套路由，形成生成器配置与验证工具漂移风险。已新增 `0067-换装生成设置与静态门禁 owner 边界`，并最小修复 `Invoke-EquipmentSystemStaticGate.ps1`：门禁读取正式生成设置资产解析派生资源路径，读不到设置资产时报告配置缺失，不再维护第二套路径真相。
    - 追加验证：2026-07-17 换装生成设置门禁收口：`Invoke-EquipmentSystemStaticGate.ps1 -AsJson` 通过，`GenerationSettingsMissing=false`，`GenerationSettingsViolationCount=0`，`ArchitectureContractViolationCount=0`，方向片段/方向状态/方向分类/旧运行时均为 0；输出路径来自正式生成设置资产，解析为动画根、共享片段、方向库、共享 Controller 和工作台目录。`spec-lint` 通过，本轮触达文件 `git diff --check` 无空白错误。
    - 追加复核：正式命令假成功候选已按参考同职责流程和当前资产证据筛过。参考 `ICommand.Execute()` 本身没有成功返回值，只有具体命令资产承担正式结果时才需要按结果链判错；当前对 `Assets/Scripts/GameCore/Runtime/Commands` 全部脚本做 GUID 引用矩阵，`Assets/GameData`、`Assets/Prefabs`、`Assets/Scenes`、`Assets/Resources` 中引用数均为 0。`CompleteTask`、`SetGameFlag`、`AddOrRemoveMoney` 等剩余样本与参考同构且无正式资产命中，本轮不按 `Task.CompletedTask`、`Debug.Assert` 或 `return` 文本继续改；后续出现具体命令资产时再按资产逐项补对照。
    - 追加修复：当前运行时状态保存的数据库引用同职责流程已对照参考工程。参考保存当前背包、任务、装备和任务进度时直接创建数据库引用；FantasyWord 读坏档可以跳过坏 GUID，但保存当前运行时结果不能把未登记物品、任务、装备或变形/感染规则过滤成部分存档。已新增 `0068-当前运行时状态保存必需数据库引用边界`，并最小修复 `DatabaseRegistry.CreateReference<T>`、库存保存、任务日志保存、任务进度保存、装备槽保存和活跃变形/感染规则保存：缺稳定数据库引用直接抛出可定位异常，读档容错语义不变。
    - 追加验证：2026-07-17 保存必需数据库引用收口：`Invoke-FoundationStaticGate.ps1 -AsJson` 通过，`SaveReferenceRequiredMissingPatternCount=0`，`SaveReferenceRequiredDisallowedPatternCount=0`，`CharacterBaseAlterationsMissingPatternCount=0`，`CharacterAlterationRuleMissingPatternCount=0`；`spec-lint` 通过。本条只证明保存链静态合同和规范结构已收口，未宣称完整 PlayMode 场景回归。
    - 追加验证：2026-07-17 角色变化规则读档合同补测收口：新增 `CharacterAlterationRuleRuntimeLoad_RestoresNonAbilityStateAndCanRevoke` 与 `CharacterAlterationRuleRuntimeLoad_DoesNotDuplicateAbilitySourceAndCanRevoke`，覆盖变形/感染规则应用后保存、读档、撤回、非能力状态恢复和能力来源不重复叠加；AIBridge EditMode 运行 `MeleeAttackAbilityEditModeTests` 时两项均进入 Unity Test Runner 且 Passed，`failedTests=0`。本条补齐 `.spec/tasks/reference-flow-comparison-audit.md` 中“角色变化规则与激活状态”原测试缺口，不新增架构决策。
    - 追加收口：2026-07-17 复核第 55 项剩余候选，`ItemPickable`、`MoneyPickable`、`PickableItem` 仍无正式场景、Prefab 或资产引用，不纳入当前业务修复；剩余命令脚本也无正式资源引用，后续只有出现具体命令资产时才按资产重新审。顺手修复两个验证工具问题：`Invoke-InventoryRuntimeStaticGate.ps1` 和 `Invoke-CommandRuntimeStaticGate.ps1` 不再在脚本源码中写中文匹配文本，改为 ASCII 结构匹配，避免 Windows PowerShell 解析 UTF-8 无 BOM 脚本时报语法错误。
    - 最终验证：2026-07-17 `spec-lint` 通过；`Invoke-FoundationStaticGate.ps1 -AsJson` 通过；`Invoke-InventoryRuntimeStaticGate.ps1 -AsJson` 通过，13 项库存合同全为 true；`Invoke-CommandRuntimeStaticGate.ps1 -AsJson` 通过，18 项命令合同全为 true 且 `RawCommandTaskDropCount=0`；`Invoke-LootRuntimeStaticGate.ps1 -AsJson` 通过；`Test-FoundationReferenceParity.ps1 -AsJson` 显示 runtime/editor unexpected mismatch 与 unexpected extra 均为 0；本轮未加载、保存或切换场景。
    - 验收标准：每个新增问题都必须列出 2DRPGEngine 同职责流程、FantasyWord 当前流程、差异性质和最小修复；门禁只绑定具体结果合同，不新增访问形式规则。2026-07-16 复验：旧决策正文中“必须 TryGetSystem / 不能直读 GameManager.PlayerSystem”的可执行残留已清零；脚本层搜索已无 `notmatch GameManager.XSystem`、`instead of reading formal system shortcuts directly`、`必须出现 GameManager.TryGetSystem` 这类访问形式门禁；`spec-lint`、Audio、Animation、Conditional、Movement、UI、Persistence、Foundation 门禁均通过；Unity 资源刷新后编译完成，Console 最近 200 条 `Error/Exception/Assert=0`，当前仍只打开 `ClickMoveTest.unity` 且 `isDirty=false`。本轮追加：同职责流程先行已升格到 `.spec/rules/system.md` 硬红线，后续参考工程/多方参考审计不得再把实现形式当判定标准；UI 门禁字段已从 `MenuContextsGuardSystems` 收紧为 `MenuContextsKeepFailedLookupInvalid`，验证菜单上下文失败时返回空角色/无效 owner，而不是验证 `TryGetSystem` 精确文本；Foundation 门禁也已去掉 `return GameManager.TryGetSystem(out playerSystem);` 精确文本要求，改为验证条件监听可失败解析、当前角色读取和监听注册/注销合同。
## 当前阻塞

- 无。全范围模块队列当前 55 项均已收口；后续新增业务或正式资产接入时，继续按“参考同职责流程优先”的口径另开新项。







