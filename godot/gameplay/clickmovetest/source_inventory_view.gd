extends Control
## 原 ClickMoveTest 背包/装备槽位读同一正式角色；不新增点击换装入口。
signal item_focus_changed(kind: int)
const Bag := preload("res://game_core/ui/source_inventory_bag_state.gd")
const Gear := preload("res://game_core/inventory/source_character_equipment.gd")
const Bags := preload("res://game_core/inventory/source_inventory_bags.gd")
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
const Text := preload("res://gameplay/clickmovetest/source_character_text.gd")
const Tiled := preload("res://gameplay/clickmovetest/source_menu_tiled_image.gd")
const Art := preload("res://gameplay/clickmovetest/source_inventory_sprite.gd")
const Layout := preload("res://gameplay/clickmovetest/source_character_selectables.gd")
const LAYOUT_SHA := "be020724e7cb4d6caa26b9c1164882cf0886c601d4b1060a1fe78a1ed82b58f8"
const SIZE := Vector2(1920,1080)
const GEAR := 31
const CATEGORY := 36
const LAST := 39
var model := Bag.new()
var _layout: Dictionary
var _background: Tiled
var _centre: Control
var _right: Control
var _cursor: Art
var _atlas := Atlas.new()
var _texture: Texture2D
var _silver: FontFile
var _targets: Dictionary = {}
var _lines: Array[Text] = []
var _category_art: Array[Art] = []
var _active := false
var _screen_scale := 1.0
var _focus := 0
var _hover := 0
var _pressed := 0
var _gear: Gear
var _control_changed: Signal
var _resolve_actor: Callable
var _resolve_values: Callable
var _initial_actor: WeakRef
var _shown_equipment: Array[Resource] = []
var _gear_icons: Dictionary = {}
var _gear_placeholders: Array[Art] = []
var _stat_values: Array[Text] = []
var _request_item_use: Callable
var _item_icons := {}
var _bag_icons: Array[Art] = []
var _bag_quantities: Array[Text] = []
var _pixel_scale := 1.0

func _init() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_IGNORE

