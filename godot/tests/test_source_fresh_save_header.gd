extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Player := preload("res://gameplay/clickmovetest/single_player_actor.gd")
const EXPECTED := "玩家角色配置 [INVALID_SHORTNAME]1"
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 原存档标题需要真实 F5 主角与原地图素材。")
		quit()
		return
	var before := Boot.new()
	check(before.has_method("capture_source_save_header") and before.call("capture_source_save_header")=="",
		"未正式启动的宿主不会生成标题")
	before.free()
	var path: String = ProjectSettings.get_setting("application/run/main_scene","")
	var opened := not path.is_empty() and change_scene_to_file(path)==OK
	check(opened,"实际 F5 入口")
	if not opened:
		finish()
		return
	if current_scene==null:
		await scene_changed
	await process_frame
	var boot := current_scene as Boot
	if boot==null or not is_instance_valid(boot.scene) or boot.player==null:
		check(false,"正式 F5 已装配原地图与原主角")
		finish()
		return
	var actor: Node2D = boot.scene.actor
	check(boot.persistables.resolve(Player.UNIQUE_PLAYER_IDENTIFIER)==actor
		and boot.persistables.identifier_for(actor)==Player.UNIQUE_PLAYER_IDENTIFIER,
		"实际主角是持久登记拥有者，不是夹具演员")
	check(boot.has_method("capture_source_save_header") and boot.call("capture_source_save_header")==EXPECTED,
		"实际新游戏标题使用原显示名、无效短名及等级，不加额外分隔")
	var raw_menu := OS.get_environment("FORMAL_PAUSE_SOURCE")
	check((boot.pause_root==null)==raw_menu.is_empty(),"使用所要求的实际可选菜单装配")
	check(boot.player.set_current_controlled(false) and not boot.player.is_current_controlled(actor)
		and boot.has_method("capture_source_save_header") and boot.call("capture_source_save_header")==EXPECTED,
		"解除控制不改变主角所有权或标题")
	boot.persistables.unregister(actor)
	check(boot.has_method("capture_source_save_header") and boot.call("capture_source_save_header")=="",
		"主角登记消失时不从当前场景、UI 或旧缓存补标题")
	finish()

func finish() -> void:
	print("%s 原 F5 逻辑存档标题：%d/%d"%["PASS" if failures==0 else "FAIL",checks-failures,checks])
	quit(1 if failures else 0)
