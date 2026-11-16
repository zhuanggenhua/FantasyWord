# 技能槽按住／松开诊断

启动：`godot --path godot res://validation/scenes/ability_slot_fixture.tscn`

这份诊断装备表只在槽位 2 装配 20004。使用原槽位按键 Q 或 2 按住蓄力，松开后才开始释放；不是声称原游戏有默认的蓄力按键。其余槽在诊断中无技能。不传 `--diagnose-attack` 参数，该参数为原释放诊断绕过输入的旧测试入口。

锁定 `31629d5` 的 `InputSystem_Actions.inputactions` 对槽 1 至 5 的键盘映射是 1、Q/2、E/3、C/4、R/5。Action 是普通二元 Button，按下 Performed 提交零基槽位 FireAbility，释放 Canceled 提交同槽 StopFireAbility。每条边沿都查询当前装备。对同一动作的满幅二元别名，按住任一键不取消；不添加新按键或把按住时长当成原版伤害档位。手柄、失焦、PlayerInput 生命周期及完整交互拥有者未接。

旧 Ability 20004 描述已与实际实现错位；`exgas_tbabilitygamecore` 的 InputTriggerMode=2 和原 EditMode 回归确认按住 Charging、松开才开始出手，HoldRelease 不用输入缓冲。释放重新验证资格，再接既有第 12 帧、真实子 Hitbox 和击退。停止通知终止当前诊断 Timeline；没有声明两引擎的完整逐帧调度顺序等价。原角色、属性、装备是否合法和费用/标签生命周期未接。诊断用明确可撤销布尔值验证“按下合格但松开不合格”的分支。原生键盘事件和 Godot 视口测试不替代 Unity 原版设备对照或完整游戏验收。
