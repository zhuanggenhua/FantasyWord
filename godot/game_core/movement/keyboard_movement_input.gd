extends RefCounted
## Original Gameplay/Move: two normalized keyboard composites plus local device 0.
## Command coordinates retain Unity's positive Y up.
const Commands = preload("res://game_core/movement/movement_commands.gd")
const GROUPS = [[KEY_W, KEY_S, KEY_A, KEY_D], [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]]
const STICK := 2
const DEADZONE_MIN := 0.125
const DEADZONE_MAX := 0.925
const UNITY_NORMALIZATION_EPSILON := 0.00001
# Original initial-state check considers the stick first, then WASD, then arrows.
const BINDING_ORDER := [STICK, 0, 1]
var _held: Dictionary = {}
var _toggle_held: Dictionary = {}
var _raw_stick := Vector2.ZERO
var _active_group := -1
var _direction := Vector2.ZERO

func get_direction() -> Vector2:
	return _direction

func handle_key(event: InputEventKey, blocked: bool, submit: Callable) -> Variant:
	return observe_move(event,true,blocked,submit)

func observe_move(event: InputEvent, gameplay: bool, blocked := false, submit: Callable = Callable()) -> Variant:
	var changed_group := -1
	if event is InputEventKey and not event.echo:
		for index in range(GROUPS.size()):
			if event.physical_keycode in GROUPS[index]:
				changed_group = index
				break
		if changed_group < 0 or bool(_held.get(event.physical_keycode,false)) == event.pressed: return null
		_held[event.physical_keycode] = event.pressed
	elif event is InputEventJoypadMotion and event.device == 0 and is_finite(event.axis_value):
		var before := _raw_stick
		match event.axis:
			JOY_AXIS_LEFT_X: _raw_stick.x = clampf(event.axis_value,-1.0,1.0)
			JOY_AXIS_LEFT_Y: _raw_stick.y = -clampf(event.axis_value,-1.0,1.0)
			_: return null
		if _raw_stick == before: return null
		changed_group = STICK
	else:
		return null
	if not gameplay: return null
	return _update_action(changed_group,blocked,submit)

func observe_toggle(event: InputEvent, gameplay: bool, submit: Callable = Callable()) -> void:
	var token := ""
	if event is InputEventKey and event.physical_keycode == KEY_TAB: token = "tab"
	elif event is InputEventJoypadButton and event.device == 0 and event.button_index == JOY_BUTTON_RIGHT_STICK: token = "right_stick"
	if token.is_empty() or event.is_echo(): return
	if not event.is_pressed():
		_toggle_held.erase(token)
	elif not _toggle_held.has(token):
		var first := _toggle_held.is_empty()
		_toggle_held[token] = true
		if gameplay and first: Commands.on_toggle_performed(submit)

func sample_enabled_action(blocked: bool, submit: Callable) -> Variant:
	if _active_group >= 0: return null
	return _update_action(-1,blocked,submit)

func _update_action(changed_group: int, blocked: bool, submit: Callable) -> Variant:
	var prior := _active_group
	var magnitude := _magnitude(prior) if prior >= 0 else 0.0
	if magnitude <= 0.0: _active_group = -1
	# Keep the active driver on equal magnitude. Compare pre-binding control
	# magnitude, not the subsequently normalized stick direction.
	for index: int in BINDING_ORDER:
		var candidate := _magnitude(index)
		if candidate > magnitude:
			_active_group = index
			magnitude = candidate
	if _active_group < 0:
		_direction = Vector2.ZERO
		return Commands.on_move_canceled(submit) if prior >= 0 else null
	if _active_group == prior and changed_group != prior: return null
	_direction = _read_group(_active_group)
	return Commands.on_move_performed(_direction,blocked,submit)

## Disabling Move cancels only the active action, never an unrelated click route.
func deactivate(submit: Callable, keep_physical := false) -> Variant:
	var had_move := _active_group >= 0
	if not keep_physical:
		_held.clear()
		_toggle_held.clear()
		_raw_stick = Vector2.ZERO
	_active_group = -1
	_direction = Vector2.ZERO
	return Commands.on_move_canceled(submit) if had_move else null

func _magnitude(index: int) -> float:
	if index == STICK:
		return clampf((_raw_stick.length()-DEADZONE_MIN)/(DEADZONE_MAX-DEADZONE_MIN),0.0,1.0)
	return 0.0 if _read_group(index) == Vector2.ZERO else 1.0

func _read_group(index: int) -> Vector2:
	# Input System's control radial deadzone is followed by the authored
	# NormalizeVector2 then StickDeadzone; an admitted vector has unit length.
	if index == STICK: return _raw_stick.normalized() if _magnitude(STICK) > UNITY_NORMALIZATION_EPSILON else Vector2.ZERO
	var keys: Array = GROUPS[index]
	return Vector2(
		int(bool(_held.get(keys[3], false))) - int(bool(_held.get(keys[2], false))),
		int(bool(_held.get(keys[0], false))) - int(bool(_held.get(keys[1], false)))
	).normalized()
