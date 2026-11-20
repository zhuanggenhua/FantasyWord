extends RefCounted
## UI/Navigate's <Gamepad>/dpad PassThrough binding. No initial state check.
const BUTTONS := {
	JOY_BUTTON_DPAD_UP: Vector2i.UP, JOY_BUTTON_DPAD_DOWN: Vector2i.DOWN,
	JOY_BUTTON_DPAD_LEFT: Vector2i.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2i.RIGHT,
}
var _held := {}
var _pending: Variant = null

## Track the physical composite on either map, publish only actual UI changes.
func observe(event: InputEvent, ui_active: bool) -> bool:
	if not event is InputEventJoypadButton or event.device!=0 or not BUTTONS.has(event.button_index):
		return false
	var button: int = event.button_index
	if _held.has(button)==event.pressed: return true
	if event.pressed: _held[button]=true
	else: _held.erase(button)
	if ui_active:
		_pending=Vector2i(
			int(_held.has(JOY_BUTTON_DPAD_RIGHT))-int(_held.has(JOY_BUTTON_DPAD_LEFT)),
			int(_held.has(JOY_BUTTON_DPAD_DOWN))-int(_held.has(JOY_BUTTON_DPAD_UP)))
	return true

## A single EventSystem update reads the last Navigate sample, including zero.
func take_direction() -> Variant:
	var direction: Variant = _pending
	_pending=null
	if direction is Vector2i and direction.y!=0: direction.x=0
	return direction

func clear_pending() -> void:
	_pending=null

func reset_device() -> void:
	clear_pending()
	_held.clear()
