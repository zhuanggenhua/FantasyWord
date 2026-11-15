extends RefCounted
## Static validation-only shapes; direct-space queries, not gameplay collision ownership.
## The isolated world contains only the locked scene's admitted, static Default bodies.

const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"


static func _point(values: Array) -> Vector2:
	assert(values.size() == 2 and is_finite(float(values[0])) and is_finite(float(values[1])))
	return Vector2(values[0], -values[1])


static func load_into(parent: Node, fixture: Dictionary) -> int:
	assert(fixture.get("schema") == 1 and fixture.get("source_commit") == SOURCE
		and fixture.get("scene") == "Assets/Scenes/ClickMoveTest.unity")
	var rows: Array = fixture.bodies
	assert(rows.size() == 35, "锁定静态形状数不符")
	var seen: Dictionary = {}
	for row in rows:
		assert(row.layer == 0 and not seen.has(row.source_file_id), "锁定碰撞层或对象身份不符")
		seen[row.source_file_id] = true
		var body := StaticBody2D.new()
		body.position = _point(row.origin)
		body.collision_layer = 1 << int(row.layer)
		body.collision_mask = 0 # Isolation: test owns overlaps; no live contact simulation.
		body.set_meta("source_file_id", int(row.source_file_id))
		var collider := CollisionShape2D.new()
		if row.kind == "box":
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(row.size[0], row.size[1])
			collider.shape = rectangle
		else:
			assert(row.kind == "outlines")
			var segments := PackedVector2Array()
			for loop in row.paths:
				assert(loop.size() >= 3)
				for i in range(loop.size()):
					segments.append(_point(loop[i]))
					segments.append(_point(loop[(i + 1) % loop.size()]))
			var outlines := ConcavePolygonShape2D.new()
			outlines.segments = segments
			collider.shape = outlines
		body.add_child(collider)
		parent.add_child(body)
	return seen.size()


static func has_blocking_circle(world: World2D, source_point: Vector2, radius: float,
		mask: int = 1) -> bool:
	assert(world != null and source_point.is_finite() and is_finite(radius) and radius > 0.0)
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, Vector2(source_point.x, -source_point.y))
	query.collision_mask = mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not world.direct_space_state.intersect_shape(query, 1).is_empty()
