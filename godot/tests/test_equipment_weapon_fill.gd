extends SceneTree
const Fill = preload("res://gameplay/presentation/equipment_weapon_fill.gd")
const Layers = preload("res://game_core/presentation/equipment_character_layers.gd")
var checks := 0
var failures := 0
var bag_calls := 0
var bag := Color(0.9,0.8,0.1,0.8)
var character := {"color":Color(0.2,0.3,0.4,0.1),"coverage":0.25,"source_id":1}

func test(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func slot(depth: float, hand: float, color: Color, sampled := true) -> Dictionary:
	return {"depth_mode":depth,"hand_in_front":hand,"color":color,"sampled":sampled}

func _bag() -> Color:
	bag_calls += 1
	return bag

func compose(a: Dictionary, b: Dictionary, parts: Dictionary = {}, north := 0.0, enabled := 0.0) -> Dictionary:
	return Fill.compose(character,parts,a,b,north,enabled,_bag)

func matches(r: Dictionary, color: Color, alpha: float, source: int) -> bool:
	return r.color.is_equal_approx(Color(color,alpha)) and is_equal_approx(r.coverage,alpha) and r.source_id == source

func _initialize() -> void:
	var red := Color(1,0,0,0.9)
	var blue := Color(0,0,1,0.7)
	var empty := slot(0,0,Color.TRANSPARENT,false)
	var a := slot(0,0,red)
	var b := slot(0,0,blue)
	test(matches(compose(empty,empty),character.color,0.25,1),"无武器时输出独立人物覆盖而非底图 alpha")
	test(matches(compose(a,b),blue,0.9,8),"后景副手 RGB 胜出但 alpha 取主手最大值，不是混色")
	character.coverage = 0.5
	test(matches(compose(a,b),blue,0.9,8),"人物覆盖等于截止值时允许后景覆盖")
	character.coverage = 0.5001
	test(matches(compose(a,b),character.color,0.9,1),"后景被遮住仍贡献 alpha 且保留人物来源")
	character.coverage = 0.25
	a.depth_mode = 1.0
	b.depth_mode = 1.0
	test(matches(compose(a,b),red,0.9,7),"前景主手 RGB 胜出")
	a.color = Color(red,0.6)
	test(matches(compose(a,b),red,0.7,7),"前景主手 RGB 胜出但保留副手更高 alpha")
	character.coverage = 1.0
	test(matches(compose(a,b),red,1.0,7),"前景覆盖颜色但不能降低人物覆盖")
	character.coverage = 0.25
	a.color = red
	a.hand_in_front = 1.0
	for hand in [&"left_hand",&"right_hand"]:
		test(matches(compose(a,b),red,0.9,7),"没有手蒙版不受手配置影响")
		test(matches(compose(a,b,{hand:true}),blue,0.7,8),"两种手蒙版均只挡开启遮挡的槽")
	b.hand_in_front = 1.0
	test(matches(compose(a,b,{&"left_hand":true}),character.color,0.25,1),"被手挡的前景既不写 RGB 也不贡献 alpha")
	for foot in [&"left_foot",&"right_foot"]:
		test(matches(compose(a,b,{foot:true}),red,0.9,7),"脚不参与武器填充遮挡")
	a.hand_in_front = 0.5
	test(matches(compose(a,b,{&"left_hand":true}),red,0.9,7),"手配置等于半值不挡")
	a.depth_mode = 0.5
	b.depth_mode = 0.5
	test(matches(compose(a,b),character.color,0.25,1),"深度等于半值两侧均不绘制")
	a.depth_mode = 0.4999
	b.depth_mode = 0.5001
	test(matches(compose(a,b),blue,0.9,8),"混合深度前景副手盖住后景主手")
	a.depth_mode = 0.5001
	b.depth_mode = 0.4999
	test(matches(compose(a,b),red,0.9,7),"混合深度前景主手盖住后景副手")
	a.sampled = false
	test(matches(compose(a,empty),character.color,0.25,1),"失败采样即便带非透明颜色也不可绘制")
	a.sampled = true
	bag_calls = 0
	compose(a,b,{},0.5,1)
	compose(a,b,{},1,0.5)
	test(bag_calls == 0,"北向和启用均严格大于半值才采背包")
	test(matches(compose(a,b,{},1,1),bag,1.0,10) and bag_calls == 1,"北向背包无躯干门槛且覆盖两武器并提升覆盖到一")
	bag.a = 0.5
	test(matches(compose(a,b,{},1,1),red,0.9,7),"背包 alpha 等于截止值不覆盖")
	bag.a = 0.5001
	test(matches(compose(a,b,{},1,1),bag,1.0,10),"背包严格越过截止即写实覆盖而非透混")
	character = Layers.compose(Color(0.2,0.3,0.4,0.1),{&"torso":true},0.0,false,
		{&"cloth":true},{},func(_key: StringName) -> Color: return Color.GREEN,Callable())
	a.depth_mode = 0.0
	b.depth_mode = 0.0
	test(matches(compose(a,b),Color.GREEN,1.0,9),"前级衣服覆盖为一时，即使底图透明也挡后景武器")
	if failures == 0: print("PASS 武器填充深度与遮盖：%d 项" % checks)
	quit(1 if failures else 0)
