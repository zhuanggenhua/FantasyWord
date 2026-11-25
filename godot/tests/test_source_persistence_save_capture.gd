extends SceneTree

const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func finish() -> void:
	print("%s 正式 F5 通用持久化快照：%d/%d" % ["PASS" if failures==0 else "FAIL",checks-failures,checks])
	quit(1 if failures!=0 else 0)

func run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 没有锁定原场景合同，不用替代场景验证正式存档。")
		quit()
		return
	var entry := "capture_source_persistence_save_block"
	var unopened := Boot.new()
	check(unopened.has_method(entry) and unopened.call(entry)=={},"未启动对象不能伪造空块")
	unopened.free()
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"主入口可打开")
	await scene_changed
	await process_frame
	var startup := current_scene as Boot
	check(startup!=null and is_instance_valid(startup.scene),"锁定原资产的正式 F5 已启动")
	if startup==null or not is_instance_valid(startup.scene): finish(); return
	var registry := startup.persistables
	var primary: Node = startup.scene.actor
	var trainer: Node = startup.scene.training_target.body
	check(primary!=null and registry.resolve("player")==primary and registry.identifier_for(primary)=="player"
			and not registry.automatically_persisted(primary),"实际主角归 PlayerSystem 自定义身份，不是通用对象")
	check(is_instance_valid(trainer) and trainer!=primary and registry.identifier_for(trainer).is_empty()
			and not registry.automatically_persisted(trainer),"实际假人按场景 m_forceNoPersistence=1 不登记")
	check(startup.has_method(entry),"实际入口连接到持久化所有者")
	if not startup.has_method(entry): finish(); return
	var empty := {"objects":[]}
	check(startup.call(entry)==empty,"实际正式原图在没有通用对象时捕获空数组")
	var snapshot: Dictionary = startup.call(entry)
	snapshot.objects.append({"not_authored":1})
	check(startup.call(entry)==empty,"编辑所返回数组不改变实际所有者")
	var spare := Node.new()
	startup.scene.add_child(spare)
	check(registry.register_pre_instanced(spare,"regression-id",true) and startup.call(entry)=={},
			"活着的自动对象未迁移时拒绝，不静默丢条目")
	var lookup_winner := Node.new()
	startup.scene.add_child(lookup_winner)
	check(registry.register_custom_instanced(lookup_winner,"regression-id") and registry.resolve("regression-id")==lookup_winner
			and startup.call(entry)=={},"共享查找键的新自定义持有者不能隐藏原自动对象")
	registry.unregister(spare)
	check(registry.resolve("regression-id")==lookup_winner and startup.call(entry)==empty,"注销自动对象后可重新捕获")
	check(registry.register_pre_instanced(spare,"regression-id-2",true) and startup.call(entry)=={},"再次登记真实活对象恢复拒绝")
	startup.scene.remove_child(spare)
	check(startup.call(entry)==empty,"已退出世界的遗留弱登记不写入快照")
	spare.free()
	check(startup.call(entry)==empty,"已释放对象不是可持久化对象")
	registry.unregister(primary)
	check(startup.call(entry)=={},"正式主角登记失效时不声称仍有正式会话")
	finish()
