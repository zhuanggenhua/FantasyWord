extends SceneTree
const Life = preload("res://game_core/combat/deferred_damage_lifecycle.gd")
const Scene = preload("res://validation/scenes/charged_attack_fixture.tscn")
var checks := 0
var failures := 0
func _initialize(): call_deferred("_run")
func _run():
	var gate := Life.new()
	var trace := []
	var mock := {"health": 0, "destroyed": false}
	var step := func():
		gate.tick_safe(func():return mock.health, func():return mock.destroyed,
			func():trace.append("interrupt"),
			func():trace.append("death");mock.destroyed = true)
	gate.on_current_health_changed(0,0)
	step.call()
	_check(trace.is_empty(), "加载零或重复零不能入队")
	gate.on_prepare_damage(true)
	_check(not gate.pending_interrupt, "静默命中不请求打断")
	gate.on_prepare_damage(false)
	gate.on_current_health_changed(5,0)
	mock.health = 1
	step.call()
	_check(trace == ["interrupt"] and gate.pending_death, "更新先打断，已恢复的目标不死亡")
	mock.health = 0
	step.call()
	step.call()
	_check(trace == ["interrupt","death"], "重读死亡资格并仅执行一次")
	var f = Scene.instantiate()
	f.automatic_clock = false
	f.motion_enabled = false
	root.add_child(f)
	await physics_frame
	await physics_frame
	f.defender.health = 12 # 测试已有伤者；最大值保持原50。
	_check(f.begin_accepted_release(), "进入本次已经允许的释放")
	f.timeline.advance(0.21)
	_check(f.defender.health == 0 and f.defender.max_health == 50 and f.defender.stats.dead,
		"实际子框致命命中，当前生命立刻归零并失去成为目标的资格")
	_check(f.defender.lifecycle.pending_death and not f.defender.marked_destroyed
		and f.defender.callbacks == ["impact","provoke","prepare","complete"], "扣血/受击回调内不执行死亡")
	f.timeline.stop()
	f.begin_accepted_release()
	f.timeline.advance(0.21)
	_check(f.defender.callbacks.size() == 4 and f.defender.push_requests == 1, "延迟死亡期间不会再被结算")
	await process_frame
	await process_frame
	_check(f.defender.marked_destroyed and f.defender.lifecycle_events == ["interrupt","death"],
		"真实场景安全阶段先打断再标记死亡")
	_check(is_instance_valid(f.defender.body) and not f.defender.can_move(), "不发明立即销毁身体或掉落")
	f.queue_free()
	await process_frame
	if failures == 0: print("PASS 致命伤害延迟生命周期：%d 项" % checks)
	quit(1 if failures else 0)
func _check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; push_error(label)
