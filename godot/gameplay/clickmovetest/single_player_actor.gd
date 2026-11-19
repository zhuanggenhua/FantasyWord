extends RefCounted
## ClickMoveTest 原主玩家的单角色运行合同，锁定 31629d53。
## PlayerSystem 提供实体身份；CharacterPlayerControl 和 Movable 分别裁决控制与朝向。
## 不实例化 Actor、不接队伍/存档/ASC，不执行尚未迁移的玩家死亡行动。
const PlayerBody = preload("res://gameplay/clickmovetest/actor.gd")
const Direction = preload("res://game_core/presentation/movable_direction_state.gd")
const Attributes = preload("res://gameplay/clickmovetest/training_damage_attributes.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
const SOURCE_ACTOR := "735002000000000004"
const SOURCE_PREFAB := "f32187b1edab1484a99d97ef54021bf5"
const SOURCE_SHEET := "13245a7230bedbe4da633d5325872ce1"
const BASE_MOVE_SPEED := 4.0
const BASE_SPEED_MULTIPLIER := 1.0
# 原 0.05f * 0.05f；显式舍入避免脚本文字浮点解析在相等边界产生误差。
static var _movement_idle_squared: float = PackedFloat32Array([0.002500000176951289])[0]

signal controlled_character_changed(actor: Node2D)
signal player_input_disabled
signal look_at_direction_changed(value: Vector2)
signal target_direction_changed(value: Vector2)
signal accepted_movement(velocity: Vector2)
signal collision_reported(collider: Object)
signal provoked(source: Variant)
signal damage_prepared(source: Variant, input: Dictionary)
signal damage_completed(source: Variant, input: Dictionary, previous_health: int, applied: int)

var _primary: WeakRef
var _primary_exited := false
var _selected := false
var _accepts := true
var _directions := Direction.new()
var _attributes := Attributes.new()
var _read_pointer: Callable
var _refresh_interaction: Callable
var _reset_interaction: Callable
var _read_destroyed: Callable

func configure(actor: Node2D, pointer_reader: Callable = Callable(),
		refresh_interaction: Callable = Callable(), reset_interaction: Callable = Callable(),
		read_destroyed: Callable = Callable()) -> bool:
	if _primary != null or not is_instance_valid(actor) or not actor is PlayerBody or not actor.is_inside_tree():
		return false
	# 缺能力可以显式不安装；失效的非空引用不能冒充未安装。
	for callback: Callable in [pointer_reader,refresh_interaction,reset_interaction,read_destroyed]:
		if not callback.is_null() and not callback.is_valid(): return false
	# 玩家角色配置.asset m_baseStats：按 Stats.cs 的原顺序解码，未开启等级成长。
	if not _attributes.configure(PackedInt32Array([100,40,10,6,6,4,8,4,100]),
			Combat.Alignment.GOOD,_no_active_invincibility):
		return false
	_primary = weakref(actor)
	_read_pointer = pointer_reader
	_refresh_interaction = refresh_interaction
	_reset_interaction = reset_interaction
	_read_destroyed = read_destroyed
	_directions.look_at_direction_changed.connect(_on_look_changed)
	_directions.target_direction_changed.connect(_on_target_changed)
	actor.tree_exiting.connect(_on_actor_exiting,CONNECT_ONE_SHOT)
	# 原 PlayerSystem.OnSystemStart 把当前控制恢复为显式主角。
	_selected = true
	controlled_character_changed.emit(actor)
	return true

func get_player_provider() -> RefCounted: return self

func get_current_controlled_character_or_player_instance() -> Node2D:
	# 单角色切片只有主角可注册。失控时主角仍可作为相机的 fallback。
	return _get_primary()

func is_current_controlled(actor: Node2D) -> bool:
	return _selected and is_instance_valid(actor) and actor == _get_primary()

func set_current_controlled(selected: bool) -> bool:
	var actor := _get_primary()
	if not is_instance_valid(actor): return false
	if selected and not can_be_player_controlled(actor): return false
	if _selected == selected and not selected: return true
	_selected = selected
	controlled_character_changed.emit(actor if selected else null)
	return true

func accepts_player_input(actor: Node2D) -> bool:
	return _accepts and is_instance_valid(actor) and actor == _get_primary()

func set_accepts_player_input(accepts: bool) -> void:
	_accepts = accepts
	# CharacterPlayerControl.SetAcceptsPlayerInput(false) 立即清理；Entry 已有正式重置入口。
	if not accepts: player_input_disabled.emit()

func can_be_player_controlled(actor: Node2D) -> bool:
	# 当前没有未迁移的 Alteration 运行时，不能把这个切片当成一般控制组。
	return is_instance_valid(actor) and actor == _get_primary() and current_health() > 0

func refresh_interaction_target(actor: Node2D) -> void:
	if is_current_controlled(actor) and _refresh_interaction.is_valid(): _refresh_interaction.call(actor)

func reset_interaction_target(actor: Node2D) -> void:
	if is_instance_valid(actor) and actor == _get_primary() and _reset_interaction.is_valid():
		_reset_interaction.call(actor)

func read_active_gameplay_pointer() -> Variant:
	var actor := _get_primary()
	if not accepts_player_input(actor) or not is_current_controlled(actor) or not _read_pointer.is_valid():
		return null
	return _read_pointer.call()

func can_move() -> bool: return is_instance_valid(_get_primary()) and not is_destroyed()
func calculate_move_speed() -> float: return BASE_MOVE_SPEED
func calculate_speed_multiplier() -> float: return BASE_SPEED_MULTIPLIER
func can_update_target_direction() -> bool: return is_instance_valid(_get_primary()) and not is_destroyed()
func can_interact() -> bool: return is_instance_valid(_get_primary()) and not is_destroyed()

func update_facing_from_intent(value: Vector2) -> void:
	# 原 MovementBased：用原方向阈值，速度和指针目标不会替代身体朝向。
	if value.length_squared() > _movement_idle_squared:
		set_look_at_direction(value.normalized())

func set_look_at_direction(value: Vector2) -> void: _directions.set_look_at_direction(value)
func get_look_at_direction() -> Vector2: return _directions.get_look_at_direction()
func set_target_direction(value: Vector2) -> void: _directions.set_target_direction(value,can_update_target_direction())
func get_target_direction() -> Vector2: return _directions.get_target_direction()
func reset_target_direction() -> void: _directions.reset_target_direction()
func update_movement_animation(velocity: Vector2) -> void: accepted_movement.emit(velocity)
func register_collision(collider: Object) -> void: collision_reported.emit(collider)
func stats() -> Dictionary: return _attributes.stats()
func current_health() -> int: return _attributes.current_health()

func is_destroyed() -> bool:
	# HP 归零是源 dead，真正销毁须等待外部安全死亡所有者。
	return not _read_destroyed.is_null() and (not _read_destroyed.is_valid() or bool(_read_destroyed.call()))

func damage_hooks() -> Dictionary:
	return {"provoke":_on_provoked,"has_formal_stats":_attributes.has_formal_stats,
		"current_health":_attributes.current_health,"prepare":_on_damage_prepared,
		"apply_current_health_delta":_attributes.apply_current_health_delta,"complete":_on_damage_completed}

func _get_primary() -> Node2D:
	if _primary_exited: return null
	var actor: Node2D = _primary.get_ref() if _primary != null else null
	return actor if is_instance_valid(actor) and actor.is_inside_tree() else null

func _on_actor_exiting() -> void:
	var was_selected := _selected
	_primary_exited = true
	_selected = false
	if was_selected: controlled_character_changed.emit(null)

func _on_look_changed(value: Vector2) -> void: look_at_direction_changed.emit(value)
func _on_target_changed(value: Vector2) -> void: target_direction_changed.emit(value)
func _on_provoked(source: Variant) -> void: provoked.emit(source)
func _on_damage_prepared(source: Variant, input: Dictionary) -> void: damage_prepared.emit(source,input)
func _on_damage_completed(source: Variant, input: Dictionary, previous: int, applied: int) -> void:
	damage_completed.emit(source,input,previous,applied)

static func _no_active_invincibility() -> bool: return false
