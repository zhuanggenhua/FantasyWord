# UI 菜单运行时替换设计

> 范围：本设计只处理 `AUIMenu/UIMenuManager/IUIMenu` 到 Yoki `UIKit` 的菜单运行时替换。当前系统菜单分支、`Death`、`Shop` 与 `Craft` 都已切到 `UIManager + UIKitMenuPanelBase`；后续只继续做废弃入口退场后的资源与共享构件收口，不夹带额外业务扩写。
> 说明：本文若提到历史独立菜单组件，只是在追溯迁移阶段，不代表当前 prefab 或运行时代码里还保留第二套菜单入口；当前实际正式落点已经并回 `UIManager`。
> 目标：把当前正式菜单语义收口到一套 `UIManager + UIKitMenuPanelBase + UIKit` 菜单运行时闭包里，不保留双栈，不引入 adapter/wrapper。

## 1. 当前正式语义

当前 `AUIMenu` 体系里，真正需要保留到新运行时的不是“继承关系”，而是这些语义：

| 当前语义 | 当前来源 | 是否保留 | 新正式落点 |
| --- | --- | --- | --- |
| 菜单请求入口 | `GameRuntimeEvents.RequestMenu/RequestShop/RequestCraft/RequestCloseAllMenus` | 保留 | `GameCore` 继续拥有 |
| 菜单栈顺序 | `UIMenuStack` | 保留语义，不保留独立实现 | UIKit 原生 stack + `UIManager` 内部菜单运行时继续拥有 |
| 菜单注册表 | `UIMenuRegistry` | 不保留独立实现 | `UIManager` 序列化声明 + 运行时内查找表继续拥有 |
| 取消键总入口 | `UIMenuManager.OnCancel()` + `InputActionReleaseGate` | 保留 | `GameCore` 菜单运行时协调器继续拥有 |
| `GameState.Menu` 层增减 | `UIMenuManager.PushMenu/Hide` | 保留 | `GameCore` 菜单运行时协调器继续拥有 |
| 焦点刷新与首个可选控件选择 | `UIMenuNavigationUtility` | 保留，但实现切到 UIKit 焦点系统 | UIKit 面板基类 + 菜单运行时协调器 |
| `OnCancel()` 局部截断 | `AUIMenu.OnCancel()` | 保留 | UIKit 面板基类 |
| `CanPop()` 不可返回策略 | `AUIMenu.CanPop()` | 保留 | UIKit 面板基类 |
| `OnMenuPushed/OnMenuPopped` 局部副作用 | 例如 `UIGameMenu` 播暂停/恢复音 | 保留 | UIKit 面板基类生命周期钩子 |
| `Show/Hide` 激活对象 | `AUIMenu.Show/Hide` | 不保留旧实现 | UIKit 面板生命周期接管 |
| `EnableInteractions()` 只切 `CanvasGroup.interactable` | `AUIMenu.EnableInteractions()` | 保留语义，不保留废弃入口 | UIKit 面板基类 |
| `FindSomethingToSelect()` | 各菜单子类 | 保留 | UIKit 面板基类默认焦点解析 |
| 关闭菜单时清空物品详情 | `UIMenuManager.Hide -> NotifyItemDetailsClosed()` | 保留 | 新运行时协调器继续拥有 |

结论：

- `GameRuntimeEvents` 的请求事件仍然是正式入口，不迁到 UIKit 插件本体。
- 栈、取消键、`GameState.Menu`、详情面板清理这些“玩法菜单语义”仍归 `GameCore`。
- 显示/隐藏、焦点、缓存、层级这些“UI 机制”改由 UIKit 接管。

## 2. 当前类型里哪些要退场

### 替换完成后已退场

- `UIMenuManager`
- `IUIMenu`
- `AUIMenu`
- `UIMenuNavigationUtility` 里基于 `EventSystem.SetSelectedGameObject(...)` 的废弃入口实现
- `UIMenuManager` 中依赖 `menu.Show()/menu.Hide()` 的旧调用面

### 替换完成后继续保留

- `GameRuntimeEvents.RequestMenu/RequestShop/RequestCraft/RequestCloseAllMenus`
- UIKit 原生 stack

原因：

