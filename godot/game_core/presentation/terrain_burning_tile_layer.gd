extends TileMapLayer
## ClickMoveTest temporary effects Tilemap 1655698545. Authored art is private.
## Godot atlas animation represents source ordered 8 FPS; engine clock/material
## and cross-renderer ordering are not Unity frame/pixel parity assertions.
const ORIGINAL_SHA256 := "3fb1a094f66e6e9d6c18f53d2dbc7cc78283eddb1ecf35a4621222856fa6146e"
const FRAME_EDGE := 32
const FIRE_TILE := "burning"
const ATLAS := 0

func configure(path: String) -> bool:
	if tile_set != null or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != ORIGINAL_SHA256:
		return false
	var image := Image.load_from_file(path)
	if image == null: return false
	var extent := image.get_size()
	if extent.x < FRAME_EDGE or extent.y < FRAME_EDGE or extent.x % FRAME_EDGE != 0 or extent.y % FRAME_EDGE != 0:
		return false
	var columns := floori(float(extent.x) / FRAME_EDGE)
	var rows := floori(float(extent.y) / FRAME_EDGE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = Vector2i(FRAME_EDGE,FRAME_EDGE)
	atlas.create_tile(Vector2i.ZERO)
	atlas.set_tile_animation_columns(Vector2i.ZERO,columns)
	atlas.set_tile_animation_frames_count(Vector2i.ZERO,columns*rows)
	atlas.set_tile_animation_speed(Vector2i.ZERO,8.0)
	var source := TileSet.new()
	source.tile_size = Vector2i(FRAME_EDGE,FRAME_EDGE)
	source.add_source(atlas,ATLAS)
	tile_set = source
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	scale = Vector2.ONE / float(FRAME_EDGE)
	collision_enabled = false
	navigation_enabled = false
	return true

static func cell_coordinate(cell: Vector3i) -> Vector2i:
	# Unity Default grid pivot (.5,.5), with project world Y inverted.
	return Vector2i(cell.x,-cell.y-1)

func set_source_tile(cell: Vector3i, tile: Variant) -> void:
	if tile_set == null or cell.z != 0: return
	var coordinate := cell_coordinate(cell)
	if tile == FIRE_TILE: set_cell(coordinate,ATLAS,Vector2i.ZERO)
	else: erase_cell(coordinate)
