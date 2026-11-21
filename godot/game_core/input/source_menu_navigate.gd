extends "res://game_core/input/source_gamepad_navigate.gd"
## UI/Navigate uses separate WASD and arrow-key DigitalNormalized composites.
## A later raw edge publishes only its own binding, including the zero value.
const KEY_GROUPS := [[KEY_W,KEY_S,KEY_A,KEY_D], [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]]
var _keys := {}

func observe(event: InputEvent, ui_active: bool) -> bool:
	if super.observe(event,ui_active): return true
	if not event is InputEventKey: return false
	var key: int = event.physical_keycode
	for group: Array in KEY_GROUPS:
		if key not in group: continue
		if event.echo or _keys.has(key)==event.pressed: return true
		if event.pressed: _keys[key]=true
		else: _keys.erase(key)
		if ui_active:
			_pending=Vector2i(int(_keys.has(group[3]))-int(_keys.has(group[2])),
				int(_keys.has(group[1]))-int(_keys.has(group[0])))
		return true
	return false

func reset_device() -> void:
	super.reset_device()
	_keys.clear()
