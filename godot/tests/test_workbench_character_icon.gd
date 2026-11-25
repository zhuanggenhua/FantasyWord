extends SceneTree

const Icon := preload("res://gameplay/equipment_workbench/character_preview_icon.gd")
const Scene := preload("res://gameplay/equipment_workbench/equipment_system_demo.tscn")
# 仅记录私有源素材经独立 Python CPU 算法所得 RGBA 哈希，不包含任何源图。
const EXPECTED := {
	"Human": "9d5ba8249caae2a25c3fcc6062a87080bf09b04ba495ac6741dfaf8c11001b52",
	"Dwarf": "79c6fbb10b6de89b5ad0cc587b9f10c8246d1f1fcfa9dcc3526a3140e1dec482",
	"Elf": "86aaff5379ad21081ad3530cfd0f6dee961c46527876905bab38196a644186dd",
	"Goblin": "48cc6eb3e6d4851a963aac459e1e8aad3e9443edb98e9e90c2548d0091f1e13f",
	"Orc": "4dd47d27ac220f9efad54f93c0013855e4dbab1dae2ec5f04eece8f665928532",
}
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)

func _digest(image: Image) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()

func run() -> void:
	var sample := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(8, 12):
		for x in range(11, 14):
			sample.set_pixel(x, y, Color8(y*11, x*7, x+y, 3 if x==11 and y==8 else 255))
	sample.set_pixel(14, 10, Color8(255, 0, 0, 2))
	sample.set_pixel(1, 1, Color8(1, 2, 3))
	sample.fill_rect(Rect2i(32, 0, 32, 32), Color.GREEN)
	_check(_digest(Icon.normalized(sample))=="951675f07c5813c51a4bda61b21645938459f1e6edc545192a06769ce83c1a55",
		"首格扫描、透明阈值与中点舍入")
	var tie := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	tie.fill_rect(Rect2i(2, 5, 2, 2), Color.RED)
	tie.fill_rect(Rect2i(20, 27, 2, 2), Color.BLUE)
	_check(Icon.normalized(tie).get_pixel(15, 15)==Color.BLUE, "等大轮廓保留 Unity 左下扫描先遇到者")
	if not OS.get_environment("FANTASYWORD_WORKBENCH_DWARF_ELF").is_empty() and not OS.get_environment("FANTASYWORD_WORKBENCH_NONHUMAN").is_empty():
		await _verify_screen()
	print(("PASS " if failures==0 else "FAIL ")+"角色选择图标：%d/%d" % [checks-failures, checks])
	quit(int(failures!=0))

func _verify_screen() -> void:
	var screen := Scene.instantiate()
	root.add_child(screen)
	await process_frame
	_check(screen.ready_for_preview, "进入锁定资源的换装预览："+screen.last_error)
	var picker := screen.find_child("SourceCharacterPicker", true, false) as GridContainer
	if picker == null:
		_check(false, "找不到正式角色选择格")
		screen.free()
		return
	_check(picker.columns == 3 and picker.get_child_count() == 5
		and picker.get_theme_constant("h_separation")==8 and picker.get_theme_constant("v_separation")==8, "原目录五角色三列")
	var textures := {}
	for i in EXPECTED.size():
		var key: String = EXPECTED.keys()[i]
		var button := picker.get_child(i) as Button
		var badge := button.get_node("CurrentBadge") as ColorRect
		var frame := button.get_node("IconFrame") as ColorRect
		var icon := frame.get_node_or_null("IdleThumbnail") as TextureRect
		_check(button.name==key and not button.disabled and button.size.y==92, key+" 原顺序、可选及格高")
		_check(frame.size==Vector2(68, 68) and frame.position.y==10 and is_equal_approx(frame.position.x+34,button.size.x/2), key+" 图标框尺寸及位置")
		_check(badge.visible==(key=="Human"), key+" 初始化时仅默认角色有当前徽标")
		_check(icon!=null and icon.texture.get_size()==Vector2(32,32)
			and _digest(icon.texture.get_image())==EXPECTED[key], key+" 原始首格图标字节")
		_check(icon!=null and icon.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST
			and icon.mouse_filter==Control.MOUSE_FILTER_IGNORE, key+" 最近邻与图标不拦截操作")
		if icon!=null: textures[key] = icon.texture
	var actions := screen.find_child("SourceActionRows", true, false)
	for key in ["Dwarf","Elf","Goblin","Orc","Human"]:
		picker.get_node(key).pressed.emit()
		_check(screen._race==key, key+" 由角色格触发")
		for item in EXPECTED:
			_check(picker.get_node(item+"/CurrentBadge").visible==(item==key), item+" 选中徽标单一")
		actions.get_node("Walk").pressed.emit()
		screen._select_direction(3)
		screen._set_cloth(false)
		for item in textures:
			var texture: Texture2D = picker.get_node(item+"/IconFrame/IdleThumbnail").texture
			_check(texture==textures[item] and _digest(texture.get_image())==EXPECTED[item], item+" 换装、切动作与方向不重算")
	screen.free()
