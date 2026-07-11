# UI 菜单运行时专项矩阵

> 本文件只处理 UI 菜单运行时真相。当前已经正式迁入系统菜单分支（`Pause/Character/Abilities/Inventory/Journal/Save/Settings`）、独立顶层 `Death`，以及 `Shop/Craft` 这类上下文菜单；旧 `AUIMenu` 体系的运行时代码已退场，剩余的只是旧菜单资源清理。
> 当前还要额外锁定一件事：Yoki `UIKit` 的原生推荐用法已经明确存在，因此项目侧菜单语义只能收在一个正式拥有者里。当前这条菜单运行时入口已并回 `UIManager`，不再允许重新长出独立过渡菜单组件或任何等价第二入口。

## 当前结论

| 项 | 结论 |
| --- | --- |
| 当前正式菜单语义 | 系统菜单分支、`Death`、`Shop` 和 `Craft` 都已由 `UIManager + UIKitMenuPanelBase` 承载；旧 `UIMenuManager` 与额外挂载的独立过渡菜单组件都已退场 |
| 当前正式落点 | `Assets/Scripts/GameCore/Runtime/UI/Menus` |
| Yoki UIKit 角色 | 当前正式 UI 机制真相；原生推荐入口是 `UIKit.OpenPanel<T>() / ClosePanel<T>() / PushPanel / PopPanel`，并由 `UIRoot + UIPanel` 承担生命周期、栈、焦点和缓存 |
| `UIManager` 菜单角色 | 唯一允许的项目菜单运行时入口；只负责把 `EMenu/Shop/Craft` 请求、返回键、`GameState.Menu` 和关闭任务接到原生 `UIKit` |
| TopDown GUI 角色 | 不接入，不能成为项目 UI 生命周期 |
| 当前动作 | 运行时入口替换设计、非业务化 smoke 与序列化注册机制都已落地；`2026-06-16` 当前正式 `User Interface.prefab` 已把 `Pause/Character/Abilities/Inventory/Journal/Save/Settings/Death/Shop/Craft` 全部切到 `UIManager + UIKitMenuPanelBase`，不再跨入口嵌套，也不再额外挂独立过渡菜单组件；`UIShop/UICraft` 也已改继承 `UIKitMenuPanelBase`，正式资源链补到 `Assets/Resources/Art/UIPrefab/UIShop.prefab` 与 `UICraft.prefab`。同期 `UIRoot` 已改为复用场景 `EventSystem`，`UIKit.prefab` 不再保留第二套输入入口；`ClickMoveTest` 也已改成显式场景 `EventSystem + InputSystemUIInputModule`，避免正式验证场景再靠 fallback 临时生成输入入口。同时 `UIRoot` 的 fallback 已改成显式暴露：如果 `SampleScene` 或 `ClickMoveTest` 仍缺显式输入入口，就会创建名为 `UIKitFallbackEventSystem` 的临时对象并打错误日志，不再允许正式场景静默依赖 fallback。本轮又直接删除 `UIMenuManager/AUIMenu/IUIMenu/UIMenuStack/UIMenuNavigationUtility` 并从正式 prefab 上移除废弃入口组件，同时清空 `User Interface.prefab/Menus` 下预摆的直系菜单实例，删掉已失联的顶层旧菜单壳 `Craft Menu / Death Menu / Shop Menu`；随后继续删除 `MenuHostRuntimeOwnershipGuard`、`UIMenuRegistry`、`MenuRouteTopology` 与 `m_claim*` 序列化字段，让正式树只剩 `UIManager + UIKitMenuPanelBase` 这条菜单运行时入口，再把仍被正式 UIKit 资源链复用的共享条目 prefab 从误导性的 `Assets/Prefabs/UI/Menus` 整体重命名到 `Assets/Prefabs/UI/MenuParts`，并继续按职责拆到 `Frames / Abilities / Stats / Crafting / Inventory / Quests / Shop / StatusEffects / SystemMenu` |

## 为什么 `UIManager` 不是第二宿主

