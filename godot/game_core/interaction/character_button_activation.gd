extends RefCounted
## 31629d5 CharacterButtonActivation；坐标输入采用 Unity 平面，原生查询采用 Godot 平面。
## 显式登记将一个 Unity Collider2D 对应到一个 CollisionObject2D，避免猜测节点身份。
const INTERACTION_MASK := 64
var character: Object
var pivot: Node2D
var current_target: Node2D
var interacted_this_frame := false
var _colliders: Dictionary = {}
var _receivers: Dictionary = {}
var _audio: Callable

func configure(owner: Object, source_pivot: Node2D, audio_request: Callable) -> bool:
	if character != null or not is_instance_valid(owner) or not is_instance_valid(source_pivot): return false
	for method in ["can_interact", "get_target_direction"]:
		if not owner.has_method(method): return false
	if not audio_request.is_valid(): return false
	character = owner
	pivot = source_pivot
	_audio = audio_request
	return true

## offset 是原 Collider2D.offset 原值，不乘缩放、不旋转。原生形状变换由碰撞节点承载。
func register_collider(collider: CollisionObject2D, target: Node2D, source_offset: Vector2) -> bool:
	if not is_instance_valid(collider) or not is_instance_valid(target): return false
	_colliders[collider] = {"target": target, "offset": source_offset}
	return true

## 宿主按原 GameObject 的组件顺序登记；active_in_hierarchy 对应 Unity activeInHierarchy。
func register_receivers(target: Node2D, components: Array, active_in_hierarchy: Callable) -> bool:
	if not is_instance_valid(target) or not active_in_hierarchy.is_valid(): return false
	for receiver in components:
		if not is_instance_valid(receiver) or not receiver.has_method("on_interact"): return false
	_receivers[target] = {"components": components.duplicate(), "active": active_in_hierarchy}
	return true

func reset_state() -> void:
	interacted_this_frame = false
	current_target = null

func refresh_current_target() -> void:
	interacted_this_frame = false
	current_target = resolve_target()

func resolve_target(explicit_target: Node2D = null) -> Node2D:
	if is_instance_valid(explicit_target): return explicit_target
	if not is_instance_valid(character) or not character.can_interact() or not is_instance_valid(pivot) or not pivot.is_inside_tree(): return null
	var circle := CircleShape2D.new()
	circle.radius = 0.75
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0, pivot.global_position)
	query.collision_mask = INTERACTION_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var space := pivot.get_world_2d().direct_space_state
	# OverlapCircleAll 不应被 Godot 默认的 32 条结果上限截断。
	var limit := 32
	var hits := space.intersect_shape(query, limit)
	while hits.size() == limit:
		limit *= 2
		hits = space.intersect_shape(query, limit)
	var candidates: Array = []
	var seen: Dictionary = {}
	for hit in hits:
		var collider: Object = hit.collider
		if seen.has(collider): continue
		seen[collider] = true
		if not _colliders.has(collider):
			push_error("Interaction 层碰撞体未登记 Unity 身份，拒绝不完整解析")
			return null
		var item: Dictionary = _colliders[collider]
		if is_instance_valid(item.target): candidates.append(item)
	var origin := Vector2(pivot.global_position.x, -pivot.global_position.y)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.target.global_position.distance_squared_to(pivot.global_position) < b.target.global_position.distance_squared_to(pivot.global_position))
	for item in candidates:
		var position: Vector2 = item.target.global_position
		var offset: Vector2 = Vector2(position.x,-position.y) + item.offset - origin
		var direction: Vector2 = character.get_target_direction()
		if direction.dot(offset) > 0: return item.target
	return null

func try_interact(explicit_target: Node2D = null) -> bool:
	var resolved_target := resolve_target(explicit_target)
	if not is_instance_valid(resolved_target): return false
	var dispatched := false
	var node: Node = resolved_target
	# 收集后派发，避免接收者修改登记表时影响本轮组件快照。
	var callbacks: Array = []
	while node != null:
		if _receivers.has(node):
			var entry: Dictionary = _receivers[node]
			if node == resolved_target or entry.active.call(): callbacks.append_array(entry.components)
		node = node.get_parent()
	for receiver in callbacks:
		if is_instance_valid(receiver):
			receiver.on_interact(character)
			dispatched = true
	if dispatched:
		interacted_this_frame = true
		_audio.call()
	return dispatched

## 原 TryGetCurrentTargetPosition；无目标返回 null，不返回碰撞形状中心。
func get_current_target_position() -> Variant:
	if not is_instance_valid(current_target): return null
	return Vector2(current_target.global_position.x,-current_target.global_position.y)
