extends Node2D
## 原 Human Idle/Walk 的显式私有图集入口；不替代换装材质、影子或其它动作。
const Playback = preload("res://game_core/presentation/directional_sprite_playback.gd")
const Driver = preload("res://game_core/presentation/character_action_animator_driver.gd")
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
var sprite: Sprite2D
var playback: Node
var driver: Node
var animator: AnimationPlayer
var last_error := ""
var material_binding: RefCounted
var _animation_contract := {}

func configure(data: Dictionary, texture_directory: String) -> bool:
	if sprite != null or not is_inside_tree():
		return _fail("入口须先进入场景树且只能配置一次。")
	if data.get("schema") != 1 or data.get("source_commit") != SOURCE or not data.get("textures") is Dictionary or not data.get("actions") is Dictionary:
		return _fail("缺少锁定来源的私有动画合同。")
	if data.actions.size() != 2 or not data.actions.has_all(["Idle", "Walk"]):
		return _fail("本入口只接入已核实的 Idle/Walk。")
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
	for action in ["Idle","Walk"]:
		if not data.actions[action] is Dictionary: return _fail("动作合同必须为字典。")
		var record: Dictionary = data.actions[action]
		if not record.get("directions") is Array or record.directions.size() != 4:
			return _fail("缺少完整四向精灵库。")
		var dirs := []
		for records in record.directions:
			if not records is Array or records.is_empty():
				return _fail("方向精灵库为空。")
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
	driver.action_keys.assign(["Idle","Walk"])
	_animation_contract = data.duplicate(true)
	return driver.try_play_animation("Idle")

## 输入为原 owner 的实际动画位移量，而非按键意图。
func set_movement(source_movement: Vector2) -> void:
	if driver != null: driver.set_movement(source_movement)

## 输入为原 owner 已裁决的身体朝向；不能自行用移动向量覆盖锁定朝向。
func set_facing(source_facing: Vector2) -> void:
	if playback != null: playback.set_facing_direction(source_facing)

## Attach only the verified base look to the existing live sprite. No automatic entry or assets.
func bind_base_material(data: Dictionary, uv_directory: String, appearance_directory: String) -> bool:
	if material_binding != null or sprite == null: return _fail("Human appearance requires a configured, unbound sprite.")
	var binding = preload("res://gameplay/clickmovetest/human_material_binding.gd").new()
	if not binding.configure(sprite,playback,driver,_animation_contract,data,uv_directory,appearance_directory):
		return _fail(binding.last_error)
	last_error = ""
	material_binding = binding
	return true

func _exit_tree() -> void:
	if material_binding != null:
		material_binding.disconnect_from_view()
		material_binding = null

func _fail(message: String) -> bool:
	last_error=message
	return false
