extends SceneTree
const Wander = preload("res://game_core/ai/combat_wander_intent.gd")
var failures := 0
var checks := 0
var draws: Array = []
var sample := 0.5
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func value() -> float:
	draws.append("value")
	return sample
func range_value(low: float, high: float) -> float:
	draws.append([low, high])
	return high
func _initialize() -> void:
	var w := Wander.new()
	check(not Wander.should_use(false, true, 1.0, 2.0), "disabled")
	check(not Wander.should_use(true, false, 1.0, 2.0), "no target including master destination")
	check(Wander.should_use(true, true, 2.0, 2.0), "range inclusive")
	check(not Wander.should_use(true, true, 2.001, 2.0), "outside range")
	check(Wander.select_branch(true, true, 0.5, 2.0, 1.0, 0.2) == "combat_wander", "wander precedes final approach")
	check(Wander.select_branch(true, true, 1.9, 2.0, 0.1, 0.2) == "combat_wander", "wander precedes navigation")
	check(Wander.select_branch(false, true, 1.0, 2.0, 0.75, 0.25) == "final_approach", "inclusive final boundary")
	check(Wander.select_branch(true, false, 3.0, 4.0, 0.75, 0.25) == "resolve_navigation", "no target cannot wander")
	check(Wander.make_intent(0.0, -1.0) == {"side_sign":1.0,"follow_distance":0.0}, "intent constructor clamps")
	var intent := w.tick(0.02, 1.0, 2.0, value, range_value)
	check(draws == ["value", [1.0,2.0]] and intent.side_sign == -1.0 and intent.follow_distance == 2.0, "ordered random draws; tie negative")
	check(w.direction_change_timer == 1.5, "initial draw sets full interval, no residual subtraction")
	intent.side_sign = 9.0
	check(w.current_intent.side_sign == -1.0, "value intent cannot mutate cache")
	draws.clear()
	w.tick(-20.0, 4.0, 9.0, value, range_value)
	check(w.direction_change_timer == 1.5 and draws.is_empty(), "negative dt and changed range preserve existing intent")
	w.tick(0.5, 4.0, 9.0, value, range_value)
	check(w.direction_change_timer == 1.0 and draws.is_empty(), "fixed timer counts only invoked ticks")
	sample = 0.75
	intent = w.tick(1.0, 4.0, 2.0, value, range_value)
	check(draws == ["value",[4.0,4.0]] and intent.side_sign == 1.0, "exact expiry and range not below attack")
	draws.clear()
	w.tick(100.0, -2.0, -1.0, value, range_value)
	check(draws == ["value",[0.0,0.0]] and w.direction_change_timer == 1.5, "large delta one renewal, negative ranges clamp")
	w.reset()
	check(w.current_intent.is_empty() and w.direction_change_timer == 0.0, "Stop reset")
	draws.clear()
	w.tick(0.0, 1.0, 2.0, value, range_value)
	check(draws.size() == 2, "reset causes immediate new intent even zero dt")
	var expected := 1.5
	for i in 7:
		expected = Wander.f32(expected - Wander.f32(0.02))
		w.tick(0.02, 1.0, 2.0, value, range_value)
	check(w.direction_change_timer == expected, "binary32 timer per fixed step")
	w.reset()
	draws.clear()
	check(w.tick(.02,1.0,3.0,value,Callable()).is_empty() and draws.is_empty(),
		"missing native provider does not consume a half-draw")
	check(w.tick(.02,1.0,3.0,func(): return NAN,range_value).is_empty() and draws.is_empty(),
		"reject invalid sign without asking for distance")
	check(w.tick(.02,1.0,3.0,func(): return "0.2",range_value).is_empty(),
		"do not coerce untrusted nonnumeric sample")
	check(w.tick(.02,1.0,3.0,func(): return 0.0,func(_lo,_hi): return 1.0)
		== {"side_sign":-1.0,"follow_distance":1.0},"native float minima are inclusive")
	var absent := w.tick(1.5,1.0,3.0,func(): return 1.0,func(_lo,_hi): return 3.01)
	check(absent.is_empty() and w.current_intent.is_empty() and w.direction_change_timer==0.0,
		"invalid renewal cannot return expired intent")
	check(w.tick(.02,1.0,3.0,func(): return 1.0,func(_lo,_hi): return 3.0)
		== {"side_sign":1.0,"follow_distance":3.0},"native float maxima are inclusive")
	if failures == 0:
		print("PASS combat wander intent/branch: %d checks" % checks)
	quit(1 if failures else 0)
