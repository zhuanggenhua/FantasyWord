extends CanvasLayer
## The source root and keyboard/mouse input owner. It does not invent any
## child scene when the actual registration is not ported yet.
signal action_requested(action: int)
const Stack := preload("res://game_core/ui/gameplay_menu_stack.gd")
const View := preload("res://gameplay/clickmovetest/source_pause_focus_view.gd")
const Settings := preload("res://gameplay/clickmovetest/source_settings_view.gd")
const Prefs := preload("res://game_core/audio/source_audio_preferences.gd")
const Points := preload("res://game_core/input/mouse_point_actions.gd")
const SUBMIT := [KEY_F,KEY_ENTER,KEY_SPACE]
const DIRS := {KEY_W:Vector2i.UP,KEY_UP:Vector2i.UP,KEY_S:Vector2i.DOWN,KEY_DOWN:Vector2i.DOWN,
	KEY_A:Vector2i.LEFT,KEY_LEFT:Vector2i.LEFT,KEY_D:Vector2i.RIGHT,KEY_RIGHT:Vector2i.RIGHT}
var stack := Stack.new()
var _entry: Node
var _points: RefCounted
var _source: Dictionary
var _dir := ""
var _mouse := Vector2.INF
var _left_down := false
var _held_submit := {}
var _held_dirs := {}
var _nav := Vector2i.ZERO
var _settings_source := {}
var _prefs: Prefs
var _fit_owner := 0
var _next_nav_us := 0

func _init() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(stack)

func bind(entry: Node, points: RefCounted, source: Dictionary, directory: String,
		can_open: Callable, dialogue_playing: Callable) -> bool:
	if _entry != null or not is_instance_valid(entry) or points==null: return false
	# Admit all private artifacts before enabling any input owner.
	var probe := View.new()
	var valid := probe.bind(source,directory)
	probe.free()
	if not valid: return false
	if not stack.configure(_open,can_open,_change_map,dialogue_playing): return false
	_entry = entry
	_points = points
	_source = source
	_dir = directory
	return true

func bind_settings(definition: Dictionary, prefs: Prefs) -> bool:
	if _source.is_empty() or prefs==null or not _settings_source.is_empty(): return false
	var probe := Settings.new()
	var valid := probe.bind(definition,_source,_dir,prefs)
	probe.free()
	if not valid: return false
	_settings_source=definition
	_prefs=prefs
	return true

func _ready() -> void:
	get_viewport().size_changed.connect(_resize)

func _open() -> void:
	var view := View.new()
	if not view.bind(_source,_dir) or not stack.push_panel(view):
		view.free()
		return
	_resize()

func _change_map(layer_id: int) -> void:
	_reset_ui_edges()
	_entry.set_source_ui_action_layer(layer_id==Stack.ActionLayer.UI)

func _resize() -> void:
	var panel := stack.top()
	_fit_owner=0
	if panel==null or not panel.has_method("fit_viewport"): return
	_fit_owner=panel.get_instance_id()
	var viewport := get_viewport()
	panel.fit_viewport(viewport.get_visible_rect().size,viewport.get_final_transform().y.length())

func _reset_ui_edges() -> void:
	_mouse = Vector2.INF
	_left_down = false
	_held_submit.clear()
	_held_dirs.clear()
	_nav = Vector2i.ZERO
	_next_nav_us = 0

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		var view := stack.top()
		if view is View or view is Settings: view.set_pressed(0)
		_reset_ui_edges()

func _input(event: InputEvent) -> void:
	var current := stack.top()
	if current == null: return
	_entry.observe_source_ui_pointer(event)
	if not (current is View or current is Settings): return
	var view := current
	if event is InputEventMouseMotion and event.device==0:
		_mouse=event.position
		return
	if event is InputEventMouseButton and event.device==0 and event.button_index==MOUSE_BUTTON_LEFT:
		_mouse=event.position
		get_viewport().set_input_as_handled()
		var hit: int = view.reference_hit(view.viewport_to_design(_mouse))
		if event.pressed and not _left_down:
			_left_down=true
			view.pointer_down(hit)
		elif not event.pressed and _left_down:
			_left_down=false
			var action: int = view.pointer_release(hit)
			if action!=0: _activate(view,action)
		return
	if not event is InputEventKey or event.echo: return
	var key: int = event.physical_keycode
	if key in SUBMIT:
		get_viewport().set_input_as_handled()
		if not event.pressed:
			_held_submit.erase(key)
		elif not _held_submit.has(key):
			var first := _held_submit.is_empty()
			_held_submit[key]=true
			if first and view.selected_action()!=0: _activate(view,view.selected_action())
	elif DIRS.has(key):
		get_viewport().set_input_as_handled()
		if event.pressed: _held_dirs[key]=DIRS[key]
		else: _held_dirs.erase(key)
		var values := _held_dirs.values()
		var direction := Vector2i(int(Vector2i.RIGHT in values)-int(Vector2i.LEFT in values),
			int(Vector2i.DOWN in values)-int(Vector2i.UP in values))
		if direction.x!=0 and direction.y!=0: direction.x=0 # source tie chooses vertical
		if direction!=_nav:
			_nav=direction
			if _nav!=Vector2i.ZERO:
				_move_selected(view)
				_next_nav_us=Time.get_ticks_usec()+500000

func _move_selected(view: Control) -> void:
	if view is View: view.move_vertical(_nav.y)
	elif view is Settings: view.move_selection(_nav)

func _activate(view: Control, action: int) -> void:
	if view is Settings:
		view.activate(action)
		return
	if action==7 and not _settings_source.is_empty():
		var panel := Settings.new()
		if not panel.bind(_settings_source,_source,_dir,_prefs) or not stack.push_panel(panel):
			panel.free()
			return
		_left_down=false
		_resize()
	action_requested.emit(action)

func _process(_dt: float) -> void:
	var view := stack.top()
	if not (view is View or view is Settings): return
	if view.get_instance_id()!=_fit_owner:
		_left_down=false
		_resize()
	# Independently sample the current hit, even when the same Point stays put.
	var sample: Variant = _points.read_active(Points.Map.UI)
	var hover: int = view.reference_hit(view.viewport_to_design(_mouse)) if _mouse.is_finite() else 0
	var hit: int = view.reference_hit(view.viewport_to_design(sample)) if sample is Vector2 else 0
	view.sample_point(hover,hit,sample is Vector2)
	if _nav!=Vector2i.ZERO and Time.get_ticks_usec()>=_next_nav_us:
		_move_selected(view)
		_next_nav_us=Time.get_ticks_usec()+100000
