extends "res://tests/test_clickmovetest_aim_pivot.gd"
## 真实 Entry 地表点施加验证。无私有文件时仅用两格作者字段等价样本验证运行时。
const Surface = preload("res://game_core/elements/terrain_element_runtime.gd")
class RuleMotion extends Owner:
	func update_movement_animation(_v: Vector2) -> void: pass

static func smoke_contract(scene: Node) -> Dictionary:
	return {"schema":1,"source_commit":scene.SOURCE,"fixed_step":.1,
		"cover_rows":[{"cell":[0,0,0],"kind":1,"traits":7,"source_id":0},
			{"cell":[1,0,0],"kind":1,"traits":3,"source_id":10}],
		"states":[{"m_stateKind":1,"m_defaultDuration":6,"m_mergePolicy":0,"m_traversalCostMultiplier":1.15},
			{"m_stateKind":2,"m_defaultDuration":5,"m_mergePolicy":1,"m_traversalCostMultiplier":4}],
		"reactions":[{"m_trigger":0,"m_elementKind":1,"m_minimumIntensity":.05,"m_requireSurfaceCover":true,
			"m_surfaceCover":1,"m_requiredSurfaceCoverTraits":1,"m_forbiddenStates":4,
			"m_operations":[{"m_kind":0,"m_stateKind":2,"m_intensityMultiplier":1,"m_durationOverride":5}]},
			{"m_trigger":1,"m_expiredStateKind":2,"m_requireSurfaceCover":true,"m_surfaceCover":1,
				"m_requiredSurfaceCoverTraits":2,"m_operations":[{"m_kind":5}]},
			{"m_trigger":0,"m_elementKind":2,"m_minimumIntensity":.05,"m_requiredStates":2,
				"m_operations":[{"m_kind":1,"m_stateKind":2},
					{"m_kind":0,"m_stateKind":1,"m_intensityMultiplier":1,"m_durationOverride":6},{"m_kind":4,"m_presentationSignal":1}]}]}

