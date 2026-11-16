extends RefCounted
## Movable.SetLookAtDirection/SetTargetDirection/ResetTargetDirection at 31629d5.
## Owner evaluates CanUpdateTargetDirection; this object owns only direction state.
signal look_at_direction_changed(value: Vector2)
signal target_direction_changed(value: Vector2)
var target_based := false
var _look := Vector2.ZERO
var _override: Variant = null

func get_look_at_direction() -> Vector2: return _look
func get_target_direction() -> Vector2: return _look if _override == null else _override

func set_look_at_direction(direction: Vector2) -> void:
	if direction.length() <= 0.0 or (direction-_look).length_squared() < 0.00001*0.00001: return
	if _override == null: target_direction_changed.emit(direction)
	_look = direction
	look_at_direction_changed.emit(direction)

func set_target_direction(direction: Vector2, can_update: bool) -> void:
	if not can_update: return
	_override = direction
	target_direction_changed.emit(direction)
	if target_based: set_look_at_direction(direction)

func reset_target_direction() -> void:
	if _override == null: return
	_override = null
	if _look.length_squared() > PackedFloat32Array([0.0001])[0]:
		target_direction_changed.emit(_look)
