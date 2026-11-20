extends Control
## Source Image.Simple / Image.Sliced in Canvas units. Atlas Unity Y is bottom-up.
const Slicing := preload("res://gameplay/clickmovetest/source_character_apply_image.gd")
var _texture: Texture2D
var _region := Rect2()
var _border := Vector4.ZERO
var _sliced := false

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func show_sprite(texture: Texture2D, spec: Dictionary, sliced: bool) -> void:
	_texture=texture
	_sliced=sliced
	if spec.is_empty():
		_region=Rect2(Vector2.ZERO,texture.get_size())
	else:
		var r: Dictionary=spec.rect
		_region=Rect2(r.x,texture.get_height()-r.y-r.height,r.width,r.height)
		var b: Dictionary=spec.border
		_border=Vector4(b.x,b.y,b.z,b.w)
	queue_redraw()

func _draw() -> void:
	if _texture==null: return
	if not _sliced:
		draw_texture_rect_region(_texture,Rect2(Vector2.ZERO,size),_region)
		return
	for y in Slicing._axis(size.y,_region.size.y,_border.w,_border.y):
		for x in Slicing._axis(size.x,_region.size.x,_border.x,_border.z):
			if x.y<=0 or y.y<=0: continue
			draw_texture_rect_region(_texture,Rect2(x.x,y.x,x.y,y.y),Rect2(
				_region.position+Vector2(x.z,y.z),Vector2(x.w,y.w)))

func _notification(what: int) -> void:
	if what==NOTIFICATION_RESIZED: queue_redraw()
