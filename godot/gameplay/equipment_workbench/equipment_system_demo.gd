extends Control
## 独立迁移原 EquipmentSystemDemo 的人类可考证的换装预览，不接入正式角色或库存。
const HumanPresentation = preload("res://gameplay/clickmovetest/human_presentation.gd")
const CloakPreview = preload("res://gameplay/equipment_workbench/cloak_preview.gd")
const BagPreview = preload("res://gameplay/equipment_workbench/bag_preview.gd")
const Headwear = preload("res://gameplay/equipment_workbench/headwear_preview.gd")
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
const CLOTH_SHA := "95616de6ca800e3ee1baf2e1d6bac8832c6237cf2d784901e6fa1ea78a09bde9"
const SILVER_SHA := "7adcf56d93142ded08ff18196f78fcaaf552411b9a94dc559dac90eb5c91cef1"
const CJK_SHA := "763146584cf0710223441356b4395e279021b0806c196614377a7a0174ae074a"
const ACTIONS := {"Idle":"待机", "Walk":"行走", "Attack":"攻击", "Dmg":"受伤"}
const DIRECTIONS := ["东南", "西南", "东北", "西北"]
const REF_SIZE := Vector2(1600, 900)
const SLOT_IDLE := Color(0.22, 0.26, 0.31)
const SLOT_ACTIVE := Color(0.34, 0.46, 0.33)
const SLOT_EQUIPPED := Color(0.20, 0.36, 0.50)
const TEXT_PRIMARY := Color(0.96, 0.98, 1)
const ACCENT := Color(0.87, 0.80, 0.58)

var ready_for_preview := false
var last_error := ""
var _canvas: Control
var _human: Node2D
var _font: FontFile
var _cloth: ImageTexture
var _material: ShaderMaterial
var _details: Label
var _remove: Button
var _equip: Button
var _remove_badge: Label
var _equip_badge: Label
var _cloak: CloakPreview
var _bag: BagPreview
var _bag_slots: GridContainer
var _bag_buttons: Array[Button] = []
var _bag_badges: Array[Label] = []
var _cloth_slots: GridContainer
var _cloak_slots: GridContainer
var _headwear: Headwear
var _head_lists: Dictionary = {}
var _head_buttons: Dictionary = {}
var _head_badges: Dictionary = {}
var _categories: Dictionary = {}
var _cloak_buttons: Array[Button] = []
var _cloak_badges: Array[Label] = []
var _category := 0
var _actions: Array[Button] = []
var _directions: Array[Button] = []

func _ready() -> void:
	var source_dir := OS.get_environment("FANTASYWORD_WORKBENCH_SOURCE")
	if source_dir.is_empty() or not _load_source(source_dir):
		_show_unavailable()
		return
	_mount_ui()
	resized.connect(_resize_workbench)
	_resize_workbench()
	ready_for_preview = true
	_refresh()

