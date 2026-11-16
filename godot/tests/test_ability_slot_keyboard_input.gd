extends SceneTree
const SlotKeys = preload("res://game_core/combat/ability_slot_keyboard_input.gd")
var receipt: Array = []
var checked := 0
var failures := 0
var router := SlotKeys.new()
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	for key in [KEY_1, KEY_Q, KEY_2, KEY_E, KEY_3, KEY_C, KEY_4, KEY_R, KEY_5]:
		_send(key, true)
		_send(key, false)
	_check(receipt == [[0,true],[0,false],[1,true],[1,false],[1,true],[1,false],
		[2,true],[2,false],[2,true],[2,false],[3,true],[3,false],[3,true],
		[3,false],[4,true],[4,false],[4,true],[4,false]], "锁定键位与零基命令索引")
	receipt.clear()
	_send(KEY_Q, true)
	_send(KEY_2, true)
	_send(KEY_Q, false)
	_check(receipt == [[1,true]], "同槽位别名键持续按住时不取消")
	_send(KEY_2, false)
	_check(receipt == [[1,true],[1,false]], "最后一个别名键释放才取消")
	receipt.clear()
	_send(KEY_5, false)
	_send(KEY_5, true, true)
	_send(KEY_SPACE, true)
	_check(receipt.is_empty(), "忽略初始无按下释放、键盘连发和非绑定")
	_send(KEY_1, true)
	_send(KEY_3, true)
	_send(KEY_1, true)
	_send(KEY_3, false)
	_send(KEY_1, false)
	_check(receipt == [[0,true],[2,true],[2,false],[0,false]], "两个槽分别处理，不重复按下")
	if failures == 0: print("PASS 技能槽键盘边沿：%d 项" % checked)
	quit(1 if failures else 0)
func _send(key: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	event.echo = echo
	router.handle_key(event, func(slot, down): receipt.append([slot,down]))
func _check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		push_error(label)
