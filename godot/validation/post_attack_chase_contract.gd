extends RefCounted
## ClickMoveTestPostAttackChaseValidator, Unity 31629d5. Validation only.
## Unity XY. Runtime must supply real animation keys, CanMove, target and positions.
## This helper does not move actors or infer Dmg from an HP change.

const OBSERVATION_FRAMES := 240
const SETUP_SPACING := 0.7200000286102295 # original float 0.72
const MOVE_AWAY := 2.5999999046325684 # original float 2.6
const REQUIRED_NPC_DISPLACEMENT := 0.20000000298023224 # original float 0.2
const REQUIRED_FINAL_DISTANCE := 1.4500000476837158 # original float 1.45
const MIN_RELOCATION_DISTANCE := 2.0
const FALLBACK_DIRECTIONS := [
	Vector2.RIGHT, Vector2.LEFT, Vector2(0, 1), Vector2(0, -1),
	Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1),
]


static func setup_npc_position(player_position: Vector2) -> Vector2:
	return player_position + Vector2(0, SETUP_SPACING)


static func relocation(player: Vector2, npc: Vector2, build_path: Callable) -> Dictionary:
	var away := player - npc
	if away.length_squared() <= 0.0001:
		away = Vector2(0, -1)
	var desired := player + away.normalized() * MOVE_AWAY
	if not build_path.is_valid():
		return {"desired": desired, "position": desired, "status": "no_map"}
	var resolved: Variant = _resolve(npc, desired, build_path)
	if resolved is Vector2:
		return {"desired": desired, "position": resolved, "status": "desired_path"}
	for i in FALLBACK_DIRECTIONS.size():
		var candidate := player + Vector2(FALLBACK_DIRECTIONS[i]).normalized() * MOVE_AWAY
		resolved = _resolve(npc, candidate, build_path)
		if resolved is Vector2:
			return {"desired": desired, "position": resolved, "status": "fallback_path", "fallback_index": i + 1}
	return {"desired": desired, "position": desired, "status": "no_reachable_candidate"}


static func _resolve(npc: Vector2, candidate: Vector2, build_path: Callable) -> Variant:
	# TerrainWorldRoute returns null or an ordered PackedVector2Array.
	var path: Variant = build_path.call(npc, candidate)
	if not path is PackedVector2Array or path.is_empty() or npc.distance_to(path[-1]) < MIN_RELOCATION_DISTANCE:
		return null
	return path[-1]


static func await_hit(frame_elapsed: int, player_animation: String) -> String:
	# The original checks Dmg before timeout, even strictly beyond 240.
	if player_animation == "Dmg":
		return "hit_observed"
	return "hit_timeout" if frame_elapsed > OBSERVATION_FRAMES else "pending"


static func chase_sufficient(npc_displacement: float, final_distance: float) -> bool:
	return npc_displacement >= REQUIRED_NPC_DISPLACEMENT or final_distance <= REQUIRED_FINAL_DISTANCE


static func evaluate(chase_frames_elapsed: int, hit_frame: int, player_animation: String,
		npc_can_move: bool, npc_has_target: bool, npc_at_relocation: Vector2,
		npc_position: Vector2, player_position: Vector2) -> Dictionary:
	if chase_frames_elapsed <= OBSERVATION_FRAMES:
		return {"complete": false, "success": false}
	var displaced := npc_at_relocation.distance_to(npc_position)
	var distance := npc_position.distance_to(player_position)
	var failures: Array[String] = []
	if hit_frame <= 0:
		failures.append("no_dmg_observed")
	if player_animation == "Dmg":
		failures.append("player_stuck_in_dmg")
	if not npc_can_move:
		failures.append("npc_movement_locked")
	if not npc_has_target:
		failures.append("npc_lost_target")
	if not chase_sufficient(displaced, distance):
		failures.append("npc_did_not_resume_chase")
	return {"complete": true, "success": failures.is_empty(), "failures": failures,
		"npc_displacement": displaced, "final_distance": distance}
