extends SceneTree
const FollowCamera = preload("res://game_core/presentation/world_space_camera_follow.gd")
const ScreenProjection = preload("res://game_core/presentation/orthographic_screen_projection.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800,600)
	root.add_child(viewport)
	var actor := Node2D.new()
	viewport.add_child(actor)
	actor.position = Vector2(2,-3)
	var camera = FollowCamera.new()
	viewport.add_child(camera)
	camera.zoom = ScreenProjection.zoom_for_view_height(600,5)
	camera.make_current()
	camera.follow = actor
	await process_frame
	_check(not camera.position_smoothing_enabled and not camera.rotation_smoothing_enabled, "禁止二次原生平滑")
	_check(camera.advance_follow(0.0), "无有效前态时允许零时间初始化")
	_check(camera.global_position.is_equal_approx(actor.global_position), "首次失效状态吸附目标")
	_check(ScreenProjection.project(camera,Vector2(400,300)).is_equal_approx(Vector2(2,3)), "真实画布中心随首次吸附更新")
	actor.position = Vector2(12,7)
	camera.advance_follow(0.5)
	_check(camera.global_position.is_equal_approx(Vector2(11,6)), "源一秒消除99百分比残差：半秒消除90百分比")
	_check(ScreenProjection.project(camera,Vector2(400,300)).is_equal_approx(Vector2(11,-6)), "阻尼后真实画布不是原位置或未阻尼目标")
	_check(ScreenProjection.project(camera,Vector2(400,0)).is_equal_approx(Vector2(11,-1)), "移动后正交半高保持5")
	camera.advance_follow(0.5)
	_check(camera.global_position.is_equal_approx(Vector2(11.9,6.9)), "第二半秒累计残差百分之一")
	actor.position = Vector2(100,-50)
	camera.advance_follow(0.0)
	_check(camera.global_position.is_equal_approx(Vector2(11.9,6.9)), "有效前态零时间不追大位移")
	camera.previous_state_is_valid = false
	camera.advance_follow(0.0)
	_check(camera.global_position.is_equal_approx(actor.position), "绑定层传送失效吸附")
	actor.position = Vector2(-5,8)
	camera.advance_follow(-1.0)
	_check(camera.global_position.is_equal_approx(actor.position), "源负时间使前态失效")
	_check(FollowCamera.standard_damp(0.00001,1,0) == 0.00001, "小分量优先于时间门禁")
	_check(FollowCamera.standard_damp(1,0,0) == 1, "零阻尼优先于时间门禁")
	_check(FollowCamera.standard_damp(-10,1,0.5) < -8.99999, "负位移同样衰减")
	_check(FollowCamera.standard_damp(10,1,0.00001) == 0, "微小时间门禁")
	actor.position = camera.position + Vector2(0.00001,1)
	camera.advance_follow(0)
	_check(absf(camera.position.x-actor.position.x)<0.000001 and absf(camera.position.y-actor.position.y+1)<0.000001, "epsilon 按轴而非向量长度")
	var before: Vector2 = camera.position
	camera.follow = null
	_check(not camera.advance_follow(1) and camera.position == before, "无目标不凭空追原点")
	camera.follow = actor
	_check(not camera.advance_follow(NAN) and camera.position == before, "非有限时间拒绝污染画布")
	actor.free()
	_check(not camera.advance_follow(1), "已释放目标不访问失效节点")
	print("PASS 世界空间镜头跟随：%d 项，失败 %d" % [checks,failures])
	quit(int(failures > 0))
