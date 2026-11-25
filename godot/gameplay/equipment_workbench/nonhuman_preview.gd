extends Node2D
## EquipmentSystemDemo only: race-specific frame/UV ownership, original shared look only where catalog refers to it.
const FrameCursor := preload("res://game_core/presentation/equipment_frame_cursor.gd")
const BaseAppearance := preload("res://gameplay/presentation/equipment_base_appearance.gd")
const Playback := preload("res://game_core/presentation/directional_sprite_playback.gd")
const MaterialBinding := preload("res://gameplay/presentation/equipment_subset_material.gd")
const MANIFEST := "private-nonhuman-action-audit.json"
const MANIFEST_SHA := "9fd5661053d3e32a51baf2bf440474e8efb45cd7d39a08b18c861940c61858c3"
const TERMINALS := {"Orc":"Die", "Goblin":"SpinDie"}
const HUMANOID_MANIFEST_SHA := "9c92d86d0ae0fcd27ec6b550bcb9ef8860f570efe6fd407bec2df87eb7e932fe"
const HUMANOID_APPEARANCE_SHA := "4fc01e9e5cde4c06752ac94d9db3025d5830d768a5d28f9283a73e5736a2a268"
const HUMANOIDS := ["Dwarf","Elf"]
var playback: Node
var animator: AnimationPlayer
var sprite: Sprite2D
var composite: ShaderMaterial
var _maps := {}
var _cursor: FrameCursor
var _appearance := {}
var _sample_action := ""

static func read_locked(dir: String) -> Dictionary:
	return _read_pinned(dir.path_join(MANIFEST),MANIFEST_SHA)

static func read_locked_humanoids(dir: String) -> Dictionary:
	return _read_pinned(dir.path_join("dwarf-elf-audit.json"),HUMANOID_MANIFEST_SHA)

static func _read_pinned(path: String, sha: String) -> Dictionary:
	if FileAccess.get_sha256(path) != sha: return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func configure(dir: String, data: Dictionary, race: String, cloth: Texture2D) -> bool:
	if not is_inside_tree() or sprite != null or cloth == null: return false
	var humanoid := race in HUMANOIDS
	if not humanoid and not TERMINALS.has(race): return false
	if humanoid and not _load_humanoid_appearance(dir,data.appearance): return false
	var record: Dictionary = data.characters[race]
	var actions := {}
	for key in record.actions:
		var spec: Dictionary = record.actions[key]
		var atlas := _texture(dir.path_join(race),spec.body)
		var body := _texture(dir.path_join(race),spec.uv.body)
		var head := _texture(dir.path_join(race),spec.uv.head)
		if atlas == null or body == null or head == null: return false
		_maps[key] = {"atlas":atlas,"body":body,"head":head,"repeat":spec.uv.body.wrap==0}
		if humanoid:
			_maps[key].frames = _source_frames(spec.frames)
			_maps[key].frame_size = Vector2i(32,32)
		var directions := []
		var sprites := {}
		for entries in spec.directions:
			var frames := []
			for entry in entries:
				var file_id: String = entry.file_id
				# Some directions share individual Sprite assets even on nonterminal
				# clips. Deduplicate by source identity, never by direction number.
				if not sprites.has(file_id):
					var r: Array = entry.rect
					var frame := AtlasTexture.new()
					frame.atlas = atlas
					frame.region = Rect2(r[0],atlas.get_height()-r[1]-r[3],r[2],r[3])
					frame.filter_clip = true
					sprites[file_id] = frame
				frames.append(sprites[file_id])
			directions.append(frames)
		var labels: Array[int] = []
		for entry in spec.labels: labels.append(int(entry))
		actions[key] = {"times":spec.times,"labels":labels,"duration":spec.duration,"loop":spec.loop,"directions":directions}

	var appearance: Dictionary = data.base_appearance
	var idle: Dictionary = _maps.Idle
	var binding := MaterialBinding.create(idle.atlas,idle.body,idle.head,true,
		{"cloth":true},
		{"cloth":{"texture":cloth,"rect":Rect2(0,0,1,1)}},
		{"left_eye":_color(appearance.leftEyeColor),"right_eye":_color(appearance.rightEyeColor)})
	if not binding.ok: return false
	composite = binding.material
	# Same non-HDR Compatibility color domain as the original Human workbench.
	if not MaterialBinding.apply_skin_palette(composite,_colors(appearance.skinSrcColors),
			_colors(appearance.skinDstColors),MaterialBinding.SKIN_DOMAIN_RAW_SRGB).ok: return false
	sprite = Sprite2D.new()
	sprite.material = composite
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE/8.0
	animator = AnimationPlayer.new()
	playback = Playback.new()
	add_child(sprite); add_child(animator); add_child(playback)
	if not playback.configure(sprite,animator,actions): return false
	if humanoid: _cursor = FrameCursor.new()
	playback.sample_resolved.connect(_bind_sample)
	reset()
	return true