static func load_layout(directory: String) -> Dictionary:
	var path := directory.path_join("inventory-layout.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=LAYOUT_SHA: return {}
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func bind(layout: Dictionary, pause: Dictionary, directory: String, silver_path: String,
		bags: Bags, owner: String, actor: Node, values: Array[int], gear: Gear,
		control_changed: Signal, resolve_actor: Callable, resolve_values: Callable) -> bool:
	if _background!=null or layout.is_empty() or layout.get("source_commit")!=Atlas.SOURCE \
			or layout.get("pause_action")!=1 or layout.get("registration")!=3 or values.size()!=8 \
			or bags==null or gear==null or not gear.belongs_to(actor) or control_changed.is_null() \
			or not resolve_actor.is_valid() or not resolve_values.is_valid(): return false
	_gear=gear
	_control_changed=control_changed
	_resolve_actor=resolve_actor
	_resolve_values=resolve_values
	_initial_actor=weakref(actor)
	# 只有两件已迁移作者物品；不把其他分类或资源悄悄映射为假物品。
	for row in bags.entries(owner):
		if _gear.slot_for_item(row.item)<0: return false
	if not model.show(bags,owner,actor,_category_for): return false
	model.details_opened.connect(_on_bag_details)
	model.details_closed.connect(func(): item_focus_changed.emit(-1))
	_layout=layout
	_silver=Text.load_silver(silver_path)
	if _silver==null or not _atlas.bind(pause,directory.path_join("pause-font-atlas.bin")): return false
	var data := pause.duplicate()
	var backing: Dictionary = layout.sprites.backing
	data.tiled_images={"Inventory Background":{"sprite_id":backing.id,"fill_center":true,"ppu_multiplier":1,
		"color":{"r":1,"g":1,"b":1,"a":1}}}
	data.sprites={backing.id:backing}
	_background=Tiled.new()
	add_child(_background)
	if not _background.bind(data,directory.path_join("SPS_GUI.png"),"Inventory Background"): return false
	_background.size=SIZE
	_texture=_background.get_atlas_texture()
	_centre=_group(self)
	_right=_group(self)
	if not _line(_centre,layout.title,layout.title.text): return false
	for footer in layout.footer:
		if not _line(self if footer.anchor=="bottom_left" else _right,footer,footer.text): return false
	for i in range(8):
		var row: Dictionary=layout.stat_rows[i]
		_blank(_centre,row.icon)
		if not _line(_centre,row.label,row.label.text) or not _line(_centre,row.value,str(values[i])): return false
		_stat_values.append(_lines.back())
	for source: Dictionary in layout.gears:
		var item := _gear.item_for_guid(source.guid)
		if item==null or _gear.slot_for_item(item)!=int(source.type): return false
		var path := directory.path_join(source.icon_file)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=source.icon_sha256: return false
		var image := Image.load_from_file(path)
		if image==null or image.get_size()!=Vector2i(32,32): return false
		_item_icons[item]=ImageTexture.create_from_image(image)
	for i in range(5):
		var box := Layout._rect(layout.equipment_rects[i])
		_targets[GEAR+i]=box
		_sprite(_centre,box,_texture,layout.sprites.slot,true)
		_gear_placeholders.append(_sprite(_centre,Rect2(box.get_center()-Vector2(24,24),Vector2(48,48)),
			_texture,layout.sprites["gear_placeholder_%d"%i],false))
		_shown_equipment.append(null)
		for row: Dictionary in layout.gears:
			if int(row.type)!=i: continue
			var item := _gear.item_for_guid(row.guid)
			_gear_icons[item]=_sprite(_centre,Layout._rect(row.rect),_item_icons[item],{},false)
			_gear_icons[item].hide()
	if not _refresh_equipment(): return false
	# Categories are painted in their actual sibling order (24-unit overlap).
	for i in range(4):
		var spec: Dictionary=layout.categories[i]
		var box := Layout._rect(spec.rect)
		_targets[CATEGORY+i]=box
		var group := _group(_centre)
		_category_art.append(_sprite(group,box,_texture,layout.sprites.category_normal,true))
		_blank(group,spec.icon_rect)
		if not _line(group,spec.label,spec.term): return false
	for i in range(30):
		var box := Layout._rect(layout.grid_cells[i].rect)
		_targets[i+1]=box
		_sprite(_centre,box,_texture,layout.sprites.slot,true)
		var offset := Layout._rect(layout.bag_icon)
		var image := Art.new()
		image.position=box.position+offset.position
		image.size=offset.size
		_centre.add_child(image)
		_bag_icons.append(image)
		var amount := Text.new()
		_centre.add_child(amount)
		_bag_quantities.append(amount)
	_cursor=_sprite(_centre,Rect2(),_texture,layout.sprites.cursor,false)
	_cursor.hide()
	return true

func _category_for(item: Resource) -> int:
	return Bag.Category.GEAR if _gear.slot_for_item(item)>=0 else -1

func _on_bag_details(item: Resource) -> void:
	if _active: item_focus_changed.emit(_gear.slot_for_item(item))

func _refresh_bag_graphics() -> void:
	var spec: Dictionary=_layout.bag_quantity
	var offset := Layout._rect(spec.rect)
	for index in range(30):
		var row := model.cell(index)
		var icon := _bag_icons[index]
		var amount := _bag_quantities[index]
		var texture: Texture2D=_item_icons.get(row.get("item"))
		if texture==null:
			icon.hide()
			amount.hide()
			continue
		var box: Rect2=_targets[index+1]
		icon.show_sprite(texture,{},false)
		icon.show()
		amount.visible=amount.configure(_atlas,_silver,str(row.quantity),
			Rect2(box.position+offset.position,offset.size),spec,_pixel_scale)

func _group(parent: Control) -> Control:
	var node := Control.new()
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _blank(parent: Control, raw: Array) -> void:
	var box := Layout._rect(raw)
	var node := ColorRect.new()
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.position=box.position
	node.size=box.size
	node.color=Color.WHITE
	parent.add_child(node)

func _line(parent: Control, spec: Dictionary, text: String) -> bool:
	var node := Text.new()
	if not node.configure(_atlas,_silver,text,Layout._rect(spec.rect),spec):
		node.free()
		return false
	var rgba: Dictionary=spec.color
	node.modulate=Color(rgba.r,rgba.g,rgba.b,rgba.a)
	parent.add_child(node)
	_lines.append(node)
	return true

func _sprite(parent: Control, box: Rect2, texture: Texture2D, spec: Dictionary, sliced: bool) -> Art:
	var node := Art.new()
	node.position=box.position
	node.size=box.size
	node.show_sprite(texture,spec,sliced)
	parent.add_child(node)
	return node

func fit_viewport(viewport: Vector2, screen_pixels := 1.0) -> void:
	if not viewport.is_finite() or viewport.x<=0.0 or viewport.y<=0.0: return
	_screen_scale=viewport.y/SIZE.y
	scale=Vector2.ONE*_screen_scale
	var width := viewport.x/_screen_scale
	_background.size=Vector2(width,SIZE.y)
	_centre.position.x=(width-SIZE.x)*.5
	_right.position.x=width-SIZE.x
	_pixel_scale=screen_pixels*_screen_scale
	for line in _lines: line.set_canvas_pixel_scale(_pixel_scale)
	for amount in _bag_quantities:
		if amount.visible: amount.set_canvas_pixel_scale(_pixel_scale)

func get_inventory_atlas() -> Texture2D: return _texture

func viewport_to_design(p: Vector2) -> Vector2: return p/_screen_scale
func selected_action() -> int: return _focus
func try_handle_back_request() -> bool: return false
func allows_stack_close() -> bool: return true
func cursor_rect() -> Rect2: return Rect2(_cursor.position+_centre.position,_cursor.size) if _cursor.visible else Rect2()
func action_rect(action: int) -> Rect2:
	var box: Rect2 = _targets.get(action,Rect2())
	return Rect2(box.position+_centre.position,box.size)
func reference_hit(p: Vector2) -> int:
	if not _active or not p.is_finite(): return 0
	for action in range(LAST,0,-1):
		if action_rect(action).has_point(p): return action
	return 0

func apply_stack_interactions(active: bool) -> void:
	_active=active
	visible=active
	_pressed=0
	_hover=0
	if active:
		if not _control_changed.is_connected(_on_control_changed):
			_control_changed.connect(_on_control_changed)
		_on_control_changed(null)
	else:
		if _control_changed.is_connected(_on_control_changed):
			_control_changed.disconnect(_on_control_changed)
		_select(0)

func _on_control_changed(_controlled: Node2D) -> void:
	if not _active or _initial_actor==null: return
	# InventoryMenuContext 重新解析，不直接使用通知的空值。
	# 该场景只支持唯一原主角，不能把其他角色的箱包/属性映射到他的装备。
	var actor: Node = _resolve_actor.call()
	if not is_instance_valid(actor) or actor!=_initial_actor.get_ref() or not _gear.belongs_to(actor): return
	var values: Array[int] = _resolve_values.call(actor)
	if values.size()!=_stat_values.size(): return
	for slot in range(_shown_equipment.size()):
		var item := _gear.equipped(slot)
		if item!=null and not _gear_icons.has(item): return
	model.refresh()
	_refresh_bag_graphics()
	_refresh_equipment()
	for i in range(values.size()):
		var spec: Dictionary=_layout.stat_rows[i].value
		var value := _stat_values[i]
		if not value.configure(_atlas,_silver,str(values[i]),Layout._rect(spec.rect),spec,_pixel_scale):
			push_error("未知的原装备摘要属性字形。")

func _refresh_equipment() -> bool:
	for slot in range(_shown_equipment.size()):
		var item := _gear.equipped(slot)
		if item!=null and not _gear_icons.has(item): return false
		var previous := _shown_equipment[slot]
		if previous!=null: _gear_icons[previous].hide()
		_shown_equipment[slot]=item
		_gear_placeholders[slot].visible=item==null
		if item!=null: _gear_icons[item].show()
		if _active and _focus==GEAR+slot:
			item_focus_changed.emit(_gear.slot_for_item(item))
	return true

func try_focus_default_target() -> bool:
	if not _active: return false
	model.set_category(0)
	_refresh_bag_graphics()
	_select(1)
	return true

func _select(action: int) -> void:
	if _focus==action:
		_sync()
		return
	if _focus>=GEAR and _focus<CATEGORY:
		item_focus_changed.emit(-1)
	_focus=action
	model.select(action-1 if action>0 and action<GEAR else -1)
	if action>=GEAR and action<CATEGORY and _active:
		item_focus_changed.emit(_gear.slot_for_item(_shown_equipment[action-GEAR]))
	elif action==0 or action>=CATEGORY:
		item_focus_changed.emit(-1)
	_sync()

func _sync() -> void:
	if _cursor==null: return
	if _active and _focus>0 and _focus<CATEGORY:
		var box: Rect2=_targets[_focus]
		var amount: Array=_layout.cursor.size_offset
		_cursor.position=box.position-Vector2(amount[0],amount[1])*.5
		_cursor.size=box.size+Vector2(amount[0],amount[1])
		_cursor.show()
	else: _cursor.hide()
	for i in range(4):
		var action := CATEGORY+i
		var sprite := "category_active" if i==model.category else "category_normal"
		if _pressed==action: sprite="m_PressedSprite"
		elif _focus==action: sprite="m_SelectedSprite"
		elif _hover==action: sprite="m_HighlightedSprite"
		_category_art[i].show_sprite(_texture,_layout.sprites[sprite],true)

func sample_point(hover: int, hit: int, point_active: bool) -> void:
	if not _active: return
	var entered := _hover!=hover
	_hover=hover
	# 原格子的 IPointerEnter 会选中按钮；分类没有此回调。
	# 原 InputSystem.Update 仍会按独立的 UI Point 射线选中分类 Button，
	# 只是不会替按钮执行 SelectCategory。遮挡后的空命中不改变焦点。
	if point_active and hit>=CATEGORY and _targets.has(hit):
		if _focus!=hit: _select(hit)
		elif entered: _sync()
	elif entered:
		if hover>0 and hover<CATEGORY: _select(hover)
		else: _sync()

func pointer_down(action: int) -> void:
	set_pressed(action)
	if _pressed>0: _select(_pressed)

func pointer_release(action: int) -> int:
	var original := _pressed
	set_pressed(0)
	return original if _active and original==action else 0

func set_pressed(action: int) -> void:
	_pressed=action if _active and _targets.has(action) else 0
	_sync()

## 只绑定显式拥有原物品使用生命周期的接收方。不用点击穿脱代替 Item.Use。
func bind_item_use(receiver: Callable) -> bool:
	if not _request_item_use.is_null() or not receiver.is_valid() or _active: return false
	_request_item_use=receiver
	return true


func activate(action: int) -> bool:
	if not _active or action<1 or action>LAST: return false
	if action<CATEGORY:
		if not _request_item_use.is_valid(): return false
		var request := model.activation(action-1) if action<GEAR else model.equipped_activation(
			_shown_equipment[action-GEAR])
		if request.is_empty() or not _item_icons.has(request.item) or not _gear.belongs_to(request.actor):
			return false
		# 成功只表示接收方承接了请求，不能当作使用完成或提前刷新。
		return _request_item_use.call(request)==true
	if not model.set_category(action-CATEGORY): return false
	_refresh_bag_graphics()
	_sync()
	return true

func move_selection(direction: Vector2i) -> bool:
	if not _active or not _targets.has(_focus) or absi(direction.x)+absi(direction.y)!=1: return false
	var v := Vector2(direction)
	var origin: Rect2=_targets[_focus]
	var start := origin.get_center()+origin.size*v*.5
	var best := 0
	var score := 0.0
	# Existing scoped candidates only. Exact tie order may differ from
	# Unity's activation registry; this is not global HUD/gamepad parity.
	for candidate: int in _targets:
		if candidate==_focus: continue
		var box: Rect2=_targets[candidate]
		var delta := box.get_center()-start
		var dot := delta.dot(v)
		if dot<=0.0: continue
		var next := dot/delta.length_squared()
		if next>score:
			best=candidate
			score=next
	if best==0: return false
	_select(best)
	return true
