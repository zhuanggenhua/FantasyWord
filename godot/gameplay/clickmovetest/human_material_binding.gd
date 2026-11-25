extends RefCounted
## 原 Human 的已核实动作共用基础外观材质；装备栏保持原空配置。
const BaseAppearance = preload("res://gameplay/presentation/equipment_base_appearance.gd")
const SubsetMaterial = preload("res://gameplay/presentation/equipment_subset_material.gd")
const FrameCursor = preload("res://game_core/presentation/equipment_frame_cursor.gd")
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
const DIRECTIONS := ["SE","SW","NE","NW"]
const LAYERS := ["hair","beard","eye_decoration"]
var material: ShaderMaterial
var last_error := ""
var _appearance := {}
var _workbench_headwear: Dictionary = {}
var _workbench_headwear_enabled := false
var _actions := {}
var _cursor := FrameCursor.new()
var _sprite: Sprite2D
var _playback: Node
var _driver: Node

func configure(sprite: Sprite2D, playback: Node, driver: Node, animation: Dictionary,
		data: Dictionary, uv_directory: String, appearance_directory: String, workbench_weapon_stage := false) -> bool:
	if material != null or sprite.material != null or not sprite.texture is AtlasTexture:
		return _fail("Expected an unbound, sampled Human AtlasTexture.")
	if data.get("schema") != 1 or data.get("source_commit") != SOURCE:
		return _fail("Missing locked Human material contract.")
	for field in ["textures","actions","appearance"]:
		if not data.get(field) is Dictionary: return _fail("Incomplete Human material contract.")
	if data.actions.size() != animation.actions.size() or not data.actions.has_all(animation.actions.keys()):
		return _fail("材质必须完整覆盖同一展示入口的全部已核实动作。")
	if animation.actions.has("SpinDie") and (data.get("training_target")!=animation.get("training_target") \
			or data.get("primary_death")!=animation.get("primary_death") \
			or data.get("workbench_spin")!=animation.get("workbench_spin")):
		return _fail("SpinDie 材质必须来自同一实际场景角色与方向库。")
	var actions := {}
	var look := {}
	var cache := {}
	for action in animation.actions:
		var spec = data.actions[action]
		if not spec is Dictionary or not spec.get("frames") is Array:
			return _fail("Incomplete Human action/material frames.")
		var source: Dictionary = animation.actions[action]
		var main_spec: Dictionary = animation.textures[source.directions[0][0].texture]
		if spec.get("main_sha256") != main_spec.sha256:
			return _fail("SubsetMaterial contract references a different main atlas.")
		var maps := {"frames": spec.frames.duplicate(true), "frame_size": Vector2i(32,32)}
		for key in ["body","head"]:
			var texture := _load_map(data.textures,spec.get(key),uv_directory,cache)
			if texture == null or texture.get_size() != Vector2(main_spec.size[0],main_spec.size[1]):
				return _fail("UV atlas does not match the verified action atlas.")
			maps[key] = texture
		var coords := {}
		for frame in maps.frames:
			if not frame is Dictionary or not _integer(frame.get("frame_index")) or not _integer(frame.get("row_index")):
				return _fail("Invalid authored frame coordinates.")
			for eye in ["left_eye_closed","right_eye_closed"]:
				if not frame.get(eye) is bool: return _fail("Invalid authored eyelid flag.")
			if not frame.get("body_regions") is Dictionary:
				return _fail("Invalid authored body regions.")
			for part in frame.body_regions:
				var region = frame.body_regions[part]
				if part not in ["head","torso"] or not region is Dictionary or not _integer(region.get("sprite_facing")) or int(region.sprite_facing) not in [0,1,2,3]:
					return _fail("Invalid authored part facing.")
			var coordinate := Vector2i(frame.frame_index,frame.row_index)
			if coords.has(coordinate): return _fail("Duplicate authored frame.")
			coords[coordinate] = true
		var expected := {}
		for direction in source.directions:
			for frame in direction:
				var r: Array = frame.rect
				var coordinate := Vector2i(floori(float(r[0])/32.0),floori((float(main_spec.size[1])-r[1]-r[3])/32.0))
				expected[coordinate] = true
		if coords != expected:
			return _fail("Authored frame coordinates do not cover the sampled library.")
		actions[action] = maps
	for part in ["hair","beard"]:
		look[part] = {}
		for direction in DIRECTIONS:
			var texture := _load_map(data.textures,data.appearance.get(part+direction),appearance_directory,cache)
			if texture == null: return _fail("Missing authored directional appearance texture.")
			look[part][direction.to_lower()] = {"texture":texture,"rect":Rect2(0,0,1,1)}
	for side in ["East","West"]:
		var texture := _load_map(data.textures,data.appearance.get("eyeDecoration"+side),appearance_directory,cache)
		if texture == null: return _fail("Missing authored eye decoration.")
		look["eye_decoration_"+side.to_lower()] = {"texture":texture,"rect":Rect2(0,0,1,1)}
	for side in ["left","right"]:
		var color = data.appearance.get(side+"EyeColor")
		if not color is Array or color.size() != 4: return _fail("Missing authored eye color.")
		for c in color:
			if typeof(c) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(c) or c < 0.0 or c > 1.0:
				return _fail("Invalid authored eye color.")
		look[side+"_eye_color"] = Color(color[0],color[1],color[2],color[3])
	var action: String = driver.current_animation_key
	if not actions.has(action) or action != playback.current_action:
		return _fail("Human action owner and initial sprite are not synchronized.")
	var atlas: Texture2D = sprite.texture.atlas
	var setup: Dictionary = SubsetMaterial.create(atlas,actions[action].body,actions[action].head,false,{},{},{},workbench_weapon_stage)
	if not setup.ok: return _fail(str(setup.reason))
	_actions = actions
	_appearance = look
	material = setup.material
	_sprite = sprite
	_playback = playback
	_driver = driver
	_cursor.refresh_requested.connect(_refresh)
	_apply_action(action)
	_sample(action,playback.current_label,playback.current_direction,sprite.texture)
	sprite.material = material
	_playback.sample_resolved.connect(_sample)
	_driver.animation_selected.connect(_apply_action)
	return true

