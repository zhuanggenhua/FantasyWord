extends Polygon2D
## 整图材质的实际帧几何桥接。调用方拥有采样 Sprite2D 的隐藏、父变换和层级。
signal sample_applied(action: String, label: int, direction: int, sample: AtlasTexture)
var last_error := ""
var _playback: Node
var _geometry: Dictionary = {}
var _provider: Callable

func configure(playback: Node, geometry: Dictionary, material_provider: Callable) -> bool:
	if _playback != null or playback == null or not playback.has_signal("sample_resolved") or not material_provider.is_valid():
		return false
	if geometry.is_empty():
		return false
	for sample in geometry:
		if not _valid_sample(sample, geometry[sample]):
			return false
	_geometry = geometry.duplicate()
	_provider = material_provider
	_playback = playback
	_playback.connect("sample_resolved", _on_sample)
	_clear("等待下一次真实动画采样")
	return true

func _valid_sample(sample: Variant, record: Variant) -> bool:
	if not sample is AtlasTexture or not record is Dictionary:
		return false
	if sample.atlas == null or sample.atlas is AtlasTexture or sample.margin != Rect2():
		return false
	var rect: Rect2 = sample.region
	if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x <= 0 or rect.size.y <= 0:
		return false
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > sample.atlas.get_width() or rect.end.y > sample.atlas.get_height():
		return false
	var pivot = record.get("pivot_bottom")
	var ppu = record.get("pixels_per_unit")
	if not pivot is Vector2 or not pivot.is_finite() or not (ppu is float or ppu is int):
		return false
	if not is_finite(float(ppu)) or ppu <= 0:
		return false
	return record.get("flip_h") is bool and record.get("flip_v") is bool

func _on_sample(action: String, label: int, direction: int, sample: Texture2D) -> void:
	var record = _geometry.get(sample)
	if not _valid_sample(sample, record):
		_clear("实际帧缺少有效切片、轴点或像素单位证据")
		return
	var result = _provider.call(action, label, direction, sample)
	if not result is Dictionary or result.get("ok") != true:
		_clear("实际帧材质绑定失败")
		return
	var next_material = result.get("material")
	if not next_material is ShaderMaterial or next_material.get_shader_parameter("main_map") != sample.atlas:
		_clear("材质未绑定当前实际帧的整图")
		return
	var rect: Rect2 = sample.region
	var pivot: Vector2 = record.pivot_bottom
	# Unity 轴点为左下起像素；Godot 局部坐标向下。镜像只由显式源 flip 设置决定。
	var top_pivot := Vector2(pivot.x, rect.size.y - pivot.y)
	var vertices := PackedVector2Array([Vector2.ZERO, Vector2(rect.size.x, 0), rect.size, Vector2(0, rect.size.y)])
	var coords := PackedVector2Array()
	for i in vertices.size():
		coords.append(rect.position + vertices[i])
		var point: Vector2 = (vertices[i] - top_pivot) / float(record.pixels_per_unit)
		if record.flip_h: point.x = -point.x
		if record.flip_v: point.y = -point.y
		vertices[i] = point
	# Polygon2D 将像素 uv 除以整图尺寸；避免 Sprite2D/AtlasTexture 局部 UV 假设。
	texture = sample.atlas
	polygon = vertices
	uv = coords
	texture_offset = Vector2.ZERO
	texture_rotation = 0.0
	texture_scale = Vector2.ONE
	offset = Vector2.ZERO
	material = next_material
	last_error = ""
	sample_applied.emit(action, label, direction, sample)

func _clear(reason: String) -> void:
	polygon = PackedVector2Array()
	uv = PackedVector2Array()
	texture = null
	material = null
	last_error = reason
