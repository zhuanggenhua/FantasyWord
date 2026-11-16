extends SceneTree
const Scene = preload("res://validation/scenes/ability_slot_fixture.tscn")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var fixture := Scene.instantiate()
	fixture.automatic_clock = false
	root.add_child(fixture)
	await physics_frame
	await physics_frame
	_key(KEY_1, true)
	_key(KEY_1, false)
	_check(not fixture.charge_gate.is_charging() and not fixture.timeline.playing, "未装配槽无施法")
	fixture.interacted_this_frame = true
	_key(KEY_Q, true)
	_key(KEY_Q, false)
	_check(not fixture.charge_gate.is_charging(), "同帧交互挡住 Fire")
	fixture.interacted_this_frame = false
	_key(KEY_Q, true)
	_check(fixture.charge_gate.is_charging(), "实际 viewport 槽位按下进入 Charging")
	fixture.charge_gate.advance(1.0)
	fixture.timeline.advance(1.0)
	_check(fixture.charge_gate.is_charging() and fixture.defender.health == 50 and not fixture.timeline.playing,
		"按住超过原命中窗口也不开始 Timeline、不扣血")
	_key(KEY_2, true)
	_key(KEY_Q, false)
	_check(fixture.charge_gate.is_charging() and not fixture.timeline.playing, "别名键还在按住，未发送 StopFire")
	fixture.ability_eligible = false
	_key(KEY_2, false)
	_check(not fixture.timeline.playing and fixture.defender.health == 50, "松开重新校验已撤销资格，不发招")
	fixture.charge_gate.advance(0.1)
	fixture.ability_eligible = true
	_key(KEY_2, true)
	_check(fixture.charge_gate.is_charging(), "恢复资格后第二次蓄力")
	fixture.equipped_slots.erase(1)
	_key(KEY_2, false)
	_check(not fixture.timeline.playing and fixture.charge_gate.is_charging(), "松开重新查当前槽，不向旧技能派发")
	# 正式装备重绑定所拥有的清理未移植，诊断显式中断旧持有者。
	fixture.charge_gate.interrupt()
	fixture.charge_gate.advance(0.1)
	fixture.equipped_slots[1] = 20004
	_key(KEY_2, true)
	_key(KEY_2, false)
	_check(fixture.timeline.playing and fixture.defender.health == 50, "两条边沿经过槽位后才启动释放")
	fixture.timeline.advance(0.19)
	_check(fixture.defender.health == 50, "释放后第 12 帧前不扣血")
	fixture.timeline.advance(0.02)
	_check(fixture.defender.health == 29 and fixture.defender.max_health == 50 and fixture.defender.body.is_pushed(),
		"真命中、HP 50→29、最大值不变、原生推力")
	fixture.charge_gate.interrupt()
	_check(not fixture.timeline.playing, "Gate 的停止通知终止当前 Timeline")
	fixture.queue_free()
	await process_frame
	if failures == 0: print("PASS 技能槽蓄力交互：%d 项" % checks)
	quit(1 if failures else 0)
func _key(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = down
	root.push_input(event, true)
func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
