extends Node
## 迁移 UIManager 菜单栈的 Gameplay ↔ Menu 路径。
## 宿主注入已注册面板、玩家命令门禁及动作图切换；不自动生成面板或处理对话状态层。
enum ActionLayer { GAMEPLAY, UI }
signal ui_input_observed(event: InputEvent)
var _stack: Array[Control] = []
var _cached_root: Control
var _cached_root_process_mode := Node.PROCESS_MODE_INHERIT
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

## Only an explicitly admitted root may be cached across normal close.
## It remains owned by this stack, not by an autoload or another scene.
func cached_root() -> Control:
	return _cached_root if is_instance_valid(_cached_root) and _stack.is_empty() else null

## 仅接收注册入口成功实例化的完整面板。宿主始终拥有失败的新对象。
func push_panel(panel: Control, retain_root := false) -> bool:
	if _transitioning or not _configured or not is_inside_tree() or not is_instance_valid(panel) \
			or panel.is_queued_for_deletion():
		return false
	var first := _stack.is_empty()
	var reuse := retain_root and first and panel==_cached_root and panel.get_parent()==self
	if (retain_root and (not first or (is_instance_valid(_cached_root) and not reuse))) \
			or (not reuse and (panel.get_parent()!=null or not _valid_panel(panel))):
		return false
	# 当前实现仅从 Gameplay 进入；不能夺取另一暂停态的时钟。
	if first and (get_tree().paused or not is_equal_approx(Engine.time_scale, 1.0)):
		return false
	_transitioning = true
	if not first: top().apply_stack_interactions(false)
	panel.hide()
	if reuse:
		panel.process_mode=_cached_root_process_mode
	else:
		if retain_root:
			_cached_root=panel
			_cached_root_process_mode=panel.process_mode
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
	if panel==_cached_root:
		# The original PopFromStack closes/hides but does not evict this panel.
		panel.process_mode=Node.PROCESS_MODE_DISABLED
	else:
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

## 原 CloseAllMenusRequested 逐层 Pop，不走 Cancel 或由面板否决。
func close_all() -> void:
	while pop_current():
		pass

func _valid_panel(panel: Control) -> bool:
	return panel.process_mode in [Node.PROCESS_MODE_INHERIT, Node.PROCESS_MODE_ALWAYS, Node.PROCESS_MODE_WHEN_PAUSED] \
		and panel.has_method("apply_stack_interactions") and panel.has_method("try_focus_default_target") \
		and panel.has_method("try_handle_back_request") and panel.has_method("allows_stack_close")

func _input(event: InputEvent) -> void:
	if not _configured: return
	var in_ui := not _stack.is_empty()
	if in_ui: ui_input_observed.emit(event)
	var key := ""
	if event is InputEventJoypadButton and event.device == 0:
		if event.button_index == JOY_BUTTON_START: key = "pad_start"
		elif event.button_index == JOY_BUTTON_B: key = "pad_east"
	elif event is InputEventKey and event.physical_keycode==KEY_ESCAPE:
		key = "escape"
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.device>=0:
		key = "right_mouse"
	if key.is_empty(): return
	# Start opens Gameplay only. East is UI Cancel, but in Gameplay its event
	# must reach the real FireAbility3 route. Track both even on the other map.
	var on_map := (in_ui and key != "pad_start") or (not in_ui and key != "pad_east")
	if on_map: get_viewport().set_input_as_handled()
	if not event.pressed:
		_cancel_held.erase(key)
		_physical_cancel.erase(key)
		return
	if event.is_echo() or _physical_cancel.has(key): return
	_physical_cancel[key] = true
	if not on_map: return
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
