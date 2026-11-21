extends CanvasLayer
## The source root and menu navigation/input owner. It does not invent any
## child scene when the actual registration is not ported yet.
signal action_requested(action: int)
const GamepadNavigate := preload("res://game_core/input/source_gamepad_navigate.gd")
const InteractSubmit := preload("res://game_core/input/source_shared_interact_submit.gd")
const Stack := preload("res://game_core/ui/gameplay_menu_stack.gd")
const View := preload("res://gameplay/clickmovetest/source_pause_focus_view.gd")
const Settings := preload("res://gameplay/clickmovetest/source_settings_view.gd")
const Abilities := preload("res://gameplay/clickmovetest/source_abilities_view.gd")
const Player := preload("res://gameplay/clickmovetest/single_player_actor.gd")
const Journal := preload("res://gameplay/clickmovetest/source_journal_view.gd")
const Inventory := preload("res://gameplay/clickmovetest/source_inventory_view.gd")
const Details := preload("res://gameplay/clickmovetest/source_item_details_view.gd")
const Bags := preload("res://game_core/inventory/source_inventory_bags.gd")
const Character := preload("res://gameplay/clickmovetest/source_character_view.gd")
const CharacterState := preload("res://game_core/ui/source_character_panel_state.gd")
const CHARACTER_STATE_HASH := "be2fcc2fd913ba41c638951000e143db3f2a8c057a082eddf89be6a8de379892"
const CHARACTER_LAYOUT_HASH := "441a56f27bc3df0d5a423ac3fb9cfb2c6bcc5499c9e21121de853c72548c68cb"
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
var _gamepad_navigation := GamepadNavigate.new()
var _pending_pad_submit := 0
var _nav := Vector2i.ZERO
var _settings_source := {}
var _character_layout := {}
var _character_profile := {}
var _character_silver := ""
var _character_actor: Callable
var _character_values: Callable
var _character_money: Callable
var item_details: Details
var _inventory_layout := {}
var _inventory_bags: Bags
var _inventory_actor: Callable
var _inventory_owner: Callable
var _inventory_stats: Callable
var _inventory_equipment: Callable
var _inventory_silver := ""
var _abilities_layout := {}
var _abilities_player: Player
var _abilities_silver := ""
var _abilities_category := Abilities.ACTIVE_CATEGORY
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
	if _entry.has_method("observe_source_ui_gameplay_controls"):
		stack.ui_input_observed.connect(_entry.observe_source_ui_gameplay_controls)
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

func bind_character(layout_path: String, profile_path: String, silver: String,
		actor: Callable, values: Callable, money: Callable) -> bool:
	if _source.is_empty() or not _character_layout.is_empty() or not actor.is_valid() or not values.is_valid() \
			or not money.is_valid() or not FileAccess.file_exists(layout_path) or not FileAccess.file_exists(profile_path) \
			or FileAccess.get_sha256(layout_path)!=CHARACTER_LAYOUT_HASH \
			or FileAccess.get_sha256(profile_path)!=CHARACTER_STATE_HASH or not FileAccess.file_exists(silver) \
			or FileAccess.get_sha256(silver)!=Character.Text.SILVER_HASH:
		return false
	var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	var profile: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	if not layout is Dictionary or not profile is Dictionary or profile.get("pause_action")!=5 \
			or profile.get("registration")!=1: return false
	_character_layout=layout
	_character_profile=profile
	_character_silver=silver
	_character_actor=actor
	_character_values=values
	_character_money=money
	return true

func bind_inventory(bags: Bags, actor: Callable, owner: Callable, values: Callable, equipment: Callable, silver: String) -> bool:
	if _source.is_empty() or not equipment.is_valid() or _inventory_bags!=null or bags==null or not actor.is_valid() \
			or not owner.is_valid() or not values.is_valid(): return false
	_inventory_layout=Inventory.load_layout(_dir)
	if _inventory_layout.is_empty(): return false
	_inventory_bags=bags
	_inventory_actor=actor
	_inventory_owner=owner
	_inventory_stats=values
	_inventory_equipment=equipment
	_inventory_silver=silver
	return true

