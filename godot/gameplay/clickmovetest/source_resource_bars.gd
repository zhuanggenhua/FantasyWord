extends Control
## HUD.prefab 中跟随当前角色的生命、魔力条。只显示正式属性，不接受玩家修改数值。
const Player := preload("res://gameplay/clickmovetest/single_player_actor.gd")
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
const Sprite := preload("res://gameplay/clickmovetest/source_inventory_sprite.gd")
const LABEL := "[INVALID_SHORTNAME]"
const LABEL_RECT := Rect2(24,20,200,64)
const SLIDER_RECT := Rect2(232,36,384,32)
const ROW_GAP := Vector2(0,64)
const BACKGROUND := Color(0.09019608,0.078431375,0.14509805)
const SHAKE_DURATION := 0.2
const FRAME := {"rect":{"x":8,"y":80,"width":8,"height":8},"border":{"x":1,"y":1,"z":1,"w":1}}

var _owner: Player
var _actor: Node2D
var _font: Atlas
var _name_art: Array[Control]=[]
var _number_art: Array[Control]=[]
var _sliders: Array[Control]=[]
var _fills: Array[Sprite]=[]
var _number_bounds: Array[Rect2]=[Rect2(),Rect2()]
var _values: PackedInt32Array
var _shake_time := SHAKE_DURATION

func bind(owner: Player, texture: Texture2D, font: Atlas) -> bool:
	if _owner!=null or owner==null or texture==null or font==null or font.texture==null: return false
	_owner=owner
	_font=font
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_process(false)
	# HorizontalLayoutGroup 不改子宽；剩余16由两格均分，每格居中偏4。
	# 外层纵向两行各64；原图名称缺术语绑定，不另造 HP/MP 标签。
	for i in 2:
		var label:=_text_control(self)
		label.position=LABEL_RECT.position+ROW_GAP*i
		_name_art.append(label)
		var slider:=Control.new()
		slider.mouse_filter=Control.MOUSE_FILTER_IGNORE
		slider.position=SLIDER_RECT.position+ROW_GAP*i
		add_child(slider)
		_sliders.append(slider)
		var base:=ColorRect.new()
		base.mouse_filter=Control.MOUSE_FILTER_IGNORE
		base.color=BACKGROUND
		base.size=SLIDER_RECT.size
		slider.add_child(base)
		var fill:=_sprite(slider,texture,Rect2(0,0,0,SLIDER_RECT.size.y),
			{"rect":{"x":i*16,"y":4,"width":16,"height":4},"border":{"x":0,"y":0,"z":0,"w":0}})
		_fills.append(fill)
		_sprite(slider,texture,Rect2(Vector2.ZERO,SLIDER_RECT.size).grow(6.0),FRAME,true)
		_number_art.append(_text_control(slider))
	var names:=_glyph_lines(LABEL,64.0,LABEL_RECT.size.x)
	if names.is_empty() or _glyph_lines("0123456789/",28.0).is_empty(): return false
	for art in _name_art: _show_glyphs(art,names,0.0,64.0)
	return true

func _ready() -> void:
	set_process(false)
	_owner.controlled_character_changed.connect(_bind_actor)
	_bind_actor(_owner.get_current_controlled_character_or_player_instance())

func _exit_tree() -> void:
	if _owner!=null and _owner.controlled_character_changed.is_connected(_bind_actor):
		_owner.controlled_character_changed.disconnect(_bind_actor)
	_detach_actor()

func _detach_actor() -> void:
	if _owner!=null: _owner.unbind_current_health_changed(_on_health_changed)
	if is_instance_valid(_actor) and _actor.tree_exiting.is_connected(_on_actor_exit):
		_actor.tree_exiting.disconnect(_on_actor_exit)
	_actor=null

func _bind_actor(actor: Node2D) -> void:
	if actor==_actor: return
	_detach_actor()
	_actor=actor
	if is_instance_valid(_actor):
		if not _owner.bind_current_health_changed(_on_health_changed):
			push_error("原 HUD 生命条未订阅当前角色的真实生命属性。")
			_actor=null
		else:
			_actor.tree_exiting.connect(_on_actor_exit)
	_values=PackedInt32Array()
	_refresh()

func _on_actor_exit() -> void: _bind_actor(null)

func _on_health_changed(_previous: int, _current: int, _source: Variant) -> void: _refresh()

