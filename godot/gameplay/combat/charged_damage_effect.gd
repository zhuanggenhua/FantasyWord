extends RefCounted
## 锁定 31629d53 的效果 2004：仅执行已解析角色的正式伤害阶段。
## 不创建 Effect 实体、不替代 CueOnApply 20001、不拥有属性或 Push。
const Combat = preload("res://game_core/combat/combat_rules.gd")
const Apply = preload("res://game_core/combat/formal_damage_application.gd")
const EFFECT_ID := 2004

## hooks 的 source 仍为 Combat 核的角色属性身份，由调用者映射回唯一真实 Actor。
## 所有位置是执行帧的 Unity Y 向上根坐标，不能传 Body/Pivot/缓存瞄准点。
## 空来源保留源执行器的无来源分支；此时作者 impactData 为零。
static func execute_damage_phase(source_stats: Variant, target_stats: Dictionary,
		hooks: Dictionary, source_root: Vector2, target_root: Vector2,
		can_critical: bool, can_miss: bool, roll: Callable) -> bool:
	var descriptor := {"flat_damage":7, "scale":1.5, "damage_type":Combat.DamageType.PHYSICAL,
		"critical_behavior":Combat.Resolution.DEFAULT, "miss_behavior":Combat.Resolution.DEFAULT,
		"ignore_defense":false, "silent":false}
	var output := Combat.solve_damage_output(source_stats, descriptor, can_critical, roll)
	# ImpactDataType.SourcePosition=0；PushMode.Default=0 的实际申请由目标 hooks 独占。
	var impact := target_root - (source_root if source_stats != null else Vector2.ZERO)
	return Apply.execute_damage_output(target_stats, output, can_miss, roll, hooks, impact)
