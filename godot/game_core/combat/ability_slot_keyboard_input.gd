extends RefCounted
## Gameplay/FireAbility1–5：键盘与本地手柄共用同一个槽位动作边沿。
## 不决定角色、装备、技能允许条件、上下文或执行结果。
const KEY_TO_SLOT := {
	KEY_1: 0, KEY_Q: 1, KEY_2: 1, KEY_E: 2, KEY_3: 2,
	KEY_C: 3, KEY_4: 3, KEY_R: 4, KEY_5: 4,
}
const BUTTON_TO_SLOT := {
	JOY_BUTTON_X: 0, JOY_BUTTON_Y: 1, JOY_BUTTON_B: 2,
	JOY_BUTTON_LEFT_SHOULDER: 3, JOY_BUTTON_RIGHT_SHOULDER: 4,
}

var _physical: Dictionary = {}
var _active: Dictionary = {}
var _held_counts := [0, 0, 0, 0, 0]

func handle_key(event: InputEventKey, dispatch: Callable) -> bool:
	return observe(event, true, dispatch)

func observe(event: InputEvent, gameplay: bool, dispatch: Callable = Callable()) -> bool:
	var slot := -1
	var token := ""
	if event is InputEventKey and KEY_TO_SLOT.has(event.physical_keycode):
		slot = KEY_TO_SLOT[event.physical_keycode]
		token = "key:%d" % event.physical_keycode
	elif event is InputEventJoypadButton and event.device == 0 and BUTTON_TO_SLOT.has(event.button_index):
		slot = BUTTON_TO_SLOT[event.button_index]
		token = "pad:%d" % event.button_index
	if token.is_empty() or event.is_echo(): return false
	if event.is_pressed():
		if _physical.has(token): return false
		_physical[token] = true
		# Original Button actions do not check initial state on map enable.
		# Observe holds in UI without admitting them to the new Gameplay action.
		if not gameplay: return false
		_active[token] = true
		_held_counts[slot] += 1
		if _held_counts[slot] == 1:
			dispatch.call(slot, true)
			return true
	else:
		_physical.erase(token)
		if not _active.erase(token): return false
		_held_counts[slot] -= 1
		if _held_counts[slot] == 0:
			dispatch.call(slot, false)
			return true
	return false

## 禁用 Gameplay 时每个活跃 Action 只发一次 canceled；持续按压等真实释放。
func deactivate(dispatch: Callable) -> void:
	var canceled: Array[int] = []
	for slot in range(_held_counts.size()):
		if _held_counts[slot] > 0: canceled.append(slot)
	_active.clear()
	_held_counts.fill(0)
	for slot in canceled: dispatch.call(slot, false)

func reset_device_state(dispatch: Callable) -> void:
	deactivate(dispatch)
	_physical.clear()
