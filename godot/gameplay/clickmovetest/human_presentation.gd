extends Node2D
## 原 Human Idle/Walk 与可选 Dmg/ChargedAttack/Attack 和经核实拥有者的 SpinDie 的显式私有图集入口；不补造受伤事件。
const Playback = preload("res://game_core/presentation/directional_sprite_playback.gd")
const Driver = preload("res://game_core/presentation/character_action_animator_driver.gd")
const Gear = preload("res://game_core/inventory/source_character_equipment.gd")
const Weapons = preload("res://gameplay/equipment_workbench/weapons_preview.gd")
const PrimaryEffects = preload("res://gameplay/clickmovetest/primary_frame_effects.gd")
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
const CLOTH_PNG_SHA := "95616de6ca800e3ee1baf2e1d6bac8832c6237cf2d784901e6fa1ea78a09bde9"
var sprite: Sprite2D
var playback: Node
var driver: Node
var animator: AnimationPlayer
var last_error := ""
var material_binding: RefCounted
var _animation_contract := {}
var _source_cloth_gear: Gear
var _source_cloth: ImageTexture
var _source_spear_gear: Gear
var _source_spear: Weapons

static func valid_primary_death(source: Variant) -> bool:
	return source is Dictionary and source.get("config_guid")=="b669f9c81be34b47bf3d083609477ab5" \
		and source.get("config_sha256")=="db6a051cac869871f8fc403b305a1fe0a8c41e125ef37faa7f4b8a60f1607a21" \
		and source.get("action_rid")==-2 and source.get("animation_key")=="SpinDie" \
		and source.get("actor_file_id")=="735002000000000004"

func configure(data: Dictionary, texture_directory: String, workbench_slash := false, workbench_spin := false) -> bool:
	if sprite != null or not is_inside_tree():
		return _fail("入口须先进入场景树且只能配置一次。")
	if data.get("schema") != 1 or data.get("source_commit") != SOURCE or not data.get("textures") is Dictionary or not data.get("actions") is Dictionary:
		return _fail("缺少锁定来源的私有动画合同。")
	var admitted := ["Idle", "Walk", "Dmg", "ChargedAttack", "Attack", "SpinDie"]
	if workbench_slash: admitted.append("SlashAttack")
	if not data.actions.has_all(["Idle", "Walk"]) or data.actions.keys().any(func(key): return key not in admitted):
		return _fail("本入口只接入已核实的 Idle/Walk 及显式提供的 Dmg/ChargedAttack/Attack/SpinDie。")
	if data.actions.has("SpinDie"):
		var target: Variant = data.get("training_target")
		var is_trainer: bool = target is Dictionary and target.get("death_animation_key")=="SpinDie" \
			and target.get("prefab_guid")=="dca23ea6afacc0647bfd10c5cefa4099"
		var is_primary := valid_primary_death(data.get("primary_death"))
		var spin_scope: Variant = data.get("workbench_spin")
		var is_workbench: bool = workbench_spin and spin_scope=={
			"scene":"Assets/Scenes/EquipmentSystemDemo.unity",
			"scene_sha256":"46e43f5f0ebfacae2ec1b8a5c123375c5667a4ae1c171d14f1aecf297d5706fc",
			"animation_key":"SpinDie"}
		if workbench_spin != is_workbench or data.has("workbench_spin") != is_workbench \
				or int(is_primary)+int(is_trainer)+int(is_workbench)!=1 \
				or (is_primary and data.has("training_target")) \
				or (is_workbench and (data.has("primary_death") or data.has("training_target"))):
			return _fail("SpinDie 须来自唯一且已核实的场景角色，不能借用另一角色的合同。")
	var loaded := {}
	for name in data.textures:
		if not name is String or name != name.get_file() or not name.ends_with(".png"):
			return _fail("纹理必须为合同内的 PNG 文件名。")
		if not data.textures[name] is Dictionary: return _fail("纹理合同必须为字典。")
		var spec: Dictionary = data.textures[name]
		var path := texture_directory.path_join(name)
		if FileAccess.get_sha256(path) != spec.get("sha256") or spec.get("pixels_per_unit") != 8:
			return _fail("原纹理哈希或 PPU 不一致。")
		var image := Image.new()
		if not spec.get("size") is Array or spec.size.size() != 2: return _fail("纹理尺寸合同无效。")
		if image.load(path) != OK or image.get_width() != spec.size[0] or image.get_height() != spec.size[1]:
			return _fail("原纹理尺寸不一致。")
		loaded[name] = ImageTexture.create_from_image(image)
	var actions := {}
	for action in data.actions:
		if not data.actions[action] is Dictionary: return _fail("动作合同必须为字典。")
		var record: Dictionary = data.actions[action]
		if not record.get("directions") is Array or record.directions.size() != 4:
			return _fail("缺少完整四向精灵库。")
		var dirs := []
		for records in record.directions:
			if not records is Array or records.is_empty():
				return _fail("方向精灵库为空。")
			if action == "SpinDie" and not dirs.is_empty():
				# Unity 四个方向库引用同一组 Sprite；换朝向不会换 Sprite 或重复刷新外观。
				if records != record.directions[0]:
					return _fail("SpinDie 方向库未引用同一组原精灵。")
				dirs.append(dirs[0])
				continue
			if action == "ChargedAttack" and dirs.size()==3 and records==record.directions[0]:
				# The locked SE and NW libraries point at the very same Sprite assets.
				dirs.append(dirs[0])
				continue
			var frames := []
			for frame in records:
				if not frame is Dictionary or not frame.get("rect") is Array or frame.rect.size() != 4 or not loaded.has(frame.get("texture")):
					return _fail("精灵区域或图集引用无效。")
				var r: Array = frame.rect
				for number in r:
					if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(number) or float(number) != floorf(number):
						return _fail("精灵区域必须是整像素。")
				var atlas: Texture2D = loaded[frame.texture]
				if r[0] < 0 or r[1] < 0 or r[2] != 32 or r[3] != 32 or r[0]+32 > atlas.get_width() or r[1]+32 > atlas.get_height():
					return _fail("精灵区域超出原图集。")
				var texture := AtlasTexture.new()
				texture.atlas = atlas
				# Unity Sprite.rect 从左下开始；Godot 纹理区域从左上开始。
				texture.region = Rect2(r[0],atlas.get_height()-r[1]-r[3],r[2],r[3])
				texture.filter_clip = true
				frames.append(texture)
			dirs.append(frames)
		var labels: Array[int] = []
		if not record.get("labels") is Array: return _fail("缺少动画标签。")
		for label in record.labels:
			if typeof(label) not in [TYPE_INT,TYPE_FLOAT] or float(label) != floorf(label): return _fail("动画标签无效。")
			labels.append(int(label))
		actions[action] = {"duration":record.get("duration"),"loop":record.get("loop"),"times":record.get("times"),"labels":labels,"directions":dirs}
	var target := Sprite2D.new()
	var player := AnimationPlayer.new()
	var view := Playback.new()
	add_child(target); add_child(player); add_child(view)
	if not view.configure(target,player,actions):
		last_error = view.last_error; target.free();player.free();view.free();return false
	sprite=target; animator=player; playback=view
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale=Vector2.ONE/8.0
	driver=Driver.new(); add_child(driver)
	driver.animator=animator
	driver.action_keys.assign(data.actions.keys())
	_animation_contract = data.duplicate(true)
	return driver.try_play_animation("Idle")

