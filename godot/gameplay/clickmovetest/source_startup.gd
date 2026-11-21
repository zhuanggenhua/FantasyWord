extends Node
## Godot 原图启动宿主：装配同一原角色、输入、地图和私有作者资源。
## 正常项目入口不启动诊断抽样或替代关卡，CLI 预览复用相同宿主。
const Entry = preload("res://gameplay/clickmovetest/entry.tscn")
const DamageScreenFlash = preload("res://gameplay/clickmovetest/source_damage_screen_flash.gd")
const EntryScript = preload("res://gameplay/clickmovetest/entry.gd")
const PlayerOwner = preload("res://gameplay/clickmovetest/single_player_actor.gd")
const SessionDraws = preload("res://gameplay/clickmovetest/source_session_draws.gd")
const TrainerOwner = preload("res://gameplay/clickmovetest/training_actor_owner.gd")
const InventoryBags := preload("res://game_core/inventory/source_inventory_bags.gd")
const PartyMoney := preload("res://game_core/inventory/source_party_money.gd")
const AudioPreferences := preload("res://game_core/audio/source_audio_preferences.gd")
const AbilityHUD := preload("res://gameplay/clickmovetest/source_ability_hud.gd")
const PauseRoot := preload("res://gameplay/clickmovetest/source_pause_root.gd")
const Point = preload("res://game_core/input/mouse_point_actions.gd")
## 原 Player System 983130465 的主角色为 735002000000000004；只绑定 Entry 明确的 actor。

const PersistenceRegistry = preload("res://game_core/persistence/persistable_identity_registry.gd")
const MapRegistry = preload("res://game_core/maps/active_map_registry.gd")
const MapInfo = preload("res://game_core/maps/registered_map_info.gd")

const REQUIRED_FILES := ["FORMAL_SURFACE_RULES","FORMAL_SURFACE_ASSETS",
	"FORMAL_BURNING_TILE_PNG"]
const REQUIRED_DIRS := ["FORMAL_GROUND_LAYERS","FORMAL_PLAYER_TEXTURES"]
const TRAINER_FILES := ["FORMAL_TRAINER_ATTACK_ANIMATION","FORMAL_TRAINER_ATTACK_MATERIAL"]
const TRAINER_DEATH_FILES := ["FORMAL_TRAINER_ATTACK_DEATH_ANIMATION","FORMAL_TRAINER_ATTACK_DEATH_MATERIAL"]
const TRAINER_DIRS := ["FORMAL_TRAINER_ATTACK_TEXTURES"]
const MAIN_FEATURES := ["--water-reflection","--control-panel","--damage-screen-flash"]

@export var launch_from_project := false
var scene: Node2D
var player: PlayerOwner
var trainer_owner: TrainerOwner
var maps := MapRegistry.new()
var persistables := PersistenceRegistry.new()
var point: Point
var pause_root: PauseRoot
var ability_hud: AbilityHUD
var audio_preferences: AudioPreferences
var party_money: PartyMoney
var inventory_bags: InventoryBags
var _listener_prior := 1.0
var _trainer_death := false
var _player_death := false
var _water_reflection := false
var damage_screen_flash: DamageScreenFlash

var refusal := ""
var _attempted := false
var _source_draws: SessionDraws


func _ready() -> void:
	if launch_from_project: call_deferred("_launch_main")


func _launch_main() -> void:
	# 锁定 ClickMoveTest 直接进入 Gameplay、正常时间倍率且没有初始存档命令。
	Engine.time_scale = 1.0
	if not open(PackedStringArray(MAIN_FEATURES),true):
		printerr("FantasyWord 启动失败：" + refusal)
		get_tree().quit(1)
		return
	print("FantasyWord 已直接进入 ClickMoveTest。左键点击移动；Tab 切换后使用 WASD；1 普攻，Q 或 2 喷火。")


