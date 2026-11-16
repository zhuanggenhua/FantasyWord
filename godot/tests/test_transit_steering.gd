extends SceneTree
const Transit = preload("res://game_core/ai/transit_steering.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.00001
func _initialize() -> void:
	var samples := Transit.directions()
	check(samples.size() == 16, "authored sixteen")
	check(samples[0].distance_to(Vector2(0, 1)) < 0.00001, "source +Y first")
	check(samples[4].distance_to(Vector2.RIGHT) < 0.00001, "clockwise to right")
	check(samples[8].distance_to(Vector2(0, -1)) < 0.00001, "negative Y eighth")
	var empty := Transit.solve({})
	check(empty.direction == Vector2.ZERO, "no direction when no contributions")
	check(empty.preferred_velocity == Vector2.ZERO and empty.strength == 0, "no fabricated movement")
	var seek := Transit.solve({"target": Vector2(3, 0)})
	check(seek.direction.distance_to(Vector2.RIGHT) < 0.00001, "weighted seek")
	check(near(seek.strength, 1), "seek strength")
	check(near(seek.seek[4], 1) and near(seek.seek[12], 0), "positive dot only")
	var near_target := Transit.solve({"target": Vector2(0.005, 0)})
	check(near_target.direction == Vector2.ZERO, "source direction squared threshold")
	var double_obstacle := {"point": Vector2(0.5, 0), "radius": 0.1}
	var obstacle := Transit.solve({"target": Vector2(3, 0), "obstacles": [double_obstacle]})
	check(near(obstacle.constraint[4], 10.0 / 11.0), "radius-aware proximity")
	check(near(obstacle.obstacle_interest[8], 0.35 * 10.0 / 11.0), "clockwise side bias")
	check(obstacle.direction.y < 0, "obstacle steers source negative Y")
	var twice := Transit.solve({"target": Vector2(3, 0), "obstacles": [double_obstacle, double_obstacle]})
	check(twice.constraint == obstacle.constraint, "constraint per behaviour max not sum")
	check(twice.obstacle_interest == obstacle.obstacle_interest, "side contribution max not sum")
	var boundary := Transit.solve({"obstacles": [{"point": Vector2(1, 0), "radius": 0.1}]})
	check(boundary.direction == Vector2.ZERO, "probe boundary excluded by proximity")
	var overlap := Transit.solve({"obstacles": [{"point": Vector2.ZERO, "radius": 1.0}]})
	check(overlap.direction == Vector2.ZERO, "zero closest-point obstacle skipped")
	var neighbour := Transit.solve({"neighbours": [{"position": Vector2(0.5, 0), "radius": 0.35}]})
	check(near(neighbour.separation[12], 1), "overlap maximum separation")
	check(near(neighbour.side_step[8], 0.5), "neighbour sidestep exact center tie")
	var coincident := Transit.solve({"neighbours": [{"position": Vector2.ZERO, "radius": 0.35}]})
	check(coincident.direction.distance_to(Vector2.LEFT) < 0.00001, "coincident neighbour opposite forward")
	check(coincident.side_step == Transit.solve({}).side_step, "coincident sidestep skipped")
	var behind := Transit.solve({"neighbours": [{"position": Vector2(-0.5, 0), "radius": 0.35}]})
	check(behind.side_step == empty.side_step, "behind below dot threshold")
	check(near(Transit.solve({"target": Vector2(3, 0)}, 2.5).preferred_velocity.length(), 2.5), "speed override")
	check(near(Transit.solve({"target": Vector2(3, 0)}, -1).preferred_velocity.length(), 1), "profile speed sentinel")
	check(Transit.solve({"target": Vector2(3, 0)}, 0).preferred_velocity == Vector2.ZERO, "zero override")
	var sum := Transit.solve({"target": Vector2(3, 0), "neighbours": [{"position": Vector2(-0.5, 0), "radius": 0.35}]})
	check(near(sum.interest[4], 2) and near(sum.combined[4], 1), "sum then clamp")
	check(near(obstacle.combined[4], 1.0 / 11.0), "multiplicative constraint")
	var forward_fallback := Transit.solve({"forward": Vector2.ZERO, "neighbours": [{"position": Vector2.ZERO, "radius": 0.35}]})
	check(forward_fallback.direction.distance_to(coincident.direction) < 0.00001, "frame zero forward uses right")
	if failures == 0:
		print("PASS Transit steering: %d checks" % checks)
	quit(1 if failures else 0)