func _load_source(source_dir: String) -> bool:
	# 路径是用户指定的本地私有资源。校验资产哈希；不按相似名称挑选替代图。
	var art := OS.get_environment("FANTASYWORD_WORKBENCH_HUMAN_ART")
	var cloth_path := OS.get_environment("FANTASYWORD_WORKBENCH_CLOTH")
	var silver := _load_font(OS.get_environment("FORMAL_PANEL_SILVER"), SILVER_SHA)
	var cjk := _load_font(OS.get_environment("FORMAL_PANEL_CJK"), CJK_SHA)
	if silver == null or cjk == null: return _fail("未提供匹配原工作台的 Silver / NotoSansSC 字体。")
	silver.fallbacks = [cjk]
	_font = silver
	var manifest := _read(source_dir.path_join("workbench.json"))
	if manifest.get("source_commit") != SOURCE or manifest.get("scene") != "Assets/Scenes/EquipmentSystemDemo.unity":
		return _fail("缺少锁定 Unity EquipmentSystemDemo 的私有资料。")
	var animation := _read(source_dir.path_join("animation.json"))
	var materials := _read(source_dir.path_join("material.json"))
	var actions: Variant = animation.get("actions")
	if not actions is Dictionary or not actions.has_all(["Idle", "Walk", "Attack"]) or actions.size() != (4 if actions.has("Dmg") else 3):
		return _fail("缺少本阶段人类原待机、行走和攻击的完整四向动画。")
	if actions.has("Dmg"):
		_cloak = CloakPreview.new()
		if not _cloak.load_source(source_dir):
			return _fail("缺少原披风图集或人类躯干帧合同。")
	var bag_dir := OS.get_environment("FANTASYWORD_WORKBENCH_BAG")
	if not bag_dir.is_empty():
		_bag = BagPreview.new()
		if _cloak == null or not _bag.load_source(bag_dir):
			return _fail("缺少原小背包图集、方向裁切合同或四动作躯干帧。")
	var head_dir := OS.get_environment("FANTASYWORD_WORKBENCH_HEADWEAR")
	if not head_dir.is_empty():
		_headwear = Headwear.new()
		if not _headwear.load_source(head_dir):
			return _fail("缺少锁定原头部装备图集或方向合同。")
	var image := Image.new()
	if FileAccess.get_sha256(cloth_path) != CLOTH_SHA or image.load(cloth_path) != OK or image.get_size() != Vector2i(32, 32):
		return _fail("未提供与原布衣一致的私有贴图。")
	_cloth = ImageTexture.create_from_image(image)
	_human = HumanPresentation.new()
	_human.name = "EquipmentSystemDemoCharacter"
	add_child(_human)
	if not _human.configure(animation, art) or not _human.bind_base_material(materials, art.path_join("uv"), art.path_join("appearance")):
		var reason: String = _human.last_error
		_human.free()
		_human = null
		return _fail(reason)
	_material = _human.sprite.material
	_material.set_shader_parameter("cloth_map", _cloth)
	_material.set_shader_parameter("cloth_rect", Vector4(0, 0, 1, 1))
	_set_cloth(true)
	if _cloak != null: _cloak.bind(_material, _human.playback)
	if _bag != null: _bag.bind(_material, _human.playback, _cloak.torso_for_sample)
	if _headwear != null: _human.material_binding.set_workbench_headwear({})
	return true

