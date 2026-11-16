extends SceneTree
const Predictive = preload("res://game_core/ai/predictive_target_steering.gd")
const Transit = preload("res://game_core/ai/transit_steering.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func near(a: float, b: float) -> bool: return absf(a-b) < 0.00001
func _initialize() -> void:
	var empty := Predictive.solve({})
	check(empty.direction == Vector2.ZERO and empty.speed_scale == 1.0, "no target imposes no arrival limit")
	check(empty.preferred_velocity == Vector2.ZERO, "empty has no fabricated movement")
	var far := Predictive.solve({"target":Vector2(3,0)})
	check(far.direction.distance_to(Vector2.RIGHT) < 0.00001 and near(far.speed_scale,1), "stationary far target")
	check(far.has("pursuit") and not far.has("seek"), "group declares pursuit not seek")
	var f := {"target":Vector2(2,0),"target_velocity":Vector2(0,2)}
	var lead := Predictive.solve(f)
	var expected := Transit.solve({"target":Vector2(2,1.5)})
	check(lead.direction.distance_to(expected.direction) < 0.00001, "fixed .75 second target extrapolation")
	check(lead.pursuit == expected.seek, "per-direction pursuit contribution equals predicted target seek")
	check(f.target == Vector2(2,0), "input dictionary unmodified")
	var stop := Predictive.solve({"target":Vector2(0.1,0),"target_velocity":Vector2(4,0)})
	check(stop.speed_scale == 0 and stop.preferred_velocity == Vector2.ZERO, "arrival uses current distance despite fast receding target")
	check(stop.strength > 0, "zero arrival speed does not erase directional scores")
	var half := Predictive.solve({"target":Vector2(0.8,0)},2.0)
	check(near(half.speed_scale,0.5) and near(half.preferred_velocity.length(),1), "authored .1 to 1.5 slowing interval")
	var at_slow := Predictive.solve({"target":Vector2(1.5,0)})
	check(near(at_slow.speed_scale,1), "slow boundary reaches full speed")
	var override := Predictive.solve({"target":Vector2(1,0),"arrival_stop_radius":1.0})
	check(override.speed_scale == 0, "source final-target sought distance overrides stop radius")
	var zero_stop := Predictive.solve({"target":Vector2(0.75,0),"arrival_stop_radius":0.0})
	check(near(zero_stop.speed_scale,0.5), "zero stop override is valid")
	var negative := Predictive.solve({"target":Vector2(0.8,0),"arrival_stop_radius":-0.5})
	check(near(negative.speed_scale,0.5), "negative stop sentinel uses authored radius")
	var oversized := Predictive.solve({"target":Vector2(2.005,0),"arrival_stop_radius":2.0})
	check(absf(oversized.speed_scale - 0.5) < 0.00003, "slow radius expands to stop plus .01")
	var at_target := Predictive.solve({"target":Vector2.ZERO,"target_velocity":Vector2(3,0)})
	check(at_target.speed_scale == 0 and at_target.preferred_velocity == Vector2.ZERO, "standing at target stops even with predicted directional interest")
	var moving_onto_self := Predictive.solve({"target":Vector2(3,0),"target_velocity":Vector2(-4,0)})
	check(moving_onto_self.direction == Vector2.ZERO and moving_onto_self.speed_scale == 1, "prediction landing at self does not invent pursuit direction")
	var obstacle_frame := {"target":Vector2(3,0),"target_velocity":Vector2(0,1),
		"obstacles":[{"point":Vector2(0.5,0),"radius":0.0}],
		"neighbours":[{"position":Vector2(0.6,0.2),"radius":0.35}]}
	var combined := Predictive.solve(obstacle_frame)
	var transit_frame := obstacle_frame.duplicate(); transit_frame.target = Vector2(3,0.75)
	var compare := Transit.solve(transit_frame)
	check(combined.constraint == compare.constraint, "shared obstacle contribution")
	check(combined.separation == compare.separation and combined.side_step == compare.side_step, "shared neighbour contributions")
	check(combined.interest == compare.interest and combined.combined == compare.combined, "same weighted sum and multiplicative constraints")
	check(near(Predictive.solve({"target":Vector2(3,0)},-1).preferred_velocity.length(),1), "negative speed sentinel")
	check(Predictive.solve({"target":Vector2(3,0)},0).preferred_velocity == Vector2.ZERO, "zero speed preserved")
	var no_target := Predictive.solve({"neighbours":[{"position":Vector2.ZERO,"radius":0.35}],"arrival_stop_radius":2.0})
	check(no_target.speed_scale == 1 and no_target.direction.distance_to(Vector2.LEFT) < 0.00001, "no target allows separation without arrival suppression")
	if failures == 0: print("PASS Predictive target steering: %d checks" % checks)
	quit(1 if failures else 0)
