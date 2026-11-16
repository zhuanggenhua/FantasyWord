extends SceneTree
const Mix = preload("res://game_core/presentation/equipment_character_layers.gd")
const Head = preload("res://game_core/presentation/equipment_head_layer.gd")
var trace: Array = []
var enabled: Dictionary = {}
var colors := {&"left_hand":Color.TAN,&"right_hand":Color.BISQUE,&"left_eye":Color.BLACK,&"right_eye":Color.PURPLE}
var textures := {&"bag":Color.GOLD,&"pants":Color.BLUE,&"cloth":Color.GREEN,&"cloak":Color.RED,&"hair":Color.BROWN}
var base := Color(0.3,0.4,0.5,0.25)
var checks := 0
var failures := 0

func test(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _sample(key: StringName) -> Color:
	trace.append(key)
	return textures.get(key,Color.TRANSPARENT)

func mix(parts: Dictionary, a: float, north: bool) -> Dictionary:
	trace.clear()
	return Mix.compose(base,parts,a,north,enabled,colors,_sample,_sample)

func _initialize() -> void:
	var r := mix({},0,false)
	test(r.color == base and r.coverage == 0.25 and r.source_id == 0,"半透明底色不假定来源但保留覆盖")
	base.a = 1.0
	test(mix({},0,false).source_id == Mix.SRC_MAIN,"超过截止值的底图来源")
	base.a = 0.25
	enabled = {&"bag":true,&"pants":true,&"cloth":true,&"cloak":true,&"hair":true,&"gloves":true,&"right_eye":true}
	r = mix({&"torso":true,&"head":true},1.0,false)
	test(r.source_id == Head.SRC_HAIR and trace == [&"hair"],"南向核心头部先拒绝躯干")
	r = mix({&"torso":true,&"head":true},0.0,false)
	test(r.source_id == Head.SRC_HAIR and trace == [&"bag",&"pants",&"cloth",&"cloak",&"hair"],
		"南向透明扩展开身体通路，但头部仍在最上")
	test(r.coverage == 1.0 and r.color.a == base.a,"RGB 与独立覆盖分别输出")
	r = mix({&"torso":true,&"head":true},1.0,true)
	test(r.source_id == Mix.SRC_CLOAK and trace == [&"hair",&"pants",&"cloth",&"cloak"],"北向先头后身，且不采背包")
	r = mix({&"left_hand":true,&"head":true},1.0,false)
	test(r.source_id == Mix.SRC_OTHER and r.color == Color(Color.TAN,base.a) and trace.is_empty(),
		"南向手套使用左右颜色，不采头部")
	r = mix({&"left_hand":true,&"head":true},1.0,true)
	test(r.source_id == Mix.SRC_CLOAK and trace == [&"pants",&"cloth",&"cloak"],"北向手也作为躯干但仍抑制头部")
	r = mix({&"right_eye":true},0.0,true)
	test(r.color == Color(Color.PURPLE,base.a) and trace.is_empty(),"眼色直接用实际绑定的右眼颜色")
	enabled = {&"bag":true}
	test(mix({&"torso":true},0,false).source_id == Mix.SRC_BAG,"南向透明底图容许背包")
	base.a = 0.51
	test(mix({&"torso":true},0,false).source_id == Mix.SRC_MAIN and trace.is_empty(),"有身体像素时背包不能盖住它")
	if failures == 0: print("PASS 换装角色像素分层顺序：%d 项" % checks)
	quit(1 if failures else 0)
