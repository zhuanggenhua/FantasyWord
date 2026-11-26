extends RefCounted
## Original human Workbench scope: main-hand weapons and off-hand shields.
const Pose = preload("res://gameplay/presentation/equipment_weapon_pose.gd")
const SubsetMaterial = preload("res://gameplay/presentation/equipment_subset_material.gd")
const SlotIcon = preload("res://gameplay/equipment_workbench/slot_icon.gd")
const MANIFESTS := [
	"b24dbe5b601fe137b3d4e54b703b6bcc413e843120a93bfadc226d4cd1454a0b",
	"0876b714bcb85858bd796a3d2352f10d0dfcb2411066cec69a6e7b5ac5364033",
	"9d5394a2de7726d591700f02237d4d3bdb1c0a0c13178c7525680a83a2921578",
]
const FORMAL_SPEAR_HASH := "ae0b9f2850574837396fdd0021b26d49877e579f8d4e25b8ff849d3b658a25da"
const BUTTON_NAMES := {"战斧":"EquipAxe", "长矛":"EquipSpear", "重盾":"EquipShield", "圆盾":"EquipRoundShield"}
const STATS := ["体质", "生命", "力量", "智力", "魔力"]
const TYPES := ["武器", "盾牌"]
const KEYS := ["se", "sw", "ne", "nw"]

var options: Array[Dictionary] = []
var worn: Array[int] = [-1,-1]
var _textures: Dictionary = {}
var _frames: Dictionary = {}
var _material: ShaderMaterial
var _playback: Node
var binding_error := ""
var _frame_effects: RefCounted
var _frame_lookup: Callable

func load_source(dir: String, formal_spear := false) -> bool:
	var manifest := dir.path_join("player-spear.json" if formal_spear else "weapons.json")
	if FileAccess.get_sha256(manifest) not in ([FORMAL_SPEAR_HASH] if formal_spear else MANIFESTS):
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
		options.append({"name":option.name,"stats":option.stats,"sprites":sprites,"sequence":seqs,
			"slot":int(option.type)-8,"is_shield":int(option.type)==9})
	return true

func supports_slash_attack() -> bool:
	return _frames.has("SlashAttack") and _frames.SlashAttack.size()==16 \
		and options.any(func(item):return item.name=="战斧" and item.sequence.has("SlashAttack"))

func supports_anchorless_war_horse() -> bool:
	# The mounted animation override uses Idle/Walk, even if the character
	# requested an unsupported Attack. Never look up the standing sequence.
	return not options.is_empty() and options.all(func(item: Dictionary) -> bool:
		return not item.sequence.has("Idle") and not item.sequence.has("Walk"))

func _sprite(row: Variant) -> Variant:
	if row == null: return null
	return {"texture":_textures[row.texture],"rect":Rect2(row.rect[0],row.rect[1],row.rect[2],row.rect[3])}

static func _anchor(row: Variant) -> Variant:
	return null if row == null else {"position":Vector2i(int(row[0]),int(row[1])),"direction":int(row[2])}

func bind(material: ShaderMaterial, playback: Node, frame_effects: RefCounted = null,
		frame_lookup := Callable()) -> void:
	_frame_effects = frame_effects
	_frame_lookup = frame_lookup
	_material = material
	_playback = playback
	_playback.sample_resolved.connect(_on_sample)
	if _frame_lookup.is_valid(): _playback.direction_applied.connect(_on_direction_applied)
	_update_now()

func disconnect_from_view() -> void:
	if is_instance_valid(_playback) and _playback.sample_resolved.is_connected(_on_sample):
		_playback.sample_resolved.disconnect(_on_sample)
	if is_instance_valid(_playback) and _playback.direction_applied.is_connected(_on_direction_applied):
		_playback.direction_applied.disconnect(_on_direction_applied)
	_frame_lookup=Callable()
	_playback=null
	_material=null
	_frame_effects=null

func ids_for(slot: int) -> Array[int]:
	var result: Array[int] = []
	for i in options.size():
		if options[i].slot == slot: result.append(i)
	return result

