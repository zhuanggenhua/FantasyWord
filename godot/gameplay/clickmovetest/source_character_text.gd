extends Control
## UICharacter authored single-visible-line TMP subset. Static Latin uses
## original RPGSystem Alpha8; verified dynamic Silver fallback is drawn with
## Godot FontFile and is not claimed byte-for-byte Unity SDF raster parity.
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
const SILVER_HASH := "7adcf56d93142ded08ff18196f78fcaaf552411b9a94dc559dac90eb5c91cef1"
const ELLIPSIS := 0x2026
const SILVER_UPEM := 1900.0
const SILVER_ADVANCE := {0x2026:1200,0x73a9:1200,0x5bb6:1200,0x89d2:1100,0x8272:1200,
	0x914d:1200,0x7f6e:1200,0x5e94:1200,0x7528:1200,0x70b9:1200}
const SILVER_FACE := Vector2(56.842106,-42.63158)
const STATIC_FACE := Vector2(67.5,-16.875)
var _atlas: Atlas
var _fallback: Control
var _silver: FontFile
var _line := {}
var _size_points := 0

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	_fallback=Control.new()
	_fallback.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_fallback)
	_fallback.draw.connect(_draw_silver)

static func load_silver(path: String) -> FontFile:
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=SILVER_HASH: return null
	var font := FontFile.new()
	font.allow_system_fallback=false
	font.hinting=TextServer.HINTING_NONE
	return font if font.load_dynamic_font(path)==OK else null

func configure(atlas: Atlas, silver: FontFile, shown: String, box: Rect2, spec: Dictionary,
		pixel_scale := 1.0) -> bool:
	if atlas==null or silver==null or not is_finite(pixel_scale) or pixel_scale<=0.0: return false
	var rendered := layout(atlas,shown,box,spec)
	if rendered.is_empty(): return false
	var points := int(spec.size)
	for glyph in rendered.glyphs:
		if glyph.silver and not silver.has_char(glyph.code): return false
	_atlas=atlas
	_silver=silver
	_line=rendered
	_size_points=points
	if not set_canvas_pixel_scale(pixel_scale): return false
	queue_redraw()
	_fallback.queue_redraw()
	return true

func set_canvas_pixel_scale(pixels: float) -> bool:
	if _atlas==null or not is_finite(pixels) or pixels<=0.0: return false
	material=_atlas.face_material(false,float(_size_points)/90.0*pixels)
	return material!=null

static func _element(atlas: Atlas, code: int, points: float, at: float) -> Dictionary:
	var static_glyph := atlas.layout_glyph(code,points,Vector2(at,0),false)
	if not static_glyph.is_empty():
		static_glyph["face"]=STATIC_FACE*static_glyph.glyph_scale
		static_glyph["silver"]=false
		static_glyph["code"]=code
		return static_glyph
	if not SILVER_ADVANCE.has(code): return {}
	return {"silver":true,"code":code,"pos":Vector2(at,0),
		"advance":float(SILVER_ADVANCE[code])*points/SILVER_UPEM,"face":SILVER_FACE*(points/90.0)}

static func layout(atlas: Atlas, text: String, bounds: Rect2, spec: Dictionary) -> Dictionary:
	if atlas==null or not bounds.is_finite() or not bounds.has_area() or spec.get("style")!=0: return {}
	var points: float = spec.get("size",0)
	var h: int = spec.get("horizontal",0)
	var v: int = spec.get("vertical",0)
	var overflow: int = spec.get("overflow",0)
	if points not in [48.0,64.0,120.0] or h not in [1,2,4] or v not in [256,512] 			or overflow not in [0,1] or text.contains("\n"): return {}
	var glyphs: Array[Dictionary] = []
	var render_text := text
	var x := 0.0
	var ascent := 0.0
	var descent := 0.0
	var width_eps := bounds.size.x + .0001
	var height_eps := bounds.size.y + .0001
	var candidate := {}
	for i in range(text.length()):
		var glyph := _element(atlas,text.unicode_at(i),points,x)
		if glyph.is_empty(): return {}
		var face: Vector2 = glyph.face
		var next_ascent := maxf(ascent,face.x)
		var next_descent := minf(descent,face.y)
		# TMP attempts to handle both vertical and horizontal overflow
		# before accepting this element into the current visible line.
		if x+glyph.advance>width_eps or next_ascent-next_descent>height_eps:
			if overflow!=1: return {}
			if candidate.is_empty():
				return {"glyphs":[],"text":"","baseline":bounds.get_center(),"width":0.0}
			glyphs.resize(candidate.count)
			var mark: Dictionary = candidate.mark
			glyphs.append(mark)
			render_text=text.left(candidate.count)+String.chr(ELLIPSIS)
			x=float(candidate.advance)
			ascent=float(candidate.ascent)
			descent=float(candidate.descent)
			break
		if overflow==1:
			var ellipsis := _element(atlas,ELLIPSIS,points,x)
			if ellipsis.is_empty(): return {}
			# Inserted ellipsis does not contribute line ascent or descent.
			if x+ellipsis.advance<width_eps and next_ascent-next_descent<height_eps:
				candidate={"count":i,"mark":ellipsis,"advance":x+ellipsis.advance,
					"ascent":ascent,"descent":descent}
		x+=glyph.advance
		ascent=next_ascent
		descent=next_descent
		glyphs.append(glyph)
	var initial := bounds.position.x
	if h==2: initial=bounds.get_center().x-x*.5
	if h==4: initial=bounds.end.x-x
	var y := bounds.position.y+ascent if v==256 else bounds.get_center().y+(ascent+descent)*.5
	var baseline := Vector2(initial,y)
	for glyph in glyphs:
		if glyph.silver: glyph.pos+=baseline
		else: glyph.destination.position+=baseline
	return {"glyphs":glyphs,"text":render_text,"baseline":baseline,"width":x}

func _draw() -> void:
	if _atlas==null: return
	for glyph in _line.glyphs:
		if not glyph.silver and glyph.destination.has_area():
			draw_texture_rect_region(_atlas.texture,glyph.destination,glyph.region,Color.WHITE,false,false)

func _draw_silver() -> void:
	if _silver==null: return
	for glyph in _line.glyphs:
		if glyph.silver:
			_fallback.draw_char(_silver,glyph.pos,String.chr(glyph.code),_size_points,Color.WHITE)
