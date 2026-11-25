extends SceneTree
## 从正式项目入口冷重开；角色、移动、物理碰撞和朝向均使用实际场景所有者。
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const CLIFF_BOX := "SourceStaticGeometry/SourceCollider314378452"
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=down
	root.push_input(event,true)

func settle_body(actor: Node2D, point: Vector2) -> bool:
	for i in 10:
		await physics_frame
		if actor.get_movement_position().is_equal_approx(point):
			return true
	return false

func cast_at(actor: Node2D, body_shape: CollisionShape2D, source: Vector2, mask: int) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape=body_shape.shape
	query.transform=Transform2D(0,Vector2(source.x,-source.y)+body_shape.position)
	query.collision_mask=mask
	query.exclude=[actor.get_rid()]
	return actor.get_world_2d().direct_space_state.intersect_shape(query)

func run() -> void:
	for field in ["FORMAL_SURFACE_RULES","FORMAL_STATIC_COLLIDERS"]:
		if OS.get_environment(field).is_empty():
			print("SKIP 主角冷恢复需要锁定关卡素材和原静态碰撞几何。")
			quit()
			return
	var path: String=ProjectSettings.get_setting("application/run/main_scene")
	check(change_scene_to_file(path)==OK,"正式项目入口")
	if failures: finish(); return
	await scene_changed
	await process_frame
	await physics_frame
	var boot := current_scene as Boot
	if boot==null or boot.scene==null or boot.player==null:
		check(false,"原场景及玩家必须装配")
		finish()
		return
	var actor: Node2D=boot.scene.actor
	var owner: RefCounted=boot.player
	boot.scene.training_target.ai_controller.stop()
	if not owner.has_method("capture_source_cold_pose") or not owner.has_method("request_source_cold_pose"):
		check(false,"实际玩家所有者缺少冷恢复能力")
		finish()
		return
	var spawn: Vector2=actor.get_movement_position()
	var start_look: Vector2=owner.get_look_at_direction()
	key(KEY_TAB,true)
	key(KEY_TAB,false)
	await process_frame
	key(KEY_D,true)
	for i in 12: await physics_frame
	key(KEY_D,false)
	for i in 12: await physics_frame
	var moved: Vector2=actor.get_movement_position()
	var look: Vector2=owner.get_look_at_direction()
	check(moved.x>spawn.x+.1 and look==Vector2.RIGHT and look!=start_look,
		"原主角经真实 WASD 离开出生点并向右看")
	var capture: Dictionary=owner.capture_source_cold_pose()
	if not capture.get("ok",false):
		check(false,"静止正式主角可采集实际移动位置")
		finish()
		return
	var saved: Dictionary=capture.fields
	check(saved.identifier=="player" and saved.position==Vector3(moved.x,moved.y,0)
		and saved.lookAtDirection==look,"快照使用原 +Y 物理坐标和角色面向")
	check(owner.try_equip_formal_ability_to_slot(20001,4),"通过真实快捷槽 owner 将普攻换至第五槽")
	var living: Dictionary=owner.capture_source_player_save_fields()
	check(living.get("ok",false),"冷开前采集同一主角的装备、资源和快捷槽")
	if failures: finish(); return
	var old_root: WeakRef=weakref(boot)
	check(reload_current_scene()==OK,"冷重新加载正式场景")
	if failures: finish(); return
	await scene_changed
	await process_frame
	await physics_frame
	boot=current_scene as Boot
	actor=boot.scene.actor
	owner=boot.player
	boot.scene.training_target.ai_controller.stop()
	check(old_root.get_ref()==null and actor.get_movement_position()==spawn
		and owner.get_look_at_direction()==start_look and boot.persistables.resolve("player")==actor,
		"重新启动没有沿用旧位置、朝向或主角身份对象")
	check(owner.equipped_ability_menu_slots()[0].formal_gas_ability_code==20001
		and owner.equipped_ability_menu_slots()[4].formal_gas_ability_code==0,
		"实际新会话只读取原初始槽位，旧第五槽没有串入")
	var teleports := [0]
	actor.teleported.connect(func(): teleports[0]+=1)
	var wrong: Dictionary=saved.duplicate(true)
	wrong.position=Vector3(moved.x,moved.y,1)
	check(not owner.request_source_cold_pose(wrong) and actor.get_movement_position()==spawn
		and owner.get_look_at_direction()==start_look,"拒绝原场景不支持的 Z，不变更位置及朝向")
	check(owner.request_source_cold_pose(saved),"正式存活主角接受原姿态")
	check(not owner.capture_source_cold_pose().get("ok",false) and not owner.request_source_cold_pose(saved)
		and not owner.restore_source_player_save_fields(living.fields),
		"物理确认前不采集上一帧位置、不重复写入或提交后续槽位")
	check(await settle_body(actor,moved),"实际物理步确认恢复的位置")
	check(owner.get_look_at_direction()==look and teleports[0]==0
		and boot.scene.camera.follow==actor and boot.scene.command_count==0,
		"恢复同一主角朝向，不伪造传送或输入命令")
	for i in 4: await physics_frame
	check(owner.restore_source_player_save_fields(living.fields)
		and owner.capture_source_player_save_fields()==living and owner.capture_source_cold_pose()==capture,
		"确认实际位置后再恢复同一主角字段，两项均可精确回读")
	if is_instance_valid(boot.ability_hud) and boot.ability_hud._entries.size()==5:
		var shown: Array=boot.ability_hud._entries.map(func(entry): return entry.visible)
		check(shown==[false,true,false,false,true]
			and boot.ability_hud._icons[4]._texture==boot.ability_hud._attack,
			"同一原 HUD 只显示恢复后的第二、第五槽，且保留原普攻图")
	else:
		print("SKIP 主角姿态与原 HUD 联测需要原暂停图集与能力布局。")
	var authored: StaticBody2D=boot.scene.get_node_or_null(CLIFF_BOX)
	check(is_instance_valid(authored) and authored.has_meta("source_file_id"),"确认为原场景固定盒碰撞体")
	if not is_instance_valid(authored): finish(); return
	var point:=Vector2(authored.global_position.x,-authored.global_position.y)-Vector2(0,.42)
	var collider: CollisionShape2D=boot.scene.actor_shape
	check(cast_at(actor,collider,point,1).any(func(row): return row.collider==authored)
		and cast_at(actor,collider,point,7752).is_empty(),
		"原 Default 盒与身体形状确有交叠，但原 7752 掩码排除它")
	var in_default: Dictionary=saved.duplicate(true)
	in_default.position=Vector3(point.x,point.y,0)
	check(owner.request_source_cold_pose(in_default),"不把原 Default 投影误当作角色禁入墙")
	check(await settle_body(actor,point),"实际同步到原碰撞过滤器允许的坐标")
	# 固定原图没有角色掩码命中的墙，单独注入测试墙证明相同查询能拒绝。
	var wall := StaticBody2D.new()
	wall.collision_layer=8
	wall.collision_mask=0
	wall.position=Vector2(spawn.x,-spawn.y)+collider.position
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size=Vector2.ONE
	shape.shape=box
	wall.add_child(shape)
	boot.scene.add_child(wall)
	for i in 3: await physics_frame
	check(cast_at(actor,collider,spawn,7752).any(func(row): return row.collider==wall),"测试墙确实命中锁定掩码")
	var blocked: Dictionary=saved.duplicate(true)
	blocked.position=Vector3(spawn.x,spawn.y,0)
	blocked.lookAtDirection=Vector2.LEFT
	check(not owner.request_source_cold_pose(blocked),"命中原掩码的候选位置不接受，不自动找替代位置")
	for i in 3: await physics_frame
	check(actor.get_movement_position().is_equal_approx(point) and owner.get_look_at_direction()==look
		and teleports[0]==0,"拒绝后实际身体、朝向和通知保持不变")
	wall.free()
	authored.get_parent().free()
	check(not owner.capture_source_cold_pose().get("ok",false) and not owner.request_source_cold_pose(saved),
		"未挂载正式场景碰撞，不冒充空场景验证")
	finish()

func finish() -> void:
	print("%s 原主角冷姿态恢复：%d/%d（无磁盘）" % ["PASS" if failures==0 else "FAIL",checks-failures,checks])
	quit(1 if failures else 0)
