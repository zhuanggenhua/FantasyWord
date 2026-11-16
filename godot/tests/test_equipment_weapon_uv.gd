extends SceneTree
const UV = preload("res://gameplay/presentation/equipment_weapon_uv.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:
	# 非零四个 atlas 边界 + 不同的帧锚点/武器 pivot，能检出 V 重翻与镜像时序。
	var char_frame := Rect2(0.25,0.125,0.5,0.5)
	var weapon := Rect2(0.375,0.25,0.25,0.5)
	var point := Vector2(0.5,0.5) # 角色帧局部 bottom (0.5,0.75)
	var hand := Vector2(0.25,0.5)
	var pivot := Vector2(0.375,0.5)
	var turn := Vector2(0,1)
	check(UV.sample_uv(point,char_frame,weapon,hand,pivot,turn,false,true) == Vector2(0.40625,0.375),
		"先从主图转换到帧，按手锚旋转后映射 off-origin 武器图集")
	check(UV.sample_uv(point,char_frame,weapon,hand,pivot,turn,true,true) == Vector2(0.53125,0.375),
		"先旋转再围绕虚拟手水平反转，而非反转角色 atlas")
	check(UV.sample_uv(point,char_frame,weapon,hand,pivot,Vector2.RIGHT,false,true) == Vector2(0.53125,0.375),
		"零旋转，武器局部平移不误用主图 UV")
	check(UV.sample_uv(point,char_frame,weapon,hand,pivot,turn,true,false) == null,"槽禁用")
	check(UV.sample_uv(Vector2(0.125,0.5),char_frame,weapon,hand,pivot,turn,false,true) == null,"角色帧外拒绝")
	check(UV.sample_uv(point,char_frame,weapon,hand,Vector2.ONE,Vector2.RIGHT,false,true) == null,"武器局部外拒绝")
	check(UV.sample_uv(point,Rect2(0,0,0.00009,0.5),weapon,hand,pivot,turn,false,true) == null,"角色帧最小矩形门禁")
	check(UV.sample_uv(Vector2(NAN,0.5),char_frame,weapon,hand,pivot,turn,false,true) == null,"非有限输入拒绝")
	check(UV.sample_uv(Vector2(0.25,0.875),char_frame,weapon,Vector2.ZERO,Vector2.ZERO,Vector2.RIGHT,false,true)
		== Vector2(0.375,0.75),"左下边缘包含")
	check(UV.sample_uv(Vector2(0.75,0.375),char_frame,weapon,Vector2.ZERO,Vector2.ZERO,Vector2.RIGHT,false,true)
		== Vector2(0.625,0.25),"右上边缘包含")
	var im := Image.create(4,4,false,Image.FORMAT_RGBAF)
	im.set_pixel(1,1,Color(0.2,0.7,0.1,0.5))
	im.set_pixel(2,1,Color(0.3,0.4,0.9,0.75))
	check(UV.sample_pixel(im,Vector2(0.40625,0.375)) == null,"严格 alpha 门禁")
	var color: Variant = UV.sample_pixel(im,Vector2(0.53125,0.375))
	check(color is Color and color.is_equal_approx(Color(0.3,0.4,0.9,0.75)),"独立色/透明度保留")
	check(UV.sample_pixel(im,null) == null,"拒绝未命中 UV")
	if failures == 0: print("PASS equipment_weapon_uv: ",checks)
	quit(1 if failures else 0)
