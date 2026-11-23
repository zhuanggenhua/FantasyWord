extends Control
## Fixed centered source Settings panel, not a generic menu or substitute font.
const Line := preload("res://gameplay/clickmovetest/source_pause_text_line.gd")
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
const Tiled := preload("res://gameplay/clickmovetest/source_menu_tiled_image.gd")
const Prefs := preload("res://game_core/audio/source_audio_preferences.gd")
const DARK := Color("#3f2832")
const VALUE := Color("#8a7257")
const NORMAL_ALPHA := 100.0/255.0
const DURATION := 0.1
const SIZE := Vector2(1920,1080)
const LABELS := ["Master Volume","Background Music\n","Background Sound","Interface Sound","Gameplay Sound"]
var _prefs: Prefs
var _atlas: Atlas
var _background: Tiled
var _lines: Array[Line] = []
var _value_specs: Array[Dictionary] = []
var _values: Array[Line] = []
var _arrows: Array[Dictionary] = []
var _selected := 0
var _hover := 0
var _pressed := 0
var _live := false
var _scale := 1.0
var _pixels := 1.0
var _last_us := 0

func _init() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func bind(def: Dictionary, pause: Dictionary, path: String, prefs: Prefs) -> bool:
	if _prefs!=null or prefs==null or def.get("source_commit")!=Atlas.SOURCE or def.get("schema")!=1 \
			or _rect(def.get("root_rect"))!=Rect2(Vector2.ZERO,SIZE) or def.get("default_focus")!=[-1.0,-1.0]: return false
	var tile: Variant = def.get("tile")
	var rows: Variant = def.get("rows")
	var footer: Variant = def.get("footer")
	if not tile is Dictionary or tile.get("id")!="-1443275623" or tile.get("pixel_size")!=6 \
			or _rect(tile.get("rect"))!=Rect2(96,88,24,24) or tile.get("border")!=[3.0,3.0,3.0,3.0] \
			or not rows is Array or rows.size()!=5 or not footer is Array or footer.size()!=2: return false
	var volume: Variant = def.get("volume")
	if not volume is Dictionary or volume.get("step")!=Prefs.STEP or volume.get("max")!=Prefs.DISPLAY_MAX \
			or volume.get("suffix")!=Prefs.DISPLAY_SUFFIX: return false
	_atlas=Atlas.new()
	if not _atlas.bind(pause,path.path_join("pause-font-atlas.bin")): return false
	var data := pause.duplicate()
	data.tiled_images={"Settings Background":{"sprite_id":tile.id,"fill_center":true,"ppu_multiplier":1,
		"color":{"r":1,"g":1,"b":1,"a":1}}}
	data.sprites={tile.id:{"rect":{"x":96,"y":88,"width":24,"height":24},"border":{"x":3,"y":3,"z":3,"w":3}}}
	_background=Tiled.new()
	add_child(_background)
	if not _background.bind(data,path.path_join("SPS_GUI.png"),"Settings Background"): return false
	_background.size=SIZE
	_prefs=prefs
	if _add_text(def.get("title"),"Settings",Rect2(100,100,1720,120),DARK,2,256)==null: return false
	for i in range(5):
		var row: Variant = rows[i]
		if not row is Dictionary or row.get("id")!=i-1: return false
		var y := 440+64*i
		if _add_text(row.get("label"),LABELS[i],Rect2(527,y,450,64),DARK,1,512)==null: return false
		var before := _add_text(row.get("decrease"),"<",Rect2(993,y,64,64),DARK,2,512)
		var current := _add_text(row.get("value"),"{value}",Rect2(1057,y,272,64),VALUE,2,512,prefs.display(i-1))
		var after := _add_text(row.get("increase"),">",Rect2(1329,y,64,64),DARK,2,512)
		if before==null or current==null or after==null: return false
		_values.append(current)
		_value_specs.append(row.value)
		for part in [[before,993],[after,1329]]:
			part[0].self_modulate=Color(DARK,NORMAL_ALPHA)
			_arrows.append({"line":part[0],"bounds":Rect2(part[1],y,64,64),"alpha":NORMAL_ALPHA,
				"from":NORMAL_ALPHA,"target":NORMAL_ALPHA,"elapsed":DURATION})
	return _add_text(footer[0],"Select",Rect2(104,996,180,64),DARK,1,512)!=null \
		and _add_text(footer[1],"Back",Rect2(1636,996,180,64),DARK,4,512)!=null

