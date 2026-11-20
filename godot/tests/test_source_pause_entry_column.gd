extends SceneTree
const Column := preload("res://gameplay/clickmovetest/source_pause_entry_column.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func run() -> void:
	var col := Column.new()
	check(not col.bind({},"") and col.get_child_count()==0,"缺失素材不绘制替代面板")
	var directory := OS.get_environment("FORMAL_PAUSE_SOURCE")
	if directory.is_empty():
		print("SKIP 私有原菜单图集和预制体布局")
	else:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("pause-contract.json")))
		var path := directory.path_join("SPS_GUI.png")
		var changed := data.duplicate(true)
		changed.entry_layout.rows[4].visible = true
		check(not col.bind(changed,path) and col.get_child_count()==0,"不会错误显示无随身设施的 Craft")
		var ok := col.bind(data,path)
		check(ok and col.get_child_count()==3,"原底图、边框和入口图层")
		if ok:
			var entries := col.entries()
			var names: Array = entries.map(func(a):return a.label)
			check(names==["Character","Items","Abilities","Journal","Save","Settings","Quit"],"实际同级顺序不取 m_menus 六项")
			check(entries[6].action_name=="GoToMainMenu","Quit 不是应用退出")
			check(entries[0].icon==Rect2(56,276,48,48) and entries[4].hitbox==Rect2(40,580,80,80)
				and entries[6].label_rect==Rect2(168,748,256,64),"原预制体图标、菜单项与标签框")
			check(col.get_child(0).position==Vector2(40,260) and col.get_child(1).position==Vector2(8,228),
				"原左列位置与边框顺序")
			if DisplayServer.get_name()!="headless":
				root.size = Vector2i(1920,1080)
				root.add_child(col)
				await RenderingServer.frame_post_draw
				var rendered := root.get_texture().get_image()
				var atlas := Image.load_from_file(path)
				for entry in entries:
					var tinted := 0
					var transparent := 0
					var frame_ok := 0
					for y in range(8):
						for x in range(8):
							var delta := Vector2i(x,y)
							var pixel := atlas.get_pixelv(Vector2i(entry.region.position)+delta)
							var actual := rendered.get_pixelv(Vector2i(entry.icon.position)+delta*6+Vector2i(3,3))
							if pixel.a>.99:
								tinted += 1
								var expected := pixel*Color("#3f2832")
								# Canvas colors and the 8-bit framebuffer round at different stages.
								var error := Vector3(actual.r-expected.r,actual.g-expected.g,actual.b-expected.b).abs()
								if maxf(error.x,maxf(error.y,error.z))<=1.01/255.0: frame_ok += 1
							elif pixel.a<.01 and actual.to_html(false)=="3a4466": transparent += 1
					check(tinted>0 and frame_ok==tinted and transparent>0,"真正的原图标与底图像素："+entry.label)
	if col.get_parent()==null: col.free()
	if failures==0: print("PASS 原暂停菜单条目列：",checks," 项（",DisplayServer.get_name(),"）")
	quit(1 if failures else 0)
