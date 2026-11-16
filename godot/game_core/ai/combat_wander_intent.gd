extends RefCounted
## CombatWanderRuntime2D / SteeringWanderIntent2D, locked Unity 31629d5.
## Pure intent and ApplyMovement branch selection, NOT a movement simulator.
const DIRECTION_CHANGE_INTERVAL := 1.5
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
		direction_change_timer = DIRECTION_CHANGE_INTERVAL
		var minimum := maxf(f32(attack_range), 0.0)
		var maximum := maxf(f32(wander_range), minimum)
		# Draw order, strict > threshold and one renewal (not catch-up) match C#.
		var side := 1.0 if f32(random_value.call()) > 0.5 else -1.0
		current_intent = make_intent(side, random_range.call(minimum, maximum))
	# Copy prevents an adapter mutating our cached value (the C# intent is a struct).
	return current_intent.duplicate()

func reset() -> void:
	# BehaviourRuntime.Stop calls Reset; merely not selecting wander does not.
	direction_change_timer = 0.0
	current_intent = {}
