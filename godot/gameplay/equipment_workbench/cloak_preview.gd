extends RefCounted
## Workbench-only mapping of the original Torso frame data to EquipmentRenderer's Cloak layer.
const CRAFT_FRAMES := {"AnvilWorking":6,"JewelryWorkshopWorking":11,"LaboratoryWorking":11,"WoodworkBenchWorking":6}
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
const EXPECTED_OPTIONS := ["12a1ff95e55e6e945952dd3f3773984b", "28bc3987db4b748408e99b8f8f982f42"]
const ACTION_FRAMES := {"Idle": 16, "Walk": 4, "Attack": 4, "Dmg": 4}

var options: Array
var selected := -1
var last_texture_guid := ""
var _frames: Dictionary
var _textures: Dictionary
var _material: ShaderMaterial
var _playback: Node

func load_source(directory: String, with_slash := false, with_spin := false, with_charge := false, with_moves := false, with_gather := false, with_craft := false) -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("cloak.json")))
	if not data is Dictionary or data.get("source_commit") != SOURCE:
		return false
	var input_textures: Variant = data.get("textures")
	var input_options: Variant = data.get("options")
	var input_frames: Variant = data.get("frames")
	if not input_textures is Dictionary or input_textures.size() != 10 or not input_options is Array or input_options.size() != 2 or not input_frames is Dictionary:
		return false
	var textures := {}
	for guid in input_textures:
		var entry: Variant = input_textures[guid]
		if not entry is Dictionary or not entry.get("file") is String or not entry.get("sha256") is String:
			return false
		var name: String = entry.file
		if name != name.get_file() or name.get_extension() != "png":
			return false
		var path := directory.path_join(name)
		var image := Image.new()
		if entry.sha256.length() != 64 or FileAccess.get_sha256(path) != entry.sha256 or image.load(path) != OK or image.get_size() != Vector2i(32, 32):
			return false
		textures[guid] = ImageTexture.create_from_image(image)
	for i in input_options.size():
		var option: Variant = input_options[i]
		if not option is Dictionary or option.get("guid") != EXPECTED_OPTIONS[i] or not option.get("name") is String or not option.get("description") is String or not option.get("stats") is Array:
			return false
		for stat in option.stats:
			if not stat is Dictionary or not _bounded(stat.get("stat"), 5) or not stat.get("value") is float:
				return false
		var sets: Variant = option.get("sprite_sets")
		if not sets is Array or sets.size() != 5:
			return false
		for row in sets:
			if not row is Array or row.size() != 4:
				return false
			for guid in row:
				if guid != null and not textures.has(guid):
					return false
		if sets[0][0] == null or sets[0][1] == null:
			return false
	var frames := {}
	var counts := ACTION_FRAMES.duplicate()
	if with_slash: counts["SlashAttack"] = 4
	if with_moves:
		counts["Dmg2"] = 4
		counts["Jump"] = 4
	if with_gather:
		for key in ["Harvest","Chopping","Mining"]: counts[key] = 6
	for action in counts:
		var rows: Variant = input_frames.get(action)
		var count: int = counts[action]
		if not rows is Array or rows.size() != count * 4:
			return false
		var by_key := {}
		for row in rows:
			if not row is Array or row.size() != 4 or not _bounded(row[0], count) or not _bounded(row[1], 4) or not _bounded(row[2], 4) or not _bounded(row[3], 5):
				return false
			var key := Vector2i(int(row[0]), int(row[1]))
			if by_key.has(key) or (action in ["SlashAttack","Dmg2","Jump","Harvest","Chopping","Mining"] and (row[1] != row[2] or row[3] != 0)):
				return false
			by_key[key] = Vector2i(int(row[2]), int(row[3]))
		frames[action] = by_key
	var same_row_counts := {}
	if with_spin: same_row_counts["SpinDie"] = 12
	if with_moves: same_row_counts["SoulDie"] = 12
	if with_craft: same_row_counts.merge(CRAFT_FRAMES)
	for action in same_row_counts:
		var count: int = same_row_counts[action]
		var rows: Variant = input_frames.get(action)
		if not rows is Array or rows.size()!=count: return false
		var by_key := {}
		for label in count:
			# 四个精灵库共用一行；无躯干区域也按原行 0 / Base。
			var row: Variant = rows[label]
			if not row is Array or row.size()!=4 or not _bounded(row[0],count) or row[0]!=label \
					or not _bounded(row[1],1) or not _bounded(row[2],1) or not _bounded(row[3],1): return false
			by_key[Vector2i(label,0)] = Vector2i.ZERO
		frames[action] = by_key
	if with_charge:
		var rows: Variant = input_frames.get("ChargedAttack")
		if not rows is Array or rows.size()!=18: return false
		var by_key := {}
		for i in 18:
			var row: Variant = rows[i]
			var facing := floori(float(i)/6.0)
			if not row is Array or row.size()!=4: return false
			var expected := [i%6,facing,facing,0]
			for column in 4:
				if not _bounded(row[column],6) or row[column]!=expected[column]: return false
			by_key[Vector2i(i%6,facing)] = Vector2i(facing,0)
		frames["ChargedAttack"] = by_key
	options = input_options
	_frames = frames
	_textures = textures
	return true

static func _bounded(value: Variant, exclusive_max: int) -> bool:
	return value is float and is_finite(value) and floor(value) == value and value >= 0 and value < exclusive_max

func bind(material: ShaderMaterial, playback: Node) -> void:
	_material = material
	_playback = playback
	_material.set_shader_parameter("cloak_rect", Vector4(0, 0, 1, 1))
	_playback.sample_resolved.connect(_on_sample)
	select(-1)

func select(index: int) -> void:
	selected = index
	_on_sample(_playback.current_action, _playback.current_label, _playback.current_direction, null)

func torso_for_sample(action: String, label: int, direction: int) -> Variant:
	var row := direction
	if action in ["SpinDie","SoulDie"] or CRAFT_FRAMES.has(action) or (action=="ChargedAttack" and direction==3): row=0
	return _frames.get(action, {}).get(Vector2i(label,row))

func _on_sample(action: String, label: int, direction: int, _sprite: Texture2D) -> void:
	var row: Variant = torso_for_sample(action, label, direction)
	var texture: Texture2D
	last_texture_guid = ""
	if selected >= 0 and row is Vector2i:
		var guid: Variant = resolve_guid(options[selected].sprite_sets, row.x, row.y)
		texture = _textures.get(guid)
		if texture != null:
			last_texture_guid = guid
	_material.set_shader_parameter("enabled_cloak", texture != null)
	_material.set_shader_parameter("cloak_map", texture)

static func resolve_guid(sets: Array, facing: int, variant: int) -> Variant:
	# Original HasVariant requires the variant's SE sprite; fallback then follows the chosen set.
	var sprites: Array = sets[variant] if sets[variant][0] != null else sets[0]
	if sprites[facing] != null:
		return sprites[facing]
	if facing == 3 and sprites[1] != null:
		return sprites[1]
	return sprites[0]

func icon_for(index: int) -> ImageTexture:
	var texture: ImageTexture = _textures[options[index].sprite_sets[0][0]]
	var image := texture.get_image()
	return ImageTexture.create_from_image(image.get_region(image.get_used_rect()))

func details_for(index: int) -> String:
	var option: Dictionary = options[index]
	var lines: Array[String] = [option.name, "斗篷", option.description]
	for stat in option.stats:
		var name: String = ["体质", "生命", "力量", "智力", "魔力"][int(stat.stat)]
		lines.append("%s %+d" % [name, int(stat.value)])
	return "\n".join(lines)