## 仅接受外部明确裁决的表现请求；不在此伪造伤害、生命值或输入事件。
func try_play_damage_animation() -> bool:
	if driver == null: return false
	return driver.try_play_damage_animation()

## 输入为原 owner 的实际动画位移量，而非按键意图。
func set_movement(source_movement: Vector2) -> void:
	if driver != null: driver.set_movement(source_movement)

## 输入为原 owner 已裁决的身体朝向；不能自行用移动向量覆盖锁定朝向。
func set_facing(source_facing: Vector2) -> void:
	if playback != null: playback.set_facing_direction(source_facing)

## Attach only the verified base look to the existing live sprite. No automatic entry or assets.
func bind_base_material(data: Dictionary, uv_directory: String, appearance_directory: String, workbench_weapon_stage := false) -> bool:
	if material_binding != null or sprite == null: return _fail("Human appearance requires a configured, unbound sprite.")
	var binding = preload("res://gameplay/clickmovetest/human_material_binding.gd").new()
	if not binding.configure(sprite,playback,driver,_animation_contract,data,uv_directory,appearance_directory,workbench_weapon_stage):
		return _fail(binding.last_error)
	last_error = ""
	material_binding = binding
	return true

## CharacterEquipmentPresentation 的基础布衣切片：监听同一个正式演员，
## 不修改背包、不切换动画、不将设计工作台的状态当成玩法装备。
func bind_source_cloth(gear: Gear, cloth_png: String) -> bool:
	var body := get_parent()
	if _source_cloth_gear!=null or material_binding==null or body==null or gear==null \
			or not gear.belongs_to(body.get_parent()) or gear.item_for_guid(Gear.CLOTH)==null:
		return _fail("布衣必须绑定同一正式演员的装备和现有原材质。")
	if not FileAccess.file_exists(cloth_png) or FileAccess.get_sha256(cloth_png)!=CLOTH_PNG_SHA:
		return _fail("基础布衣原图哈希不符。")
	var image := Image.load_from_file(cloth_png)
	if image==null or image.get_size()!=Vector2i(32,32):
		return _fail("基础布衣原精灵必须是 32×32。")
	_source_cloth = ImageTexture.create_from_image(image)
	_source_cloth_gear = gear
	gear.loadout_changed.connect(_refresh_source_cloth)
	_refresh_source_cloth()
	last_error = ""
	return true

