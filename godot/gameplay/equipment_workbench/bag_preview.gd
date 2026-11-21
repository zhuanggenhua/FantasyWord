extends RefCounted
## Independent preview slot, bound to the same authored torso sample as cloth/cloak.
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
const VISUAL := "3d5f5f390d826f94e83fe535b39178c5"
const TEXTURES := {
	"b24192a048865fa4ea58bea8694713dd": ["YellowBackpacks_facingfront.png", "19e37f8bc9fe654c25d5ff8011650cf7cecc179bf4c859b84a06356dfb0b2b3d"],
	"e0b192e8bc8bc5443b28fd64964e95dc": ["YellowBackpacks_facingback.png", "a3f6a224398d1890cea7051079a3a93eb4998c5f085cce9bd4f1e938fb464c9a"]
}
# Locks the four authored sprite slices, including the negative Unity Sprite IDs.
const SLICES := [
	["b24192a048865fa4ea58bea8694713dd", "-7371305434098653786", 96],
	["b24192a048865fa4ea58bea8694713dd", "-3256268399560461775", 64],
	["e0b192e8bc8bc5443b28fd64964e95dc", "6035224804152983905", 32],
	["e0b192e8bc8bc5443b28fd64964e95dc", "8545490660887638272", 0]
]

var worn := false
var display_name := ""
var description := ""
var _material: ShaderMaterial
var _playback: Node
var _torso: Callable
var _maps: Array[Texture2D] = []
var _rectangles: Array[Vector4] = []
var _icon: ImageTexture

func load_source(directory: String) -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("bag.json")))
	if not data is Dictionary or data.get("source_commit") != SOURCE or data.get("visual_guid") != VISUAL:
		return false
	if data.get("name") != "小背包" or data.get("description") != "用于验证背包表现层与额外插槽。" or data.get("stats") != [{"stat": 1.0, "value": 2.0}, {"stat": 4.0, "value": 3.0}]:
		return false
	var sheets: Variant = data.get("textures")
	var directions: Variant = data.get("directions")
	if not sheets is Dictionary or sheets.size() != TEXTURES.size() or not directions is Array or directions.size() != SLICES.size():
		return false
	var textures := {}
	for guid in TEXTURES:
		var entry: Variant = sheets.get(guid)
		var fixed: Array = TEXTURES[guid]
		if not entry is Dictionary or entry.get("file") != fixed[0] or entry.get("sha256") != fixed[1] or entry.get("size") != [160.0, 128.0]:
			return false
		var path := directory.path_join(fixed[0])
		var image := Image.new()
		if FileAccess.get_sha256(path) != fixed[1] or image.load(path) != OK or image.get_size() != Vector2i(160, 128):
			return false
		textures[guid] = ImageTexture.create_from_image(image)
	for index in SLICES.size():
		var row: Variant = directions[index]
		var expected: Array = SLICES[index]
		if not row is Dictionary or row.get("texture") != expected[0] or row.get("file_id") != expected[1] or row.get("rect") != [0.0, float(expected[2]), 32.0, 32.0]:
			return false
		_maps.append(textures[expected[0]])
		var bottom := float(expected[2])
		_rectangles.append(Vector4(0, bottom / 128.0, 0.2, (bottom + 32.0) / 128.0))
	display_name = data.name
	description = data.description
	_icon = _make_icon(_maps[0].get_image().get_region(Rect2i(0, 0, 32, 32)))
	return true

func bind(material: ShaderMaterial, playback: Node, torso: Callable) -> void:
	_material = material
	_playback = playback
	_torso = torso
	_playback.sample_resolved.connect(_on_sample)
	select(false)

func select(value: bool) -> void:
	worn = value
	_on_sample(_playback.current_action, _playback.current_label, _playback.current_direction, null)

func _on_sample(action: String, label: int, direction: int, _sprite: Texture2D) -> void:
	var row: Variant = _torso.call(action, label, direction)
	var visible_on_frame := worn and row is Vector2i
	if visible_on_frame:
		_material.set_shader_parameter("bag_map", _maps[row.x])
		_material.set_shader_parameter("bag_rect", _rectangles[row.x])
	_material.set_shader_parameter("enabled_bag", visible_on_frame)

func icon() -> ImageTexture:
	return _icon

func details() -> String:
	return "%s\n背包\n%s\n生命 +2 | 魔力 +3" % [display_name, description] if worn else "背包\n当前为空"

static func _make_icon(sprite: Image) -> ImageTexture:
	# Unity GetSequenceFramePreviewSprite: crop visible pixels, fit edge 30 into 32.
	var lo := Vector2i(32, 32)
	var hi := Vector2i(-1, -1)
	for y in 32:
		for x in 32:
			if sprite.get_pixel(x, y).a > 0.01:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var canvas := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	if hi.x >= lo.x:
		var size := hi - lo + Vector2i.ONE
		var factor := 30.0 / float(maxi(size.x, size.y))
		var target := Vector2i(maxi(1, roundi(size.x * factor)), maxi(1, roundi(size.y * factor)))
		var offset := Vector2i((32 - target.x) >> 1, (32 - target.y) >> 1)
		# Source floors in the bottom-origin frame and only writes alpha above 0.01.
		for y in target.y:
			for x in target.x:
				var sx := lo.x + mini(floori(x / factor), size.x - 1)
				var sy := hi.y - mini(floori(y / factor), size.y - 1)
				var color := sprite.get_pixel(sx, sy)
				if color.a > 0.01:
					canvas.set_pixel(offset.x + x, 31 - offset.y - y, color)
	return ImageTexture.create_from_image(canvas)
