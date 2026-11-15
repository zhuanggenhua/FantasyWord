extends RefCounted

# 原始提交 31629d5：TerrainDestinationResolver + TerrainNavigationMap 875–1027。
# 仅迁移候选决策；地图、图节点及逐层坐标变换由调用者注入，不生成替代地图。
# 节点编码 Vector4i(layer, cell.x, cell.y, cell.z)，坐标仍是 Unity 源坐标。
enum Failure { NONE, START_NODE_UNAVAILABLE, NO_CANDIDATE, UNREACHABLE, AMBIGUOUS }
var _layers: Array
var _radius: int
var _world_to_cell: Callable
var _contains: Callable
var _center: Callable
var _path: Callable

# world_to_cell(layer, world) 返回 Vector3i，缺少该层 Tilemap 时返回 null。
# center(node) 返回源世界 Vector2；path(start, goal) 返回非空路径（null 或空数组表示不可达）。
func _init(layer_ids: Array, radius: int, world_to_cell: Callable,
		contains_node: Callable, node_center: Callable, build_node_path: Callable) -> void:
	assert(world_to_cell.is_valid() and contains_node.is_valid()
		and node_center.is_valid() and build_node_path.is_valid(), "导航解析器缺少地图或图依赖")
	_layers = [0]
	for layer in layer_ids:
		if not _layers.has(layer):
			_layers.append(layer)
	_radius = radius
	_world_to_cell = world_to_cell
	_contains = contains_node
	_center = node_center
	_path = build_node_path

func resolve_start(world: Vector2, current_layer: int) -> Variant:
	return resolve_on_layer(world, current_layer)

func resolve_on_layer(world: Vector2, layer: int) -> Variant:
	var requested: Variant = _world_to_cell.call(layer, world)
	if requested == null:
		return null
	var key := Vector4i(layer, requested.x, requested.y, requested.z)
	if _contains.call(key):
		return _candidate(key, world, false)
	var found := false
	var best_distance := INF
	var best := Vector4i.ZERO
	for radius in range(1, _radius + 1):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if absi(x) != radius and absi(y) != radius:
					continue
				var node := key + Vector4i(0, x, y, 0)
				if not _contains.call(node):
					continue
				var center: Vector2 = _center.call(node)
				var distance := center.distance_squared_to(world)
				if not found or distance < best_distance - 0.0001 or (
					_unity_approximately(distance, best_distance) and (
						node.z < best.z or (node.z == best.z and node.y < best.y))):
					found = true
					best_distance = distance
					best = node
		if found:
			break
	if not found:
		return null
	return _candidate(best, _center.call(best), true)

func collect_candidates(world: Vector2) -> Array:
	var candidates: Array = []
	var has_exact := false
	for layer in _layers:
		var candidate: Variant = resolve_on_layer(world, layer)
		if candidate != null:
			candidates.append(candidate)
			has_exact = has_exact or not candidate.was_snapped
	if has_exact:
		for i in range(candidates.size() - 1, -1, -1):
			if candidates[i].was_snapped:
				candidates.remove_at(i)
	return candidates

func resolve_destination(start: Vector4i, world: Vector2, current_layer: int) -> Dictionary:
	var candidates := collect_candidates(world)
	if candidates.is_empty():
		return {"candidate": null, "failure": Failure.NO_CANDIDATE}
	var reachable_count := 0
	var unique: Variant = null
	var current: Variant = null
	for candidate in candidates:
		var path: Variant = _path.call(start, candidate.node_key)
		if path == null or path.is_empty():
			continue
		reachable_count += 1
		unique = candidate
		if candidate.node_key.x == current_layer:
			current = candidate
	if current != null:
		return {"candidate": current, "failure": Failure.NONE}
	if reachable_count == 1:
		return {"candidate": unique, "failure": Failure.NONE}
	return {"candidate": null, "failure": Failure.UNREACHABLE if reachable_count == 0 else Failure.AMBIGUOUS}

static func _candidate(key: Vector4i, world: Vector2, snapped: bool) -> Dictionary:
	return {"node_key": key, "world_position": world, "was_snapped": snapped}

static func _unity_approximately(a: float, b: float) -> bool:
	# Unity Mathf.Approximately 的阈值不同于 Godot is_equal_approx。
	return absf(b - a) < maxf(0.000001 * maxf(absf(a), absf(b)), 1.1210387714598537e-44)
