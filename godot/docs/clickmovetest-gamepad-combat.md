# ClickMoveTest 原手柄技能和暂停键
原依据为锁定 Unity `31629d53` 的 `Assets/InputSystem_Actions.inputactions` 中 Gameplay/FireAbility1–5、OpenGameMenu 和 UI/Cancel。West、North、East、左肩、右肩按序对应技能槽 1–5；与原键盘别名进入同一正式技能命令和实际装备。没有另造手柄装备或诊断角色。Gameplay 的 Start 打开原 Pause，UI 的 East 返回当前菜单层；Start 不是 UI Cancel，East 不从 Gameplay 打开 Pause。

源按钮动作没有初始状态检查。打开 Pause 后将 Gameplay 已活跃的每个技能取消一次；跨图层仍记录真实物理按压和释放，避免按住 East 穿过菜单变成新技能。多种键同时驱动同槽，只在槽位从无按键到按下和最后一个已激活的按键松手时派发。UI 的 A/Submit 仍按原共享确认规则。当前只涉及已接入本地设备 0 的动作，不声明玩家配对、多手柄、摇杆移动、D-pad 菜单导航、摇杆瞄准或实物手柄对照。

`test_source_gamepad_combat_entry.gd` 从真实 F5 场景注入 Godot 本地设备事件：实测 West 普攻、North 喷火，空槽反馈、跨 Pause 的按住/释放和双层返回，以及原窗口可见文字。无私有资源时只测试按钮及边沿合同，明确跳过菜单和战斗渲染。
