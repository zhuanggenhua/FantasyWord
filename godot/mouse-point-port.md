# 鼠标 Point 动作生命周期切片

## 真相来源与范围

锁定 Unity 提交 `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的 `Assets/InputSystem_Actions.inputactions`、`Assets/Scripts/GameCore/Runtime/Game/Systems/InputSystem.cs`；依赖语义核对 Unity InputSystem 1.18.0 官方提交 `c0d61169c3ccce912ce6a8dec13a30e6e35fdeb8`。

Gameplay 和 UI 的 Point 是两个独立的 PassThrough Vector2 动作，只有 `<Mouse>/position` 绑定，无处理器、交互及初始状态检查。原项目以 activeControl 判定活动，再读值。官方 `InputActionState.ChangePhaseOfAction` 的无交互 PassThrough 分支保持 Performed，不能依据 `ProcessDefaultInteraction` 的旧注释误写成每帧失活。Disable 和设备重置清掉活动控件。`PlayerInput.SwitchCurrentActionMap` 调用 currentActionMap setter，旧图 Disable 再新图 Enable，即便选择同一个图也重置。

## 已接入

`game_core/input/mouse_point_actions.gd` 只持有两个 Point 状态。调用者传入已确认的 Godot 鼠标设备 ID，显式调用 `enable` / `disable`，设备重置时调用 `reset_device`。单纯再次 Enable 不清状态；同图切换须先 Disable。两图可由宿主独立启用，本类不猜测哪个图应当活动。

实际 `ClickMoveTest.entry` 提供可选 `bind_mouse_point_actions`，在 `_input` 观察 Viewport 事件。绑定后，空闲瞄准读取此 Gameplay Point；未绑定时保留既有显式宿主接口。按钮路径、UI 点击门禁及移动命令不变；不依据点击位置、全局鼠标读取或暂停状态伪造 Point。

位置变化后，静止帧与有效零坐标保留活动状态；未启用动作不捕获值。非配对设备、模拟触屏的负设备 ID、鼠标按钮、非有限坐标不激活动作。仍观察禁用期间的配对鼠标位置，以免重新 Enable 后将相同坐标当作新变化。

## Godot 适配边界与未验收

首次尚无位置历史时，仅非零 relative 的鼠标运动事件证明发生变化；首个 relative=0 事件只建立基线，不假定鼠标原来位于原点。已有历史时以绝对坐标差异判断，因此忽略纯相对量变化，也支持 relative=0 的实际位置变化。此规则是缺少 Unity 设备状态事件时的明确保守适配，尚未验收原生鼠标 warp、设备重新配对与原生平台事件完整对等。

不提供 PlayerInput、设备自动切换、键鼠方案仲裁、触屏/手柄 Point、GameState 动作图切换、UI 选中项逻辑或整个项目验收。宿主必须负责这些生命周期；暂停不自动等于禁用输入。设备更换应创建与新设备对应的新实例并显式绑定，不能借旧值跨设备继承。

## 验证入口

`tests/test_mouse_point_actions.gd` 经真实 Viewport.push_input 进入实际 ClickMoveTest 场景，挂接 Human 逻辑/表现/瞄准，验证 21 项，包括空闲瞄准实际使用新样本、无初始检查、静止持有、零坐标、两图隔离、同图禁用重启、设备重置、点击不激活、非配对设备和模拟触屏拒绝。默认图片为自建夹具；通过 `FORMAL_HUMAN_PRIVATE` 可选择外部私有的锁定原规则和 Human 图集，两种输入各通过 21 项。这不是原生渲染截图或视觉一比一验收。
