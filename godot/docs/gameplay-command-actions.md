# Gameplay 动作回调到角色命令（可选入口）

依据 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`：
- `Assets/InputSystem_Actions.inputactions` 中 Gameplay 的 Interact 与 FireAbility1–5 为 Button，无 interactions/processors，initialStateCheck=false。
- `InputSystem.cs` 的 OnInteractPerformed、十个 FireAbility performed/canceled 回调、ExecuteLocalPlayerCommand / NotifyLocalPlayerCommandResult。
- `Commands/GameCommandContext.cs`：LocalPlayer(null) 的 issuer kind=1、issuer id=`local`。

`game_core/input/gameplay_command_actions.gd` 接收**已经由输入宿主归一化的动作阶段**，通过实际 ClickMoveTest 的 `bind_human_gameplay_actions` / `receive_human_gameplay_action` 接到既有 `submit_human_command`，不是新造技能实现。

宿主显式提供三个接口：
1. 每次尝试命令时解析当前 input target，返回 `{actor, command_context}` 或 null。上下文原样传递；null 产生 MissingInputTarget，不提交角色命令，失败记录保留 LocalPlayer(null) 的字段投影。
2. Interact 的原共享释放门禁查询。仅 performed 查询，blocked 不发命令；取消/started 不发命令。
3. 失败回调 `(request, failure)`，只在命令失败时触发一次。实际 GameRuntimeEvents / HUD 仍需正式宿主。

FireAbility1–5 performed → FireAbility，canceled → StopFireAbility，槽位 0–4，均**不查 Interact 共享门禁**。实际 entry 的玩家归属、当前受控角色、控制允许门禁保持；角色执行器仍拥有交互许可、同帧交互后禁止 Fire（不禁止 Stop）、正式技能宿主结果。关闭 human aim 时解除桥接；解除桥接本身不会伪造输入取消事件。

## 验证与未验收边界

`test_gameplay_command_actions.gd` 覆盖所有槽位、阶段、共享门禁、失败通知、缺失 input target、控制锁、同帧交互锁，并通过真实 Viewport → 测试输入宿主 → 已有键盘别名跟踪器 → 实际场景入口 → 角色执行器验证 Q/2 不早退槽位。测试宿主只是显式接口调用者，不宣称完整输入系统已接好。

没有新增自动 PlayerInput、自动动作图切换、设备配对、原始游戏手柄输入或全设备释放门禁；不根据物理按键猜测 SwitchCurrentActionMap 后动作 IsPressed。未迁移原始 Interact 键 F/Enter/Space 的动作状态机；不将 keypad Enter 擅自算作 Enter。原有 Fire 键盘别名跟踪器仅验证连续启用会话内的满值按键边沿，禁用/重启、持键跨图、焦点/设备重置、跨设备冲突仍由正式归一化输入宿主承担，不在此宣称等价。

因此这是可注入的动作回调闭环，不是整个游戏、PlayerSystem、GAS、UI 或输入系统完成验收。
