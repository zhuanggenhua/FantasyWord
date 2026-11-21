extends RefCounted
## Original human Workbench scope: spear (main) and heavy shield (off hand).
const Pose = preload("res://gameplay/presentation/equipment_weapon_pose.gd")
const SubsetMaterial = preload("res://gameplay/presentation/equipment_subset_material.gd")
const SlotIcon = preload("res://gameplay/equipment_workbench/slot_icon.gd")
const MANIFEST := "0876b714bcb85858bd796a3d2352f10d0dfcb2411066cec69a6e7b5ac5364033"
const STATS := ["体质", "生命", "力量", "智力", "魔力"]
const TYPES := ["武器", "盾牌"]
const KEYS := ["se", "sw", "ne", "nw"]

var options: Array[Dictionary] = []
var worn: Array[bool] = [false,false]
var _textures: Dictionary = {}
var _frames: Dictionary = {}
var _material: ShaderMaterial
var _playback: Node
var binding_error := ""

func load_source(dir: String) -> bool:
	var manifest := dir.path_join("weapons.json")
	if FileAccess.get_sha256(manifest) != MANIFEST:
		return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	for key in data.textures:
		var item: Dictionary = data.textures[key]
		var path := dir.path_join(item.file)
		var img := Image.new()
		if FileAccess.get_sha256(path) != item.sha256 or img.load(path) != OK or img.get_size() != Vector2i(item.size[0], item.size[1]):
			return false
		_textures[key] = ImageTexture.create_from_image(img)
	for key in data.frames:
		var by_frame := {}
		for row: Array in data.frames[key]:
			by_frame[Vector2i(int(row[0]),int(row[1]))] = [int(row[2]),_anchor(row[3]),_anchor(row[4])]
		_frames[key] = by_frame
	for option: Dictionary in data.options:
		var sprites := {}
		for i in 4:
			sprites[KEYS[i]] = _sprite(option.directions[i])
		var seqs := {}
		for act in option.sequences:
			var rows := []
			for row: Array in option.sequences[act]:
				var strip := []
				for frame: Dictionary in row:
					strip.append({"sprite":_sprite(frame.sprite), "depth_back":frame.depth_back})
				rows.append(strip)
			seqs[act] = rows
		options.append({"name":option.name,"stats":option.stats,"sprites":sprites,"sequence":seqs,"is_shield":int(option.type)==9})
	return true

func _sprite(row: Variant) -> Variant:
	if row == null: return null
	return {"texture":_textures[row.texture],"rect":Rect2(row.rect[0],row.rect[1],row.rect[2],row.rect[3])}

static func _anchor(row: Variant) -> Variant:
	return null if row == null else {"position":Vector2i(int(row[0]),int(row[1])),"direction":int(row[2])}

func bind(material: ShaderMaterial, playback: Node) -> void:
	_material = material
	_playback = playback
	_playback.sample_resolved.connect(_on_sample)
	_update_now()

func select(slot: int, value: bool) -> void:
	worn[slot] = value
	_update_now()

func reset() -> void:
	worn = [false,false]
	_update_now()

func _update_now() -> void:
	_on_sample(_playback.current_action,_playback.current_label,_playback.current_direction,_playback.sprite.texture)

func _on_sample(action: String, label: int, direction: int, sample: Texture2D) -> void:
	var frame: Variant = _frames.get(action,{}).get(Vector2i(label,direction))
	if frame == null or not sample is AtlasTexture or not (worn[0] or worn[1]):
		SubsetMaterial.reset_weapon_fill(_material)
		return
	var atlas := sample as AtlasTexture
	var tex_size: Vector2 = atlas.atlas.get_size()
	var bounds: Rect2 = atlas.region
	# Godot atlas regions are top-origin; the original shader contract is bottom-origin.
	var normalized := Rect2(Vector2(bounds.position.x,tex_size.y-bounds.end.y)/tex_size,bounds.size/tex_size)
	var facing: int = frame[0]
	var slots: Array = [{},{}]
	for i in 2:
		if not worn[i]: continue
		var option := options[i]
		var configured: bool = option.sequence.has(action)
		var seq: Dictionary = option.sequence[action][facing][label] if configured else {}
		var result := Pose.resolve(facing,i==0,bounds.size,frame[i+1],option,configured,seq)
		if not result.enabled: continue
		var sprite: Dictionary = result.sprite
		var size: Vector2 = sprite.texture.get_size()
		var rect: Rect2 = sprite.rect
		slots[i] = {"enabled":true,"texture":sprite.texture,"rect":Rect2(rect.position/size,rect.size/size),
			"anchor_frame_uv":result.anchor_frame_uv,"hand_local_uv":result.hand_local_uv,"rot_cos_sin":result.rot_cos_sin,
			"flip_x":result.flip_x,"depth_mode":float(result.slot_is_front),"hand_in_front":float(result.hand_in_front)}
	var outcome := SubsetMaterial.apply_weapon_fill(_material,normalized,slots)
	binding_error = "" if outcome.ok else outcome.reason

func icon(slot: int) -> ImageTexture:
	var item := options[slot]
	var sprite: Dictionary = item.sequence.Attack[0][0].sprite if item.sequence.has("Attack") else item.sprites.se
	var im: Image = sprite.texture.get_image()
	var rect: Rect2 = sprite.rect
	return SlotIcon.from_sprite(im.get_region(Rect2i(int(rect.position.x),im.get_height()-int(rect.end.y),int(rect.size.x),int(rect.size.y))))

func details(slot: int) -> String:
	if not worn[slot]: return TYPES[slot] + "\n当前为空"
	var item := options[slot]
	var lines: Array[String] = [item.name,TYPES[slot]]
	for row in item.stats:
		lines.append("%s %+d" % [STATS[int(row.stat)],int(row.value)])
	return "\n".join(lines)
