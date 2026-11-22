extends SceneTree
## 锁定原 ClickMoveTest 项目启动；不替换角色、纹理或朝向能力。
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
var total := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var source := OS.get_environment("FORMAL_PAUSE_SOURCE")
	var atlas := OS.get_environment("FORMAL_MOVEMENT_INDICATOR_ATLAS")
	if atlas.is_empty() and not source.is_empty():
		atlas=source.path_join("SPS_GUI.png")
	if atlas.is_empty() or not FileAccess.file_exists(atlas):
		printerr("需要私有锁定的 SPS_GUI.png；未运行场景。")
		quit(2)
		return
	root.size=Vector2i(800,600)
	if change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))!=OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var boot := current_scene as Boot
	if boot==null or boot.scene==null:
		_check(false,"正式原图启动失败")
		_finish()
		return
	var indicator: Node2D = boot.scene.actor.get_node_or_null("Polydirectional Pivot")
	_check(indicator!=null,"普通 F5 将原旋转 Pivot 装到实际主角")
	if indicator==null:
		_finish()
		return
	_check((boot.pause_root!=null)==(not source.is_empty()),"提示与暂停入口无双向依赖")
	boot.scene.training_target.ai_controller.stop()
	_check(not boot.scene.training_target.has_node("Polydirectional Pivot"),"不把尚未验证的训练假人朝向门控当作等价")
	var arrow := indicator.get_node_or_null("Movement Indicator") as Sprite2D
	_check(arrow!=null,"原 8×8 指示器是旋转 Pivot 子项")
	if arrow==null:
		_finish()
		return
	var image := Image.load_from_file(atlas)
	var crop := image.get_region(Rect2i(112,88,8,8))
	crop.convert(Image.FORMAT_RGBA8)
	var mounted := arrow.texture.get_image()
	mounted.convert(Image.FORMAT_RGBA8)
	_check(mounted.get_size()==Vector2i(8,8) and mounted.get_data()==crop.get_data(),"图集实际原像素裁切")
	_check(arrow.centered and arrow.scale.is_equal_approx(Vector2.ONE/16.0)
		and arrow.position.is_equal_approx(Vector2(.682,0)) and indicator.position.is_equal_approx(Vector2(0,-.4))
		and arrow.z_index==0 and is_equal_approx(arrow.self_modulate.a,.4509804),"原 PPU、中心、偏移、顺序及 alpha")
	var static_pivot: Node2D = boot.scene.aim_pivot
	var static_pose := static_pivot.transform
	for direction in [Vector2(1,1),Vector2(-1,1),Vector2.UP,Vector2.DOWN]:
		boot.player.set_target_direction(direction.normalized())
		var local_tip := (indicator.transform*arrow.position)-indicator.position
		_check(local_tip.is_equal_approx(Vector2(direction.x,-direction.y).normalized()*.682)
			and signf(indicator.transform.determinant())==(1.0 if direction.x>0 else -1.0),
			"实际朝向信号、旋转及 X<=0 反射 " + str(direction))
	_check(static_pivot.transform.is_equal_approx(static_pose),"仅旋转表现 Pivot，不改静态技能/交互挂点")
	var mouse := InputEventMouseMotion.new()
	mouse.position=Vector2(465,300)
	mouse.relative=Vector2.ONE
	root.push_input(mouse,true)
	await process_frame
	_key(KEY_Q,true)
	var deadline := Time.get_ticks_msec()+2000
	while boot.player.can_update_target_direction() and Time.get_ticks_msec()<deadline:
		await physics_frame
	_check(not boot.player.can_update_target_direction(),"实际 Q 技能锁定原朝向门")
	paused=true
	Engine.time_scale=0.0
	var start_alpha := arrow.self_modulate.a
	await create_timer(.30,true,false,true).timeout
	_check(arrow.self_modulate.a<.015 and arrow.self_modulate.a<start_alpha,"树暂停期间仍以真实时钟淡出")
	Engine.time_scale=1.0
	paused=false
	_key(KEY_Q,false)
	deadline=Time.get_ticks_msec()+3000
	while not boot.player.can_update_target_direction() and Time.get_ticks_msec()<deadline:
		await physics_frame
	await create_timer(.30,true,false,true).timeout
	_check(boot.player.can_update_target_direction() and absf(arrow.self_modulate.a-.4509804)<.01,"松开真实 Q 后恢复原透明度")
	_finish()

func _key(code: Key,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	root.push_input(event,true)

func _check(ok: bool,label: String) -> void:
	total+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func _finish() -> void:
	print("%s ClickMoveTest 主角原目标方向提示：%d/%d" % ["PASS" if failures==0 else "FAIL",total-failures,total])
	quit(0 if failures==0 else 1)
