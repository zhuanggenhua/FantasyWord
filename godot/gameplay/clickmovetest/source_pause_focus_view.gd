extends Control
## Original left column, title, and exclusive focus label at reference dimensions.
## The input owner supplies an ordered UI Point hit; this view doesn't route actions.
const Column := preload("res://gameplay/clickmovetest/source_pause_entry_column.gd")
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
const PauseLine := preload("res://gameplay/clickmovetest/source_pause_text_line.gd")
const NORMAL := Color("#3f2832")
const BRIGHT := Color("#f5f5f5")
const FADE := 0.1

var _column: Control
var _footer_hit_areas: Array[Rect2] = []
var _centered_pieces: Array[Control] = []
var _effects_title: Control
var _design_width := 1920.0
var _canvas_scale := 1.0
var _shade := Color.TRANSPARENT
var _labels := {}
var _states := {}
var _entries: Array[Dictionary] = []
var _selected := 0
var _remembered := 0
var _hovered := 0
var _pressed := 0
var _live := false
var _last_us := 0

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func bind(source: Dictionary, dir: String) -> bool:
	if _column != null: return false
	var atlas := Atlas.new()
	var column := Column.new()
	var typography: Variant = source.get("text_layout")
	var layout: Variant = source.get("entry_layout")
	if not layout is Dictionary or not _valid_transition(layout.get("tints")):
		column.free()
		return false
	if not typography is Dictionary or not typography.get("title") is Dictionary \
			or not typography.get("entry") is Dictionary \
			or not atlas.bind(source,dir.path_join("pause-font-atlas.bin")) \
			or not column.bind(source,dir.path_join("SPS_GUI.png")):
		column.free()
		return false
	var title := PauseLine.new()
	var spec: Dictionary = typography.title
	if spec.get("rect") != [704.0,508.0,512.0,64.0] or spec.get("text") != "Pause" \
			or not title.configure(atlas,spec.text,Rect2(704,508,512,64),spec):
		column.free()
		title.free()
		return false
	var labels := {}
	var entries: Array[Dictionary] = column.entries()
	for e in entries:
		var label := PauseLine.new()
		if not label.configure(atlas,e.label,e.label_rect,typography.entry):
			for prior in labels.values(): prior.free()
			title.free()
			column.free()
			label.free()
			return false
		label.hide()
		labels[e.action] = label
	var raw_shade: Variant = source.get("shade")
	var dark := {"r":0.24705882,"g":0.15686275,"b":0.19607843,"a":0.78431374}
	var effects: Variant = typography.get("effects_title")
	var effect_title := PauseLine.new()
	if raw_shade != dark or not effects is Dictionary \
			or effects.get("rect") != [1536.0,240.0,384.0,64.0] or effects.get("text")!="Active Effects" \
			or not effect_title.configure(atlas,effects.text,Rect2(1536,240,384,64),effects):
		effect_title.free()
		for prior in labels.values(): prior.free()
		title.free()
		column.free()
		return false
	var footer := _make_footer(atlas,typography.get("default_footer"))
	if footer.is_empty():
		effect_title.free()
		for prior in labels.values(): prior.free()
		title.free()
		column.free()
		return false
	# Original sibling order: title, Menu Items, then Controls.
	_shade = Color(dark.r,dark.g,dark.b,dark.a)
	add_child(title)
	_centered_pieces.append(title)
	add_child(column)
	_entries = entries
	_column = column
	_labels = labels
	for action in labels:
		add_child(labels[action])
		_states[action] = {"color":NORMAL,"from":NORMAL,"target":NORMAL,"elapsed":FADE,"disabled":false}
	for item in footer:
		add_child(item.line)
		_footer_hit_areas.append(item.bounds)
		_centered_pieces.append(item.line)
	add_child(effect_title)
	_effects_title = effect_title
	queue_redraw()
	return true

## Match Height = 1, not a fixed-width letterbox. The three anchor groups
## deliberately use different X offsets. Pass screen scale for TMP smoothing.
func fit_viewport(size_pixels: Vector2, screen_scale := 1.0) -> void:
	if not size_pixels.is_finite() or size_pixels.x<=0.0 or size_pixels.y<=0.0: return
	_canvas_scale = size_pixels.y/1080.0
	_design_width = size_pixels.x/_canvas_scale
	scale = Vector2.ONE*_canvas_scale
	for line in _centered_pieces:
		line.position.x = (_design_width-1920.0)/2
		line.set_canvas_pixel_scale(_canvas_scale*screen_scale)
	if is_instance_valid(_effects_title):
		_effects_title.position.x = _design_width-1920.0
		_effects_title.set_canvas_pixel_scale(_canvas_scale*screen_scale)
	for line in _labels.values(): line.set_canvas_pixel_scale(_canvas_scale*screen_scale)
	queue_redraw()

func viewport_to_design(point: Vector2) -> Vector2:
	return point/_canvas_scale

func _draw() -> void:
	draw_rect(Rect2(0,0,_design_width,1080),_shade)