- 菜单栈和菜单查找的语义仍然要保留，但正式实现已经直接收回 `UIKit` 原生 stack 与 `UIManager` 内部序列化声明，不再保留独立 `UIMenuStack/UIMenuRegistry` 类型。
- 真正要退场的是 `AUIMenu` 那套“MonoBehaviour 自己开关 active + 事件系统自己选焦点”的废弃入口机制；这一步当前已经完成。

## 3. 新运行时闭包

当前正式替换完成后，目录落点是：

- `Assets/Scripts/GameCore/Runtime/UI/`

当前正式类型是：

| 类型 | 作用 |
| --- | --- |
| `UIManager` 内部菜单运行时 | 当前唯一菜单协调器，继续拥有请求入口、栈、取消键、`GameState.Menu` 和详情关闭 |
| `UIKitMenuPanelBase` | 当前项目侧正式菜单面板基类，继承 `UIPanel`，承接 `AUIMenu` 被保留的菜单语义 |
| `UIKitMenuRegistration` | 当前 `UIManager` 内部使用的菜单声明结构，配合序列化字段重建正式查找表 |

这里的 `UIKitMenuPanelBase` 不是 adapter：

- 它不会同时实现 `IUIMenu`。
- 它不会包装一个 `AUIMenu` 实例。
- 它是迁移完成后的唯一正式菜单面板基类。

## 4. 语义映射

### `AUIMenu` 到 `UIKitMenuPanelBase`

| 旧语义 | 新语义 |
| --- | --- |
| `OnInit()` | `OnPanelInit()`，只执行一次 |
| `OnMenuShown(args)` | `OnPanelShown(context)` |
| `OnMenuHidden()` | `OnPanelHidden()` |
| `OnMenuPushed()` | `OnPushedToMenuStack()` |
| `OnMenuPopped()` | `OnPoppedFromMenuStack()` |
| `OnCancel()` | `HandleBackRequested()`，返回是否已消费 |
| `CanPop()` | `CanCloseFromMenuStack()` |
| `FindSomethingToSelect()` | `ResolveDefaultFocusTarget()` |
| `EnableInteractions(bool)` | `SetPanelInteractions(bool)`，默认继续切 `CanvasGroup` |

### `UIMenuManager` 到 `UIManager` 内部菜单运行时

`UIManager` 内部菜单运行时必须继续承担：

- 监听 `MenuRequestedEvent/ShopRequestedEvent/CraftRequestedEvent/CloseAllMenusRequestedEvent`
- 监听 UI `Cancel`
- 管理 `InputActionReleaseGate`
- 管理 `UIMenuStack`
- 在打开首个菜单时加 `GameState.Menu`
- 在全部菜单关闭后移除 `GameState.Menu`
- 在任意菜单关闭时调用 `GameRuntimeEvents.NotifyItemDetailsClosed()`

`UIManager` 内部菜单运行时不再承担：

- 直接 `menu.Show()/menu.Hide()`
- 直接 `gameObject.SetActive(true/false)`
- 直接使用 `EventSystem.SetSelectedGameObject(...)` 作为正式焦点系统

## 5. 必须保留的菜单级特殊规则

这些不是业务内容，而是当前菜单运行时合同的一部分，新运行时不能丢：

| 代表菜单 | 必须保留的合同 |
| --- | --- |
| `UIGameMenu` | 打开时播放暂停音，关闭时播放恢复音；显示时隐藏 `m_disableWhileOpened`；关闭时恢复；继续显示 `UIEffectList` |
| `UIAbilities` | `OnCancel()` 在装备模式下必须先退出装备模式，而不是直接关菜单 |
| `UIDeath` | `CanPop() == false`；死亡菜单不能被通用返回键直接弹掉 |
| `UIInventory` | 继续在显示时更新背包/装备/属性；继续根据包裹或装备区决定默认焦点 |

这些规则应该迁移到具体 UIKit 面板子类里，不能偷懒回收到全局运行时协调器。

## 6. 不允许的方案

- 同一个具体菜单同时保留 `AUIMenu` 和 `UIPanel`
- `AUIMenuToUIPanelAdapter`
- `UIPanelWrapper`
- 先把某个业务菜单双栈跑起来，再说以后统一
- 把 `GameRuntimeEvents.RequestMenu(...)` 改成直接调 UIKit 插件全局 API
- 为了图快，让 UIKit 直接拥有背包、任务、属性、商店或死亡流程真相

## 7. 实施顺序

