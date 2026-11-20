extends Node
## 迁移 UIManager 菜单栈的 Gameplay ↔ Menu 路径。
## 宿主注入已注册面板、玩家命令门禁及动作图切换；不自动生成面板或处理对话状态层。
enum ActionLayer { GAMEPLAY, UI }
var _stack: Array[Control] = []
var _request_root: Callable
var _may_open: Callable
var _change_map: Callable
var _dialogue_playing: Callable
var _cancel_held: Dictionary = {}
var _physical_cancel: Dictionary = {}
var _configured := false
var _transitioning := false

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(request_root: Callable, may_open: Callable, change_map: Callable,
		dialogue_playing: Callable) -> bool:
	if _configured or not request_root.is_valid() or not may_open.is_valid() \
			or not change_map.is_valid() or not dialogue_playing.is_valid():
		return false
	_request_root = request_root
	_may_open = may_open
	_change_map = change_map
	_dialogue_playing = dialogue_playing
	_configured = true
	return true

func depth() -> int:
	return _stack.size()

func top() -> Control:
	return null if _stack.is_empty() else _stack.back()

## 仅接收注册入口成功实例化的完整面板。宿主始终拥有失败对象的处置责任。
func push_panel(panel: Control) -> bool:
	if _transitioning or not _configured or not is_inside_tree() or not is_instance_valid(panel) \
			or panel.get_parent() != null or panel.is_queued_for_deletion() \
			or not _valid_panel(panel):
		return false
	var first := _stack.is_empty()
	# 当前实现仅从 Gameplay 进入；不能夺取另一暂停态的时钟。
	if first and (get_tree().paused or not is_equal_approx(Engine.time_scale, 1.0)):
		return false
	_transitioning = true
	if not first: top().apply_stack_interactions(false)
	panel.hide()
	add_child(panel)
	# Godot 的固定步用常量源步长；仅令 delta 归零不能停止该链。
	if first:
		_cancel_held.clear()
		_change_map.call(ActionLayer.UI)
		Engine.time_scale = 0.0
		get_tree().paused = true
	_stack.append(panel)
	panel.show()
	panel.apply_stack_interactions(true)
	panel.try_focus_default_target()
	_transitioning = false
	return true

func pop_current() -> bool:
	if _transitioning or _stack.is_empty(): return false
	_transitioning = true
	var panel: Control = _stack.pop_back()
	panel.apply_stack_interactions(false)
	panel.hide()
	remove_child(panel)
	panel.queue_free()
	if _stack.is_empty():
		_cancel_held.clear()
		_change_map.call(ActionLayer.GAMEPLAY)
		Engine.time_scale = 1.0
		get_tree().paused = false
	else:
		top().apply_stack_interactions(true)
		top().try_focus_default_target()
	_transitioning = false
	return true

func _valid_panel(panel: Control) -> bool:
	return panel.process_mode in [Node.PROCESS_MODE_INHERIT, Node.PROCESS_MODE_ALWAYS, Node.PROCESS_MODE_WHEN_PAUSED] \
		and panel.has_method("apply_stack_interactions") and panel.has_method("try_focus_default_target") \
		and panel.has_method("try_handle_back_request") and panel.has_method("allows_stack_close")

func _input(event: InputEvent) -> void:
	if not _configured: return
	var key := ""
	if event is InputEventKey and event.physical_keycode==KEY_ESCAPE:
		key = "escape"
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.device>=0:
		key = "right_mouse"
	if key.is_empty(): return
	get_viewport().set_input_as_handled()
	if not event.pressed:
		_cancel_held.erase(key)
		_physical_cancel.erase(key)
		return
	if event.is_echo() or _physical_cancel.has(key): return
	_physical_cancel[key] = true
	var first_edge := _cancel_held.is_empty()
	_cancel_held[key] = true
	if not first_edge: return
	# The destination Button has no initial state check. A new physical press
	# is required instead of opening and closing on the same held control.
	if _stack.is_empty():
		if bool(_may_open.call()): _request_root.call()
	elif not bool(_dialogue_playing.call()) and not bool(top().try_handle_back_request()) \
			and bool(top().allows_stack_close()):
		pop_current()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_held.clear()
		_physical_cancel.clear()

func _exit_tree() -> void:
	if _stack.is_empty(): return
	Engine.time_scale = 1.0
	get_tree().paused = false
