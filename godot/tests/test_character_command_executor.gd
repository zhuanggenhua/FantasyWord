extends SceneTree
const Executor = preload("res://game_core/interaction/character_command_executor.gd")
class Owner extends RefCounted:
	var allowed := true
	func can_interact() -> bool: return allowed
class Interaction extends RefCounted:
	var interacted_this_frame := false
	var calls := 0
	var dispatched := true
	func try_interact(_target: Variant) -> bool:
		calls += 1
		if dispatched: interacted_this_frame = true
		return dispatched
var n := 0
var bad := 0
func check(value: bool, label: String) -> void:
	n += 1
	if not value: bad += 1; printerr(label)
func _initialize() -> void:
	var x := Executor.new()
	var owner := Owner.new()
	var other := Owner.new()
	var interaction := Interaction.new()
	x.enabled = false
	check(x.execute({"kind":0,"actor":other}) == 3,"character before enabled/actor")
	x.character = owner
	check(x.execute({"kind":0,"actor":other}) == 6,"enabled before actor")
	x.enabled = true
	check(x.execute({"kind":0,"actor":other}) == 5,"actor before dispatch")
	check(x.execute({"kind":0}) == 8,"missing button component")
	x.interaction = interaction
	owner.allowed = false
	check(x.execute({"kind":0}) == 8 and interaction.calls == 0,"locked action not dispatched")
	owner.allowed = true
	interaction.dispatched = false
	check(x.execute({"kind":0}) == 9 and not interaction.interacted_this_frame,"no receiver blocked")
	interaction.dispatched = true
	check(x.execute({"kind":0}) == 0 and interaction.interacted_this_frame,"dispatch success latches")
	var calls := []
	var notices := []
	var fire_result := {"has_ability_source":false,"result":1,"formal_gas_ability_code":20001}
	var stop_result := [true]
	var context := {"provenance":"test command context"}
	var activation := {"provenance":"explicit host activation"}
	check(x.bind_abilities(func(index, original, resolved):
		calls.append([index,original,resolved]);return fire_result,
		func(index): calls.append(["stop",index]);return stop_result[0],
		func(request): calls.append(["activation",request]);return activation,
		func(code,result):notices.append([code,result])),"explicit ability host binding")
	var request := {"kind":6,"ability_index":4,"command_context":context,"actor":owner}
	check(x.execute(request) == 9 and calls.is_empty(),"same frame gate precedes context and slot dispatch")
	check(x.execute({"kind":7,"ability_index":4}) == 0 and calls == [["stop",4]],"stop bypasses latch")
	calls.clear();interaction.interacted_this_frame = false
	check(x.execute(request) == 10 and calls[0] == ["activation",request] and calls[1] == [4,context,activation]
		and notices.is_empty(),"missing source precedes rejected result, no failure notification")
	fire_result.has_ability_source = true
	check(x.execute(request) == 11 and notices == [[20001,1]],"actual rejected result notified once")
	fire_result.result = 0
	check(x.execute(request) == 0 and notices.size() == 1,"valid accepted, no fabricated failure")
	calls.clear()
	check(x.execute({"kind":6}) == 0 and calls[1][0] == -1,"omitted ability index preserves source -1, never slot zero")
	check(x.execute({"kind":7}) == 0 and calls[2] == ["stop",-1],"omitted stop index also -1")
	check(x.execute({"kind":6,"actor":owner,"command_context":{"actor":other}}) == 5,
		"context actor cannot be overridden by projected actor")
	check(x.execute({"kind":6,"command_context":{"actor":other}}) == 5,
		"context actor alone still authoritative")
	stop_result[0] = false
	check(x.execute({"kind":7,"ability_index":4}) == 10,"stop actual missing source")
	check(x.execute({"kind":4}) == 4,"preserve missing click target")
	check(x.execute({"kind":99}) == 1,"unsupported command")
	if bad == 0: print("PASS character command executor ",n," checks")
	quit(0 if bad == 0 else 1)
