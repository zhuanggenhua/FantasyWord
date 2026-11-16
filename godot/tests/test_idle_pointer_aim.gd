extends SceneTree
const Aim = preload("res://game_core/movement/idle_pointer_aim.gd")
const Direction = preload("res://game_core/presentation/movable_direction_state.gd")
const Body = preload("res://game_core/movement/native_motion_body.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
class Owner extends RefCounted:
	var directions := Direction.new()
	var allowed := true
	func can_move() -> bool: return true
	func calculate_move_speed() -> float: return 4
	func calculate_speed_multiplier() -> float: return 1
	func update_movement_animation(_v: Vector2) -> void: pass
	func update_facing_from_intent(v: Vector2) -> void:
		if v.length_squared() > 0.0025: directions.set_look_at_direction(v.normalized())
	func register_collision(_v: Object) -> void: pass
	func can_update_target_direction() -> bool: return allowed
	func set_target_direction(v: Vector2) -> void: directions.set_target_direction(v,allowed)
	func reset_target_direction() -> void: directions.reset_target_direction()
class InputProbe extends Node:
	var last_screen := Vector2.ZERO
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion: last_screen=event.position

var n := 0
var failed := 0
func check(value: bool, label: String) -> void:
	n += 1
	if not value: failed += 1; printerr(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(640,480)
	var body := Body.new()
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 0.2
	body.add_child(shape);root.add_child(body)
	var owner := Owner.new()
	body.configure_movement(shape,Filter.new(Filter.Mode.FREE,false,0.05,10,10),owner,0)
	# Explicit host hierarchy, not a claim about unresolved authored pivot hierarchy.
	var parent := Node2D.new()
	parent.position = Vector2(1,-2)
	body.add_child(parent)
	var pivot := Node2D.new()
	pivot.position=Vector2(0,-0.4)
	parent.add_child(pivot)
	var camera := Camera2D.new()
	root.add_child(camera);camera.zoom=Vector2(40,40);camera.make_current()
	var probe := InputProbe.new();root.add_child(probe)
	await process_frame
	camera.force_update_scroll()
	var aim := Aim.new()
	check(aim.configure(body,owner,pivot,true),"explicit owner and world pivot bind")
	owner.directions.set_look_at_direction(Vector2(1,-1).normalized())
	var look := owner.directions.get_look_at_direction()
	var source_point := Vector2(-1,2.2)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_canvas_transform()*Vector2(source_point.x,-source_point.y)
	root.push_input(motion,true)
	aim.update_eligible(camera,probe.last_screen,true)
	check(owner.directions.get_target_direction().is_equal_approx((source_point-Vector2(1,2.4)).normalized()),"native pointer projected relative to actual parented pivot")
	check(owner.directions.get_look_at_direction()==look,"MovementBased aim does not change body facing")
	var old_target := owner.directions.get_target_direction()
	owner.allowed=false
	aim.update_eligible(camera,Vector2.ZERO,false)
	check(owner.directions.get_target_direction()==old_target,"forbidden update retains prior override")
	owner.allowed=true
	body.move_to(Vector2(3,0))
	check(body.has_active_movement_intent(),"outstanding actual MoveOrder is active before first physics step")
	aim.update_eligible(camera,probe.last_screen,true)
	check(owner.directions.get_target_direction()==look,"eligible order resets aim to body rather than pointer")
	body.reset_movement()
	aim.update_eligible(camera,probe.last_screen,true)
	check(owner.directions.get_target_direction()==old_target,"idle probe resumes after order reset")
	aim.update_eligible(camera,probe.last_screen,false)
	check(owner.directions.get_target_direction()==look,"inactive pointer resets eligible target")
	body.set_movement_direction(Vector2(0.05,0))
	check(not body.has_active_movement_intent(),"strict idle threshold not greater at equality")
	body.set_movement_direction(Vector2(0.051,0))
	check(body.has_active_movement_intent(),"raw direction above threshold is active")

	body.reset_movement()
	body.execution._last_successful_movement = Vector2(0.1,0)
	check(body.has_active_movement_intent(),"last accepted movement retains active intent after raw input clears")
	body.execution._last_successful_movement = Vector2.ZERO
	body.execution._push_order = {"remaining":1.0}
	check(body.has_active_movement_intent(),"pending push is active even without raw input or route")
	body.execution._push_order.clear()
	body.reset_movement()
	owner.directions.target_based=true
	aim.update_eligible(camera,probe.last_screen,true)
	check(owner.directions.get_look_at_direction()==owner.directions.get_target_direction(),"TargetBased uses separate original policy")
	var zero := root.get_canvas_transform()*pivot.global_position
	check(not aim.try_update(camera,zero,true),"pointer on pivot is not a direction")
	aim.update_eligible(camera,zero,true)
	check(owner.directions.get_target_direction()==owner.directions.get_look_at_direction(),"near-pivot probe failure resets override")
	body.free();camera.free();probe.free()
	if failed==0: print("PASS idle pointer aim native viewport: %d checks" % n)
	quit(0 if failed==0 else 1)
