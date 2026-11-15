extends RefCounted
## 原 CatchAreaPolygon2D 的有界矩形子 Hitbox 查询。
## 使用真实物理粗筛、源多边形窄筛；只接受调用方显式登记的 RectangleShape2D。
## 不冒充 Circle/其他碰撞体、超过 64 候选时的跨引擎返回顺序或边界精度验收。

static func query(world: World2D, source_position: Vector2, facing: Vector2,
		local_points: PackedVector2Array, layer: int, source_owner: Object,
		resolve_owner: Callable) -> Array:
	if world == null or source_owner == null or facing.length_squared() <= 0.0001 or local_points.size() < 3:
		return []
	var points := PackedVector2Array()
	for point in local_points:
		var source_point := source_position + point.rotated(facing.angle())
		points.append(Vector2(source_point.x, -source_point.y))
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points: bounds = bounds.expand(point)
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(maxf(bounds.size.x, 0.01), maxf(bounds.size.y, 0.01))
	var parameters := PhysicsShapeQueryParameters2D.new()
	parameters.shape = rectangle
	parameters.transform = Transform2D(0.0, bounds.get_center())
	parameters.collision_mask = layer
	parameters.collide_with_bodies = true
	parameters.collide_with_areas = true
	var results: Array = []
	for hit in world.direct_space_state.intersect_shape(parameters, 64):
		var collider: CollisionObject2D = hit.collider
		var actor: Variant = resolve_owner.call(collider)
		if actor == null or actor == source_owner or results.has(actor): continue
		var shape_owner := collider.shape_find_owner(hit.shape)
		assert(collider.shape_owner_get_shape_count(shape_owner) == 1, "诊断要求每个子 Hitbox 形状 owner 仅含一个形状")
		var shape: Shape2D = collider.shape_owner_get_shape(shape_owner, 0)
		assert(shape is RectangleShape2D, "此有界迁移只接受矩形 Hitbox，不能用包围盒冒充其他形状")
		var transform := collider.global_transform * collider.shape_owner_get_transform(shape_owner)
		if _intersects(shape.size, transform, points): results.append(actor)
	return results

static func _intersects(size: Vector2, transform: Transform2D, polygon: PackedVector2Array) -> bool:
	var half := size * 0.5
	var corners := PackedVector2Array([transform * Vector2(-half.x,-half.y),
		transform * Vector2(-half.x,half.y), transform * half, transform * Vector2(half.x,-half.y)])
	for point in corners:
		if _inside(point, polygon): return true
	for point in polygon:
		var local := transform.affine_inverse() * point
		if absf(local.x) <= half.x and absf(local.y) <= half.y: return true
	for i in range(polygon.size()):
		for j in range(corners.size()):
			if _segments(polygon[i], polygon[(i+1)%polygon.size()], corners[j], corners[(j+1)%corners.size()]): return true
	return false

static func _inside(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var j := polygon.size()-1
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[j]
		if (a.y > point.y) != (b.y > point.y) and point.x < (b.x-a.x)*(point.y-a.y)/(b.y-a.y)+a.x:
			inside = not inside
		j = i
	return inside

static func _on(point: Vector2, a: Vector2, b: Vector2) -> bool:
	return point.x >= minf(a.x,b.x)-0.0001 and point.x <= maxf(a.x,b.x)+0.0001 \
		and point.y >= minf(a.y,b.y)-0.0001 and point.y <= maxf(a.y,b.y)+0.0001

static func _segments(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var e := (d-c).cross(a-c)
	var f := (d-c).cross(b-c)
	var g := (b-a).cross(c-a)
	var h := (b-a).cross(d-a)
	if ((e>0 and f<0) or (e<0 and f>0)) and ((g>0 and h<0) or (g<0 and h>0)): return true
	return (absf(e)<=0.0001 and _on(a,c,d)) or (absf(f)<=0.0001 and _on(b,c,d)) \
		or (absf(g)<=0.0001 and _on(c,a,b)) or (absf(h)<=0.0001 and _on(d,a,b))
