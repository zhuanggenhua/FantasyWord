extends RefCounted
## 对应 CharacterCommandExecutor.CreateAbilityActivationContext/ResolveAbilityAimDirection。
const Context = preload("res://game_core/interaction/ability_activation_context.gd")

## 所有坐标、方向均为 Unity 原坐标（Y 向上）；Cell 与几何位置由原目标的独立宿主适配提供。
static func build(request: Dictionary, root: Vector3, current_direction: Callable,
		target_root: Callable, target_cell: Callable) -> RefCounted:
	var target: Object = request.get("target_character")
	var cell: Object = target_cell.call(target) if is_instance_valid(target) else null
	var direction: Vector2 = request.get("direction",Vector2.ZERO)
	var epsilon: float = PackedFloat32Array([0.0001])[0]
	if not (Context.source_sqr_magnitude(Vector3(direction.x,direction.y,0)) > epsilon) and is_instance_valid(target):
		var position: Vector3 = target_root.call(target)
		direction = Vector2(position.x-root.x,position.y-root.y)
	if not (Context.source_sqr_magnitude(Vector3(direction.x,direction.y,0)) > epsilon) and request.get("world_position") is Vector2:
		direction = request.world_position - Vector2(root.x,root.y)
	if not (Context.source_sqr_magnitude(Vector3(direction.x,direction.y,0)) > epsilon):
		direction = current_direction.call()
	if Context.source_sqr_magnitude(Vector3(direction.x,direction.y,0)) > epsilon:
		direction = direction.normalized()
		if Context.source_sqr_magnitude(Vector3(direction.x,direction.y,0)) > epsilon:
			return Context.new(root,cell,Vector3(direction.x,direction.y,0))
	return Context.new(root,cell)
