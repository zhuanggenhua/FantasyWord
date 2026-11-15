extends SceneTree
const Scene = preload("res://validation/scenes/keyboard_motion_fixture.tscn")
const Movement = preload("res://game_core/movement/character_movement.gd")
const Terrain = preload("res://game_core/movement/terrain_cast.gd")
const Commands = preload("res://game_core/movement/movement_commands.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(800, 600)
	var host := Scene.instantiate()
	root.add_child(host)
	await process_frame
	await physics_frame
	var loaded: bool = host.route != null
	_check(loaded or host.rules.is_empty(), "不制造备用地图")
	_check(host.movement.mode == Movement.Mode.CLICK_TO_MOVE, "原场景默认点击模式")
	_key(KEY_TAB, true)
	_key(KEY_TAB, false)
	_check(host.movement.mode == Movement.Mode.DIRECTIONAL, "Tab 切至方向模式")
	_check(not host.load_rules("/nonexistent/private-map.json"), "拒绝缺失的私有地图")
	var origin: Vector2 = host.body.get_movement_position()
	_key(KEY_W, true)
	for step in range(20): await physics_frame
	var north: Vector2 = host.body.get_movement_position()
	_check(north.y > origin.y + 0.3 and absf(north.x-origin.x)<0.001, "视口 W 驱动真实原生身体向北")
	_check(host.camera.get_screen_center_position().y < -0.1, "真实阻尼相机跟随身体")
	_key(KEY_RIGHT, true)
	for step in range(5): await physics_frame
	_check(absf(host.body.get_movement_position().x-origin.x)<0.001, "等强方向键组不夺取输入")
	_key(KEY_W, false)
	for step in range(10): await physics_frame
	_check(host.body.get_movement_position().x > origin.x + 0.1, "释放当前组交接向右输入")
	host.blocked = true
	_key(KEY_RIGHT, false)
	await physics_frame
	await physics_frame
	var stop: Vector2 = host.body.get_movement_position()
	for step in range(5): await physics_frame
	_check(host.last_command == Commands.Kind.STOP_MOVE and host.body.get_movement_position() == stop, "门禁下释放停止后续物理步")
	_key(KEY_D, true)
	for step in range(3): await physics_frame
	_check(host.body.get_movement_position() == stop, "门禁下 performed 不移动")
	_key(KEY_D, false)
	host.blocked = false
	_key(KEY_S, true)
	for step in range(10): await physics_frame
	_key(KEY_S, false)
	_check(host.body.get_movement_position().y < stop.y - 0.1, "重复释放后重新移动")
	_check(host.steps >= 50, "真实场景物理驱动已执行")
	_key(KEY_TAB, true)
	_key(KEY_TAB, false)
	_check(host.movement.mode == Movement.Mode.CLICK_TO_MOVE, "Tab 切回点击模式")
	var before_click: Vector2 = host.body.get_movement_position()
	var click_point: Vector2 = host.camera.get_canvas_transform() * Terrain.to_physics(Vector2(4.5, 0.5))
	_mouse(click_point, true)
	if loaded:
		_check(host.body.execution.has_move_order(), "私有源图经视口点击产生真实路径")
		var click_count: int = host.command_count
		_mouse(click_point, false)
		_check(host.command_count == click_count, "松开左键不重复发点击")
		for step in range(25): await physics_frame
		_check(host.body.get_movement_position().distance_to(before_click) > 0.1, "点击源路径驱动真实身体")
		_key(KEY_TAB, true)
		_key(KEY_TAB, false)
		_check(not host.body.execution.has_move_order(), "切换模式清掉在途路径")
	else:
		_check(not host.body.execution.has_move_order(), "无原图时拒绝点击而非直线兜底")
		_mouse(click_point, false)
	host.queue_free()
	await process_frame
	if failures == 0: print("PASS 原生移动诊断场景：%d 项" % checks)
	quit(1 if failures else 0)
func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)
func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
