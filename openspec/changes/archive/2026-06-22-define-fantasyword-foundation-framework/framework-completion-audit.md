# Framework Completion Audit

> 目的：按用户要求复核“正确理由”和“正确框架”是否真的落地。
> 本文件只记录当前证据，不把未来计划写成已完成。
> 阅读顺序固定为：`docs/ai/框架最终裁决.md` 先给结论，`docs/ai/框架三项判分矩阵.md` 负责回答“为什么选这边”，`docs/ai/框架正式动作清单.md` 负责回答“到底替换/融合/冻结什么”，`docs/ai/框架实施阶段表.md` 负责回答“先做什么后做什么”，本文件只负责检查当前仓库有没有按这几层裁决执行。
> 说明：本文若提到历史独立菜单组件名称，只用于留痕说明已删除阶段，不代表当前正式 prefab 或运行时代码里还保留第二套菜单入口。

## 审计口径

- 判断标准只用三项：`设计模式`、`软件工程`、`易用`。
- “当前已经接入/已经存在”不是理由，只能作为事实证据。
- `2DRPGEngine`、`TopDownEngine`、`YokiFrame` 同职责冲突时只能留下一个正式真相源。
- `uMMORPG` 不参与上面这张总框架胜负表；它当前只作为 `2D 移动与场景组织` 的局部源码证据源。
- 融合必须落到 `GameCore` 正式闭包或第三方稳定工具入口；不得新增 `Compatibility`、`Adapter`、`Wrapper`、`Facade`、`FoundationSupport` 等双轨层。
- 当前不得为开放世界模拟层先写空类；只有区域、队伍、派系、AI 日程、经济等具体能力进入验收时才落代码。

## 审计结论摘要

这里记录的是“裁决是否已经被当前仓库执行证据支持”，不是再做一遍裁决。

先看结论，不看过程时，只需要记住四句话：

- 世界规则层按裁决应由 `2DRPGEngine` 担任正式真相源，这一点当前已有执行证据支持。
- 动作表现层按裁决应由 `TopDownEngine` 担任正式胜者，并吸收到 `GameCore`；这件事当前只完成到“核心闭包已吸收”，还没完成所有表现接线。
- 工具层按裁决应由 `YokiFrame` 担任正式胜者；当前对象池、SaveKit、InputKit 已切入，UIKit 菜单运行时也已进入正式融合并成为当前 UI 唯一菜单入口。
- 开放世界模拟层按裁决应由 `FantasyWord` 自建；当前还没有形成正式实现，不能误报成“地基已经足够”。

如果要再压成一句话，就是：

- 当前仓库已经证明“世界规则层归 2DRPG、动作层归 TopDown、工具层归 YokiFrame”这套裁决方向是成立的。
- 当前仓库还没有证明“开放世界模拟层已经完成”。
- 当前 foundation 完成门禁只看框架收口和代表性案例，不把后续玩法扩展、控制组进阶、RTS 化、未来远程访客或开放世界模拟未开工项当成当前框架失败证据。

| 类别 | 裁决 | 当前审计结论 |
| --- | --- | --- |
| 兼容层/适配层 | 正式禁止 | 已成立。插件边界门禁持续禁止 `Compatibility/Adapter/Wrapper/Facade/FoundationSupport` 命名与路径段，`Invoke-FrameworkVerdictGate.ps1` 当前 `CompatibilityViolationCount = 0` |
| 世界规则真相 | `2DRPGEngine` 胜出 | 已成立。`GameManager + AGameSystem`、地图、存档、背包、命令、持久化等闭包已在 `GameCore` 落地，并通过 parity / 静态门禁保护 |
| 动作表现层 | `TopDownEngine` 胜出并吸收到 `GameCore` | 已部分完成。移动、能力权限、武器执行、命中窗口、受击/死亡/拾取/交互反馈已吸收；相机/屏幕反馈和更多表现接线仍有剩余 |
| 工具层 | `YokiFrame` 胜出 | 已完成当前阶段。对象池、SaveKit 文件层、InputKit 绑定层已切入；UIKit 菜单运行时也已成为正式 UI 菜单入口。`2026-06-18` 重新实跑 UIKit 非业务面板栈 smoke 继续通过，正式 `MenuParts` 分层与旧菜单壳退场也已复核，不再存在框架级未闭合项 |
| 开放世界模拟层 | `FantasyWord` 自建 | 未开始正式实现。当前没有任何正式 world runtime 入口，区域/Cell、队伍、派系、AI 日程、经济/基地生产仍未落地 |
| 目录边界 | `GameCore/Editor/Plugins` 当前成立 | 已成立。目录裁决和现态执行一致；`Invoke-FrameworkVerdictGate.ps1` 当前 `MissingDirectoryCount = 0`，顶层 `World/Characters/Combat/...` 仍只是未来晋升目标 |
| 一级缺口 | 点击移动/实例宿主/出生点分流等仍受阻 | 未解锁。还缺 4 个正式参考位，因此这些能力仍不得硬做 |
| 提案剩余暂留项 | 只保留确实未决的裁决 | 当前 `patched-parity-matrix.md` 的 runtime patched 项已清零 `暂留`，`docs/ai/foundation-reference-audit.md` 里原先最后 3 条 `暂留` 也已改成正式 `保留`：`GameConfig` 继续作为唯一配置真相入口，`Persistable.Destroy()` 的 fire-and-forget 命令调用只是语言适配，`PersistenceSystem.GetActualIdentifier()` 只是把映射读取统一收回 `GameConfig` API 的内部薄 helper。当前剩余工作已不再是“同职责真相未决”，而是动作表现深化、投射物池化/真实存档/点击移动一级缺口，以及更高层开放世界模拟尚未开工 |

