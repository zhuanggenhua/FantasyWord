extends RefCounted
## Original TerrainNavigationGraph algorithm over explicitly authored data.
## Key: (layer ID, Unity cell X, Unity cell Y, Unity cell Z). Rendering conversion is external.

var _nodes: Dictionary = {}
var _outgoing: Dictionary = {}
var _edge_count: int = 0
var edge_count: int:
	get: return _edge_count


func clear() -> void:
	_nodes.clear()
	_outgoing.clear()
	_edge_count = 0


func add_node(key: Vector4i, walkable: bool, elevation: int,
		surface_kind: int, traversal_cost: float) -> bool:
	if not walkable or _nodes.has(key):
		return false
	_nodes[key] = {"elevation": elevation, "surface_kind": surface_kind,
		"cost": _f32(maxf(0.01, traversal_cost))}
	_outgoing[key] = []
	return true


func contains_node(key: Vector4i) -> bool:
	return _nodes.has(key)


func get_node(key: Vector4i) -> Dictionary:
	return _nodes.get(key, {}).duplicate()


func node_count() -> int:
	return _nodes.size()


func add_same_layer_edge(from: Vector4i, to: Vector4i, traversal_cost: float) -> bool:
	return from.x == to.x and _add_edge(from, to, traversal_cost, null)


func add_transition(from: Vector4i, to: Vector4i, kind: int, bidirectional: bool,
		traversal_cost: float, waypoints: PackedVector2Array,
		commit_point: Vector2) -> bool:
	# None is invalid; distinct endpoints can be explicit even within one layer.
	if from == to or kind == 0:
		return false
	var link := {"from": from, "to": to, "kind": kind, "waypoints": waypoints.duplicate(),
		"commit_point": commit_point}
	var added := _add_edge(from, to, traversal_cost, link)
	if bidirectional:
		var reverse_added := _add_edge(to, from, traversal_cost, link)
		added = added or reverse_added # Try both, even if the forward edge existed.
	return added


func _add_edge(from: Vector4i, to: Vector4i, cost: float, link: Variant) -> bool:
	if not _nodes.has(from) or not _nodes.has(to):
		return false
	var edges: Array = _outgoing[from]
	for edge in edges:
		if edge.to == to:
			return false
	edges.append({"to": to, "cost": _f32(maxf(0.01, cost)), "link": link})
	_edge_count += 1
	return true


func get_edge(from: Vector4i, to: Vector4i) -> Dictionary:
	for edge in _outgoing.get(from, []):
		if edge.to == to:
			return edge.duplicate(true)
	return {}


func has_path(start: Vector4i, goal: Vector4i) -> bool:
	return not find_path(start, goal).is_empty()


func find_path(start: Vector4i, goal: Vector4i) -> Array[Vector4i]:
	if not _nodes.has(start) or not _nodes.has(goal):
		return []
	var open: Array[Vector4i] = [start]
	var closed: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score := {start: 0.0}
	var f_score := {start: _heuristic(start, goal)}
	while not open.is_empty():
		var best_idx := 0
		# The original retains the earliest open node when scores are equal.
		for i in range(1, open.size()):
			if f_score[open[i]] < f_score[open[best_idx]]:
				best_idx = i
		var current := open[best_idx]
		open.remove_at(best_idx)
		if current == goal:
			var path: Array[Vector4i] = [current]
			while came_from.has(current):
				current = came_from[current]
				path.append(current)
			path.reverse()
			return path
		closed[current] = true
		for edge in _outgoing[current]:
			var target: Vector4i = edge.to
			if closed.has(target):
				continue
			var tentative := _f32(g_score[current] + edge.cost)
			if tentative >= g_score.get(target, INF):
				continue
			came_from[target] = current
			g_score[target] = tentative
			f_score[target] = _f32(tentative + _heuristic(target, goal))
			if not open.has(target):
				open.append(target)
	return []


static func _heuristic(from: Vector4i, to: Vector4i) -> float:
	return _f32(absi(from.y - to.y) + absi(from.z - to.z) + int(from.x != to.x))


static func _f32(value: float) -> float:
	# Pin the C# float score boundaries instead of changing tie order via GDScript doubles.
	return PackedFloat32Array([value])[0]
