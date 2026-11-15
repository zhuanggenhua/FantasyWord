extends RefCounted
## 单个凸形状的地形探测边界；宿主显式提供正式身体形状、偏移、掩码和排除项。
## 输入仍为 Unity 世界单位、Y 向上；物理世界采用同单位、Y 向下，不含像素倍率。
## 只返回命中身体身份，不提供 Unity 命中法线/距离排序，也不移动角色。

var _world: World2D
var _shape: Shape2D
var _offset: Vector2
var _mask: int
var _exclude: Array[RID]


func _init(world: World2D, shape: Shape2D, source_offset: Vector2,
		terrain_mask: int, self_bodies: Array[RID]) -> void:
	assert(world != null and shape != null, "地形探测缺少物理世界或角色身体形状")
	assert(shape is CapsuleShape2D or shape is CircleShape2D or shape is RectangleShape2D,
		"当前地形适配仅验证圆、胶囊及矩形；其他形状需先验证")
	_world = world
	_shape = shape
	_offset = to_physics(source_offset)
	_mask = terrain_mask
	_exclude = self_bodies.duplicate()


static func to_physics(source_vector: Vector2) -> Vector2:
	return Vector2(source_vector.x, -source_vector.y)


func cast_hits(source_position: Vector2, source_direction: Vector2, distance: float) -> Array:
	assert(source_position.is_finite() and source_direction.is_finite()
		and is_finite(distance) and distance >= 0.0, "地形探测坐标或距离无效")
	var state := _world.direct_space_state
	assert(state != null, "地形探测必须在可访问的物理世界调用")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, to_physics(source_position) + _offset)
	query.collision_mask = _mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.margin = 0.0
	query.exclude = _exclude.duplicate()
	# 固定的 GodotPhysics2D 4.7.2 intersect_shape 会将 motion 送入形状求交，
	# 同时覆盖起点重叠与扫掠中途命中；不是仅在终点做静态重叠。
	query.motion = to_physics(source_direction.normalized()) * distance
	var hits: Array = []
	while true:
		var contacts := state.intersect_shape(query, 32)
		if contacts.is_empty():
			return hits
		var previous_count := hits.size()
		var exclusions := query.exclude
		for contact in contacts:
			var rid: RID = contact.rid
			if exclusions.has(rid):
				continue # 同一刚体的多个形状只报告一次。
			exclusions.append(rid)
			if contact.collider == null:
				push_error("地形命中没有节点身份，当前宿主不支持纯 RID 身体")
				assert(false, "地形命中身体已失效或未绑定节点")
				return hits
			hits.append(contact.collider)
		if hits.size() == previous_count:
			push_error("地形查询未能排除命中身体，停止当前动作")
			assert(false, "地形查询不满足已验证的身份排除合同")
			return hits # 仅保留已验证身份；不冒充一般错误恢复或正式宿主终止协议。
		query.exclude = exclusions
	return hits
