extends Node2D
## 原场景基础地面与 Grass 覆盖。每格 Sprite2D 用于保留原 Tile 的逐格透明度，
## 不擦除作者格、不生成焦土，也不另建碰撞/导航。静态装饰、湖草与可燃覆盖分别注册。
const BASE_MANIFEST_SHA256 := "8029f8cd8084d4431b9c29b7742520ccc93dd66e60c878f7a55d33dfa0747e63"
const SHADOW_MANIFEST_SHA256 := "8dc2f663c559186bc19c76c056431610badce287036f38c9ccc9ed9b8c66c040"
const PILLAR_MANIFEST_SHA256 := "72c5606eb476b9414d34adbd314362e349084c1beb06af6f315f24b9fe9f8ae5"
const HORIZONTAL_WALL_MANIFEST_SHA256 := "4b7f1216d907a2fb783ef496fcaaacdbd8a984b9314b64710eda93e5cbb3c6bc"
const WALL_AND_CLIFF_MANIFEST_SHA256 := "7c0e6adedad2486a5da45c30ca58094468a4e94fc18a35074862636338635056"
const GROUPED_TREE_MANIFEST_SHA256 := "2d67f9c4d46c564ebb823a07468b5c53b58e6dc57487be4e32e25f801e1d0a89"
const LOW_PROP_MANIFEST_SHA256 := "60f578fa179c4c7bb858c6ea83a5377bf0a795966dd705f74b6f901605ebda61"
const COVER_SOURCES := [0,10,20,30,31]
var _cells: Dictionary = {}
var _lakegrass: Dictionary = {}
var _water_base: Dictionary = {}
var _static_decorations: Dictionary = {}
var _shadow_layers: Dictionary = {}
var _pillars: Dictionary = {}
var _low_props: Dictionary = {}
var _configured := false
var _textures: Dictionary = {}
var _tree_groups: Dictionary = {}
var _reflection_tree_candidate: Node2D
var _reflection_tree: Node2D
var _base_water_material: CanvasItemMaterial

