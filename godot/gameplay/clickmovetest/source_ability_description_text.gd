extends Control
## 原技能说明的普通字形、混排、换行与明确下划线；不替换作者字体或补造文本。
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
var _atlas: Atlas
var _silver: FontFile
var _metrics: Dictionary
var _points: int
var _bounds: Rect2
var _glyphs: Array[Dictionary] = []
var _underlines: Array[Rect2] = []
var _fallback: Control
var displayed_lines: Array[String] = []
var truncated := false

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_fallback=Control.new()
	_fallback.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_fallback)
	_fallback.draw.connect(_draw_silver)

func bind(atlas: Atlas, silver: FontFile, metrics: Dictionary, box: Rect2, spec: Dictionary) -> bool:
	if atlas==null or silver==null or metrics.is_empty() or not box.has_area() or spec.size!=40 \
			or spec.horizontal!=2 or spec.vertical!=256 or spec.overflow!=1 or not spec.wrap: return false
	_atlas=atlas
	_silver=silver
	_metrics=metrics
	_points=int(spec.size)
	_bounds=box
	var clr: Dictionary=spec.color
	modulate=Color(clr.r,clr.g,clr.b,clr.a)
	return set_canvas_pixel_scale(1.0)

func set_canvas_pixel_scale(scale_value: float) -> bool:
	if _atlas==null: return false
	material=_atlas.face_material(false,float(_points)/90.0*scale_value)
	return material!=null

func show_ability(row: Dictionary) -> bool:
	if row.is_empty(): return show_message("")
	var paragraphs: Array = [{"text":row.description,"under":0}]
	if not row.damage.is_empty(): paragraphs.append({"text":"","under":0})
	for damage in row.damage:
		paragraphs.append({"text":damage.head+": "+damage.detail,"under":String(damage.head).length()})
	return _render(paragraphs)

func show_message(value: String) -> bool:
	var paragraphs: Array=[]
	for part in value.split("\n",true): paragraphs.append({"text":part,"under":0})
	return _render(paragraphs)

func _glyph(code: int, under: bool = false) -> Dictionary:
	var row := _atlas.layout_glyph(code,_points,Vector2.ZERO,false)
	if not row.is_empty():
		row.silver=false
		row.face=Vector2(_atlas._face.m_AscentLine,_atlas._face.m_DescentLine)*float(row.glyph_scale)
	else:
		var advance: float=_metrics.get(str(code),0.0)
		if advance<=0.0 or not _silver.has_char(code): return {}
		var factor:=float(_points)/1900.0
		row={"silver":true,"advance":advance*factor,"face":Vector2(1200,-900)*factor}
	row.code=code
	row.under=under
	return row

func _wrap(text: String, underline_length: int, lines: Array) -> bool:
	var line: Array[Dictionary]=[]
	var width := 0.0
	for i in text.length():
		var g := _glyph(text.unicode_at(i),i<underline_length)
		if g.is_empty(): return false
		if not line.is_empty() and width+float(g.advance)>_bounds.size.x:
			# Space-delimited Latin words remain intact when possible; CJK
			# text can break between glyphs. Do not move punctuation into a
			# preceding paragraph or discard damage-summary rows.
			var cut := line.size()
			if int(g.code)<128 and int(g.code)!=32:
				for j in range(line.size()-1,-1,-1):
					var code: int=line[j].code
					if code==32 or code>127:
						cut=j+1
						break
			if cut<line.size():
				lines.append(line.slice(0,cut))
				line=line.slice(cut)
				width=0.0
				for prior in line: width+=prior.advance
			else:
				lines.append(line)
				line=[]
				width=0.0
			if line.is_empty() and int(g.code)==32: continue
		line.append(g)
		width+=g.advance
	lines.append(line)
	return true

func _line_metrics(line: Array) -> Vector3:
	var factor:=float(_points)/float(_atlas._face.m_PointSize)
	var ascent:=float(_atlas._face.m_AscentLine)*factor
	var descent:=float(_atlas._face.m_DescentLine)*factor
	var width:=0.0
	for glyph in line:
		width+=glyph.advance
		ascent=maxf(ascent,glyph.face.x)
		descent=minf(descent,glyph.face.y)
	return Vector3(width,ascent,descent)

func _render(paragraphs: Array) -> bool:
	var lines: Array=[]
	for row in paragraphs:
		if not _wrap(row.text,row.under,lines): return false
	var results: Array=[]
	var top := _bounds.position.y
	for line: Array in lines:
		var metrics:=_line_metrics(line)
		if top+metrics.y-metrics.z>_bounds.end.y+.0001: break
		results.append({"glyphs":line,"top":top})
		var native_height:=float(_atlas._face.m_LineHeight)*_points/float(_atlas._face.m_PointSize)
		top+=maxf(native_height,metrics.y-metrics.z)
	truncated=results.size()<lines.size()
	if truncated and not results.is_empty():
		var row: Array=results.back().glyphs.duplicate()
		var ellipsis:=_glyph(0x2026)
		if ellipsis.is_empty(): return false
		while not row.is_empty() and (_line_metrics(row).x+ellipsis.advance>_bounds.size.x or row.back().code==32):
			row.pop_back()
		row.append(ellipsis)
		results.back().glyphs=row

	_glyphs.clear()
	_underlines.clear()
	displayed_lines.clear()
	for drawn in results:
		var line: Array=drawn.glyphs
		var metrics:=_line_metrics(line)
		var x:=_bounds.get_center().x-metrics.x*.5
		var y: float=drawn.top+metrics.y
		var text := ""
		for glyph in line:
			var pos:=Vector2(x,y)
			var g: Dictionary=glyph.duplicate()
			if g.silver: g.pos=pos
			else: g.destination.position+=pos
			if g.under:
				var unit := float(_points)/float(_atlas._face.m_PointSize)
				_underlines.append(Rect2(x,y-float(_atlas._face.m_UnderlineOffset)*unit,g.advance,
					float(_atlas._face.m_UnderlineThickness)*unit))
			_glyphs.append(g)
			x+=g.advance
			text+=String.chr(g.code)
		displayed_lines.append(text)
	queue_redraw()
	_fallback.queue_redraw()
	return true

func _draw() -> void:
	if _atlas==null: return
	for glyph in _glyphs:
		if not glyph.silver and glyph.destination.has_area():
			draw_texture_rect_region(_atlas.texture,glyph.destination,glyph.region)

func _draw_silver() -> void:
	if _silver==null: return
	for glyph in _glyphs:
		if glyph.silver: _fallback.draw_char(_silver,glyph.pos,String.chr(glyph.code),_points,Color.WHITE)
	for rect in _underlines: _fallback.draw_rect(rect,Color.WHITE)