func _open_inventory() -> bool:
	var actor: Node = _inventory_actor.call()
	if not is_instance_valid(actor): return false
	var values: Array[int] = _inventory_stats.call(actor)
	var view := Inventory.new()
	if not view.bind(_inventory_layout,_source,_dir,_inventory_silver,
			_inventory_bags,_inventory_owner.call(actor),actor,values,_inventory_equipment.call()):
		view.free()
		return false
	if item_details==null:
		var spec := Details.load_layout(_dir)
		if not spec.is_empty():
			var candidate := Details.new()
			if candidate.bind(spec,_source,_dir,_inventory_silver,view.get_inventory_atlas()):
				item_details=candidate
				add_child(item_details)
			else: candidate.free()
	if item_details!=null:
		view.item_focus_changed.connect(item_details.select_gear)
	if not stack.push_panel(view):
		view.free()
		return false
	_left_down=false
	_resize()
	return true

func bind_abilities(player: Player, silver: String) -> bool:
	if _source.is_empty() or _abilities_player!=null or player==null: return false
	var layout:=Abilities.load_layout(_dir)
	if layout.is_empty() or player.active_ability_menu_codes()!=[20001,20010]: return false
	_abilities_player=player
	_abilities_layout=layout
	_abilities_silver=silver
	return true

func _open_abilities() -> bool:
	var view:=Abilities.new()
	if not view.bind(_abilities_layout,_source,_dir,_abilities_silver,_abilities_player,_abilities_category):
		view.free()
		return false
	view.category_changed.connect(_remember_abilities_category)
	if not stack.push_panel(view):
		view.free()
		return false
	_left_down=false
	_resize()
	return true

func _remember_abilities_category(category: int) -> void:
	_abilities_category=category

func _open_journal() -> bool:
	var spec := Journal.load_layout(_dir)
	if spec.is_empty(): return false
	var view := Journal.new()
	if not view.bind(spec,_source,_dir) or not stack.push_panel(view):
		view.free()
		return false
	_left_down=false
	_resize()
	return true

func _open_character() -> bool:
	var state := CharacterState.new()
	if not state.bind(_character_values.bind(_character_profile),_character_money) \
			or not state.show(_character_actor.call()): return false
	var panel := Character.new()
	if not panel.bind(_character_layout,_source,_dir,_character_silver,state) or not stack.push_panel(panel):
		panel.free()
		return false
	_left_down=false
	_resize()
	return true

func _ready() -> void:
	get_viewport().size_changed.connect(_resize)

func _open() -> void:
	var cached := stack.cached_root()
	if cached!=null:
		if stack.push_panel(cached,true): _resize()
		return
	var view := View.new()
	if not view.bind(_source,_dir) or not stack.push_panel(view,true):
		view.free()
		return
	_resize()

func _change_map(layer_id: int) -> void:
	_reset_ui_edges()
	_entry.set_source_ui_action_layer(layer_id==Stack.ActionLayer.UI)

func _resize() -> void:
	var panel := stack.top()
	_fit_owner=0
	var viewport := get_viewport()
	if item_details!=null:
		item_details.fit_viewport(viewport.get_visible_rect().size,viewport.get_final_transform().y.length())
	if panel==null or not panel.has_method("fit_viewport"): return
	_fit_owner=panel.get_instance_id()
	panel.fit_viewport(viewport.get_visible_rect().size,viewport.get_final_transform().y.length())

func _reset_ui_edges() -> void:
	_mouse = Vector2.INF
	_left_down = false
	_held_submit.clear()
	_held_dirs.clear()
	_nav = Vector2i.ZERO
	_next_nav_us = 0
	_gamepad_navigation.clear_pending()
	_pending_pad_submit = 0

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		var view := stack.top()
		if view is View or view is Settings or view is Character or view is Inventory or view is Abilities: view.set_pressed(0)
		_reset_ui_edges()
		_gamepad_navigation.reset_device()

