extends SceneTree
const Policy = preload("res://game_core/combat/damage_push_policy.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
var checks := 0
var failures := 0
var receipt: Array = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var config := {"regular":true, "critical":true, "missed":true, "silent":false}
	var hit := {"flags":0, "silent":false, "damage":0}
	_check(Policy.try_push(hit, false, Vector2(3,4), Policy.Mode.DEFAULT, config, _request), "常规零伤害不禁止推力")
	_check(receipt == [Vector2(0.6,0.8),5.0,10.0], "方向归一化，默认申请不覆盖 5/10")
	receipt.clear()
	_check(not Policy.try_push(hit, false, Vector2.RIGHT, Policy.Mode.DISABLED, config, _request) and receipt.is_empty(), "禁推")
	_check(not Policy.try_push(hit, true, Vector2.RIGHT, Policy.Mode.DEFAULT, config, _request) and receipt.is_empty(), "自命中禁止")
	hit.silent = true
	_check(not Policy.try_push(hit, false, Vector2.RIGHT, Policy.Mode.DEFAULT, config, _request), "静默命中阻止")
	hit.silent = false
	hit.flags = Combat.MISS
	_check(Policy.try_push(hit, false, Vector2.DOWN, Policy.Mode.DEFAULT, config, _request), "闪避允许推")
	config.regular = false
	_check(Policy.try_push(hit, false, Vector2.DOWN, Policy.Mode.DEFAULT, config, _request), "闪避不属于常规命中")
	config.critical = false
	hit.flags = Combat.CRITICAL | Combat.MISS
	_check(not Policy.try_push(hit, false, Vector2.DOWN, Policy.Mode.DEFAULT, config, _request), "暴击+闪避要同时通过两项")
	config.critical = true
	config.missed = false
	_check(not Policy.try_push(hit, false, Vector2.DOWN, Policy.Mode.DEFAULT, config, _request), "关闭闪避拒绝复合标志")
	hit.flags = Combat.CRITICAL
	_check(Policy.try_push(hit, false, Vector2(0.000001,0), Policy.Mode.OVERRIDE, config, _request, -1.0, 3.0), "允许暴击的自定义推力")
	_check(receipt == [Vector2.ZERO,0.0,3.0], "近零方向归零，负参数截到零")
	if failures == 0: print("PASS 伤害推力规则：%d 项" % checks)
	quit(1 if failures else 0)
func _request(direction: Vector2, intensity: float = 5.0, resistance: float = 10.0) -> void:
	receipt = [direction,intensity,resistance]
func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
