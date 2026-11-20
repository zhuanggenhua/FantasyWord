# ClickMoveTest 原手柄移动与模式切换

依据锁定 Unity `31629d53` 的 `Assets/InputSystem_Actions.inputactions`、原测试面板与角色移动。F5 仍按原面板从 ClickToMove 启动。Gameplay 的 Tab 和右摇杆按下调用同一个真实主角命令，重置旧路径与旧移动方向；它们不是两次切换。原 Button 没有进入动作图时的初始按压检查。切模式不重新启用 Gameplay，不重新读取持续未变的轴。方向模式拒绝点击寻路。

本地手柄 0 左摇杆：Godot 的屏幕轴 Y 转换到原命令正 Y 向上。Unity Input System 1.18 的控制径向死区默认 0.125–0.925，原绑定再 NormalizeVector2 与 StickDeadzone；通过归一化的摇杆按单位方向走，不套用额外的比例速度。与两个键盘组合共用一个原 Move 动作，竞争使用控制端量级而不是归一化后的命令值；没有叠加三个方向。原 Unity PlayerInput 的设备配对/自动切控制方案、平台同时轴事件的确切顺序、断线/失焦与实物手柄对照未验收。

Pause 停止现有 Move，但记录暂停期间的物理轴。与 Button 不同，原 Value Move 在动作图启用后的首个输入更新采样；源 Input System 关闭旧动作时清除按压，原游戏又在新动作刚开启时检查释放门禁，所以正常返回时按住摇杆预期在后续采样重新按当前方向移动，无需归中。动过或归中的轴按最新值；这来自 [Unity Input System 1.18 源码](https://github.com/Unity-Technologies/InputSystem/blob/1.18.0/Packages/com.unity.inputsystem/InputSystem/Actions/InputActionState.cs#L771-L861) 及其 [初始采样](https://github.com/Unity-Technologies/InputSystem/blob/1.18.0/Packages/com.unity.inputsystem/InputSystem/Actions/InputActionState.cs#L1122-L1209)，不是双引擎同机实测。

`test_source_gamepad_movement_entry.gd` 从真实 F5 入口注入 Godot 事件，点击产生原路线、切模式清路、摇杆在现有角色上实际斜走并播放 Walk、回中停止、暂停保持/转向/松手与返回，以及按住 Tab/右摇杆别名抑制重复。无私有素材运行独立动作合同，将地图、动画和暂停分支明确跳过。不涉及手柄瞄准、D-pad 菜单导航或整项目验收。
