extends SceneTree
const Default = preload("res://game_core/ai/default_target_steering.gd")
const Transit = preload("res://game_core/ai/transit_steering.gd")
const Predictive = preload("res://game_core/ai/predictive_target_steering.gd")
var checks := 0
var failures := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _initialize() -> void:
	var frame := {"position":Vector2(1,2),"target":Vector2(2.25,2),
		"target_velocity":Vector2(0,6),"arrival_stop_radius":1.0}
	var initial := frame.duplicate(true)
	var result := Default.solve(frame, 4.0)
	check(result.direction.distance_to(Vector2.RIGHT) < .00001, "默认组按当前目标向右")
	check(absf(result.preferred_velocity.length()-2.0) < .00001, "1.25 距离处，4×.5=2")
	check(result.seek == Transit.solve(frame).seek, "当前目标的 16 个 Seek 采样与 Transit 共享")
	check(result.direction.distance_to(Predictive.solve(frame).direction) > .5, "默认组不得借用追击预测")
	check(frame == initial and result.has("seek") and not result.has("pursuit"), "组语义及输入不被替换")
	frame.target = Vector2(2,2)
	var stopped := Default.solve(frame,4.0)
	check(stopped.preferred_velocity == Vector2.ZERO and stopped.strength > 0, "边界停速不清除方向分数")
	frame.target = Vector2(2.5,2)
	check(Default.solve(frame,4.0).speed_scale == 1.0, "慢速半径上沿恢复全速")
	var constrained := {"target":Vector2(.8,0),"obstacles":[{"point":Vector2(.5,0),"radius":0.0}],
		"neighbours":[{"position":Vector2(.6,.2),"radius":.35}]}
	var with_constraints := Default.solve(constrained)
	var transit := Transit.solve(constrained)
	check(with_constraints.combined == transit.combined and with_constraints.constraint == transit.constraint, "到达限速不改障碍、分离及侧步合成")
	check(absf(with_constraints.speed_scale-.5) < .00001, "未覆盖时使用 .1/1.5 源参数")
	check(with_constraints.preferred_velocity.distance_to(transit.preferred_velocity*.5) < .00001, "限速作用在合成后的速度")
	var no_target := Default.solve({"arrival_stop_radius":1.0,"neighbours":[{"position":Vector2.ZERO,"radius":.35}]})
	check(no_target.speed_scale == 1.0 and no_target.direction.distance_to(Vector2.LEFT) < .00001, "无目标仅不施加到达限制，保留分离")
	check(Default.solve({}).preferred_velocity == Vector2.ZERO, "空输入不产生移动")
	if failures == 0: print("PASS Default steering: %d checks" % checks)
	quit(1 if failures else 0)
