extends RefCounted
## 锁定的普通攻击效果 2003：同一个效果先结算基础伤害，再判定背刺。
## 阶段入口负责保持角色身份、目标当前属性和随机源；此处不创建属性或效果实体。
const Combat = preload("res://game_core/combat/combat_rules.gd")
const Apply = preload("res://game_core/combat/formal_damage_application.gd")
const EFFECT_ID := 2003

static func is_backstab(source_root: Vector2, target_root: Vector2, target_direction: Vector2) -> bool:
	var target_to_attacker := source_root - target_root
	if target_to_attacker.length_squared() <= 0.0001:
		return false
	var facing := target_direction if target_direction.length_squared() > 0.0001 else Vector2.RIGHT
	return facing.normalized().dot(target_to_attacker.normalized()) <= -0.35

## 背刺在基础结算完成后重新读取当前根坐标和目标朝向，不缓存命中帧或位移意图。
static func execute_damage_phase(source_stats: Dictionary, target_stats: Dictionary,
		hooks: Dictionary, read_pose: Callable, can_critical: bool, can_miss: bool,
		roll: Callable) -> void:
	_apply(source_stats,target_stats,hooks,4,1.0,can_critical,can_miss,roll)
	if not read_pose.is_valid(): return
	var pose: Variant = read_pose.call()
	if not pose is Dictionary or not pose.get("source_root") is Vector2 \
			or not pose.get("target_root") is Vector2 or not pose.get("target_direction") is Vector2:
		return
	if is_backstab(pose.source_root,pose.target_root,pose.target_direction):
		_apply(source_stats,target_stats,hooks,3,0.0,can_critical,can_miss,roll)

static func _apply(source: Dictionary, target: Dictionary, hooks: Dictionary, flat: int,
		scale: float, can_critical: bool, can_miss: bool, roll: Callable) -> void:
	var descriptor := {"flat_damage":flat, "scale":scale, "damage_type":Combat.DamageType.PHYSICAL,
		"critical_behavior":Combat.Resolution.DEFAULT, "miss_behavior":Combat.Resolution.DEFAULT,
		"ignore_defense":false, "silent":false}
	var output := Combat.solve_damage_output(source,descriptor,can_critical,roll)
	# 两段原 PushMode=Disabled，不能借用蓄力的默认冲击回调。
	Apply.execute_damage_output(target,output,can_miss,roll,hooks)
