extends Node2D
## 原 MountedCharacterPresentation 无装备直显切片。调用方持有正式 Mount 槽，
## 此节点只消费动作/朝向和资产，不修改站立渲染器的贴图或材质。
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
const CONTRACT_SHA := "f2d63ee8da382560e2509c13cf9731a51322603ce0409a374060509703904ff5"

var mount_sprite: Sprite2D
var rider_sprite: Sprite2D
var elapsed := 0.0
var frame_index := -1
var facing := -1
var action := ""
var used_fallback := false
var mount_frame_name := ""
var rider_frame_name := ""
var _actions := {}
var _driver: Node
var _playback: Node

func configure(path: String, driver: Node, playback: Node) -> bool:
	var manifest := path.path_join("plain-horse-source.json")
	if mount_sprite != null or FileAccess.get_sha256(manifest) != CONTRACT_SHA:
		return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	if data.source != SOURCE or data.mount_id != "war_horse_human" or data.fallback != "Stand":
		return false
	var textures := {}
	for guid: String in data.atlases:
		var atlas: Dictionary = data.atlases[guid]
		var file := path.path_join(atlas.file)
		var image := Image.new()
		if FileAccess.get_sha256(file) != atlas.sha256 or image.load(file) != OK \
				or image.get_size() != Vector2i(atlas.size[0], atlas.size[1]) or atlas.pixels_per_unit != 8:
			return false
		textures[guid] = ImageTexture.create_from_image(image)
	for key: String in data.actions:
		var spec: Dictionary = data.actions[key]
		var directions := []
		for row: Array in spec.directions:
			var frames := []
			for pair: Dictionary in row:
				frames.append([_layer(pair.mount, textures), _layer(pair.rider, textures)])
			directions.append(frames)
		_actions[key] = {"cycle": float(spec.cycle), "directions": directions}
	_driver = driver
	_playback = playback
	mount_sprite = _make_layer("MountBody", -1)
	rider_sprite = _make_layer("MountedRider", 0)
	set_active(false)
	return true

func _layer(record: Dictionary, textures: Dictionary) -> Dictionary:
	var texture := AtlasTexture.new()
	texture.atlas = textures[record.atlas]
	var rect: Array = record.rect
	# 提取合同已将 Unity 左下坐标转换成 Godot 左上坐标。
	texture.region = Rect2(rect[0], rect[1], rect[2], rect[3])
	texture.filter_clip = true
	return {"name": record.name, "texture": texture}

func _make_layer(node_name: String, order: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.z_index = order
	sprite.scale = Vector2.ONE / 8.0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	return sprite

func set_active(enabled: bool) -> void:
	visible = enabled
	set_process(enabled)
	frame_index = -1
	action = ""
	facing = -1
	elapsed = 0.0
	mount_frame_name = ""
	rider_frame_name = ""
	used_fallback = false
	if enabled: _process(0.0)
	else:
		mount_sprite.texture = null
		rider_sprite.texture = null

func _process(delta: float) -> void:
	tick(str(_driver.current_animation_key), int(_playback.current_direction), delta)

func tick(request: String, direction: int, delta: float) -> void:
	if not visible or direction < 0 or direction >= 4:
		return
	# 原素材只支持 Stand/Move；其余原语义均回到该资产声明的 Stand。
	var resolved := "Move" if request == "Walk" else "Stand"
	used_fallback = request not in ["Idle", "Walk", ""]
	if action != resolved or facing != direction:
		action = resolved
		facing = direction
		elapsed = 0.0
		frame_index = -1
	else:
		elapsed += maxf(0.0, delta)
	var spec: Dictionary = _actions[action]
	var frames: Array = spec.directions[direction]
	var index := mini(floori(fposmod(elapsed, spec.cycle) / spec.cycle * frames.size()), frames.size() - 1)
	if frame_index == index:
		return
	frame_index = index
	var pair: Array = frames[index]
	mount_sprite.texture = pair[0].texture
	mount_frame_name = pair[0].name
	rider_sprite.texture = pair[1].texture
	rider_frame_name = pair[1].name
