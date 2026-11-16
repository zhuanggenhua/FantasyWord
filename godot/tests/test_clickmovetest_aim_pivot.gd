extends SceneTree
const Entry = preload("res://gameplay/clickmovetest/entry.tscn")
const Direction = preload("res://game_core/presentation/movable_direction_state.gd")
class Owner extends RefCounted:
	signal look_at_direction_changed(value: Vector2)
	var state := Direction.new()
	var allow_aim := true
	func _init() -> void: state.look_at_direction_changed.connect(_forward_look)
	func _forward_look(v: Vector2) -> void: look_at_direction_changed.emit(v)
	func get_look_at_direction() -> Vector2: return state.get_look_at_direction()
	func can_move() -> bool: return true
	func calculate_move_speed() -> float: return 4
	func calculate_speed_multiplier() -> float: return 1
	func update_facing_from_intent(v: Vector2) -> void:
		if v.length_squared() > 0.0025: state.set_look_at_direction(v.normalized())
	func register_collision(_collider: Object) -> void: pass
	func can_update_target_direction() -> bool: return allow_aim
	func set_target_direction(v: Vector2) -> void: state.set_target_direction(v,allow_aim)
	func reset_target_direction() -> void: state.reset_target_direction()
class Player extends RefCounted:
	signal controlled_character_changed(character: Node2D)
	var actor: Node2D
	func get_current_controlled_character_or_player_instance() -> Node2D: return actor
class MapEvents extends RefCounted:
	signal map_loaded
	signal map_unloaded
class ControlHost extends Node:
	var local := true
	var accepts := true
	var capable := true
	var active := true
	var reads := 0
	var refreshes := 0
	var resets := 0
	var point: Variant = null
	func accepts_player_input(_actor: Node2D) -> bool: return accepts
	func is_current_controlled(_actor: Node2D) -> bool: return local
	func can_be_player_controlled(_actor: Node2D) -> bool: return capable
	func refresh_interaction_target(_actor: Node2D) -> void: refreshes += 1
	func reset_interaction_target(_actor: Node2D) -> void: resets += 1
	func read_active_gameplay_pointer() -> Variant:
		reads += 1
		return point if active else null
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion: point = event.position
var n := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	n += 1
	if not value: failed += 1; printerr(label)
