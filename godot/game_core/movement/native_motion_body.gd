extends AnimatableBody2D
## 正式角色显式注入身体形状和动作 owner；不创建角色、查找依赖或决定场景配置。
## 使用 Godot 4.7.2 原生同步：提交后仍读旧姿态，待物理步回写实际姿态。
## 已接推力和显式配置的脱墙，不替代完整 Movable 生命周期或独立传送接口。

const Terrain = preload("res://game_core/movement/terrain_cast.gd")
const Execution = preload("res://game_core/movement/motion_execution.gd")

@export var push_intensity_scale := 1.0
@export var push_resistance_scale := 1.0

var execution: RefCounted
var _terrain: RefCounted
var _motion_owner: Object
var _wall_recovery_distance := 0.0
var _wall_recovery_origin: Variant


func configure_movement(body_shape: CollisionShape2D, input_filter: RefCounted,
		motion_owner: Object, terrain_mask: int, wall_recovery_distance := 0.0) -> void:
	assert(execution == null, "角色身体只能初始化一次")
	assert(is_inside_tree() and sync_to_physics, "角色身体须进入场景并启用物理同步")
	assert(body_shape != null and body_shape.get_parent() == self and not body_shape.disabled,
		"角色身体缺少直属的启用碰撞形状")
	assert(get_shape_owners().size() == 1, "当前身体适配只接受一个附着形状")
	assert(body_shape.shape != null and body_shape.rotation == 0.0 and body_shape.skew == 0.0 and body_shape.scale == Vector2.ONE,
		"当前角色身体适配只接受未旋转、未缩放的形状")
	assert(global_transform.x == Vector2.RIGHT and global_transform.y == Vector2.DOWN,
		"当前角色物理世界采用原单位，身体不能旋转或缩放")
	assert(is_instance_valid(motion_owner) and input_filter != null, "缺少角色动作 owner 或过滤器")
	for method in ["can_move", "calculate_move_speed", "calculate_speed_multiplier",
			"update_movement_animation", "update_facing_from_intent", "register_collision"]:
		assert(motion_owner.has_method(method), "角色动作 owner 缺少方法：" + method)
	_motion_owner = motion_owner
	assert(is_finite(wall_recovery_distance) and wall_recovery_distance >= 0.0,"角色脱墙距离无效")
	_wall_recovery_distance = wall_recovery_distance
	_terrain = Terrain.new(get_world_2d(), body_shape.shape,
		Terrain.to_physics(body_shape.position), terrain_mask, [get_rid()])
	execution = Execution.new(self, input_filter)


func advance_movement(fixed_delta: float, ramp_direction: Callable = Callable()) -> void:
	# 角色 owner 在自身物理回调里先更新控制意图，再调用；此节点不另开重复调度。
	assert(execution != null and Engine.is_in_physics_frame(), "须先配置身体并在固定物理步推进移动")
	if _wall_recovery_distance > 0.0:
		_wall_recovery_origin = _terrain.wall_recovery_destination(get_movement_position(),
			_wall_recovery_distance, Execution.COLLISION_OFFSET)
		if _wall_recovery_origin is Vector2:
			request_move_position(_wall_recovery_origin)
	execution.handle_movement(fixed_delta, ramp_direction)
	execution.handle_push(fixed_delta) # 原 FixedUpdate 顺序：正常移动后才执行推力。
	_wall_recovery_origin = null


func has_active_movement_intent() -> bool:
	return execution != null and execution.has_active_movement_intent()


func get_movement_position() -> Vector2:
	# Unity 先改刚体位置再计算同一步移动；Godot 同步身体须等物理服回写。
	# 只在本次移动/推力内部使用已验证的脱墙点，不伪造场景节点已同步的姿态。
	if _wall_recovery_origin is Vector2: return _wall_recovery_origin
	return Terrain.to_physics(global_position)


func request_move_position(source_position: Vector2) -> void:
	assert(source_position.is_finite() and sync_to_physics, "角色位移请求无效或物理同步被关闭")
	global_position = Terrain.to_physics(source_position)


func cast_motion_hits(direction: Vector2, distance: float) -> Array:
	assert(_terrain != null, "角色身体未配置地形查询")
	return _terrain.cast_hits(get_movement_position(), direction, distance)

## 原 Movable.NearestValidDestination：无导航图的点击探测落点，不重定位身体。
## 原点可站或同半径内无空位时，保留原点交给既有直线移动和碰撞处理。
func nearest_valid_destination(source_point: Vector2) -> Vector2:
	assert(_terrain != null and source_point.is_finite(), "点击落点缺少有效坐标或地形查询")
	var candidate: Variant = _terrain.wall_recovery_destination(source_point,
		_wall_recovery_distance, Execution.COLLISION_OFFSET)
	return candidate if candidate is Vector2 else source_point


## Synced kinematic body state from the previous physics step, in Unity XY.
## Do not use input intent/last requested move: those may not have reached the body.
func get_movement_linear_velocity() -> Vector2:
	return Terrain.to_physics(PhysicsServer2D.body_get_state(get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY))


func clear_velocity() -> void:
	# 原 ResetMovement 清线速度；不擅自丢弃已提交目标或声称取消了同帧 MovePosition。
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)


func can_move() -> bool:
	return not execution.is_pushed() and _motion_owner.can_move()


func calculate_move_speed() -> float:
	return _motion_owner.calculate_move_speed()


func calculate_speed_multiplier() -> float:
	return _motion_owner.calculate_speed_multiplier()


func update_movement_animation(direction: Vector2) -> void:
	_motion_owner.update_movement_animation(direction)


func update_facing_from_intent(direction: Vector2) -> void:
	_motion_owner.update_facing_from_intent(direction)


func register_collision(body: Object) -> void:
	_motion_owner.register_collision(body)


func set_movement_direction(direction: Vector2) -> void:
	execution.set_movement_direction(direction)


func reset_movement() -> void:
	execution.reset_movement()


func move_to(destination: Vector2, stopping_distance: float = 0.1, speed_override: Variant = null):
	return execution.move_to(destination, stopping_distance, speed_override)


func move_along_path(route: PackedVector2Array, stopping_distance: float, speed_override: Variant = null):
	return execution.move_along_path(route, stopping_distance, speed_override)


func push_motion(direction: Vector2, intensity: float = 5.0, resistance: float = 10.0) -> void:
	execution.push_motion(direction, intensity, resistance, push_intensity_scale, push_resistance_scale)


func is_pushed() -> bool:
	return execution.is_pushed()


func interrupt_push() -> void:
	execution.interrupt_push()
