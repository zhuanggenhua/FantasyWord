extends SceneTree
## 原 F5 直启：活动场景不等于存档登记了命名地图。
const Startup := preload("res://gameplay/clickmovetest/source_startup.gd")
const MapRegistry := preload("res://game_core/maps/active_map_registry.gd")
const EMPTY_MAP := {"currentMap":"","checkpoints":[],"hasOrderedCheckpoint":false,
	"currentCheckpointOrder":-2147483648,"playtest":false}
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)

func run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 正式 F5 地图存档块需要原场景私有资源。")
		quit()
		return
	var path: String = ProjectSettings.get_setting("application/run/main_scene","")
	check(not path.is_empty() and change_scene_to_file(path)==OK,"加载项目实际 F5 入口")
	if failures:
		finish()
		return
	await scene_changed
	await process_frame
	var boot := current_scene as Startup
	if not is_instance_valid(boot) or not is_instance_valid(boot.scene):
		check(false,"原 F5 活动地图已装配")
		finish()
		return
	var map := boot.maps.resolve_active_map_info()
	check(map!=null and map.get_scene_root()==boot.scene
		and boot.maps.get_active_terrain_navigation_map()==boot.scene.route,
		"原地图信息与实际 F5 地形同属一个活动场景")
	if map==null or not boot.has_method("capture_source_map_save_block"):
		check(false,"原 F5 宿主支持地图存档块采集")
		finish()
		return
	var first: Dictionary=boot.call("capture_source_map_save_block")
	check(first.get("ok",false) and first.get("fields",{})==EMPTY_MAP,
		"实际直启保留空 currentMap 和原检查点默认值，没有伪装命名地图")
	var pose: Vector2=boot.scene.actor.get_movement_position()
	var facing: Vector2=boot.player.get_look_at_direction()
	var lifecycle := [0]
	boot.maps.map_loaded.connect(func(): lifecycle[0]+=1)
	boot.maps.map_unloaded.connect(func(): lifecycle[0]+=1)
	var preflight := boot.preflight_source_map_load(first.get("fields"))
	var named_intent := EMPTY_MAP.duplicate(true)
	named_intent.currentMap="ClickMoveTest"
	check(not preflight.ok and preflight.reason=="initial_checkpoint_required",
		"实际 F5 采集块缺少首次进入所需的原检查点，不能用冷姿态满足地图载入")
	check(boot.preflight_source_map_load(named_intent).reason=="named_map_unavailable",
		"把 ClickMoveTest 填进块也不会让未配置命名过场的 F5 变成可载入")
	await physics_frame
	check(lifecycle[0]==0 and boot.scene.actor.get_movement_position()==pose
		and boot.player.get_look_at_direction()==facing and boot.maps.resolve_active_map_info()==map
		and boot.capture_source_map_save_block().get("fields")==EMPTY_MAP,
		"预检不触发过场、不改原地图块或实际主角姿态")
	if first.get("ok",false) and first.get("fields") is Dictionary:
		first.fields.currentMap="not-persisted"
		if first.fields.get("checkpoints") is Array:
			first.fields.checkpoints.append("not-persisted")
	var second: Dictionary=boot.call("capture_source_map_save_block")
	check(second.get("ok",false) and second.get("fields",{})==EMPTY_MAP
		and boot.maps.get_active_terrain_navigation_map()==boot.scene.route,
		"采集块不反写活动地图、检查点或导航")
	# F5 still resolves gameplay MapInfo through the active-scene fallback, but
	# capture must not infer a durable name when the independent host cannot.
	boot.maps.record_current_map_name("ClickMoveTest")
	var unavailable: Dictionary=boot.call("capture_source_map_save_block")
	check(boot.maps.resolve_active_map_info()==map and not unavailable.get("ok",false)
		and unavailable.get("reason")=="reported_map_unresolved",
		"直启活动图仍可用，但不能把无法解析的名称写进存档")
	boot.maps.record_current_map_name("")
	# In isolation, bind an explicit named lookup to the *same actual* MapInfo.
	# This checks owner admission only, not a host transition or Continue.
	var named := MapRegistry.new()
	check(named.configure(func(name): return boot.scene if name=="ClickMoveTest" else null,
		func(): return boot.scene), "单独装配命名查找和活动场景查找")
	named.register(map)
	named.record_current_map_name("ClickMoveTest")
	var expected_named := EMPTY_MAP.duplicate(true)
	expected_named.currentMap="ClickMoveTest"
	var named_block: Dictionary=named.capture_source_map_save_block(boot.scene)
	check(named_block.get("ok",false) and named_block.get("fields",{})==expected_named,
		"只有显式命名查找匹配真实 MapInfo 才能采集名称")
	check(boot.call("capture_source_map_save_block").get("fields",{})==EMPTY_MAP,
		"命名查找夹具未改变实际 F5 的无名状态")
	boot.maps.unregister(map)
	check(boot.maps.resolve_active_map_info()==null and not boot.call("capture_source_map_save_block").get("ok",false),
		"移除真实 MapInfo 后拒绝用空字典冒充有效启动状态")
	finish()

func finish() -> void:
	print("%s 原 F5 地图存档块采集与预检：%d/%d（无磁盘、无地图切换）" % ["PASS" if failures==0 else "FAIL",checks-failures,checks])
	quit(1 if failures else 0)
