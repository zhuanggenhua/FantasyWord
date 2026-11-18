extends "res://tests/test_clickmovetest_element_surface.gd"
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
	check(ground.cell_count(10)==158 and ground.cell_count(20)==3,"来源10/20真实映射覆盖158/3格，非覆盖装饰未装配")
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
	events.map_unloaded.emit()
	check(scene.ground_layers==null and scene.surface_presentation==null and not ground.visible,"卸载取消绑定且立即隐藏地图")
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS 原基础地面与草覆盖运行验收：%s 项，失败 %s；不包含旁观装饰或 Unity 像素对照" % [n,failed])
	quit(1 if failed else 0)