func _add_text(spec: Variant, original: String, box: Rect2, tint: Color, align: int, vertical: int,
		display := "") -> Line:
	if not spec is Dictionary or spec.get("text")!=original or _rect(spec.get("rect"))!=box \
			or spec.get("horizontal")!=align or spec.get("vertical")!=vertical: return null
	var raw: Variant = spec.get("color")
	if not raw is Dictionary or not Color(raw.get("r",0),raw.get("g",0),raw.get("b",0),raw.get("a",0)).is_equal_approx(tint):
		return null
	var line := Line.new()
	if not line.configure(_atlas,original if display.is_empty() else display,box,spec):
		line.free()
		return null
	line.self_modulate=tint
	add_child(line)
	_lines.append(line)
	return line

static func _rect(value: Variant) -> Rect2:
	if not value is Array or value.size()!=4: return Rect2()
	for side in value:
		if typeof(side) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(side): return Rect2()
	return Rect2(value[0],value[1],value[2],value[3])

func fit_viewport(viewport: Vector2, screen_scale := 1.0) -> void:
	if not viewport.is_finite() or viewport.y<=0.0: return
	_scale=viewport.y/SIZE.y
	_pixels=_scale*screen_scale
	scale=Vector2.ONE*_scale
	position=(viewport-SIZE*_scale)/2.0
	for line in _lines: line.set_canvas_pixel_scale(_pixels)

func viewport_to_design(p: Vector2) -> Vector2: return (p-position)/_scale

func apply_stack_interactions(active: bool) -> void:
	_live=active
	visible=active
	if active:
		if not _refresh_volume_rows(): push_error("无法显示正式音频设置的当前值。")
	else:
		_selected=0
		_hover=0
		_pressed=0
	_retarget()

func try_focus_default_target() -> bool:
	if not _live: return false
	_selected=1 # Master decrease, not the text value or its row root.
	_retarget()
	return true

func try_handle_back_request() -> bool: return false
func allows_stack_close() -> bool: return true
func selected_action() -> int: return _selected

func reference_hit(p: Vector2) -> int:
	if not _live: return 0
	for i in range(_arrows.size()):
		if _arrows[i].bounds.has_point(p): return i+1
	return 0

func sample_point(hover: int, at: int, point_active: bool) -> void:
	if not _live: return
	_hover=hover
	if point_active and at!=0: _selected=at
	_retarget()

func pointer_down(hit: int) -> void:
	if not _live: return
	if hit!=0: _selected=hit
	set_pressed(hit)

func pointer_release(hit: int) -> int:
	var result := _pressed if _live and hit==_pressed else 0
	set_pressed(0)
	return result

func set_pressed(hit: int) -> void:
	_pressed=hit if _live else 0
	_retarget()

func move_selection(direction: Vector2i) -> bool:
	if not _live or _selected==0 or direction==Vector2i.ZERO: return false
	var index := _selected-1
	var next := Vector2i(index%2,index/2)+direction
	if next.x<0 or next.x>1 or next.y<0 or next.y>4: return false
	_selected=next.y*2+next.x+1
	_retarget()
	return true

func activate(action: int) -> bool:
	if not _live or action<1 or action>10: return false
	var index := action-1
	var row := index/2
	if not _prefs.adjust(row-1,-1 if index%2==0 else 1): return false
	return _refresh_volume_rows()

## 对应 UISettings.UpdateUI：显示时和任一按钮回调结束后重读全部音量，
## 而不是保留其他可能已由共享音量拥有者改变的标签缓存。
func _refresh_volume_rows() -> bool:
	var refreshed := true
	for i in range(_values.size()):
		var spec := _value_specs[i]
		if not _values[i].configure(_atlas,_prefs.display(i-1),_rect(spec.rect),spec,_pixels):
			refreshed=false
	return refreshed

func _retarget() -> void:
	for i in range(_arrows.size()):
		var arrow: Dictionary = _arrows[i]
		var target := 1.0 if i+1 in [_selected,_pressed,_hover] else NORMAL_ALPHA
		if target==arrow.target: continue
		arrow.from=arrow.alpha
		arrow.target=target
		arrow.elapsed=0.0

func _ready() -> void: _last_us=Time.get_ticks_usec()

func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now-_last_us)/1000000.0
	_last_us=now
	for arrow in _arrows:
		if arrow.elapsed>=DURATION: continue
		arrow.elapsed=minf(DURATION,arrow.elapsed+dt)
		arrow.alpha=lerpf(arrow.from,arrow.target,arrow.elapsed/DURATION)
		arrow.line.self_modulate=Color(DARK,arrow.alpha)
