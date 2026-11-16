extends RefCounted
## Source AIController.CanSee/FindTarget + semantic slice of steering detection.
## All public positions use Unity XY; Godot physics receives reflected Y.
const Rules = preload("res://game_core/combat/combat_rules.gd")
const VISIBILITY_MASK := 3144
const COLLISION_MASK := 7752
const CHARACTER_MASK := 256
const STATE_META := &"fantasyword_character_state"
# 每个观察者使用自己的实例，目标关系不得写回共享角色状态。
var _observations: Dictionary = {}

static func can_see(world: World2D, origin: Vector2, target: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(Vector2(origin.x,-origin.y), Vector2(target.x,-target.y), VISIBILITY_MASK)
	# CanSee passes ONLY layerMask, not the ContactFilter. The locked project's
	# global queriesHitTriggers/queriesStartInColliders are both true.
	ray.collide_with_bodies = true
	ray.collide_with_areas = true
	ray.hit_from_inside = true
	return world.direct_space_state.intersect_ray(ray).is_empty()

static func character_parent(collider: Node) -> Node2D:
	var current: Node = collider
	while current != null:
		if current is Node2D and current.has_meta(STATE_META): return current
		current = current.get_parent()
	return null

func refresh_observation(world: World2D, observer: Dictionary, origin: Vector2, actor: Node2D) -> Dictionary:
	# Preserve the dictionary identity held by the target lifecycle, including
	# when a tracked actor has left the overlap radius. Never cache visibility.
	var actor_id := actor.get_instance_id()
	if not _observations.has(actor_id): _observations[actor_id] = {}
	var state: Dictionary = _observations[actor_id]
	state.merge(actor.get_meta(STATE_META),true)
	state.position = Vector2(actor.global_position.x,-actor.global_position.y)
	state.hostile = Rules.is_hostile_towards(observer,state)
	state.judicious = Rules.is_judicious_target(observer,state)
	state.visible = can_see(world,origin,state.position)
	return state

func observe_ordered(world: World2D, observer: Dictionary, origin: Vector2, colliders: Array) -> Array:
	var result: Array = []
	for collider in colliders:
		if not is_instance_valid(collider): continue
		var actor := character_parent(collider)
		if actor != null: result.append(refresh_observation(world,observer,origin,actor))
	# Source keeps repeated colliders and their order, not a nearest/distance sort.
	return result

static func detect(world: World2D, origin: Vector2, attached_body: CollisionObject2D,
		semantic_radius: float, obstacle_probe_radius: float, capacity: int) -> Dictionary:
	var radius := maxf(semantic_radius,obstacle_probe_radius)
	if radius <= 0.0: return {"ok":true,"colliders":[]}
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0,Vector2(origin.x,-origin.y))
	query.collision_mask = COLLISION_MASK | CHARACTER_MASK
	query.collide_with_areas = false # all three source union filters disable triggers
	query.collide_with_bodies = true
	query.margin = 0.0
	var limit := maxi(capacity,8)
	var hits := world.direct_space_state.intersect_shape(query,limit)
	# Same fail-closed capacity condition, BEFORE own-body/semantic filtering.
	if hits.size() >= limit: return {"ok":false,"error":"detection_buffer_full","colliders":[]}
	var detected: Array = []
	for hit in hits:
		var collider: CollisionObject2D = hit.collider
		if collider == attached_body: continue
		if semantic_radius > 0.0 and collider.collision_layer & CHARACTER_MASK:
			detected.append(collider)
	return {"ok":true,"colliders":detected}
