extends Node2D
## 原场景基础地面与 Grass 覆盖。每格 Sprite2D 用于保留原 Tile 的逐格透明度，
## 不擦除作者格、不生成焦土，也不另建碰撞/导航。湖草动画与可燃覆盖分别注册。
const MANIFEST_SHA256 := "6f917225436508339bad265af26df8b0f578a3ff1cd9e020c48e51d8f0e464e5"
const COVER_SOURCES := [0,10,20,30,31]
var _cells: Dictionary = {}
var _lakegrass: Dictionary = {}
var _configured := false

func configure(directory: String) -> bool:
	if _configured: return false
	var path := directory.path_join("ground.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != MANIFEST_SHA256: return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return false
	var textures: Dictionary = {}
	for key in data.textures:
		var item: Dictionary = data.textures[key]
		var file := directory.path_join(item.file)
		if not FileAccess.file_exists(file) or FileAccess.get_sha256(file) != item.sha256: return false
		var image := Image.load_from_file(file)
		if image == null: return false
		textures[key] = ImageTexture.create_from_image(image)
	var frames: Dictionary = {}
	for key in data.sprites:
		var item: Dictionary = data.sprites[key]
		var frame := AtlasTexture.new()
		frame.atlas = textures[item.texture]
		# Unity rect 原点在左下，Godot 图片原点在左上；不翻转图片本身。
		frame.region = Rect2(item.rect[0],frame.atlas.get_height()-item.rect[1]-item.rect[3],item.rect[2],item.rect[3])
		frame.filter_clip = true
		frames[key] = frame
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	for layer in data.layers:
		var source := int(layer.source_id)
		_cells[source] = {}
		for row in layer.rows:
			var cell := Vector3i(int(row.cell[0]),int(row.cell[1]),int(row.cell[2]))
			var metadata: Dictionary = data.sprites[row.sprite]
			var sprite := Sprite2D.new()
			sprite.texture = frames[row.sprite]
			sprite.centered = false
			sprite.offset = Vector2(-metadata.pivot[0]*metadata.rect[2],-(1.0-metadata.pivot[1])*metadata.rect[3])
			sprite.scale = Vector2.ONE / float(metadata.ppu)
			var shift: Array = row.get("translation", [0,0])
			sprite.position = Vector2(cell.x+.5+shift[0],-cell.y-.5-shift[1])
			sprite.z_index = int(layer.sorting_order)
			add_child(sprite)
			_cells[source][cell] = sprite
		if layer.has("decorations"):
			_add_lakegrass(layer.decorations, int(layer.sorting_order), frames, data.sprites)
	_configured = true
	return true

func _add_lakegrass(data: Dictionary, sorting_order: int, textures: Dictionary, metadata: Dictionary) -> void:
	var shared: Dictionary = {}
	for row in data.rows:
		var cell := Vector3i(int(row.cell[0]),int(row.cell[1]),int(row.cell[2]))
		var key := JSON.stringify(row.frames)
		if not shared.has(key):
			var anim := SpriteFrames.new()
			anim.set_animation_speed(&"default", float(data.frames_per_second))
			anim.set_animation_loop(&"default", true)
			for id in row.frames: anim.add_frame(&"default", textures[id])
			shared[key] = anim
		var pose: Dictionary = metadata[row.frames[0]]
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = shared[key]
		sprite.centered = false
		sprite.offset = Vector2(-pose.pivot[0]*pose.rect[2],-(1.0-pose.pivot[1])*pose.rect[3])
		sprite.scale = Vector2.ONE / float(pose.ppu)
		sprite.position = Vector2(cell.x+.5,-cell.y-.5)
		sprite.z_index = sorting_order
		sprite.autoplay = &"default"
		add_child(sprite)
		_lakegrass[cell] = sprite

func lakegrass_sprite(cell: Vector3i) -> AnimatedSprite2D:
	return _lakegrass.get(cell)

func lakegrass_count() -> int:
	return _lakegrass.size()

func cover_port() -> Dictionary:
	return {"mapped_cover_sources":mapped_cover_sources,"source_available":source_available,
		"set_cover_alpha":set_cover_alpha,"unlock_cover_cell":unlock_cover_cell}

func mapped_cover_sources(cell: Vector3i) -> Array:
	var sources: Array = []
	if not _configured: return sources
	for source in COVER_SOURCES:
		if _cells[source].has(cell): sources.append(source)
	return sources

func source_available(source: int) -> bool:
	# 基础地面不属于可移除覆盖。
	return _configured and source in COVER_SOURCES and _cells.has(source)

func set_cover_alpha(source: int, cell: Vector3i, alpha: float) -> void:
	if not source_available(source) or not _cells[source].has(cell): return
	var sprite: Sprite2D = _cells[source][cell]
	var color := sprite.self_modulate
	color.a = alpha
	sprite.self_modulate = color

func unlock_cover_cell(_source: int, _cell: Vector3i) -> void:
	# Sprite2D 原生不具备 Unity TileFlags.LockColor，逐格颜色始终可写。
	pass

func source_sprite(source: int, cell: Vector3i) -> Sprite2D:
	return _cells.get(source,{}).get(cell)

func cell_count(source: int) -> int:
	return _cells.get(source,{}).size()
