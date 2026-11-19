extends RefCounted
## CombatWanderRuntime2D / SteeringWanderIntent2D, locked Unity 31629d5.
## Pure intent and ApplyMovement branch selection, NOT a movement simulator.
const DIRECTION_CHANGE_INTERVAL := 1.5
const CLICK_MOVE_TEST_WANDER_RANGE := 3.0
var direction_change_timer := 0.0
var current_intent: Dictionary = {}

static func f32(value: float) -> float:
	return PackedFloat32Array([value])[0]

static func should_use(enabled: bool, has_target: bool, distance_to_target: float,
		wander_range: float) -> bool:
	return enabled and has_target and f32(distance_to_target) <= f32(wander_range)

static func select_branch(enabled: bool, has_target: bool, distance_to_destination: float,
		wander_range: float, sought_distance: float, waypoint_tolerance: float) -> String:
	# Destination is the controller's last-known target position, not live position.
	# Navigation availability must NOT veto the earlier combat-wander branch.
	if should_use(enabled, has_target, distance_to_destination, wander_range):
		return "combat_wander"
	if f32(distance_to_destination) <= f32(f32(sought_distance) + f32(waypoint_tolerance)):
		return "final_approach"
	return "resolve_navigation"

static func make_intent(side_sign: float, follow_distance: float) -> Dictionary:
	return {"side_sign": 1.0 if f32(side_sign) >= 0.0 else -1.0,
		"follow_distance": maxf(f32(follow_distance), 0.0)}

func tick(fixed_delta: float, attack_range: float, wander_range: float,
		random_value: Callable, random_range: Callable) -> Dictionary:
	# Caller invokes only from ApplyMovement's wander branch. No frame/LOS timer.
	direction_change_timer = f32(direction_change_timer - maxf(f32(fixed_delta), 0.0))
	if current_intent.is_empty() or direction_change_timer <= 0.0:
		var minimum := maxf(f32(attack_range), 0.0)
		var maximum := maxf(f32(wander_range), minimum)
		# Unity's native shared Random supplies both inclusive draws. When the
		# source provider is absent/invalid, never keep an expired intent or
		# invent a value. This boundary is outside the Unity algorithm.
		current_intent = {}
		direction_change_timer = 0.0
		if not random_value.is_valid() or not random_range.is_valid(): return {}
		var sign_draw: Variant = random_value.call()
		if not _is_inclusive_draw(sign_draw,0.0,1.0): return {}
		var distance_draw: Variant = random_range.call(minimum,maximum)
		if not _is_inclusive_draw(distance_draw,minimum,maximum): return {}
		# Draw order, strict > threshold and one renewal (not catch-up) match C#.
		direction_change_timer = DIRECTION_CHANGE_INTERVAL
		current_intent = make_intent(1.0 if f32(sign_draw) > 0.5 else -1.0,distance_draw)
	# Copy prevents an adapter mutating our cached value (the C# intent is a struct).
	return current_intent.duplicate()

static func _is_inclusive_draw(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) \
		and float(value) >= minimum and float(value) <= maximum

func reset() -> void:
	# BehaviourRuntime.Stop calls Reset; merely not selecting wander does not.
	direction_change_timer = 0.0
	current_intent = {}
