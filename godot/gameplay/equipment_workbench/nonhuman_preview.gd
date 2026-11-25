extends Node2D
## EquipmentSystemDemo only. Do not reuse the Human frame/gear data for either actor.
const Playback := preload("res://game_core/presentation/directional_sprite_playback.gd")
const MaterialBinding := preload("res://gameplay/presentation/equipment_subset_material.gd")
const MANIFEST := "private-nonhuman-action-audit.json"
const MANIFEST_SHA := "9fd5661053d3e32a51baf2bf440474e8efb45cd7d39a08b18c861940c61858c3"
const TERMINALS := {"Orc":"Die", "Goblin":"SpinDie"}
var playback: Node
var animator: AnimationPlayer
var sprite: Sprite2D
var composite: ShaderMaterial
var _maps := {}

static func read_locked(dir: String) -> Dictionary:
	var path := dir.path_join(MANIFEST)
	if FileAccess.get_sha256(path) != MANIFEST_SHA: return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func configure(dir: String, data: Dictionary, race: String, cloth: Texture2D) -> bool:
	if not is_inside_tree() or sprite != null or not TERMINALS.has(race) or cloth == null: return false
	var record: Dictionary = data.characters[race]
	var actions := {}
	for key in record.actions:
		var spec: Dictionary = record.actions[key]
		var atlas := _texture(dir.path_join(race),spec.body)
		var body := _texture(dir.path_join(race),spec.uv.body)
		var head := _texture(dir.path_join(race),spec.uv.head)
		if atlas == null or body == null or head == null: return false
		_maps[key] = [atlas,body,head]
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
	var idle: Array = _maps.Idle
	var binding := MaterialBinding.create(idle[0],idle[1],idle[2],true,
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

func _bind_sample(key: String, _label: int, _direction: int, _texture: Texture2D) -> void:
	var maps: Array = _maps[key]
	composite.set_shader_parameter("main_map",maps[0])
	MaterialBinding.apply_nullable_action_uv_maps(composite,maps[1],maps[2],true)

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
	if image == null or image.get_size() != Vector2i(spec.size[0],spec.size[1]): return null
	return ImageTexture.create_from_image(image)
