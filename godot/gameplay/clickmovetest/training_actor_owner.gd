extends RefCounted
## 锁定 31629d53 中 ClickMoveTest 唯一启用的 735002000000000003。
## 只负责该角色的 Movable 朝向和受击事件端口；身体、属性、AI 与安全结算仍属于 TrainingTarget。
const Target = preload("res://gameplay/clickmovetest/training_target.gd")
const Direction = preload("res://game_core/presentation/movable_direction_state.gd")
const SOURCE_INSTANCE := "735002000000000003"
const SOURCE_SHEET := "163f3276394fbf347b2f1f48fcc5b45e"
const SOURCE_MOVE_SPEED := 4.0
const SOURCE_MOVE_GAIN := 1.0
static var _idle_squared: float = PackedFloat32Array([0.002500000176951289])[0]

signal look_at_direction_changed(value: Vector2)
signal target_direction_changed(value: Vector2)
signal accepted_movement(value: Vector2)
signal collision_reported(collider: Object)
signal damage_prepared(source: Variant, input: Dictionary)
signal damage_completed(source: Variant, input: Dictionary, previous_health: int, applied: int)
signal action_interrupted
signal death_committed

var _direction := Direction.new()
var _target: WeakRef
var _dead := false

func _init() -> void:
	_direction.look_at_direction_changed.connect(look_at_direction_changed.emit)
	_direction.target_direction_changed.connect(target_direction_changed.emit)

func bind_target(target: Node2D) -> bool:
	if _target != null or not is_instance_valid(target) or not target is Target \
			or not target.is_inside_tree() or not target.uses_movement_owner(self):
		return false
	_target = weakref(target)
	return true

func _is_live() -> bool:
	if _target == null or _dead: return false
	var target: Node2D = _target.get_ref()
	return is_instance_valid(target) and target.is_inside_tree()

func can_move() -> bool: return _is_live()
func calculate_move_speed() -> float: return SOURCE_MOVE_SPEED
func calculate_speed_multiplier() -> float: return SOURCE_MOVE_GAIN

func update_facing_from_intent(value: Vector2) -> void:
	# 只有本体 MovementBased 输入使用此阈值；AI 安全转向由 AIController 显式提交。
	if _is_live() and value.length_squared()>_idle_squared:
		set_look_at_direction(value.normalized())

func set_look_at_direction(value: Vector2) -> void: _direction.set_look_at_direction(value)
func get_look_at_direction() -> Vector2: return _direction.get_look_at_direction()
func set_target_direction(value: Vector2) -> void: _direction.set_target_direction(value,_is_live())
func get_target_direction() -> Vector2: return _direction.get_target_direction()
func update_movement_animation(value: Vector2) -> void: accepted_movement.emit(value)
func register_collision(collider: Object) -> void: collision_reported.emit(collider)

func hooks() -> Dictionary:
	return {"is_invincible":_no_invincibility,"is_destroyed":_is_destroyed,
		"provoke":_provoke,"prepare":damage_prepared.emit,"complete":damage_completed.emit,
		"interrupt_actions":action_interrupted.emit,"mark_death":_mark_death}

func _mark_death() -> void:
	# TrainingTarget 已按原顺序停控制器、清移动、开始已绑定的死亡动作。
	if _dead: return
	_dead = true
	death_committed.emit()

func _is_destroyed() -> bool: return _dead
static func _no_invincibility() -> bool: return false
static func _provoke(_source: Variant) -> void:
	# 真实来源和仇恨归 TrainingTarget.formal_provoked；这里不能拿属性快照再挑衅一次。
	pass
