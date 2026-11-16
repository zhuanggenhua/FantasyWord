extends SceneTree
const Palette = preload("res://gameplay/presentation/equipment_skin_palette.gd")
const Mix = preload("res://game_core/presentation/equipment_character_layers.gd")
var count := 0
var failed := 0
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failed += 1
		push_error(message)
func near(a: Color,b: Color) -> bool:
	return Vector4(a.r,a.g,a.b,a.a).distance_to(Vector4(b.r,b.g,b.b,b.a)) < 0.00001
func sample(_key: StringName) -> Color:
	return Color(0.5,0.7,0.3,1)
func _initialize() -> void:
	var src := Color(0.5,0.7,0.3,0.2)
	var dst := Color(0.8,0.1,0.2,0.4)
	var base := Color(src.r,src.g,src.b,0.75)
	var bound := Palette.bind_palette([src],[dst],false)
	check(bound.ok and bound.enabled and bound.count==1,"有效作者配对")
	check(bound.source.size()==16 and bound.target.size()==16,"固定16槽")
	check(bound.source[0]==src and bound.target[0]==dst,"Gamma不改参数")
	check(near(Palette.apply(base,1,bound),Color(dst.r,dst.g,dst.b,base.a)),"匹配只替换RGB保留alpha")
	for id in range(12):
		if id!=1: check(Palette.apply(base,id,bound)==base,"同RGB非主体不能改色")
	for alpha in [0.0,0.49,0.5]:
		var c := Color(base.r,base.g,base.b,alpha)
		check(Palette.apply(c,1,bound)==c,"本体alpha门禁严格大于一半")
	var duplicate := Palette.bind_palette([Color(src.r+0.002,src.g,src.b),src],[dst,Color.BLUE],false)
	check(near(Palette.apply(base,1,duplicate),Color(dst.r,dst.g,dst.b,base.a)),"取首个近似匹配而非最近匹配")
	for channel in 3:
		var c := base
		c[channel]+=0.0038
		check(near(Palette.apply(c,1,bound),Color(dst.r,dst.g,dst.b,c.a)),"每通道容差内")
		c=base
		c[channel]+=0.004
		check(Palette.apply(c,1,bound)==c,"任一通道容差外不匹配")
	# 低亮度单色即使有精确配对仍不替换；不使用算术平均。
	var low:=Color(0.4,0,0,1)
	var low_map:=Palette.bind_palette([low],[dst],false)
	check(Palette.apply(low,1,low_map)==low,"加权亮度过滤")
	var high:=Color(0,0.3,0,1)
	check(near(Palette.apply(high,1,Palette.bind_palette([high],[dst],false)),Color(dst.r,dst.g,dst.b,1)),"加权而非平均亮度")
	for pair in [[null,null],[[],[dst]],[[src],[]],[null,[dst]],[[src],null]]:
		var empty:=Palette.bind_palette(pair[0],pair[1],true)
		check(empty.ok and not empty.enabled and empty.count==0,"空配置不继承旧颜色")
		check(Palette.apply(base,1,empty)==base,"关闭保持原色")
	var many:Array=[]
	var targets:Array=[]
	for index in 20:
		many.append(src)
		targets.append(dst)
	check(Palette.bind_palette(many,targets,false).count==16,"16色上限")
	check(Palette.bind_palette(many,[dst,dst],false).count==2,"双数组最短长度")
	many[19]="unused"
	check(Palette.bind_palette(many,targets,false).ok,"截断外条目未读")
	for bad in ["bad",[Color(2,0,0,1)],[Color(NAN,0,0,1)],[7]]:
		check(not Palette.bind_palette(bad,[dst],true).ok,"未验证输入不猜测")
	var linear:=Palette.bind_palette([src],[dst],true)
	# 独立 sRGB 传递函数数值，避免只比较调用自身的结果。
	check(near(linear.source[0],Color(0.21404114,0.44798841,0.07323896,0.2)),"源中间色明确转线性且保留alpha")
	check(near(linear.target[0],Color(0.60382734,0.01002283,0.03310477,0.4)),"目标也明确转线性")
	var lin_input:=Color(0.21404114,0.44798841,0.07323896,0.75)
	check(near(Palette.apply(lin_input,1,linear),Color(0.60382734,0.01002283,0.03310477,0.75)),"同一线性色域匹配")
	check(Palette.apply(base,1,linear)==base,"原始sRGB不得冒充线性纹理")
	var overlay:=Mix.compose(base,{&"head":true},0,false,{&"hair":true},{},sample,sample)
	check(overlay.source_id!=1 and Palette.apply(overlay.color,overlay.source_id,bound)==overlay.color,"同RGB头发按实际来源排除")
	var main:=Mix.compose(base,{},0,false,{},{},sample,sample)
	check(main.source_id==1 and near(Palette.apply(main.color,main.source_id,bound),Color(dst.r,dst.g,dst.b,base.a)),"实际本体来源连接")
	if failed==0: print("PASS equipment_skin_palette: ",count)
	quit(1 if failed else 0)
