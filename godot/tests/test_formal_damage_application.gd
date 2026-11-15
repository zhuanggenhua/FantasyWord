extends SceneTree
const Apply = preload("res://game_core/combat/formal_damage_application.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
var checks := 0
var failures := 0
var trace: Array = []
var health := 6
var max_health := 20
var applied := -1
var has_stats := true
var modifier_success := true
var bounds: Array = []
var draw_count := 0
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var source := {"snapshot": {"physical_attack": 5, "luck": 0, "agility": 10}, "dead": false}
	var target := {"snapshot": {"physical_defense": 0, "agility": 0}, "invincible": false, "dead": false}
	var cfg := {"flat_damage": 4, "scale": 1.0, "damage_type": Combat.DamageType.PHYSICAL,
		"critical_behavior": Combat.Resolution.NEVER, "miss_behavior": Combat.Resolution.NEVER, "ignore_defense": false, "silent": false}
	var output := Combat.solve_damage_output(source, cfg, true, _roll)
	var hooks := {"impact": _impact, "provoke": _provoke,
		"has_formal_stats": _has_formal_stats, "current_health": _current_health,
		"prepare": _prepare, "apply_current_health_delta": _apply_delta, "complete": _complete}
	_check(Apply.execute_damage_output(target, output, true, _roll, hooks, Vector2.RIGHT), "正伤害返回有命中")
	_check(trace == ["impact", "provoke", "formal", "get", "prepare", "modify", "complete"], "事件顺序")
	_check(health == 0 and max_health == 20 and applied == 6, "减当前生命且零下限、不改最大生命")
	_check(bounds == [0, null] and draw_count == 0, "仅零下限、Never 分支无随机抽样")
	trace.clear()
	target.invincible = true
	_check(not Apply.execute_damage_output(target, output, true, _roll, hooks, Vector2.RIGHT) and trace.is_empty(), "目标门禁先于所有效果")
	target.invincible = false
	output.miss_behavior = Combat.Resolution.ALWAYS
	_check(not Apply.execute_damage_output(target, output, true, _roll, hooks, Vector2.RIGHT), "闪避返回未命中")
	_check(trace == ["impact", "provoke"], "闪避仍触发影响与激怒，不扣血")
	trace.clear()
	output.miss_behavior = Combat.Resolution.NEVER
	has_stats = false
	_check(not Apply.execute_damage_output(target, output, true, _roll, hooks, Vector2.RIGHT), "缺少正式属性不能写入")
	_check(trace == ["impact", "provoke", "formal"], "缺少正式属性也保留前置影响")
	trace.clear()
	has_stats = true
	modifier_success = false
	_check(not Apply.execute_damage_output(target, output, true, _roll, hooks), "属性修改失败")
	_check(trace == ["provoke", "formal", "get", "prepare", "modify"], "无冲量则不触发影响，写入失败不完成命中")
	if failures == 0: print("PASS 正式伤害应用顺序：%d 项" % checks)
	quit(1 if failures else 0)
func _roll() -> int:
	draw_count += 1
	return 50
func _impact(_input: Dictionary, _velocity: Vector2) -> void: trace.append("impact")
func _provoke(_source: Variant) -> void: trace.append("provoke")
func _has_formal_stats() -> bool:
	trace.append("formal")
	return has_stats
func _current_health() -> int:
	trace.append("get")
	return health
func _prepare(_source: Variant, _input: Dictionary) -> void: trace.append("prepare")
func _apply_delta(delta: int, minimum: int, maximum: Variant, _source: Variant) -> Variant:
	trace.append("modify")
	bounds = [minimum, maximum]
	if not modifier_success: return null
	health = maxi(health + delta, minimum)
	return health
func _complete(_source: Variant, _input: Dictionary, _previous: int, damage: int) -> void:
	trace.append("complete")
	applied = damage
func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