func _mount_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.19215687, 0.3019608, 0.4745098)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_canvas = Control.new()
	_canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.size = REF_SIZE
	var title := _label(_canvas, "换装预览", 22)
	title.position = Vector2(32, 26)
	title.size = Vector2(320, 40)
	var left := _label_column("角色", 316)
	var player := _button(left, "人类", Vector2(84, 92))
	player.name = "Human"
	player.pressed.connect(_reset_human)
	_header(left, "动作")
	var action_scroll := ScrollContainer.new()
	left.add_child(action_scroll)
	action_scroll.custom_minimum_size.y = 270
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var action_row := GridContainer.new()
	action_row.columns = 3
	action_row.add_theme_constant_override("h_separation", 8)
	action_scroll.add_child(action_row)
	for key in ["Idle", "Walk", "Wait", "Attack", "Dmg"]:
		if key == "Wait":
			_button(action_row, "等待", Vector2(88, 32)).disabled = true
			continue
		if key == "Dmg" and _cloak == null: continue
		var button := _button(action_row, ACTIONS[key], Vector2(88, 32))
		button.name = key
		button.pressed.connect(_select_action.bind(key))
		_actions.append(button)
	_header(left, "方向")
	var direction_grid := GridContainer.new()
	direction_grid.columns = 3
	direction_grid.add_theme_constant_override("h_separation", 8)
	direction_grid.add_theme_constant_override("v_separation", 8)
	left.add_child(direction_grid)
	for index in DIRECTIONS.size():
		var button := _button(direction_grid, DIRECTIONS[index], Vector2(88, 32))
		button.name = ["SE", "SW", "NE", "NW"][index]
		button.pressed.connect(_select_direction.bind(index))
		_directions.append(button)
	_style(player, SLOT_ACTIVE)

	var right := _label_column("类型", 470)
	var categories := GridContainer.new()
	categories.columns = 3
	categories.add_theme_constant_override("h_separation", 8)
	categories.add_theme_constant_override("v_separation", 6)
	right.add_child(categories)
	_button(categories, "形象", Vector2(96, 34)).disabled = true
	_add_category(categories, 0, "服装", "ClothCategory")
	if _cloak != null: _add_category(categories, 1, "斗篷", "CloakCategory")
	if _headwear != null:
		for kind: int in Headwear.CATEGORIES:
			_add_category(categories, kind, Headwear.CATEGORIES[kind], ["HelmetCategory", "HatCategory", "MaskCategory"][kind - 5])
	if _bag != null: _add_category(categories, 2, "背包", "BagCategory")
	_header(right, "装备列表")
	var scroll := ScrollContainer.new()
	right.add_child(scroll)
	scroll.custom_minimum_size.y = 340
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lists := VBoxContainer.new()
	scroll.add_child(lists)
	_cloth_slots = _slot_grid(lists)
	_remove = _button(_cloth_slots, "卸下", Vector2(108, 96))
	_remove.name = "RemoveCloth"
	_equip_slot_icon(_remove, _empty_slot_icon())
	_remove.pressed.connect(_set_cloth.bind(false))
	_equip = _button(_cloth_slots, "布衣", Vector2(108, 96))
	_equip.name = "EquipCloth"
	_equip.pressed.connect(_set_cloth.bind(true))
	_equip_slot_icon(_equip, _cloth)
	_remove_badge = _badge(_remove, "当前为空")
	_equip_badge = _badge(_equip, "已装备")
	if _cloak != null:
		_cloak_slots = _slot_grid(lists)
		for index in range(-1, _cloak.options.size()):
			var option: Dictionary = _cloak.options[index] if index >= 0 else {}
			var button := _button(_cloak_slots, option.get("name", "卸下"), Vector2(108, 96))
			button.name = ["RemoveCloak", "EquipTravelCloak", "EquipHeavyCloak"][index + 1]
			_equip_slot_icon(button, _cloak.icon_for(index) if index >= 0 else _empty_slot_icon())
			button.pressed.connect(_select_cloak.bind(index))
			_cloak_buttons.append(button)
			_cloak_badges.append(_badge(button, "已装备" if index >= 0 else "当前为空"))
	if _bag != null:
		_bag_slots = _slot_grid(lists)
		for i in 2:
			var button := _button(_bag_slots, "卸下" if i == 0 else _bag.display_name, Vector2(108, 96))
			button.name = "RemoveBag" if i == 0 else "EquipBag"
			_equip_slot_icon(button, _empty_slot_icon() if i == 0 else _bag.icon())
			button.pressed.connect(_select_bag.bind(i == 1))
			_bag_buttons.append(button)
			_bag_badges.append(_badge(button, "当前为空" if i == 0 else "已装备"))
	if _headwear != null:
		for kind: int in Headwear.CATEGORIES:
			_mount_headwear_slots(lists, kind)
	_header(right, "当前装备")
	var detail_box := PanelContainer.new()
	detail_box.custom_minimum_size.y = 156
	detail_box.add_theme_stylebox_override("panel", _box(Color(0.09, 0.11, 0.14, 0.94), 12, 0))
	right.add_child(detail_box)
	_details = _label(detail_box, "", 14)
	_details.name = "CurrentDetails"
	_details.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _add_category(parent: Container, id: int, label: String, node_name: String) -> void:
	var category := _button(parent, label, Vector2(96, 34))
	category.name = node_name
	category.pressed.connect(_select_category.bind(id))
	_categories[id] = category

func _mount_headwear_slots(parent: Container, kind: int) -> void:
	var slots := _slot_grid(parent)
	_head_lists[kind] = slots
	_head_buttons[kind] = {}
	_head_badges[kind] = {}
	var ids: Array[int] = _headwear.ids_for(kind)
	ids.push_front(-1)
	for id in ids:
		var option: Dictionary = _headwear.options[id] if id >= 0 else {}
		var button := _button(slots, option.get("name", "卸下"), Vector2(108, 96))
		if id < 0:
			button.name = ["RemoveHelmet", "RemoveHat", "RemoveMask"][kind - 5]
			button.pressed.connect(_remove_headwear.bind(kind))
		else:
			button.name = Headwear.BUTTON_NAMES[option.name]
			button.pressed.connect(_select_headwear.bind(id))
		_equip_slot_icon(button, _empty_slot_icon() if id < 0 else option.icon)
		_head_buttons[kind][id] = button
		_head_badges[kind][id] = _badge(button, "当前为空" if id < 0 else "已装备")

