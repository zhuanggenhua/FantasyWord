extends SceneTree
const MapInfo = preload("res://game_core/maps/registered_map_info.gd")
const Registry = preload("res://game_core/maps/active_map_registry.gd")
var checks := 0
var failures := 0
var _active: Node
var _names: Dictionary = {}
var _events: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",description)


func test_load_preflight(maps: Registry, map: Node, other: Node, authored: MapInfo) -> void:
	var captured := maps.capture_source_map_save_block(map)
	var fields: Dictionary=captured.get("fields",{})
	var empty := fields.duplicate(true)
	empty.currentMap=""
	check(maps.preflight_source_map_load_block(null,map).reason=="invalid_map_block",
		"没有地图块不能预检")
	var malformed := fields.duplicate(true)
	malformed.currentCheckpointOrder=float(-2147483648)
	check(maps.preflight_source_map_load_block(malformed,map).reason=="invalid_map_block",
		"当前只接逻辑整数顺序，不冒充线格式解码")
	check(maps.preflight_source_map_load_block(fields,other).reason=="map_owner_unavailable",
		"另一场景不能借用活动地图登记")
	check(maps.preflight_source_map_load_block(empty,map).reason=="initial_checkpoint_required",
		"空名与空栈缺少源首次进入的传送检查点")
	var with_checkpoint := empty.duplicate(true)
	with_checkpoint.checkpoints=[{}]
	check(maps.preflight_source_map_load_block(with_checkpoint,map).reason=="unsupported_map_checkpoint_state",
		"非空检查点仍待迁移，不能伪造首次进入")
	var playtest := fields.duplicate(true)
	playtest.playtest=true
	check(maps.preflight_source_map_load_block(playtest,map).reason=="unsupported_map_checkpoint_state",
		"独立 Playtest 检查点未接通")
	var ordered := fields.duplicate(true)
	ordered.hasOrderedCheckpoint=true
	check(maps.preflight_source_map_load_block(ordered,map).reason=="unsupported_map_checkpoint_state",
		"顺序检查点不属于当前逻辑块")
	var missing := fields.duplicate(true)
	missing.currentMap="Missing"
	check(maps.preflight_source_map_load_block(missing,map).reason=="named_map_unavailable",
		"活动回退不能认证不存在的具名目标")
	var named := maps.preflight_source_map_load_block(fields,map)
	check(not named.ok and named.reason=="named_map_transition_required",
		"显式名称匹配同一地图也仍需真实过场")
	check(_events==["loaded"] and maps.resolve_active_map_info()==authored
		and maps.capture_source_map_save_block(map).get("fields")==fields,
		"预检不触碰地图事件、登记与当前地图名")


func run() -> void:
	var shell := Node2D.new()
	var map := Node2D.new()
	var unloaded := Node2D.new()
	root.add_child(shell)
	root.add_child(map)
	_active = shell
	_names = {"AuthorMap":map,"Unloaded":unloaded}
	var maps := Registry.new()
	check(maps.configure(func(name):return _names.get(name),func():return _active),"explicit host lookup")
	var terrain := RefCounted.new()
	var target := Node2D.new()
	var bounds := Node2D.new()
	map.add_child(target)
	map.add_child(bounds)
	var authored := MapInfo.new()
	var also_registered := MapInfo.new()
	check(authored.configure(map,terrain,target,false,bounds,.75) and also_registered.configure(map,null,null,true,bounds),
		"explicit authored scene configurations")
	maps.register(authored)
	maps.register(authored)
	maps.register(also_registered)
	maps.on_system_start()
	check(maps.resolve_active_map_info()==null and maps.get_active_terrain_navigation_map()==null,
		"direct engine shell never picks a registered but different map")
	check(authored.get_camera_target()==target and authored.get_level_bounds()==null and also_registered.get_level_bounds()==bounds,
		"camera override and explicit level-bound actual-enable gates")
	var loaded := func():
		if maps.resolve_active_map_info()==authored: _events.append("loaded")
	var unloading := func():
		if maps.get_respawn_delay()==0.0: _events.append("unloaded")
	maps.map_loaded.connect(loaded)
	maps.map_unloaded.connect(unloading)
	maps.record_current_map_name("AuthorMap")
	check(maps.resolve_active_map_info()==authored and maps.get_active_terrain_navigation_map()==terrain
		and is_equal_approx(maps.get_respawn_delay(),.75),"tracked named scene resolves its first registered instance")
	maps.notify_map_loaded()
	_active = map
	test_load_preflight(maps,map,shell,authored)
	maps.record_current_map_name("Unloaded")
	check(maps.resolve_active_map_info()==null,"valid unloaded named scene never falls through to active")
	maps.record_current_map_name("Missing")
	check(maps.resolve_active_map_info()==authored,"missing named scene falls back to active root")
	maps.notify_map_unloaded()
	check(_events==["loaded","unloaded"] and maps.get_respawn_delay()==0.0,"unload clears cache before lifecycle event")
	check(maps.resolve_active_map_info()==authored,"explicit resolution rebuilds after a cache clear if remaining scene still owns it")
	maps.unregister(authored)
	check(maps.resolve_active_map_info()==also_registered and maps.get_active_terrain_navigation_map()==null,
		"same registered record deduplicated; unregister leaves next real scene owner")
	map.free()
	check(maps.resolve_active_map_info()==null,"destroyed scene never lends its old metadata")
	maps.map_loaded.disconnect(loaded)
	maps.map_unloaded.disconnect(unloading)
	unloaded.free()
	shell.free()
	print("PASS MapSystem active MapInfo: %d/%d" % [checks-failures,checks])
	quit(1 if failures else 0)
