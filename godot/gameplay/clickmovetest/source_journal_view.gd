extends Control
## Actual fresh ClickMoveTest Journal only. No quest entries, default focus,
## sample text or fake scroll handle are inserted in the unseeded Journal.
const Line := preload("res://gameplay/clickmovetest/source_pause_text_line.gd")
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
const Tiled := preload("res://gameplay/clickmovetest/source_menu_tiled_image.gd")
const Art := preload("res://gameplay/clickmovetest/source_inventory_sprite.gd")
const Layout := preload("res://gameplay/clickmovetest/source_character_selectables.gd")
const JOURNAL_HASH := "40a4aaf12e3b8c3d25accf2893ea442d391ce22971272161b27a8a52571a6f26"
const SIZE := Vector2(1920,1080)
var _background: Tiled
var _atlas := Atlas.new()
var _center: Control
var _right: Control
var _lines: Array[Line] = []
var _frames: Array[Art] = []
var _viewports: Array[Control] = []

func _init() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_IGNORE

static func load_layout(directory: String) -> Dictionary:
	var path := directory.path_join("journal-layout.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=JOURNAL_HASH: return {}
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func bind(layout: Dictionary, pause: Dictionary, directory: String) -> bool:
	if _background!=null or layout.get("source_commit")!=Atlas.SOURCE or layout.get("registration")!=4 \
			or layout.get("pause_action")!=2 or not _atlas.bind(pause,directory.path_join("pause-font-atlas.bin")): return false
	var data := pause.duplicate()
	var tile: Dictionary=layout.tile
	data.tiled_images={"Journal Background":{"sprite_id":tile.id,"fill_center":true,"ppu_multiplier":1,
		"color":{"r":1,"g":1,"b":1,"a":1}}}
	data.sprites={tile.id:tile}
	_background=Tiled.new()
	add_child(_background)
	if not _background.bind(data,directory.path_join("SPS_GUI.png"),"Journal Background"): return false
	_background.size=SIZE
	_center=_group()
	_right=_group()
	var texture := _background.get_atlas_texture()
	for panel: Dictionary in layout.backgrounds:
		var node := Art.new()
		_place(node,Layout._rect(panel.rect))
		node.show_sprite(texture,panel.sprite,true)
		_center.add_child(node)
		_frames.append(node)
	for box: Array in layout.empty_viewports:
		var viewport := Control.new()
		viewport.mouse_filter=Control.MOUSE_FILTER_IGNORE
		viewport.clip_contents=true
		_place(viewport,Layout._rect(box))
		_center.add_child(viewport)
		_viewports.append(viewport)
	for spec: Dictionary in layout.labels:
		var line := Line.new()
		if not line.configure(_atlas,spec.text,Layout._rect(spec.rect),spec):
			line.free()
			return false
		var c: Dictionary=spec.color
		line.modulate=Color(c.r,c.g,c.b,c.a)
		var parent := _center if spec.anchor=="center" else (_right if spec.anchor=="right" else self)
		parent.add_child(line)
		_lines.append(line)
	return true

func _group() -> Control:
	var node := Control.new()
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func _place(node: Control, box: Rect2) -> void:
	node.position=box.position
	node.size=box.size

func fit_viewport(viewport: Vector2, screen_pixels := 1.0) -> void:
	if not viewport.is_finite() or viewport.x<=0.0 or viewport.y<=0.0: return
	var units := viewport.y/SIZE.y
	var width := viewport.x/units
	scale=Vector2.ONE*units
	_background.size=Vector2(width,SIZE.y)
	_center.position.x=(width-SIZE.x)*.5
	_right.position.x=width-SIZE.x
	for line in _lines: line.set_canvas_pixel_scale(screen_pixels*units)

func apply_stack_interactions(active: bool) -> void: visible=active
func try_focus_default_target() -> bool: return false
func try_handle_back_request() -> bool: return false
func allows_stack_close() -> bool: return true
