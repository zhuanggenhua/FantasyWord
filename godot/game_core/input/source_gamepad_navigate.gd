extends "res://game_core/input/source_dpad_navigate.gd"
## UI/Navigate: a D-pad binding and the separate original Gamepad 2DVector.
## Both sticks' directional ButtonControls feed this one digital composite.
const AXES := [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]
const DEADZONE_MIN := 0.125
const DEADZONE_MAX := 0.925
const BUTTON_POINT := 0.5
var _axes: Array[float] = [0,0,0,0]

func observe(event: InputEvent, ui_active: bool) -> bool:
	if super.observe(event,ui_active): return true
	if not event is InputEventJoypadMotion or event.device!=0 or not is_finite(event.axis_value):
		return false
	var index := AXES.find(event.axis)
	if index<0: return false
	var raw := clampf(event.axis_value,-1,1)
	if _axes[index]==raw: return true
	_axes[index]=raw
	# Input System monitors underlying raw state, then dispatches the entire
	# PassThrough value, even if the processed digital direction is unchanged.
	if ui_active: _pending=_digital_vector()
	return true

func _pressed(value: float) -> bool:
	# Stick child controls have their own half-axis deadzone, not parent radial.
	return clampf((value-DEADZONE_MIN)/(DEADZONE_MAX-DEADZONE_MIN),0,1)>=BUTTON_POINT

func _either(left: float, right: float) -> int:
	return int(_pressed(left) or _pressed(right))

func _digital_vector() -> Vector2i:
	# Use viewport Y down; distinct bindings per direction use any sibling.
	return Vector2i(_either(_axes[0],_axes[2])-_either(-_axes[0],-_axes[2]),
		_either(_axes[1],_axes[3])-_either(-_axes[1],-_axes[3]))

func reset_device() -> void:
	super.reset_device()
	_axes.fill(0)
