extends SceneTree
const Prep = preload("res://game_core/combat/formal_hit_preparation.gd")
const Life = preload("res://game_core/combat/deferred_damage_lifecycle.gd")
const Driver = preload("res://game_core/presentation/character_action_animator_driver.gd")
const Apply = preload("res://game_core/combat/formal_damage_application.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
var checks := 0
var failures := 0
var events: Array[String] = []
var health := 20
var history := Prep.new()
var lifecycle := Life.new()
var driver := Driver.new()
var source := {"snapshot": {"physical_attack": 4, "luck": 0, "agility": 10}, "dead":false}
var owner := {"snapshot": {"physical_defense": 0, "agility": 0}, "invincible":false, "dead":false}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var actor := Node.new()
	root.add_child(actor)
	var player := AnimationPlayer.new()
	actor.add_child(player)
	actor.add_child(driver)
	driver.animator = player
	driver.set_process(false)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var lib := AnimationLibrary.new()
	for key in ["Idle", "Walk", "Dmg"]:
		var clip := Animation.new()
		clip.length = 0.5
		lib.add_animation(key, clip)
	player.add_animation_library("", lib)
	driver.action_keys = ["Idle", "Walk", "Dmg"]
	history.lifecycle = lifecycle
	history.owner_identity = owner
	history.formal_driver_assigned = true
	history.play_formal_damage = _formal
	history.play_legacy_damage = _legacy
	history.report_formal_animation_error = func(): events.append("error")
	check(_hit(source, false), "正式正伤害命中")
	check(health == 16 and events == ["formal_at_20", "delta_Dmg", "complete"], "先请求受击再改当前 HP")
	check(lifecycle.pending_interrupt and history.last_effective_source == source and driver.pending_key == "Dmg", "延迟打断、有效来源和恢复定时")
	lifecycle.tick_safe(func(): return health, func(): return false, func(): events.append("interrupt"), func(): events.append("death"))
	check(not lifecycle.pending_interrupt and events.back() == "interrupt", "行动在安全阶段才打断")
	driver.set_movement(Vector2.RIGHT)
	driver.advance_game_time(0.49)
	check(driver.current_animation_key == "Dmg", "期限内保留受击")
	driver.advance_game_time(0.02)
	check(driver.current_animation_key == "Walk" and driver.pending_key.is_empty(), "按本步移动意图恢复 Walk")
	events.clear()
	var other := source.duplicate(true)
	check(_hit(other, true) and is_same(history.last_effective_source, other), "静默伤害仍记录真实来源身份")
	check(events == ["delta_Walk", "complete"] and not lifecycle.pending_interrupt, "静默扣血不请求打断或动画")
	history.prepare(owner, {"silent":true})
	history.prepare(null, {"silent":true})
	check(is_same(history.last_effective_source, other), "自身与空来源不覆盖已有有效来源")
	events.clear()
	history.play_formal_damage = Callable()
	check(_hit(source, false) and events == ["error", "delta_Walk", "complete"], "已绑定正式驱动失效：报错且继续扣血，不调旧策略")
	events.clear()
	history.formal_driver_assigned = false
	check(_hit(source, false) and events == ["legacy", "delta_Walk", "complete"], "仅未绑定正式驱动才走旧策略")
	actor.free()
	if failures == 0:
		print("PASS 正式伤害受击动画链：%d 项" % checks)
	quit(1 if failures else 0)

func _formal() -> bool:
	check(lifecycle.pending_interrupt and history.last_effective_source != null, "先记录来源和排队打断，再请求动画")
	events.append("formal_at_%d" % health)
	return driver.try_play_damage_animation()

func _legacy() -> bool:
	events.append("legacy")
	return true

func _hit(attacker: Dictionary, silent: bool) -> bool:
	var config := {"flat_damage":0, "scale":1.0, "damage_type":Combat.DamageType.PHYSICAL,
		"critical_behavior":Combat.Resolution.NEVER, "miss_behavior":Combat.Resolution.NEVER,
		"ignore_defense":false, "silent":silent}
	var output := Combat.solve_damage_output(attacker, config, true, func(): return 50)
	return Apply.execute_damage_output(owner, output, true, func(): return 50, {
		"provoke": func(_source): pass,
		"has_formal_stats": func(): return true,
		"current_health": func(): return health,
		"prepare": history.prepare,
		"apply_current_health_delta": _apply_health,
		"complete": func(_s, _i, _before, _d): events.append("complete"),
	})

func _apply_health(delta: int, minimum: int, _maximum: Variant, _source: Variant) -> int:
	events.append("delta_" + driver.current_animation_key)
	health = maxi(health + delta, minimum)
	return health
