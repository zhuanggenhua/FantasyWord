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
var _world_to_cell: Callable


func _init(rows: Array, radius: int, world_to_cell: Callable, node_center: Callable,
		effective_costs: Dictionary = {}) -> void:
	assert(world_to_cell.is_valid() and node_center.is_valid(), "缺少规则地图坐标转换")
	_node_center = node_center
	_world_to_cell = world_to_cell
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

## 原 TryResolveRampMovementDirection：按当前物理根给方向输入挑选合法邻格；
## 找不到足够同向的邻格时返回 null，保留原意图，不改变路径或碰撞数据。
func resolve_ramp_movement_direction(current: Vector2, desired: Vector2) -> Variant:
	if not current.is_finite() or not desired.is_finite() or desired.length_squared()<=0.000001:
		return null
	var cell: Variant = _world_to_cell.call(0,current)
	if not cell is Vector3i: return null
	var tile: Variant = _tiles.get(cell)
	if tile==null or tile.transition!=1 or tile.ramp==0: return null
	var input := desired.normalized()
	var best_score := 0.25
	var best: Variant = null
	for offset: Vector3i in RuleMap.CARDINAL:
		var other: Vector3i = cell+offset
		var key := RuleMap.key(other)
		if not graph.contains_node(key): continue
		var target: Dictionary = _tiles[other]
		if (target.transition==1 and target.ramp!=tile.ramp) or not RuleMap.can_traverse_elevation(cell,tile,other,target):
			continue
		var center: Vector2 = _node_center.call(key)
		var delta := center-current
		if delta.length_squared()<=0.000001: continue
		var direction := delta.normalized()
		var score := input.dot(direction)
		# 原严格大于；平手保留右、左、上、下顺序中的较早邻格。
		if score>best_score:
			best_score=score
			best=direction
	return best
