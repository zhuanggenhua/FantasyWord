extends SceneTree
const Resolver = preload("res://game_core/navigation/terrain_destination_resolver.gd")
const Graph = preload("res://game_core/navigation/terrain_navigation_graph.gd")
var checks := 0
var failures := 0
var nodes: Dictionary = {}
var reachable: Array = []
var queried: Array = []
var cell_z := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _cell(layer: int, world: Vector2) -> Variant:
	if layer == 99:
		return null
	return Vector3i(floori(world.x), floori(world.y), cell_z)

func _contains(key: Vector4i) -> bool:
	return nodes.has(key)

func _center(key: Vector4i) -> Vector2:
	return nodes[key]

func _path(start: Vector4i, goal: Vector4i) -> Array:
	queried.append(goal)
	return [start, goal] if reachable.has(goal) else []

func _resolver(layers: Array = [0], radius: int = 2):
	return Resolver.new(layers, radius, _cell, _contains, _center, _path)

func _run() -> void:
	var zero := Vector4i.ZERO
	var click := Vector2(0.2, 0.8)
	nodes[zero] = Vector2(0.5, 0.5)
	var resolver = _resolver()
	var candidate = resolver.resolve_start(click, 0)
	_check(candidate.node_key == zero and candidate.world_position == click and not candidate.was_snapped,
		"精确起点保留点击位置，不强制吸附中心")
	_check(resolver.resolve_start(click, 99) == null, "缺少当前层地图时起点失败，不切换层")
	_check(resolver.resolve_destination(zero, click, 0).failure == Resolver.Failure.UNREACHABLE, "存在但不可达")
	nodes.clear()
	_check(resolver.resolve_destination(zero, click, 0).failure == Resolver.Failure.NO_CANDIDATE, "无任何候选")
	var left := Vector4i(0, -1, 0, 0)
	var right := Vector4i(0, 1, 0, 0)
	var down := Vector4i(0, 0, -1, 0)
	nodes[left] = Vector2(-1, 0)
	nodes[right] = Vector2(1, 0)
	nodes[down] = Vector2(0, -1)
	candidate = resolver.resolve_on_layer(Vector2.ZERO, 0)
	_check(candidate.node_key == down and candidate.world_position == Vector2(0, -1) and candidate.was_snapped,
		"等距按源 Y 再 X，不使用屏幕 Y")
	nodes.erase(down)
	_check(resolver.resolve_on_layer(Vector2.ZERO, 0).node_key == left, "等 Y 按源 X")
	nodes[right] = Vector2(sqrt(0.99995), 0)
	_check(resolver.resolve_on_layer(Vector2.ZERO, 0).node_key == left, "微小距离改善未越过原 0.0001 门槛，不覆盖先选格")
	nodes[right] = Vector2(sqrt(0.9998), 0)
	_check(resolver.resolve_on_layer(Vector2.ZERO, 0).node_key == right, "距离改善超过原 0.0001 门槛才覆盖")
	nodes[right] = Vector2(1, 0)
	nodes[left] = Vector2(-3, 0)
	_check(resolver.resolve_on_layer(Vector2.ZERO, 0).node_key == right, "首环内按距离选择")
	var far := Vector4i(0, 2, 0, 0)
	nodes[far] = Vector2(0.01, 0)
	_check(resolver.resolve_on_layer(Vector2.ZERO, 0).node_key == right, "首个非空方环优先于更远环更近世界中心")
	reachable = [far]
	queried.clear()
	_check(resolver.resolve_destination(zero, Vector2.ZERO, 0).failure == Resolver.Failure.UNREACHABLE
		and queried == [right], "首环胜出但不可达，不改选其他格或扩环")
	_check(_resolver([0], 0).resolve_on_layer(Vector2.ZERO, 0) == null, "搜索半径零不吸附")
	nodes.clear()
	nodes[far] = Vector2(2, 0)
	_check(_resolver([0], 1).resolve_on_layer(Vector2.ZERO, 0) == null, "半径外拒绝")
	_check(resolver.resolve_on_layer(Vector2.ZERO, 0).node_key == far, "半径边界包含")
	var upper := Vector4i(10, 0, 0, 0)
	var other := Vector4i(20, 0, 0, 0)
	nodes[upper] = Vector2(0.5, 0.5)
	resolver = _resolver([10, 10, 20])
	reachable = [far]
	queried.clear()
	_check(resolver.collect_candidates(click).size() == 1, "精确候选剔除所有吸附候选并去重层")
	_check(resolver.resolve_destination(zero, click, 0).failure == Resolver.Failure.UNREACHABLE
		and queried == [upper], "先精确剪枝再查可达，不能回退可达吸附格")
	reachable = [upper]
	_check(resolver.resolve_destination(zero, click, 0).candidate.node_key == upper, "接受唯一可达其他层")
	nodes[other] = Vector2(0.5, 0.5)
	reachable = [upper, other]
	_check(resolver.resolve_destination(zero, click, 0).failure == Resolver.Failure.AMBIGUOUS, "两个其他可达层拒绝歧义")
	_check(resolver.resolve_destination(zero, click, 10).candidate.node_key == upper, "可达当前层优先")
	reachable = [other]
	_check(resolver.resolve_destination(zero, click, 10).candidate.node_key == other, "当前层不可达则接受唯一其他层")
	cell_z = 7
	nodes.clear()
	var z_node := Vector4i(0, 1, 0, 7)
	nodes[z_node] = Vector2(1.5, 0.5)
	_check(resolver.resolve_start(click, 0).node_key == z_node, "搜环保留源 Z 身份")
	_check(Resolver._unity_approximately(1.0, 1.0000005), "Unity 近似相等阈值")
	_check(not Resolver._unity_approximately(1.0, 1.000005), "不使用 Godot 较宽近似阈值")
	cell_z = 0
	var graph = Graph.new()
	graph.add_node(zero, true, 0, 0, 1)
	graph.add_node(upper, true, 0, 0, 1)
	nodes = {zero: Vector2(0.5, 0.5), upper: Vector2(0.5, 0.5)}
	resolver = Resolver.new([10], 2, _cell, graph.contains_node, _center, graph.find_path)
	_check(resolver.resolve_destination(zero, click, 10).candidate.node_key == zero,
		"真实图未连通的上层不误判可达，同节点路径可用")
	graph.add_transition(zero, upper, 1, false, 1, PackedVector2Array(), Vector2.ZERO)
	_check(resolver.resolve_destination(zero, click, 10).candidate.node_key == upper,
		"真实显式有向过渡与解析器接通")
	print("PASS terrain_destination_resolver ", checks, " checks" if failures == 0 else " FAILED")
	quit(0 if failures == 0 else 1)
