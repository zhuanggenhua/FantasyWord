extends SceneTree
## Source geometry and rule inputs are explicitly private files outside Git.

const Geometry = preload("res://validation/clickmovetest_static_geometry.gd")
const Selector = preload("res://validation/static_waypoint_route_selector.gd")
const Route = preload("res://game_core/navigation/terrain_world_route.gd")
const U_START := Vector2(-5.5, 5.5)
const U_DESTINATION := Vector2(-3.5, 3.5)
const HISTORICAL_SOURCE := "fallback:(-10, -10, 0)->(-7, -8, 0)"
const RADIUS := 0.32 # Pinned scene/prefab steering profile radius .35 minus source skin .03.
var _all_cells: Array[Vector3i] = []
var _rule_cells: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _world_cell(layer: int, world: Vector2) -> Variant:
	return Vector3i(floori(world.x), floori(world.y), 0) if layer == 0 else null


func _node_center(node: Vector4i) -> Vector2:
	return Vector2(node.y + 0.5, node.z + 0.5)


func _cell_center(cell: Vector3i) -> Vector2:
	return _node_center(Vector4i(0,cell.x,cell.y,cell.z))


func _has_surface(point: Vector2) -> bool:
	return _rule_cells.has(_world_cell(0, point))


func _blocked(point: Vector2, radius: float) -> bool:
	return Geometry.has_blocking_circle(root.world_2d, point, radius)


func _refuse(reason: String) -> void:
	printerr("ClickMoveTest static clearance: ", reason)
	quit(1)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		_refuse("pass the locked rules JSON and the static geometry JSON after --")
		return
	var rules: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var original_shapes: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not rules is Dictionary or not original_shapes is Dictionary or rules.get("source_commit") != Geometry.SOURCE \
			or rules.get("rule_tilemap") != 1361196487 or rules.get("rows", []).size() != 900 \
			or original_shapes.get("schema") != 1 or original_shapes.get("source_commit") != Geometry.SOURCE \
			or original_shapes.get("scene") != "Assets/Scenes/ClickMoveTest.unity" \
			or original_shapes.get("bodies", []).size() != 35:
		_refuse("locked input provenance not admitted")
		return
	for row in rules.rows:
		var c := Vector3i(int(row.cell[0]),int(row.cell[1]),int(row.cell[2]))
		_all_cells.append(c)
		_rule_cells[c] = true # A defined blocked tile still has a source surface sample.
	_all_cells.sort_custom(func(a: Vector3i,b: Vector3i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var route := Route.new(rules.rows, int(rules.nearest_radius), _world_cell, _node_center)
	if Geometry.load_into(root, original_shapes) != 35 or route.graph.node_count() != 649:
		_refuse("locked map inventory mismatch")
		return
	await physics_frame
	await physics_frame
	if not _blocked(Vector2(-3.5,4.0), RADIUS) or Geometry.has_blocking_circle(root.world_2d, Vector2(-3.5,4.0), RADIUS, 7752):
		_refuse("default static clearance and production movement mask must stay distinct")
		return
	var selector := Selector.new(func(): return _all_cells, _cell_center, route.try_build_world_path, _has_surface, _blocked)
	var historical := PackedVector2Array([Vector2(-9.5,-9.5), Vector2(-8.5,-9.5), Vector2(-8.5,-7.5)])
	var found: Dictionary = selector.resolve(U_START, U_DESTINATION, RADIUS)
	var historical_hits := Selector.count_clearance_violations(historical, RADIUS, _blocked)
	print("historical world polyline clearance=", historical_hits)
	print("current route source=", found.get("route_source"), " world path=", found.get("full_route"))
	if historical_hits != 0 or found.get("route_source") != HISTORICAL_SOURCE or found.get("full_route") != historical:
		_refuse("historical source cell label and final world route must reproduce independently")
		return
	print("ClickMoveTest serialized static clearance: PASS (35 source bodies; distinct movement and static masks; native fallback selection)")
	quit(0)
