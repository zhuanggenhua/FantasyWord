extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const RESTORE := "restore_source_controlled_references"
var total := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	total+=1
	if not ok:
		failed+=1
		printerr("FAIL ",label)

func finish() -> void:
	print("%s F5 当前控制冷读档：%d/%d"%["FAIL" if failed else "PASS",total-failed,total])
	quit(1 if failed else 0)

func run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 需要锁定原关卡")
		quit()
		return
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"正式 F5 启动")
	await scene_changed
	await process_frame
	var boot := current_scene as Boot
	check(boot!=null and boot.scene!=null and boot.player!=null,"正式角色")
	if failed: finish(); return
	check(boot.has_method(RESTORE),"实现 PlayerSystem 读档尾的控制恢复")
	if failed: finish(); return
	var ref_rows := boot.capture_source_controlled_references()
	var previous: Node = boot.scene.actor
	check(ref_rows==[{"m_identifier":"player"}],"从实际当前控制采集，而非测试常量")
	check(reload_current_scene()==OK,"实际冷重开")
	await scene_changed
	await process_frame
	boot=current_scene as Boot
	check(boot!=null and boot.scene!=null and boot.scene.actor!=previous,"重开后的新角色")
	if failed: finish(); return
	boot.scene.training_target.ai_controller.stop()
	var actor: Node=boot.scene.actor
	var player:=boot.player
	var seen := []
	var on_control := func(owner: Node):
		seen.append([owner, boot.call(RESTORE,[]) if owner!=null else false,boot.capture_source_controlled_references()])
	check(player.set_current_controlled(false),"让正式玩家控制失去当前归属")
	player.controlled_character_changed.connect(on_control)
	check(not boot.call(RESTORE,[ref_rows[0],{"m_identifier":17}]) and seen.is_empty()
		and boot.capture_source_controlled_references()==[],"后到的非法引用不能先重置当前控制")
	check(not boot.call(RESTORE,[{"m_identifier":"unknown"}]) and seen.is_empty(),
		"不伪造未知角色的延期登记")
	check(boot.call(RESTORE,[ref_rows[0],{"m_identifier":" "},ref_rows[0],null])
		and seen==[[actor,false,ref_rows],[actor,false,ref_rows]],
		"先主角重置，后单次重新选择，重复引用不产生控制组且拒绝递归")
	seen.clear()
	check(player.set_current_controlled(false) and seen.size()==1,"正式控制可再次取消")
	seen.clear()
	player.set_accepts_player_input(false)
	check(boot.call(RESTORE,null) and seen==[[actor,false,ref_rows]]
		and not player.accepts_player_input(actor),"缺失数组仍回退主角；不会擅自打开输入使能")
	player.set_accepts_player_input(true)
	seen.clear()
	var shadow := Node.new()
	boot.scene.add_child(shadow)
	check(boot.persistables.register_custom_instanced(shadow,"player")
		and not boot.call(RESTORE,ref_rows) and seen.is_empty(),"登记键被非主角取代时不误绑")
	boot.persistables.unregister(shadow)
	check(boot.persistables.register_custom_instanced(actor,"player"),"恢复实际拥有者")
	player.controlled_character_changed.disconnect(on_control)
	var ownership_changes := []
	var replace_registry := func(_owner: Node):
		ownership_changes.append(boot.persistables.register_custom_instanced(shadow,"player"))
	player.controlled_character_changed.connect(replace_registry)
	check(boot.call(RESTORE,ref_rows) and ownership_changes==[true],
		"重置的同步通知中目标登记变化时，旧引用不会再选择一次")
	player.controlled_character_changed.disconnect(replace_registry)
	boot.persistables.unregister(shadow)
	check(boot.persistables.register_custom_instanced(actor,"player"),"重新登记正式主角")
	# Use the formal Gameplay route, not a mocked movement controller.
	actor.request_move_position(Vector2(-3.55,3.5))
	for i in 4: await physics_frame
	key(KEY_TAB,true)
	key(KEY_TAB,false)
	await process_frame
	check(player.set_current_controlled(false),"清空当前控制以观察实际输入差异")
	var before: Vector2=actor.get_movement_position()
	key(KEY_D,true)
	for i in 8: await physics_frame
	key(KEY_D,false)
	for i in 4: await physics_frame
	check(actor.get_movement_position().is_equal_approx(before),"失控时原 WASD 不移动角色")
	check(boot.call(RESTORE,ref_rows),"按采集引用恢复正式当前控制")
	key(KEY_D,true)
	for i in 14: await physics_frame
	key(KEY_D,false)
	for i in 4: await physics_frame
	check(actor.get_movement_position().x>before.x+0.05,"同一正式 WASD 再次驱动已恢复的主角")
	boot.scene.queue_free()
	check(not boot.call(RESTORE,ref_rows),"正式会话即将销毁时拒绝")
	finish()

func key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=pressed
	root.push_input(event,true)