| 判断项 | 当前结论 |
| --- | --- |
| `UIKit` 还握着什么 | `UIRoot + UIPanel + static UIKit` 仍然独占 panel 生命周期、资源加载、缓存、焦点和 stack 真相；`UIManager` 自己并不 new 第二套 panel、也不维护第二个 cache |
| `UIManager` 还握着什么 | 只握项目菜单语义：`EMenu/Shop/Craft -> PanelType` 路由、返回键、`GameState.Menu`、关闭结果 `TaskCompletionSource`，以及“当前打开的是不是菜单栈里的 panel”这类项目规则 |
| 删除测试 | 删掉 `UIManager`，菜单语义会散回事件监听者、输入调用点和各个菜单 caller；删掉 `UIKit`，整个 panel 机制直接不存在。两者都在做事，但不是重复做同一件事 |
| 为什么不直接让所有调用点都 `UIKit.OpenPanel<T>()` | 因为系统菜单不是“随便开个 panel”这么简单；它还绑定 `EMenu`、返回键、`GameState.Menu` 和“等菜单关闭再继续”的项目语义。把这些语义散到调用点，会重新长成第二套弱约束菜单系统 |
| 为什么不允许再造 `UIHost/Facade/Wrapper` | 因为那会开始复制 `UIKit` 已经提供的 panel 生命周期、stack 或 cache 能力，重新制造同职责第二真相 |

## 原生用法裁决

| 场景 | 正式做法 |
| --- | --- |
| 只是 panel 机制问题，例如打开、关闭、压栈、弹栈、焦点、缓存 | 直接按 `UIPanel + UIKit.OpenPanel<T>() / PushPanel / PopPanel` 原生用法实现 |
| 需要承接项目菜单语义，例如 `EMenu`、`Shop/Craft`、返回键、`GameState.Menu`、等待菜单关闭 | 继续走唯一菜单运行时入口，由 `GameRuntimeEvents -> UIManager -> UIKit` 处理 |
| 只是某个菜单 panel 自己的显示行为，例如默认焦点、面板内返回消费、面板交互开关 | 继续留在 `UIKitMenuPanelBase` 子类里，用 `ResolveDefaultFocusTarget()`、`HandleBackRequested()`、`CanCloseFromMenuStack()` 这类面板内钩子解决，不上升成新宿主 |
| 想为了“统一一下”再造一层 `UIHost/Facade/Wrapper/Adapter` | 不允许；这是把原生 `UIKit` 再包装成第二真相 |

## 取舍

| 维度 | `AUIMenu/UIMenuManager` | Yoki `UIKit/UIPanel` | 当前判断 |
| --- | --- | --- | --- |
| 设计模式 | 旧模型把菜单语义和入口生命周期绑在同一套 `AUIMenu/UIMenuManager` 里 | 原生把面板生命周期、焦点、缓存和资源加载模型都收在 `UIRoot + UIPanel + static UIKit` | `UIKit` 赢 UI 机制；项目侧只允许额外保留一条菜单运行时入口，而不是再保留第二入口 |
| 软件工程 | 废弃入口已退场；若继续保留会重建第二套菜单生命周期 | 原生入口已经足够完整，继续加 wrapper 只会制造第二套路由/stack/cache | 不允许玩法代码散落直开系统菜单 panel 绕过菜单运行时入口；但在运行时入口内部和纯 `UIPanel` 机制内，应直接使用 `UIKit` 原生 API |
| 易用 | 旧方式对当前菜单资源熟，但可扩展性差 | 原生 API 简单直接，和插件文档一致，后续纯工具 panel 也更容易实现 | 以原生用法为默认；项目菜单语义统一由 `UIManager` 内部运行时入口出场 |

## 正式迁移条件

| 条件 | 必须证明 |
| --- | --- |
| 原生真相 | `UIKit.OpenPanel<T>() / PushPanel / PopPanel`、`UIPanel`、`UIRoot` 必须是唯一 UI 机制真相，不再额外复制 panel 生命周期、缓存或 stack |
| 入口合法性 | 项目侧额外类型必须直接服务菜单语义，例如 `EMenu`、`Shop/Craft`、返回键、`GameState.Menu`、关闭任务；答不出这一层真实语义，就不该存在 |
| 入口替换 | 同一个菜单不能同时继承 `AUIMenu` 和 `UIPanel`，也不能通过 adapter/wrapper 两边都跑 |
| 资源链 | 面板加载来源、Prefab 引用、Addressables/ResourceKey 边界必须明确；不能因为 Yoki 支持 Addressables 就默认全项目迁移 |
| 生命周期 | 打开、关闭、返回、暂停层、焦点恢复、输入锁定必须有一套入口 |
| 存档/玩法隔离 | UI 面板不能拥有背包、任务、属性、存档或牌局状态真相 |
| 验收 | 至少需要一个非业务化 UI 菜单运行时 smoke，验证打开、压栈、弹栈、焦点和缓存，而不是迁具体菜单当样板 |

