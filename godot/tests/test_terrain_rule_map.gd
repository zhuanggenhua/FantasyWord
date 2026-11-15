extends SceneTree
const Map = preload("res://game_core/navigation/terrain_rule_map.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL ", label)
func tile(x: int, y: int, elevation := 0, transition := 0, ramp := 0) -> Dictionary:
	return {"cell": [x,y,0], "walkable": true, "elevation": elevation,
		"transition": transition, "ramp": ramp, "surface": 1, "cost": 1.0}
func k(x: int, y: int) -> Vector4i:
	return Vector4i(0,x,y,0)
func _run() -> void:
	var map = Map.new()
	var blocked := tile(2,0,0,2)
	var disabled := tile(0,2)
	disabled.walkable = false
	var negative := tile(-1,0,-5)
	var graph = map.build([tile(1,1),tile(0,1),tile(1,0),tile(0,0),blocked,disabled,negative])
	check(graph.node_count() == 5, "Blocked 与 Walkable=false 都排除")
	check(graph.get_node(k(-1,0)).elevation == 0, "负高度归零")
	check(graph.find_path(k(0,0),k(1,1)) == [k(0,0),k(1,0),k(1,1)], "等分按右左上下插入，输入乱序不改变")
	check(graph.get_edge(k(0,0),k(1,1)).is_empty(), "不连对角边")
	for ramp in range(1,5):
		for direction in Map.CARDINAL:
			var low := tile(0,0,0,1,ramp)
			var high := tile(direction.x,direction.y,1)
			graph = map.build([low,high])
			var allowed: bool = (direction.x == 1 and ramp in [1,3]) or (direction.x == -1 and ramp in [2,4]) or (direction.y == 1 and ramp in [1,2]) or (direction.y == -1 and ramp in [3,4])
			check(graph.has_path(k(0,0),k(direction.x,direction.y)) == allowed, "坡向上行")
			check(graph.has_path(k(direction.x,direction.y),k(0,0)) == allowed, "坡向下行")
	for pair in [[tile(0,0),tile(1,0,1)], [tile(0,0,0,1,0),tile(1,0,1)], [tile(0,0,0,1,1),tile(1,0,1,1,3)], [tile(0,0,0,1,1),tile(1,0,2)]]:
		graph = map.build(pair)
		check(graph.edge_count == 0, "无坡、空坡、冲突坡或跨两级拒绝")
	graph = map.build([tile(0,0,0,1,0),tile(1,0,0,1,4)])
	check(graph.edge_count == 2, "同高度不检查坡向")
	graph = map.build([tile(0,0),tile(1,0,1,1,1)])
	check(graph.edge_count == 2, "高处瓦片也可以提供坡向")
	var cheap := tile(0,0)
	cheap.cost = -2.0
	graph = map.build([cheap,tile(1,0)], {Vector3i(1,0,0): 7.0})
	check(is_equal_approx(graph.get_edge(k(1,0),k(0,0)).cost,0.01), "目标基础代价下限")
	check(graph.get_node(k(1,0)).cost == 7.0 and graph.get_edge(k(0,0),k(1,0)).cost == 7.0, "注入有效代价作用于节点及进入边")
	var resolver = map.make_resolver(2, func(_layer, world): return Vector3i(floori(world.x),floori(world.y),0), func(node): return Vector2(node.y+0.5,node.z+0.5))
	var resolved = resolver.resolve_destination(k(0,0),Vector2(1.2,0.3),0)
	check(resolved.failure == 0 and resolved.candidate.node_key == k(1,0), "真实图接入目标解析")
	graph = map.build([tile(0,0)])
	check(graph.node_count() == 1 and graph.edge_count == 0, "重建移除旧节点和边")
	print("PASS terrain_rule_map ", checks, " checks" if failures == 0 else " FAILED")
	quit(1 if failures else 0)
