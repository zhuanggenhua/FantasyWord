extends Control
## Source UICharacter for ClickMoveTest's actual actor. The caller owns the
## menu stack and input layer; business guards do not disable the buttons.
const State := preload("res://game_core/ui/source_character_panel_state.gd")
const Targets := preload("res://gameplay/clickmovetest/source_character_selectables.gd")
const Text := preload("res://gameplay/clickmovetest/source_character_text.gd")
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
const Tiled := preload("res://gameplay/clickmovetest/source_menu_tiled_image.gd")
const Apply := preload("res://gameplay/clickmovetest/source_character_apply_image.gd")
const SubmitFeedback := preload("res://gameplay/clickmovetest/source_category_submit_feedback.gd")
const SIZE := Vector2(1920,1080)
const DARK := Color("#3f2832")
const NORMAL_ALPHA := 100.0/255.0
const FADE := 0.1
var _state: State
var _targets := Targets.new()
var _atlas: Atlas
var _silver: FontFile
var _background: Tiled
var _apply_submit := SubmitFeedback.new()
var _apply_hover := 0
var _apply: Apply
var _apply_rect := Rect2()
var _lines: Array[Dictionary] = []
var _values: Array[Dictionary] = []
var _arrows: Array[Dictionary] = []
var _icons: Array[ColorRect] = []
var _icon_base: Array[float] = []
var _scale := 1.0
var _pixels := 1.0
var _last_us := 0
var _offset := 0.0
var _admitted := false

func _init() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func bind(layout: Dictionary, pause: Dictionary, directory: String, silver_path: String, state: State) -> bool:
	if _state!=null or state==null or state.visible_data().is_empty() or layout.get("schema")!=1 			or layout.get("source_commit")!=Atlas.SOURCE or layout.get("canvas")!=[0.0,0.0,1920.0,1080.0]:
		return false
	var tile: Variant = layout.get("tile")
	if not tile is Dictionary or tile.get("id")!="-1443275623" or tile.get("pixel_size")!=6 			or tile.get("rect")!=[96.0,88.0,24.0,24.0] or tile.get("border")!=[3.0,3.0,3.0,3.0]:
		return false
	_atlas=Atlas.new()
	_silver=Text.load_silver(silver_path)
	if _silver==null or not _atlas.bind(pause,directory.path_join("pause-font-atlas.bin")) or not _targets.bind(layout,state):
		return false
	_state=state
	var data := pause.duplicate()
	data.tiled_images={"Character Background":{"sprite_id":tile.id,"fill_center":true,"ppu_multiplier":1,
		"color":{"r":1,"g":1,"b":1,"a":1}}}
	data.sprites={tile.id:{"rect":{"x":96,"y":88,"width":24,"height":24},"border":{"x":3,"y":3,"z":3,"w":3}}}
	_background=Tiled.new()
	add_child(_background)
	if not _background.bind(data,directory.path_join("SPS_GUI.png"),"Character Background"): return false
	_background.size=SIZE

	if not _append_text(layout.get("title"),"Character"): return false
	var footer: Variant = layout.get("footer")
	if not footer is Array or footer.size()!=2 or not _append_text(footer[0],"Select") or not _append_text(footer[1],"Back"):
		return false

	var state_values := state.visible_data()
	for i in range(8):
		var row: Dictionary = layout.rows[i]
		var box := Targets._rect(row.get("null_icon_rect"))
		if box.size!=Vector2(48,48): return false
		# Graphic.OnPopulateMesh when activeSprite is null produces a plain
		# white quad, not a substituted icon or removal of its layout slot.
		var icon := ColorRect.new()
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		icon.color=Color.WHITE
		icon.position=box.position
		icon.size=box.size
		_icons.append(icon)
		_icon_base.append(box.position.x)
		add_child(icon)
		if not _append_text(row.get("label"),"[INVALID_SHORTNAME]"): return false
		if not _append_text(row.get("decrease"),"<"): return false
		_add_arrow(_lines.back().line,_arrows.size()+1)
		if not _append_value(row.get("value"),state_values.rows[i],"rows",i): return false
		if not _append_text(row.get("increase"),">"): return false
		_add_arrow(_lines.back().line,_arrows.size()+1)

	var info: Variant = layout.get("info")
	if not info is Array or info.size()!=5: return false
	var keys := ["class","level","experience","skill_points","currency"]
	for i in range(keys.size()):
		var item: Variant = info[i]
		if not item is Dictionary or item.get("key")!=keys[i]: return false
		var label: String = ["[INVALID_SHORTNAME]","[INVALID_SHORTNAME]","[INVALID_SHORTNAME] Req.",
			"[INVALID_SHORTNAME]","[INVALID_FULLNAME]"][i]
		if not _append_text(item.get("label"),label) or not _append_value(item.get("value"),state_values[keys[i]],keys[i]):
			return false

	_apply=Apply.new()
	add_child(_apply)
	if not _apply.bind(layout.apply.get("sprite_state"),_background): return false
	_apply_rect=Targets._rect(layout.apply.get("rect"))
	_apply.position=_apply_rect.position
	_apply.size=_apply_rect.size
	if not _append_value(layout.apply.get("label"),state_values.apply,"apply"): return false
	_admitted=true
	return true

func _append_text(spec: Variant, authored: String) -> bool:
	if not spec is Dictionary or spec.get("text")!=authored: return false
	return _add_line(spec,authored)

