extends Control
## Faithful single-line subset for original RPGSystem pause title and labels.
## No fallback font, shaping, wrap or selection ownership.
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
var _atlas: RefCounted
var _line: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func configure(atlas: RefCounted, text: String, bounds: Rect2, spec: Dictionary,
		canvas_pixel_scale := 1.0) -> bool:
	var line := layout(atlas,text,bounds,spec)
	if line.is_empty() or not is_finite(canvas_pixel_scale) or canvas_pixel_scale<=0.0: return false
	_atlas = atlas
	_line = line
	if not set_canvas_pixel_scale(canvas_pixel_scale): return false
	queue_redraw()
	return true

func set_canvas_pixel_scale(canvas_pixel_scale: float) -> bool:
	if _atlas == null or not is_finite(canvas_pixel_scale) or canvas_pixel_scale<=0.0: return false
	var adjusted: ShaderMaterial = _atlas.face_material(_line.bold,_line.glyph_scale*canvas_pixel_scale)
	if adjusted == null: return false
	material = adjusted
	return true

static func layout(atlas: RefCounted, text: String, bounds: Rect2, spec: Dictionary) -> Dictionary:
	if atlas == null or text.is_empty() or not bounds.has_area() or not bounds.is_finite():
		return {}
	var bold: bool = spec.get("style")==17
	var centered: bool = spec.get("horizontal")==2
	var right_aligned: bool = spec.get("horizontal")==4
	var top: bool = spec.get("vertical")==256 and spec.get("style")==0 and centered and spec.get("size")==120
	if not top and (spec.get("vertical")!=512 or not ((bold and centered and spec.get("size")==80) \
			or (spec.get("style")==0 and (spec.get("horizontal")==1 or centered or right_aligned) and spec.get("size")==64))):
		return {}
	var shown := text.to_upper() if bold else text
	# One authored settings label contains a final glyphless line. Keep the
	# exact recorded string, admitting just its single visible line geometry.
	if shown=="Background Music\n" and spec.get("overflow")==1:
		shown=shown.trim_suffix("\n")
	var points: float = spec.size
	var spacing := 7.0*points*0.01 if bold else 0.0
	var distance := 0.0
	var scale := 0.0
	var boxes: Array[Dictionary] = []
	for i in range(shown.length()):
		var glyph: Dictionary = atlas.layout_glyph(shown.unicode_at(i),points,Vector2(distance,0),bold)
		if glyph.is_empty(): return {}
		if i==0: scale = glyph.glyph_scale
		if glyph.glyph_scale!=scale: return {} # original visible glyphs all share the same scale
		boxes.append(glyph)
		distance += glyph.advance
		if i+1<shown.length(): distance += spacing
	if distance>bounds.size.x: return {} # not a multiline TMP implementation
	var center := bounds.get_center()
	var start_x := bounds.position.x
	if centered: start_x = center.x-distance/2.0
	if right_aligned: start_x = bounds.end.x-distance
	var y: float = atlas.top_baseline(bounds.position.y,scale) if top else atlas.middle_baseline(center.y,scale)
	var baseline := Vector2(start_x,y)
	for glyph in boxes:
		glyph.destination.position += baseline
	return {"text":shown,"bold":bold,"glyph_scale":scale,"baseline":baseline,"width":distance,"quads":boxes}

func _draw() -> void:
	if _atlas == null: return
	for glyph in _line.quads:
		if glyph.destination.has_area():
			draw_texture_rect_region(_atlas.texture,glyph.destination,glyph.region,Color.WHITE,false,false)
