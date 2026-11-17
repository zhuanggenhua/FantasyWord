extends "res://tests/test_clickmovetest_aim_pivot.gd"
const Points = preload("res://game_core/input/mouse_point_actions.gd")
const Actions = preload("res://game_core/input/gameplay_command_actions.gd")
const ScreenProject = preload("res://game_core/presentation/orthographic_screen_projection.gd")
class CountingPoints extends Points:
	var reads := 0
	func _init(): super(0)
	func read_value_local(map: Map, rect: Rect2) -> Vector2:
		reads += 1
		return super(map,rect)
class ClickHost extends Node:
	var scene: Node
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			scene.receive_human_gameplay_action("Gameplay","Click","performed")
func run() -> void:
	root.size = Vector2i(800,600)
	var scene = Entry.instantiate();root.add_child(scene)
	var control := ControlHost.new();root.add_child(control)
	var player := Player.new();player.actor=scene.actor
	var owner := Owner.new();var events := MapEvents.new()
	var directory := ProjectSettings.globalize_path("user://click-action")
	var fixture := fixtures(scene,directory)
	var samples := [];var over := [false]
	check(scene.start_human_presentation(fixture[1],directory)!=null,"presentation")
	check(scene.start_human_logic(owner,fixture[0],func():return player,func():return null,events,func(p):samples.append(p);return over[0]),"logic")
	check(scene.start_human_aim(owner,control),"aim")
	check(scene.start_human_interaction(owner,func(_v):pass),"interaction")
	var points := CountingPoints.new();points.enable(Points.Map.GAMEPLAY)
	check(scene.bind_mouse_point_actions(points),"point bound")
	var blocked_click := [true];var resolved := [0];var failures := [];var target := [true]
	var context := {"actor":owner,"issuer_kind":1,"issuer_id":"local"}
	check(scene.bind_human_gameplay_actions(func():
		resolved[0]+=1
		return {"actor":owner,"command_context":context} if target[0] else null,
		func():return false,func(request,result):failures.append([request,result])),"actions")
	check(scene.bind_human_click_action(func():return blocked_click[0]),"explicit click")
	await process_frame
	samples.clear()
	check(scene.receive_human_gameplay_action("Gameplay","Click","performed")==null and samples.is_empty() and resolved[0]==0 and points.reads==0,"release guard before Point/UI/resolve")
	blocked_click[0]=false
	over[0]=true
	check(scene.receive_human_gameplay_action("Gameplay","Click","performed")==null,"UI blocks inactive read")
	check(samples[-1]==Vector2(0,600) and points.read_active(Points.Map.GAMEPLAY)==null and resolved[0]==0,"inactive read is bottom-left but aim stays inactive")
	over[0]=false;target[0]=false
	scene.receive_human_gameplay_action("Gameplay","Click","performed")
	check(failures.size()==1 and failures[0][1]==2,"missing exact command target")
	check(failures[0][0].world_position.is_equal_approx(ScreenProject.project(scene.camera,Vector2(0,600))) and failures[0][0].command_context.issuer_id=="local","inactive projected point and default context")
	var motion := InputEventMouseMotion.new();motion.device=0;motion.position=Vector2(430,270);motion.relative=Vector2(30,-30)
	root.push_input(motion,true)
	scene.receive_human_gameplay_action("Gameplay","Click","performed")
	check(failures.size()==2 and samples[-1]==motion.position,"active sample directly reused without fresh motion")
	check(failures[-1][0].world_position.is_equal_approx(ScreenProject.project(scene.camera,motion.position)),"exact active projection")
	check(points.read_value_local(Points.Map.UI,Rect2(10,20,800,600))==Vector2(10,620),"rect offset + height, not height minus one")
	var saved_camera=scene.camera;scene.camera=null
	var before: int =resolved[0]
	check(scene.receive_human_gameplay_action("Gameplay","Click","performed")==null and resolved[0]==before,"missing camera stops before command")
	check(points.reads==5,"Point is read before missing camera rejection")
	scene.camera=saved_camera
	var saved_actor=player.actor;player.actor=null
	var reads_before:=points.reads
	check(scene.receive_human_gameplay_action("Gameplay","Click","performed")==null and points.reads==reads_before+1 and resolved[0]==before,"missing fallback actor still reads Point")
	player.actor=saved_actor
	target[0]=true
	var host:=ClickHost.new();host.scene=scene;root.add_child(host)
	var button:=InputEventMouseButton.new();button.button_index=MOUSE_BUTTON_LEFT;button.pressed=true;button.position=Vector2(100,100)
	before=scene.command_count
	root.push_input(button,true)
	check(scene.command_count==before+1,"actual Viewport formal host exactly once, no raw double command")
	host.free()
	before=scene.command_count
	root.push_input(button,true)
	check(scene.command_count==before,"binding does not auto-route raw input")
	scene.unbind_human_click_action()
	root.push_input(button,true)
	check(scene.command_count==before+1,"legacy raw compatibility restored")
	check(scene.receive_human_gameplay_action("Gameplay","Click","performed")==null,"unbound normalized click inert")
	check(scene.bind_human_click_action(func():return false),"rebind click")
	scene.unbind_mouse_point_actions()
	before=scene.command_count
	root.push_input(button,true)
	check(scene.command_count==before+1 and scene.receive_human_gameplay_action("Gameplay","Click","performed")==null,"Point unbind releases formal ownership and restores raw")
	scene.free();control.free()
	if failed:printerr("FAIL gameplay Click: %s/%s"%[failed,n]);quit(1)
	else:print("PASS gameplay Click: %s checks"%n);quit(0)
