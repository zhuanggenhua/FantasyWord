extends RefCounted
## AIController.BehaviourRuntime target-state slice, Unity 31629d5.
## Targets are live adapter dictionaries: position, dead, judicious, hostile, visible.
## Detection order and visibility/faction truth must be supplied by the caller;
## this module does NOT synthesize detection, steering, GAS attacks or an enemy.
signal path_invalidated

var target: Dictionary = {}
var target_position := Vector2.ZERO
var retarget_cooldown := 0.0
var attack_cooldown := 0.0
var navigation_repath_timer := 0.0
var time_since_target_last_seen := 0.0
var waiting_for_attack_facing := false
# AIController serialized defaults, not asserted as any scene's enemy setup.
var reset_from_home_radius := 10.0
var reset_from_target_radius := 10.0
var out_of_range_cooldown := 3.0
var sight_lost_timeout := 3.0
var cannot_see_cooldown := 1.0

static func f32(value: float) -> float:
	return PackedFloat32Array([value])[0]

func try_handle_provoked(source: Dictionary) -> bool:
	# Deliberately no hostility/visibility/dead predicate: source only checks
	# a non-null source, no target, zero cooldown and IsJudiciousTarget.
	if not source.is_empty() and target.is_empty() and retarget_cooldown == 0.0 and source.judicious:
		target = source
		return true
	return false

func tick(fixed_delta: float, frame_delta: float, position: Vector2,
		home: Vector2, detected: Array, try_attack: Callable) -> void:
	# Keep source order. Attack attempt can occur BEFORE an out-of-range reset.
	# The callback implements TryAttackTarget gates separately; it is not damage.
	update_cooldowns(fixed_delta)
	refresh_target(position, home, detected, try_attack)
	update_target_position(frame_delta, home)
	# ApplyMovement must be supplied by a future ContextSteering2D port.

func update_cooldowns(fixed_delta: float) -> void:
	var delta := f32(fixed_delta)
	if retarget_cooldown > 0.0:
		retarget_cooldown = maxf(f32(retarget_cooldown - delta), 0.0)
	if attack_cooldown > 0.0:
		attack_cooldown = maxf(f32(attack_cooldown - delta), 0.0)
	if navigation_repath_timer > 0.0:
		navigation_repath_timer = maxf(f32(navigation_repath_timer - delta), 0.0)

func refresh_target(position: Vector2, home: Vector2, detected: Array, try_attack: Callable) -> void:
	if not target.is_empty() and (target.dead or not target.judicious):
		target = {}
		waiting_for_attack_facing = false
	if target.is_empty():
		waiting_for_attack_facing = false
		if retarget_cooldown == 0.0:
			for candidate in detected:
				# Unity FindTarget checks hostile+visible, not judicious/dead.
				if candidate != null and not candidate.is_empty() and candidate.hostile and candidate.visible:
					target = candidate
					break
		# Newly acquired target is not attacked or range-checked until next tick.
		return
	var distance := position.distance_to(target.position)
	try_attack.call(target, distance)
	if position.distance_to(home) > reset_from_home_radius or distance > reset_from_target_radius:
		stop_chase(out_of_range_cooldown)

func stop_chase(cooldown: float) -> void:
	retarget_cooldown = f32(cooldown)
	target = {}
	waiting_for_attack_facing = false
	navigation_repath_timer = 0.0
	path_invalidated.emit()

func update_target_position(frame_delta: float, home: Vector2) -> void:
	if not target.is_empty():
		if target.visible:
			target_position = target.position
			time_since_target_last_seen = 0.0
		else:
			# Source uses Time.deltaTime here, fixedDeltaTime for cooldowns.
			time_since_target_last_seen = f32(time_since_target_last_seen + f32(frame_delta))
			if time_since_target_last_seen > sight_lost_timeout:
				stop_chase(cannot_see_cooldown)
			# Keep last-seen position THIS tick even if StopChase cleared target.
	else:
		target_position = home