func configure(directory: String) -> bool:
	if _configured: return false
	var path := directory.path_join("ground.json")
	if not FileAccess.file_exists(path): return false
	if FileAccess.get_sha256(path) not in [BASE_MANIFEST_SHA256,SHADOW_MANIFEST_SHA256,PILLAR_MANIFEST_SHA256,HORIZONTAL_WALL_MANIFEST_SHA256,WALL_AND_CLIFF_MANIFEST_SHA256,GROUPED_TREE_MANIFEST_SHA256,LOW_PROP_MANIFEST_SHA256]: return false
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
			_add_static_tile(row, int(layer.sorting_order), frames, data.sprites, _cells[source])
		if layer.has("static_decorations"):
			_static_decorations[source] = {}
			for row in layer.static_decorations:
				_add_static_tile(row, int(layer.sorting_order), frames, data.sprites, _static_decorations[source])
		if layer.has("decorations"):
			_add_animated_tiles(layer.decorations, int(layer.sorting_order), frames, data.sprites, _lakegrass)
	# 原纯显示阴影另存，不能误进可移除的植被阴影来源31。
	for layer in data.get("shadow_layers",[]):
		var tilemap_id := int(layer.tilemap_id)
		var layer_registry := {}
		for row in layer.rows:
			_add_static_tile(row, int(layer.sorting_order),frames,data.sprites,layer_registry)
		_shadow_layers[tilemap_id] = layer_registry
	# 只安装原墙体显示，碰撞仍属于独立的原 Default 几何。
	var structures: Array = data.get("walls",[])+data.get("cliff_bodies",[])
	if data.has("horizontal_wall"): structures.append(data.horizontal_wall)
	for layer in structures:
		var registry := {}
		for row in layer.rows:
			_add_static_tile(row,int(layer.sorting_order),frames,data.sprites,registry)
		_static_decorations[int(layer.tilemap_id)]=registry
	# 柱身和阴影没有 SortingGroup。位置一致，排序各自保留。
	for row in data.get("pillars",[]):
		var pillar_id := int(row.collider_id)
		var pillar := Node2D.new()
		pillar.name = "SourcePillar%d"%int(row.object_id)
		pillar.position = Vector2(row.position[0],-row.position[1])
		pillar.set_meta("source_box_id",pillar_id)
		pillar.set_meta("source_variant",int(row.variant))
		add_child(pillar)
		for part in ["body","shadow"]:
			var authored: Dictionary = row[part]
			var sprite := _static_atlas_sprite(frames[authored.sprite],data.sprites[authored.sprite],int(authored.sorting_order))
			sprite.name=part
			sprite.z_as_relative=false
			sprite.set_meta("source_renderer_id",int(authored.renderer_id))
			pillar.add_child(sprite)
		_pillars[pillar_id]=pillar
	# SortingGroup 外部只按组排序；阴影在同组内先绘制，不把 -7 设成全局顺序。
	for row in data.get("trees",[]):
		var group := Node2D.new()
		group.name="SourceTreeGroup%d"%int(row.group_id)
		group.position=Vector2(row.position[0],-row.position[1])
		group.z_index=int(row.order)
		group.set_meta("source_box_id",int(row.collider_id))
		add_child(group)
		for part in ["shadow","body"]:
			var entry: Dictionary = row[part]
			var sprite:=_static_atlas_sprite(frames[entry.sprite],data.sprites[entry.sprite],0)
			sprite.name=part
			sprite.position=Vector2(-.125,0) if part=="shadow" else Vector2.ZERO
			sprite.set_meta("source_renderer_id",int(entry.renderer_id))
			sprite.set_meta("source_inner_order",int(entry.inner_order))
			group.add_child(sprite)
		_tree_groups[int(row.collider_id)]=group
		if row.reflection: _reflection_tree_candidate=group
	# Creeper/Cattail have ordinary SpriteRenderers, not tree SortingGroups.
	# Neither renderer enters the terrain, reflector, or static collision registries.
	for row in data.get("low_props",[]):
		var object_id := int(row.object_id)
		var prop := Node2D.new()
		prop.name = "Source%s%d"%[row.kind,object_id]
		prop.position = Vector2(row.position[0],-row.position[1])
		prop.set_meta("source_variant",int(row.selection))
		add_child(prop)
		for part in ["body","shadow"]:
			var entry: Dictionary = row[part]
			var sprite := _static_atlas_sprite(frames[entry.sprite],data.sprites[entry.sprite],int(entry.sorting_order))
			sprite.name = part
			sprite.z_as_relative = false
			sprite.position = Vector2(entry.offset[0],-entry.offset[1])
			sprite.set_meta("source_renderer_id",int(entry.renderer_id))
			prop.add_child(sprite)
		_low_props[object_id] = prop
	# Original water compositor at reflection alpha zero: unlit authored base
	# with unchanged sprite alpha. Actual reflected contributions are separate.
	_base_water_material = CanvasItemMaterial.new()
	_base_water_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_add_animated_tiles(data.water_base, int(data.water_base.sorting_order), frames, data.sprites,
		_water_base, _base_water_material)
	_textures = textures
	_configured = true
	return true

func _add_static_tile(row: Dictionary, sorting_order: int, textures: Dictionary,
		metadata: Dictionary, registry: Dictionary) -> void:
	var cell := Vector3i(int(row.cell[0]),int(row.cell[1]),int(row.cell[2]))
	var sprite := _static_atlas_sprite(textures[row.sprite],metadata[row.sprite],sorting_order)
	var shift: Array = row.get("translation", [0,0])
	sprite.position = Vector2(cell.x+.5+shift[0],-cell.y-.5-shift[1])
	add_child(sprite)
	registry[cell] = sprite

