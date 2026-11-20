extends Control
## Shared Overlay sibling after Menus, not a child of Inventory or a tooltip
## following the pointer. Only the pinned initial items are currently bound.
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
const Text := preload("res://gameplay/clickmovetest/source_character_text.gd")
const Art := preload("res://gameplay/clickmovetest/source_inventory_sprite.gd")
const Layout := preload("res://gameplay/clickmovetest/source_character_selectables.gd")
const CONTRACT_SHA := "46a19bd7a17aa20cb531c76420d9f76847e5a0ad9f65492bf3e4d11adc8820dd"
var shown_type := -1
var _atlas := Atlas.new()
var _silver: FontFile
var _items := {}
var _definition: Dictionary
var _hit: Array[Rect2] = []
var _title: Text
var _description: Text
var _icon: Art
var _pixel_scale := 1.0

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	hide()

static func load_layout(directory: String) -> Dictionary:
	var path := directory.path_join("item-details-layout.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=CONTRACT_SHA: return {}
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func bind(spec: Dictionary, pause: Dictionary, directory: String, silver_path: String, texture: Texture2D) -> bool:
	if not _definition.is_empty() or spec.get("source_commit")!=Atlas.SOURCE or texture==null: return false
	_silver=Text.load_silver(silver_path)
	if _silver==null or not _atlas.bind(pause,directory.path_join("pause-font-atlas.bin")): return false
	for item: Dictionary in spec.items:
		var path := directory.path_join(item.icon_file)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=item.icon_sha256: return false
		var image := Image.load_from_file(path)
		if image==null or image.get_size()!=Vector2i(32,32): return false
		if Text.layout(_atlas,item.name,Layout._rect(spec.name.rect),spec.name).is_empty() or \
				Text.layout(_atlas,item.description,Layout._rect(spec.description.rect),spec.description).is_empty(): return false
		var data := item.duplicate()
		data.texture=ImageTexture.create_from_image(image)
		_items[int(item.type)]=data
	_definition=spec
	_add_background(spec.body)
	_add_frame(spec.body_frame,texture)
	_add_background(spec.header)
	_add_frame(spec.header_frame,texture)
	_icon=Art.new()
	var icon_box := Layout._rect(spec.icon)
	_icon.position=icon_box.position
	_icon.size=icon_box.size
	add_child(_icon)
	_title=_add_text(spec.name)
	_description=_add_text(spec.description)
	return true

func _tint(spec: Dictionary) -> Color:
	var c: Dictionary=spec.color
	return Color(c.r,c.g,c.b,c.a)

func _add_background(spec: Dictionary) -> void:
	var node := ColorRect.new()
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var box := Layout._rect(spec.rect)
	node.position=box.position
	node.size=box.size
	node.color=_tint(spec)
	add_child(node)
	_hit.append(box)

func _add_frame(spec: Dictionary,texture: Texture2D) -> void:
	var node := Art.new()
	var box := Layout._rect(spec.rect)
	node.position=box.position
	node.size=box.size
	node.show_sprite(texture,spec.sprite,true)
	add_child(node)
	_hit.append(box)

func _add_text(spec: Dictionary) -> Text:
	var node := Text.new()
	node.modulate=_tint(spec)
	add_child(node)
	_hit.append(Layout._rect(spec.rect))
	return node

func fit_viewport(viewport: Vector2, pixels: float) -> void:
	if not viewport.is_finite() or viewport.x<=0.0 or viewport.y<=0.0: return
	var units := viewport.y/1080.0
	position=Vector2((viewport.x-1920.0*units)*.5,0)
	scale=Vector2.ONE*units
	_pixel_scale=pixels*units
	if visible:
		_title.set_canvas_pixel_scale(_pixel_scale)
		_description.set_canvas_pixel_scale(_pixel_scale)

func intercepts_point(p: Vector2) -> bool:
	if not visible or not p.is_finite(): return false
	var point := (p-position)/scale
	for box in _hit:
		if box.has_point(point): return true
	return false

func select_gear(kind: int) -> void:
	var item: Dictionary = _items.get(kind,{})
	if item.is_empty():
		shown_type=-1
		hide()
		return
	if shown_type==kind: return
	var title: Dictionary=_definition.name
	var description: Dictionary=_definition.description
	if not _title.configure(_atlas,_silver,item.name,Layout._rect(title.rect),title,_pixel_scale) or \
			not _description.configure(_atlas,_silver,item.description,Layout._rect(description.rect),description,_pixel_scale):
		shown_type=-1
		hide()
		return
	_icon.show_sprite(item.texture,{},false)
	shown_type=kind
	show()
