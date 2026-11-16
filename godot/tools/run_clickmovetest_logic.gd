extends SceneTree
## 显式逻辑宿主：没有美术或 GAS，不提供任何替代图像；不得当作正式游玩截图。
const PointerPolicy = preload("res://game_core/ui/pointer_blocker_policy.gd")
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
var gui_clicks := 0
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
			func(): return null, events, _ui_guard):
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
	# 实际 Viewport/Control 消费输入，不替换为直接调用 _input。
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var blocker := Control.new()
	blocker.position = screen - Vector2(20, 20)
	blocker.size = Vector2(40, 40)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(blocker)
	blocker.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			gui_clicks += 1
			blocker.accept_event())
	await process_frame
	host.set_process(false)
	over_ui = true
	_mouse(screen, true)
	_check(gui_clicks == 1 and host.command_count == 0, "Control STOP 真实消费点击而非命令接受")
	_check(host.click_observation.latest.over_ui and host.click_observation.latest.projection_valid,
		"GUI 消费仍先观察且 UI 阻挡不跳过投影")
	_check(host.click_observation.latest.had_input_target and host.click_observation.latest.could_move,
		"观察当前绑定目标与动作能力")
	host._process(0)
	_check(host.click_observation.pending_frames == 0 and not host.click_observation.latest.has("order_after_updates"),
		"首次更新只递减")
	host._process(0)
	_check(not host.click_observation.latest.order_after_updates and host.click_observation.latest.position_after_updates == host.actor.get_movement_position(),
		"第二次更新读取实际运动根")
	_mouse(screen, false)
	over_ui = false
	_mouse(screen, true)
	_check(gui_clicks == 2 and host.command_count == 0 and not host.click_observation.latest.over_ui,
		"原生 Control 消费与显式 UI 判定分开记录，不宣称等价")
	_mouse(screen, false)
	layer.free()
	host.set_process(true)
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
	var latest_screen: Vector2 = host.click_observation.latest.screen_position
	_mouse(screen, false)
	_check(host.click_observation.latest.screen_position == latest_screen, "松开不覆盖观察")
	_check(host.command_count == 1, "松开不重复提交")
	# 新的 UI 拒绝点击可能读到旧路径仍在运行，不能归因为新指令。
	over_ui = true
	_mouse(screen + Vector2(1, 0), true)
	_check(host.command_count == 1 and host.click_observation.latest.order_before_dispatch,
		"被拒绝新点击保留旧订单，单独记录先前状态")
	host.set_process(false)
	host._process(0)
	host._process(0)
	_check(host.click_observation.latest.order_after_updates, "延迟订单为实际当前订单，不标作新命令")
	host.set_process(true)
	over_ui = false
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

# 显式命中元数据注入，不冒充 Godot 或 Unity 的真实射线枚举。
func _ui_guard(_point: Vector2) -> bool:
	var hits := [{"object_present": true, "name": "Mask", "canvas_groups": [],
		"graphic_present": true, "raycast_target": true}]
	if over_ui:
		hits.append({"object_present": true, "name": "下层独立阻挡", "canvas_groups": [],
			"graphic_present": true, "raycast_target": true})
	return PointerPolicy.is_over_ui(hits, true)