func _append_value(spec: Variant, text: String, key: String, i := -1) -> bool:
	if not spec is Dictionary or not _add_line(spec,text): return false
	var data: Dictionary = _lines.back().duplicate()
	data["key"]=key
	data["index"]=i
	_values.append(data)
	return true

func _add_line(spec: Dictionary, display: String) -> bool:
	var box := Targets._rect(spec.get("rect"))
	var rgba: Variant = spec.get("color")
	if not rgba is Dictionary or spec.get("anchor") not in ["wide","center","bottom_left","bottom_right"]: return false
	for k in ["r","g","b","a"]:
		if typeof(rgba.get(k)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(rgba[k]) or rgba[k]<0 or rgba[k]>1: return false
	var line := Text.new()
	if not line.configure(_atlas,_silver,display,box,spec):
		line.free()
		return false
	# Modulate also applies tint to the separate dynamic font child.
	line.modulate=Color(rgba.r,rgba.g,rgba.b,rgba.a)
	add_child(line)
	_lines.append({"line":line,"box":box,"spec":spec})
	return true

func _add_arrow(line: Text, action: int) -> void:
	line.modulate=Color(DARK,NORMAL_ALPHA)
	_arrows.append({"line":line,"action":action,"alpha":NORMAL_ALPHA,"target":NORMAL_ALPHA,
		"start":NORMAL_ALPHA,"elapsed":FADE})

func _refresh_values() -> void:
	var data := _state.visible_data()
	if data.is_empty(): return
	for field in _values:
		var value: String = data.rows[field.index] if field.key=="rows" else data[field.key]
		field.line.configure(_atlas,_silver,value,field.box,field.spec,_pixels)

func fit_viewport(viewport: Vector2, screen_scale := 1.0) -> void:
	if not viewport.is_finite() or viewport.x<=0.0 or viewport.y<=0.0: return
	_scale=viewport.y/SIZE.y
	_pixels=_scale*screen_scale
	var width := viewport.x/_scale
	var delta := width-SIZE.x
	_offset=delta/2.0
	scale=Vector2.ONE*_scale
	_background.size=Vector2(width,SIZE.y)
	for part in _lines:
		match part.spec.anchor:
			"bottom_left": part.line.position.x=0.0
			"bottom_right": part.line.position.x=delta
			_: part.line.position.x=_offset
		part.line.set_canvas_pixel_scale(_pixels)
	for i in range(_icons.size()):
		_icons[i].position.x=_icon_base[i]+_offset
	_apply.position.x=_apply_rect.position.x+_offset

func viewport_to_design(p: Vector2) -> Vector2: return p/_scale
func try_handle_back_request() -> bool: return false
func allows_stack_close() -> bool: return true
func selected_action() -> int: return _targets.selected_action()
func reference_hit(p: Vector2) -> int: return _targets.hit(p,Vector2(_offset,0))
func button_visual(action: int) -> String:
	return "pressed" if action==Targets.APPLY and _apply_submit.pressed==action else _targets.visual(action)
func character_data() -> Dictionary: return _state.visible_data()

func apply_stack_interactions(active: bool) -> void:
	visible=active
	_targets.set_active(active)
	if not active:
		_apply_submit.clear()
		_apply_hover=0
		_state.clear()
	_sync_button_states()

func try_focus_default_target() -> bool:
	var focused := _targets.focus_default()
	_sync_button_states()
	return focused

func sample_point(hover: int, hit: int, active: bool) -> void:
	_apply_submit.interrupt_pointer(_apply_hover,hover)
	_apply_hover=hover
	_targets.sample_point(hover,hit,active)
	if selected_action()!=Targets.APPLY: _apply_submit.clear()
	_sync_button_states()

func pointer_down(hit: int) -> void:
	_apply_submit.clear()
	_targets.pointer_down(hit)
	_sync_button_states()

func pointer_release(hit: int) -> int:
	var action := _targets.pointer_release(hit)
	_sync_button_states()
	return action

func set_pressed(hit: int) -> void:
	_apply_submit.clear()
	_targets.set_pressed(hit)
	_sync_button_states()

func move_selection(direction: Vector2i) -> bool:
	var moved := _targets.move(direction)
	if moved:
		if selected_action()!=Targets.APPLY: _apply_submit.clear()
		_sync_button_states()
	return moved

func activate(action: int, from_submit := false) -> bool:
	var changed := _targets.activate(action)
	if changed: _refresh_values()
	# The native Button remains interactable when the actor has no points.
	if from_submit and action==Targets.APPLY and selected_action()==action and visible and is_inside_tree():
		_apply_submit.start(action,get_tree(),_sync_button_states)
		_sync_button_states()
	return changed

func _sync_button_states() -> void:
	if not _admitted: return
	for arrow in _arrows:
		var alpha := NORMAL_ALPHA if _targets.visual(arrow.action)=="normal" else 1.0
		if alpha!=arrow.target:
			arrow.start=arrow.alpha
			arrow.target=alpha
			arrow.elapsed=0.0
	_apply.show_button_state(button_visual(Targets.APPLY))

func _ready() -> void: _last_us=Time.get_ticks_usec()

func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now-_last_us)/1000000.0
	_last_us=now
	for arrow in _arrows:
		if arrow.elapsed>=FADE: continue
		arrow.elapsed=minf(FADE,arrow.elapsed+dt)
		arrow.alpha=lerpf(arrow.start,arrow.target,arrow.elapsed/FADE)
		arrow.line.modulate=Color(DARK,arrow.alpha)