static func _make_footer(atlas: RefCounted, footer: Variant) -> Array[Dictionary]:
	if not footer is Dictionary or footer.get("icons_visible",true) != false \
			or footer.get("bounds") != [688.0,996.0,544.0,64.0]:
		return []
	var specs: Variant = footer.get("labels")
	if not specs is Array or specs.size()!=2: return []
	var result: Array[Dictionary] = []
	var label_bounds := [[692.0,996.0,180.0,64.0],[1048.0,996.0,180.0,64.0]]
	var icon_bounds := [[892.0,996.0,64.0,64.0],[964.0,996.0,64.0,64.0]]
	for i in range(specs.size()):
		var part: Variant = specs[i]
		var text: String = ["Select","Close"][i]
		var align: int = [4,1][i]
		if not part is Dictionary or part.get("rect")!=label_bounds[i] \
				or part.get("icon_rect")!=icon_bounds[i] or part.get("horizontal")!=align \
				or part.get("text")!=text or part.get("action")!=i+7 or part.get("raycast")!=true:
			for item in result: item.line.free()
			return []
		var r: Array = label_bounds[i]
		var bounds := Rect2(r[0],r[1],r[2],r[3])
		var line := PauseLine.new()
		if not line.configure(atlas,text,bounds,part):
			line.free()
			for item in result: item.line.free()
			return []
		result.append({"line":line,"bounds":bounds})
	return result

## Original TMP labels are non-selectable Graphics; absent icon Images do
## not obstruct. The host can distinguish their raycast from empty space.
func reference_footer_blocks(at: Vector2) -> bool:
	if not _live: return false
	var at_footer := at-Vector2((_design_width-1920.0)/2,0)
	for area in _footer_hit_areas:
		if area.has_point(at_footer): return true
	return false

static func _valid_transition(tints: Variant) -> bool:
	if not tints is Dictionary or tints.get("m_ColorMultiplier")!=1 or tints.get("m_FadeDuration")!=FADE:
		return false
	var white := {"r":1.0,"g":1.0,"b":1.0,"a":1.0}
	var bright := {"r":0.9607843,"g":0.9607843,"b":0.9607843,"a":1.0}
	return tints.get("m_DisabledColor")==white and tints.get("m_PressedColor")==white \
		and tints.get("m_SelectedColor")==bright and tints.get("m_HighlightedColor")==bright

## The Button parent has no Graphic. Only actual icon and currently visible
## TMP label are candidate row hits; external ordered blockers still take precedence.
func reference_hit(at: Vector2) -> int:
	if not _live or reference_footer_blocks(at) \
			or Rect2(_design_width-384.0,240,384,64).has_point(at): return 0
	for row in _entries:
		if _available(row.action) and (row.icon.has_point(at) \
				or (label_visible(row.action) and row.label_rect.has_point(at))):
			return row.action
	return 0

func selected_action() -> int: return _selected
func label_visible(action: int) -> bool: return _labels.has(action) and _labels[action].visible
func entry_tint(action: int) -> Color: return _states[action].color if _states.has(action) else Color.TRANSPARENT

func apply_stack_interactions(active: bool) -> void:
	_live = active
	visible = active
	if not active:
		_hovered = 0
		_pressed = 0
		_set_selected(0)
	_retarget()

func try_focus_default_target() -> bool:
	return choose(_remembered)

func move_vertical(step: int) -> bool:
	if not _live or step==0 or _selected==0: return false
	var from := _entries.find_custom(func(row): return row.action==_selected)
	if from<0: return false
	var index := from + signi(step)
	while index>=0 and index<_entries.size():
		if choose(_entries[index].action): return true
		index += signi(step)
	return false

func choose(action: int) -> bool:
	if not _live or not _available(action): return false
	_set_selected(action)
	_retarget()
	return true

## Pointer exit or a hit on shade doesn't clear actual selection.
## Highlight receives its own field because it can occur without a qualifying selection raycast.
func sample_point(highlight: int, selectable_hit: int, point_active: bool) -> void:
	if not _live: return
	_hovered = highlight if _available(highlight) else 0
	if point_active and _available(selectable_hit): _set_selected(selectable_hit)
	_retarget()

func pointer_down(hit: int) -> void:
	# Selection happens on down for an interactable left mouse button.
	choose(hit)
	set_pressed(hit)

func pointer_release(hit: int) -> int:
	var action := _pressed
	set_pressed(0)
	return action if action!=0 and hit==action and _available(action) else 0

func set_pressed(action: int) -> void:
	_pressed = action if _live and _available(action) else 0
	_retarget()

func set_disabled(action: int, disabled: bool) -> void:
	if not _states.has(action): return
	_states[action].disabled = disabled
	if disabled:
		if _pressed==action: _pressed=0
		if _hovered==action: _hovered=0
		if _selected==action: _set_selected(0)
	_retarget()

func try_handle_back_request() -> bool: return false
func allows_stack_close() -> bool: return true

func _available(action: int) -> bool:
	return _states.has(action) and not _states[action].disabled

func _set_selected(action: int) -> void:
	if action==_selected: return
	if _labels.has(_selected): _labels[_selected].hide()
	_selected=action
	if _labels.has(action):
		_remembered=action
		_labels[action].show()

func _retarget() -> void:
	for action in _states:
		var row: Dictionary = _states[action]
		var target := NORMAL
		if not _live or row.disabled or _pressed==action:
			target = Color.WHITE
		elif _selected==action or _hovered==action:
			target = BRIGHT
		if target!=row.target:
			row.from=row.color
			row.target=target
			row.elapsed=0.0

func _ready() -> void:
	_last_us=Time.get_ticks_usec()

func _process(_scaled_delta: float) -> void:
	var now := Time.get_ticks_usec()
	advance_unscaled(float(now-_last_us)/1000000.0)
	_last_us=now

func advance_unscaled(seconds: float) -> void:
	if not is_finite(seconds) or seconds<=0: return
	for action in _states:
		var row: Dictionary = _states[action]
		if row.elapsed>=FADE: continue
		row.elapsed=minf(FADE,row.elapsed+seconds)
		row.color=(row.from as Color).lerp(row.target,row.elapsed/FADE)
		_column.set_entry_tint(action,row.color)