func reset() -> void:
	playback.set_direction(0)
	set_cloth(true)
	play("Idle")

func has_action(key: String) -> bool:
	return _maps.has(key)

func play(key: String) -> bool:
	if not _maps.has(key): return false
	animator.play(key)
	animator.advance(0.0)
	# Source explicitly plays even the same Animator state from normalized time zero.
	animator.seek(0.0,true)
	return true

func set_cloth(worn: bool) -> void:
	composite.set_shader_parameter("enabled_cloth",worn)

func _bind_sample(key: String, _label: int, _direction: int, texture: Texture2D) -> void:
	var maps: Dictionary = _maps[key]
	if _sample_action != key:
		composite.set_shader_parameter("main_map",maps.atlas)
		MaterialBinding.apply_nullable_action_uv_maps(composite,maps.body,maps.head,maps.repeat)
		_sample_action = key
		if _cursor != null: _cursor.configure_animation(maps)
	if _cursor == null or _cursor.last_sprite == texture: return
	_cursor.late_sync(texture)
	var frame = _cursor.refresh_frame()
	if not frame is Dictionary: return
	var flags := BaseAppearance.resolve(_cursor.row_index,frame,_appearance)
	composite.set_shader_parameter("body_in_front",flags.body_in_front)
	BaseAppearance.apply_material_layers(composite,flags)

func _load_humanoid_appearance(dir: String, colors: Dictionary) -> bool:
	var refs := _read_pinned(dir.path_join("appearance-reference.json"),HUMANOID_APPEARANCE_SHA)
	if refs.is_empty(): return false
	for part in ["hair","beard"]:
		_appearance[part] = {}
		for side in ["SE","SW","NE","NW"]:
			var tech := _texture(dir.path_join("appearance"),refs[part+side])
			if tech == null: return false
			_appearance[part][side.to_lower()] = {"texture":tech}
	for side in ["East","West"]:
		var tech := _texture(dir.path_join("appearance"),refs["eyeDecoration"+side])
		if tech == null: return false
		_appearance["eye_decoration_"+side.to_lower()] = {"texture":tech}
	for side in ["left","right"]:
		_appearance[side+"_eye_color"] = _color(colors[side+"EyeColor"])
	return true

static func _source_frames(records: Array) -> Array:
	var frames := []
	for frame in records:
		var regions := {}
		for region in frame.bodyRegions:
			var part: String = {0:"head",1:"torso"}.get(int(region.part),"")
			if not part.is_empty() and not regions.has(part):
				regions[part] = {"sprite_facing":int(region.spriteFacing)}
		frames.append({"frame_index":int(frame.frameIndex),"row_index":int(frame.rowIndex),
			"body_regions":regions,"left_eye_closed":bool(frame.leftEyeClosed),"right_eye_closed":bool(frame.rightEyeClosed)})
	return frames

static func _color(entry: Dictionary) -> Color:
	return Color(entry.r,entry.g,entry.b,entry.a)

static func _colors(entries: Array) -> Array[Color]:
	var result: Array[Color] = []
	for entry in entries: result.append(_color(entry))
	return result

static func _texture(dir: String, spec: Dictionary) -> ImageTexture:
	var path := dir.path_join(spec.file)
	if FileAccess.get_sha256(path) != spec.sha256: return null
	var image := Image.load_from_file(path)
	if image == null or (spec.has("size") and image.get_size() != Vector2i(spec.size[0],spec.size[1])): return null
	return ImageTexture.create_from_image(image)
