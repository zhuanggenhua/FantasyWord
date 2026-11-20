extends RefCounted
## 锁定 Gameplay/Interact 与 UI/Submit 共用的四个物理控制。
## Button 默认只在动作从未按到按下时 performed；切图层不清空物理按压。
enum Edge { OTHER, HELD_OR_RELEASE, FIRST_PRESS }
const KEYS := [KEY_F,KEY_ENTER,KEY_SPACE]
var _held: Dictionary = {}

func observe(event: InputEvent) -> int:
	var token := ""
	if event is InputEventKey and event.physical_keycode in KEYS:
		token="key:%d"%event.physical_keycode
	elif event is InputEventJoypadButton and event.device==0 and event.button_index==JOY_BUTTON_A:
		token="pad:0/south"
	if token.is_empty(): return Edge.OTHER
	if not event.is_pressed():
		_held.erase(token)
		return Edge.HELD_OR_RELEASE
	if event.is_echo() or _held.has(token): return Edge.HELD_OR_RELEASE
	var first:=_held.is_empty()
	_held[token]=true
	return Edge.FIRST_PRESS if first else Edge.HELD_OR_RELEASE

func reset_device_state() -> void:
	_held.clear()
