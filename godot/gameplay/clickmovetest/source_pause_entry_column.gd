extends Control
## Reference-Canvas rendering of UIGameMenu's original left-hand column.
## This is not the menu owner: no input, focus, actions, TMP labels or scaling.
const Tiled := preload("res://gameplay/clickmovetest/source_menu_tiled_image.gd")
const ACTIONS := [5,1,4,2,6,3,7,8]
const IDS := ["2054828684","416732651","2059989182","-827782456","31728771","811364011","2143314096","1726937278"]
var _atlas: ImageTexture
var _icons: Array[Dictionary] = []
var _tint: Color
var _icon_layer: Control
var _tints: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func bind(data: Dictionary, png: String) -> bool:
	if _atlas != null: return false
	var layout: Variant = data.get("entry_layout")
	var sprites: Variant = data.get("sprites")
	if not layout is Dictionary or layout.get("craft_available",true) != false or not sprites is Dictionary:
		return false
	var rows: Variant = layout.get("rows")
	if not rows is Array or rows.size()!=8: return false
	var tints: Variant = layout.get("tints")
	if not tints is Dictionary: return false
	var normal: Variant = tints.get("m_NormalColor")
	if not normal is Dictionary or normal != {"r":0.24705882,"g":0.15686275,"b":0.19607843,"a":1.0}:
		return false
	var body := _rect(layout.get("body_rect"))
	var border := _rect(layout.get("frame_rect"))
	if body != Rect2(40,260,80,560) or border != Rect2(8,228,144,624): return false
	var body_image := Tiled.new()
	var border_image := Tiled.new()
	if not body_image.bind(data,png,"Menu Items") or not border_image.bind(data,png,"Frame"):
		body_image.free()
		border_image.free()
		return false
	var tex: ImageTexture = body_image.get_atlas_texture()
	var resolved: Array[Dictionary] = []
	for i in range(rows.size()):
		var entry: Variant = rows[i]
		if not entry is Dictionary or entry.get("action") != ACTIONS[i] or entry.get("sprite_id") != IDS[i] \
				or entry.get("authored_active") != true or entry.get("visible") != (i != 4):
			break
		if i == 4: continue
		var sprite: Variant = sprites.get(IDS[i])
		if not sprite is Dictionary or not sprite.get("rect") is Dictionary: break
		var r: Dictionary = sprite.rect
		var from := _rect([r.get("x"),r.get("y"),r.get("width"),r.get("height")])
		if from.size != Vector2(8,8): break
		from.position.y = tex.get_height() - from.end.y
		if not Rect2(Vector2.ZERO,tex.get_size()).encloses(from): break
		var y := body.position.y + 80.0*resolved.size()
		var hitbox := _rect(entry.get("rect"))
		var to := _rect(entry.get("icon_rect"))
		var label := _rect(entry.get("label_rect"))
		if hitbox != Rect2(40,y,80,80) or to != Rect2(56,y+16,48,48) or label != Rect2(168,y+8,256,64):
			break
		if not entry.get("label") is String or entry.label.is_empty() or not entry.get("action_name") is String: break
		resolved.append({"action":int(entry.action),"action_name":entry.action_name,"label":entry.label,
			"hitbox":hitbox,"icon":to,"label_rect":label,"region":from})
	if resolved.size()!=7:
		body_image.free()
		border_image.free()
		return false
	body_image.position = body.position
	body_image.size = body.size
	border_image.position = border.position
	border_image.size = border.size
	add_child(body_image)
	add_child(border_image)
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.draw.connect(_draw_icons.bind(layer))
	add_child(layer)
	_icon_layer = layer
	_atlas = tex
	_tint = Color(normal.r,normal.g,normal.b,normal.a)
	_icons = resolved
	layer.queue_redraw()
	return true

func entries() -> Array[Dictionary]:
	return _icons.duplicate(true)

func set_entry_tint(action: int, tint: Color) -> void:
	if _icon_layer == null: return
	_tints[action] = tint
	_icon_layer.queue_redraw()

func _draw_icons(layer: Control) -> void:
	if _atlas == null: return
	for entry in _icons:
		layer.draw_texture_rect_region(_atlas,entry.icon,entry.region,_tints.get(entry.action,_tint))

static func _rect(fields: Variant) -> Rect2:
	if not fields is Array or fields.size()!=4: return Rect2()
	for field in fields:
		if typeof(field) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(field): return Rect2()
	return Rect2(fields[0],fields[1],fields[2],fields[3])
