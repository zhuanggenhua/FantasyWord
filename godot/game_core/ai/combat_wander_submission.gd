extends RefCounted
## Source controller/runtime boundary; all vectors are in Unity-style Y-up space.
## The caller supplies a registered solver's latest SAFE result, not preferred velocity.
const Wander = preload("res://game_core/ai/combat_wander_intent.gd")
const Targets = preload("res://game_core/ai/ai_target_lifecycle.gd")

enum Facing { KEEP_CURRENT, FACE_TARGET, FACE_MOVEMENT }
var wander := Wander.new()
var average_output := Vector2.ZERO

# Values resolved for the original ClickMoveTest combat-wander AI configuration.
var enabled := true
var wander_range := Wander.CLICK_MOVE_TEST_WANDER_RANGE
var attack_radius := 1.0
var speed_multiplier := 1.0
var semantic_radius := 5.0
var group_id := "combat-wander"
var facing_mode := Facing.KEEP_CURRENT

func try_apply(state: Targets, current_position: Vector2, fixed_delta: float,
		target_body_velocity: Variant, look: Vector2, transform_right: Vector2,
		resolved_move_speed: float, random_value: Callable, random_range: Callable,
		submit: Callable, latest_safe_result: Callable, set_motion: Callable,
		set_movement_direction: Callable, can_move: Callable,
		look_at_target: Callable, set_look_direction: Callable) -> bool:
	# The controller has already updated target state this tick.
	var destination := state.target_position
	var has_target := not state.target.is_empty()
	if not Wander.should_use(enabled, has_target, current_position.distance_to(destination), wander_range):
		return false
	var intent := wander.tick(fixed_delta, attack_radius, wander_range, random_value, random_range)
	if intent.is_empty():
		# The group was selected, but source RNG evidence is unavailable.
		# Claim this branch and withdraw instead of falling into pursuit.
		submit.call({"active":false,"target_position":null,"target_velocity":Vector2.ZERO,
			"forward":transform_right,"group_id":group_id,"semantic_query_radius":semantic_radius,
			"arrival_stop_radius":-1.0,"max_speed":0.0,"wander_intent":{}})
		set_motion.call(1.0,Vector2.ZERO)
		set_movement_direction.call(Vector2.ZERO)
		return true
	var forward := transform_right
	if look != Vector2.ZERO:
		forward = look.normalized() if look.length() > Wander.f32(0.00001) else Vector2.ZERO
	# Rigidbody velocity stays live during a short LOS loss, unlike destination.
	var velocity: Vector2 = target_body_velocity if target_body_velocity is Vector2 else Vector2.ZERO
	var max_speed := Wander.f32(Wander.f32(resolved_move_speed) * maxf(Wander.f32(speed_multiplier), 0.0))
	submit.call({
		"active": true, "target_position": destination, "target_velocity": velocity,
		"forward": forward, "group_id": group_id, "semantic_query_radius": semantic_radius,
		"arrival_stop_radius": -1.0, "max_speed": max_speed, "wander_intent": intent,
	})
	# Submit writes an intent; it does not guarantee a newly solved result.
	var result: Dictionary = latest_safe_result.call()
	var safe_velocity: Vector2 = result.safe_velocity
	var push_correction: Vector2 = result.push_correction
	# SubmitIntent immediately updates the handle's MaxSpeed, even though
	# the safe velocity can still be from the previous solve.
	var scale := clampf(Wander.f32(safe_velocity.length() / maxf(max_speed, Wander.f32(0.0001))), 0.0, 1.0)
	var direction := safe_velocity.normalized() if safe_velocity.length_squared() > Wander.f32(0.0001) else Vector2.ZERO
	set_motion.call(scale, push_correction)
	set_movement_direction.call(direction)
	average_output = direction
	if can_move.call():
		match facing_mode:
			Facing.FACE_TARGET:
				look_at_target.call(destination)
			Facing.FACE_MOVEMENT:
				if direction != Vector2.ZERO:
					set_look_direction.call(direction)
	return true

func reset_intent() -> void:
	# BehaviourRuntime.Stop resets the wander timer; it does not clear average output.
	wander.reset()
