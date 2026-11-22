extends "res://tests/test_clickmovetest_element_surface.gd"
const STRUCTURE_IDS := [1289053702,163064786,2118149258,432984437,147438656]
const Ground = preload("res://gameplay/clickmovetest/ground_layers.gd")
func run() -> void:
	var rejected := Ground.new()
	check(not rejected.configure("res://"),"缺少私有原地面目录必须拒绝，不造替代草图")
	check(rejected.get_child_count()==0,"失败装配不留下半成品格")
	check(not rejected.source_available(0) and rejected.mapped_cover_sources(Vector3i.ZERO).is_empty(),"未配置层不冒充存在")
	rejected.free()
	var directory := OS.get_environment("FORMAL_GROUND_LAYERS")
	var rules := OS.get_environment("FORMAL_SURFACE_RULES")
	var assets := OS.get_environment("FORMAL_SURFACE_ASSETS")
	var fire_path := OS.get_environment("FORMAL_BURNING_TILE_PNG")
	if directory.is_empty() or rules.is_empty() or assets.is_empty() or fire_path.is_empty():
		print("PASS 原地面保护检查：%s 项；私有素材装配与燃尽图层验收未运行" % n)
		quit(failed)
		return
	var scene = Entry.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var owner := RuleMotion.new()
	var player := Player.new()
	player.actor = scene.actor
	var events := MapEvents.new()
	check(scene.start_logic(owner,read(rules),func():return player,func():return null,events,func(_p):return false),"原地图逻辑装配")
	check(scene.start_surface_elements(read(assets)),"原地图覆盖与反应装配")
	check(scene.bind_ground_layers(directory),"原 Entry 装配实际基础地面与覆盖图像")
	if scene.ground_layers==null:
		scene.free()
		quit(1)
		return
	var ground: Node2D = scene.ground_layers
	check(not scene.bind_ground_layers(directory),"重复装配拒绝，不堆叠第二份地图")
	check(ground.cell_count(-1)==900 and ground.cell_count(0)==547,"900 个基础格与547个作者覆盖格")
	check(not ground.source_available(-1) and ground.source_available(30) and ground.source_available(31),"基础地面不当作可删除覆盖，原植被与阴影可用")
	check(scene.bind_surface_presentation(fire_path),"现有地表控制器自动绑定实际逐格透明度")
	var terrain: RefCounted = scene.surface_elements
	check(ground.cell_count(10)==158 and ground.cell_count(20)==3,"来源10/20真实映射覆盖158/3格，不包含独立装饰")
	var road_cell := Vector3i(8,6,0)
	var road := ground.static_decoration_sprite(10,road_cell) as Sprite2D
	check(ground.static_decoration_count(10)==74 and ground.static_decoration_count(20)==10,
		"来源10/20装配固定装饰15/4格与原缓存装饰59/6格")
	var manifest_hash := FileAccess.get_sha256(directory.path_join("ground.json"))
	var all_structures := manifest_hash==Ground.WALL_AND_CLIFF_MANIFEST_SHA256
	var horizontal_wall := all_structures or manifest_hash==Ground.HORIZONTAL_WALL_MANIFEST_SHA256
	var combo_tiles: Array[Sprite2D] = []
	var samples := [[10, Vector3i(6,-5,0), 168], [10, Vector3i(7,-5,0), 104],
		[20, Vector3i(-6,13,0), 136]]
	for sample in samples:
		var source: int = sample[0]
		var cell: Vector3i = sample[1]
		var tile := ground.static_decoration_sprite(source,cell) as Sprite2D
		var atlas := tile.texture as AtlasTexture if tile!=null else null
		check(atlas!=null and atlas.region==Rect2(sample[2],atlas.atlas.get_height()-136,8,8)
			and tile.position==Vector2(cell.x+.5,-cell.y-.5) and tile.offset==Vector2(-4,-4)
			and tile.scale==Vector2(.125,.125) and tile.z_index==(-8 if source==10 else -1),
			"同一条原规则的三种缓存选图、原锚点及排序：%s" % cell)
		check(ground.source_sprite(source,cell)==null and not ground.mapped_cover_sources(cell).has(source),
			"石草混合装饰不是该来源的可燃覆盖：%s" % cell)
		if tile!=null: combo_tiles.append(tile)
	if DisplayServer.get_name()!="headless":
		for tile in combo_tiles:
			var cell:=Vector3i(floori(tile.position.x),floori(-tile.position.y),0)
			var occluders: Array[Sprite2D] = []
			# 原建筑覆盖部分石草；在诊断中隔离下层素材，正式叠放原样。
			for id in STRUCTURE_IDS:
				var top:=ground.static_decoration_sprite(id,cell) as Sprite2D
				if top!=null and top.z_index>tile.z_index:
					top.hide()
					occluders.append(top)
			await check_combo_pixels(scene.camera,tile,"原缓存装饰 %s"%cell)
			for top in occluders: top.show()
	var fixed_tiles := {
		Vector3i(-16,-6,0):Vector2i(64,128), Vector3i(-16,-5,0):Vector2i(64,136),
		Vector3i(-16,-4,0):Vector2i(64,144), Vector3i(-6,10,0):Vector2i(56,16),
		Vector3i(8,6,0):Vector2i(160,128), Vector3i(9,6,0):Vector2i(176,128),
		Vector3i(8,7,0):Vector2i(160,144), Vector3i(9,7,0):Vector2i(176,144)}
	for dirt_cell in [Vector3i(5,-6,0),Vector3i(12,-5,0),Vector3i(-14,-2,0),Vector3i(-10,-1,0),
			Vector3i(10,0,0),Vector3i(1,3,0),Vector3i(-10,5,0)]:
		fixed_tiles[dirt_cell] = Vector2i(40,160)
	for cell: Vector3i in fixed_tiles:
		var tile := ground.static_decoration_sprite(10,cell) as Sprite2D
		var atlas := tile.texture as AtlasTexture if tile != null else null
		var at: Vector2i = fixed_tiles[cell]
		check(atlas!=null and atlas.region==Rect2(at.x,atlas.atlas.get_height()-at.y-8,8,8)
			and tile.position==Vector2(cell.x+.5,-cell.y-.5) and tile.offset==Vector2(-4,-4)
			and tile.scale==Vector2(.125,.125) and tile.z_index==-8,"来自原作者图集的固定装饰：%s" % cell)
		check(not ground.mapped_cover_sources(cell).has(10),"固定装饰不加入来源10的可删除草：%s" % cell)
	check(scene.route.graph.contains_node(Vector4i(0,8,6,0)) and not scene.route.graph.contains_node(Vector4i(0,-6,10,0)),
		"石路和崖壁保留原规则格的可走与不可走区别")
	var shadow_cell := Vector3i(-6,10,0)
	var cliff_shadow := ground.static_decoration_sprite(20,shadow_cell) as Sprite2D
	var stairs: Array[Sprite2D] = []
	for y in [10,11,12]:
		var cell := Vector3i(-5,y,0)
		var stair := ground.static_decoration_sprite(20,cell) as Sprite2D
		stairs.append(stair)
		var atlas := stair.texture as AtlasTexture if stair != null else null
		check(atlas!=null and atlas.region==Rect2(24,atlas.atlas.get_height()-56-8*(y-10),8,8)
			and stair.position==Vector2(-4.5,-y-.5) and stair.offset==Vector2(-4,-4)
			and stair.scale==Vector2(.125,.125) and stair.z_index==-1,
			"来源20楼梯按原 Fixed/Single 匹配、原锚点和排序：%s" % cell)
		check(not scene.route.graph.contains_node(Vector4i(0,-5,y,0))
			and not ground.mapped_cover_sources(cell).has(20),
			"楼梯图像既不加入可走图也不加入可燃映射：%s" % cell)
	var shadow_frame := cliff_shadow.texture as AtlasTexture if cliff_shadow != null else null
	var cliff := ground.static_decoration_sprite(10,shadow_cell) as Sprite2D
	check(shadow_frame!=null and cliff!=null and shadow_frame.atlas!=(cliff.texture as AtlasTexture).atlas
		and shadow_frame.atlas.get_image().get_size()==Image.load_from_file(directory.path_join("TilesShadows.png")).get_size()
		and shadow_frame.region==Rect2(16,shadow_frame.atlas.get_height()-56,8,8)
		and cliff_shadow.position==cliff.position and cliff_shadow.z_index==-1 and cliff.z_index==-8,
		"悬崖顶阴影来自独立的原阴影图集，保留与下层崖缘同格排序")
	check(ground.mapped_cover_sources(shadow_cell).is_empty(),"崖缘和上层崖影都不是可燃映射")
	# 同一合同的旧版仍能打开，但不冒充已验证新增的42格。
	var shadow_manifest := horizontal_wall or manifest_hash in [Ground.SHADOW_MANIFEST_SHA256, Ground.PILLAR_MANIFEST_SHA256]
	if shadow_manifest:
		check(ground.shadow_count(1712506432)==35 and ground.shadow_count(1850812192)==7,
			"两套新增原作者阴影容量不混同来源31")
		for sample in [[1712506432,Vector3i(4,-5,0),-7,Vector2i(8,9)],
				[1850812192,Vector3i(-13,6,0),-1,Vector2i(16,56)]]:
			var cell: Vector3i = sample[1]
			var tile := ground.shadow_sprite(sample[0],cell) as Sprite2D
			var atlas := tile.texture as AtlasTexture if tile!=null else null
			var source_rect: Vector2i = sample[3]
			check(atlas!=null and atlas.atlas==shadow_frame.atlas
				and atlas.region==Rect2(source_rect.x,atlas.atlas.get_height()-source_rect.y-8,8,8)
				and tile.position==Vector2(cell.x+.5,-cell.y-.5) and tile.offset==Vector2(-4,-4)
				and tile.scale==Vector2(.125,.125) and tile.z_index==sample[2],
				"同一原阴影图集、独立层、原枢轴和世界格：%s" % cell)
			check(not ground.source_available(sample[0]) and not ground.mapped_cover_sources(cell).has(sample[0]),
				"阴影不受地表可燃覆盖控制")
			if tile!=null and DisplayServer.get_name()!="headless":
				await check_combo_pixels(scene.camera,tile,"两层原阴影 %s"%cell,true)
	else:
		check(ground.shadow_count(1712506432)==0 and ground.shadow_count(1850812192)==0,
			"旧合同仍加载，但未装配新增两层阴影")
	if horizontal_wall or manifest_hash==Ground.PILLAR_MANIFEST_SHA256:
		var data: Dictionary=read(directory.path_join("ground.json"))
		check(ground.pillar_count()==14 and data.pillars.size()==14,"原十四根柱子及各自独立柱影")
		for row: Dictionary in data.pillars:
			var pillar:=ground.pillar_for_collider(int(row.collider_id)) as Node2D
			var exact: bool = pillar!=null and pillar.position==Vector2(row.position[0],-row.position[1]) \
				and pillar.get_meta("source_variant")==int(row.variant)
			check(exact,"原柱位置、Box标识及作者变体 %s"%row.collider_id)
			if not exact: continue
			for part in ["body","shadow"]:
				var sprite:=pillar.get_node_or_null(part) as Sprite2D
				var info: Dictionary=data.sprites[row[part].sprite]
				var rect: Array=info.rect
				var atlas:=sprite.texture as AtlasTexture if sprite!=null else null
				check(atlas!=null and atlas.region==Rect2(rect[0],atlas.atlas.get_height()-rect[1]-rect[3],rect[2],rect[3])
					and sprite.position==Vector2.ZERO and sprite.scale==Vector2.ONE/8
					and sprite.offset==Vector2(-info.pivot[0]*rect[2],-(1.0-info.pivot[1])*rect[3])
					and not sprite.z_as_relative and sprite.z_index==int(row[part].sorting_order)
					and sprite.get_meta("source_renderer_id")==int(row[part].renderer_id),
					"原柱精灵引用、裁切、枢轴和排序 %s/%s"%[row.collider_id,part])
		if DisplayServer.get_name()!="headless":
			var p11:=ground.pillar_for_collider(325078254) as Node2D
			if p11!=null:
				await check_combo_pixels(scene.camera,p11.get_node("body"),"柱身 (11)",true)
				await check_combo_pixels(scene.camera,p11.get_node("shadow"),"独立柱影 (11)",true)
	else:
		check(ground.pillar_count()==0,"原地面历史清单不冒充已装配柱子")
	if horizontal_wall:
		var wall_id:=1289053702
		var cell:=Vector3i(6,-6,0)
		var tile:=ground.static_decoration_sprite(wall_id,cell) as Sprite2D
		var atlas:=tile.texture as AtlasTexture if tile!=null else null
		var data: Dictionary=read(directory.path_join("ground.json"))
		var wall_data: Dictionary=data.walls[0] if all_structures else data.horizontal_wall
		check(ground.static_decoration_count(wall_id)==56 and wall_data.rows.size()==56
			and not ground.source_available(wall_id),"56 格原横墙不属于可删除的地表覆盖")
		check(atlas!=null and atlas.region==Rect2(16,atlas.atlas.get_height()-33,8,8)
			and tile.position==Vector2(6.5,5.5) and tile.offset==Vector2(-4,-4)
			and tile.scale==Vector2(.125,.125) and tile.z_index==-5,
			"原横墙第 6,-6 格为规则命中图、原位置和排序")
		for row: Dictionary in wall_data.rows:
			var at:=Vector3i(row.cell[0],row.cell[1],row.cell[2])
			var original:=ground.static_decoration_sprite(wall_id,at) as Sprite2D
			var frame:=original.texture as AtlasTexture if original!=null else null
			var src: Array=data.sprites[row.sprite].rect
			check(frame!=null and atlas!=null and frame.atlas==atlas.atlas and frame.region==Rect2(src[0],frame.atlas.get_height()-src[1]-8,8,8)
				and original.position==Vector2(at.x+.5,-at.y-.5) and original.z_index==-5
				and not ground.mapped_cover_sources(at).has(wall_id),"原横墙图样与缓存 %s"%at)
		if tile!=null and DisplayServer.get_name()!="headless":
			await check_combo_pixels(scene.camera,tile,"原横墙 (6,-6)",true)
	else:
		check(ground.static_decoration_count(1289053702)==0,"旧私有合同不冒充有原横墙")
	if all_structures:
		var data: Dictionary=read(directory.path_join("ground.json"))
		var wall_body: Dictionary=data.walls[1]
		check_structure_layer(ground,data.sprites,wall_body,163064786,11,-6,{"fixed":4,"cached_random":7})
		check_structure_layer(ground,data.sprites,data.cliff_bodies[0],2118149258,72,-4,{"fixed":66,"standard":6})
		check_structure_layer(ground,data.sprites,data.cliff_bodies[1],432984437,47,-3,{"fixed":41,"standard":6})
		check_structure_layer(ground,data.sprites,data.cliff_bodies[2],147438656,32,-2,{"fixed":23,"standard":9})
		var mid_a := ground.static_decoration_sprite(163064786,Vector3i(11,0,0)) as Sprite2D
		var mid_b := ground.static_decoration_sprite(163064786,Vector3i(11,-1,0)) as Sprite2D
		check(mid_a!=null and mid_b!=null
			and (mid_a.texture as AtlasTexture).region.position.y!=(mid_b.texture as AtlasTexture).region.position.y,
			"原纵墙中段保留不同的锁定随机缓存，不用一张图代替")
		if DisplayServer.get_name()!="headless":
			for sample in [[163064786,Vector3i(11,0,0)],[2118149258,Vector3i(-5,1,0)],
					[432984437,Vector3i(0,2,0)],[147438656,Vector3i(-4,4,0)]]:
				var sprite := ground.static_decoration_sprite(sample[0],sample[1]) as Sprite2D
				if sprite!=null: await check_combo_pixels(scene.camera,sprite,"原纵墙/崖体 %s"%sample[0],true)
	var water_cell := Vector3i(-8,-10,0)
	var water := ground.water_base_sprite(water_cell) as AnimatedSprite2D
	check(ground.water_base_count()==87 and is_instance_valid(water),"原河湖水面底图87格，独立于35格 LakeGrass 装饰")
	if water==null:
		scene.free()
		quit(1)
		return
	var visited_water := 0
	var surviving_coverage := true
	for row in read(rules).rows:
		var c := Vector3i(int(row.cell[0]),int(row.cell[1]),int(row.cell[2]))
		if ground.water_base_sprite(c)==null: continue
		visited_water+=1
		surviving_coverage = surviving_coverage and row.surface==4 and not row.walkable \
			and not scene.route.graph.contains_node(Vector4i(0,c.x,c.y,c.z)) and ground.mapped_cover_sources(c).is_empty()
	check(visited_water==87 and surviving_coverage,"全体河湖保持原水地表、无作者映射覆盖且不可行走")
	check(water.position==Vector2(-7.5,9.5) and water.scale==Vector2(.125,.125) and water.offset==Vector2(-4,-4)
		and water.z_index==-9 and water.material.light_mode==CanvasItemMaterial.LIGHT_MODE_UNSHADED,"原水朝向、锚点、排序及无反射贡献时的不受光底图")
	check(water.sprite_frames.get_frame_count(&"default")==2 and water.is_playing()
		and water.sprite_frames.get_animation_speed(&"default")==1,"河湖固定两帧自动播放")
	for i in 2:
		var image := water.sprite_frames.get_frame_texture(&"default",i) as AtlasTexture
		check(image!=null and image.region==Rect2(200+32*i,image.atlas.get_height()-136,8,8),
			"原 RuleTile 首匹配水帧 %d" % i)
	check(not terrain.apply_point(Surface.FIRE,Vector2(-7.5,-9.5),1,.1,scene.actor,20010)
		and scene.surface_fire_tiles.get_used_cells().is_empty(),
		"原水域没有可燃草，不凭空加残火或改变水域")
	var water_frames: Array[int] = []
	water.frame_changed.connect(func():water_frames.append(water.frame))
	var lake_cell := Vector3i(0,-10,0)
	var lake: AnimatedSprite2D = ground.lakegrass_sprite(lake_cell)
	check(ground.lakegrass_count()==35 and is_instance_valid(lake),"原湖岸 LakeGrass 35 格独立装配")
	check(ground.source_sprite(10,lake_cell)==null and ground.mapped_cover_sources(lake_cell)==[0],
		"同格 source10 旁观动画不参与覆盖匹配")
	if not is_instance_valid(lake):
		scene.free()
		quit(1)
		return
	var animations := lake.sprite_frames
	check(lake.position==Vector2(.5,9.5) and lake.scale==Vector2(.125,.125)
		and lake.offset==Vector2(-4,-4) and lake.z_index==-8,"原矩形、绘制排序、8 PPU 与中心锚点")
	check(animations.get_frame_count(&"default")==2 and animations.get_animation_loop(&"default")
		and animations.get_animation_speed(&"default")==1 and lake.is_playing(),"原两帧顺序自动循环，单帧一秒")
	for i in 2:
		var atlas := animations.get_frame_texture(&"default",i) as AtlasTexture
		check(atlas!=null and atlas.region==Rect2(200+32*i,atlas.atlas.get_height()-152,8,8)
			and animations.get_frame_duration(&"default",i)==1,"实际 LakeGrass1 原图帧 %d，末帧缓存非首帧" % i)
	check(lake.frame==0,"Godot 附挂后的首帧是作者序列首帧")
	var seen: Array[int] = []
	lake.frame_changed.connect(func():seen.append(lake.frame))
	var selected := Vector3i.ZERO
	var found := false
	for row in read(rules).rows:
		var cell := Vector3i(int(row.cell[0]),int(row.cell[1]),0)
		var state: Dictionary = terrain.sample(cell)
		if row.walkable and state.cover_source_id==0 and state.base_surface==2 and ground.mapped_cover_sources(cell)==[0,10]:
			selected=cell
			found=true
			break
	check(found,"找到原图、原地图、原元素规则同时认可的真实草格")
	if not found:
		scene.free()
		quit(1)
		return
	var cover: Sprite2D = ground.source_sprite(0,selected)
	var base: Sprite2D = ground.source_sprite(-1,selected)
	var base_texture := base.texture
	var cover_texture := cover.texture
	var upper: Sprite2D = ground.source_sprite(10,selected)
	check(upper.z_index==-8,"来源10使用原排序-8而非覆盖优先级10")
	check(cover.position==Vector2(selected.x+.5,-selected.y-.5) and cover.scale==Vector2(.125,.125)
		and cover.offset==Vector2(-4,-4),"真实8像素/单位与中心锚点、Y翻转")
	check(base.z_index==-10 and cover.z_index==-9 and base.self_modulate.a==1 and cover.self_modulate.a==1,"原排序与初始逐格透明度")
	check(ground.mapped_cover_sources(selected)==[0,10],"仅返回该格确有作者覆盖的已挂载层")
	var point := Vector2(selected.x+.5,selected.y+.5)
	check(terrain.apply_point(Surface.FIRE,point,1,.1,scene.actor,20010),"原规则点燃真实草格")
	check(cover.self_modulate.a==1 and scene.surface_fire_tiles.get_used_cells().size()==1,"燃烧中保留草与残火，未过早删除覆盖")
	check(terrain.apply_point(Surface.WATER,point,1,.1),"燃尽前水熄火走原反应")
	check(cover.self_modulate.a==1 and scene.surface_fire_tiles.get_used_cells().is_empty(),"水熄火不隐藏仍有的草覆盖")
	check(terrain.apply_point(Surface.FIRE,point,1,.1,scene.actor,20010),"水后再次点燃，不自行补素材")
	for step in 51: terrain.advance(.1)
	check(terrain.sample(selected).cover_lifecycle==3 and cover.self_modulate.a==0 and upper.self_modulate.a==0,"五秒燃尽由原状态驱动实际 Sprite 透明度")
	check(base.self_modulate.a==1 and base.texture==base_texture and cover.texture==cover_texture
		and ground.cell_count(0)==547 and ground.cell_count(-1)==900,"只隐藏覆盖，不删除瓦片、不替换底图，不合成焦土")
	check(scene.surface_fire_tiles.get_used_cells().is_empty(),"燃尽删除原临时火焰，不新增 Steam 图")
	terrain.clear()
	check(cover.self_modulate.a==1 and upper.self_modulate.a==1 and base.texture==base_texture,"清除运行时状态恢复同一个作者覆盖格")
	check(terrain.apply_point(Surface.FIRE,point,1,.1,scene.actor,20010),"恢复后可再次点燃")
	for step in 51: terrain.advance(.1)
	scene.surface_presentation.disable()
	check(cover.self_modulate.a==1,"控制器禁用恢复真实逐格透明度")
	check(scene.surface_presentation.enable(terrain.runtime_cells()) and cover.self_modulate.a==0,"重新启用同步仍燃尽的状态")
	terrain.clear()
	for cell in [Vector3i(-7,6,0),Vector3i(-6,6,0),Vector3i(-4,3,0)]:
		var expected := [10,20] if cell==Vector3i(-4,3,0) else [20]
		check(ground.mapped_cover_sources(cell)==expected,"原作者上层映射与实际重叠来源")
		check(ground.source_sprite(20,cell).z_index==-1,"来源20沿用原排序-1")
		check(terrain.apply_point(Surface.FIRE,Vector2(cell.x+.5,cell.y+.5),1,.1,scene.actor,20010),"来源20真实草点燃")
		for step in 51: terrain.advance(.1)
		for source in expected:
			check(ground.source_sprite(source,cell).self_modulate.a==0,"每个实际映射图层都隐藏，不只最高优先级")
		terrain.clear()
		for source in expected:
			check(ground.source_sprite(source,cell).self_modulate.a==1,"清理恢复所有实际映射草")
	check(ground.source_sprite(20,Vector3i(-7,13,0))==null and not ground.mapped_cover_sources(Vector3i(-7,13,0)).has(20),"同层随机旁观瓦片不冒充可移除草")
	var flower_cell := Vector3i(3,-2,0)
	var flower: Sprite2D = ground.source_sprite(30,flower_cell)
	var shadow: Sprite2D = ground.source_sprite(31,flower_cell)
	var grass: Sprite2D = ground.source_sprite(0,flower_cell)
	check(ground.cell_count(30)==33 and ground.cell_count(31)==33,"原植被与阴影各33格完整装配")
	check(ground.mapped_cover_sources(flower_cell)==[0,30,31],"同格明确映射原草、花、阴影，底图不参与")
	if flower==null or shadow==null or grass==null:
		check(false,"必须从原图取到三份覆盖")
		scene.free()
		quit(1)
		return
	var flower_texture := flower.texture
	var shadow_texture := shadow.texture
	check(flower.position==Vector2(3.3125,1.4375) and shadow.position==Vector2(3.1875,1.4375)
		and flower.scale==Vector2(.125,.125) and shadow.scale==flower.scale,"来源30/31真矩阵，阴影左移1个原图像素")
	check(flower.z_index==-8 and shadow.z_index==-7 and flower.offset==Vector2(-1.5,-2.5)
		and shadow.offset==Vector2(-.5,-2.5),"原排序、导入枢轴、矩形")
	var base_flower: Sprite2D = ground.source_sprite(-1,flower_cell)
	check(terrain.sample(flower_cell).cover_source_id==0 and terrain.sample(flower_cell).base_surface==2,
		"实际较低排序优先级来源0在原规则选为有效覆盖，底图Dirt保持独立")
	check(terrain.apply_point(Surface.FIRE,Vector2(3.5,-1.5),1,.1,scene.actor,20010),"实际花格可燃")
	check(flower.self_modulate.a==1 and shadow.self_modulate.a==1 and grass.self_modulate.a==1,"燃烧中三份作者覆盖保留")
	for step in 51: terrain.advance(.1)
	check(terrain.sample(flower_cell).cover_lifecycle==3 and flower.self_modulate.a==0
		and shadow.self_modulate.a==0 and grass.self_modulate.a==0 and base_flower.self_modulate.a==1,
		"原燃尽同时隐藏草、花与阴影，并保留底图")
	terrain.clear()
	check(flower.self_modulate.a==1 and shadow.self_modulate.a==1 and grass.self_modulate.a==1
		and flower.texture==flower_texture and shadow.texture==shadow_texture,"重置恢复同一原图与原色，不以替代精灵复原")
	# 等真实节点按引擎时钟走完两个帧，区分原静态 cache 和实际播放。
	var deadline := Time.get_ticks_msec()+4500
	while seen.size()<2 and Time.get_ticks_msec()<deadline: await process_frame
	check(seen.slice(0,2)==[1,0],"LakeGrass 自动播放原顺序而非冻结在场景静态缓存")
	check(water_frames.slice(0,2)==[1,0] and water.self_modulate.a==1,
		"作者河湖底图实际播放原帧序，不受地表覆盖燃尽与清理影响")
	check(lake.self_modulate.a==1,"变换地表状态不影响该独立装饰")
	events.map_unloaded.emit()
	check(scene.ground_layers==null and scene.surface_presentation==null and not ground.visible,"卸载取消绑定且立即隐藏地图")
	scene.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(lake),"卸载释放自主动画，不保留上次场景的相位")
	check(combo_tiles.all(func(tile):return not is_instance_valid(tile)),"卸载释放原缓存装饰")
	check(not is_instance_valid(road),"地图卸载释放确定性石路精灵")
	check(not is_instance_valid(water),"地图卸载释放独立的原河湖动画")
	check(not is_instance_valid(cliff_shadow) and stairs.all(func(stair):return not is_instance_valid(stair)),
		"地图卸载释放原楼梯和崖影节点")
	print("PASS 原基础地面与草覆盖运行验收：%s 项，失败 %s；不包含倒影、动态随机重算、完整物理或 Unity 像素对照" % [n,failed])
	quit(1 if failed else 0)

