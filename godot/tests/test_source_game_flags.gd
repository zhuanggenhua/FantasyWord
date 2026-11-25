extends SceneTree
const Flags := preload("res://game_core/persistence/source_game_flags.gd")
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
var checks := 0
var failed := 0
var events: Array = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failed+=1
		printerr("FAIL ",label)

func run() -> void:
	var owner := Flags.new()
	owner.flag_changed.connect(record.bind(owner))
	check(not owner.get_flag("Door") and owner.create_data_block()=={"flags":[]},"缺省为 false")
	for row: Array in [["Door",true],["Door",true],["door",false],["door",false],[" Door",true],["",true],[null,true]]:
		check(owner.set_flag(row[0],row[1]),"原字符串名的写入可用")
	check(events==[["Door",true,true],["Door",true,true],["door",false,false],["door",false,false],
		[" Door",true,true],["",true,true],[null,true,true]],"通知每次发生且观察已更新值")
	var block := owner.create_data_block()
	check(block.flags.size()==4 and block.flags.has("Door") and not block.flags.has("door") 		and block.flags.has(" Door") and block.flags.has("") and block.flags.has(null),"只存启用名、保留原键")
	check(owner.set_flag("Door",false) and block.flags.has("Door"),"快照和当前集合隔离")
	var before := events.size()
	check(owner.load_data_block({"flags":["door","door",null]}) and owner.get_flag("door") 		and owner.get_flag(null) and not owner.get_flag(" Door") and owner.create_data_block().flags.size()==2
		and events.size()==before,"加载静默替换、去重，不使用 Set")
	check(not owner.load_data_block({"flags":["partial",4]}) and not owner.load_data_block({"flags":null})
		and not owner.set_flag(42,true) and owner.get_flag("door") and not owner.get_flag("partial")
		and events.size()==before,"坏输入不部分改动现有状态")
	check(owner.load_data_block({"flags":[]}) and not owner.get_flag(null) and not owner.get_flag("door"),"空集合静默清除")
	owner.flag_changed.disconnect(record.bind(owner))
	if not OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		await check_entry()
	else:
		print("SKIP 私有 F5 标记所有者，不使用替代地图")
	print("%s 源游戏标记块：%d/%d" % ["PASS" if failed==0 else "FAIL",checks-failed,checks])
	quit(1 if failed else 0)

func record(name: Variant,value: bool,owner: Flags) -> void:
	events.append([name,value,owner.get_flag(name)])

const CAPTURE := "capture_source_game_flags_save_block"
const RESTORE := "restore_source_game_flags_save_block"

func check_entry() -> void:
	var path: String=ProjectSettings.get_setting("application/run/main_scene")
	check(change_scene_to_file(path)==OK,"实际项目入口")
	await scene_changed
	await process_frame
	var boot := current_scene as Boot
	if boot==null or boot.scene==null:
		check(false,"私有原图成功启动")
		return
	check(boot.has_method(CAPTURE) and boot.has_method(RESTORE),"正式 F5 暴露独立存档边界")
	if failed: return
	var owner = boot.game_flags
	check(boot.call(CAPTURE)=={"flags":[]} and not owner.get_flag("fixture"),
		"当前正式世界新会话没有伪造标记")
	var flag_events: Array = []
	var observe := func(flag,value): flag_events.append([flag,value,owner.get_flag(flag)])
	owner.flag_changed.connect(observe)
	check(owner.set_flag("fixture",true) and owner.set_flag("Fixture",true)
		and owner.set_flag("Fixture",false),"实际会话通过 Set 改变标记")
	var saved: Dictionary = boot.call(CAPTURE)
	check(saved=={"flags":["fixture"]} and flag_events==[["fixture",true,true],
		["Fixture",true,true],["Fixture",false,false]],"正式快照使用同一实时集合，保存且仅保存 true")
	saved.flags.append("consumer")
	check(boot.call(CAPTURE)=={"flags":["fixture"]},"修改快照不影响会话真相")
	var observed := flag_events.size()
	check(not boot.call(RESTORE,{"flags":["partial",42]}) and boot.call(CAPTURE)=={"flags":["fixture"]}
		and flag_events.size()==observed,"非法标记恢复不改变真实所有者也不广播")
	check(boot.call(RESTORE,{"flags":["second","second",null]}) and owner.get_flag("second")
		and owner.get_flag(null) and not owner.get_flag("fixture") and flag_events.size()==observed,
		"换集合仍使用同一会话所有者；静默去重，不反复 Set")
	boot.persistables.unregister(boot.scene.actor)
	check(boot.call(CAPTURE).flags.size()==2,
		"GameFlags 属于世界，不因主角持久身份缺失而失效")
	var clone := Boot.new()
	root.add_child(clone)
	clone.game_flags.set_flag("diagnostic",true)
	check(clone.call(CAPTURE)=={} and not clone.call(RESTORE,{"flags":[]})
		and clone.game_flags.get_flag("diagnostic"),"未成功装配的宿主没有可调用的正式存档边界")
	check(not clone.open(PackedStringArray(["--trainer-diagnostic"]),true)
		and clone.call(CAPTURE)=={} and not clone.call(RESTORE,{"flags":[]}),
		"启动失败后的会话也不得采集和恢复")
	clone.free()
	owner.flag_changed.disconnect(observe)
	boot.scene.queue_free()
	check(boot.call(CAPTURE)=={} and not boot.call(RESTORE,{"flags":[]})
		and owner.get_flag("second"),"正式场景进入注销时拒绝继续访问会话快照")
	check(reload_current_scene()==OK,"从同一项目入口重新启动")
	await scene_changed
	await process_frame
	var fresh := current_scene as Boot
	check(fresh!=null and fresh.scene!=null and fresh.game_flags!=owner
		and fresh.call(CAPTURE)=={"flags":[]},"新会话使用新所有者，不泄漏旧标记或隐式载入")
