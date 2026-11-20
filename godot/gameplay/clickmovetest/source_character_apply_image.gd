extends Control
## UICharacter Apply target Graphic: original Image.Type.Sliced and Button
## SpriteSwap. Uses the authenticated existing menu atlas, never a substitute.
const SOURCE := preload("res://gameplay/clickmovetest/source_menu_tiled_image.gd")
const STATES := {
	"normal": ["2007578060", Vector4(73,1,14,14), Vector4(2,2,2,2)],
	"highlighted": ["-467190130", Vector4(105,1,14,14), Vector4(2,2,2,2)],
	"pressed": ["419123229", Vector4(121,1,14,14), Vector4(2,2,2,3)],
	"selected": ["-467190130", Vector4(105,1,14,14), Vector4(2,2,2,2)],
	"disabled": ["-1772095805", Vector4(121,17,14,14), Vector4(2,2,2,2)],
}
const UNITS_PER_TEXEL := 6.0
var _atlas: Texture2D
var _state := "normal"

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func bind(contract: Variant, background: SOURCE) -> bool:
	if _atlas!=null or not contract is Dictionary or contract.size()!=STATES.size() or background==null: return false
	var texture := background.get_atlas_texture()
	if texture==null: return false
	for key in STATES:
		var canonical: Array = STATES[key]
		var actual: Variant = contract.get(key)
		if not actual is Dictionary or actual.get("id")!=canonical[0] or actual.get("pixel_size")!=UNITS_PER_TEXEL 				or not _matches(actual.get("rect"),canonical[1]) or not _matches(actual.get("border"),canonical[2]):
			return false
		var source_rect: Vector4 = canonical[1]
		if not Rect2(Vector2.ZERO,texture.get_size()).encloses(
				Rect2(source_rect.x,texture.get_height()-source_rect.y-source_rect.w,source_rect.z,source_rect.w)):
			return false
	_atlas=texture
	queue_redraw()
	return true

static func _matches(raw: Variant, expected: Vector4) -> bool:
	if not raw is Array or raw.size()!=4: return false
	for i in range(4):
		if typeof(raw[i]) not in [TYPE_INT,TYPE_FLOAT] or raw[i]!=expected[i]: return false
	return true

func show_button_state(value: String) -> void:
	if value==_state or not STATES.has(value): return
	_state=value
	queue_redraw()

static func _axis(length: float, texels: float, near: float, far: float) -> Array[Vector4]:
	var s := minf(UNITS_PER_TEXEL,length/(near+far))
	var start := near*s
	var end := length-far*s
	return [Vector4(0,start,0,near),Vector4(start,end-start,near,texels-near-far),
		Vector4(end,length-end,texels-far,far)]

func patches(destination_size: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _atlas==null or not destination_size.is_finite() or destination_size.x<=0 or destination_size.y<=0: return result
	var r: Vector4 = STATES[_state][1]
	var b: Vector4 = STATES[_state][2] # Unity left, bottom, right, top order
	var atlas_top := _atlas.get_height()-r.y-r.w
	for y in _axis(destination_size.y,r.w,b.w,b.y):
		for x in _axis(destination_size.x,r.z,b.x,b.z):
			if x.y<=0 or y.y<=0: continue
			result.append({"destination":Rect2(x.x,y.x,x.y,y.y),
				"source":Rect2(r.x+x.z,atlas_top+y.z,x.w,y.w)})
	return result

func _notification(what: int) -> void:
	if what==NOTIFICATION_RESIZED: queue_redraw()

func _draw() -> void:
	for patch in patches(size):
		draw_texture_rect_region(_atlas,patch.destination,patch.source)
