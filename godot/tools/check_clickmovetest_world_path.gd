extends SceneTree
## Optional actual rule data → world path → actor physics bridge.
## Source collision shapes, visuals, camera scheduler parity and OS input remain excluded.

const Route = preload("res://game_core/navigation/terrain_world_route.gd")
const Body = preload("res://game_core/movement/native_motion_body.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const CharacterMovement = preload("res://game_core/movement/character_movement.gd")
const Terrain = preload("res://game_core/movement/terrain_cast.gd")
const Commands = preload("res://game_core/movement/movement_commands.gd")
const ScreenProjection = preload("res://game_core/presentation/orthographic_screen_projection.gd")
const WorldSpaceFollow = preload("res://game_core/presentation/world_space_camera_follow.gd")
const Binding = preload("res://game_core/presentation/player_camera_binding.gd")
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
const START := Vector2(-5.5, 5.5)
const END := Vector2(-3.5, 3.5)

class ProbeBody extends Body:
	signal teleported

class PlayerProvider extends RefCounted:
	signal controlled_character_changed(character: Node2D)
	var actor: Node2D
	func get_current_controlled_character_or_player_instance() -> Node2D: return actor

class MapEvents extends RefCounted:
	signal map_loaded
	signal map_unloaded

class Owner extends RefCounted:
	func can_move() -> bool: return true
	func calculate_move_speed() -> float: return 4.0
	func calculate_speed_multiplier() -> float: return 1.0
	func update_movement_animation(_value: Vector2) -> void: pass
	func update_facing_from_intent(_value: Vector2) -> void: pass
	func register_collision(_body: Object) -> void: pass

class FixedDriver extends Node:
	var body
	var observed_steps := 0
	func _physics_process(_delta: float) -> void:
		if not body.execution.has_move_order():
			return
		body.advance_movement(0.02) # Controlled source-sized step, not a Unity timing comparison.
		observed_steps += 1


func _initialize() -> void:
	call_deferred("_run")


func _world_cell(layer: int, world: Vector2) -> Variant:
	if layer != 0:
		return null
	return Vector3i(floori(world.x), floori(world.y), 0)


func _world_center(node: Vector4i) -> Vector2:
	return Vector2(node.y + 0.5, node.z + 0.5)


func _refuse(reason: String) -> void:
	printerr("ClickMoveTest world route probe failed: ", reason)
	quit(1)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		_refuse("pass the local extractor output path after --")
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not data is Dictionary or data.get("source_commit") != SOURCE or data.get("rule_tilemap") != 1361196487 			or not data.get("rows") is Array or data.rows.size() != 900:
		_refuse("missing locked extracted scene rule data")
		return
	var route := Route.new(data.rows, int(data.nearest_radius), _world_cell, _world_center)
	if route.graph.node_count() != 649:
		_refuse("wrong original default-layer graph")
		return
	var expected := PackedVector2Array([Vector2(-4.5,5.5), Vector2(-3.5,5.5), Vector2(-3.5,4.5), END])
	var actual: Variant = route.try_build_world_path(START, END)
	if actual != expected:
		_refuse("source-preferred corner path no longer preserves the authored ramp centers")
		return
	if route.try_build_world_path(Vector2.ZERO, Vector2(4.5,0)) != PackedVector2Array([Vector2(3.5,0.5), Vector2(4.5,0)]):
		_refuse("flat path compression or exact final click changed")
		return
	if route.try_build_world_path(START, Vector2(1000,1000)) != null:
		_refuse("no legal route must refuse rather than traverse terrain")
		return
	var body := ProbeBody.new()
	body.position = Terrain.to_physics(START)
	body.collision_layer = 256
	var capsule := CapsuleShape2D.new()
	capsule.radius = 0.39
	capsule.height = 0.86
	var shape := CollisionShape2D.new()
	shape.shape = capsule
	shape.position = Vector2(0,-0.42)
	body.add_child(shape)
	root.add_child(body)
	body.configure_movement(shape, Filter.new(Filter.Mode.FREE, false, 0.05, 10.0, 10.0), Owner.new(), 7752)
	var driver := FixedDriver.new()
	driver.body = body
	root.add_child(driver)
	await physics_frame
	var controller := CharacterMovement.new(body, 0.05)
	if not controller.set_movement_control_mode(CharacterMovement.Mode.CLICK_TO_MOVE) or not controller.handle_click_move(END, route) 			or not body.execution.has_move_order():
		_refuse("source-map click did not immediately queue a native actor order")
		return
	var reached := 0
	for tick in range(180):
		await physics_frame
		if reached < expected.size() and body.get_movement_position().distance_to(expected[reached]) <= 0.10001:
			reached += 1
		if not body.execution.has_move_order():
			break
	if body.execution.has_move_order() or driver.observed_steps <= 0 or reached != expected.size():
		_refuse("real Godot body did not observe all source waypoints in order")
		return
	var stopped: Vector2 = body.get_movement_position()
	if not controller.handle_click_move(START, route) or not body.execution.has_move_order() \
			or controller.handle_click_move(Vector2(1000,1000), route) or body.execution.has_move_order():
		_refuse("unreachable map click must clear a pending order without fallback")
		return
	await physics_frame
	await physics_frame
	if body.get_movement_position() != stopped:
		_refuse("cleared order moved the native actor")
		return
	# Reuse the verified starting camera pose, not an invented follow trajectory.
	# Try the original 75%/50% screen sample against the real viewport.
	root.size = Vector2i(800, 600)
	var camera := WorldSpaceFollow.new()
	camera.position = Terrain.to_physics(Vector2(0.75,-3.1))
	root.add_child(camera)
	camera.make_current()
	await process_frame
	var viewport_size: Vector2 = root.get_visible_rect().size
	camera.zoom = ScreenProjection.zoom_for_view_height(viewport_size.y, 5.0)
	camera.force_update_scroll()
	var screen := viewport_size * Vector2(0.75,0.5)
	var world_point: Variant = ScreenProjection.project(camera, screen)
	if world_point == null or not world_point.is_equal_approx(Vector2(0.75 + 2.5 * viewport_size.x / viewport_size.y, -3.1)):
		_refuse("authored orthographic viewport did not project the test click")
		return
	var result: Variant = Commands.on_click_performed(screen, false, camera, body,
		func(_point): return false,
		func(cam, _actor, point): return ScreenProjection.project(cam, point),
		func(kind, direction, world):
			return Commands.execute(kind, direction, world, body, true, body, controller, route))
	if result != Commands.Failure.NONE or not body.execution.has_move_order():
		_refuse("projected viewport click did not queue a route on the original rule data")
		return
	for tick in range(6):
		await physics_frame
	if body.get_movement_position().distance_to(stopped) < 0.1:
		_refuse("projected click order did not move the real body")
		return
	var player := PlayerProvider.new()
	player.actor = body
	var map_events := MapEvents.new()
	var binding := Binding.new(camera, null, func(): return player, func(): return null, map_events)
	binding.on_enable()
	binding.start_binding()
	if not camera.advance_follow(0.0) or not camera.get_screen_center_position().is_equal_approx(body.global_position):
		binding.on_disable()
		_refuse("invalid camera state must snap to the bound actor before sampling")
		return
	var camera_from := camera.get_screen_center_position()
	var actor_from := body.global_position
	for tick in range(120):
		await physics_frame
		camera.advance_follow(0.02)
	var actor_delta := body.global_position - actor_from
	var camera_delta := camera.get_screen_center_position() - camera_from
	binding.on_disable()
	if actor_delta.length() < 0.1 or camera_delta.length() < 0.1 \
			or actor_delta.normalized().dot(camera_delta.normalized()) < 0.9:
		_refuse("actor/camera displacement failed source-validator thresholds in the isolated probe")
		return
	print("ClickMoveTest locked world route: PASS (source-damped follow; actor %.4f, screen center %.4f, alignment %.4f; no source colliders)" % [actor_delta.length(), camera_delta.length(), actor_delta.normalized().dot(camera_delta.normalized())])
	quit(0)
