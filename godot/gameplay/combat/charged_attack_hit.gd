extends RefCounted
## 31629d53：20004 第 12 帧 TaskApplyEffects 的目标查询和 2004 效果派发。
## 只抽取现有诊断的源代码对应流程；时间轴、角色属性、效果实体和反馈仍归调用方。
const Query = preload("res://game_core/combat/box_hitbox_query.gd")
const EFFECT_ID := 2004

## source_position/facing 必须在命中帧从实际施法者读取，采用 Unity Y 向上的坐标。
## resolve_target(collider) 返回实际业务 owner；apply_effect(caster,target,2004)
## 必须调用该角色现有的效果入口，不得在这里创建替代角色、属性或命中回调。
## ok 只表示查询/派发合同成立，不代表目标未闪避或完整 GAS 已实现。
static func run(world: World2D, caster: Object, source_position: Vector2,
		facing: Vector2, resolve_target: Callable, apply_effect: Callable) -> Dictionary:
	var result := {"ok": false, "error": "", "targets": [], "application_count": 0}
	if world == null or not is_instance_valid(caster):
		result.error = "蓄力命中缺少实际施法者或其 World2D"
		return result
	if not resolve_target.is_valid() or not apply_effect.is_valid():
		result.error = "蓄力命中缺少目标身份解析或效果应用入口"
		return result
	if not source_position.is_finite() or not facing.is_finite() or facing.length_squared() <= 0.0001:
		result.error = "蓄力命中需要实际角色的有效当前位置和朝向"
		return result
	# 原 CatchAreaBox2D 的相对模式不采用 ActivationContext 的缓存目标位置。
	# 继续复用已有 64 碰撞体上限、自身排除和 owner 去重实现。
	var targets := Query.query(world, source_position, facing,
		Vector2(0.75, 0.15), Vector2(1.15, 0.95), 0.0, 128, caster, resolve_target)
	result.targets = targets
	for target in targets:
		apply_effect.call(caster, target, EFFECT_ID)
		result.application_count += 1
	result.ok = true
	return result