func _pointer_hit(view: Control,point: Vector2) -> int:
	if item_details!=null and item_details.intercepts_point(point): return 0
	return view.reference_hit(view.viewport_to_design(point))

func _input(event: InputEvent) -> void:
	var current := stack.top()
	if _gamepad_navigation.observe(event,current!=null):
		# Keep stick axes visible to the gameplay observer while paused,
		# so its distinct Value action can seed the latest state on resume.
		if current!=null and event is InputEventJoypadButton: get_viewport().set_input_as_handled()
		return
	if current == null: return
	_entry.observe_source_ui_pointer(event)
	var supports_action := current is View or current is Settings or current is Character or current is Inventory or current is Abilities
	if _entry.uses_source_interact_submit():
		var edge: int = _entry.source_interact_submit_edge(event)
		if edge!=InteractSubmit.Edge.OTHER:
			get_viewport().set_input_as_handled()
			if supports_action and edge==InteractSubmit.Edge.FIRST_PRESS:
				if event is InputEventJoypadButton:
					# The UI module dispatches Move before Submit in the same update.
					_pending_pad_submit=current.get_instance_id()
				elif current.selected_action()!=0:
					_activate(current,current.selected_action())
			return
	if not supports_action: return
	var view := current
	if event is InputEventMouseMotion and event.device==0:
		_mouse=event.position
		return
	if event is InputEventMouseButton and event.device==0 and event.button_index==MOUSE_BUTTON_LEFT:
		_mouse=event.position
		get_viewport().set_input_as_handled()
		var hit: int = _pointer_hit(view,_mouse)
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
		if _held_dirs.has(key)==event.pressed: return
		_gamepad_navigation.clear_pending()
		if event.pressed: _held_dirs[key]=DIRS[key]
		else: _held_dirs.erase(key)
		var values := _held_dirs.values()
		var direction := Vector2i(int(Vector2i.RIGHT in values)-int(Vector2i.LEFT in values),
			int(Vector2i.DOWN in values)-int(Vector2i.UP in values))
		if direction.x!=0 and direction.y!=0: direction.x=0 # source tie chooses vertical
		_set_navigation(view,direction,Time.get_ticks_usec())

func _set_navigation(view: Control,direction: Vector2i,now: int) -> void:
	if direction==_nav: return
	_nav=direction
	_next_nav_us=0
	if _nav!=Vector2i.ZERO:
		_move_selected(view)
		_next_nav_us=now+500000

func _move_selected(view: Control) -> void:
	if view is View: view.move_vertical(_nav.y)
	elif view is Settings or view is Character or view is Inventory or view is Abilities: view.move_selection(_nav)

func _activate(view: Control, action: int) -> void:
	if view is Settings or view is Character or view is Inventory or view is Abilities:
		view.activate(action)
		return
	if action==1 and not _inventory_layout.is_empty():
		if not _open_inventory(): return
	if action==2:
		if not _open_journal(): return
	if action==4 and not _abilities_layout.is_empty():
		if not _open_abilities(): return
	if action==5 and not _character_layout.is_empty():
		if not _open_character(): return
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
	var submit := _pending_pad_submit
	_pending_pad_submit=0
	var pad_direction: Variant = _gamepad_navigation.take_direction()
	if not (view is View or view is Settings or view is Character or view is Inventory or view is Abilities): return
	if view.get_instance_id()!=_fit_owner:
		_left_down=false
		_resize()
	# Independently sample the current hit, even when the same Point stays put.
	var sample: Variant = _points.read_active(Points.Map.UI)
	var hover: int = _pointer_hit(view,_mouse) if _mouse.is_finite() else 0
	var hit: int = _pointer_hit(view,sample) if sample is Vector2 else 0
	view.sample_point(hover,hit,sample is Vector2)
	var now := Time.get_ticks_usec()
	if pad_direction is Vector2i: _set_navigation(view,pad_direction,now)
	if _nav!=Vector2i.ZERO and now>=_next_nav_us:
		_move_selected(view)
		_next_nav_us=now+100000
	if submit==view.get_instance_id() and view.selected_action()!=0:
		_activate(view,view.selected_action())
