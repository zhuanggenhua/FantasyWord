extends SceneTree
## 从 project.godot 的真正入口启动；不挂旧预览脚本或伪造角色。
const Startup := preload("res://gameplay/clickmovetest/source_startup.gd")
const Entry := preload("res://gameplay/clickmovetest/entry.gd")
const Player := preload("res://gameplay/clickmovetest/single_player_actor.gd")
const Move := preload("res://game_core/movement/character_movement.gd")
const Point := preload("res://game_core/input/mouse_point_actions.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene","")
	_check(path=="res://gameplay/clickmovetest/source_startup.tscn" and ResourceLoader.exists(path),
		"项目配置直接选择唯一原图启动场景")
	if failures>0:
		_finish()
		return
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 私有原图启动与交互；需显式原始资源，不用替代图")
		_finish()
		return
	root.size=Vector2i(800,600)
	Engine.time_scale=.8
	_check(change_scene_to_file(path)==OK,"以 SceneTree 的正式场景入口加载")
	if failures>0:
		_finish()
		return
	await scene_changed
	await process_frame
	await process_frame
	var startup := current_scene as Startup
	_check(_has_one_authored_map(startup),
		"实际主场景宿主持有且只持有一份原地图")
	if failures>0:
		_finish()
		return
	var scene := startup.scene
	var actor: Node2D = scene.actor
	_check(Engine.time_scale==1.0 and actor.get_movement_position()==Vector2.ZERO
		and startup.player.is_current_controlled(actor) and scene.camera.follow==actor,
		"正常时间、原点出生、当前控制和镜头使用同一主角")
	_check(startup.maps.get_active_terrain_navigation_map()==scene.route and scene.route.graph.node_count()==649
		and scene.ground_layers.cell_count(-1)==900 and scene.ground_layers.water_base_count()==87,
		"真实地图配对原导航与地面水格")
	_check(startup.persistables.resolve(Player.UNIQUE_PLAYER_IDENTIFIER)==actor
		and startup.persistables.resolve(Player.SOURCE_PREINSTANCED_IDENTIFIER)==null
		and not startup.persistables.automatically_persisted(actor),
		"只替换原主角持久化身份，启动不触发通用自动存档")
	var panel: ColorRect=scene.control_panel
	_check(scene.human_presentation.driver.current_animation_key=="Idle" and is_instance_valid(scene.water_reflection)
		and is_instance_valid(startup.damage_screen_flash) and startup.damage_screen_flash.color.a==0.0
		and startup.damage_screen_flash.mouse_filter==Control.MOUSE_FILTER_IGNORE
		and is_instance_valid(panel) and panel.body.text.contains("还没有收到 Gameplay 点击输入")
		and is_instance_valid(scene.training_target) and is_instance_valid(scene.surface_contact_damage),"原主角、倒影、面板和闪屏及地表接收及唯一原活动假人正常")
	if failures>0:
		_finish()
		return
	# 使用已核实的面板内部坐标，验证不是 Escape 或鼠标移动测试的替代路径。
	var screen := Vector2(430,245)
	var rect := Rect2(panel.position,panel.size*panel.scale)
	_check(rect.has_point(screen),"点击处实际在原面板覆盖范围")
	var motion := InputEventMouseMotion.new()
	motion.device=0
	motion.position=screen
	motion.relative=Vector2(1,1)
	root.push_input(motion,true)
	await process_frame
	var click := InputEventMouseButton.new()
	click.device=0 # 正式配对鼠标，注入事件不使用默认模拟设备号。
	click.position=screen
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	root.push_input(click,true)
	var release: InputEventMouseButton=click.duplicate()
	release.pressed=false
	root.push_input(release,true)
	_check(startup.point.read_active(Point.Map.GAMEPLAY)==screen
		and startup.point.read_active(Point.Map.UI)==null
		and not scene.click_observation.latest.get("over_ui",true)
		and scene.command_count==1 and actor.execution.has_move_order(),
		"原 Gameplay Point 和面板内真实点击穿透到原导航")
	var walked := false
	for i in range(200):
		await physics_frame
		walked = walked or scene.human_presentation.driver.current_animation_key=="Walk"
		if not actor.execution.has_move_order(): break
	_check(walked and not actor.execution.has_move_order() and actor.get_movement_position().length()>.1,
		"正式入口的原角色沿接收的路线移动并停下")
	_key(KEY_TAB,true)
	_key(KEY_TAB,false)
	await process_frame
	var previous: Vector2=actor.get_movement_position()
	_key(KEY_D,true)
	for i in range(12): await physics_frame
	_key(KEY_D,false)
	_check(scene.movement.mode==Move.Mode.DIRECTIONAL and actor.get_movement_position().x>previous.x+.1,
		"Tab 切换真实模式，并在同一角色上执行 WASD")
	if DisplayServer.get_name()!="headless":
		# 真正渲染的诊断文字须改变屏幕像素，不以文字属性冒充画面。
		await RenderingServer.frame_post_draw
		var shown := root.get_texture().get_image()
		panel.body.hide()
		await RenderingServer.frame_post_draw
		var hidden := root.get_texture().get_image()
		panel.body.show()
		var changed := 0
		for y in range(55,mini(303,shown.get_height()),2):
			for x in range(20,mini(630,shown.get_width()),2):
				if shown.get_pixel(x,y)!=hidden.get_pixel(x,y): changed+=1
		_check(changed>200,"正式入口的原面板实际渲染非空字形")
		print("原生启动面板可见样本：",changed)
	var first: WeakRef = weakref(startup)
	_check(reload_current_scene()==OK,"引擎支持从相同项目入口重新启动该场景")
	if failures>0:
		_finish()
		return
	await scene_changed
	await process_frame
	await process_frame
	var next := current_scene as Startup
	_check(first.get_ref()==null and _has_one_authored_map(next)
		and next.player.is_current_controlled(next.scene.actor)
		and next.scene.actor.get_movement_position()==Vector2.ZERO
		and next.scene.command_count==0 and next.persistables.resolve("player")==next.scene.actor,
		"退出释放旧宿主，重新打开只登记一个原点角色且没有沿用输入")
	# 仅测试注入小地形，不动原场景资源；不提交移动命令，验证固定步主动脱墙。
	var original_body: Node2D = next.scene.actor
	var trainer: Node2D = next.scene.training_target
	trainer.ai_controller.stop()
	trainer.body.reset_movement()
	for i in 3: await physics_frame
	var trainer_start: Vector2 = trainer.body.get_movement_position()
	var wall := _embed_at(next.scene.actor_shape.global_position)
	var trainer_wall := _embed_at(trainer.body.global_position+Vector2(0,-trainer.BODY_OFFSET.y))
	for i in 4: await physics_frame
	_check(original_body.get_movement_position().is_equal_approx(Vector2(0,.625))
		and next.player.is_current_controlled(original_body) and next.scene.camera.follow==original_body
		and not original_body.execution.has_move_order() and next.scene.command_count==0,
		"真实入口的原主角无输入也先向原 +Y 脱墙，不替换角色、镜头或补造命令")
	_check(trainer.body.get_movement_position().is_equal_approx(trainer_start+Vector2(0,.625))
		and next.scene.training_target==trainer and not trainer.body.execution.has_move_order(),
		"同一正式场景的原训练假人继承脱墙，不生成另一个角色或移动命令")
	wall.free(); trainer_wall.free()
	_finish()

func _embed_at(point: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer=8
	wall.position=point
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size=Vector2(.1,.1)
	collider.shape=rectangle
	wall.add_child(collider)
	root.add_child(wall)
	return wall

func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=down
	root.push_input(event,true)

func _has_one_authored_map(startup: Startup) -> bool:
	return is_instance_valid(startup) and is_instance_valid(startup.scene) \
		and startup.get_children().filter(func(child): return child.get_script()==Entry)==[startup.scene]


func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)

func _finish() -> void:
	if not failures: print("PASS 原 ClickMoveTest 项目启动：%d 项（%s）" % [checks,DisplayServer.get_name()])
	quit(1 if failures else 0)
