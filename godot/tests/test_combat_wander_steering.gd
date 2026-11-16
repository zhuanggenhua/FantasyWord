extends SceneTree
const Wander = preload("res://game_core/ai/combat_wander_steering.gd")
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
	var frame := {"position":Vector2.ZERO,"target":Vector2(0,1),"wander_intent":{"side_sign":1.0,"follow_distance":1.0}}
	check(Wander.solve({}).direction == Vector2.ZERO, "empty input has no invented interest")
	check(Wander.solve({"target":Vector2.UP}).direction == Vector2.ZERO, "target alone is not seek")
	check(Wander.solve({"wander_intent":frame.wander_intent}).direction == Vector2.ZERO, "intent alone is insufficient")
	var coincident := frame.duplicate(); coincident.target = Vector2.ZERO
	check(Wander.solve(coincident).direction == Vector2.ZERO, "coincident target does not fabricate radial")
	var right := Wander.solve(frame)
	check(right.direction.distance_to(Vector2.RIGHT) < 0.00001, "Unity up target positive sign selects right")
	check(right.wander.size() == 16 and near(right.wander[4],1.0), "authored clockwise sixteen bins")
	check(right.speed_scale == 1.0 and near(right.strength,1.0), "no arrive or speed limiter")
	var left_frame := frame.duplicate(true); left_frame.wander_intent.side_sign = -1.0
	check(Wander.solve(left_frame).direction.distance_to(Vector2.LEFT) < 0.00001, "negative sign reverses tangent")
	var close_frame := frame.duplicate(); close_frame.target = Vector2(0,0.5)
	check(Wander.solve(close_frame).direction.distance_to(Vector2.RIGHT) < 0.00001, "inside follow has no radial retreat")
	var far_frame := frame.duplicate(); far_frame.target = Vector2(0,2)
	var far := Wander.solve(far_frame)
	check(near(far.wander[2],sqrt(0.5)), "tangent and radial use maximum not sum")
	check(near(far.wander[0],1.0) and near(far.wander[4],1.0), "distance weight at twice follow is one")
	check(far.direction.distance_to(Vector2(1,1).normalized()) < 0.00001, "weighted selection combines radial and tangent")
	far_frame.target = Vector2(0,4)
	var farther := Wander.solve(far_frame)
	check(near(farther.wander[0],3.0) and near(farther.combined[0],1.0), "radial contribution unclamped until group resolve")
	var zero_follow := frame.duplicate(true); zero_follow.wander_intent.follow_distance = 0.0
	check(Wander.solve(zero_follow).wander[0] > 9000, "follow epsilon prevents division by zero")
	var obstacle := {"point":Vector2(0.2,0),"radius":0.0}
	var blocked := frame.duplicate(); blocked.obstacles = [obstacle]
	check(Wander.resolve_side(blocked,1.0,Vector2.RIGHT) == 1.0, "one full proximity obstacle stays at threshold exactly one")
	blocked.obstacles = [obstacle,obstacle]
	check(Wander.resolve_side(blocked,1.0,Vector2.RIGHT) == -1.0, "summed danger above one flips toward free side")
	check(Wander.resolve_side(blocked,-1.0,Vector2.RIGHT) == -1.0, "already safer side remains")
	blocked.obstacles = [{"point":Vector2(0,0.2),"radius":0.0},{"point":Vector2(0,0.2),"radius":0.0}]
	check(Wander.resolve_side(blocked,1.0,Vector2.RIGHT) == 1.0, "equal side danger retains requested side")
	blocked.obstacles = [obstacle,{"point":Vector2(-0.2,0),"radius":0.0}]
	check(Wander.resolve_side(blocked,1.0,Vector2.RIGHT) == 1.0, "opposite obstacles cancel vector danger")
	blocked.obstacles = [{"point":Vector2.ZERO,"radius":0.0},{"point":Vector2(2,0),"radius":0.0}]
	check(Wander.resolve_side(blocked,1.0,Vector2.RIGHT) == 1.0, "coincident and out of probe obstacles contribute zero")
	var crowded := frame.duplicate(true)
	crowded.forward = Vector2.RIGHT
	crowded.obstacles = [obstacle]
	crowded.neighbours = [{"position":Vector2(0.6,0.2),"radius":0.35}]
	var shared := Transit.solve(crowded)
	var result := Wander.solve(crowded)
	check(result.constraint == shared.constraint and result.obstacle_interest == shared.obstacle_interest, "same source obstacle avoidance")
	check(result.separation == shared.separation, "same source separation")
	var exact_group := true
	for i in 16:
		var expected := Transit.f32(Transit.f32(result.obstacle_interest[i]+result.wander[i])+result.separation[i])
		exact_group = exact_group and result.interest[i] == expected
	check(exact_group and not result.has("side_step") and not result.has("seek"), "only authored three behaviours in authored order")
	check(near(Wander.solve(frame,2.0).preferred_velocity.length(),2.0), "max speed multiplies preferred velocity")
	check(near(Wander.solve(frame,-1.0).preferred_velocity.length(),1.0), "negative sentinel uses profile max")
	check(Wander.solve(frame,0.0).preferred_velocity == Vector2.ZERO, "explicit zero speed")
	check(frame.wander_intent.side_sign == 1.0 and not frame.has("obstacles"), "solver leaves input intent untouched")
	print("PASS combat-wander steering: %d checks" % checks) if failures == 0 else print("FAIL combat-wander steering: %d" % failures)
	quit(0 if failures == 0 else 1)
