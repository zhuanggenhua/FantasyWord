extends SceneTree
const Shadow = preload("res://gameplay/presentation/equipment_shadow_coverage.gd")
const Outline = preload("res://gameplay/presentation/equipment_outline_coverage.gd")
var checks := 0
var failures := 0
var taps: Array = []
var alpha := 0.2
var enabled := {}
var slots := [{},{}]
var weapon_alpha := 0.0

func test(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func caster(uv: Vector2) -> float:
	taps.append(uv)
	return alpha
func sheet(_uv: Vector2) -> Dictionary:
	return {"main":Color(0,0,0,alpha),"body":Color.TRANSPARENT,"head":Color.TRANSPARENT}
func equip(_key: StringName, _uv: Vector2) -> Color:
	return Color.WHITE
func weapon(_slot: int, _uv: Vector2) -> Color:
	return Color(0,0,0,weapon_alpha)
func covered(uv: Vector2) -> float:
	return Outline.coverage(uv,Rect2(0,0,1,1),sheet,enabled,equip,slots,weapon).caster_alpha
func _initialize() -> void:
	var left := [Vector2i(3,8),Vector2i(5,9)]
	var right := [Vector2i(11,8),Vector2i(13,10)]
	for diff in [-3,0,1,2,3,9,10,30]:
		var w := Shadow.height_writes(left,right,8+diff)
		var expected := 0 if diff <= 0 else (1 if diff <= 2 else (2 if diff <= 9 else 3))
		test(w.mode == expected,"高度阈值："+str(diff))
		test(w.base_y == 1.0-(8+diff+0.5)/32.0,"基线像素中心")
		test(w.frame_size == Vector2(32,32),"无动画尺寸默认 32")
		if expected == 1:
			test(w.left_x == 3.0/32 and w.right_x == 13.0/32,"双脚所有像素 X 极值")
		elif expected == 2:
			test(w.center_x == 5.0/32,"同高优先左脚最右像素而非均值")
		elif expected == 3:
			test(w.center_x == 0.5,"高空固定帧中央")
	var p := Shadow.height_writes(left,[Vector2i(12,7),Vector2i(14,8)],11,Vector2i(16,64))
	test(p.center_x == 12.0/16 and p.base_y == 1.0-11.5/64,"右侧较小 Y 取最左 X，非方帧")
	test(Shadow.height_writes([],right,12).center_x == 11.0/32,"仅右脚")
	test(Shadow.height_writes(left,[],12).center_x == 5.0/32,"仅左脚")
	test(Shadow.height_writes([Vector2i(1200,0)],[],1).left_x == 999.0/32,"保留缺侧 999 哨兵")
	test(Shadow.height_writes([], [Vector2i(-1200,0)],1).right_x == -999.0/32,"保留缺侧 -999 哨兵")
	var previous := {"mode":2.0,"base_y":0.5,"frame_size":Vector2(8,8),"left_x":0.25,"right_x":0.5,"center_x":0.5,"enabled":1.0}
	for writes in [Shadow.height_writes([],[],0),Shadow.height_writes(left,right,0,Vector2i(32,32),true,false),Shadow.height_writes(left,right,0,Vector2i(32,32),true,true,false)]:
		test(writes == {"mode":-1.0},"空脚或帧只写 mode")
		var kept := Shadow.apply_writes(previous,writes)
		test(kept.base_y == 0.5 and kept.frame_size == Vector2(8,8) and kept.enabled == 1,"其它参数原值保留")
	test(Shadow.height_writes([],[],0,Vector2i(32,32),false) == {},"无材质不写")
	test(previous.mode == 2.0,"应用写入不修改输入")
	p = previous.duplicate()
	p.mode = -1.0
	test(Shadow.mask(Vector2(0.5,0.5),p,caster),"负模式仍走 Mode0，不能发明关闭")
	p.mode = 0.0
	for y in [0.5+0.5/8,0.5-0.5/8,0.5-1.5/8]:
		test(Shadow.mask(Vector2(0.5,y),p,caster),"Mode0 Y 包含边界")
	test(not Shadow.mask(Vector2(0.5,0.5+0.501/8),p,caster),"Mode0 上边界之外")
	test(not Shadow.mask(Vector2(0.5,0.5-1.501/8),p,caster),"Mode0 下边界之外")
	taps.clear()
	Shadow.mask(Vector2(0.5,0.5),p,caster)
	test(taps == [Vector2(.375,.5),Vector2(.5,.5),Vector2(.25,.5),Vector2(.625,.5),Vector2(.75,.5),Vector2(.5,.5)],"基线两个三点探针，保留顺序与重复中心")
	taps.clear()
	Shadow.mask(Vector2(.5,.375),p,caster)
	test(taps == [Vector2(.5,.5),Vector2(.625,.5),Vector2(.375,.5)],"下一排单个三点")
	taps.clear()
	Shadow.mask(Vector2(0,.5),p,caster)
	test(taps == [Vector2(0,.5),Vector2(.125,.5),Vector2(.25,.5),Vector2(0,.5)],"X=0 只筛各点，不筛探针中心")
	taps.clear()
	Shadow.ground_probe(1.0,p,caster)
	test(taps == [Vector2(1,.5),Vector2(.875,.5)],"X=1 闭边界")
	p.base_y = -0.25
	taps.clear()
	Shadow.ground_probe(.5,p,caster)
	test(taps[0].y == -.25,"基线 Y 不夹帧")
	p.base_y = .5
	alpha = .001
	test(not Shadow.mask(Vector2(.5,.5),p,caster),"caster alpha 等于 .001 不命中")
	alpha = .00101
	test(Shadow.mask(Vector2(.5,.5),p,caster),"caster alpha 大于 .001 命中，不使用 .5")
	p.mode = 1.0
	for uv in [Vector2(.125,.375),Vector2(.625,.625),Vector2(.3,.5)]:
		test(Shadow.mask(uv,p,caster),"Mode1 四边闭区间")
	test(not Shadow.mask(Vector2(.124,.5),p,caster) and not Shadow.mask(Vector2(.626,.5),p,caster),"Mode1 X 外部")
	p.mode = 2.0
	for x in range(-3,4):
		for y in range(-3,4):
			var expected: bool = x >= -1 and x <= 2 and y >= -1 and y <= 1 and not ((x == -1 or x == 2) and abs(y) == 1)
			test(Shadow.mask(Vector2(.5+x/8.0,.5+y/8.0),p,caster) == expected,"Mode2 非对称 4×3 缺角")
	test(Shadow.mask(Vector2(.5+1.5/8,.5+1.0/8),p,caster),"角截止 1.5 属内侧")
	test(not Shadow.mask(Vector2(.5+1.501/8,.5+1.0/8),p,caster),"角截止之外排除")
	p.mode = 3.0
	for x in range(-3,4):
		for y in range(-3,4):
			test(Shadow.mask(Vector2(.5+x/8.0,.5+y/8.0),p,caster) == (abs(x)+abs(y) <= 1),"Mode3 十字")
	test(Shadow.mask(Vector2(.5+1.5/8,.5+.5/8),p,caster),"十字外沿含半像素")
	test(not Shadow.mask(Vector2(.5+1.501/8,.5+.5/8),p,caster),"十字外沿之外")
	# 模式选择使用实数区间，不先取整。
	for pair in [[.499,0.0],[.5,1.0],[1.499,1.0],[1.5,2.0],[2.499,2.0],[2.5,3.0]]:
		for x in range(-3,4):
			var uv := Vector2(.5+x/8.0,.5)
			p.mode = pair[0]
			var actual := Shadow.mask(uv,p,caster)
			p.mode = pair[1]
			test(actual == Shadow.mask(uv,p,caster),"实数模式分界")
	p.mode = 0.0
	alpha = 0.0
	enabled = {&"bag":1.0}
	test(not Shadow.mask(Vector2(.5,.5),p,covered),"复用轮廓 caster：排除背包")
	enabled = {&"cloth":1.0}
	test(Shadow.mask(Vector2(.5,.5),p,covered),"复用轮廓 caster：服装并集")
	enabled = {}
	weapon_alpha = .5
	test(not Shadow.mask(Vector2(.5,.5),p,covered),"武器内部 .5 截止")
	weapon_alpha = .6
	slots = [{"hide_outline_on_body":1.0},{}]
	test(Shadow.mask(Vector2(.5,.5),p,covered),"静态武器投影")
	slots = [{"is_sequence":.5},{"is_sequence":1.0}]
	test(not Shadow.mask(Vector2(.5,.5),p,covered),"序列武器排除")
	alpha = .2
	var original := Color(.8,.7,.6,.9)
	var shadow := Color(.1,.2,.3,.4)
	test(Shadow.apply_shadow(original,.5,1,shadow,Vector2(.5,.5),p,caster) == shadow,"独立 finalAlpha 门限且整色替换")
	test(Shadow.apply_shadow(original,.501,1,shadow,Vector2(.5,.5),p,caster) == original,"已填像素保留")
	test(Shadow.apply_shadow(original,0,.5,shadow,Vector2(.5,.5),p,caster) == original,"启用门限严格")
	test(Shadow.apply_shadow(original,0,1,Color(1,1,1,0),Vector2(.5,.5),p,caster) == original,"零 alpha 阴影不覆写")
	test(Shadow.apply_shadow(original,0,1,shadow,Vector2(.5,.8),p,caster) == original,"遮罩未命中")
	if failures == 0:
		print("PASS equipment_shadow_coverage ",checks," checks")
	quit(1 if failures else 0)