## 禁止项

| 禁止项 | 理由 |
| --- | --- |
| 为了“统一入口”再造 `UIKitFacade`、第二个 `UIHost`、第二套路由注册表或第二套 panel stack | Yoki 原生入口已经完整，再包一层只会制造第二真相 |
| 新增 `AUIMenuToUIPanelAdapter`、`UIPanelWrapper`、`UIKitFacade` 等兼容层 | 规避选择宿主，会制造第二真相 |
| 在玩法代码里绕过菜单运行时入口直接打开系统菜单 panel | 会把 `EMenu`、`Shop/Craft`、`GameState.Menu`、关闭任务和返回键语义散回各处 |
| 在没有整组迁移方案时拆分 `Pause` 分支 | 会让 `Pause/Character/Abilities/Inventory/Journal/Save/Settings` 重新落回跨宿主嵌套和双真相 |
| 接入 TopDown `GUIManager` | 会引入第二 UI 生命周期和 TopDown 场景假设 |
| 把 UIKit 事件定义为玩法事件真相 | UIKit 只管 UI 机制，玩法领域事件仍归 `GameCore` |

## 后续动作

| 顺序 | 动作 |
| --- | --- |
| 1 | 保持当前门禁：玩法代码不得散落打开系统菜单 panel；系统菜单继续走唯一菜单运行时入口。纯 `UIPanel` 机制和未来非菜单 utility panel 允许直接按 `UIKit` 原生方式实现 |
| 2 | 审查 `UIManager` 内部菜单职责，只保留菜单语义入口；凡是 `UIRoot/UIKit` 原生已提供的生命周期、stack、cache、focus 能力，不再在项目层重复复制 |
| 3 | 当前现场已不存在双入口，因此 `MenuHostRuntimeOwnershipGuard`、`UIMenuRegistry`、`MenuRouteTopology`、runtime override 与 claim 字段已直接删除；后续继续保持“项目侧只剩一个菜单运行时入口” |
| 4 | 已建立并验证非业务化 UI 菜单运行时 smoke：`UIKitSmokePanelBase/Primary/Secondary`、`UIKitSmokeValidator` 和 `Resources/Art/UIPrefab/UIKitSmoke*.prefab` 已在 PlayMode 验证资源链、层级、栈、焦点和缓存 |
| 5 | 基于 smoke 通过结果，正式菜单运行时入口已并回 `UIManager`，并让它承担唯一菜单入口 |
| 6 | 已补正式序列化注册基础设施：`UIManager` 现在能在 Inspector 里登记 `EMenu -> UIKitMenuPanelBase` 类型映射，不再依赖运行时代码硬注册 |
| 7 | `Death` 已作为独立顶层菜单完成正式样板迁移，`Pause/Character/Abilities/Inventory/Journal/Save/Settings` 也已按同一菜单运行时整组切到 `UIManager` |
| 8 | 当前正式 `Menus` 节点已经不再预摆任何菜单实例，只保留 `RectTransform + CanvasGroup` 作为容器；动态加载映射收在同一个 `UIManager` 组件 |
| 9 | 下一步继续清理旧菜单资源残留：先禁止旧 `Assets/Prefabs/UI/Menus` 目录、`Craft Menu / Death Menu / Shop Menu` 这类失联顶层旧壳，以及 `MenuParts/Character / Craft / Journal / Game Menu` 这类已判退旧分组名回潮；当前共享条目 prefab 已统一落到 `Assets/Prefabs/UI/MenuParts`，并进一步拆到 `Frames / Abilities / Stats / Crafting / Inventory / Quests / Shop / StatusEffects / SystemMenu`，在正式 `Resources/Art/UIPrefab/*.prefab` 还依赖它们之前，不得误删，也不再回退 `Pause`、`Shop` 或 `Craft` 到双入口 |
