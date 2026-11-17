# UI Point 命中后的选择迁移

## 锁定依据

原项目锁定版本为 `31629d53a110dd4c87d4c85e6ad5a387fbafb931`。
对象是 `Assets/Scripts/GameCore/Runtime/Game/Systems/InputSystem.cs`
的 `Update`（680–724 行），不是 Gameplay 点击门禁 `UIPointerUtility`。

执行顺序：

1. UI 动作图 Point 必须有活动控件。
2. EventSystem 必须报告当前指针位于 UI 上。
3. 再读取 UI Point，交给宿主的原顺序射线结果。
4. 每个命中先检查最近父级 Selectable：`isActiveAndEnabled` 且
   没有目标 Graphic 或该 Graphic 的 `raycastTarget` 为真。
   原方法没有检查 `IsInteractable`。
5. 合格时仅在当前选中项不同时设置选择并返回。
6. 不合格时才检查该命中自己的 Graphic；吃射线则停止穿透。
   没有合格项时不清空旧选中项。

## 实际接入层

`game_core/ui/pointer_selection.gd` 接收显式注入的组件属性和有序实际
Control 命中，沿实际父级查找最近已登记 Selectable，并修改实际 Viewport
焦点。组件属性来自宿主，不把 Godot `mouse_filter` 当作 Unity
`raycastTarget`，不把 Godot 按钮可交互性当作原选择前置条件。

`ClickMoveTest.entry.bind_ui_pointer_selection` 是可选宿主入口：
原有 `bind_mouse_point_actions` 提供两个独立 Point；新增 pointer-over 和
raycast 回调必须显式提供。每个实际 `_process` 帧执行此链。
离开场景树解绑 UI 选择宿主；重新入树须重新绑定，不复用旧 Viewport。
失效回调报告 `missing_host`，不搜索或创造替代宿主。
不绑定时不影响原场景。原诊断面板没有据此被变成可选菜单。

属性字典由真实 Control 作为键；Selectable 使用
`selectable / active_and_enabled / target_graphic_present / target_raycast`；
命中 Graphic 使用 `graphic_present / raycast_target`。
宿主须给出真实组件的这些状态。未登记祖先不是 Selectable；遇到已登记但停用的
最近 Selectable 不继续找更远祖先。一个原生不可聚焦、隐藏或别的 Viewport 的
目标报告 `unsupported_selection`，不得跳到后面按钮冒充原始选中成功。

## 本次证据与边界

`tests/test_ui_pointer_selection.gd` 使用真实 Control 父子层级、真实 Viewport
焦点与 `Viewport.push_input`，通过 23 项：双 Point 隔离、先活动性后
pointer-over 再射线、子命中选择父级先于遮挡、无交互性门禁、
不重复选中、阻止穿透、无目标 Graphic、最近停用 Selectable、保留旧焦点、
动作图禁用/重启、零坐标、设备重置、退出与再入树、实际逐帧入口。
其中 pointer-over 期间禁用图的检查保留原读取顺序：原 ReadValue 返回
Unity 零坐标，对应 Godot 本地视口左下角，而不是再次检查活动性。

这些有序命中与元数据为宿主注入的测试夹具，**不是原菜单已迁移**；
尚未迁移的原 GraphicRaycaster 排序、CanvasGroup/遮罩、焦点通知、
触屏/手柄切图、Unity EventSystem 实际选中生命周期仍未验收。
本次也不包含素材、截图、渲染或整项迁移通过结论。