func _select_headwear(id: int) -> void:
	_headwear.select_option(id)
	_human.material_binding.set_workbench_headwear(_headwear.render_entry())
	_refresh()

func _remove_headwear(kind: int) -> void:
	_headwear.unequip(kind)
	_human.material_binding.set_workbench_headwear(_headwear.render_entry())
	_refresh()

func _slot_grid(parent: Container) -> GridContainer:
	var slots := GridContainer.new()
	slots.columns = 4
	slots.add_theme_constant_override("h_separation", 4)
	slots.add_theme_constant_override("v_separation", 8)
	parent.add_child(slots)
	return slots

func _select_category(index: int) -> void:
	_category = index
	_refresh()

func _select_cloak(index: int) -> void:
	_cloak.select(index)
	_refresh()

func _select_bag(worn: bool) -> void:
	_bag.select(worn)
	_refresh()

func _label_column(title: String, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "CharacterPanel" if width == 316.0 else "EquipmentPanel"
	panel.position = Vector2(16, 16)
	panel.size = Vector2(width, REF_SIZE.y - 32.0)
	panel.add_theme_stylebox_override("panel", _box(Color(0.09, 0.11, 0.14, 0.74), 12, 0))
	_canvas.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_header(column, title)
	return column

func _resize_workbench() -> void:
	if _canvas == null: return
	# Unity CanvasScaler 的 MatchWidthOrHeight=0.5 在对数空间插值；
	# 正交相机则跟物理视窗的高度变动，二者不能共用一个缩放。
	var ui_scale := sqrt(size.x / REF_SIZE.x * size.y / REF_SIZE.y)
	if ui_scale <= 0.0: return
	_canvas.scale = Vector2.ONE * ui_scale
	_canvas.size = size / ui_scale
	_canvas.get_node("CharacterPanel").size.y = _canvas.size.y - 32.0
	var right: Control = _canvas.get_node("EquipmentPanel")
	right.size.y = _canvas.size.y - 32.0
	right.position.x = _canvas.size.x - 486.0
	var camera_scale := size.y / 9.0
	_human.scale = Vector2.ONE * camera_scale
	_human.position = size * 0.5 + Vector2(-0.25 * camera_scale, 0)

func _reset_human() -> void:
	_human.driver.try_play_animation("Idle")
	_human.animator.seek(0.0, true)
	_human.playback.set_direction(0)
	if _cloak != null: _cloak.select(-1)
	if _bag != null: _bag.select(false)
	if _headwear != null:
		_headwear.select_option(-1)
		_human.material_binding.set_workbench_headwear({})
	_set_cloth(true)

func _select_action(key: String) -> void:
	if ACTIONS.has(key) and _human.driver.try_play_animation(key):
		# Workbench SelectAnimation uses SetAnimation, not the gameplay damage auto-return.
		_human.driver.cancel_pending_restore()
		_refresh()

func _select_direction(index: int) -> void:
	if _human.playback.set_direction(index):
		_refresh()

func _set_cloth(worn: bool) -> void:
	_material.set_shader_parameter("enabled_cloth", worn)
	if ready_for_preview: _refresh()

func _refresh() -> void:
	var worn: bool = _material.get_shader_parameter("enabled_cloth")
	var direction: int = _human.playback.current_direction
	var current: String = _human.driver.current_animation_key
	for i in _actions.size():
		_style(_actions[i], SLOT_ACTIVE if _actions[i].name == current else SLOT_IDLE)
	for i in _directions.size():
		_style(_directions[i], SLOT_ACTIVE if direction == i else SLOT_IDLE)
	_style(_remove, SLOT_IDLE if worn else SLOT_ACTIVE)
	_style(_equip, SLOT_EQUIPPED if worn else SLOT_IDLE)
	_remove_badge.visible = not worn
	_equip_badge.visible = worn
	var category_text := "布衣\n服装\n生命 +6" if worn else "服装\n当前为空"
	for i: int in _categories:
		_style(_categories[i], SLOT_ACTIVE if i == _category else SLOT_IDLE)
	_cloth_slots.visible = _category == 0
	if _cloak != null:
		_cloak_slots.visible = _category == 1
		for i in _cloak_buttons.size():
			var current_slot := _cloak.selected + 1 == i
			_style(_cloak_buttons[i], (SLOT_ACTIVE if i == 0 else SLOT_EQUIPPED) if current_slot else SLOT_IDLE)
			_cloak_badges[i].visible = current_slot
		if _category == 1:
			category_text = "斗篷\n当前为空" if _cloak.selected < 0 else _cloak.details_for(_cloak.selected)
	if _bag != null:
		_bag_slots.visible = _category == 2
		for i in _bag_buttons.size():
			var current_slot := _bag.worn == (i == 1)
			_style(_bag_buttons[i], (SLOT_ACTIVE if i == 0 else SLOT_EQUIPPED) if current_slot else SLOT_IDLE)
			_bag_badges[i].visible = current_slot
		if _category == 2: category_text = _bag.details()
	if _headwear != null:
		for kind: int in _head_lists:
			_head_lists[kind].visible = _category == kind
			var equipped := _headwear.equipped_in(kind)
			for id: int in _head_buttons[kind]:
				_style(_head_buttons[kind][id], (SLOT_ACTIVE if id < 0 else SLOT_EQUIPPED) if id == equipped else SLOT_IDLE)
				_head_badges[kind][id].visible = id == equipped
			if _category == kind: category_text = _headwear.details(kind)
	_details.text = "角色 人类 | 形象 基础人形外观\n动作 %s | 方向 %s\n身体动画 %s\n\n%s" % [
		ACTIONS[current], DIRECTIONS[direction], ACTIONS[current],
		category_text]

func _header(parent: Control, value: String) -> void:
	_label(parent, value, 20).custom_minimum_size.y = 28

func _equip_slot_icon(button: Button, texture: Texture2D) -> void:
	button.icon = texture
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = TEXTURE_FILTER_NEAREST
	button.add_theme_constant_override("icon_max_width", 32)

func _empty_slot_icon() -> ImageTexture:
	# 源工作台运行时代码生成的 16×16 卸下图标；坐标从左下转左上。
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	var frame := Color(0.57, 0.64, 0.70, 0.95)
	var mark := Color(0.35, 0.41, 0.48, 0.95)
	for x in range(4, 12):
		for y in [4, 12]: image.set_pixel(x, 15 - y, frame)
	for x in [3, 4, 11, 12]:
		for y in range(5, 12): image.set_pixel(x, 15 - y, frame)
	for x in range(6, 10):
		for y in [7, 8]: image.set_pixel(x, 15 - y, mark)
	return ImageTexture.create_from_image(image)

func _badge(parent: Button, value: String) -> Label:
	var badge := _label(parent, value, 13)
	badge.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	badge.position.y -= 17
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", ACCENT)
	return badge

func _label(parent: Control, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.text = value
	if _font != null: label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	parent.add_child(label)
	return label

func _button(parent: Container, value: String, minimum: Vector2) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = minimum
	button.size_flags_horizontal = SIZE_SHRINK_BEGIN
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	parent.add_child(button)
	_style(button, SLOT_IDLE)
	return button

func _style(button: Button, color: Color) -> void:
	button.add_theme_stylebox_override("normal", _box(color))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.09)))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.1)))

func _box(color: Color, pad := 4, border := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(border)
	style.border_color = Color(0, 0, 0, 0.35)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, pad)
	return style

func _read(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _load_font(path: String, sha: String) -> FontFile:
	if path.is_empty() or FileAccess.get_sha256(path) != sha: return null
	var result := FontFile.new()
	return result if result.load_dynamic_font(path) == OK else null

func _show_unavailable() -> void:
	_label(self, last_error if not last_error.is_empty() else "未指定原换装工作台私有资料，本入口不会使用替代素材。", 20)

func _fail(message: String) -> bool:
	last_error = message
	return false