# 在实际窗口比较同一原格显示、隐藏和恢复，不把图集离线预览当作绘制证据。
func check_structure_layer(ground: Node2D, meta: Dictionary, layer: Dictionary,
		id: int, count: int, order: int, expected_modes: Dictionary) -> void:
	check(int(layer.tilemap_id)==id and layer.rows.size()==count and ground.static_decoration_count(id)==count
		and not ground.source_available(id),"原独立结构层规模和来源 %d"%id)
	var modes := {}
	for row: Dictionary in layer.rows:
		modes[row.mode]=int(modes.get(row.mode,0))+1
		var cell:=Vector3i(row.cell[0],row.cell[1],row.cell[2])
		var sprite:=ground.static_decoration_sprite(id,cell) as Sprite2D
		var frame:=sprite.texture as AtlasTexture if sprite!=null else null
		var rect: Array=meta[row.sprite].rect
		check(frame!=null and frame.region==Rect2(rect[0],frame.atlas.get_height()-rect[1]-8,8,8)
			and sprite.position==Vector2(cell.x+.5,-cell.y-.5) and sprite.offset==Vector2(-4,-4)
			and sprite.scale==Vector2(.125,.125) and sprite.z_index==order
			and not ground.mapped_cover_sources(cell).has(id),"精确原结构精灵与位置 %d/%s"%[id,cell])
	check(modes==expected_modes,"原规则选图模式分布 %d"%id)