func _refresh_source_cloth() -> void:
	var equipped := _source_cloth_gear.equipped(Gear.Slot.TORSO)==_source_cloth_gear.item_for_guid(Gear.CLOTH)
	var current: ShaderMaterial = material_binding.material
	# 原 Clothing 四向共用同一 Sprite，整张 32×32，且没有偏向变体。
	current.set_shader_parameter("cloth_map",_source_cloth if equipped else null)
	current.set_shader_parameter("cloth_rect",Vector4(0,0,1,1))
	current.set_shader_parameter("enabled_cloth",equipped)

func bind_source_standing_render(gear: Gear, directory: String, effects_path := "") -> bool:
	if not valid_primary_death(_animation_contract.get("primary_death")):
		return _fail("站立材质须接到原主角的实际动作库。")
	return _bind_actor_standing_render(gear,directory,effects_path)

## The original trainer inherits CharacterEquipment and EquipmentRenderer
## from the same authored base, but owns its slots and material separately.
func bind_source_trainer_render(gear: Gear, directory: String, effects_path: String) -> bool:
	var owner: Variant = _animation_contract.get("training_target")
	if not owner is Dictionary or owner.get("prefab_guid")!="dca23ea6afacc0647bfd10c5cefa4099" \
			or owner.get("death_animation_key")!="SpinDie" or directory.is_empty() or effects_path.is_empty():
		return _fail("须提供正式训练假人动作库和原长矛、轮廓及阴影合同。")
	return _bind_actor_standing_render(gear,directory,effects_path)

func _bind_actor_standing_render(gear: Gear, directory: String, effects_path: String) -> bool:
	var body := get_parent()
	if _source_spear!=null or body==null or gear==null or material_binding==null \
			or material_binding.material.shader!=Weapons.SubsetMaterial.WEAPON_SUBSET \
			or not gear.belongs_to(body.get_parent()) or gear.item_for_guid(Gear.SPEAR)==null \
			or not _animation_contract.actions.has_all(["Idle","Walk","Attack","Dmg","SpinDie"]):
		return _fail("站立材质须接到同一角色的原装备与动作库。")
	var binding := Weapons.new()
	if not directory.is_empty() and not binding.load_source(directory,true):
		return _fail("缺少经核对的原长矛图和人物锚点合同。")
	var effects: PrimaryEffects
	if not effects_path.is_empty():
		effects = PrimaryEffects.new()
		if not effects.load_source(effects_path):
			return _fail("缺少同一人类帧数据库的原轮廓和阴影合同。")
	_source_spear = binding
	_source_spear_gear = gear
	binding.bind(material_binding.material,playback,effects)
	gear.loadout_changed.connect(_refresh_source_spear)
	_refresh_source_spear()
	if not binding.binding_error.is_empty():
		return _fail(binding.binding_error)
	last_error = ""
	return true

func _refresh_source_spear() -> void:
	var equipped := _source_spear_gear.equipped(Gear.Slot.WEAPON)==_source_spear_gear.item_for_guid(Gear.SPEAR)
	# Actual actor's equipment owns the state. No Workbench option changes it.
	_source_spear.select(0,0 if equipped and not _source_spear.options.is_empty() else -1)

## EquipmentRenderer.TryGetGroundAnchorWorldPosition；仅支持已经核实的正中 FullRect 人形帧。
## 原帧高 32，groundPixelY=18；从中心到行像素中心是 2.5 个向下的图集像素。
func reflection_ground_anchor() -> Variant:
	if material_binding==null or not is_instance_valid(sprite) or not sprite.texture is AtlasTexture \
			or not is_instance_valid(driver) or driver.current_animation_key not in ["Idle","Walk","Dmg","Attack","SpinDie"] \
			or sprite.texture.region.size!=Vector2(32,32) or not sprite.centered or sprite.offset!=Vector2.ZERO:
		return null
	var world_bounds := sprite.global_transform * sprite.get_rect()
	var ground := sprite.global_transform * Vector2(0,-2.5 if sprite.flip_v else 2.5)
	return Vector2(world_bounds.get_center().x,ground.y)

func _exit_tree() -> void:
	if _source_spear!=null:
		_source_spear_gear.loadout_changed.disconnect(_refresh_source_spear)
		_source_spear.disconnect_from_view()
		_source_spear_gear=null
		_source_spear=null
	if _source_cloth_gear!=null:
		_source_cloth_gear.loadout_changed.disconnect(_refresh_source_cloth)
		_source_cloth_gear=null
		_source_cloth=null
	if material_binding != null:
		material_binding.disconnect_from_view()
		material_binding = null

func _fail(message: String) -> bool:
	last_error=message
	return false