这里也要分层理解：

- `一级缺口` 只描述当前 `2D 移动与场景组织` 这条线还缺什么正式参考。
- `开放世界模拟层` 描述的是更大一层的长期架构还没正式开工。

两者不是同一层待办，不能读成“当前只剩 5 个并列缺口”。

## 动作状态总表

| 动作类型 | 模块 | 当前状态 | 当前判定 |
| --- | --- | --- | --- |
| 直接替换 | 旧自造地基 | 已完成 | `Bootstrapper/RuntimeContext/ModuleInstaller/EventBus` 已退出正式口径 |
| 直接替换 | 对象池 | 已完成 | 项目侧浅池已由 `GameObjectPoolService` 取代 |
| 直接替换 | 武器执行层 | 已完成当前阶段 | TopDown 风格武器状态机、命中窗口和执行闭包已吸收进 `GameCore` |
| 直接替换 | 动作阻断模型 | 已完成当前阶段 | 权限与阻断已收口到统一能力合同 |
| 正式融合 | 地图、检查点、传送、重生 | 已完成当前阶段 | `MapSystem` 保真相，TopDown 表现配置已吸收 |
| 正式融合 | 生命数值与受击表现 | 已部分完成 | 数值真相已留在 RPG stats；相机/屏幕反馈仍有剩余 |
| 正式融合 | 存档 | 已完成当前阶段 | `SaveDataBlock` 保语义，`SaveKit` 保文件层 |
| 正式融合 | 输入 | 已完成当前阶段 | `InputSystem` 保真相，`InputKit` 只做重绑定工具 |
| 正式融合 | 背包真相与角色操作目标 | 已完成当前阶段 | 背包仍是一套真相，操作目标已跟随当前控制 Hero |
| 正式融合 | 前台角色回退规则 | 已完成当前阶段 | 回退规则已统一收回 `PlayerSystem` |
| 正式融合 | UI 菜单语义与缓存工具 | 已完成当前阶段 | 当前由 `UIManager` 内部承接唯一菜单运行时，旧 `AUIMenu/IUIMenu/UIMenuManager` 代码与历史阶段独立菜单组件都已退场；`MenuHostRuntimeOwnershipGuard/UIMenuRegistry/MenuRouteTopology` 与对应 orphan `.meta` 也已确认不存在。`2026-06-18` 重新实跑 UIKit 非业务面板栈 smoke 继续通过，`Assets/Prefabs/UI/Menus` 已不存在，顶层旧菜单壳搜索结果为 0 |
| 暂不动 | TopDown manager / 输入 / GUI / Level 生命周期 | 禁止升格为正式入口 | 继续禁止升格为正式入口 |
| 暂不动 | YokiFrame 架构层 | 禁止接管生命周期 | 继续禁止接管生命周期 |
| 暂不动 | 具体业务 UI 扩写 | 继续禁止 | 当前只做正式入口、资源链和共享构件收口，不因 UIKit 已落地就顺手扩写商店、制作或其它业务流程 |
| 暂不动 | 完整点击移动 / 自动靠近 / 控制组穿越 / 实例入口 | 待一级参考补齐 | 一级缺口未补齐前不得硬做；当前只允许保留已落地的第一阶段基础点击移动链路 |
| 暂不动 | 开放世界模拟空壳 | 待具体规格锁定 | 具体规格未建前不得先写空 `World` 架构 |

