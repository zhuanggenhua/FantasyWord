extends RefCounted
## ClickMoveTest's default-layer TryBuildWorldPath, with geometry supplied by the map.
## No automatic navigation fallback; a present map either gives waypoints or refuses.

const RuleMap = preload("res://game_core/navigation/terrain_rule_map.gd")
const WorldPath = preload("res://game_core/navigation/terrain_world_path.gd")
var _graph: RefCounted
var graph: RefCounted:
	get: return _graph
var _resolver: RefCounted
var _rule_map := RuleMap.new()
var _tiles: Dictionary[Vector3i, Dictionary] = {}
var _node_center: Callable


func _init(rows: Array, radius: int, world_to_cell: Callable, node_center: Callable,
		effective_costs: Dictionary = {}) -> void:
	assert(world_to_cell.is_valid() and node_center.is_valid(), "缺少规则地图坐标转换")
	_node_center = node_center
	_graph = _rule_map.build(rows, effective_costs)
	for row in rows:
		var cell := Vector3i(int(row.cell[0]), int(row.cell[1]), int(row.cell[2]))
		var source := {"elevation": maxi(0, int(row.elevation)), "transition": int(row.transition),
			"ramp": int(row.ramp)}
		_tiles[cell] = source
	_resolver = _rule_map.make_resolver(radius, world_to_cell, _node_center)


func try_build_world_path(start: Vector2, destination: Vector2) -> Variant:
	if graph.node_count() == 0:
		return null
	var from: Variant = _resolver.resolve_start(start, 0)
	if from == null:
		return null
	var goal: Dictionary = _resolver.resolve_destination(from.node_key, destination, 0)
	if goal.candidate == null:
		return null
	var candidate: Dictionary = goal.candidate
	var path: Array[Vector4i] = graph.find_path(from.node_key, candidate.node_key)
	if path.is_empty():
		return null
	var world_points := WorldPath.project_default(path, _tiles, _node_center, candidate.world_position, not candidate.was_snapped)
	return null if world_points.is_empty() else world_points