func read(path: String) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(path))
func fixtures(scene: Node, directory: String) -> Array:
	var rows := []
	for i in range(900):
		rows.append({"cell":[i%30-15,int(float(i)/30.0)-15,0],"walkable":i<649,"elevation":0,"transition":0,"ramp":0,"surface":0,"cost":1})
	var rules := {"schema":1,"source_commit":scene.SOURCE,"rule_tilemap":1361196487,"nearest_radius":2,"rows":rows}
	DirAccess.make_dir_recursive_absolute(directory)
	var png := directory.path_join("fixture.png")
	var image := Image.create_empty(32,128,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	assert(image.save_png(png) == OK)
	var directions := []
	for row in range(4): directions.append([{"texture":"fixture.png","rect":[0,(3-row)*32,32,32]}])
	var action := {"duration":1.0,"times":[0.0],"labels":[0],"loop":true,"directions":directions}
	return [rules,{"schema":1,"source_commit":scene.SOURCE,"actions":{"Idle":action,"Walk":action},
		"textures":{"fixture.png":{"sha256":FileAccess.get_sha256(png),"size":[32,128],"pixels_per_unit":8}}}]
func pointer(world: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_canvas_transform()*world
	root.push_input(event,true)
func run() -> void:
	root.size = Vector2i(800,600)
	var scene = Entry.instantiate()
	root.add_child(scene)
	var control := ControlHost.new()
	root.add_child(control)
	var player := Player.new()
	player.actor = scene.actor
	var events := MapEvents.new()
	var owner := Owner.new()
	owner.state.set_look_at_direction(Vector2(1,-1).normalized())
	var private_dir := OS.get_environment("FORMAL_HUMAN_PRIVATE")
	var directory := ProjectSettings.globalize_path("user://aim-pivot-test")
	var rules: Dictionary
	var animation: Dictionary
	if private_dir.is_empty():
		var fixture := fixtures(scene,directory)
		rules=fixture[0];animation=fixture[1]
	else:
		directory=private_dir.path_join("private-human-source")
		animation=read(private_dir.path_join("private-formal-human-verification/animation-final.json"))
		rules=read(private_dir.path_join("private-clickmove-audit/rules.json"))
	check(scene.aim_pivot.get_parent() == scene.actor and scene.aim_pivot.position.is_equal_approx(Vector2(0,-0.4)),
		"source Static Pivot is parented to Actor, not visual Body")
	var display: Node2D = scene.start_human_presentation(animation,directory)
	if display == null or not scene.start_human_logic(owner,rules,func():return player,func():return null,events,func(_p):return false):
		printerr("Could not start actual ClickMoveTest entry.");scene.free();control.free();quit(1);return
	var foreign := Owner.new()
	check(not scene.start_human_aim(foreign,control),"must share the authoritative Human movement/facing owner")
	check(scene.start_human_aim(owner,control),"start explicit source aim control")
	await process_frame
	pointer(Vector2(0,-0.2))
	scene._update_human_aim()
	check(owner.state.get_target_direction().is_equal_approx(Vector2(0,-1)),"between pivot and root: aim down in source Y-up coordinates")
	check(display.playback.current_direction == 0,"actual Human atlas stays SE with separated target")
	var old := owner.state.get_target_direction()
	owner.allow_aim = false
	control.active = false
	var reads := control.reads
	var refreshes := control.refreshes
	scene._update_human_aim()
	check(owner.state.get_target_direction() == old and control.reads == reads and control.refreshes == refreshes+1,
		"interaction refresh precedes blocked aim gate; blocked aim preserves target")
	owner.allow_aim = true
	control.active = true
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = root.get_canvas_transform()*Vector2(1.5,-0.5)
	root.push_input(click,true)
	check(scene.actor.execution.has_move_order(),"native viewport click issued actual move order")
	scene._update_human_aim()
	check(owner.state.get_target_direction() == owner.state.get_look_at_direction(),"open order immediately clears idle pointer target")
	for i in range(110):
		await physics_frame
		if not scene.actor.execution.has_move_order(): break
	await process_frame
	check(scene.actor.global_position.distance_to(Vector2(1.5,-0.5)) <= 0.10001,"actual authored Actor moved under native physics")
	check(scene.aim_pivot.global_position.is_equal_approx(scene.actor.global_position+Vector2(0,-0.4)),"actual world pivot follows Actor")
	pointer(scene.actor.global_position+Vector2(0,-0.2))
	scene._update_human_aim()
	check(owner.state.get_target_direction().is_equal_approx(Vector2(0,-1)),"aim resumes relative to moving world pivot")
	check(display.playback.current_direction == 2,"actual body direction comes only from accepted owner signal")
	scene.actor.move_to(scene.actor.get_movement_position()+Vector2(2,0))
	control.local = false
	scene._update_human_aim()
	scene._update_human_aim()
	check(control.resets == 1 and not scene.actor.execution.has_move_order()
		and owner.state.get_target_direction() == owner.state.get_look_at_direction(),"loss of local control clears aim and movement exactly once")
	control.local = true
	control.capable = false
	scene._update_human_aim()
	check(control.resets == 1,"ineligible actor that was not local does not repeat reset")
	control.accepts = false
	scene.notify_human_aim_input_disabled()
	scene._update_human_aim()
	check(control.resets == 2,"input disable resets immediately, disabled frames do not repeat")
	scene.stop_human_aim()
	check(control.resets == 3,"stop follows source explicit disable reset")
	scene.free();control.free()
	if failed == 0: print("PASS authored ClickMoveTest aim pivot: %d checks" % n)
	quit(0 if failed == 0 else 1)
