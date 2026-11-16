extends RefCounted
## CatchAreaBox2D 的局部朝向查询切片：当前朝向旋转 offset 和 box，Unity Y 上转 Godot Y 下。
## 原 64 项上限；显式 owner 去重。仅验收无缩放矩形子命中框，不声称跨引擎边界精度一致。
static func query(world: World2D, source_position: Vector2, facing: Vector2,
		offset: Vector2, size: Vector2, rotation_degrees: float, layer: int,
		source_owner: Object, resolve_owner: Callable) -> Array:
	if world == null or source_owner == null or facing.length_squared() <= 0.0001: return []
	var center := source_position + offset.rotated(facing.angle())
	var shape := RectangleShape2D.new()
	shape.size = size
	var parameters := PhysicsShapeQueryParameters2D.new()
	parameters.shape = shape
	parameters.transform = Transform2D(-facing.angle()-deg_to_rad(rotation_degrees),Vector2(center.x,-center.y))
	parameters.collision_mask = layer
	parameters.collide_with_bodies = true
	parameters.collide_with_areas = true
	parameters.margin = 0.0
	var targets: Array = []
	for hit in world.direct_space_state.intersect_shape(parameters,64):
		var owner: Variant = resolve_owner.call(hit.collider)
		if owner != null and owner != source_owner and not targets.has(owner): targets.append(owner)
	return targets