func run() -> void:
	var scene = Entry.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var owner := RuleMotion.new()
	var player := Player.new()
	player.actor=scene.actor
	var events := MapEvents.new()
	var source_rules := OS.get_environment("FORMAL_SURFACE_RULES")
	var source_assets := OS.get_environment("FORMAL_SURFACE_ASSETS")
	var source := not source_rules.is_empty() and not source_assets.is_empty()
	var data: Dictionary
	var assets: Dictionary
	if source:
		data=read(source_rules)
		assets=read(source_assets)
	else:
		data=fixtures(scene,ProjectSettings.globalize_path("user://surface-fixture"))[0]
		for row in data.rows: row.surface=2
		assets=smoke_contract(scene)
	if not scene.start_logic(owner,data,func():return player,func():return null,events,func(_p):return false):
		printerr("无法装配原场景规则")
		quit(1)
		return
	var wrong := assets.duplicate()
	wrong.source_commit=""
	check(not scene.start_surface_elements(wrong),"拒绝无锁定作者身份的数据")
	if not scene.start_surface_elements(assets):
		printerr("无法绑定原元素规则与作者覆盖")
		quit(1)
		return
	check(not scene.start_surface_elements(assets),"不创建同地图第二个运行时状态")
	var system: RefCounted=scene.surface_elements
	var candidates: Array[Vector3i]=[]
	for row in data.rows:
		if not row.walkable: continue
		var c:=Vector3i(int(row.cell[0]),int(row.cell[1]),0)
		var info: Dictionary=system.sample(c)
		if info.base_surface==2 and info.effective_cover==1 and (int(info.traits)&3)==3:
			candidates.append(c)
	if candidates.size()<2:
		printerr("没有符合锁定验证器的可燃草覆盖")
		quit(1)
		return
	var start: Vector2=scene.actor.get_movement_position()
	var origin:=Vector3i(floori(start.x),floori(start.y),0)
	candidates.sort_custom(func(a: Vector3i,b: Vector3i):
		var ad: int=(a-origin).length_squared()
		var bd: int=(b-origin).length_squared()
		return ad<bd or (ad==bd and (a.y<b.y or (a.y==b.y and a.x<b.x))))
	var cell: Vector3i=candidates[0]
	var other: Vector3i=candidates[1]
	var point:=Vector2(cell.x+.5,cell.y+.5)
	var applied: Array = []
	system.cell_changed.connect(func(p,before,after,notice):applied.append([p,before,after,notice]))
	check(not system.apply_point(Surface.WATER,point,1,0),"无火时水规则不产生虚构湿润")
	check(not system.apply_point(Surface.FIRE,point,.049,.2),"作者强度门槛")
	check(system.apply_point(Surface.FIRE,point,1,.2,scene.actor,0),"原验证点火应用")
	var burn: Dictionary=system.sample(cell)
	check(burn.flags==2 and burn.cover_lifecycle==2 and burn.effective_cover==1,"草仍在但处于原燃烧标记")
	check(is_equal_approx(burn.traversal_cost,applied[0][1].traversal_cost*4)
		and burn.states[2].remaining==5 and burn.states[2].source_entity.get_ref()==scene.actor,"原倍率、时长及来源")
	check(system.sample(other).flags==0,"点火无邻格自动扩散")
	for i in 20: system.advance(.1)
	var remaining: float=system.sample(cell).states[2].remaining
	check(not system.apply_point(Surface.FIRE,point,1,.2,scene.actor,0)
		and system.sample(cell).states[2].remaining==remaining,"同强度不刷新燃烧时间")
	check(system.apply_point(Surface.WATER,point,1,.2),"水仅对已有火生效")
	var wet: Dictionary=system.sample(cell)
	check(wet.flags==1 and wet.states[1].remaining==6 and wet.cover_lifecycle==1 and wet.effective_cover==1,
		"立即灭火、湿润但草不燃尽")
	check(applied.back()[3]==1 and is_equal_approx(wet.traversal_cost,applied[0][1].traversal_cost*1.15),
		"一次原蒸汽事件与湿润代价")
	for i in 60: system.advance(.1)
	check(system.sample(cell).flags==1,"float32累减第60步仍有正值")
	system.advance(.1)
	check(system.sample(cell).flags==0 and system.sample(cell).effective_cover==1,"第61步湿润到期不丢草")
	check(system.apply_point(Surface.FIRE,point,1,.2,scene.actor,0),"可再点火")
	for i in 50: system.advance(.1)
	check(system.sample(cell).flags==2,"float32累减第50步仍有正值")
	system.advance(.1)
	var expired: Dictionary=system.sample(cell)
	check(expired.flags==0 and expired.cover_lifecycle==3 and expired.effective_cover==0
		and expired.base_cover==1 and expired.effective_surface==2,"自然燃尽只移除上层草，露出原底层土")
	check(not system.apply_point(Surface.FIRE,point,1,.2),"自然燃尽后不在裸土复燃")
	system.clear()
	applied.clear()
	check(not system.apply_cone(Surface.FIRE,Vector2(.5,.5),Vector2.ZERO,3.5,30,1,.1),"非法朝向不产生元素")
	check(system.apply_cone(Surface.FIRE,Vector2(.5,.5),Vector2.RIGHT,3.5,30,1,.1,scene.actor,20010),
		"正式世界元素投射参数通过地图四邻和可燃条件")
	var actual: Array[Vector3i]=[]
	for event in applied: actual.append(event[0])
	var expected := [Vector3i.ZERO,Vector3i(3,0,0),Vector3i(3,1,0),Vector3i(3,-1,0)] if source else [Vector3i.ZERO,Vector3i.RIGHT]
	check(actual==expected,"仅命中锥内相连的可燃覆盖，保留四邻访问次序")
	check(system.sample(Vector3i.ZERO).states[2].source_ability==20010,"不把效果编号误当作来源技能")
	if source:
		check(str(burn.states[2].rule_id)!="" and str(burn.states[2].state_id)!=""
			and burn.cover_source_id==expired.cover_source_id,"原 Registry 稳定身份及来源层保留")
	events.map_unloaded.emit()
	check(scene.surface_elements==null and system.sample(cell).effective_cover==1,"卸载清除运行态不写回作者层")
	scene.free()
	await process_frame
	if failed==0: print("PASS ClickMoveTest 原点火和水反应：%d 项（锁定源=%s，测试格=%s）" % [n,str(source),str(cell)])
	quit(0 if failed==0 else 1)