# The source changes action maps before the next Sprite identity refresh.
func _apply_action(action: String) -> void:
	var maps: Dictionary = _actions.get(action,{})
	_cursor.configure_animation(maps)
	SubsetMaterial.apply_nullable_action_uv_maps(material,maps.get("body"),maps.get("head"))

func _sample(_action: String, _label: int, _direction: int, texture: Texture2D) -> void:
	if texture == _cursor.last_sprite or not texture is AtlasTexture: return
	# AtlasTexture's CanvasItem region is already in full-atlas UV; no second region transform.
	material.set_shader_parameter("main_map",texture.atlas)
	_cursor.late_sync(texture)

## Optional Workbench owner. The formal scene does not register preview headgear.
func set_workbench_headwear(entry: Dictionary) -> void:
	_workbench_headwear_enabled = true
	_workbench_headwear = entry
	_refresh()

func _refresh() -> void:
	var frame = _cursor.refresh_frame()
	for layer in LAYERS: material.set_shader_parameter("enabled_"+layer,false)
	if _workbench_headwear_enabled:
		for layer in ["helmet", "mask"]:
			material.set_shader_parameter("enabled_" + layer, false)
			material.set_shader_parameter(layer + "_map", null)
			material.set_shader_parameter(layer + "_rect", Vector4(0, 0, 1, 1))
	material.set_shader_parameter("enabled_left_eye",false)
	material.set_shader_parameter("enabled_right_eye",false)
	if frame == null:
		SubsetMaterial.apply_nullable_action_uv_maps(material,null,null)
		return
	var maps: Dictionary = _cursor.current_animation
	SubsetMaterial.apply_nullable_action_uv_maps(material,maps.body,maps.head)
	var flags := BaseAppearance.resolve(_cursor.row_index,frame,_appearance,_workbench_headwear)
	material.set_shader_parameter("body_in_front",flags.body_in_front)
	if not _workbench_headwear.is_empty():
		var facing: int = flags.head_facing
		if facing < 0 or facing > 3: facing = 0
		var channel: String = _workbench_headwear.channel
		var slice: Dictionary = _workbench_headwear.directions[facing]
		material.set_shader_parameter(channel + "_map", slice.map)
		material.set_shader_parameter(channel + "_rect", slice.rect)
		material.set_shader_parameter("enabled_" + channel, true)
	BaseAppearance.apply_material_layers(material, flags)

## 骑乘使用同一基础人形外观，但绝不读站立精灵、动画或其当前衣甲。
func apply_mounted_base_appearance(target: ShaderMaterial, row: int, frame: Dictionary) -> void:
	var flags := BaseAppearance.resolve(row, frame, _appearance)
	target.set_shader_parameter("body_in_front", flags.body_in_front)
	BaseAppearance.apply_material_layers(target, flags)

func disconnect_from_view() -> void:
	if is_instance_valid(_playback) and _playback.sample_resolved.is_connected(_sample):
		_playback.sample_resolved.disconnect(_sample)
	if is_instance_valid(_driver) and _driver.animation_selected.is_connected(_apply_action):
		_driver.animation_selected.disconnect(_apply_action)
	if _cursor.refresh_requested.is_connected(_refresh):
		_cursor.refresh_requested.disconnect(_refresh)
	if is_instance_valid(_sprite) and _sprite.material == material: _sprite.material = null

func _load_map(specs: Dictionary, name: Variant, directory: String, cache: Dictionary) -> Texture2D:
	if not name is String or name != name.get_file() or not name.ends_with(".png") or not specs.get(name) is Dictionary:
		return null
	var path := directory.path_join(name)
	if cache.has(path): return cache[path]
	var spec: Dictionary = specs[name]
	if not spec.get("sha256") is String or spec.sha256.length() != 64 or FileAccess.get_sha256(path) != spec.sha256:
		return null
	if not spec.get("size") is Array or spec.size.size() != 2: return null
	var image := Image.new()
	if image.load(path) != OK or image.get_width() != spec.size[0] or image.get_height() != spec.size[1]:
		return null
	var texture := ImageTexture.create_from_image(image)
	cache[path] = texture
	return texture

func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_FLOAT,TYPE_INT] and is_finite(value) and value == floorf(value)

func _fail(error: String) -> bool:
	last_error = error
	return false
