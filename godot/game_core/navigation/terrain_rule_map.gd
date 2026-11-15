extends RefCounted
## 31629d5：TerrainNavigationMap.BuildLegacyDefaultLayerGraph / AddDefaultLayerGraphEdges
## / CanTraverseElevation；TerrainNavigationTile 的字段语义。仅默认层、Z=0。
## 输入是已核实的规则瓦片语义，不负责图片、Tilemap 坐标变换或表面状态模拟。
const Graph = preload("res://game_core/navigation/terrain_navigation_graph.gd")
const Resolver = preload("res://game_core/navigation/terrain_destination_resolver.gd")
const CARDINAL := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i(0, 1, 0), Vector3i(0, -1, 0)]
var graph = Graph.new()

# rows 必须包含 cell:[x,y,0], walkable,elevation,transition,ramp,surface,cost。
# effective_costs 为调用者已计算的有效代价，键为 Vector3i；缺省代表无运行时倍率。
# 更新规则或倍率时显式重新 build，清除旧图；不暗中保留过时边。
func build(rows: Array, effective_costs: Dictionary = {}) -> RefCounted:
	graph.clear()
	var tiles: Dictionary = {}
	for row in rows:
		for field in ["cell", "walkable", "elevation", "transition", "ramp", "surface", "cost"]:
			assert(row.has(field), "规则瓦片缺少作者字段：" + field)
		var c = row.cell
		assert(c.size() == 3, "规则瓦片坐标必须为三个整数")
		for value in c:
			assert(is_finite(float(value)) and float(value) == floor(float(value)), "规则瓦片坐标不是有限整数")
		assert(int(c[2]) == 0, "仅支持原始默认层缓存的 Z=0")
		var cell := Vector3i(int(c[0]), int(c[1]), 0)
		assert(not tiles.has(cell), "规则瓦片坐标重复")
		var tile: Dictionary = row.duplicate(true)
		tile.walkable = bool(row.walkable) and int(row.transition) != 2
		tile.elevation = maxi(0, int(row.elevation))
		tile.cost = Graph._f32(maxf(0.01, Graph._f32(float(row.cost))))
		tiles[cell] = tile
	var cells: Array = tiles.keys()
	cells.sort_custom(func(a: Vector3i, b: Vector3i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell in cells:
		var tile: Dictionary = tiles[cell]
		graph.add_node(key(cell), tile.walkable, tile.elevation, int(tile.surface),
			float(effective_costs.get(cell, tile.cost)))
	for cell in cells:
		if not graph.contains_node(key(cell)):
			continue
		for offset in CARDINAL:
			var target: Vector3i = cell + offset
			if graph.contains_node(key(target)) and can_traverse_elevation(cell, tiles[cell], target, tiles[target]):
				graph.add_same_layer_edge(key(cell), key(target), float(effective_costs.get(target, tiles[target].cost)))
	return graph

func make_resolver(radius: int, world_to_cell: Callable, node_center: Callable) -> RefCounted:
	return Resolver.new([], radius, world_to_cell, graph.contains_node, node_center, graph.find_path)

static func key(cell: Vector3i) -> Vector4i:
	return Vector4i(0, cell.x, cell.y, cell.z)

static func can_traverse_elevation(a: Vector3i, first: Dictionary, b: Vector3i, second: Dictionary) -> bool:
	var difference := absi(int(first.elevation) - int(second.elevation))
	if difference == 0:
		return true
	if difference > 1:
		return false
	var ramp := 0
	for tile in [first, second]:
		if int(tile.transition) != 1:
			continue
		var direction := int(tile.ramp)
		if direction == 0 or (ramp != 0 and ramp != direction):
			return false
		ramp = direction
	var step: Vector3i = b - a if first.elevation < second.elevation else a - b
	match ramp:
		1: return step == Vector3i.RIGHT or step == Vector3i(0, 1, 0)
		2: return step == Vector3i.LEFT or step == Vector3i(0, 1, 0)
		3: return step == Vector3i.RIGHT or step == Vector3i(0, -1, 0)
		4: return step == Vector3i.LEFT or step == Vector3i(0, -1, 0)
	return false