### Phase 1：运行时骨架

- 新增 `UIKitMenuPanelBase`
- 新增 `UIManager` 内部菜单运行时
- 保持 `GameRuntimeEvents.RequestMenu/RequestShop/RequestCraft/RequestCloseAllMenus` 不变
- 先让 UIKit 菜单运行时能跑空面板和 smoke 面板
- 历史阶段曾短暂并行过废弃入口与一层独立过渡菜单组件
- 该并行阶段现在已明确失效，不得恢复成“先双入口再慢慢收口”；当前正式入口只剩并回 `UIManager` 的这一条
- 正式菜单到 UIKit 面板的未来映射，不再靠运行时代码硬注册；应通过可序列化的面板类型引用和 Inspector 注册表登记

### Phase 2：运行时切换

- 让 `UIManager` 内部菜单运行时取代 `UIMenuManager` 成为正式入口
- 项目侧不再保留独立 `UIMenuStack/UIMenuRegistry`；菜单栈和菜单声明直接收回 `UIKit` 原生 stack 与 `UIManager`
- 旧 `UIMenuManager` 从正式场景退场

`2026-06-16` 当前这一步已完成：项目侧已不再保留独立 `UIMenuRegistry/UIMenuStack`。当前正式路由已经切成：

- `UIManager` 正式声明并接管 `Pause/Character/Abilities/Inventory/Journal/Save/Settings/Death/Shop/Craft`
- `UIManager` 内部直接用 `m_registeredMenuPanels + m_shopPanel + m_craftPanel` 重建正式查找表
- 正式 prefab 与运行时代码都不再保留第二个菜单入口

这样系统菜单与上下文菜单都不再拆给两个入口，也不需要再让 `UIManager` 旁边偷偷维护第二套 `Dictionary<EMenu, ...>` 真相。

### Phase 3：菜单基类替换

- 逐个把正式菜单从 `AUIMenu` 换到 `UIKitMenuPanelBase`
- 每迁完一类菜单，就删除对应 `AUIMenu` 依赖，不保留双轨

`2026-06-16` 当前已完成系统菜单分支、`Death`、`Shop` 与 `Craft` 的基类和运行时切换：`UIGameMenu`、`UICharacter`、`UIAbilities`、`UIInventory`、`UIJournal`、`UISave`、`UISettings`、`UIDeath`、`UIShop`、`UICraft` 都已进入 `UIManager` 内部菜单运行时正式链路，正式资源链也已收口到 `Assets/Resources/Art/UIPrefab/*.prefab`。

### Phase 4：旧类型退场

- 删除 `UIMenuManager`
- 删除 `IUIMenu`
- 删除 `AUIMenu`
- 删除旧 `UIMenuNavigationUtility` 的旧焦点实现

`2026-06-16` 当前这一步也已完成：废弃入口代码已经从正式树移除，后续不再回到“双入口并行”阶段。

## 8. 验收

切换到正式菜单运行时替换阶段后，至少要补这几类证据：

- `UIKitSmokeValidator.Run()` 继续保持通过
- `GameRuntimeEvents.RequestMenu(...)` 仍能打开正确面板
- `Cancel` 键在可弹菜单、不可弹菜单和局部消费菜单上行为正确
- `GameState.Menu` 层增减仍正确
- 关闭菜单时 `NotifyItemDetailsClosed()` 仍只走一条正式路径

## 9. 当前可直接开工的第一刀

当前这条设计线已经进入“废弃入口退场后的收口阶段”，下一步不再是改正式入口，而是补齐剩余收口：

1. `UIManager` 已真实承接正式 `User Interface.prefab` 上的菜单序列化声明
2. `UIManager` 内部菜单运行时已收回为唯一菜单入口，不再需要额外所有权守卫或独立注册表
3. `Pause/Character/Abilities/Inventory/Journal/Save/Settings/Death` 已切到 `UIManager`
4. 旧 `UIMenuManager/AUIMenu/IUIMenu` 闭包已退出正式树，`Shop/Craft` 与 `IUIMenu/AUIMenu/UIMenuNavigationUtility` 遗留依赖也已清掉

下一步不再是“证明 UIKit 能不能进正式入口”，而是继续清理旧菜单资源残留、共享构件目录命名和运行侧 smoke 证据，不允许再回长出第二宿主、第二注册表或第二套路由。
