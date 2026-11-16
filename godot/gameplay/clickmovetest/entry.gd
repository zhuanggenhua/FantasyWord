extends Node2D
## ClickMoveTest 的可注入启动切片。无正式素材、GAS 和系统宿主时不自行补依赖。
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Movement = preload("res://game_core/movement/character_movement.gd")
const Commands = preload("res://game_core/movement/movement_commands.gd")
const Keyboard = preload("res://game_core/movement/keyboard_movement_input.gd")
const Route = preload("res://game_core/navigation/terrain_world_route.gd")
const Binding = preload("res://game_core/presentation/player_camera_binding.gd")
const ScreenProjection = preload("res://game_core/presentation/orthographic_screen_projection.gd")
const Step = preload("res://game_core/movement/source_fixed_step.gd")
const Observation = preload("res://gameplay/clickmovetest/click_observation.gd")
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
@export var actor: AnimatableBody2D
@export var actor_shape: CollisionShape2D
@export var visual_body: Node2D
@export var camera: Camera2D
var movement: RefCounted
var route: RefCounted
var binding: RefCounted
var blocked := false
var command_count := 0
var last_result: Variant
var click_observation := Observation.new()
var keyboard := Keyboard.new()
var _ui_guard: Callable
var _player_provider: Callable

## 宿主明确选中的玩家、地图事件、动作能力与 UI 门禁均由调用者提供。
## 此阶段不宣称提供完整 PlayerSystem、GAS、地图加载或视觉资源。
func start_logic(owner: Object, data: Dictionary, player_provider: Callable,
		map_provider: Callable, map_events: Object, ui_guard: Callable) -> bool:
	if movement != null or not is_inside_tree() or not is_instance_valid(owner) \
			or not player_provider.is_valid() or not map_provider.is_valid() \
			or not is_instance_valid(map_events) or not ui_guard.is_valid():
		return false
	if not valid_rules(data) or not map_events.has_signal("map_loaded") \
			or not map_events.has_signal("map_unloaded"): return false
	var player: Object = player_provider.call()
	if not is_instance_valid(player) or not player.has_signal("controlled_character_changed") \
			or not player.has_method("get_current_controlled_character_or_player_instance") \
			or player.get_current_controlled_character_or_player_instance() != actor: return false
	for method in ["can_move", "calculate_move_speed", "calculate_speed_multiplier",
			"update_movement_animation", "update_facing_from_intent", "register_collision"]:
		if not owner.has_method(method): return false
	var candidate := Route.new(data.rows, int(data.nearest_radius),
		func(layer, world): return Vector3i(floori(world.x), floori(world.y), 0) if layer == 0 else null,
		func(cell): return Vector2(cell.y + 0.5, cell.z + 0.5))
	if candidate.graph.node_count() != 649: return false
	# 不将表现 Body 错接成运动主体，也不将场景静态相机姿态当运行期跟随目标。
	if not is_instance_valid(actor) or not is_instance_valid(actor_shape) \
			or not is_instance_valid(camera) or not is_instance_valid(visual_body): return false
	actor.configure_movement(actor_shape, Filter.new(Filter.Mode.FREE, false, 0.05, 10.0, 10.0), owner, 7752)
	route = candidate
	movement = Movement.new(actor, 0.05)
	movement.set_movement_control_mode(Movement.Mode.CLICK_TO_MOVE)
	_ui_guard = ui_guard
	_player_provider = player_provider
	binding = Binding.new(camera, null, player_provider, map_provider, map_events)
	binding.on_enable()
	binding.start_binding()
	camera.make_current()
	_resize_camera()
	camera.advance_follow(0.0)
	get_viewport().size_changed.connect(_resize_camera)
	return true

func _resize_camera() -> void:
	camera.zoom = ScreenProjection.zoom_for_view_height(get_viewport_rect().size.y, 5.0)
	camera.force_update_scroll()

func _input(event: InputEvent) -> void:
	if movement == null: return
	# 原生 GUI 可能在 _unhandled_input 前消费点击；观察必须先于该阶段。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var owned := _owns_current_actor()
		var projected: Variant = ScreenProjection.project(camera, event.position) if owned else null
		click_observation.observe({
			"frame": Engine.get_process_frames(), "screen_position": event.position,
			"over_ui": bool(_ui_guard.call(event.position)),
			"had_input_target": owned, "could_move": owned and actor.can_move(),
			"movement_mode": movement.mode,
			"projection_valid": projected is Vector2,
			"world_position": projected if projected is Vector2 else Vector2.ZERO,
			"order_before_dispatch": owned and actor.execution.has_move_order(),
		})
	if event is InputEventKey:
		if event.physical_keycode == KEY_TAB and event.pressed and not event.echo:
			Commands.on_toggle_performed(_submit)
		keyboard.handle_key(event, blocked, _submit)

func _unhandled_input(event: InputEvent) -> void:
	if movement == null: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Commands.on_click_performed(event.position, blocked, camera, actor, _ui_guard,
			func(cam, _actor, point): return ScreenProjection.project(cam, point), _submit)

func _submit(kind: int, direction: Vector2, point: Variant) -> int:
	if not _owns_current_actor():
		last_result = Commands.Failure.ACTOR_MISMATCH
		return last_result
	command_count += 1
	last_result = Commands.submit_single_character(kind, direction, point, actor, true,
		actor, true, true, actor, movement, route)
	return last_result

func _physics_process(_delta: float) -> void:
	if movement != null:
		actor.advance_movement(Step.GAMEPLAY_DELTA_SECONDS)

func _process(delta: float) -> void:
	click_observation.advance(func():
		var owned := _owns_current_actor()
		return {"order": owned and actor.execution.has_move_order(),
			"position": actor.get_movement_position() if owned else Vector2.ZERO})
	if binding != null: camera.advance_follow(delta)

func _exit_tree() -> void:
	if binding != null:
		binding.on_disable()
		binding = null

func _owns_current_actor() -> bool:
	var player: Object = _player_provider.call()
	return is_instance_valid(player) and player.has_method("get_current_controlled_character_or_player_instance") \
		and player.get_current_controlled_character_or_player_instance() == actor

## 外部派生文件在构造导航图前验证结构，避免部分启动后才触发断言。
static func valid_rules(data: Dictionary) -> bool:
	if data.get("schema") != 1 or data.get("source_commit") != SOURCE \
			or data.get("rule_tilemap") != 1361196487 or not data.get("rows") is Array \
			or data.rows.size() != 900 or data.get("nearest_radius") != 2: return false
	var seen := {}
	for row in data.rows:
		if not row is Dictionary or not row.get("cell") is Array or row.cell.size() != 3 \
				or not row.get("walkable") is bool: return false
		for value in row.cell:
			if not _integer(value): return false
		if row.cell[2] != 0: return false
		var cell := Vector3i(row.cell[0], row.cell[1], row.cell[2])
		if seen.has(cell): return false
		seen[cell] = true
		for field in ["elevation", "transition", "ramp", "surface"]:
			if not _integer(row.get(field)): return false
		var cost: Variant = row.get("cost")
		if not (cost is float or cost is int) or not is_finite(float(cost)): return false
	return true

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))
