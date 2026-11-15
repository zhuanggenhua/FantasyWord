extends SceneTree
## Optional source-data probe. Read only the locally extracted rules, never source assets.

const RuleMap = preload("res://game_core/navigation/terrain_rule_map.gd")
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"


func _initialize() -> void:
	call_deferred("_run")


func _world_cell(layer: int, world: Vector2) -> Variant:
	if layer != 0:
		return null
	return Vector3i(floori(world.x), floori(world.y), 0)


func _world_center(node: Vector4i) -> Vector2:
	return Vector2(node.y + 0.5, node.z + 0.5)


func _integral(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))


func _refuse(message: String) -> void:
	printerr("ClickMoveTest rule verification failed: ", message)
	quit(1)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		_refuse("pass one local rules JSON path after --")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not parsed is Dictionary:
		_refuse("invalid JSON fixture")
		return
	if parsed.get("schema") != 1 or parsed.get("source_commit") != SOURCE or parsed.get("rule_tilemap") != 1361196487:
		_refuse("locked scene identity missing")
		return
	if parsed.get("origin") != [-16.0, -10.0, 0.0] or parsed.get("size") != [30.0, 30.0, 1.0] 			or parsed.get("nearest_radius") != 2 or parsed.get("rule_count") != 9:
		_refuse("locked bounds, search radius or rule kinds changed")
		return
	var rows: Variant = parsed.get("rows")
	if not rows is Array or rows.size() != 900:
		_refuse("missing locked rule cells")
		return
	# JSON numbers arrive as floats. Do not silently truncate an edited invalid fixture.
	for row in rows:
		if not row is Dictionary or not row.get("cell") is Array or row.cell.size() != 3 or not row.get("walkable") is bool \
				or not (row.get("cost") is int or row.get("cost") is float) or not is_finite(float(row.cost)):
			_refuse("invalid source rule row")
			return
		for key in ["elevation", "transition", "ramp", "surface"]:
			if not _integral(row.get(key)):
				_refuse("nonintegral rule metadata")
				return
			row[key] = int(row[key])
		for i in range(3):
			if not _integral(row.cell[i]):
				_refuse("nonintegral cell coordinate")
				return
			row.cell[i] = int(row.cell[i])
	var map = RuleMap.new()
	var graph = map.build(rows)
	if graph == null or graph.node_count() != 649 or graph.edge_count != 2226:
		_refuse("actual source graph node or edge count does not match")
		return
	var resolver = map.make_resolver(int(parsed.nearest_radius), _world_cell, _world_center)
	for request in [[Vector2(-5.5, 5.5), Vector2(-3.5, 3.5)], [Vector2.ZERO, Vector2(4.5, 0.0)]]:
		var start_pos: Vector2 = request[0]
		var target: Vector2 = request[1]
		var from: Variant = resolver.resolve_start(start_pos, 0)
		if from == null or from.was_snapped:
			_refuse("source probe start must be an unsnapped rule cell")
			return
		var goal: Dictionary = resolver.resolve_destination(from.node_key, target, 0)
		if goal.candidate == null or goal.candidate.was_snapped or goal.candidate.world_position != target:
			_refuse("source probe destination lost its original coordinate")
			return
		var path: Array[Vector4i] = graph.find_path(from.node_key, goal.candidate.node_key)
		if path.size() < 2 or path.front() != from.node_key or path.back() != goal.candidate.node_key:
			_refuse("nodes do not connect the authored probe endpoints")
			return
		var elevation_changed := false
		for i in range(1, path.size()):
			var a: Vector4i = path[i - 1]
			var b: Vector4i = path[i]
			if absi(a.y - b.y) + absi(a.z - b.z) != 1 or graph.get_edge(a, b).is_empty():
				_refuse("route cut through a non-cardinal or absent edge")
				return
			elevation_changed = elevation_changed or graph.get_node(a).elevation != graph.get_node(b).elevation
		if elevation_changed != (start_pos != Vector2.ZERO):
			_refuse("source corner/flat route elevation differs")
			return
	print("ClickMoveTest locked rule graph: PASS (900 cells, 9 rules, 649 nodes, 2226 edges, 2 route probes)")
	quit(0)