## 裁决依据与证据边界

- `docs/ai/框架最终裁决.md`：默认引用入口。这里把最终结论、目录边界和模块动作先压成单一入口。
- `docs/ai/框架三项判分矩阵.md`：正式胜负依据。这里定义每个系统在 `设计模式 / 软件工程 / 易用` 三项上的强弱，不允许用现态倒推。
- `docs/ai/框架正式动作清单.md`：正式动作依据。这里定义每个模块属于 `直接替换 / 正式融合 / 暂不动` 哪一类。
- `docs/ai/框架代码现态矩阵.md`：代码现态依据。这里回答“当前正式运行时代码已经收口到了哪一步”。
- `docs/ai/框架代码未收口矩阵.md`：代码缺口依据。这里回答“哪些裁决还只是文档成立，代码尚未彻底收口”。
- `docs/ai/框架实施阶段表.md`：正式顺序依据。这里定义这些动作先后如何推进。
- 本审计里出现的脚本、门禁、搜索结果和文件落点，只用于证明“当前仓库执行到了哪一步”，不反过来充当胜负理由。

## 框架裁决结果

| 层 | 真相源 | 使用参考 | 当前状态 | 证据 |
| --- | --- | --- | --- | --- |
| RPG 世界规则 | `GameCore` 中的 2DRPG 闭包 | `2DRPGEngine` | 已作为地基正式闭包落地 | `Test-FoundationReferenceParity.ps1`：missing 0、unexpected mismatch 0、unexpected extra 0 |
| 俯视角动作表现 | `GameCore` 正式角色/战斗/表现闭包 | `TopDownEngine` | 已吸收移动、能力权限、武器、命中窗口、受击/死亡/奖励/拾取/交互反馈；未完成相机/屏幕反馈、地图表现接线 | `Movable.cs`、`AbilityPermissionSettings.cs`、`ActiveAbilityBase.cs`、`CharacterBase.cs`、`Monster.cs`、`Entity.cs`、`WeaponExecutionRuntime.cs`、`WeaponHitWindowRuntime.cs`、`GameplayFeedbackSet.cs` |
| 通用工具 | `YokiFrame` 稳定工具入口 | `YokiFrame` | 已替换对象池、SaveKit 文件层、InputKit 绑定层，并由 `UIManager + UIKit` 接管正式 UI 菜单运行时 | `GameObjectPoolService` 调用点、`SaveSystem.cs`、`InputSystem.cs`、`UIManager.cs` |
| 开放世界模拟 | FantasyWord 未来世界运行时内核 | Skyrim/Kenshi 概念参考 | 未落代码，只登记缺口 | `docs/ai/三方框架系统对照.md` 的世界运行时候选表 |

## 动作详细证据

