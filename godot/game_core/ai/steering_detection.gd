extends RefCounted
## Locked SteeringDetectionScheduler2D input adapter. Public coordinates: Unity XY.
## Limited to a single rectangle or uniformly scaled circle per collision object.
const OBSTACLE_MASK := 7752
const CHARACTER_MASK := 256

static func _unity(v: Vector2) -> Vector2:
	return Vector2(v.x, -v.y)

static func closest_point(collider: CollisionObject2D, origin: Vector2) -> Dictionary:
	var enabled: Array = []
	for owner in collider.get_shape_owners():
		if collider.is_shape_owner_disabled(owner): continue
		for index in collider.shape_owner_get_shape_count(owner):
			enabled.append([owner,index])
	if enabled.size() != 1: return {"ok":false,"error":"unsupported_shape_count"}
	var owner: int = enabled[0][0]
	var shape: Shape2D = collider.shape_owner_get_shape(owner,enabled[0][1])
	var transform: Transform2D = collider.global_transform * collider.shape_owner_get_transform(owner)
	var sx := transform.x.length()
	var sy := transform.y.length()
	if sx <= 0.000001 or sy <= 0.000001 or absf(transform.x.normalized().dot(transform.y.normalized())) > 0.00001:
		return {"ok":false,"error":"unsupported_shape_transform"}
	var point := transform.affine_inverse() * _unity(origin)
	var nearest: Vector2
	if shape is RectangleShape2D:
		nearest = point.clamp(-shape.size * 0.5, shape.size * 0.5)
	elif shape is CircleShape2D:
		if absf(sx-sy) > 0.00001: return {"ok":false,"error":"unsupported_circle_scale"}
		nearest = point.limit_length(shape.radius)
	else:
		return {"ok":false,"error":"unsupported_shape_type"}
	return {"ok":true,"position":_unity(transform * nearest)}

static func collect_neighbours(origin: Vector2, own_body: CollisionObject2D, registry: Array,
		radius: float, cell_size: float) -> Array:
	var result: Array = []
	if radius <= 0.0: return result
	var size := maxf(cell_size,0.01)
	# AgentSpatialIndex2D traverses cells Y then X; registration order within cell.
	for y in range(int(floor((origin.y-radius)/size)),int(floor((origin.y+radius)/size))+1):
		for x in range(int(floor((origin.x-radius)/size)),int(floor((origin.x+radius)/size))+1):
			for entry: Dictionary in registry:
				var body: CollisionObject2D = entry.body
				if not is_instance_valid(body) or body == own_body or not entry.get("active",true): continue
				if not (body.collision_layer & CHARACTER_MASK): continue
				var position := _unity(body.global_position)
				if int(floor(position.x/size)) != x or int(floor(position.y/size)) != y: continue
				if position.distance_squared_to(origin) > radius * radius: continue
				result.append({"agent_id":entry.agent_id,"position":position,"radius":entry.radius,
					"velocity":entry.velocity,"mass":entry.mass,"priority":entry.priority})
	return result

static func build_frame(world: World2D, origin: Vector2, own_body: CollisionObject2D,
		registry: Array, obstacle_radius: float, semantic_radius: float,
		neighbour_radius: float, cell_size: float, capacity: int = 64) -> Dictionary:
	var neighbours := collect_neighbours(origin,own_body,registry,neighbour_radius,cell_size)
	var result := {"ok":true,"obstacles":[],"neighbours":neighbours,"detected_colliders":[]}
	var radius := maxf(obstacle_radius,semantic_radius)
	if radius <= 0.0: return result
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0,_unity(origin))
	query.collision_mask = OBSTACLE_MASK | CHARACTER_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false # Locked AI controller's three filters disable triggers.
	query.margin = 0.0
	var limit := maxi(capacity,8)
	var hits := world.direct_space_state.intersect_shape(query,limit)
	if hits.size() >= limit: return {"ok":false,"error":"detection_buffer_full"}
	var registered: Dictionary = {}
	for entry: Dictionary in registry:
		for collider in entry.colliders: registered[collider] = true
	for hit: Dictionary in hits:
		var collider: CollisionObject2D = hit.collider
		if collider == own_body: continue
		if semantic_radius > 0.0 and collider.collision_layer & CHARACTER_MASK:
			result.detected_colliders.append(collider)
		if registered.has(collider): continue
		if obstacle_radius <= 0.0 or not (collider.collision_layer & OBSTACLE_MASK): continue
		var closest := closest_point(collider,origin)
		if not closest.ok: return closest # No fabricated obstacle center or silently missing shape.
		result.obstacles.append({"point":closest.position,"radius":0.0,"is_static":collider is StaticBody2D and not collider is AnimatableBody2D})
	return result
