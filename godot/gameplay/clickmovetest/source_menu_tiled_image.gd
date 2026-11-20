extends Control
## UIGameMenu 的两个有边框 Image.Type.Tiled。调用方提供原 Canvas 单位下的矩形。
## 这里不使用 NinePatchRect 的默认拉伸，也不负责菜单层级、布局或点击。
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
const ATLAS_HASH := "2db1269537f02431a2f433ecca936d72840962f8b8b765e44405839c1dcdc612"
const IDS := {"Menu Items": "366804271", "Frame": "548018584", "Settings Background": "-1443275623", "Character Background": "-1443275623", "Inventory Background": "-1443275623", "Journal Background": "-1443275623"}

var _texture: ImageTexture
var _region: Rect2
var _border: Vector4 # L, bottom, R, top (Unity)
var _units_per_texel: float
var _max_width := 1920.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func bind(data: Dictionary, path: String, source_name: String) -> bool:
	if _texture != null or not IDS.has(source_name) or data.get("source_commit") != SOURCE \
			or data.get("schema") != 1 or data.get("atlas_sha256") != ATLAS_HASH \
			or data.get("canvas_reference_ppu") != 96 or data.get("sprite_ppu") != 16 \
			or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != ATLAS_HASH:
		return false
	var images: Variant = data.get("tiled_images")
	var sprites: Variant = data.get("sprites")
	if not images is Dictionary or not sprites is Dictionary: return false
	var spec: Variant = images.get(source_name)
	var key: String = IDS[source_name]
	if not spec is Dictionary or spec.get("sprite_id") != key \
			or spec.get("fill_center") != true or spec.get("ppu_multiplier") != 1:
		return false
	var tint: Variant = spec.get("color")
	if not tint is Dictionary or tint.get("r") != 1 or tint.get("g") != 1 or tint.get("b") != 1 or tint.get("a") != 1:
		return false
	var sprite: Variant = sprites.get(key)
	if not sprite is Dictionary: return false
	var rect := _field_vector(sprite.get("rect"), ["x","y","width","height"])
	var border := _field_vector(sprite.get("border"), ["x","y","z","w"])
	var expected := Vector4(0,80,8,8) if source_name == "Menu Items" else Vector4(2,58,20,20)
	var inset := 1.0 if source_name == "Menu Items" else 6.0
	if source_name in ["Settings Background","Character Background","Inventory Background","Journal Background"]:
		expected = Vector4(96,88,24,24)
		inset = 3.0
	if rect != expected or border != Vector4(inset,inset,inset,inset): return false
	var image := Image.load_from_file(path)
	if image == null or image.is_empty(): return false
	var region := Rect2(rect.x, image.get_height()-rect.y-rect.w, rect.z, rect.w)
	if not Rect2(Vector2.ZERO, image.get_size()).encloses(region): return false
	_texture = ImageTexture.create_from_image(image)
	if _texture == null: return false
	_region = region
	_border = border
	_units_per_texel = float(data.canvas_reference_ppu) / float(data.sprite_ppu) / float(spec.ppu_multiplier)
	if source_name in ["Character Background","Inventory Background","Journal Background"]: _max_width=4096.0
	queue_redraw()
	return true

static func _field_vector(data: Variant, keys: Array) -> Vector4:
	if not data is Dictionary: return Vector4.INF
	var value := Vector4.ZERO
	for i in range(4):
		var field: Variant = data.get(keys[i])
		if typeof(field) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(field): return Vector4.INF
		value[i] = field
	return value

## Axis intervals: destination start/length, source start/length.
## Work in Unity bottom-up on Y, then flip geometry AND atlas UV so a partial
## top tile starts with the bottom portion of the original sprite's center.
static func _axis(total: float, src_total: float, near: float, far: float, units: float) -> Array[Vector4]:
	var result: Array[Vector4] = []
	var scale := minf(units, total / (near + far))
	var d0 := near * scale
	var d1 := total - far * scale
	var inner_src := src_total - near - far
	var step := inner_src * units
	if d0 > 0.0: result.append(Vector4(0.0, d0, 0.0, near))
	var span := maxf(0.0, d1 - d0)
	for i in range(ceili(span / step)):
		var start := d0 + step * i
		var length := minf(step, d1 - start)
		if length > 0.0: result.append(Vector4(start, length, near, length / units))
	if total > d1: result.append(Vector4(d1, total-d1, src_total-far, far))
	return result

func patches(destination_size: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# The only supported shapes are within the source menu's bounded draw domain.
	# No fallback to a stretched panel or unbounded mesh allocation.
	if _texture == null or not destination_size.is_finite() or destination_size.x <= 0.0 \
			or destination_size.y <= 0.0 or destination_size.x > _max_width or destination_size.y > 1080.0:
		return result
	var xs := _axis(destination_size.x, _region.size.x, _border.x, _border.z, _units_per_texel)
	var ys := _axis(destination_size.y, _region.size.y, _border.y, _border.w, _units_per_texel)
	for y in ys:
		for x in xs:
			result.append({
				"destination": Rect2(x.x, destination_size.y-y.x-y.y, x.y, y.y),
				"source": Rect2(_region.position.x+x.z, _region.end.y-y.z-y.w, x.w, y.w),
			})
	return result

func get_atlas_texture() -> ImageTexture:
	return _texture

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: queue_redraw()

func _draw() -> void:
	for patch in patches(size):
		draw_texture_rect_region(_texture, patch.destination, patch.source)
