# 移动与战斗联合诊断

运行：`godot --path godot res://validation/scenes/movement_combat_fixture.tscn`。默认原移动面板 ClickToMove；
先 Tab 切为方向模式，再 WASD/方向键移动。槽位 1 显式装配普攻 20001，按住 1 直到命中；
槽位 2 显式装配 20004，Q 或 2 按住蓄力、松开释放。未加载原地图，所以点击不启用。
显示原始HP与简单规则几何，不是正式可玩回合、原角色美术或默认装备存档。

基线368835e；Unity锁定31629d53a110dd4c87d4c85e6ad5a387fbafb931。
组合已有native_motion_body、keyboard_movement_input、movement_commands、
character_movement、world_space_camera_follow及ability_slot_fixture。

源0_CharacterActor_Base.prefab:754的朝向策略0即MovementBased；
Movable.MotionRuntime:530–539按移动意图、阈值.05更新朝向；
命中Box读取命中帧的真实朝向与body位置，不自动指向对手。
不配置target override；未移植鼠标瞄准或目标选择。
原技能槽输入不附带方向，释放前再次校验，延续现有HoldRelease诊断。

Ability20004的ActivationOwnedTags含3003 Event.Attacking；
CharacterBase.StateApi锁移动/技能/目标方向。这里仅以timeline.playing映射
该次释放的移动/再次激活门禁，不宣称完整GAS标签状态机迁移。
仅Charging尚未激活formal lifecycle，因此不锁移动。

明确隔离参数：攻击者起点(-2,0)用于先移动入范围；速度4来自基础预制体，
身体沿用原EditMode矩形测试角色，不声称生产角色胶囊或原关卡出生点。
目标(.75,.2)HP50/防御2沿用原charged测试，伤害21与默认物理击退沿用源效果。
镜头复用原Follow参数与正交半高5，不声称完整Brain更新仲裁。

集成测试通过真实Viewport键盘事件移动入范围，按住不出手、松开Timeline，
第12帧HP50→29，目标真实物理位移；验证移动更新facing/Hitbox/镜头跟随，
以及 Charging 可移动、释放期间锁移动。普攻命中与门控见 [普攻整合范围](../../unified-basic-port.md)。未引入新的玩法设计。