func select(slot: int, option: int) -> void:
	if slot not in [0,1] or option < -1 or option >= options.size():
		return
	if option >= 0 and options[option].slot != slot:
		return
	worn[slot] = option
	_update_now()

func reset() -> void:
	worn = [-1,-1]
	_update_now()

func _on_direction_applied(_direction: int) -> void:
	_update_now()

func _update_now() -> void:
	if not is_instance_valid(_playback): return
	_on_sample(_playback.current_action,_playback.current_label,_playback.current_direction,_playback.sprite.texture)

func _on_sample(action: String, label: int, direction: int, sample: Texture2D) -> void:
	var frame: Variant = _frames.get(action,{}).get(Vector2i(label,direction))
	var frame_index := label
	if _frame_lookup.is_valid():
		var selected: Variant = _frame_lookup.call(action,sample)
		frame = null if selected == null else selected.frame
		if selected != null: frame_index = selected.index
	if not sample is AtlasTexture or (_frame_effects == null and (frame == null or worn == [-1,-1])):
		SubsetMaterial.reset_weapon_fill(_material)
		return
	var atlas := sample as AtlasTexture
	var tex_size: Vector2 = atlas.atlas.get_size()
	var bounds: Rect2 = atlas.region
	# Godot atlas regions are top-origin; the original shader contract is bottom-origin.
	var normalized := Rect2(Vector2(bounds.position.x,tex_size.y-bounds.end.y)/tex_size,bounds.size/tex_size)
	var slots: Array = [{},{}]
	var slot_flags := [{"is_sequence":0.0,"hide_outline_on_body":0.0},{"is_sequence":0.0,"hide_outline_on_body":0.0}]
	for i in 2:
		if frame == null or worn[i] < 0: continue
		var facing: int = frame[0]
		var option := options[worn[i]]
		var configured: bool = option.sequence.has(action)
		var strip: Array = option.sequence[action][facing] if configured else []
		var seq: Dictionary = strip[frame_index] if frame_index >= 0 and frame_index < strip.size() else {}
		var result := Pose.resolve(facing,i==0,bounds.size,frame[i+1],option,configured,seq)
		if not result.enabled: continue
		slot_flags[i].is_sequence = float(result.is_sequence)
		var sprite: Dictionary = result.sprite
		var size: Vector2 = sprite.texture.get_size()
		var rect: Rect2 = sprite.rect
		slots[i] = {"enabled":true,"texture":sprite.texture,"rect":Rect2(rect.position/size,rect.size/size),
			"anchor_frame_uv":result.anchor_frame_uv,"hand_local_uv":result.hand_local_uv,"rot_cos_sin":result.rot_cos_sin,
			"flip_x":result.flip_x,"depth_mode":float(result.slot_is_front),"hand_in_front":float(result.hand_in_front)}
	var outcome := SubsetMaterial.apply_weapon_fill(_material,normalized,slots)
	if outcome.ok and _frame_effects != null:
		outcome = _frame_effects.apply(_material,action,atlas,normalized,slot_flags)
	binding_error = "" if outcome.ok else outcome.reason

func icon(option: int) -> ImageTexture:
	var item := options[option]
	var sprite: Dictionary = item.sequence.Attack[0][0].sprite if item.sequence.has("Attack") else item.sprites.se
	var im: Image = sprite.texture.get_image()
	var rect: Rect2 = sprite.rect
	return SlotIcon.from_sprite(im.get_region(Rect2i(int(rect.position.x),im.get_height()-int(rect.end.y),int(rect.size.x),int(rect.size.y))))

func details(slot: int) -> String:
	if worn[slot] < 0: return TYPES[slot] + "\n当前为空"
	var item := options[worn[slot]]
	var lines: Array[String] = [item.name,TYPES[slot]]
	for row in item.stats:
		lines.append("%s %+d" % [STATS[int(row.stat)],int(row.value)])
	return "\n".join(lines)
