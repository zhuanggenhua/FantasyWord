extends SceneTree
const Presentation = preload("res://game_core/elements/terrain_surface_presentation.gd")
var checks := 0
var failures := 0
var cells: Dictionary = {}
var tiles: Dictionary = {}
var alpha: Dictionary = {}
var unlocks: Array = []
var warnings: Array = []
var available: Array = [10, 11]
const CELL := Vector3i(1, 2, 0)
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr(label)
func _initialize(): call_deferred("run")
func callbacks() -> Dictionary:
	return {"sample":func(c):return cells.get(c, {}),
		"mapped_cover_sources":func(_c):return [10, 11],
		"source_available":func(s):return s in available,
		"set_cover_alpha":func(s,c,a):alpha[[s,c]]=a,
		"unlock_cover_cell":func(s,c):unlocks.append([s,c]),
		"set_tile":func(c,t):tiles[c]=t,
		"clear_tiles":func():tiles.clear()}
func sample(states: Dictionary, removed := false) -> Dictionary:
	return {"states":states,"flags":2 if states.has(2) else 1,"base_cover":1,
		"effective_cover":0 if removed else 1,"cover_source_id":10,"cover_lifecycle":3 if removed else 1}
func run():
	var p = Presentation.new()
	p.missing_mapping.connect(func(k):warnings.append(k))
	check(not p.configure([], [], {}), "缺宿主引用拒绝配置")
	check(p.configure([{"state":2,"tile":"fire","priority":100}], [], callbacks()), "原场景仅燃烧映射装配")
	cells[CELL] = sample({2:{}})
	check(p.enable([CELL]) and tiles[CELL]=="fire", "启用恢复当前燃烧")
	cells[CELL] = sample({1:{}})
	p.on_cell_changed(CELL, {}, cells[CELL], 1)
	check(tiles[CELL]==null, "原场景无 Steam 映射不得补视觉")
	p.on_cell_changed(CELL, {}, cells[CELL], 1)
	check(warnings.size()==2, "缺状态与信号分别只报告一次")
	cells[CELL] = sample({}, true)
	p.on_cell_changed(CELL, {}, cells[CELL], 0)
	check(alpha[[10,CELL]]==0.0 and alpha[[11,CELL]]==0.0, "燃尽隐藏所有映射覆盖层")
	p.on_cell_changed(CELL, {}, cells[CELL], 0)
	check(unlocks.size()==2, "同层同格只解除一次颜色锁")
	cells[CELL] = sample({})
	p.on_cell_changed(CELL, {}, cells[CELL], 0)
	check(alpha[[10,CELL]]==1.0 and alpha[[11,CELL]]==1.0, "恢复不删除作者 Tile")
	available=[]
	p.on_cell_changed(CELL, {}, sample({},true), 0)
	check(warnings.has("surface-source:10") and alpha[[10,CELL]]==1.0, "缺实际来源停止覆盖写入")
	available=[10,11]
	# 下列人工映射仅测原配置支持的通用信号，不宣称原场景存在 Steam 素材。
	var q = Presentation.new()
	check(q.configure([{"state":2,"tile":"fire","priority":100},{"state":1,"tile":"wet","priority":100}],
		[{"signal":1,"tile":"signal","duration":0.35}], callbacks()), "通用配置合同")
	q.enable([])
	cells[CELL]=sample({2:{},1:{}})
	q.on_cell_changed(CELL,{},cells[CELL],0)
	check(tiles[CELL]=="wet", "等优先级按原有顺序取后者")
	q.on_cell_changed(CELL,{},cells[CELL],1)
	check(tiles[CELL]=="signal", "信号暂时覆盖状态")
	q.advance(.2)
	q.on_cell_changed(CELL,{},cells[CELL],1)
	q.advance(.2)
	check(tiles[CELL]=="signal", "重复信号替换计时")
	cells[CELL]=sample({2:{}})
	q.advance(.16)
	check(tiles[CELL]=="fire", "到期重新采样而非清空或恢复旧快照")
	q.on_cell_changed(CELL,{},cells[CELL],1)
	cells.erase(CELL)
	q.advance(.36)
	check(tiles[CELL]==null, "到期采样不存在清临时格")
	cells[CELL]=sample({},true)
	q.on_cell_changed(CELL,{},cells[CELL],1)
	q.disable()
	q.advance(1)
	check(tiles[CELL]=="signal" and alpha[[10,CELL]]==1.0, "禁用停止计时恢复草但不清临时格")
	q.on_cell_changed(CELL,{},sample({2:{}}),0)
	check(tiles[CELL]=="signal", "禁用后忽略外部状态事件")
	q.enable([CELL])
	q.on_cell_changed(CELL,{},cells[CELL],1)
	q.clear()
	q.advance(1)
	check(tiles.is_empty() and alpha[[10,CELL]]==1.0, "清空取消信号清图恢复草")
	var r = Presentation.new()
	check(r.configure([], [{"signal":1,"tile":"short","duration":-2}], callbacks()), "作者信号时长由配置约束")
	r.enable([])
	cells[CELL]=sample({})
	r.on_cell_changed(CELL,{},cells[CELL],1)
	r.advance(.005)
	check(tiles[CELL]=="short", "非正信号时长最低 0.01 秒")
	r.advance(.006)
	check(tiles[CELL]==null, "最低信号时长到期回到当前空状态")
	r.on_cell_changed(CELL,{},cells[CELL],1)
	r.advance(-1)
	check(tiles[CELL]=="short", "负推进不改变信号计时")
	r.on_cell_changed(CELL,{},sample({},true),1)
	available=[]
	r.clear()
	available=[10,11]
	alpha[[10,CELL]]=0.5
	r.clear()
	check(alpha[[10,CELL]]==0.5, "来源消失时恢复跳过并释放隐藏记录")
	print("terrain_surface_presentation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
