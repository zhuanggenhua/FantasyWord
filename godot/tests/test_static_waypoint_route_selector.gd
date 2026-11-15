extends SceneTree
const Selector = preload("res://validation/static_waypoint_route_selector.gd")
var checks := 0
var failures := 0
var cells: Array = []
var routes := {}
var queries: Array = []
var samples: Array = []
var blockers: Array = []
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL ", label)
func center(cell: Vector3i) -> Vector2:
	return Vector2(cell.x, cell.y)
func route(start: Vector2, destination: Vector2) -> Variant:
	queries.append([start,destination])
	return routes.get([start,destination])
func _run() -> void:
	var selector = Selector.new(func(): return cells, center, route, func(_p): return true, func(p,r): return p in blockers and r == 0.32)
	check(Selector.create_full_route(Vector2.ZERO,null).is_empty(),"null 路径失败")
	check(Selector.create_full_route(Vector2.ZERO,[]).is_empty(),"空路径失败")
	check(Selector.create_full_route(Vector2.ZERO,[Vector2(2,2)]).is_empty(),"少于两个路径点失败")
	check(Selector.create_full_route(Vector2.ZERO,[Vector2(1,0),Vector2(3,0)]).is_empty(),"直线不是拐角路线")
	check(Selector.create_full_route(Vector2.ZERO,[Vector2(1,0),Vector2(1,1.59)]).is_empty(),"拐角距终点不足 1.6")
	check(not Selector.create_full_route(Vector2.ZERO,[Vector2(1,0),Vector2(1,1.6)]).is_empty(),"1.6 边界包含")
	check(Selector.count_corners(PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2(2,0.00009)])) == 0,"叉积阈值内不算拐角")
	check(Selector.count_corners(PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2(2,0.00011)])) == 1,"叉积阈值外算拐角")
	var preferred := [Vector2(1,0),Vector2(1,2)]
	routes[[Vector2.ZERO,Vector2(1,2)]] = preferred
	var result: Dictionary = selector.resolve(Vector2.ZERO,Vector2(1,2),0.32)
	check(result.route_source == "preferred-clickmove-corner", "优先路线通过")
	check(result.full_route == PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2(1,2)]),"世界路径只前置起点，不重算终点")
	check(result.primary_corner == Vector2(1,0),"保留第一个合格拐角")
	blockers = [Vector2(1,1)]
	check(selector.resolve(Vector2.ZERO,Vector2(1,2),0.32).is_empty(),"真实圆查询谓词阻断优先路线")
	blockers = []
	var segment := PackedVector2Array([Vector2.ZERO,Vector2(0.25,0)])
	check(Selector.count_surface_violations(segment,func(p): samples.append(p); return false) == 4,"ceil 距离步数加两端")
	check(samples.front() == Vector2.ZERO and samples.back() == Vector2(0.25,0),"包括两端采样")
	samples.clear()
	check(Selector.count_clearance_violations(PackedVector2Array([Vector2.ZERO,Vector2.ZERO]),0.32,func(p,r): samples.append([p,r]); return true) == 2,"零长度段仍采样两次")
	check(samples[0][1] == 0.32,"圆半径原样传入")
	check(Selector.count_surface_violations(PackedVector2Array([Vector2.ZERO,Vector2(0.1,0),Vector2(0.2,0)]),func(_p): return false) == 4,"共享顶点按各段重复计数")
	# 人工有序候选只测试枚举合同，既不声称 Unity 原生顺序，也不沿用历史场景结果。
	cells = [Vector3i.ZERO,Vector3i(5,0,0),Vector3i(6,0,0),Vector3i(11,0,0)]
	routes.clear()
	queries.clear()
	routes[[Vector2.ZERO,Vector2(5,0)]] = [Vector2(2,0),Vector2(2,2)]
	routes[[Vector2.ZERO,Vector2(6,0)]] = [Vector2(1,0),Vector2(1,2)]
	routes[[Vector2(5,0),Vector2(11,0)]] = [Vector2(6,0),Vector2(6,2)]
	result = selector.find_fallback(0.32)
	check(result.route_source == "fallback:(0, 0, 0)->(6, 0, 0)","较短路线替换，同长路线保持第一个")
	check(result.full_route[-1] == Vector2(1,2),"原点击格标签与吸附后路径终点分离")
	check(not [Vector2.ZERO,Vector2(11,0)] in queries,"Manhattan 大于 10 不请求路径")
	check(not [Vector2(5,0),Vector2(6,0)] in queries,"Manhattan 小于 5 不请求路径")
	check([Vector2.ZERO,Vector2(5,0)] in queries,"Manhattan 5 包含")
	check(Selector.polyline_length(result.full_route) == 3.0,"长度 3 下限包含")
	cells = [Vector3i.ZERO,Vector3i(10,0,0)]
	routes.clear()
	routes[[Vector2.ZERO,Vector2(10,0)]] = [Vector2(6,0),Vector2(6,2)]
	check(not selector.find_fallback(0.32).is_empty(),"Manhattan 10 与长度 8 上限包含")
	routes[[Vector2.ZERO,Vector2(10,0)]] = [Vector2(6.1,0),Vector2(6.1,2)]
	check(selector.find_fallback(0.32).is_empty(),"长度超过 8 拒绝")
	routes[[Vector2.ZERO,Vector2(10,0)]] = [Vector2(0.5,0),Vector2(0.5,2)]
	check(selector.find_fallback(0.32).is_empty(),"长度低于 3 拒绝")
	var absent_surface = Selector.new(func(): return cells,center,route,func(_p): return false,func(_p,_r): return false)
	check(absent_surface.resolve(Vector2.ZERO,Vector2(10,0),0.32).is_empty(),"缺 surface 的优先和候选路线均失败")
	if failures == 0: print("PASS static_waypoint_route_selector ",checks," checks")
	quit(1 if failures else 0)
