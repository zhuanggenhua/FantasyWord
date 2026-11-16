extends SceneTree
const Outline = preload("res://gameplay/presentation/equipment_outline_coverage.gd")
const Weapon = preload("res://gameplay/presentation/equipment_weapon_uv.gd")
const UV = preload("res://game_core/presentation/equipment_uv_sampler.gd")
var checks := 0
var failures := 0
var slots := [{},{ }]
var sheet := {"main":Color(0,0,0,0.2),"body":Color(0.2,0.7,0,0),"head":Color(0.8,0.1,0,0)}
var equip_color := Color(1,0,0,0.6)
var weapon_colors := [Color(1,0,0,0.6),Color(0,1,0,0.8)]
var rg_calls: Array = []
var center: Dictionary
var neighbor: Dictionary
var positions: Array = []

func test(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _sheet(_uv: Vector2) -> Dictionary:
	return sheet
func _equip(key: StringName, rg: Vector2) -> Color:
	rg_calls.append([key,rg])
	return equip_color
func _weapon(slot: int, _uv: Vector2) -> Color:
	return weapon_colors[slot]
func cover(enabled: Dictionary = {}) -> Dictionary:
	return Outline.coverage(Vector2(0.5,0.5),Rect2(0,0,1,1),_sheet,enabled,_equip,slots,_weapon)
func _coverage(uv: Vector2) -> Dictionary:
	positions.append(uv)
	return center if uv.is_equal_approx(Vector2(0.5,0.5)) else neighbor
func decide(source := 0, north := 0.0, baseline := 0.0) -> Dictionary:
	positions.clear()
	return Outline.outline(Vector2(0.5,0.5),Vector2(4,4),baseline,source,north,slots,_coverage)
func blank() -> Dictionary:
	return {"body_alpha":0.0,"bag_alpha":0.0,"weapon0_alpha":0.0,"weapon1_alpha":0.0,"weapon_alpha":0.0,"body_uv":Color.TRANSPARENT,"head_uv":Color.TRANSPARENT}
func _initialize() -> void:
	test(is_equal_approx(cover().body_alpha,0.2),"保留底图分数 alpha，不依赖填色")
	for key in Outline.BODY_KEYS + Outline.HEAD_KEYS:
		rg_calls.clear()
		test(cover({key:1.0}).body_alpha == 1.0,"八类装备各自形成并集："+str(key))
		var wanted := Vector2(0.2,0.7) if key in Outline.BODY_KEYS else Vector2(0.8,0.1)
		test(rg_calls[0][1].is_equal_approx(wanted),"无需部位或 alpha 标记，直接原始 RG："+str(key))
	rg_calls.clear()
	test(is_equal_approx(cover({&"eye_decoration":1.0,&"gloves":1.0}).body_alpha,0.2) and rg_calls.is_empty(),"眼饰和手套不加入装备轮廓并集")
	equip_color.a = 0.5
	test(is_equal_approx(cover({&"hair":1.0}).body_alpha,0.2),"装备 alpha 恰好截止值不命中")
	equip_color.a = 0.6
	test(cover({&"hair":0.5}).body_alpha < 0.5,"装备启用严格大于截止值")
	test(cover({&"bag":0.5}).bag_alpha == 1.0 and cover({&"bag":0.49}).bag_alpha == 0.0,"背包启用边界忠于源码")
	test(is_equal_approx(cover().caster_alpha,0.8) and is_equal_approx(cover().weapon_alpha,0.8),"静态武器保留分数 alpha")
	slots[1].is_sequence = 0.5
	test(cover().weapon1_alpha == 0 and is_equal_approx(cover().caster_alpha,0.6),"序列及边界不投影不描边")
	slots = [{"hide_outline_on_body":1.0},{}]
	var hidden := cover({&"hair":1.0})
	test(hidden.weapon_alpha == 0 and hidden.caster_alpha == 1,"任意槽隐藏标志压制两槽但不压制投影")
	sheet.main.a = 0.9
	test(cover().weapon_alpha == 0,"本体 alpha 同样触发跨槽隐藏")
	sheet.main.a = 0.2
	slots = [{},{}]
	# 左半帧空，右半相邻帧非零；越过帧边界必须读到相邻帧。
	var image := Image.create(4,2,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.set_pixel(2,1,Color.WHITE)
	var adjacent_sheet := func(uv: Vector2) -> Dictionary:
		return {"main":UV.sample_point(image,uv),"body":Color(uv.x,uv.y,0,0),"head":Color.TRANSPARENT}
	var no_weapon := func(_slot: int,_uv: Vector2) -> Variant: return null
	var adjacent := Outline.coverage(Vector2(1.25,0.25),Rect2(0,0,0.5,1),adjacent_sheet,{},_equip,slots,no_weapon)
	test(adjacent.body_alpha == 1.0,"本体邻居跨帧读取实际非零相邻格，禁止局部 clamp")
	rg_calls.clear()
	Outline.coverage(Vector2(1.25,0.25),Rect2(0,0,0.5,1),adjacent_sheet,{&"bag":1},_equip,slots,no_weapon)
	test(rg_calls[0][1].is_equal_approx(Vector2(0.625,0.75)),"背包邻居同样跨帧保留原始 RG")
	var white_weapon := Image.create(2,2,false,Image.FORMAT_RGBA8)
	white_weapon.fill(Color.WHITE)
	var bounded_weapon := func(_slot: int,uv: Vector2) -> Variant:
		return Weapon.sample_pixel(white_weapon,Weapon.sample_uv(uv,Rect2(0,0,0.5,1),Rect2(0,0,1,1),Vector2(0.5,0.5),Vector2(0.5,0.5),Vector2(1,0),false,true))
	var edge := Outline.coverage(Vector2(1.25,0.25),Rect2(0,0,0.5,1),adjacent_sheet,{},_equip,slots,bounded_weapon)
	test(edge.body_alpha==1.0 and edge.weapon_alpha==0.0,"相邻非零帧贡献本体，但武器采样仍拒绝越界")
	var inside := Outline.coverage(Vector2(0.75,0.25),Rect2(0,0,0.5,1),adjacent_sheet,{},_equip,slots,bounded_weapon)
	test(inside.body_alpha==0.0 and inside.weapon_alpha==1.0 and inside.caster_alpha==1.0,"同一实际武器采样在帧内参与轮廓与投影")
	for id in [1,2,3,4,5,6,9,11]:
		test(Outline.layer_priority(id,0,slots)==50,"本体来源优先级："+str(id))
	test(Outline.layer_priority(0,1,slots)==-1 and Outline.layer_priority(12,1,slots)==-1,"空和未知来源优先级")
	test(Outline.layer_priority(10,0,slots)==0 and Outline.layer_priority(10,1,slots)==100,"南北背包优先级")
	test(Outline.layer_priority(7,0,slots)==10 and Outline.layer_priority(8,0,slots)==5,"后景两槽优先级")
	slots = [{"depth_mode":1.0},{"depth_mode":1.0}]
	test(Outline.layer_priority(7,1,slots)==80 and Outline.layer_priority(8,1,slots)==70,"前景层级由槽深度决定而非手部")
	center = blank()
	neighbor = blank()
	neighbor.body_alpha = 1.0
	test(decide().is_outline and positions.size()==5,"中心加四个正交邻居")
	test(positions.has(Vector2(0.75,0.5)) and positions.has(Vector2(0.5,0.25)),"邻居步长准确")
	test(decide(1).is_outline and not decide(7).is_outline,"轮廓可覆盖相同但不能覆盖更高来源优先级")
	test(decide(0,0,0.625).is_outline and not decide(0,0,0.626).is_outline,"半像素基线边界")
	neighbor.body_uv = Color(0,0,0.4,0)
	slots[1].depth_mode = 0.0
	test(not decide(8).is_outline,"手部邻居不能覆盖低优先级武器填色来源")
	slots[1].depth_mode = 1.0
	neighbor.body_uv.a = 1
	test(not decide().is_outline,"手部位于躯干核心不描边")
	neighbor.body_uv.a = 0
	neighbor.head_uv = Color(0,0,0.1,1)
	test(not decide().is_outline,"手部位于头部核心不描边")
	neighbor.head_uv.a = 0.5
	test(decide().is_outline,"核心 alpha 严格大于截止值")
	neighbor = blank()
	neighbor.weapon0_alpha = 0.8
	test(decide().best_priority==80,"武器独立邻居")
	neighbor.body_alpha = 1
	slots = [{},{}]
	test(decide().best_priority==50,"本体邻居遮挡低层武器")
	center.body_alpha = 1
	test(not decide().is_outline,"本体中心不扩边时，邻居本体仍单独挡住后景武器")
	center.body_alpha = 0
	slots = [{"depth_mode":1.0},{}]
	test(decide().best_priority==80,"本体不能遮挡前景武器")
	neighbor.body_alpha = 0
	neighbor.bag_alpha = 1
	test(decide(0,1).best_priority==100 and decide().best_priority==80,"北向背包挡武器，南向不挡")
	center.bag_alpha = 1
	test(not decide(0,1).is_outline and decide().best_priority==80,"背包中心不扩边时仍单独挡北向武器")
	center.bag_alpha = 0
	neighbor.bag_alpha = 0
	center.body_alpha = 1
	slots[1].hide_outline_on_body = 1
	test(not decide().is_outline,"中心跨槽隐藏也阻止武器邻居描边")
	center = blank()
	center.weapon_alpha = 0.8
	test(not decide().is_outline,"任意槽占据中心则两槽不描边")
	var yes := {"is_outline":true}
	var before := Color(0.2,0.3,0.4,0.2)
	test(Outline.apply_outline(before,yes,0,0,0,Color.RED,Color.BLUE)==before,"默认关闭不改填色")
	test(Outline.apply_outline(before,yes,0,1,1,Color(1,0,0,0.2),Color.BLUE)==Color.RED,"受击高于额外且强制 alpha 为一")
	test(Outline.apply_outline(before,yes,0,0,1,Color.RED,Color.BLUE)==Color.BLUE,"额外请求强制描边")
	test(Outline.apply_outline(before,yes,1,0,0,Color.RED,Color.BLUE)==Color.BLACK,"默认黑轮廓")
	if failures == 0:
		print("PASS equipment_outline_coverage ",checks," checks")
	quit(1 if failures else 0)