func _static_atlas_sprite(texture: Texture2D, pose: Dictionary, sort_order: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = Vector2(-pose.pivot[0]*pose.rect[2],-(1.0-pose.pivot[1])*pose.rect[3])
	sprite.scale = Vector2.ONE / float(pose.ppu)
	sprite.z_index = sort_order
	return sprite

func pillar_for_collider(collider_id: int) -> Node2D:
	return _pillars.get(collider_id)

func pillar_count() -> int:
	return _pillars.size()

func low_prop_for_object(object_id: int) -> Node2D:
	return _low_props.get(object_id)

func low_prop_count() -> int:
	return _low_props.size()

func static_decoration_sprite(source: int, cell: Vector3i) -> Sprite2D:
	return _static_decorations.get(source, {}).get(cell)

func static_decoration_count(source: int) -> int:
	return _static_decorations.get(source, {}).size()

func shadow_sprite(tilemap_id: int, cell: Vector3i) -> Sprite2D:
	return _shadow_layers.get(tilemap_id,{}).get(cell)

func shadow_count(tilemap_id: int) -> int:
	return _shadow_layers.get(tilemap_id,{}).size()

func _add_animated_tiles(data: Dictionary, sorting_order: int, textures: Dictionary,
		metadata: Dictionary, registry: Dictionary, material_override: Material = null) -> void:
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
		if material_override != null: sprite.material = material_override
		add_child(sprite)
		registry[cell] = sprite

func water_base_sprite(cell: Vector3i) -> AnimatedSprite2D:
	return _water_base.get(cell)

func water_base_count() -> int:
	return _water_base.size()

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

func tree_group_count() -> int:
	return _tree_groups.size()

func tree_group_for_collider(collider_id: int) -> Node2D:
	return _tree_groups.get(collider_id)

## 锁定 ClickMoveTest Tree：独立实际场景对象，不把附近树形 Tile 当作 987751660。
## 父 SortingGroup 顺序 1；组内 Shadow(-7) 在 Tree(0) 前画且不参加倒影。
func install_reflection_tree() -> Sprite2D:
	if not _configured or is_instance_valid(_reflection_tree): return null
	if is_instance_valid(_reflection_tree_candidate):
		_reflection_tree=_reflection_tree_candidate
		return _reflection_tree.get_node("body") as Sprite2D
	# 旧地面清单的单棵树仍可用于原独立反射验证。
	var foliage := _authored_tree_sprite("be785b53e8101134cb49e391918a7a82",Rect2(155,52,21,25))
	var shadow := _authored_tree_sprite("da4d732596845594e9b99bf9488ee15f",Rect2(153,51,23,27))
	if foliage==null or shadow==null:
		if foliage!=null: foliage.free()
		if shadow!=null: shadow.free()
		return null
	_reflection_tree = Node2D.new()
	_reflection_tree.name = "原树木 987751656"
	_reflection_tree.position = Vector2(-.4375,8.1875)
	_reflection_tree.z_index = 1
	add_child(_reflection_tree)
	shadow.name = "原树影 843448604"
	shadow.position = Vector2(-.125,0)
	_reflection_tree.add_child(shadow)
	foliage.name = "原倒影树 987751660"
	_reflection_tree.add_child(foliage)
	return foliage

func _authored_tree_sprite(key: String, unity_rect: Rect2) -> Sprite2D:
	var atlas: Texture2D = _textures.get(key)
	if atlas==null or unity_rect.end.x>atlas.get_width() or unity_rect.end.y>atlas.get_height(): return null
	var frame := AtlasTexture.new()
	frame.atlas = atlas
	frame.region = Rect2(unity_rect.position.x,atlas.get_height()-unity_rect.end.y,unity_rect.size.x,unity_rect.size.y)
	frame.filter_clip = true
	var item := Sprite2D.new()
	item.texture = frame
	item.scale = Vector2.ONE/8.0
	item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return item

func set_water_capture_material(value: ShaderMaterial) -> void:
	# 单一作者水 Renderer 2080991805 的 87 格；不动底地和水生植被。
	for sprite: AnimatedSprite2D in _water_base.values():
		sprite.material = value if value!=null else _base_water_material

func rendered_water_bounds() -> Rect2:
	var result := Rect2()
	for sprite: AnimatedSprite2D in _water_base.values():
		if not sprite.is_visible_in_tree(): continue
		var tex := sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
		if tex==null: continue
		var footprint := sprite.global_transform * Rect2(sprite.offset,tex.get_size())
		result = footprint if not result.has_area() else result.merge(footprint)
	return result
