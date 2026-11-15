extends SceneTree
const WorldPath = preload("res://game_core/navigation/terrain_world_path.gd")
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
func center(node: Vector4i) -> Vector2:
	return Vector2(node.y + 0.5, node.z + 0.5)
func key(x: int, y: int) -> Vector4i:
	return Vector4i(0,x,y,0)
func _run() -> void:
	check(WorldPath.project_default([],{},center,Vector2.ZERO,false).is_empty(), "空路径")
	check(WorldPath.project_default([key(0,0)],{},center,Vector2(0.2,0.3),true) == PackedVector2Array([Vector2(0.2,0.3)]), "单格精确终点")
	check(WorldPath.project_default([key(0,0)],{},center,Vector2.ZERO,false) == PackedVector2Array([Vector2(0.5,0.5)]), "单格吸附终点")
	for direction in [Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
		var ramp: int = [Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)].find(direction) + 1
		var cells := [Vector3i(-direction.x,0,0),Vector3i.ZERO,Vector3i(0,direction.y,0),Vector3i(direction.x,direction.y,0),Vector3i(2*direction.x,direction.y,0)]
		var rows: Array = []
		var tiles: Dictionary = {}
		for i in range(cells.size()):
			var c: Vector3i = cells[i]
			var row := {"cell":[c.x,c.y,0],"walkable":true,"elevation":0 if i < 2 else 1,"transition":1 if i in [1,2,3] else 0,"ramp":ramp,"surface":1,"cost":1.0}
			rows.append(row)
			tiles[c] = row
		var graph = Map.new().build(rows)
		for reverse in [false,true]:
			var path = graph.find_path(key(cells[-1].x,cells[-1].y) if reverse else key(cells[0].x,cells[0].y),key(cells[0].x,cells[0].y) if reverse else key(cells[-1].x,cells[-1].y))
			check(path.size() == 5, "原 NW/NE 用例及 SE/SW 镜像图可达")
			var expected := PackedVector2Array()
			for i in range(1,path.size()): expected.append(center(path[i]))
			check(WorldPath.project_default(path,tiles,center,center(path[-1]),true) == expected,"坡道所有拐角保留，正反双向")
	var line := [key(0,0),key(1,0),key(2,0),key(3,0)]
	check(WorldPath.project_default(line,{},center,Vector2.ZERO,false) == PackedVector2Array([Vector2(3.5,0.5)]), "平地同向共线压缩，不含起点")
	check(WorldPath.project_default(line,{},center,Vector2(3.2,0.7),true) == PackedVector2Array([Vector2(2.5,0.5),Vector2(3.2,0.7)]), "精确终点覆盖后再压缩")
	var points: Array[Vector2] = [Vector2.ZERO,Vector2(1,0),Vector2(2,0),Vector2(3,0)]
	var markers: Array[bool] = [false,true,false,false]
	check(WorldPath.compress_points(points,markers) == PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2(3,0)]),"共线标记不丢")
	check(WorldPath.compress_points([Vector2.ZERO,Vector2(1,0),Vector2.ZERO],[false,false,false]).size() == 3,"折返不能压缩")
	check(WorldPath.compress_points([Vector2.ZERO,Vector2(1,0),Vector2(2,0.00009)],[false,false,false]).size() == 2,"叉积阈值内压缩")
	check(WorldPath.compress_points([Vector2.ZERO,Vector2(1,0),Vector2(2,0.00011)],[false,false,false]).size() == 3,"叉积阈值外保留")
	points = [Vector2.ZERO]
	markers = [false]
	WorldPath.append_point(points,markers,Vector2(0.0005,0),true)
	check(points.size() == 1 and points[0] == Vector2.ZERO and markers[0],"近重复点合并标记且保留原坐标")
	WorldPath.append_point(points,markers,Vector2(0.002,0),false)
	check(points.size() == 2,"超出合并阈值追加")
	# 更长阶梯中共线中间点也必须保留；起点自身不参加 ramp run。
	var stair := [key(-1,0),key(0,0),key(1,0),key(2,0),key(2,1),key(2,2),key(3,2)]
	var authored: Dictionary = {}
	for i in range(1,6): authored[Vector3i(stair[i].y,stair[i].z,0)] = {"transition":1,"ramp":1,"elevation":0 if i < 4 else 1}
	check(WorldPath.project_default(stair,authored,center,Vector2.ZERO,false).size() == 6,"对角端点坡段内共线节点仍保留")
	for cell in authored: authored[cell].elevation = 0
	check(WorldPath.project_default(stair,authored,center,Vector2.ZERO,false).size() == 3,"同高度坡段不产生保留标记")
	for cell in authored:
		authored[cell].elevation = 0 if cell.y == 0 else 1
		authored[cell].ramp = 2
	check(WorldPath.project_default(stair,authored,center,Vector2.ZERO,false).size() == 3,"端点斜向与作者坡向不符不产生标记")
	var straight_ramp := {Vector3i(1,0,0): {"transition":1,"ramp":1,"elevation":0}, Vector3i(2,0,0): {"transition":1,"ramp":1,"elevation":1}, Vector3i(3,0,0): {"transition":1,"ramp":1,"elevation":1}}
	check(WorldPath.project_default(line,straight_ramp,center,Vector2.ZERO,false).size() == 1,"仅单轴端点不算作者对角坡段")
	check(WorldPath.project_default([key(0,0),key(1,0)],{},func(_node): return Vector2.ZERO,Vector2(0.2,0.3),true) == PackedVector2Array([Vector2(0.2,0.3)]),"合并后仅剩一点仍正确去除起点并返回精确目标")
	print("PASS terrain_world_path ", checks, " checks" if failures == 0 else " FAILED")
	quit(1 if failures else 0)
