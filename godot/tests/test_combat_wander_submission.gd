extends SceneTree

const Runner = preload("res://game_core/ai/combat_wander_submission.gd")
const State = preload("res://game_core/ai/ai_target_lifecycle.gd")
var count := 0
var failed := false
var events: Array = []
var sent: Dictionary
var movable := true
var source_ready := true
var safe: Dictionary = {"safe_velocity": Vector2(0, 2),
		"push_correction": Vector2(0.25, 0), "preferred_velocity": Vector2.LEFT}
var runner := Runner.new()
var state := State.new()

func expect(ok: bool, what: String) -> void:
	count += 1
	if not ok:
		failed = true
		printerr(what)

func apply_tick(body_velocity: Variant = null, look := Vector2.ZERO) -> bool:
	return runner.try_apply(state, Vector2.ZERO, 0.02, body_velocity, look, Vector2.RIGHT, 4.0,
		(func(): events.append("rng"); return 0.8) if source_ready else Callable(),
		func(lo, hi): events.append(["range", lo, hi]); return 2.0,
		func(intent): events.append("submit"); sent = intent,
		func(): events.append("latest"); return safe,
		func(scale, push): events.append(["motion", scale, push]),
		func(direction): events.append(["move", direction]),
		func(): events.append("can_move"); return movable,
		func(destination): events.append(["face_target", destination]),
		func(direction): events.append(["face_movement", direction]))

func _initialize() -> void:
	state.target_position = Vector2(3, 0)
	expect(not apply_tick() and events.is_empty(), "no target cannot submit or consume RNG")
	state.target = {"position":Vector2(5, 0), "visible":false}
	state.waiting_for_attack_facing = true
	expect(apply_tick(Vector2(0.25, 0.5), Vector2(0, -2)), "inclusive range uses last-seen, not live position")
	expect(events == ["rng", ["range", 1.0, 3.0], "submit", "latest",
		["motion", 0.5, Vector2(0.25,0)], ["move", Vector2.DOWN], "can_move"],
		"RNG and runtime result application sequence; no movement-facing override from attack wait")
	expect(sent.target_position == Vector2(3, 0) and sent.target_velocity == Vector2(0.25, 0.5), "cached position vs live velocity")
	expect(sent.forward == Vector2.UP and sent.active and sent.group_id == "combat-wander", "forward and correct group")
	expect(sent.semantic_query_radius == 5.0 and sent.arrival_stop_radius == -1.0 and sent.max_speed == 4.0, "intent parameters")
	expect(sent.wander_intent == {"side_sign":1.0, "follow_distance":2.0}, "value-shaped intent")
	expect(runner.average_output == Vector2.DOWN, "use safe direction, not preferred")
	events.clear()
	runner.facing_mode = Runner.Facing.FACE_TARGET
	runner.speed_multiplier = -2.0
	expect(apply_tick(), "missing body supplies zero velocity")
	expect(sent.forward == Vector2.RIGHT and sent.target_velocity == Vector2.ZERO and sent.max_speed == 0.0, "fallback and nonnegative multiplier")
	expect(events == ["submit", "latest", ["motion", 1.0, Vector2(0.25,0)],
		["move", Vector2.DOWN], "can_move", ["face_target", Vector2(3,0)]],
		"old safe velocity divides by newly submitted max speed; cached intent and facing")
	events.clear()
	runner.facing_mode = Runner.Facing.FACE_MOVEMENT
	movable = false
	expect(apply_tick() and events.back() == "can_move", "locked action still receives motion but no facing")
	events.clear()
	movable = true
	safe.safe_velocity = Vector2(0, 0.005)
	expect(apply_tick() and events[-3] == ["motion", 1.0, Vector2(0.25,0)] and events[-2] == ["move", Vector2.ZERO] and events.back() == "can_move",
		"nonzero subthreshold safe velocity has speed scale but zero direction")
	events.clear()
	safe.safe_velocity = Vector2(-6, 0)
	expect(apply_tick() and events.back() == ["face_movement", Vector2.LEFT], "face movement uses safe direction")
	var timer := runner.wander.direction_change_timer
	state.target_position = Vector2(3.01, 0)
	events.clear()
	expect(not apply_tick() and events.is_empty() and runner.wander.direction_change_timer == timer, "branch exit does not reset or advance timer")
	runner.reset_intent()
	expect(runner.wander.current_intent.is_empty() and runner.average_output == Vector2.LEFT, "Stop resets intent but not average")
	source_ready = false
	state.target_position = Vector2(3,0)
	events.clear()
	expect(apply_tick() and not sent.active and sent.target_position==null
		and events==["submit",["motion",1.0,Vector2.ZERO],["move",Vector2.ZERO]],
		"missing source draws withdraw selected wander without replaying safe result or falling into pursuit")
	if not failed:
		print("PASS combat wander controller and solver-result boundary: ", count)
	quit(1 if failed else 0)
