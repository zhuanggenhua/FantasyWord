extends Polygon2D
## 整图材质的实际帧几何桥接。调用方拥有采样 Sprite2D 的隐藏、父变换和层级。
signal sample_applied(action: String, label: int, direction: int, sample: AtlasTexture)
var last_error := ""
var _playback: Node
var _geometry: Dictionary = {}
var _provider: Callable
var _ground_sample: AtlasTexture
var _ground_geometry: Dictionary = {}

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
		_ground_sample = null
		_ground_geometry = {}
		_clear("实际帧缺少有效切片、轴点或像素单位证据")
		return
	# 原脚底查询依赖当前 Sprite，不依赖材质/UV 是否成功；绘制失败不抹掉此身份。
	_ground_sample = sample
	_ground_geometry = record.duplicate(true)
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

## 当前已采样 Sprite 的表现脚底。bounds_center_x 是调用者核实的世界渲染边界中心，
## 不能用节点原点或未经核实的完整矩形推断 Unity 紧网格/自定义 Bounds。
## configured_frame_height 为 null 仅表示原 _currentAnimData 缺失，使用实际 Sprite 高。
## ground_pixel_y 为 null 表示原 frameData 缺失；不以透明边界猜脚底。
func query_ground_anchor(ground_pixel_y: Variant, configured_frame_height: Variant,
		bounds_center_x: float) -> Dictionary:
	if not is_inside_tree() or not _valid_sample(_ground_sample, _ground_geometry):
		return {"ok":false,"reason":"缺少当前真实 Sprite 几何"}
	if not ground_pixel_y is int:
		return {"ok":false,"reason":"缺少作者顶部起算地面像素行"}
	if not is_finite(bounds_center_x):
		return {"ok":false,"reason":"缺少有限的世界渲染边界中心"}
	var actual_height: float = _ground_sample.region.size.y
	var frame_height: float = actual_height
	if configured_frame_height != null:
		if not (configured_frame_height is int or configured_frame_height is float):
			return {"ok":false,"reason":"配置帧高度类型无效"}
		frame_height = float(configured_frame_height)
	if not is_finite(frame_height) or frame_height <= 0.0:
		return {"ok":false,"reason":"配置帧高度必须有限且为正"}
	var transform_now := global_transform
	if not transform_now.is_finite():
		return {"ok":false,"reason":"当前主体变换无效"}
	var ground_from_top := clampf(float(ground_pixel_y)+0.5,0.0,frame_height)
	var bottom_fraction := 1.0-ground_from_top/frame_height
	var source_local_y: float = (bottom_fraction*actual_height-_ground_geometry.pivot_bottom.y)/float(_ground_geometry.pixels_per_unit)
	if _ground_geometry.flip_v: source_local_y = -source_local_y
	# Unity 局部向上改为 Godot 向下，X 保持零；不能以 Bounds 中心的局部 X 求 Y。
	var ground_global := transform_now * Vector2(0.0,-source_local_y)
	if not ground_global.is_finite():
		return {"ok":false,"reason":"脚底变换结果无效"}
	return {"ok":true,"position":Vector2(bounds_center_x,ground_global.y)}