func check_combo_pixels(camera: Camera2D, tile: Sprite2D, label: String="原缓存装饰", alpha_probe: bool=false) -> void:
	var original := camera.global_position
	camera.global_position = tile.global_position
	camera.force_update_scroll()
	await RenderingServer.frame_post_draw
	var center := Vector2i(tile.get_global_transform_with_canvas().origin)
	var region := Rect2i(center-Vector2i(13,13),Vector2i(26,26))
	# 阴影只有瓦片边缘有内容，原空白中心不能作为像素样本。
	if alpha_probe:
		var frame := tile.texture as AtlasTexture
		var atlas := frame.atlas.get_image()
		var pixel := Vector2i.ZERO
		var alpha := 0.0
		for y in int(frame.region.size.y):
			for x in int(frame.region.size.x):
				var sample := atlas.get_pixelv(Vector2i(frame.region.position)+Vector2i(x,y)).a
				if sample>alpha:
					alpha=sample
					pixel=Vector2i(x,y)
		check(alpha>0.0,"%s 原纹理边缘非透明"%label)
		center=Vector2i(tile.get_global_transform_with_canvas()*(tile.offset+Vector2(pixel)+Vector2(.5,.5)))
		region=Rect2i(center-Vector2i(1,1),Vector2i(3,3))
	var shown := root.get_texture().get_image().get_region(region).get_data()
	tile.hide()
	await RenderingServer.frame_post_draw
	var hidden := root.get_texture().get_image().get_region(region).get_data()
	tile.show()
	await RenderingServer.frame_post_draw
	var restored := root.get_texture().get_image().get_region(region).get_data()
	check(shown!=hidden and shown==restored,"%s 原生画面贡献：隐藏改变=%s，恢复一致=%s，像素中心=%s" % [label,shown!=hidden,shown==restored,center])
	camera.global_position = original
	camera.force_update_scroll()
