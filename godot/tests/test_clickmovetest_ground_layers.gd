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
	check(not ground.source_available(-1) and not ground.source_available(10),"基础地面不当作可删除覆盖，未迁移来源不假装可用")
	check(scene.bind_surface_presentation(fire_path),"现有地表控制器自动绑定实际逐格透明度")
	var terrain: RefCounted = scene.surface_elements
	var selected := Vector3i.ZERO
	var found := false
	for row in read(rules).rows:
		var cell := Vector3i(int(row.cell[0]),int(row.cell[1]),0)
		var state: Dictionary = terrain.sample(cell)
		if row.walkable and state.cover_source_id==0 and state.base_surface==2 and ground.source_sprite(0,cell)!=null:
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
	check(cover.position==Vector2(selected.x+.5,-selected.y-.5) and cover.scale==Vector2(.125,.125)
		and cover.offset==Vector2(-4,-4),"真实8像素/单位与中心锚点、Y翻转")
	check(base.z_index==-10 and cover.z_index==-9 and base.self_modulate.a==1 and cover.self_modulate.a==1,"原排序与初始逐格透明度")
	check(ground.mapped_cover_sources(selected)==[0],"仅返回该格确有作者覆盖的已挂载层")
	var point := Vector2(selected.x+.5,selected.y+.5)
	check(terrain.apply_point(Surface.FIRE,point,1,.1,scene.actor,20010),"原规则点燃真实草格")
	check(cover.self_modulate.a==1 and scene.surface_fire_tiles.get_used_cells().size()==1,"燃烧中保留草与残火，未过早删除覆盖")
	check(terrain.apply_point(Surface.WATER,point,1,.1),"燃尽前水熄火走原反应")
	check(cover.self_modulate.a==1 and scene.surface_fire_tiles.get_used_cells().is_empty(),"水熄火不隐藏仍有的草覆盖")
	check(terrain.apply_point(Surface.FIRE,point,1,.1,scene.actor,20010),"水后再次点燃，不自行补素材")
	for step in 51: terrain.advance(.1)
	check(terrain.sample(selected).cover_lifecycle==3 and cover.self_modulate.a==0,"五秒燃尽由原状态驱动实际 Sprite 透明度")
	check(base.self_modulate.a==1 and base.texture==base_texture and cover.texture==cover_texture
		and ground.cell_count(0)==547 and ground.cell_count(-1)==900,"只隐藏覆盖，不删除瓦片、不替换底图，不合成焦土")
	check(scene.surface_fire_tiles.get_used_cells().is_empty(),"燃尽删除原临时火焰，不新增 Steam 图")
	terrain.clear()
	check(cover.self_modulate.a==1 and base.texture==base_texture,"清除运行时状态恢复同一个作者覆盖格")
	check(terrain.apply_point(Surface.FIRE,point,1,.1,scene.actor,20010),"恢复后可再次点燃")
	for step in 51: terrain.advance(.1)
	scene.surface_presentation.disable()
	check(cover.self_modulate.a==1,"控制器禁用恢复真实逐格透明度")
	check(scene.surface_presentation.enable(terrain.runtime_cells()) and cover.self_modulate.a==0,"重新启用同步仍燃尽的状态")
	events.map_unloaded.emit()
	check(scene.ground_layers==null and scene.surface_presentation==null and not ground.visible,"卸载取消绑定且立即隐藏地图")
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS 原基础地面与草覆盖运行验收：%s 项，失败 %s；未包含其他覆盖图层或 Unity 像素对照" % [n,failed])
	quit(1 if failed else 0)
