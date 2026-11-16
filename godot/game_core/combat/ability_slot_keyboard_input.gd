extends RefCounted
## Gameplay/FireAbility1–5 的源码键盘子集。只生产零基槽位边沿，
## 不决定角色、装备、技能允许条件、上下文或执行结果。
const KEY_TO_SLOT := {
	KEY_1: 0, KEY_Q: 1, KEY_2: 1, KEY_E: 2, KEY_3: 2,
	KEY_C: 3, KEY_4: 3, KEY_R: 4, KEY_5: 4,
}

var _held_keys: Dictionary = {}
var _held_counts := [0, 0, 0, 0, 0]

func handle_key(event: InputEventKey, dispatch: Callable) -> bool:
	var key := event.physical_keycode
	if event.echo or not KEY_TO_SLOT.has(key) or bool(_held_keys.has(key)) == event.pressed:
		return false
	var slot: int = KEY_TO_SLOT[key]
	# 满幅值键冲突只看 Action 是否从/到零，不让同一槽位的别名键过早取消技能。
	if event.pressed:
		_held_keys[key] = true
		_held_counts[slot] += 1
		if _held_counts[slot] == 1:
			dispatch.call(slot, true)
			return true
	else:
		_held_keys.erase(key)
		_held_counts[slot] -= 1
		if _held_counts[slot] == 0:
			dispatch.call(slot, false)
			return true
	return false