func open(args: PackedStringArray, mount_project_contact: bool = false) -> bool:
	if _attempted or not is_inside_tree():
		return false
	_attempted = true
	var panel := "--control-panel" in args
	var trainer_diagnostic := "--trainer-diagnostic" in args
	var player_combat := "--player-combat-diagnostic" in args
	_trainer_death = "--trainer-death-diagnostic" in args
	_player_death = "--player-death-diagnostic" in args
	_water_reflection = "--water-reflection" in args
	if mount_project_contact and (trainer_diagnostic or player_combat or _trainer_death or _player_death):
		return _fail("正式地表接收不使用诊断生物或固定抽样。")
	if (_trainer_death or _player_death) and not player_combat:
		return _fail("死亡诊断需要同图原玩家技能入口。")
	if player_combat and not trainer_diagnostic:
		return _fail("玩家技能诊断需要同图原训练假人。")
	var player_files: Array = ["FORMAL_PLAYER_COMBAT_ANIMATION","FORMAL_PLAYER_COMBAT_MATERIAL"] if player_combat \
		else ["FORMAL_PLAYER_DAMAGE_ANIMATION","FORMAL_PLAYER_DAMAGE_MATERIAL"]
	if _player_death or mount_project_contact: player_files = ["FORMAL_PLAYER_DEATH_ANIMATION","FORMAL_PLAYER_DEATH_MATERIAL"]
	var trainer_files: Array = TRAINER_DEATH_FILES if _trainer_death or mount_project_contact else TRAINER_FILES
	var paths := {}
	for key in REQUIRED_FILES + player_files + (trainer_files if trainer_diagnostic or mount_project_contact else []) \
			+ (["FORMAL_WATER_REFLECTION_MASK"] if _water_reflection else []) \
			+ (["FORMAL_PANEL_SILVER","FORMAL_PANEL_CJK"] if panel else []):
		var path := OS.get_environment(key)
		if path.is_empty() or not FileAccess.file_exists(path):
			return _fail("缺少明确的原作者输入：" + key)
		paths[key] = path
	for key in REQUIRED_DIRS + (TRAINER_DIRS if trainer_diagnostic or mount_project_contact else []) + (["FORMAL_FLAMETHROWER_CUE"] if player_combat or mount_project_contact else []):
		var path := OS.get_environment(key)
		if path.is_empty() or not DirAccess.dir_exists_absolute(path):
			return _fail("缺少明确的原作者资源目录：" + key)
		paths[key] = path
	var rules := _read(paths.FORMAL_SURFACE_RULES)
	var surface := _read(paths.FORMAL_SURFACE_ASSETS)
	var animation := _read(paths[player_files[0]])
	var material := _read(paths[player_files[1]])
	if not EntryScript.valid_rules(rules) or surface.is_empty() or animation.is_empty() or material.is_empty() \
			or animation.has("training_target") or material.has("training_target"):
		return _fail("原场景规则、地表或玩家动画合同无效；不能借训练假人资料启动玩家。")
	scene = Entry.instantiate()
	add_child(scene)
	player = PlayerOwner.new()
	if not player.configure(scene.actor,Callable(),Callable(),Callable()):
		return _fail("缺少原序列化玩家角色或当前输入所有者。")
	# 原角色 735002000000000004 先持有预摆标识；主角色启动时替换为 player。
	if not persistables.register_pre_instanced(scene.actor,PlayerOwner.SOURCE_PREINSTANCED_IDENTIFIER,false) \
			or not player.register_primary_persistence(persistables):
		return _fail("原玩家正式持久化标识未绑定。")
	var art: String = paths.FORMAL_PLAYER_TEXTURES
	if _player_death or mount_project_contact: animation["primary_death"] = material.get("primary_death")
	var view: Node2D = scene.start_human_presentation(animation,art)
	var spear := OS.get_environment("FORMAL_PLAYER_SPEAR_SOURCE") if mount_project_contact else ""
	var effects := OS.get_environment("FORMAL_PLAYER_EFFECTS_SOURCE") if mount_project_contact else ""
	if not is_instance_valid(view) or not view.bind_base_material(material,art.path_join("uv"),art.path_join("appearance"),not spear.is_empty() or not effects.is_empty()):
		return _fail("原玩家角色动画与身体、头部 UV 无法绑定。")
	# 原 ClickMoveTest MapInfo 没有相机目标覆盖，也没有启用地图相机边界。
	if not maps.configure(func(_name):return null,func():return scene) \
			or not scene.start_human_logic(player,rules,player.get_player_provider,
			maps.resolve_active_map_info,maps,_over_native_ui):
		return _fail("原 PlayerSystem、地图规则或镜头绑定未成立。")
	# 原 MapInfo 6951708 拥有地形 1148507052，未配置检查点、相机目标或边界。
	# 直接启动不伪造加载过存档或触发过地图切换。
	var authored_map := MapInfo.new()
	if not authored_map.configure(scene,scene.route):
		return _fail("原 ClickMoveTest 地图配置未绑定。")
	maps.register(authored_map)
	maps.on_system_start()
	scene.binding.start_binding()
	if not scene.bind_active_terrain(maps.get_active_terrain_navigation_map):
		return _fail("点击导航与原 MapInfo 不属于同一地图。")
	if not scene.start_surface_elements(surface) or not scene.bind_ground_layers(paths.FORMAL_GROUND_LAYERS) \
			or not scene.bind_surface_presentation(paths.FORMAL_BURNING_TILE_PNG):
		return _fail("原底图、固定装饰或地表效果未通过来源检查。")
	if _water_reflection and (not scene.bind_static_tree_reflection(paths.FORMAL_WATER_REFLECTION_MASK) \
			or not scene.bind_player_water_reflection()):
		return _fail("原树、主角正式换装材质和 87 格水层无法装配倒影。")
	point = Point.new(0)
	point.enable(Point.Map.GAMEPLAY)
	if not scene.bind_mouse_point_actions(point) or not scene.start_human_aim(player,player):
		return _fail("原玩家 Point 与 Static Pivot 未绑定。")
	player.player_input_disabled.connect(scene.notify_human_aim_input_disabled)
	if "--damage-screen-flash" in args:
		_mount_damage_screen_flash()
	if panel and not scene.bind_source_control_panel(paths.FORMAL_PANEL_SILVER,paths.FORMAL_PANEL_CJK):
		return _fail("原静态测试面板字体与实际玩家入口未绑定。")
	if mount_project_contact:
		party_money=PartyMoney.new()
		inventory_bags=InventoryBags.new()
		if not player.start_source_equipment():
			return _fail("原玩家初始装备槽未绑定。")
		var cloth_png := OS.get_environment("FORMAL_PLAYER_CLOTH_PNG")
		if not cloth_png.is_empty() and not view.bind_source_cloth(player.source_equipment(),cloth_png):
			return _fail(view.last_error)
		if (not spear.is_empty() or not effects.is_empty()) and not view.bind_source_standing_render(player.source_equipment(),spear,effects):
			return _fail(view.last_error)
		_source_draws = SessionDraws.new()
		if not _mount_trainer(paths,trainer_files,true,_source_draws.value,_source_draws.inclusive_range,
				OS.get_environment("FORMAL_TRAINER_EFFECTS_SOURCE")):
			return _fail("原图活动假人的身份、原素材、地图路径或死亡动作无法装配。")
		var combat := _mount_player_combat(paths.FORMAL_FLAMETHROWER_CUE,_source_draws.resolve_damage)
		if not is_instance_valid(combat) or not scene.bind_human_damage_lifecycle(player.is_destroyed,combat.interrupt_owned_actions) \
				or not scene.bind_source_primary_death(player,material,inventory_bags,persistables.identifier_for(scene.actor)) \
				or not scene.bind_source_player_surface_contact(player) \
				or not is_instance_valid(scene.start_training_basic_attack(player.get_target_direction,player.damage_hooks(),
					_source_draws.resolve_damage)):
			return _fail("原主角、同图假人普攻或地表受击未通过正式装配。")
		if not _start_source_audio_preferences():
			return _fail("原音量所有者未能绑定到实际 GameplaySoundFX。")
		# ClickMoveTest 与两条角色 prefab 链均无 Interaction 层目标。
		# 装配角色原组件但不造对象、不播放来源未到位的成功音效。
		if not scene.start_human_interaction(player,_on_unadmitted_interact_success) or not scene.bind_source_interact_submit():
			return _fail("原角色 Static Pivot 或同一交互命令宿主未绑定。")
	if trainer_diagnostic and not _mount_trainer_diagnostic(paths,player_combat,trainer_files,material):
		return _fail("原活动假人的动画材质、同图路径或 20001 入口未通过来源与装配检查。")
	var pause_source := OS.get_environment("FORMAL_PAUSE_SOURCE")
	if mount_project_contact and not pause_source.is_empty():
		if not _mount_source_pause(pause_source):
			return _fail("原暂停面板合同或私有素材未通过检查。")
		if FileAccess.file_exists(pause_source.path_join("abilities-layout.json")):
			var hud := AbilityHUD.new()
			if not hud.bind(player,pause_source,OS.get_environment("FORMAL_PANEL_SILVER")):
				hud.free()
				return _fail("原 HUD 技能栏的图标或作者合同未通过检查。")
			ability_hud = hud
			scene.add_child(hud)
	return true

