extends SceneTree
const Tiled := preload("res://gameplay/clickmovetest/source_menu_tiled_image.gd")
var failed := 0
var checks := 0
func _initialize() -> void: call_deferred("run")

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		printerr("FAIL ",what)

func patch_at(patches: Array[Dictionary], position: Vector2) -> Dictionary:
	for patch in patches:
		if patch.destination.has_point(position): return patch
	return {}

func run() -> void:
	var body := Tiled.new()
	var frame := Tiled.new()
	check(not body.bind({}, "", "Menu Items") and body.patches(Vector2(80,560)).is_empty(),
		"缺少锁定素材时不画占位")
	var directory := OS.get_environment("FORMAL_PAUSE_SOURCE")
	if directory.is_empty():
		print("SKIP 私有原暂停菜单图集")
	else:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("pause-contract.json")))
		var png := directory.path_join("SPS_GUI.png")
		var wrong := data.duplicate(true)
		wrong.tiled_images.Frame.sprite_id = wrong.tiled_images["Menu Items"].sprite_id
		check(not frame.bind(wrong,png,"Frame") and not frame.bind(data,"res://project.godot","Frame"),
			"拒绝错误的原 sprite ID 或图集")
		var body_ok := body.bind(data,png,"Menu Items")
		var frame_ok := frame.bind(data,png,"Frame")
		check(body_ok and frame_ok, "仅绑定原基础背景和边框")
		if body_ok and frame_ok:
			var blocks := body.patches(Vector2(80,560))
			var edges := frame.patches(Vector2(144,624))
			check(blocks.size()==72 and edges.size()==56, "包含四角、边缘及即使透明仍平铺的中心")
			var cropped := patch_at(blocks,Vector2(60,7))
			check(cropped.get("destination")==Rect2(42,6,32,8)
				and (cropped.get("source",Rect2()) as Rect2).is_equal_approx(Rect2(1,31-8.0/6.0,32.0/6.0,8.0/6.0)),
				"背景源相位从左下开始，顶部及右端裁切")
			check(patch_at(edges,Vector2(100,39)).get("source")==Rect2(8,44,4,4)
				and patch_at(edges,Vector2(70,560)).get("source")==Rect2(8,40,8,8),
				"边框顶端残片采用原图下半片，右端采用左半片")
			check(frame.patches(Vector2(60,60)).size()==4, "过小矩形仅按比缩短边框，不生成负宽瓦片")
			if DisplayServer.get_name()!="headless":
				root.size = Vector2i(1920,1080)
				var backdrop := ColorRect.new()
				backdrop.color = Color.BLACK
				backdrop.size = Vector2(1920,1080)
				root.add_child(backdrop)
				body.position = Vector2(40,260)
				body.size = Vector2(80,560)
				frame.position = Vector2(8,228)
				frame.size = Vector2(144,624)
				root.add_child(body)
				root.add_child(frame)
				await RenderingServer.frame_post_draw
				var drawn := root.get_texture().get_image()
				check(drawn.get_pixel(29,285).to_html(false)=="3f2832"
					and drawn.get_pixel(29,291).to_html(false)=="743f39",
					"原生 framebuffer 采样实际的左框裁切顶瓦片与下一块边瓦片")
				check(drawn.get_pixel(80,450).to_html(false)=="3a4466"
					and drawn.get_pixel(4,225).to_html(false)=="000000",
					"边框透明中心透出真背景、矩形外无绘制")
	if body.get_parent()==null: body.free()
	if frame.get_parent()==null: frame.free()
	if failed==0: print("PASS 原暂停菜单背景与边框：",checks," 项（",DisplayServer.get_name(),"）")
	quit(1 if failed else 0)
