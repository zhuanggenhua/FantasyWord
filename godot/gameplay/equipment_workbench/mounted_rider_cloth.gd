extends RefCounted
## 独立骑手材质：只接受已核实的战马骑手 UV 和基础布衣。
## 马身保持作者原 Sprite，站立材质不借给骑手使用。
const Subset = preload("res://gameplay/presentation/equipment_subset_material.gd")
const Shadow = preload("res://gameplay/presentation/equipment_shadow_coverage.gd")
const Cursor = preload("res://game_core/presentation/equipment_frame_cursor.gd")
const CONTRACT_SHA := "0d15b75ea00bc98e81a9056606f95ab1ab693391ea8f820eba32f5e45556b1b9"
const FRAME_SHA := "a7d86f4322b7e4eb9d189d5aadc791e70824d81101a40fde220d312faf15666b"
const EMPTY_SLOT := {"is_sequence": 0.0, "hide_outline_on_body": 0.0}
var _frame_effects := {}
var _material: ShaderMaterial
var _actions := {}
var _cursor := Cursor.new()
var _appearance: Callable

func configure(path: String, first_sprite: AtlasTexture, cloth: Texture2D, appearance: Callable) -> bool:
	var file := path.path_join("mounted-cloth-source.json")
	if _material != null or FileAccess.get_sha256(file) != CONTRACT_SHA or not appearance.is_valid():
		return false
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	for key: String in contract.actions:
		var record: Dictionary = contract.actions[key]
		var maps := {"frame_size": Vector2i(32,32), "frames": record.frames}
		for channel in ["body", "head"]:
			var spec: Dictionary = record[channel]
			var image := Image.new()
			var location := path.path_join(spec.file)
			if FileAccess.get_sha256(location) != spec.sha256 or image.load(location) != OK \
					or image.get_size() != Vector2i(spec.size[0], spec.size[1]):
				return false
			maps[channel] = ImageTexture.create_from_image(image)
		_actions[key] = maps
	var frame_file := path.path_join("outline-shadow-frames.json")
	if FileAccess.file_exists(frame_file):
		if FileAccess.get_sha256(frame_file) != FRAME_SHA:
			return false
		var effect_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(frame_file))
		# Preserve the original top-origin authored foot marks; use the same
		# height rules as EquipmentRenderer, not a shadow sampled from the horse.
		for action: String in effect_data.frames:
			var frames := {}
			for record: Dictionary in effect_data.frames[action]:
				var key := Vector2i(int(record.frame_index), int(record.row_index))
				frames[key] = Shadow.height_writes(record.left_foot, record.right_foot,
					int(effect_data.ground_pixel_y))
			_frame_effects[action] = frames
	var standing: Dictionary = _actions.Stand
	var setup := Subset.create(first_sprite.atlas, standing.body, standing.head, false,
		{"cloth": true}, {"cloth": {"texture": cloth, "rect": Rect2(0, 0, 1, 1)}}, {}, not _frame_effects.is_empty())
	if not setup.ok:
		return false
	_material = setup.material
	_appearance = appearance
	return true

func apply_sample(action: String, sample: AtlasTexture) -> ShaderMaterial:
	var maps: Dictionary = _actions[action]
	_cursor.configure_animation(maps)
	_cursor.sync_current_sprite(sample)
	var frame: Variant = _cursor.refresh_frame()
	if frame == null or maps.body.get_size() != sample.atlas.get_size() or maps.head.get_size() != sample.atlas.get_size():
		push_error("战马骑手的实际原帧与骑乘 UV 合同不匹配。")
		return null
	_material.set_shader_parameter("main_map", sample.atlas)
	Subset.apply_nullable_action_uv_maps(_material, maps.body, maps.head)
	_appearance.call(_material, _cursor.row_index, frame)
	if not _frame_effects.is_empty() and not _apply_outline_shadow(action, sample):
		push_error("战马骑手当前帧无法应用原轮廓与地面阴影。")
		return null
	return _material

func _apply_outline_shadow(action: String, sample: AtlasTexture) -> bool:
	var size := sample.atlas.get_size()
	var rect := Rect2(sample.region.position.x / size.x,
		(size.y - sample.region.end.y) / size.y,
		sample.region.size.x / size.x, sample.region.size.y / size.y)
	var cell := Vector2i(sample.region.position / sample.region.size)
	var params: Dictionary = _frame_effects[action].get(cell, {})
	if params.is_empty() or not Subset.apply_weapon_fill(_material, rect, [{}, {}]).ok:
		return false
	# The preview defaults enable normal outline and shadow. The locked
	# 64 frames have no hit flag; neither equipment slot has a weapon.
	if not Subset.apply_outline(_material, rect, params.frame_size, params.base_y,
			[EMPTY_SLOT, EMPTY_SLOT], Vector3(1.0, 0.0, 0.0),
			Color(0.7059, 0.0353, 0.0353, 1.0), Color.WHITE).ok:
		return false
	return Subset.apply_shadow(_material, rect, params, 1.0, Color(0.0, 0.0, 0.0, 0.6)).ok
