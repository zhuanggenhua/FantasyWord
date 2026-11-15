extends RefCounted
## 31629d5 TerrainNavigationMap.ConvertToWorldPath / TryAppendRampCenterLine /
## AppendWorldPoint / CompressWorldPoints 的默认层移植。仅处理已经找到的节点路径。
## 坐标由作者网格的 node_center 回调提供；本模块不猜像素倍率或生成新坡线。
const Graph = preload("res://game_core/navigation/terrain_navigation_graph.gd")

# tiles 以 Vector3i 为键，包含原规则字段 transition、ramp、elevation。
# node_center 接收 Vector4i(layer,x,y,z) 返回 Vector2。
static func project_default(node_path: Array, tiles: Dictionary, node_center: Callable,
		requested_destination: Vector2, use_requested_destination: bool) -> PackedVector2Array:
	if node_path.is_empty():
		return PackedVector2Array()
	for node in node_path:
		assert(node is Vector4i and node.x == 0 and node.w == 0, "仅支持默认层 Z=0 路径")
	if node_path.size() == 1:
		return PackedVector2Array([requested_destination if use_requested_destination else node_center.call(node_path[0])])
	var points: Array[Vector2] = []
	var preserved: Array[bool] = []
	append_point(points, preserved, node_center.call(node_path[0]), false)
	var index := 1
	while index < node_path.size():
		var end := _ramp_end(node_path, tiles, index)
		for i in range(index, end + 1):
			append_point(points, preserved, node_center.call(node_path[i]), end > index)
		index = end + 1
	if use_requested_destination:
		points[-1] = requested_destination
		preserved[-1] = true
	var compressed := compress_points(points, preserved)
	compressed.remove_at(0)
	return compressed

static func _cell(node: Vector4i) -> Vector3i:
	return Vector3i(node.y, node.z, node.w)

static func _ramp_end(path: Array, tiles: Dictionary, start: int) -> int:
	var first: Dictionary = tiles.get(_cell(path[start]), {})
	if first.is_empty() or int(first.transition) != 1 or int(first.ramp) == 0:
		return start
	var end := start
	var minimum := maxi(0, int(first.elevation))
	var maximum := minimum
	while end + 1 < path.size():
		var candidate: Dictionary = tiles.get(_cell(path[end + 1]), {})
		if candidate.is_empty() or int(candidate.transition) != 1 or int(candidate.ramp) != int(first.ramp):
			break
		end += 1
		minimum = mini(minimum, maxi(0, int(candidate.elevation)))
		maximum = maxi(maximum, maxi(0, int(candidate.elevation)))
	if end == start or minimum == maximum:
		return start
	var delta := _cell(path[end]) - _cell(path[start])
	if delta.x == 0 or delta.y == 0 or absi(delta.x) != absi(delta.y):
		return start
	var authored := Vector2i.ZERO
	match int(first.ramp):
		1: authored = Vector2i(1, 1)
		2: authored = Vector2i(-1, 1)
		3: authored = Vector2i(1, -1)
		4: authored = Vector2i(-1, -1)
	var direction := Vector2i(signi(delta.x), signi(delta.y))
	return end if direction == authored or direction == -authored else start

static func append_point(points: Array[Vector2], preserved: Array[bool], point: Vector2, preserve: bool) -> void:
	if not points.is_empty() and (points[-1] - point).length_squared() <= Graph._f32(0.000001):
		preserved[-1] = preserved[-1] or preserve
		return
	points.append(point)
	preserved.append(preserve)

static func compress_points(points: Array[Vector2], preserved: Array[bool]) -> PackedVector2Array:
	assert(not points.is_empty() and points.size() == preserved.size())
	var compressed := PackedVector2Array([points[0]])
	for i in range(1, points.size() - 1):
		var first := points[i] - compressed[-1]
		var second := points[i + 1] - points[i]
		var cross := Graph._f32(Graph._f32(first.x * second.y) - Graph._f32(first.y * second.x))
		var dot := Graph._f32(Graph._f32(first.x * second.x) + Graph._f32(first.y * second.y))
		if preserved[i] or absf(cross) > Graph._f32(0.0001) or dot <= 0.0:
			compressed.append(points[i])
	# 与原方法一致：即使所有采样合并为一个点，仍追加末点，之后移除起点。
	compressed.append(points[-1])
	return compressed