| 裁决项 | 应做动作 | 当前证据 | 状态 | 下一步 |
| --- | --- | --- | --- | --- |
| 旧自造地基 | 用 `GameManager + AGameSystem + GameConfig` 替换旧 Bootstrapper/RuntimeContext/ModuleInstaller/EventBus | `Invoke-FoundationStaticGate.ps1` 通过，旧入口搜索由门禁覆盖 | 已完成静态收口 | 后续只在 Unity smoke 失败时修接线 |
| TopDown manager | 不接入 `GameManager/LevelManager/InputManager/GUIManager/Health` 作为第二生命周期 | `Invoke-PluginFacadeBoundaryGate.ps1` 违规 0 | 已完成门禁约束 | 吸收 TopDown 新模块前继续跑门禁 |
| YokiFrame 生命周期 | 不把 `Architecture/EventKit/SingletonKit` 当游戏生命周期 | `Invoke-PluginFacadeBoundaryGate.ps1` 违规 0 | 已完成门禁约束 | YokiFrame 继续只做工具层 |
| 对象池 | 用 YokiFrame `GameObjectPoolService` 替换 2DRPG 浅池和 UI 局部池 | `FloatingTextPool`、`FloatingText`、`UICharacterInfo`、`UIHUDEffectBar`、`UICraft` 均调用 `GameObjectPoolService`；`InstancePool` 被 parity 排除 | 已完成当前收口 | 投射物池化等涉及持久化的对象另开规则 |
| 能力权限 | 用 TopDown `CharacterAbility` 的许可和阻断模型替换 2DRPG 分散的 `CanFire/Can/IsPushed` 判断 | `AbilityPermissionSettings` 进入 `ActiveAbilitySheet`，`ActiveAbilityBase.CanFire()` 统一调用，`CharacterBase.HasOtherAbilityInWeaponState()` 查询其它能力武器状态，`AbilityBase.UpdateAnimationState()` 提供动画状态更新触点 | 已完成第一段收口 | 后续具体能力只扩展同一权限配置，不在控制器或能力子类里散落重复阻断 |
| 武器执行 | 用 TopDown `Weapon/CharacterHandleWeapon/DamageOnTouch` 思路替换 2DRPG 薄攻击执行 | `WeaponExecutionRuntime`、`WeaponExecutionSettings`、`WeaponHitWindowRuntime`、`ActiveAbilityBase`、`MeleeAttackAbility` 已落地 | 已完成当前三段吸收 | 后续只补投射物池化和更完整表现，不改 RPG 伤害真相 |
| 生命/受击 | RPG stats 做数值真相，TopDown 只做无敌帧、击退和反馈表现 | `EffectImpactSettings` 传递击退/短暂无敌到 `CharacterBase.Damage`；`CharacterSheet/CharacterBase` 通过 `GameplayFeedbackSet` 触发受击/死亡反馈；未见 TopDown `Health` 直依赖 | 当前地基吸收已完成，屏幕/相机反馈未完成 | 继续补相机/屏幕反馈 |
| 反馈系统 | 只允许 GameCore 正式入口边界持有 `MMFeedbacks` | `GameplayFeedbackSet.cs` 是唯一 `MMFeedbacks` 运行时引用；命中、受击、数值恢复/消耗、持续效果、死亡、奖励掉落、拾取、交互成功/拒绝都经该入口边界触发，并已补成正式只读表现上下文；`CameraShake.cs`、`DamageScreenFlash.cs` 与 `CombatTextDisplay.cs` 已改为消费 `GameplayFeedbackSet` 广播出的正式表现上下文，而不是直接监听全局伤害、治疗、法力或持续效果通知；`SampleScene` 也已在 `Screen Space UI/Overlay` 下补入独立的 `Damage Screen Flash` 正式对象，不复用过场黑幕；插件边界门禁违规 0 | 核心触发点和核心表现上下文已接入，当前监听者仍主要是第一段相机震动、第一段屏幕闪屏和浮字入口 | 继续扩展同一入口边界，不散落字段 |
| 隐式字符串消息入口 | 把单用途 `BroadcastMessage/SendMessage` 改成显式接口合同 | `CharacterBase` 已改为只通知实现 `IActionInterruptReceiver` 的能力实例，不再广播 `OnActionInterrupted`；`CollisionDispatcher` 已改为只调用实现 `IMovableCollisionReceiver` 的组件，不再字符串分发 `OnMovableCollision`；`PlayerController` 不再用 `SendMessageUpwards("OnInteract")`，而是只通知实现 `IInteractionReceiver` 的父级组件，`Entity/IInteractionTarget` 与 `CommandTrigger` 已接入该合同；`StateMessageDispatcher` 对当前仓库实际使用的角色无敌/死亡、过场淡入淡出完成和浮字动画结束消息，现已强制命中 `ICharacterAnimationStateReceiver/ITransitionAnimationStateReceiver/IFloatingTextAnimationStateReceiver` 正式接口，缺接收者时直接视为接线错误；旧 `BroadcastMessage/SendMessage/SendMessageUpwards` 动画传播分支也已从正式运行时移除。角色、过场和浮字这 7 条已登记动画消息的 controller 资产也已统一切到 `EMessagePropagationMode.RequireExplicitReceiver` 语义，不再留着“代码走显式接口、资产还写旧传播模式”的错位；旧的 `IAnimationMessageReceiver -> Movable.DispatchAnimationMessage -> IAnimationStrategy.OnMessageReceived(...)` 兼容链已经连同废弃接口文件一起从正式运行时移除；Hero 预制体里已失效的 `m_invincibilityAnimationStartMessage/m_invincibilityAnimationStopMessage/m_deathAnimationStartMessage/m_deathAnimationStopMessage` 历史字段也已从 `0_Hero_Base.prefab` 清掉；能力菜单树内部的 `UIAbilityBarEntry/UIAbilityCategory/UIAbilityListEntry` 也已改为通过 `IAbilityMenuEventReceiver` 显式通知 `UIAbilities`，不再依赖 `SendMessageUpwards` 命中私有方法；对话 HUD 内部的 `UIDialogueMessageBox/UIDialogueOption` 也已改为通过 `IDialogueHudEventReceiver` 显式通知 `UIDialogue`，不再依赖消息框动画结束和选项点击的字符串上行消息；在这些高价值入口之外，`UIEffectListEntry -> UIEffectList`、`UIGameMenuEntry -> UIGameMenu`、`UISaveFile -> UISave/UIMainMenu`、`UIRecipeEntry -> UICraft`、`UIShopEntry -> UIShop`、`UIInventoryBagCategory/UIInventoryBagSlot/UIInventoryEquipmentSlot -> UIInventoryBag/UIInventory`，以及 `UIJournalQuestEntry -> UIJournal` 也已开始收成显式宿主调用 | 已完成当前六条高价值入口收口，并清掉已确认失效的 prefab 历史字段 | 后续若新增动画消息进入正式范围，必须先登记到 `AnimationStateMessageContracts` 并给出正式接收者，而不是再回退到字符串广播 |
| `CharacterBase/Hero` 浅 runtime 清理 vs 真容器保留 | 删除单拥有者浅 runtime，但保留真正持有状态和快照职责的内部容器 | `CharacterBase.cs`、`CharacterBase.Abilities.cs`、`CharacterBase.StateApi.cs`、`CharacterBase.Persistence.cs`、`Hero.cs`、`Monster.cs`、`CharacterBase.AbilitySetRuntime.cs`、`CharacterBase.ActionStateRuntime.cs`、`CharacterBase.TemporalEffectRuntime.cs`、`CharacterBase.AttributeBootstrapBuffer.cs` | `2026-06-17` 的 deletion test 已证明一批浅 seam 可以撤回；`2026-06-18` 又继续把属性正式读取、资源写入口、通知、死亡链和当前值存档收回 `CharacterBase`，并把能力实例投影查询、冷却快照读取和触发入口解析也收回 `CharacterBase.Abilities`。因此当前保留项里，`CharacterAbilitySetRuntime`、`CharacterActionStateRuntime` 与 `CharacterTemporalEffectRuntime` 仍分别握着能力实例仓库与 bonus ability 计数、动作锁/速度倍率表和持续效果 live 集合；而能力 runtime state 的创建/恢复编排已经进一步收回 `CharacterBase.Persistence`。文件级所有权已继续收口成 `CharacterBase` 私有 nested helper；`AttributeBootstrapBuffer` 则不再是属性与资源真相容器，只剩旧属性缓冲、旧档导入和正式镜像回填。删除它们应以“是否还能维持单一真相”判断，而不是以“主类看起来是否更薄”判断 | 已完成当前裁决澄清 | 后续若继续收 `CharacterBase/Hero`，先找新的单拥有者浅 seam；不要为了“更扁平”把真容器也并回主类，重新制造状态散乱 |
| NPC 任务提示监听 | 保留 2DRPG 的任务提示真相，但修正参考原件的监听生命周期错误 | `NPC.cs` 在 `OnDestroy()` 中已将 `questAvailabilityChanged` 从误加监听改为对称移除；`Test-FoundationReferenceParity.ps1` 已把该文件登记为最小正式补丁 | 已完成最小工程收口 | 后续若继续改 NPC，只能围绕正式任务/提示真相，不再散落额外监听 |
| 存档文件层 | `SaveSystem` 保留 RPG `SaveDataBlock`，底层文件换 YokiFrame SaveKit | `SaveSystem.cs + SaveFileStorageRuntime.cs` 这组正式存档闭包调用 `SaveKit`，并只注册 `SaveDataBlock` 模块 | 已完成当前融合 | 后续补真实场景存档 smoke |
| 输入重绑定 | `GameCore InputSystem` 保留语义，YokiFrame InputKit 只做绑定工具 | `InputSystem.cs` 调 `InputKit` 导入/导出/保存/加载/冲突查询；未接入 TopDown `InputManager`；`GameStateSystem` 已不再靠一帧延迟切 action map，而是由 `InputSystem` 用共享输入释放门禁和 UI `BaseInputModule` 启停收口共享按键串扰 | 已完成当前融合 | 点击移动前先定控制组和导航 Provider |
| 现有 UI 菜单时序 | 不迁 UIKit 的前提下，先把 `AUIMenu/UIDialogue/UIStatBar` 自身的“一帧后才正确”补丁收回显式规则 | `UIMenuManager.cs` 已改为显示菜单后立刻刷新布局并更新导航选中，不再 `ExecuteInXFrames(1)`；`UIStatBar.cs` 已改为“同一绑定目标至少显示过一次正式值后，才允许下降触发震动”；`UIDialogueMessageBox.cs` 已改为持有当前跳字协程句柄，在跳过、切句或关闭时显式终止旧协程并当场结束/中止文本动画；通用 `CoroutineHelpers` 已删除，`CommandTrigger` 的可配置帧延迟只保留为组件内部协程；`Invoke-FoundationStaticGate.ps1` 已把旧补丁和 `CoroutineHelpers` 写成禁止回归项；正式运行时搜索 `ExecuteInXFrames(` 结果为 0 | 已完成当前菜单时序收口 | 后续 UI 大迁移若开启，继续沿现有菜单运行时或正式替代入口推进，不再回加时间补丁 |
| 角色复活无敌起点 | 复活无敌只保留动画策略这一套正式真相，不再额外保留帧计数兜底 | `CharacterBase.cs` 已删除 `m_invincibilityFrames` 与复活两帧 workaround；`AAnimationStrategy.PlayInvincibleAnimation()` 现在会在请求无敌动画的同一帧立即建立无敌状态，后续仍由显式动画状态消息收回；`Invoke-FoundationStaticGate.ps1` 已把旧字段与旧注释写成禁止回归项 | 已完成当前时序收口 | 后续若要改无敌持续策略，只改动画策略或临时保护时长，不再另加第二套帧计数 |
| 事件单发射口 | 正式玩法事件只允许由 `GameRuntimeEvents` 发出，不能旁路直发 `EventKit` | `Invoke-FoundationStaticGate.ps1` 输出 `EventKitDispatchBoundaryViolationCount = 0`；`GameRuntimeEvents.cs` 是唯一 `EventKit.Type.Send(...)` 命中 | 已完成当前门禁 | 后续新增事件继续只加到 `GameRuntimeEvents`，不新增第二发射口 |
| 角色实体注册预留删除 | 不为未来多角色语义提前保留无调用者预留系统 | `2026-06-17` 已对 `CharacterRegistrySystem` 做 deletion test，并因没有任何真实调用者而整块撤回；`CharacterBase` 也已去掉注册/反注册接线，正式场景不再摆 `Character Registry System` | 已按当前目标收口 | 后续只有在控制组、世界层筛选或长期身份语义出现真实调用者后，才允许重建正式注册入口 |
| 当前前台角色回退规则 | 把“当前控制对象为空时回退谁”收回 `PlayerSystem` 正式 API，而不是让 UI/表现/交互层各写一遍 | `PlayerSystem` 已提供 `currentControlledCharacterOrPlayerInstance/currentControlledHeroOrPlayerInstance`，并补了 `currentControlledHeroChanged` 作为 Hero 专属切换事件；`InventorySystem`、`UIInventory`、`UIInventoryStats`、`UIEffectList`、`CameraShake`、`AudioRegion`、`MovementZone`、`PickableItem`、HUD 与能力/角色菜单等调用点都已改用该 API/事件；运行时代码搜索 `currentControlledHero ?? GetPlayerInstance()` 与 `currentControlledCharacter ?? GetPlayerInstance()` 结果为 0 | 已完成第二阶段收口 | 后续若控制组语义变化，只改 `PlayerSystem`，不再逐处扫回退判断 |
| UI 菜单运行时与缓存 | 以 UIKit 作为正式 UI 机制，保留 `GameCore` 菜单语义拥有权 | `UIManager` 内部菜单运行时、`UIKitMenuPanelBase` 与 `UIKitMenuPanelTypeReference` 已落地；旧 `AUIMenu/IUIMenu/UIMenuManager`、历史阶段独立菜单组件、`UIMenuRegistry`、`MenuHostRuntimeOwnershipGuard` 与 `MenuRouteTopology` 已退场；`2026-06-18` 再次通过 UIKit 非业务面板栈 smoke，正式资源链也已复核到 `MenuParts` 分层与旧菜单壳退场 | 已完成当前阶段 | 后续只在同一正式入口内扩展，不把 UIKit 变成业务真相拥有者 |
| EquipmentSystem 正式树 | 正式换装运行时不再保留 Legacy 兼容占位或空 Legacy 目录 | `Invoke-EquipmentSystemStaticGate.ps1` 输出 `LegacyRuntimeDirectoryExists = false`、`LegacyRuntimeFileCount = 0`；正式资产搜索 `EquipmentDemoExtension` 命中 0 | 已完成本轮清理 | 后续若还需要测试入口，只能以正式运行时/编辑器工具进入，不再回加同名占位组件 |
| 地图边界/出生/重生 | `MapSystem/MapInfo` 保留地图真相，吸收 TopDown Level/Checkpoint 表现配置，并把 uMMORPG 的失效保存位置回退规则作为健壮性补强融合进现有闭包 | `MapInfo` 已承载默认出生点、重生延迟、边界和相机目标，并在启用/禁用与 Start 时正式登记给 `MapSystem`；`Checkpoint` 已承载顺序/强制覆盖；无资产实例、无运行时调用的 `GameObjectCheckpoint` 已删除；`MapSystem` 已保存有序检查点状态并按地图配置延迟重生；恢复 `currentMap` 时若保存位置已失效，则回退到 `MapInfo.initialSpawnCheckpoint`；当前 `activeMapInfo` 也已从“注册 + 场景扫描补洞”收回到“注册表 + tracked scene 选择”单一入口 | 已落地基础配置、活动地图配置缓存与当前地图恢复健壮性 | 后续只在正式场景接线时补相机组件读取，不挂 TopDown `LevelManager` |
| 目录边界 | 当前地基继续以 `Assets/Scripts/GameCore/Runtime` + `Assets/Editor/GameCore` 作为正式落点；顶层 `World/Characters/Combat/...` 只在独立真相源形成后再晋升 | 目录裁决理由已回写到 `docs/ai/三方框架系统对照.md` 和 `docs/ai/项目目录与入口.md`；现态证据包括 `2DRPGEngine` 参考根、`Sync-2DRPGFoundation.ps1` 映射和当前门禁/台账执行面 | 当前执行已对齐裁决 | 后续只有在世界层或项目自有模块正式成形时才迁出 `GameCore` |
| 世界穿越目标 | 当前仍以玩家存档 Hero 为真相 | `MapSystem.TeleportTo/RespawnPlayer`、`Checkpoint` 与 `Teleporter` 已显式统一到 `PlayerSystem.GetPlayerInstance()`，不再散落依赖 `GameManager.Player` 快捷入口 | 当前边界已收口，但尚未进入控制组/多 Hero 世界穿越语义 | 等控制组和世界角色实体设计锁定后，再决定“当前控制角色是否可以成为世界穿越目标” |
| 单玩家 Hero 假设 | 输入目标从“静态玩家别名”改成“当前控制对象/控制组”与“玩家长期存档 Hero”分层 | `InputSystem` 已成为唯一 `InputAction` 订阅者；`PlayerSystem` 已持有 `currentInputTarget/currentControlledCharacter/currentControlledCharacterChanged`；`PlayerController` 已实现 `IPlayerInputTarget`；UI 交互提示、玩家触发器、区域音频、HUD 技能栏、HUD 状态条、HUD 效果栏、能力菜单、角色菜单、效果列表、`CameraShake`，以及 `PickableItem` 的“仅玩家可拾取”判定，都已开始跟随当前控制角色；同时玩家长期真相调用点也已显式收回 `PlayerSystem.GetPlayerInstance()`，当前主要包括世界穿越、任务等级校验和重生入口；命令默认目标与能力条件已继续收口到当前受控角色 / 当前受控 Hero。当前运行时代码对 `GameManager.Player` 静态别名的直接引用搜索结果为 0 | 第二阶段已完成：前台控制对象与玩家长期真相已分层，控制组与世界角色实体解耦未完成 | 点击移动/WASD/摇杆继续在同一接口上扩展；后续重点转向控制组、角色实体注册和世界层多角色语义，而不是回退到静态玩家别名 |
| 背包与角色操作边界 | 背包/货币保留全局真相，装备与可消费物品目标由父级库存上下文显式决定 | `InventorySystem` 仍保留 `items/money` 全局模型；`UIInventory` 现在从 `InventoryMenuContext` 解析 actor 和 display owner，再显式传给 `UIInventoryBag`、`UIInventoryEquipment` 与 `UIInventoryStats`；子控件不再各自回头猜当前受控 Hero 或玩家主角 | 当前边界已收口，尚未进入多 Hero 私有背包/货币模型 | 后续只有在存档、商店、掉落和任务真相明确需要时，才考虑多 Hero 私有背包 |
| 开放世界 Cell/派系/AI/经济 | 不塞进 `GameManager.*`，按具体能力落深 Module | `Invoke-FoundationStaticGate.ps1` 已禁止新增开放世界 `GameManager.XxxSystem` shortcut；尚无正式 Module | 只完成禁止扩张，未实现能力 | 进入对应玩法时逐个建规格和验收 |

