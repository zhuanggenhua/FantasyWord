extends RefCounted
## 显式运动 owner 接线，不提供 PlayerSystem/GAS，也不裁决瞄准/身体朝向。
## Movable.MotionRuntime → CharacterActor.UpdateMovementAnimation → 动作驱动；
## DirectionalSpriteLibraryDriver 单独监听 owner 身体朝向，不监听移动意图。
signal accepted_movement(value: Vector2)
var _owner: Object
var _view: Node2D
var last_error := ""
var _active := false

func configure(owner: Object, view: Node2D, activate_now := true) -> bool:
	if is_instance_valid(_owner): return _fail("已绑定，不能重复绑定。")
	if not is_instance_valid(owner) or not is_instance_valid(view): return _fail("缺少显式 owner 或已配置表现。")
	for method in ["can_move", "calculate_move_speed", "calculate_speed_multiplier", "update_facing_from_intent", "register_collision", "get_look_at_direction"]:
		if not owner.has_method(method): return _fail("owner 缺少 " + method)
	if not owner.has_signal("look_at_direction_changed"): return _fail("owner 缺少权威身体朝向通知。")
	if not view.has_method("set_movement") or not view.has_method("set_facing") or view.get("driver") == null or view.get("playback") == null:
		return _fail("Human 表现尚未配置。")
	var initial: Variant = owner.get_look_at_direction()
	if not initial is Vector2 or not initial.is_finite(): return _fail("初始身体朝向无效。")
	_owner=owner
	_view=view
	if activate_now: activate()
	return true

func activate() -> void:
	if _active or not is_instance_valid(_owner): return
	_active=true
	_owner.look_at_direction_changed.connect(_on_look_at_direction_changed)
	var current: Variant = _owner.get_look_at_direction()
	if current is Vector2 and current.is_finite(): _on_look_at_direction_changed(current)

func detach() -> void:
	if is_instance_valid(_owner) and _owner.look_at_direction_changed.is_connected(_on_look_at_direction_changed):
		_owner.look_at_direction_changed.disconnect(_on_look_at_direction_changed)
	_owner=null
	_view=null
	_active=false

func uses_owner(owner: Object) -> bool:
	return _active and is_instance_valid(owner) and owner == _owner

func can_move() -> bool:
	return is_instance_valid(_owner) and _owner.can_move()
func calculate_move_speed() -> float: return _owner.calculate_move_speed() if is_instance_valid(_owner) else 0.0
func calculate_speed_multiplier() -> float: return _owner.calculate_speed_multiplier() if is_instance_valid(_owner) else 0.0
func register_collision(body: Object) -> void:
	if is_instance_valid(_owner): _owner.register_collision(body)
func update_facing_from_intent(intent: Vector2) -> void:
	# owner 可以拒绝/保持朝向；绝不能由此直接改变纹理方向。
	if is_instance_valid(_owner): _owner.update_facing_from_intent(intent)
func update_movement_animation(accepted_velocity: Vector2) -> void:
	# 此值是执行器接受的 velocity，不是输入意图或物理回写位置差。
	# 原 CharacterActor 已选动作驱动时不同时调用 legacy 动画策略。
	if is_instance_valid(_view):
		_view.set_movement(accepted_velocity)
		accepted_movement.emit(accepted_velocity)
func _on_look_at_direction_changed(approved_direction: Vector2) -> void:
	if is_instance_valid(_view) and approved_direction.is_finite(): _view.set_facing(approved_direction)
func _fail(message: String) -> bool:
	last_error=message
	return false
