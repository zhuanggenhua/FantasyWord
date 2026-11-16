extends SceneTree
## 显式逻辑宿主：没有美术或 GAS，不提供任何替代图像；不得当作正式游玩截图。
const Scene = preload("res://gameplay/clickmovetest/entry.tscn")
const Terrain = preload("res://game_core/movement/terrain_cast.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Movement = preload("res://game_core/movement/character_movement.gd")
class IsolatedOwner extends RefCounted:
	func can_move() -> bool: return true
	func calculate_move_speed() -> float: return 4.0
	func calculate_speed_multiplier() -> float: return 1.0
	func update_movement_animation(_value: Vector2) -> void: pass
	func update_facing_from_intent(_value: Vector2) -> void: pass
	func register_collision(_body: Object) -> void: pass
class Player extends RefCounted:
	signal controlled_character_changed(character: Node2D)
	var actor: Node2D
	func get_current_controlled_character_or_player_instance() -> Node2D: return actor
class MapEvents extends RefCounted:
	signal map_loaded
	signal map_unloaded
var over_ui := false
var failed := false
var checks := 0
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var rule_path := ""
	for arg in args:
		if arg.begins_with("--rules="): rule_path = arg.trim_prefix("--rules=")
	if not "--logic-only" in args or not FileAccess.file_exists(rule_path):
		printerr("拒绝启动：仅支持显式 --logic-only --rules=私有规则文件；正式素材与系统尚未接齐。")
		quit(1)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(rule_path))
	if not data is Dictionary:
		printerr("拒绝启动：规则不是有效字典。")
		quit(1)
		return
	root.size = Vector2i(800, 600)
	var host := Scene.instantiate()
	root.add_child(host)
	var player := Player.new()
	player.actor = host.actor
	var events := MapEvents.new()
	_check(host.actor.position == Vector2.ZERO, "运动根使用场景原点")
	_check(host.visual_body.position == Vector2(0.75, 3.1), "表现 Body 独立保留作者偏移")
	_check(host.camera.position == Vector2(0.75, 3.1), "绑定前保留序列化相机位置")
	if not host.start_logic(IsolatedOwner.new(), data, func(): return player,
			func(): return null, events, func(_point): return over_ui):
		printerr("拒绝启动：锁定规则或显式依赖不完整。")
		host.free()
		quit(1)
		return
	await process_frame
	await physics_frame
	_check(host.camera.follow == host.actor and host.camera.position == Vector2.ZERO,
		"无地图覆盖时运行期绑定跟随 Actor，不能跟随表现 Body")
	_check(host.movement.mode == Movement.Mode.CLICK_TO_MOVE, "面板首次启用点击模式")
	if not "--smoke" in args:
		print("逻辑启动切片已运行：只接输入、路径、原生物理与相机；无素材，无完整玩法。")
		return
	var destination := Vector2(4.5, 0)
	var screen: Vector2 = host.camera.get_canvas_transform() * Terrain.to_physics(destination)
	over_ui = true
	_mouse(screen, true)
	_check(host.command_count == 0, "UI 门禁阻止点击提交")
	over_ui = false
	host.blocked = true
	_mouse(screen, true)
	_check(host.command_count == 0, "输入阻塞阻止点击提交")
	host.blocked = false
	_mouse(screen, true)
	_check(host.command_count == 1 and host.actor.execution.has_move_order(), "真实视口点击产生原地图路径")
	_mouse(screen, false)
	_check(host.command_count == 1, "松开不重复提交")
	for tick in range(200):
		await physics_frame
		if not host.actor.execution.has_move_order(): break
	await physics_frame
	print("到达位置：", host.actor.get_movement_position(), "；目标：", destination)
	_check(not host.actor.execution.has_move_order() and host.actor.get_movement_position().distance_to(destination) <= Filter.effective_stop_distance(0.05) + 0.00001,
		"原生物理从原点沿源路径到达点击停止范围")
	_check(host.visual_body.position == Vector2(0.75, 3.1), "移动不吞掉表现局部偏移")
	_key(KEY_TAB, true)
	_key(KEY_TAB, false)
	for tick in range(3): await physics_frame
	_check(host.movement.mode == Movement.Mode.DIRECTIONAL, "首次默认模式不覆盖后续 Tab 切换")
	_key(KEY_TAB, true)
	_key(KEY_TAB, false)
	_mouse(host.camera.get_canvas_transform() * Terrain.to_physics(Vector2(7.5, 0)), true)
	_check(host.actor.execution.has_move_order(), "切换控制前已接受移动路径")
	player.actor = null
	var old_count: int = host.command_count
	var old_position: Vector2 = host.actor.position
	_key(KEY_D, true)
	for tick in range(5): await physics_frame
	_key(KEY_D, false)
	_check(host.command_count == old_count and host.actor.position != old_position and host.actor.execution.has_move_order(), "拒绝旧 Actor 新命令但不擅自取消已接受的路径")
	host.free()
	_check(not events.map_loaded.has_connections() and not player.controlled_character_changed.has_connections(), "退出解绑事件")
	if not failed: print("PASS ClickMoveTest 启动切片：%d 项；仅逻辑集成，不代表视觉或完整玩法验收" % checks)
	quit(1 if failed else 0)
func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)
func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error(detail)
