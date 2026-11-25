extends SceneTree
## Real F5, original water/actor and actual inventory equipment service.
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const CaptureMath := preload("res://gameplay/clickmovetest/water_reflection_capture_math.gd")
const Gear := preload("res://game_core/inventory/source_character_equipment.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=pressed
	root.push_input(event,true)

func run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 正式水面捕获需要锁定作者资源。")
		quit()
		return
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"实际 F5")
	await scene_changed
	await process_frame
	var boot := current_scene as Boot
	if boot==null or boot.scene==null or boot.scene.water_reflection==null:
		check(false,"实际场景与倒影宿主已装配")
		finish()
		return
	var scene := boot.scene
	var capture = scene.water_reflection
	var view = scene.human_presentation
	var actor: Node2D = scene.actor
	var sprite: Sprite2D = view.sprite
	check(actor.get_movement_position()==Vector2.ZERO and scene.ground_layers.water_base_count()==87,
		"正式入口不挪出生点或水格")
	check(capture._color_target.get_child_count()==2 and capture._color_target.world_2d!=root.world_2d,
		"单独捕获原树及主角，不捕获树影、假人或重复长矛")
	var fallback: Node2D = scene.reflection_anchor
	if fallback == null:
		check(false,"正式场景缺原回退锚点")
		finish()
		return
	check(fallback.get_parent()==scene.visual_body and fallback.position==Vector2(0,.3125),
		"原场景 37030680 是 Body 子锚点，翻一次 Y")
	# Test-only near-water pose. No change to startup, terrain, or action runtime.
	scene.set_process(false)
	root.size=Vector2i(800,600)
	actor.request_move_position(Vector2(4.75,-4.5))
	await physics_frame
	await physics_frame
	scene.set_physics_process(false)
	scene.camera.global_position=Vector2(5.5,8.2)
	scene.camera.force_update_scroll()
	scene.advance_static_tree_reflection(0)
	var proxy: Sprite2D = capture._player_proxy
	var material: ShaderMaterial = sprite.material
	var clone: ShaderMaterial = proxy.material
	check(proxy.visible and capture._player_quality==Vector2.ONE and clone!=material,
		"实际主角在真实水边使用独立代理材质")
	check(material.get_shader_parameter("weapon0_enabled")==true \
		and clone.get_shader_parameter("weapon0_map")==material.get_shader_parameter("weapon0_map") \
		and clone.get_shader_parameter("weapon0_enabled")==true,
		"原长矛在角色材质合成中参与倒影而非另造子渲染器")
	var gear: Gear = boot.player.source_equipment()
	var owner := boot.primary_bag_owner(actor)
	var spear := gear.equipped(Gear.Slot.WEAPON)
	check(boot.inventory_bags.try_unequip(owner,gear,Gear.Slot.WEAPON)==Gear.Result.VALID,
		"正式装备服务卸矛回原包")
	scene.advance_static_tree_reflection(0)
	check(proxy.visible and clone.get_shader_parameter("weapon0_enabled")==false \
		and clone.get_shader_parameter("weapon0_map")==null,
		"同一反射代理移除原长矛贴图，不留下旧武器")
	check(boot.inventory_bags.try_equip(owner,gear,spear)==Gear.Result.VALID,"正式服务取回同一长矛")
	scene.advance_static_tree_reflection(0)
	check(clone.get_shader_parameter("weapon0_enabled")==true and sprite.material==material \
		and capture._color_target.get_child_count()==2,"恢复长矛而不替换主材质或新增武器代理")

	# Same captured actor, not a second preview or a manually selected animation.
	var near_camera: Vector2 = scene.camera.global_position
	var stand: Texture2D = material.get_shader_parameter("weapon0_map")
	scene.set_physics_process(true)
	scene.set_process(true)
	key(KEY_1,true)
	var limit := Time.get_ticks_msec()+1200
	while view.playback.current_action!="Attack" and Time.get_ticks_msec()<limit: await process_frame
	key(KEY_1,false)
	scene.camera.global_position=near_camera
	scene.camera.force_update_scroll()
	scene.advance_static_tree_reflection(0)
	var attack_texture: Texture2D = material.get_shader_parameter("weapon0_map")
	check(view.playback.current_action=="Attack" and attack_texture!=null and attack_texture!=stand
		and sprite.texture==proxy.texture and proxy.visible
		and clone.get_shader_parameter("weapon0_map")==attack_texture
		and clone.get_shader_parameter("weapon0_rect")==material.get_shader_parameter("weapon0_rect")
		and clone.get_shader_parameter("body_map")==material.get_shader_parameter("body_map")
		and capture._color_target.get_child_count()==2,
		"实际普攻帧同步自身贴图、躯干 UV、长矛序列和帧区，不新增代理")
	limit=Time.get_ticks_msec()+1800
	while view.playback.current_action=="Attack" and Time.get_ticks_msec()<limit: await process_frame
	scene.camera.global_position=near_camera
	scene.camera.force_update_scroll()
	scene.advance_static_tree_reflection(0)
	check(view.playback.current_action=="Idle" and proxy.visible and proxy.texture==sprite.texture
		and clone.get_shader_parameter("weapon0_map")==stand and sprite.material==material,
		"原普攻自然结束后代理回到同一已装备待机帧")

	# The water/lensing queries must not leave a stale proxy if the authored
	# actor moves out of range or is no longer visible.
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.camera.global_position=near_camera+Vector2(100,100)
	scene.camera.force_update_scroll()
	scene.advance_static_tree_reflection(0)
	check(not proxy.visible and capture._player_quality==Vector2.ZERO,"真实投影移出观察范围后关闭玩家代理")
	scene.camera.global_position=near_camera
	scene.camera.force_update_scroll()
	sprite.hide()
	scene.advance_static_tree_reflection(0)
	check(not proxy.visible,"仅隐藏真实源精灵就停止其捕获")
	sprite.show()
	scene.advance_static_tree_reflection(0)
	check(proxy.visible and proxy.texture==sprite.texture and capture._color_target.get_child_count()==2,
		"重新显示后复用同一个两源画布")

	# Distinguish preferred live ground from the authored fallback without
	# replacing the actual player, sprite or textures with a stand-in.
	sprite.flip_v=true
	scene.advance_static_tree_reflection(0)
	var frame_anchor: Vector2 = view.reflection_ground_anchor()
	check(not frame_anchor.is_equal_approx(fallback.global_position) \
		and proxy.transform.is_equal_approx(CaptureMath.reflection_transform(frame_anchor,1.0)*sprite.global_transform),
		"有效实时脚底优先于回退点")
	sprite.centered=false
	scene.advance_static_tree_reflection(0)
	check(view.reflection_ground_anchor()==null and proxy.visible \
		and proxy.transform.is_equal_approx(CaptureMath.reflection_transform(fallback.global_position,1.0)*sprite.global_transform),
		"帧脚底不可取时仍按绑定的实场景锚点捕获可见角色")
	sprite.centered=true
	sprite.flip_v=false
	capture.set_player_swimming(true)
	scene.advance_static_tree_reflection(0)
	check(not proxy.visible,"直接设置原游泳门禁后不继续显示站立倒影")
	capture.set_player_swimming(false)
	scene.advance_static_tree_reflection(0)
	check(proxy.visible,"门禁解除后重读同一原角色")
	finish()

func finish() -> void:
	print("%s 正式 F5 水面捕获与装备同步：%d/%d（未验像素）" % ["PASS" if failures==0 else "FAIL",checks-failures,checks])
	quit(1 if failures else 0)