func _refresh() -> void:
	var next:=_owner.resource_bar_values(_actor)
	var shake:=next.size()==4 and _values.size()==4 and next[0]<_values[0]
	_values=next
	for i in 2:
		var ratio:=0.0
		var shown:=""
		if _values.size()==4:
			var current:int=_values[i*2]
			var maximum:int=_values[i*2+1]
			if maximum>0: ratio=clampf(float(current)/float(maximum),0.0,1.0)
			shown="%d/%d"%[current,maximum]
		_fills[i].size.x=SLIDER_RECT.size.x*ratio
		_fills[i].visible=ratio>0
		var rows:=_glyph_lines(shown,28.0)
		# 原 ContentSizeFitter 的 TMP preferred 使用百分位向上，pivot 保持居中。
		var preferred:=Vector2.ZERO if shown.is_empty() else Vector2(
			float(int(float(rows[0].width)*100.0+1.0))*.01,26.26)
		var point:=(SLIDER_RECT.size-preferred)*.5
		_number_art[i].position=point
		_number_bounds[i]=Rect2(point,preferred)
		_show_glyphs(_number_art[i],rows,0.0,28.0)
	if shake:
		# 降值时先取消同一次旧位移再执行协程首步；首步 sin(0)=0。
		_shake_time=0.0
		_sliders[0].position=SLIDER_RECT.position
		set_process(true)

func _process(delta: float) -> void:
	_shake_time=minf(_shake_time+delta,SHAKE_DURATION)
	_sliders[0].position=SLIDER_RECT.position+shake_offset(_shake_time)
	if _shake_time>=SHAKE_DURATION: set_process(false)

static func shake_offset(elapsed: float) -> Vector2:
	if elapsed>=SHAKE_DURATION: return Vector2.ZERO
	# TransformShaker 的时间是缩放秒；原 Y 向上。
	return 5.0*Vector2(sin(30.0*elapsed),-sin(25.0*elapsed))

func blocks_map_pointer(point: Vector2) -> bool:
	# GraphicRaycaster 不按图片 alpha 掏空。原 Frame 包住背景和填充，名称仍只按 Rect。
	for i in _sliders.size():
		if Rect2(LABEL_RECT.position+ROW_GAP*i,LABEL_RECT.size).has_point(point): return true
		var relative:=point-_sliders[i].position
		if Rect2(Vector2.ZERO,SLIDER_RECT.size).grow(6.0).has_point(relative) \
				or _number_bounds[i].has_point(relative): return true
	return false

func set_canvas_pixel_scale(pixels: float) -> void:
	var sizes:=[64.0,28.0]
	var families:=[_name_art,_number_art]
	for i in sizes.size():
		var face:=_font.face_material(false,sizes[i]/90.0*pixels)
		for art: Control in families[i]: art.material=face

func _text_control(parent: Control) -> Control:
	var art:=Control.new()
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	art.draw.connect(_draw_text.bind(art))
	parent.add_child(art)
	return art

func _sprite(parent: Control, texture: Texture2D, rect: Rect2, source: Dictionary, sliced := false) -> Sprite:
	var art:=Sprite.new()
	art.position=rect.position
	art.size=rect.size
	art.show_sprite(texture,source,sliced)
	parent.add_child(art)
	return art

func _glyph_lines(shown: String, points: float, max_width := INF) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	var glyphs: Array[Dictionary]=[]
	var width:=0.0
	# 本入口只接收锁定占位术语和数值，字体的 pair adjustment 表为空。
	# 原 TMP Normal wrap 在无普通断点长词按字符断行；Overflow 保留框外行。
	for i in shown.length():
		var glyph:=_font.layout_glyph(shown.unicode_at(i),points,Vector2(width,0),false)
		if glyph.is_empty(): return []
		if width>0 and width+glyph.advance>max_width+.0001:
			rows.append({"width":width,"glyphs":glyphs})
			glyphs=[]
			glyph.destination.position.x-=width
			width=0.0
		glyphs.append(glyph)
		width+=glyph.advance
	rows.append({"width":width,"glyphs":glyphs})
	return rows

func _show_glyphs(art: Control, rows: Array[Dictionary], top: float, points: float) -> void:
	# face 90pt：line height 92.46094，ascent 67.5，descent -16.875。
	var unit:=points/90.0
	var line_height:=92.46094*unit
	var first:=top+67.5*unit
	art.set_meta("lines",rows)
	art.set_meta("baseline",Vector2(first,line_height))
	art.queue_redraw()

func _draw_text(art: Control) -> void:
	if not art.has_meta("lines"): return
	var rows: Array=art.get_meta("lines")
	var baseline: Vector2=art.get_meta("baseline")
	for line in rows.size():
		for glyph: Dictionary in rows[line].glyphs:
			if not glyph.destination.has_area(): continue
			var box: Rect2=glyph.destination
			box.position.y+=baseline.x+line*baseline.y
			art.draw_texture_rect_region(_font.texture,box,glyph.region,Color.WHITE,false,false)