## 后续专项留档

1. 反馈层：`GameplayFeedbackSet -> CameraShake/DamageScreenFlash/CombatTextDisplay` 这条正式表现链已建立；后续若继续扩展，只沿同一入口边界补更多相机或屏幕表现，不散落额外反馈入口。
2. 地图表现层：基础配置已落地；下一步只在正式场景接线时补相机/边界读取组件，不接入 TopDown `LevelManager`。
3. 控制对象层：当前控制对象接口前两阶段已完成；`PlayerController` 里也已经存在 `Directional + ClickToMove` 的第一阶段基础移动链路。`2026-06-17` 又补过一轮 `ClickMoveTest / SampleScene` 的最小 PlayMode smoke，两张正式场景都没有新的 `Error / Exception / Assert`。但 2D 移动与场景组织仍卡在 4 个一级框架缺口上：单机/本地 2D 导航 Provider、2D 点击移动执行闭包、单机/本地场景实例宿主参考、单机/本地出生点分流宿主参考。当前已经吸收进现有闭包的 `uMMORPG` 规则包括：`Movement.Reset/Warp/IsValidSpawnPoint/NearestValidDestination`、`Navigate(destination, stoppingDistance)`、`PlayerNavMeshMovement.MoveWASD()` 的手动输入取消旧路径、`Database.CharacterLoad()` 的失效保存位置回退，以及 `Portal.cs` 的父级玩家解析；同时现有 `Movable.MoveTo(...)` 已能跑通“点地后直线靠近”。但正式的完整 2D 导航 Provider 仍不存在，也没有“靠近完成后自动续接动作”框架入口，因此“超距后自动靠近再施法/交互”和“控制对象与世界穿越目标统一”都只能继续登记为二级缺口，不能绕过一级缺口先落代码。补充：本机现有参考池已复核到当前边界；工作区虽已新增 `Assets/Plugins/AStar 2D Grid Pathfinding` 本地源码，但它当前不止算法层，还带有 demo 级 world/grid 映射与路径跟随宿主，不过仍缺正式运行时状态和输入/移动闭包整合，不能直接关闭前两个一级缺口。`2DRPGEngine` 的 NodeCanvas `Pathfinding` 任务已确认只是 `NavMeshAgent` 包装，`uMMORPG PlayerCharacterControllerMovement.cs + CharacterController2k.cs` 也已判退为 `Mirror + 3D CharacterController` 玩家运动体系；后续若要补前两个一级缺口，仍需更完整的新参考或继续扩大本地候选取证。
4. 开放世界层：区域/Cell、队伍、派系、AI 日程、经济/基地生产和局部模拟都未实现；当前也没有任何真实调用者需要“live runtime 角色集合”这层真相，因此 `CharacterRegistrySystem` 已撤回，世界层身份、离线状态、区域外角色和长期队伍语义仍待后续正式规格决定。`uMMORPG Instance.cs` 只能证明“实例宿主至少要显式承载入口、归属、边界、实例内出生点和清理策略”，`PortalToInstance.cs` 只额外证明“入口脚本最多负责查找/创建实例并把玩家送到实例入口”，`NetworkManagerMMO.GetStartPositionFor(...) + NetworkStartPositionForClass.cs` 只能证明“出生点分流本身也应有正式宿主”；它们都还不能直接搬回当前单机 `MapSystem + MapInfo + Teleporter`，详见 `ummorpg-movement-scene-audit.md`；因此不能把当前 GameCore 基线说成完整开放世界地基。
5. Unity 现态验证：当前静态门禁已通过；若继续改运行时代码或场景接线，再跑 AIBridge `Invoke-FoundationBridgeSmoke.ps1`。

## 已跑静态验收

- `scripts/Invoke-FrameworkVerdictGate.ps1 -AsJson`：通过。`MissingDirectoryCount = 0`、`CompatibilityViolationCount = 0`，并已回报当前 runtime/editor/plugins 目录清单。
- `scripts/Test-FoundationReferenceParity.ps1 -AsJson`：runtime/editor 均无未登记差异。
- `scripts/Invoke-PluginFacadeBoundaryGate.ps1 -AsJson`：违规 0。
- `scripts/Invoke-FoundationStaticGate.ps1 -AsJson`：违规 0。
- `scripts/Invoke-WorkspacePreflight.ps1 -AsJson`：正式违规 0，待处理空目录 0。
- `scripts/Invoke-EquipmentSystemStaticGate.ps1 -AsJson`：旧标识 0，demo 场景缺失 0。
- `npx openspec validate define-fantasyword-foundation-framework --strict`：通过。
