extends SceneTree

const SlotIcon := preload("res://gameplay/equipment_workbench/slot_icon.gd")
const Scene := preload("res://gameplay/equipment_workbench/equipment_system_demo.tscn")
# 由独立 CPU 原规则核算，不包含素材或输出像素。
const EXPECTED := [
	"a32a10ee2f99437f73dcb8f8d4b06c8860039332b6069bc9f3c7744d13aeadb4",
	"08da0e003cd32612d87b4680c981c487d3afd91ffdcc1848b8636ac871b1df80",
	"9ea2c48f8f8a329f3ae9179bb3050f230b3a582779e9c3c0618d087a90e6e37b",
]
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func digest(tex: Texture2D) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(tex.get_image().get_data())
	return hash.finish().hex_encode()

func run() -> void:
	var sprite := Image.create_empty(32,32,false,Image.FORMAT_RGBA8)
	sprite.fill_rect(Rect2i(10,8,3,4),Color.WHITE)
	check(SlotIcon.from_sprite(sprite).get_image().get_used_rect()==Rect2i(5,1,22,30),
		"原 Mathf 的 .5 中点到偶数，而非 23 像素宽")
	sprite.fill(Color.TRANSPARENT)
	sprite.fill_rect(Rect2i(0,8,25,1),Color.WHITE)
	sprite.set_pixel(14,8,Color.RED)
	sprite.set_pixel(15,8,Color.BLUE)
	check(SlotIcon.from_sprite(sprite).get_image().get_pixel(19,16)==Color.RED,
		"原 float32 除法在 X=19 采样 14 而不是 15")
	sprite.fill(Color.TRANSPARENT)
	sprite.fill_rect(Rect2i(4,25,3,2),Color.WHITE)
	sprite.set_pixel(13,24,Color8(5,77,15,3))
	sprite.set_pixel(8,25,Color8(5,77,15,2))
	var disconnected := SlotIcon.from_sprite(sprite).get_image()
	check(disconnected.get_used_rect()==Rect2i(1,12,30,9) and disconnected.get_pixel(28,12).a>0.01
		and disconnected.get_pixel(15,17).a==0.0, "保留所有不连通轮廓，忽略低透明像素，双轴居中")
	var narrow := Image.create_empty(7,12,false,Image.FORMAT_RGBA8)
	narrow.fill_rect(Rect2i(4,8,3,4),Color.WHITE)
	check(SlotIcon.from_sprite(narrow).get_image().get_used_rect()==Rect2i(5,1,22,30), "读实际 Sprite 尺寸")
	var blank := Image.create_empty(32,32,false,Image.FORMAT_RGBA8)
	blank.set_pixel(2,4,Color8(255,0,0,2))
	check(SlotIcon.from_sprite(blank).get_image().get_pixel(2,4)==Color8(255,0,0,2), "无法正规化时返回原图")
	var raw := ImageTexture.create_from_image(blank)
	check(SlotIcon.from_texture(raw)==raw,"未生成纹理时保留同一源资源")
	if not OS.get_environment("FANTASYWORD_WORKBENCH_DWARF_ELF").is_empty():
		await check_scene()
	print(("PASS" if failures==0 else "FAIL")+" 原工作台装备缩略图：%d/%d" % [checks-failures,checks])
	quit(int(failures!=0))

func check_scene() -> void:
	var screen := Scene.instantiate()
	root.add_child(screen)
	await process_frame
	check(screen.ready_for_preview and screen._cloak!=null, "原工作台加载")
	if not screen.ready_for_preview or screen._cloak==null:
		screen.free()
		return
	var slots: Array[Button] = [
		screen._equip,screen._cloak_slots.get_node("EquipTravelCloak"),screen._cloak_slots.get_node("EquipHeavyCloak"),
	]
	var textures: Array[Texture2D] = []
	for i in slots.size():
		var icon: Texture2D = slots[i].icon
		check(icon.get_size()==Vector2(32,32) and digest(icon)==EXPECTED[i], "按钮完整 RGBA 原规则 "+str(i))
		textures.append(icon)
	check(screen._material.get_shader_parameter("cloth_map")==screen._cloth and screen._cloth!=textures[0],
		"布衣材质不引用按钮缩略纹理")
	screen._remove.pressed.emit()
	screen.find_child("CloakCategory",true,false).pressed.emit()
	slots[1].pressed.emit()
	check(screen._cloak.selected==0 and screen._material.get_shader_parameter("enabled_cloak") and
		screen._material.get_shader_parameter("cloak_map")!=textures[1], "实际服装状态使用原纹理而非按钮缩略图")
	var picker := screen.find_child("SourceCharacterPicker",true,false)
	picker.get_node("Dwarf").pressed.emit()
	slots[2].pressed.emit()
	check(screen._race_views.Dwarf.cloak_selected==1, "矮人从同一槽选择厚斗篷")
	picker.get_node("Elf").pressed.emit()
	screen._cloak_slots.get_node("RemoveCloak").pressed.emit()
	check(screen._race_views.Elf.cloak_selected==-1, "切换精灵保留空披风选择")
	for i in slots.size():
		check(slots[i].icon==textures[i] and digest(slots[i].icon)==EXPECTED[i], "换装、角色切换后图标稳定 "+str(i))
	screen.free()
