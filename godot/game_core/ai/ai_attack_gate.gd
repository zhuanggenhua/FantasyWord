extends RefCounted
## AIController.BehaviourRuntime.TryAttackTarget; no spell damage or actor creation.
## The subject's action bridge supplies resolved first eligible GAS code and
## reports whether the final source-equivalent Fire request was accepted.
const Lifecycle = preload("res://game_core/ai/ai_target_lifecycle.gd")
const MIN_VECTOR_SQ := 0.0001

var trigger_radius := 1.0
var cooldown_seconds := 1.0
var require_facing := true
var facing_completion_degrees := 5.0


func try_attack(state: Lifecycle, visible: bool, distance: float, offset: Vector2,
		find_first_triggerable: Callable, set_target_direction: Callable,
		get_look_direction: Callable, set_look_direction: Callable,
		stop_fire: Callable, fire_ai: Callable) -> bool:
	if state.target.is_empty() or not visible or state.attack_cooldown != 0.0 or distance >= trigger_radius:
		state.waiting_for_attack_facing = false
		return false

	var ability_code: int = find_first_triggerable.call()
	if ability_code <= 0 or offset.length_squared() <= MIN_VECTOR_SQ:
		state.waiting_for_attack_facing = false
		return false

	var direction := offset.normalized()
	set_target_direction.call(direction)
	if not require_facing:
		state.waiting_for_attack_facing = false
		set_look_direction.call(direction)
	elif is_facing_aligned(get_look_direction.call(), direction, facing_completion_degrees):
		state.waiting_for_attack_facing = false
	else:
		state.waiting_for_attack_facing = true
		set_look_direction.call(direction)
		return false

	stop_fire.call(ability_code)
	if not fire_ai.call(ability_code):
		return false
	state.attack_cooldown = Lifecycle.f32(cooldown_seconds)
	return true


static func is_facing_aligned(current: Vector2, direction: Vector2, completion_deg: float) -> bool:
	var current_sq := current.length_squared()
	var direction_sq := direction.length_squared()
	if current_sq <= MIN_VECTOR_SQ or direction_sq <= MIN_VECTOR_SQ:
		return false
	var denominator := Lifecycle.f32(sqrt(Lifecycle.f32(current_sq * direction_sq)))
	var cosine := clampf(Lifecycle.f32(current.dot(direction) / denominator), -1.0, 1.0)
	var angle := Lifecycle.f32(Lifecycle.f32(acos(cosine)) * Lifecycle.f32(180.0 / PI))
	return angle < clampf(completion_deg, 0.0, 45.0)
