extends Node2D
## 显式诊断宿主，不是原版 ClickMoveTest 场景或 PlayerSystem。
## 颜色与标记仅可视化规则坐标，不代替原版美术。
const Body = preload("res://game_core/movement/native_motion_body.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Keyboard = preload("res://game_core/movement/keyboard_movement_input.gd")
const Commands = preload("res://game_core/movement/movement_commands.gd")
const Movement = preload("res://game_core/movement/character_movement.gd")
const Follow = preload("res://game_core/presentation/world_space_camera_follow.gd")
const SourceFixedStep = preload("res://game_core/movement/source_fixed_step.gd")
const ScreenProjection = preload("res://game_core/presentation/orthographic_screen_projection.gd")
const Terrain = preload("res://game_core/movement/terrain_cast.gd")
const Route = preload("res://game_core/navigation/terrain_world_route.gd")
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"

# 显式隔离角色配置取基础预制体值，不是 GAS 计算结果。
@export var base_speed := 4.0
@export var acceleration := 10.0
@export var deceleration := 10.0
@export var source_start := Vector2.ZERO
var body: AnimatableBody2D
var camera: Camera2D
var movement: RefCounted
var keyboard := Keyboard.new()
var rules: Array = []
var route: RefCounted
var blocked := false
var steps := 0
var last_direction := Vector2.ZERO
var last_command: Variant
var command_count := 0
var _status: Label

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--rules="):
			if not load_rules(argument.trim_prefix("--rules=")):
				push_error("私有规则数据缺失或版本不符，拒绝启动")
				get_tree().quit(1)
				return
	body = Body.new()
	body.position = Terrain.to_physics(source_start)
	body.collision_layer = 256
	body.collision_mask = 0 # 只查询，不猜测 Physics2D 接触矩阵。
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 0.39
	capsule.height = 0.86
	shape.shape = capsule
	shape.position = Vector2(0, -0.42)
	body.add_child(shape)
	add_child(body)
	body.configure_movement(shape, Filter.new(Filter.Mode.FREE, false, 0.05,
		acceleration, deceleration), self, 7752)
	movement = Movement.new(body, 0.05)
	movement.set_movement_control_mode(Movement.Mode.CLICK_TO_MOVE) # 原面板的初始模式。
	camera = Follow.new()
	add_child(camera)
	camera.follow = body
	camera.make_current()
	_resize_camera()
	camera.advance_follow(0.0)
	get_viewport().size_changed.connect(_resize_camera)
	var overlay := CanvasLayer.new()
	add_child(overlay)
	_status = Label.new()
	_status.position = Vector2(12, 12)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_status)

func load_rules(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("source_commit") != SOURCE \
			or data.get("rule_tilemap") != 1361196487 or not data.get("rows") is Array \
			or data.rows.size() != 900:
		return false
	var candidate := Route.new(data.rows, int(data.nearest_radius),
		func(layer, world): return Vector3i(floori(world.x), floori(world.y), 0) if layer == 0 else null,
		func(cell): return Vector2(cell.y + 0.5, cell.z + 0.5))
	if candidate.graph.node_count() != 649:
		return false
	route = candidate
	rules = data.rows
	return true

func _resize_camera() -> void:
	camera.zoom = ScreenProjection.zoom_for_view_height(get_viewport_rect().size.y, 5.0)
	camera.force_update_scroll()

func _input(event: InputEvent) -> void:
	if movement == null:
		return
	if event is InputEventKey:
		if event.physical_keycode == KEY_TAB and event.pressed and not event.echo:
			Commands.on_toggle_performed(_submit)
		keyboard.handle_key(event, blocked, _submit)

# 诊断没有可交互 UI；若加真实 Control，其消耗事件不会进入此入口。
# 这是 Godot 本机门禁，不冒充原 EventSystem/UIPointerUtility 完整迁移。
func _unhandled_input(event: InputEvent) -> void:
	if movement == null or route == null:
		return # 没有原地图就拒绝点击，不走身体尚未实现的合法落点兜底。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Commands.on_click_performed(event.position, blocked, camera, body,
			func(_point): return false,
			func(cam, _actor, point): return ScreenProjection.project(cam, point), _submit)

func _submit(kind: int, direction: Vector2, point: Variant) -> int:
	last_command = kind
	command_count += 1
	return Commands.submit_single_character(kind, direction, point, body, true,
		body, true, true, body, movement, route)

func _physics_process(_native_delta: float) -> void:
	if movement != null:
		body.advance_movement(SourceFixedStep.GAMEPLAY_DELTA_SECONDS)
		steps += 1

func _process(delta: float) -> void:
	if movement == null:
		return
	camera.advance_follow(delta)
	_status.text = "仅移动诊断 | 左键点地 / Tab 切换 / WASD / 方向键\n未接原版美术、界面、GAS、接触场景；未验收 Unity 时序\n%s | 模式 %s | 原坐标 %s" % [
		"已加载锁定规则坐标（不是物理墙）" if route != null else "未加载原地图，点击停用", "方向" if movement.mode == Movement.Mode.DIRECTIONAL else "点击", body.get_movement_position()]
	queue_redraw()

func _draw() -> void:
	for row in rules:
		var color := Color(0.12, 0.22, 0.18) if row.walkable else Color(0.23, 0.12, 0.14)
		draw_rect(Rect2(Vector2(row.cell[0], -row.cell[1]-1), Vector2.ONE), color)
	if is_instance_valid(body):
		draw_circle(body.position, 0.12, Color(0.9, 0.9, 0.2))
		draw_line(body.position, body.position + Terrain.to_physics(last_direction) * 0.5, Color.WHITE, 0.03)

func can_move() -> bool: return true
func calculate_move_speed() -> float: return base_speed
func calculate_speed_multiplier() -> float: return 1.0
func update_movement_animation(value: Vector2) -> void: last_direction = value
func update_facing_from_intent(_value: Vector2) -> void: pass
func register_collision(_body: Object) -> void: pass
