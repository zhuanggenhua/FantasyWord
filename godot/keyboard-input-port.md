# 有序键盘移动子集

## 四项前提与职责

- 对象：`game_core/movement/keyboard_movement_input.gd`，只解析 Gameplay/Move 的两个键盘组合，再调用既有 `movement_commands`；不接管角色或场景生命周期。
- 来源：锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的 `Assets/InputSystem_Actions.inputactions`（Move/Value、独立 WASD 与 Arrow Keys、默认 2DVector）和 `Assets/Scripts/GameCore/Runtime/Game/Systems/InputSystem.cs` 的 `OnMovePerformed` / `OnMoveCanceled`。等强保留当前组按已核对的 Input System 1.18.0 `InputActionState.IsConflictingInput` 行为处理。
- 入口：Godot 4.7.2 的 `InputEventKey` 经 `handle_key(event, blocked, submit)` 输入。调用方按设备实际交付顺序提交物理按键事件；`blocked` 沿用已解析门禁，`submit` 沿用现有命令入口。单个实例持有一次键盘输入会话的按住状态。
- 验收：`tests/test_keyboard_movement.gd` 构造真实 Godot 键事件并验证命令输出，23 项；没有使用 Unity 原生运行态或 OS 注入，不能声称硬件或场景验收。

## 已实现

WASD 与方向键分别组内反向抵消、非零归一化；跨组不合并，等强保持现有驱动组。当前组归零时转交仍按住的另一组，只在所有组归零时提交 StopMove。被门禁阻挡时设备状态仍更新，performed 不发 Move，但 canceled 仍提交 StopMove。物理键使用 `physical_keycode`，不以逻辑字符代替；重复状态、自动重复及无关键不产生新命令。

命令方向保留 Unity 上为正 Y，不在此层擅自翻转为 Godot 世界坐标。角色控制、移动模式和角色状态门禁继续由既有命令/角色层负责。

## 未验收与明确排除

- 同值换组（如 A 转 LeftArrow）的回调次数未完成 Unity 原生对照；测试只验证方向连续及最后停止，不断言回调数量。
- 同时按键的 OS 交付顺序、平台键盘布局和自动重复原生语义尚未对照；只覆盖有序状态样本。
- 不实现摇杆、控制方案自动切换、重绑、动作图切换、开启动作时已按住的 initialStateCheck、失焦/禁用时释放、InputSystem 全生命周期。
- 已在[独立移动诊断场景](validation/scenes/README.md)接入 `_input`，通过同一场景的原生身体联测。尚无正式可试玩场景，没有美术或截图验收。此模块不是完整 PlayerInput 的替代实现；未来正式接入必须补齐上述实际入口合同，不能凭此宣称输入完整迁移。

新增运行时代码是设备状态到既有命令的唯一解析 owner；新增测试只持有验证样本，不作为运行时备用入口。没有修改作者源 Unity 配置、现有角色移动或命令规则。