## ClickMoveTest is the admitted primary actor, whose inherited CharacterInventory
## owns main, weapon and hotbar. Read the actual replaced PersistenceSystem key.
func primary_bag_owner(actor: Node) -> String:
	if inventory_bags==null or player==null or not is_instance_valid(actor) \
			or actor!=player.get_current_controlled_character_or_player_instance():
		return ""
	return inventory_bags.character_owner(persistables.identifier_for(actor))


func _start_source_audio_preferences() -> bool:
	var flames: Node = scene.flamethrower_audio
	if not is_instance_valid(flames): return false
	var preferences := AudioPreferences.new()
	_listener_prior = AudioServer.get_bus_volume_linear(0)
	if not preferences.start("user://fantasyword-source-audio.cfg",_apply_source_listener,
			{3:flames.set_volume_scale}): return false
	audio_preferences = preferences
	return true

func _apply_source_listener(gain: float) -> void:
	AudioServer.set_bus_volume_linear(0,gain)

func _exit_tree() -> void:
	if audio_preferences==null: return
	var saved := audio_preferences.stop()
	if saved!=OK: push_warning("FantasyWord 音量设置未能保存："+error_string(saved))
	_apply_source_listener(_listener_prior)
	audio_preferences = null

func _mount_source_pause(directory: String) -> bool:
	var menu := PauseRoot.new()
	var source := _read(directory.path_join("pause-contract.json"))
	if not menu.bind(scene,point,source,directory,
			func(): return player.is_current_controlled(scene.actor) \
					and player.accepts_player_input(scene.actor) and player.can_be_player_controlled(scene.actor) \
					and player.can_interact(),
			func():return false):
		menu.free()
		return false
	var settings_path := directory.path_join("settings-contract.json")
	if FileAccess.file_exists(settings_path) and not menu.bind_settings(_read(settings_path),audio_preferences):
		menu.free()
		return false
	var character_layout := directory.path_join("character-layout.json")
	if FileAccess.file_exists(character_layout) and not menu.bind_character(character_layout,
			directory.path_join("character-contract.json"),OS.get_environment("FORMAL_PANEL_SILVER"),
			player.get_current_controlled_character_or_player_instance,player.character_menu_fresh_values,party_money.money):
		menu.free()
		return false
	if FileAccess.file_exists(directory.path_join("inventory-layout.json")) and not menu.bind_inventory(
			inventory_bags,player.get_current_controlled_character_or_player_instance,primary_bag_owner,
			player.inventory_fresh_stats,player.source_equipment,OS.get_environment("FORMAL_PANEL_SILVER")):
		menu.free()
		return false
	if FileAccess.file_exists(directory.path_join("abilities-layout.json")) and not menu.bind_abilities(
			player,OS.get_environment("FORMAL_PANEL_SILVER")):
		menu.free()
		return false
	pause_root = menu
	add_child(menu)
	return true


