extends SceneTree
const Head = preload("res://game_core/presentation/equipment_head_layer.gd")
var base := Color(0.2,0.3,0.4,0.25)
var checks := 0
var failures := 0
var taps: Array = []
var data := {}
var layers := {&"helmet":true,&"beard":true,&"face_accessory":true,&"hair":true,&"eye_decoration":true,&"mask":true}

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(msg)

func _sample(key: StringName) -> Color:
	taps.append(key)
	return data.get(key,Color.TRANSPARENT)

func _apply(head_id := true, hand_id := false, enabled := layers) -> Dictionary:
	taps.clear()
	return Head.apply(base,head_id,hand_id,enabled,_sample)

func _initialize() -> void:
	var clear := {"color":base,"source_id":Head.SRC_NONE,"layer_alpha":0.0}
	check(_apply(false,false) == clear and taps.is_empty(),"非头部不采样")
	check(_apply(true,true) == clear and taps.is_empty(),"头部区域中的手禁止覆盖")
	check(_apply() == clear and taps.size() == 6,"透过所有纹理保留底色")
	data[&"helmet"] = Color(1.0,0.0,0.0,0.501)
	data[&"mask"] = Color.BLUE
	var got := _apply()
	check(got.source_id == Head.SRC_HELMET and taps == [&"helmet"],"头盔成功立即返回，不再取面罩与下层")
	check(got.color == Color(1,0,0,base.a) and got.layer_alpha == 1.0,"成功采样替换 RGB，独立头层覆盖为一")
	data[&"helmet"].a = 0.5
	data[&"beard"] = Color.DARK_GREEN
	data[&"face_accessory"] = Color.RED
	data[&"hair"] = Color.ORANGE
	data[&"eye_decoration"] = Color.LAVENDER
	got = _apply()
	check(got.source_id == Head.SRC_MASK and taps == [&"helmet",&"beard",&"eye_decoration",&"mask"],
		"等于截止值的头盔不通过，胡须先取，眼饰再取，面罩最后")
	data.erase(&"mask")
	got = _apply()
	check(got.source_id == Head.SRC_FACE and got.color == Color(Color.LAVENDER,base.a),"眼饰盖住胡须")
	data.erase(&"eye_decoration")
	got = _apply()
	check(got.source_id == Head.SRC_BEARD and not taps.has(&"hair"),"成功胡须遮挡面饰与头发")
	data.erase(&"beard")
	got = _apply()
	check(got.source_id == Head.SRC_FACE and not taps.has(&"hair"),"成功面饰遮挡头发")
	got = _apply(true,false,{&"hair":true})
	check(got.source_id == Head.SRC_HAIR and taps == [&"hair"],"不启用的图层不能触发采样")
	if failures == 0: print("PASS 换装头部像素合成判据：%d 项" % checks)
	quit(1 if failures else 0)
