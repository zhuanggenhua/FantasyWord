extends SceneTree

const Gate = preload("res://game_core/ai/ai_attack_gate.gd")
const Lifecycle = preload("res://game_core/ai/ai_target_lifecycle.gd")
var events: Array = []
var turn := Vector2.UP
var allowed_code := 20001
var accepts_fire := false
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(detail)


func exercise(gate: Gate, state: Lifecycle, visible: bool, length: float, offset: Vector2) -> bool:
	events.clear()
	return gate.try_attack(state, visible, length, offset,
		func():
			events.append("eligible")
			return allowed_code,
		func(direction): events.append(["target", direction]),
		func(): return turn,
		func(direction): events.append(["look", direction]),
		func(code): events.append(["stop", code]),
		func(code):
			events.append(["fire_ai", code])
			return accepts_fire)


func _run() -> void:
	var gate := Gate.new()
	var state := Lifecycle.new()
	check(not exercise(gate, state, true, 0.5, Vector2(0.5, 0.0)) and events.is_empty(),
		"no target does not consult ability bridge")
	state.target = {"id": "hero"}
	state.waiting_for_attack_facing = true
	check(not exercise(gate, state, false, 0.5, Vector2(0.5, 0.0)) and events.is_empty()
		and not state.waiting_for_attack_facing, "visibility veto clears pending facing first")
	check(not exercise(gate, state, true, 1.0, Vector2.RIGHT) and events.is_empty(),
		"attack radius is strict, not inclusive")
	allowed_code = 0
	check(not exercise(gate, state, true, 0.5, Vector2(0.5, 0.0)) and events == ["eligible"],
		"no triggerable ability does not ask facing or issue command")
	allowed_code = 20001
	check(not exercise(gate, state, true, 0.0, Vector2.ZERO) and events == ["eligible"],
		"zero direction is rejected after checking ability")
	check(not exercise(gate, state, true, 0.5, Vector2(0.5, 0.0))
		and events == ["eligible", ["target", Vector2.RIGHT], ["look", Vector2.RIGHT]]
		and state.waiting_for_attack_facing and state.attack_cooldown == 0.0,
		"request turning this tick; never assume the requested facing is already applied")
	turn = Vector2.RIGHT
	var attack := ["eligible", ["target", Vector2.RIGHT], ["stop", 20001], ["fire_ai", 20001]]
	check(not exercise(gate, state, true, 0.5, Vector2(0.5, 0.0))
		and events == attack and not state.waiting_for_attack_facing and state.attack_cooldown == 0.0,
		"already aligned requests Stop before AI Fire; rejected Fire does not spend cooldown")
	accepts_fire = true
	check(exercise(gate, state, true, 0.5, Vector2(0.5, 0.0))
		and events == attack and state.attack_cooldown == 1.0, "accepted Fire starts authored cooldown")
	check(not exercise(gate, state, true, 0.5, Vector2(0.5, 0.0)) and events.is_empty(),
		"nonzero cooldown vetoes future attempts before consulting abilities")
	state.update_cooldowns(1.0)
	turn = Vector2.UP
	gate.require_facing = false
	check(exercise(gate, state, true, 0.5, Vector2(0.5, 0.0))
		and events == ["eligible", ["target", Vector2.RIGHT], ["look", Vector2.RIGHT],
			["stop", 20001], ["fire_ai", 20001]], "optional facing gate still writes look before firing")
	check(not Gate.is_facing_aligned(Vector2.ZERO, Vector2.RIGHT, 5.0),
		"zero look is never aligned")
	check(Gate.is_facing_aligned(Vector2.RIGHT.rotated(deg_to_rad(4.0)), Vector2.RIGHT, 5.0),
		"4 degrees is aligned at 5 degrees")
	check(not Gate.is_facing_aligned(Vector2.RIGHT.rotated(deg_to_rad(6.0)), Vector2.RIGHT, 5.0),
		"6 degrees is not aligned at 5 degrees")
	check(not Gate.is_facing_aligned(Vector2.RIGHT, Vector2.RIGHT, 0.0),
		"zero completion angle remains strict even for exact alignment")
	check(not Gate.is_facing_aligned(Vector2.UP, Vector2.RIGHT, 100.0),
		"completion is clamped to 45 degrees")
	if failures == 0:
		print("PASS AI attack gate: %d checks" % checks)
	quit(1 if failures != 0 else 0)