func _fail(reason: String) -> bool:
	refusal = reason
	if is_instance_valid(scene): scene.free()
	scene = null
	return false


func _mount_damage_screen_flash() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ClickMoveTest 受伤闪屏"
	# 原覆盖层层级：场景过渡之后、测试面板之前。本预览尚未挂场景过渡。
	layer.layer = 4
	scene.add_child(layer)
	damage_screen_flash = DamageScreenFlash.new()
	layer.add_child(damage_screen_flash)
	player.damage_completed.connect(_on_source_player_damage_completed)


func _on_source_player_damage_completed(_source: Variant, input: Dictionary, _previous: int, _applied: int) -> void:
	damage_screen_flash.present(scene.actor,player.get_current_controlled_character_or_player_instance(),input)


func _mount_trainer(paths: Dictionary, files: Array, require_death: bool, random_value: Callable,
		random_range: Callable, effects := "") -> bool:
	var art: String = paths.FORMAL_TRAINER_ATTACK_TEXTURES
	var animation := _read(paths[files[0]])
	var material := _read(paths[files[1]])
	if animation.is_empty() or material.is_empty(): return false
	if require_death and (animation.get("training_target",{}).get("death_animation_key")!="SpinDie"
			or material.get("training_target")!=animation.get("training_target")):
		return false
	trainer_owner = TrainerOwner.new()
	var trainer: Node2D = scene.start_training_damage_target(trainer_owner,trainer_owner.hooks(),7752)
	if not is_instance_valid(trainer) or not trainer_owner.bind_target(trainer): return false
	var trainer_material := {"data":material,"uv_directory":art.path_join("uv"),"appearance_directory":art.path_join("appearance")}
	if not effects.is_empty():
		var gear := player.source_equipment()
		if gear==null or inventory_bags==null: return false
		trainer_material.merge({"effects":effects,"bags":inventory_bags,
			"items":{gear.CLOTH:gear.item_for_guid(gear.CLOTH),gear.SPEAR:gear.item_for_guid(gear.SPEAR)},
			"cloth":OS.get_environment("FORMAL_PLAYER_CLOTH_PNG"),"spear":OS.get_environment("FORMAL_PLAYER_SPEAR_SOURCE")})
	if not is_instance_valid(scene.start_training_target_presentation(animation,art,trainer_material)):
		return false
	if not scene.start_training_target_tracking(player.stats,scene) or not scene.start_training_transit_steering():
		return false
	return scene.start_training_combat_wander(random_value,random_range)


