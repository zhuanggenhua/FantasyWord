extends RefCounted
## 对应 31629d5 的 ClickMoveTestContextSteeringWaypointValidator 静态选路部分。
## 仅验证器使用，不实现 NPC 转向、运行时碰撞过滤或 Unity 原生枚举顺序。
## 有序候选须由调用方按原 cellBounds 顺序提供 TryGetSurfaceSample(cell) 成功的格子；
## 这里的 surface 存在不等于 Walkable，不能用导航图节点集合替代。
const SAMPLE_SPACING := 0.1
var _ordered_surface_cells: Callable
var _cell_center: Callable
var _build_world_path: Callable
var _has_surface_world: Callable
var _has_blocking_circle: Callable

func _init(ordered_surface_cells: Callable, cell_center: Callable, build_world_path: Callable, has_surface_world: Callable, has_blocking_circle: Callable) -> void:
	_ordered_surface_cells = ordered_surface_cells
	_cell_center = cell_center
	_build_world_path = build_world_path
	_has_surface_world = has_surface_world
	_has_blocking_circle = has_blocking_circle

## 路径提供者返回不含起点的世界路径，失败返回 null 或空数组。
## 圆检测提供者须执行原静态合同：非 trigger 且无 CharacterBase 祖先即阻塞。
func resolve(start: Vector2, destination: Vector2, radius: float) -> Dictionary:
	var preferred := create_full_route(start, _build_world_path.call(start, destination))
	if not preferred.is_empty() and _is_clear(preferred.full_route, radius):
		preferred.route_source = "preferred-clickmove-corner"
		return preferred
	return find_fallback(radius)

func find_fallback(radius: float) -> Dictionary:
	var cells: Array = _ordered_surface_cells.call()
	var best: Dictionary = {}
	var best_length := INF
	for start_cell: Vector3i in cells:
		var start: Vector2 = _cell_center.call(start_cell)
		for destination_cell: Vector3i in cells:
			var manhattan := absi(start_cell.x - destination_cell.x) + absi(start_cell.y - destination_cell.y)
			if manhattan < 5 or manhattan > 10:
				continue
			var destination: Vector2 = _cell_center.call(destination_cell)
			var candidate := create_full_route(start, _build_world_path.call(start, destination))
			if candidate.is_empty():
				continue
			var length := polyline_length(candidate.full_route)
			if length < 3.0 or length > 8.0 or length >= best_length:
				continue
			if candidate.primary_corner.distance_to(candidate.full_route[-1]) < 1.6 or not _is_clear(candidate.full_route, radius):
				continue
			best_length = length
			candidate.route_source = "fallback:%s->%s" % [str(start_cell), str(destination_cell)]
			best = candidate
	return best

func _is_clear(points: PackedVector2Array, radius: float) -> bool:
	return count_surface_violations(points, _has_surface_world) == 0 and count_clearance_violations(points, radius, _has_blocking_circle) == 0

static func create_full_route(start: Vector2, path: Variant) -> Dictionary:
	if path == null or path.size() < 2:
		return {}
	var route := PackedVector2Array([start])
	route.append_array(PackedVector2Array(path))
	if count_corners(route) == 0:
		return {}
	for i in range(1, route.size() - 1):
		var previous := route[i] - route[i - 1]
		var next := route[i + 1] - route[i]
		if absf(previous.cross(next)) <= 0.0001:
			continue
		if route[i].distance_to(route[-1]) >= 1.6:
			return {"full_route": route, "primary_corner": route[i]}
	return {}

static func count_corners(points: PackedVector2Array) -> int:
	var count := 0
	for i in range(1, points.size() - 1):
		if absf((points[i] - points[i - 1]).cross(points[i + 1] - points[i])) > 0.0001:
			count += 1
	return count

static func polyline_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, points.size()):
		length = PackedFloat32Array([length + points[i - 1].distance_to(points[i])])[0]
	return length

static func count_surface_violations(points: PackedVector2Array, has_surface: Callable) -> int:
	var violations := 0
	for i in range(1, points.size()):
		var steps := sample_steps(points[i - 1], points[i])
		for step in range(steps + 1):
			if not has_surface.call(points[i - 1].lerp(points[i], float(step) / steps)):
				violations += 1
	return violations

static func count_clearance_violations(points: PackedVector2Array, radius: float, has_blocking_circle: Callable) -> int:
	var violations := 0
	for i in range(1, points.size()):
		var steps := sample_steps(points[i - 1], points[i])
		for step in range(steps + 1):
			if has_blocking_circle.call(points[i - 1].lerp(points[i], float(step) / steps), radius):
				violations += 1
	return violations

static func sample_steps(from: Vector2, to: Vector2) -> int:
	# Unity 使用 float 除法；GDScript 标量为 double，需还原单精度再 CeilToInt。
	var spacing := PackedFloat32Array([SAMPLE_SPACING])[0]
	var quotient := PackedFloat32Array([from.distance_to(to) / spacing])[0]
	return maxi(1, ceili(quotient))
