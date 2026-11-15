extends SceneTree
const Scene = preload("res://validation/scenes/basic_attack_fixture.tscn")
const Query = preload("res://game_core/combat/polygon_hitbox_query.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
func _run() -> void:
	var fixture := Scene.instantiate()
	fixture.automatic_clock = false
	root.add_child(fixture)
	await process_frame
	await physics_frame
	fixture.defender.add_hitbox()
	await physics_frame
	_check(fixture.begin_accepted_attack(), "允许后的技能开始")
	_check(not fixture.begin_accepted_attack(), "活动期间不重复激活诊断")
	fixture.timeline.advance(0.1)
	_check(fixture.defender.health == 40 and fixture.hit_count == 0, "第 8 帧前不造成伤害")
	fixture.timeline.advance(0.04)
	_check(fixture.defender.health == 27, "真实子 Hitbox 命中，14 经防御2结算为13，仅扣一次")
	_check(fixture.defender.max_health == 40, "当前生命变化而最大生命不变")
	_check(fixture.attacker.health == 30 and fixture.outside.health == 40, "排除施法者与范围外目标")
	_check(fixture.defender.callbacks == ["impact_disabled","provoke","prepare","complete"], "源冲击禁推、挑衅、准备、扣血、完成顺序")
	_check(not fixture.defender.body.is_pushed(), "原 effect2003禁推，不因有伤害开始击退")
	fixture.timeline.advance(0.04)
	_check(fixture.defender.health == 27 and fixture.hit_count == 1, "命中任务不每帧重复")
	fixture.timeline.advance(0.4)
	_check(not fixture.timeline.playing, "30帧生命周期结束")
	fixture.defender.facing = Vector2.RIGHT
	_check(fixture.begin_accepted_attack(), "结束后重新激活")
	fixture.timeline.advance(0.14)
	_check(fixture.defender.health == 12, "背刺额外3经防御2结算为2，基础13加2")
	_check(fixture.defender.max_health == 40 and not fixture.defender.body.is_pushed(), "背刺同样不改最大生命也不击退")
	fixture.timeline.stop()
	fixture.defender.position = Vector2(-0.15,-0.65)
	fixture.defender.facing = Vector2(0,-1)
	await physics_frame
	fixture.begin_accepted_attack()
	fixture.timeline.advance(0.10)
	fixture.attacker.facing = Vector2(0,1)
	fixture.timeline.advance(0.04)
	_check(fixture.defender.health < 12, "命中帧读取当前朝向，不缓存起手朝向")
	fixture.timeline.stop()
	fixture.begin_accepted_attack()
	fixture.timeline.advance(0.05)
	fixture.timeline.stop()
	var prior: int = fixture.hit_count
	fixture.timeline.advance(1.0)
	_check(fixture.hit_count == prior, "命中前中断不再执行伤害")
	var targets := Query.query(fixture.get_world_2d(), Vector2.ZERO, Vector2.ZERO,
		PackedVector2Array(fixture.POINTS),128,fixture.attacker,func(c): return c.get_meta("actor",null))
	_check(targets.is_empty(), "无有效当前朝向不得退回 Transform 朝向")
	fixture.queue_free()
	await process_frame
	if failures == 0: print("PASS 普通攻击真实子命中体诊断：%d 项" % checks)
	quit(1 if failures else 0)
