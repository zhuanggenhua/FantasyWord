extends SceneTree
const Scene = preload("res://validation/scenes/movement_combat_fixture.tscn")
var checks := 0
var failures := 0
func _initialize(): call_deferred("_run")
func check(ok: bool, why: String):
	checks += 1
	if not ok: failures += 1; push_error(why)
func key(code: Key, down: bool):
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = down
	root.push_input(e,true)
func _run():
	var f = Scene.instantiate()
	f.automatic_clock = false
	root.add_child(f)
	await process_frame
	await physics_frame
	await physics_frame
	check(f.attacker.source_position().x == -2,"明确隔离起点")
	key(KEY_Q,true)
	key(KEY_Q,false)
	f.timeline.advance(0.21)
	check(f.defender.health == 50,"远处释放不能命中")
	f.charge_gate.interrupt()
	f.charge_gate.advance(0)
	key(KEY_TAB,true)
	key(KEY_TAB,false)
	key(KEY_D,true)
	var ticks := 0
	while f.attacker.source_position().x < -0.15 and ticks < 100:
		await physics_frame
		ticks += 1
	key(KEY_D,false)
	for i in range(15): await physics_frame
	check(f.attacker.source_position().x > -0.15,"viewport移动命令经过真实物理身体")
	check(f.attacker.facing == Vector2.RIGHT,"移动意图更新源MovementBased朝向")
	check(f.attacker.body.get_child(1).global_position.distance_to(f.attacker.body.global_position)<0.0001,"攻击者hitbox随移动身体")
	check(f.camera.follow == f.attacker.body and f.camera.global_position.x > -2,"源Follow镜头跟随")
	key(KEY_2,true)
	var charging_start = f.attacker.source_position()
	key(KEY_D,true)
	for i in range(4): await physics_frame
	check(f.attacker.source_position().x > charging_start.x,"蓄力尚未激活Event.Attacking，仍能移动")
	key(KEY_D,false)
	check(f.charge_gate.is_charging() and not f.timeline.playing and f.defender.health == 50,"入范围后按住不伤害")
	key(KEY_2,false)
	check(f.timeline.playing,"松手通过槽位与独立资格后启动")
	key(KEY_D,true)
	for i in range(2): await physics_frame
	var locked_position = f.attacker.source_position()
	for i in range(5): await physics_frame
	check(f.attacker.source_position().distance_to(locked_position)<0.0001,"释放Event.Attacking切片锁移动")
	key(KEY_D,false)
	f.timeline.advance(0.19)
	check(f.defender.health == 50,"原命中帧前无伤害")
	f.timeline.advance(0.02)
	check(f.defender.health == 29 and f.defender.max_health == 50,"移动后命中按源数值扣21")
	check(f.defender.push_requests == 1,"源默认冲击一次")
	var before = f.defender.source_position()
	for i in range(5): await physics_frame
	check(f.defender.source_position().distance_to(before)>0.1,"目标真实物理击退")
	f.queue_free()
	await process_frame
	if failures == 0: print("PASS 移动入范围→蓄力→真实命中击退：%d 项" % checks)
	quit(1 if failures else 0)
