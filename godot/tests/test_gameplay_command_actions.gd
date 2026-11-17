extends "res://tests/test_clickmovetest_aim_pivot.gd"
const Actions = preload("res://game_core/input/gameplay_command_actions.gd")
const Executor = preload("res://game_core/interaction/character_command_executor.gd")
class KeyboardHost extends Node:
	var scene: Node
	var fire := preload("res://game_core/combat/ability_slot_keyboard_input.gd").new()
	func _input(event: InputEvent) -> void:
		if event is InputEventKey:
			fire.handle_key(event,func(slot,pressed):scene.receive_human_gameplay_action("Gameplay","FireAbility%s" % (slot+1),"performed" if pressed else "canceled"))
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code; event.pressed = pressed
	root.push_input(event,true)
func run() -> void:
	root.size = Vector2i(800,600)
	var scene = Entry.instantiate(); root.add_child(scene)
	var control := ControlHost.new(); root.add_child(control)
	var player := Player.new(); player.actor = scene.actor
	var owner := Owner.new(); var events := MapEvents.new()
	var directory := ProjectSettings.globalize_path("user://actions-test")
	var fixture := fixtures(scene,directory)
	check(scene.start_human_presentation(fixture[1],directory) != null,"presentation")
	check(scene.start_human_logic(owner,fixture[0],func():return player,func():return null,events,func(_p):return false),"logic")
	check(scene.start_human_aim(owner,control),"aim")
	check(scene.start_human_interaction(owner,func(_v):pass),"interaction")
	var fires := []; var stops := []; var failures := []; var gate := [true]; var has_target := [true]; var queries := [0]
	check(scene.start_human_abilities(owner,func(slot,context,activation):
		fires.append([slot,context,activation]); return {"has_ability_source":true,"result":0,"formal_gas_ability_code":0},
		func(slot):stops.append(slot);return true,func(_t):return null,func(_t):return null,func(_a,_b):pass),"abilities")
	var context := {"actor":owner,"source":"local-player"}
	check(scene.bind_human_gameplay_actions(func():return {"actor":owner,"command_context":context} if has_target[0] else null,
		func():queries[0]+=1;return gate[0],func(request,result):failures.append([request,result])),"explicit callback host")
	check(scene.receive_human_gameplay_action("UI","Interact","performed") == null,"UI excluded")
	check(scene.receive_human_gameplay_action("Gameplay","Interact","canceled") == null,"Interact canceled has no command")
	check(scene.receive_human_gameplay_action("Gameplay","Interact","started") == null,"started excluded")
	check(queries[0] == 0,"non-callback phases never query gate")
	check(scene.receive_human_gameplay_action("Gameplay","Interact","performed") == null and failures.is_empty(),"blocked Interact no submit/no failure")
	for slot in range(5):
		check(scene.receive_human_gameplay_action("Gameplay","FireAbility%s"%(slot+1),"performed") == 0,"fire slot %s"%slot)
		check(fires[-1][0] == slot and fires[-1][1] == context,"zero based slot and original context")
		check(scene.receive_human_gameplay_action("Gameplay","FireAbility%s"%(slot+1),"canceled") == 0 and stops[-1] == slot,"cancel slot")
	check(queries[0] == 1,"Fire and Stop do not share Interact release blocker")
	gate[0] = false; owner.allow_interact = false
	check(scene.receive_human_gameplay_action("Gameplay","Interact","performed") == Executor.Failure.INTERACTION_LOCKED,"real owner gate")
	check(failures.size() == 1 and failures[-1][0].ability_index == -1,"failed interaction notified once")
	has_target[0] = false
	check(scene.receive_human_gameplay_action("Gameplay","FireAbility1","performed") == Executor.Failure.MISSING_INPUT_TARGET,"unresolved current input target")
	check(failures.size() == 2 and failures[-1][0].actor == null and failures[-1][0].command_context.issuer_id == "local" and failures[-1][0].command_context.issuer_kind == 1,"missing input target notification once")
	has_target[0] = true; control.accepts = false
	check(scene.receive_human_gameplay_action("Gameplay","FireAbility1","performed") == Executor.Failure.CONTROL_LOCKED,"entry control gate preserved")
	control.accepts = true
	scene.human_interaction.interacted_this_frame = true
	check(scene.receive_human_gameplay_action("Gameplay","FireAbility1","performed") == Executor.Failure.BLOCKED_BY_STATE,"real same-frame interaction latch")
	check(scene.receive_human_gameplay_action("Gameplay","FireAbility1","canceled") == 0,"Stop unaffected by interaction latch")
	scene.human_interaction.interacted_this_frame = false
	var host := KeyboardHost.new(); host.scene = scene; root.add_child(host)
	await process_frame
	var before := fires.size(); var before_stop := stops.size()
	key(KEY_Q,true); key(KEY_2,true); key(KEY_Q,false)
	check(fires.size() == before+1 and stops.size() == before_stop,"Viewport host normalizes shared alias without early Stop")
	key(KEY_2,false)
	check(stops.size() == before_stop+1 and stops[-1] == 1,"Viewport final alias release reaches actual entry executor")
	scene.unbind_human_gameplay_actions()
	check(scene.receive_human_gameplay_action("Gameplay","FireAbility1","performed") == null,"unbind")
	host.free();scene.free();control.free()
	if failed: printerr("FAIL gameplay actions: %s/%s"%[failed,n]);quit(1)
	else:print("PASS gameplay actions: %s checks"%n);quit(0)
