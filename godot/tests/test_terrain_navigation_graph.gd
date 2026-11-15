extends SceneTree

const Graph = preload("res://game_core/navigation/terrain_navigation_graph.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)


func _node(graph, key: Vector4i) -> bool:
	return graph.add_node(key, true, 0, 0, 1.0)


func _run() -> void:
	var start := Vector4i(0, 0, 0, 0)
	var upper := Vector4i(3, 0, 0, 0)
	var vertical_cell := Vector4i(0, 0, 0, 1)
	var right := Vector4i(0, 1, 0, 0)
	var down := Vector4i(0, 0, -1, 0)
	var goal := Vector4i(0, 1, -1, 0)
	var graph = Graph.new()
	_check(not graph.add_node(start, false, 0, 0, 1), "不可走格不得建立节点")
	for k in [start, upper, vertical_cell, right, down, goal]:
		_check(_node(graph, k), "已审定可走格建立节点")
	_check(not _node(graph, start) and graph.node_count() == 6, "重复节点不会覆盖原记录")
	_check(not graph.add_same_layer_edge(start, upper, 1), "同层接口不能隐式跨层")
	_check(not graph.has_path(start, upper) and not graph.has_path(start, vertical_cell), "同坐标的层与Z不合并")
	_check(graph.find_path(start, start) == [start], "同一节点原路返回")
	_check(not graph.has_path(start, Vector4i(0, 99, 0, 0)), "缺少目标节点")
	var points := PackedVector2Array([Vector2(0.4, 1.2)])
	_check(not graph.add_transition(start, start, 1, true, 1, points, Vector2.ZERO), "相同端点拒绝")
	_check(not graph.add_transition(start, upper, 0, true, 1, points, Vector2.ZERO), "None 过渡拒绝")
	_check(not graph.add_transition(start, Vector4i(99, 1, 2, 0), 1, true, 1, points, Vector2.ZERO), "显式过渡缺少端点拒绝")
	_check(graph.add_transition(start, upper, 1, false, 0, points, Vector2(0, 1)), "原版单向跨层")
	_check(graph.has_path(start, upper) and not graph.has_path(upper, start), "单向过渡不能反走")
	_check(is_equal_approx(graph.get_edge(start, upper).cost, 0.01), "代价限制下限")
	_check(graph.get_edge(start, upper).link.waypoints == points, "保留作者过渡路径点")
	_check(graph.add_transition(start, upper, 2, true, 5, PackedVector2Array(), Vector2.ZERO),
		"已有正向边仍可补反向")
	_check(graph.get_edge(start, upper).link.kind == 1 and graph.get_edge(upper, start).link.kind == 2, "不覆盖已有边")
	_check(not graph.add_transition(start, upper, 2, true, 5, points, Vector2.ZERO) and graph.edge_count == 2,
		"重复边不改变拓扑")
	graph.add_same_layer_edge(start, down, 1)
	graph.add_same_layer_edge(start, right, 1)
	graph.add_same_layer_edge(down, goal, 1)
	graph.add_same_layer_edge(right, goal, 1)
	_check(graph.find_path(start, goal) == [start, down, goal], "等分保持先入开放集合的作者边")
	var weighted = Graph.new()
	for k in [start, down, right, goal]:
		_node(weighted, k)
	weighted.add_same_layer_edge(start, down, 1)
	weighted.add_same_layer_edge(start, right, 1)
	weighted.add_same_layer_edge(down, goal, 9)
	weighted.add_same_layer_edge(right, goal, 1)
	_check(weighted.find_path(start, goal) == [start, right, goal], "先发现的昂贵路径由更低代价更新")
	_check(weighted.find_path(goal, start).is_empty(), "有向图不会自动补边")
	weighted.clear()
	_check(weighted.node_count() == 0 and weighted.edge_count == 0 and not weighted.has_path(start,goal), "清图同时删除节点与边")
	_check(weighted.add_node(start, true, 4, 7, 0) and weighted.get_node(start).elevation == 4
		and weighted.get_node(start).surface_kind == 7 and is_equal_approx(weighted.get_node(start).cost, 0.01),
		"记录正式地形信息并限制节点代价")
	print("PASS 加权地形寻路图：%d 项，失败 %d" % [checks, failures])
	quit(int(failures > 0))
