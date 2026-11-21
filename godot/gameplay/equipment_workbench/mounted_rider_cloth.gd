extends RefCounted
## 独立骑手材质：只接受已核实的战马骑手 UV 和基础布衣。
## 马身保持作者原 Sprite，站立材质不借给骑手使用。
const Subset = preload("res://gameplay/presentation/equipment_subset_material.gd")
const Cursor = preload("res://game_core/presentation/equipment_frame_cursor.gd")
const CONTRACT_SHA := "0d15b75ea00bc98e81a9056606f95ab1ab693391ea8f820eba32f5e45556b1b9"
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
	var standing: Dictionary = _actions.Stand
	var setup := Subset.create(first_sprite.atlas, standing.body, standing.head, false,
		{"cloth": true}, {"cloth": {"texture": cloth, "rect": Rect2(0, 0, 1, 1)}}, {})
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
	return _material
