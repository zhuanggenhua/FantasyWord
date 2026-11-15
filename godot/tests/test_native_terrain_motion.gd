extends SceneTree

const Terrain = preload("res://game_core/movement/terrain_cast.gd")
const Execution = preload("res://game_core/movement/motion_execution.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
var checks := 0
var failures := 0

class Host extends RefCounted:
	var position := Vector2.ZERO
	var requested: Array[Vector2] = []
	var collisions: Array = []
	var terrain: RefCounted
	func get_movement_position(): return position
	func request_move_position(value): requested.append(value)
	func cast_motion_hits(direction, distance): return terrain.cast_hits(position, direction, distance)
	func can_move(): return true
	func calculate_move_speed(): return 4.0
	func calculate_speed_multiplier(): return 1.0
	func clear_velocity(): pass
	func update_movement_animation(_value): pass
	func update_facing_from_intent(_value): pass
	func register_collision(value): collisions.append(value)

func _initialize() -> void:
	call_deferred("_run")

func _box(source_position: Vector2, size: Vector2, layer := 8, area := false) -> CollisionObject2D:
	var body: CollisionObject2D = Area2D.new() if area else StaticBody2D.new()
	body.position = Terrain.to_physics(source_position)
	body.collision_layer = layer
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	return body

func _capsule() -> CapsuleShape2D:
	# 原基础角色根身体竖向胶囊，独立 Hitbox 子节点不属于它。
	var capsule := CapsuleShape2D.new()
	capsule.radius = 0.39
	capsule.height = 0.86
	return capsule

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", label)

func _run() -> void:
	var first := _box(Vector2(1, 0.42), Vector2(0.1, 0.1))
	var second := _box(Vector2(2, 0.42), Vector2(0.1, 0.1))
	var embedded := _box(Vector2(0, 3.42), Vector2(0.1, 0.1))
	var trigger := _box(Vector2(1, 6.42), Vector2(0.1, 0.1), 8, true)
	var character := _box(Vector2(2, 6.42), Vector2(0.1, 0.1), 256)
	var self_body := _box(Vector2(0, 9.42), Vector2(0.1, 0.1))
	var duplicate_shape := CollisionShape2D.new()
	duplicate_shape.shape = first.get_child(0).shape
	first.add_child(duplicate_shape)
	var upwards := _box(Vector2(0, 13), Vector2(0.1, 0.1))
	# 斜向的终点接触墙角，X 轴试走畅通；保持相同速度而非重新归一化位移。
	var corner := _box(Vector2(0.38, 16.84), Vector2(0.08, 0.08))
	var crowded: Array[CollisionObject2D] = []
	for i in range(40):
		crowded.append(_box(Vector2(0.6 + i * 0.2, 20.42), Vector2(0.08, 0.08)))
	await physics_frame
	await physics_frame
	var terrain := Terrain.new(root.world_2d, _capsule(), Vector2(0, 0.42), 7752, [])
	var hits: Array = terrain.cast_hits(Vector2.ZERO, Vector2.RIGHT, 3.0)
	_check(hits.size() == 2 and hits.has(first) and hits.has(second), "终点之外的两个中途阻挡均保留身份，复合形状去重")
	_check(terrain.cast_hits(Vector2(0,3), Vector2.RIGHT, 3).has(embedded), "起点重叠不被运动扫掠漏掉")
	_check(terrain.cast_hits(Vector2(0,3), Vector2.ZERO, 0).has(embedded), "零运动检测重叠")
	hits = terrain.cast_hits(Vector2(0,6), Vector2.RIGHT, 3)
	_check(hits.is_empty() and not hits.has(trigger) and not hits.has(character), "触发器及 Character 不属于地形")
	var excluding := Terrain.new(root.world_2d, _capsule(), Vector2(0,0.42), 7752, [self_body.get_rid()])
	_check(excluding.cast_hits(Vector2(0,9), Vector2.RIGHT, 1).is_empty(), "同一身体明确排除")
	_check(terrain.cast_hits(Vector2(0,12), Vector2(0,1), 1).has(upwards), "Unity 正 Y 映射 Godot 负 Y")
	_check(terrain.cast_hits(Vector2.ZERO, Vector2(0.25,0), 3).size() == 2, "轴方向幅值不缩短前探距离")
	hits = terrain.cast_hits(Vector2(0,20), Vector2.RIGHT, 9)
	_check(hits.size() == 40, "超过单批32个命中继续查询而非截断")
	_check(crowded.all(func(body): return hits.has(body)), "多批保留每个身体身份")
	var host := Host.new()
	host.terrain = terrain
	host.position = Vector2(0,16)
	var filter := Filter.new(Filter.Mode.FREE, false, 0.05, 10.0, 10.0)
	var execution := Execution.new(host, filter)
	var order = execution.move_to(Vector2(1,17))
	execution.handle_movement(0.02)
	_check(host.collisions.has(corner), "执行器保留失败整向探测的真实碰撞对象")
	_check(host.requested.size() == 1, "整向阻挡后仍有轴向位移请求")
	if host.requested.size() == 1:
		_check(host.requested[0].is_equal_approx(Vector2(0.08 / sqrt(2),16)), "轴向回退不重新归一化位移")
	_check(order.state == Execution.Completion.PENDING, "轴向成功不把整条路径判失败")
	host.position = Vector2(0,3)
	host.requested.clear()
	order = execution.move_to(Vector2(3,3))
	execution.handle_movement(0.02)
	_check(host.requested.is_empty() and order.state == Execution.Completion.FAILED, "起点重叠阻挡不误发位移")
	_check(host.collisions.has(embedded), "起点阻挡身份进入执行器通知")
	print("PASS 原生地形查询及位移链：%d 项，失败 %d" % [checks, failures])
	quit(int(failures > 0))
