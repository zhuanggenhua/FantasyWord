extends SceneTree
const ScreenProjection = preload("res://game_core/presentation/orthographic_screen_projection.gd")
const Commands = preload("res://game_core/movement/movement_commands.gd")
var checks := 0
var failures := 0
var projection_calls := 0
var results: Array[Vector2] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)


func _project(camera, _role, point: Vector2) -> Variant:
	projection_calls += 1
	return ScreenProjection.project(camera, point)


func _submit(_command, _direction, world: Vector2) -> int:
	results.append(world)
	return Commands.Failure.NONE


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 600)
	root.add_child(viewport)
	var actor := Node2D.new()
	viewport.add_child(actor)
	var camera := Camera2D.new()
	camera.position = Vector2(0.75, 3.1) # Locked ClickMoveTest authored Unity XY, with Y reflected.
	camera.zoom = ScreenProjection.zoom_for_view_height(viewport.size.y, 5)
	viewport.add_child(camera)
	camera.make_current()
	await process_frame
	camera.force_update_scroll()
	_check(camera.zoom.is_equal_approx(Vector2(60,60)), "正交半高 5 对应屏幕总高 10 世界单位")
	_check(ScreenProjection.zoom_for_view_height(600, 0) == Vector2.ZERO, "无效镜头尺寸不生成比例")
	_check(ScreenProjection.project(camera, Vector2(400,300)).is_equal_approx(Vector2(0.75,-3.1)), "点击视口中心得到原场景作者相机 XY")
	_check(ScreenProjection.project(camera, Vector2(600,300)).is_equal_approx(Vector2(0.75 + 10.0/3.0,-3.1)), "四分之三宽点击的比例来自真实画布")
	_check(ScreenProjection.project(camera, Vector2(400,0)).is_equal_approx(Vector2(0.75,1.9)), "画面上方对应 Unity Y 正向")
	camera.limit_right = 8
	camera.position = Vector2(20,2)
	camera.force_update_scroll()
	var center: Vector2 = ScreenProjection.project(camera, Vector2(400,300))
	_check(center.is_equal_approx(Vector2(1.333333,-2)), "限位后投影采用实际画布中心")
	_check(not center.is_equal_approx(Vector2(20,-2)), "不能用相机节点位置代替输出")
	var screen := Vector2(600, 300)
	var allow := func(_point): return false
	var block_ui := func(_point): return true
	_check(Commands.on_click_performed(screen, true, camera, actor, allow, _project, _submit) == null, "动作阻断先不投影")
	_check(Commands.on_click_performed(screen, false, camera, actor, block_ui, _project, _submit) == null, "UI 阻断先不投影")
	_check(projection_calls == 0 and results.is_empty(), "两个门禁都不调用镜头或角色")
	_check(Commands.on_click_performed(screen, false, camera, actor, allow, _project, _submit) == Commands.Failure.NONE, "原点击动作接入真实画布投影")
	_check(projection_calls == 1 and results.size() == 1 and results[0].is_equal_approx(Vector2(4.666667,-2)), "实际相机边界下保留世界点击值")
	var not_active := Camera2D.new()
	viewport.add_child(not_active)
	_check(ScreenProjection.project(not_active, screen) == null, "非当前相机不能作投影")
	_check(Commands.on_click_performed(screen, false, not_active, actor, allow, _project, _submit) == null and results.size() == 1, "投影失败不发原点移动")
	_check(ScreenProjection.project(camera, Vector2(INF,0)) == null, "非有限屏幕点拒绝")
	print("PASS 原生镜头屏幕投影：%d 项，失败 %d" % [checks, failures])
	quit(int(failures > 0))