func _mount_trainer_diagnostic(paths: Dictionary, player_combat: bool, files: Array, player_material: Dictionary) -> bool:
	# 显式诊断的固定样本不进入正常启动。
	if not _mount_trainer(paths,files,_trainer_death,func():return .5,func(minimum,_maximum):return minimum):
		return false
	var interrupt := _interrupt_unmounted_player_abilities
	if player_combat:
		var combat := _mount_player_combat(paths.FORMAL_FLAMETHROWER_CUE,func():return 50)
		if not is_instance_valid(combat): return false
		interrupt = combat.interrupt_owned_actions
	if not scene.bind_human_damage_lifecycle(player.is_destroyed,interrupt):
		return false
	if _player_death:
		if not scene.bind_source_primary_death(player,player_material): return false
	else:
		player.damage_completed.connect(_end_diagnostic_on_zero_health)
	return is_instance_valid(scene.start_training_basic_attack(
		player.get_target_direction,player.damage_hooks(),func():return 50))


func _mount_player_combat(cue_dir: String, damage_roll: Callable) -> Node:
	if not scene.start_human_command_execution(player): return null
	# 原热键只提交槽位，无目标、Cell 或显式朝向。
	var combat: Node = scene.start_human_fresh_source_combat(player,damage_roll,
		func(_target):return null,func(_target):return null,_on_source_ability_rejected)
	if not is_instance_valid(combat) or not scene.bind_human_gameplay_actions(func():
		if not player.is_current_controlled(scene.actor): return null
		return {"actor":player,"command_context":{"actor":player,"issuer_kind":1,"issuer_id":"local"}},
		func():return false,_on_source_gameplay_command_failed) or not scene.bind_human_ability_keyboard():
		return null
	if not scene.bind_flamethrower_cues(player,cue_dir.path_join("FlamethrowerJet.png"),
			cue_dir.path_join("Flamethrower_FireSpell03_CC0.ogg")):
		return null
	return combat


func _on_unadmitted_interact_success() -> void:
	push_error("ClickMoveTest 没有已获准的交互接收件；不得假造频道 2 的原成功音效。")

func _interrupt_unmounted_player_abilities() -> void:
	# 原安全阶段只通知能力拥有者；未挂能力时不伪造取消动作，也不清移动或输入。
	pass


func _end_diagnostic_on_zero_health(_source: Variant,_input: Dictionary,_previous: int,_applied: int) -> void:
	if player.current_health()==0:
		# 不继续伪造尚无正式来源接线的玩家死亡生命周期。
		call_deferred("_finish_at_unsupported_death")


func _finish_at_unsupported_death() -> void:
	print("玩家生命归零；诊断结束，未装配正式死亡流程。")
	if is_instance_valid(scene): scene.free()
	get_tree().quit()

func _read(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path))!=OK or not json.data is Dictionary: return {}
	return json.data


func _on_source_ability_rejected(code: int, reason: int) -> void:
	if is_instance_valid(ability_hud): ability_hud.message.on_ability_rejected(code,reason)


func _on_source_gameplay_command_failed(request: Dictionary, reason: int) -> void:
	if is_instance_valid(ability_hud): ability_hud.message.on_command_failed(request,reason)


func _over_native_ui(point_in_viewport: Vector2) -> bool:
	# InputSystem 校验本次 Point 的射线；这里不能仅依赖上一次 GUI 悬停。
	if is_instance_valid(ability_hud) and ability_hud.blocks_map_pointer(point_in_viewport): return true
	var hovered := get_viewport().gui_get_hovered_control()
	# HUD 用上面的实时命中规则，不让滞后的原生悬停吞掉空隙点击。
	return is_instance_valid(hovered) and (not is_instance_valid(ability_hud) or not ability_hud.is_ancestor_of(hovered))
