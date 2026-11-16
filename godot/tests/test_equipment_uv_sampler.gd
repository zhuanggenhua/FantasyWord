extends SceneTree
const Sampler = preload("res://game_core/presentation/equipment_uv_sampler.gd")
var count := 0
var failed := 0
func check(ok: bool, detail: String) -> void:
	count += 1
	if not ok:
		failed += 1
		push_error(detail)
func _initialize() -> void:
	var main := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	var body := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	var head := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	for y in range(8):
		for x in range(12):
			main.set_pixel(x,y,Color8(x * 17,y * 29,3,255))
			body.set_pixel(x,y,Color8(x * 19,y * 31,102,255))
			head.set_pixel(x,y,Color8(x * 21,y * 33,26,0))
	# 非零列与行，V 非对称；逐点覆盖整张图，避免上下翻转或帧局部误采样漏检。
	for y in range(8):
		for x in range(12):
			var uv := Vector2((x + 0.5) / 12.0,(y + 0.5) / 8.0)
			var samples := Sampler.sample_sheet(main,body,head,uv)
			check(samples.main == main.get_pixel(x,y),"主图同整图 UV")
			check(samples.body == body.get_pixel(x,y),"身体图同整图 UV")
			check(samples.head == head.get_pixel(x,y),"头部扩展透明像素仍保留 RGB")
	var frame := Rect2(0.25,0.5,0.25,0.25)
	check(Sampler.frame_local_uv(Vector2(0.3125,0.53125),frame).is_equal_approx(Vector2(0.25,0.875)),"整图转当前帧左下局部 UV")
	check(Sampler.frame_local_uv(frame.position,frame) == Vector2(0,1),"帧左上转左下坐标")
	check(Sampler.frame_local_uv(frame.end,frame) == Vector2(1,0),"帧右下转左下坐标")
	var rect := Sampler.rect_from_unity_bounds(Vector4(0.25,0.125,0.75,0.5))
	check(rect == Rect2(0.25,0.125,0.5,0.375),"xyzw 转 position+size")
	check(Sampler.equipment_uv(Vector2(0.2,0.8),rect).is_equal_approx(Vector2(0.35,0.575)),"编码 RG 先重映射装备矩形再翻转 V")
	check(Sampler.equipment_uv(Vector2.ZERO,rect) == Vector2(0.25,0.875),"装备左下")
	check(Sampler.equipment_uv(Vector2.ONE,rect) == Vector2(0.75,0.5),"装备右上")
	check(Sampler.sample_point(body,Vector2(-1,-1)) == body.get_pixel(0,0),"Clamp 负边界")
	check(Sampler.sample_point(body,Vector2(2,2)) == body.get_pixel(11,7),"Clamp 正边界")
	check(Sampler.sample_point(body,Vector2(0.25,0.5)) == body.get_pixel(3,4),"Point 不插值像素边界")
	check(Sampler.sample_point(body,Vector2(0.24999,0.49999)) == body.get_pixel(2,3),"Point 边界前像素")
	print("PASS equipment_uv_sampler %d checks" % count if failed == 0 else "FAIL equipment_uv_sampler %d" % failed)
	quit(0 if failed == 0 else 1)
