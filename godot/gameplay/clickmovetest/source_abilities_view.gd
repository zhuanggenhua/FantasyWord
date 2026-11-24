extends Control
## ClickMoveTest 的原 Pause → Abilities；同一角色服务同时供键盘与快捷栏读取。
signal category_changed(category: int)
const Player := preload("res://gameplay/clickmovetest/single_player_actor.gd")
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
const Text := preload("res://gameplay/clickmovetest/source_character_text.gd")
const Description := preload("res://gameplay/clickmovetest/source_ability_description_text.gd")
const Draw := preload("res://gameplay/clickmovetest/source_inventory_sprite.gd")
const Tiled := preload("res://gameplay/clickmovetest/source_menu_tiled_image.gd")
const Rects := preload("res://gameplay/clickmovetest/source_character_selectables.gd")
const CONTRACT_SHA := "cf9df62db3bf77ca0a8285f1af6cc24af48558f02827c85dbc798ac72558c3ed"
const SIZE := Vector2(1920,1080)
const ROW_ACTION := 11
const SLOT_ACTION := 21
# ItemNavigationCursorStyle in Unity 31629d53: GUI sprite 1581307299, white,
# zero position offset and +16 on both size axes. Selection Indicator is a
# Simple Image (not sliced) and does not receive pointer hits.
const SLOT_CURSOR_SPRITE := {
	"rect":{"x":128,"y":48,"width":16,"height":16},
	"border":{"x":3,"y":3,"z":3,"w":3},
}
const SLOT_CURSOR_PADDING := Vector2(16,16)
const ACTIVE_CATEGORY := 1
const PASSIVE_CATEGORY := 2
const CategorySubmit := preload("res://gameplay/clickmovetest/source_category_submit_feedback.gd")

var _owner: Player
var _spec: Dictionary
var _atlas := Atlas.new()
var _silver: FontFile
var _background: Tiled
var _center: Control
var _right: Control
var _list: Control
var _texture: Texture2D
var _attack: Texture2D
var _solid: Texture2D
var _description: Description
var _category_art: Array[Draw] = []
var _row_icons: Array[Draw] = []
var _row_labels: Array[Text] = []
var _bar_icons: Array[Draw] = []
var _slot_cursor: Draw
var _equip_art: Array[Draw] = []
var _labels: Array[Text] = []
var _rows: Array[int] = []
var _shortcuts := []
var _row_fades := {}
var _row_colors := {}
var _targets := {}
var _size_scale := 1.0
var _active := false
var _point_active := false
var category := ACTIVE_CATEGORY
var equip_from := 0
var _pressed := 0
var _category_submit := CategorySubmit.new()
var _hover := 0
var _focus := 0

func _init() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_IGNORE

static func load_layout(directory: String) -> Dictionary:
	var path := directory.path_join("abilities-layout.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=CONTRACT_SHA: return {}
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

## 两个正式入口共用同一原图切片；不回退到占位图标。
static func load_attack_icon(contract: Dictionary, dir: String) -> Texture2D:
	var attack_spec: Dictionary=contract.abilities["20001"].icon
	var attack_path:=dir.path_join(attack_spec.file)
	if not FileAccess.file_exists(attack_path) or FileAccess.get_sha256(attack_path)!=attack_spec.sha256:
		return null
	var attack_sheet:=Image.load_from_file(attack_path)
	if attack_sheet==null or attack_sheet.get_size()!=Vector2i(128,128): return null
	var clip:=Rect2i(Rects._rect(attack_spec.sheet_rect))
	return ImageTexture.create_from_image(attack_sheet.get_region(clip))

static func create_null_sprite() -> Texture2D:
	var white:=Image.create_empty(1,1,false,Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	return ImageTexture.create_from_image(white)

func bind(contract: Dictionary, pause: Dictionary, dir: String, silver_path: String, owner: Player, initial_category: int = ACTIVE_CATEGORY) -> bool:
	if _owner!=null or owner==null or contract.get("source_commit")!=Atlas.SOURCE \
			or contract.get("registration")!=2 or contract.get("pause_action")!=4 \
			or owner.active_ability_menu_codes()!=[20001,20010] or owner.equipped_ability_menu_slots().size()!=5:
		return false
	_silver=Text.load_silver(silver_path)
	if _silver==null or not _atlas.bind(pause,dir.path_join("pause-font-atlas.bin")): return false
	_attack=load_attack_icon(contract,dir)
	if _attack==null: return false
	_solid=create_null_sprite()

	if initial_category not in [ACTIVE_CATEGORY,PASSIVE_CATEGORY]: return false
	category=initial_category
	_spec=contract
	var layout: Dictionary=contract.layout
	var tile: Dictionary=layout.tile.sprite
	var data:=pause.duplicate()
	data.tiled_images={"Abilities Background":{"sprite_id":tile.id,"fill_center":true,"ppu_multiplier":1,
		"color":{"r":1,"g":1,"b":1,"a":1}}}
	data.sprites={tile.id:tile}
	_background=Tiled.new()
	add_child(_background)
	if not _background.bind(data,dir.path_join("SPS_GUI.png"),"Abilities Background"): return false
	_background.size=SIZE
	_texture=_background.get_atlas_texture()
	_center=_group(self)
	_right=_group(self)
	for node: Dictionary in layout.backings: _source_art(_center,node)
	for spec: Dictionary in layout.labels:
		var parent:=_center if spec.anchor=="center" else (_right if spec.anchor=="right" else self)
		if _add_text(parent,spec,spec.text,Rects._rect(spec.rect))==null: return false

	var viewport:=Rects._rect(layout.viewport)
	_list=_group(_center)
	_list.position=viewport.position
	_list.size=viewport.size
	_list.clip_contents=true
	for index in range(2):
		var spec: Dictionary=layout.categories[index]
		var bounds:=Rects._rect(spec.rect)
		_targets[index+1]=bounds
		_category_art.append(_picture(_center,bounds,_texture,layout.category_sprites.unselected,1))
		_picture(_center,Rects._rect(spec.icon),_solid,{},0)
		var label_spec: Dictionary=spec.label.duplicate()
		label_spec.overflow_width=true
		var count:=owner.active_ability_menu_codes().size() if index==0 else 0
		if _add_text(_center,label_spec,"%s (%d)"%[spec.term,count],Rects._rect(spec.label.rect))==null: return false

	var codes:=owner.active_ability_menu_codes()
	for index in range(codes.size()):
		var code:=codes[index]
		var row: Dictionary=layout.rows[index]
		var hit:=Rects._rect(row.rect)
		_targets[ROW_ACTION+index]=hit
		var icon:=Rects._rect(row.icon)
		icon.position-=viewport.position
		_row_icons.append(_picture(_list,icon,_icon_for(code),{},0))
		var text_box:=Rects._rect(row.label.rect)
		text_box.position-=viewport.position
		var label:=_add_text(_list,row.label,_definition(code).name,text_box)
		if label==null: return false
		_row_labels.append(label)

	for index in range(5):
		var row: Dictionary=layout.bar[index]
		_source_art(_center,row.background)
		_source_art(_center,row.frame)
		_targets[SLOT_ACTION+index]=Rects._rect(row.rect)
		_bar_icons.append(_picture(_center,Rects._rect(row.icon),_solid,{},0))

	for row: Dictionary in layout.equip_images:
		var decoration:=_source_art(_center,row)
		decoration.hide()
		_equip_art.append(decoration)

	_description=Description.new()
	if not _description.bind(_atlas,_silver,contract.silver_metrics,Rects._rect(layout.description.rect),layout.description):
		_description.free()
		_description=null
		return false
	_center.add_child(_description)
	_slot_cursor=_picture(_center,Rect2(),_texture,SLOT_CURSOR_SPRITE,0)
	_slot_cursor.hide()
	# Verify every reachable character row/font before installing focus/input.
	for def: Dictionary in contract.abilities.values():
		if not _description.show_ability(def): return false
	for spec: Dictionary in layout.categories:
		if not _description.show_message(spec.description): return false
	if not _description.show_message(""): return false

	_owner=owner
	_rows=codes
	_shortcuts=owner.equipped_ability_menu_slots()
	_owner.equipped_abilities_changed.connect(_on_slots_changed)
	_sync()
	return true

func _group(parent: Control) -> Control:
	var node:=Control.new()
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _definition(code: int) -> Dictionary:
	return _spec.abilities.get(str(code),{})

func _icon_for(code: int) -> Texture2D:
	# A present ability with a null source sprite still has Image.enabled.
	return _attack if code==20001 else _solid

func _rgba(c: Dictionary) -> Color:
	return Color(c.r,c.g,c.b,c.a)

func _picture(parent: Control, bounds: Rect2, texture: Texture2D, spec: Dictionary, type: int) -> Draw:
	var node:=Draw.new()
	node.position=bounds.position
	node.size=bounds.size
	node.show_sprite(texture,spec,type==1,type==2)
	parent.add_child(node)
	return node

func _source_art(parent: Control,row: Dictionary) -> Draw:
	var node:=_picture(parent,Rects._rect(row.rect),_texture,row.sprite,int(row.type))
	node.modulate=_rgba(row.color)
	if row.flip:
		node.pivot_offset=node.size*.5
		node.scale=Vector2(-1,1)
	return node

func _add_text(parent: Control, spec: Dictionary, value: String, box: Rect2) -> Text:
	var node:=Text.new()
	if not node.configure(_atlas,_silver,value,box,spec):
		node.free()
		return null
	node.modulate=_rgba(spec.color)
	parent.add_child(node)
	_labels.append(node)
	return node

func fit_viewport(viewport: Vector2, screen_pixels := 1.0) -> void:
	if not viewport.is_finite() or viewport.x<=0.0 or viewport.y<=0.0: return
	_size_scale=viewport.y/SIZE.y
	var width:=viewport.x/_size_scale
	scale=Vector2.ONE*_size_scale
	_background.size=Vector2(width,SIZE.y)
	_center.position.x=(width-SIZE.x)*.5
	_right.position.x=width-SIZE.x
	for label in _labels: label.set_canvas_pixel_scale(screen_pixels*_size_scale)
	_description.set_canvas_pixel_scale(screen_pixels*_size_scale)

func viewport_to_design(p: Vector2) -> Vector2: return p/_size_scale
func selected_action() -> int: return _focus
func slot_cursor_rect() -> Rect2:
	return _slot_cursor.get_rect() if _slot_cursor!=null and _slot_cursor.visible else Rect2()
func allows_stack_close() -> bool: return true
func try_handle_back_request() -> bool:
	if not _active or equip_from==0: return false
	_exit_equip()
	return true

func apply_stack_interactions(active: bool) -> void:
	_active=active
	visible=active
	_pressed=0
	_hover=0
	if not active:
		_category_submit.clear()
		equip_from=0
		_focus=0
	_sync()

func try_focus_default_target() -> bool:
	if not _active: return false
	# The hot UIKit cache retains category. With no active rows the base
	# fallback is the first existing Selectable (original Active Category).
	_select(ROW_ACTION if category==ACTIVE_CATEGORY and not _rows.is_empty() else ACTIVE_CATEGORY)
	return true

func action_rect(action: int) -> Rect2:
	var bounds: Rect2=_targets.get(action,Rect2())
	return Rect2(bounds.position+_center.position,bounds.size)

func _row_action(action: int) -> bool:
	return action>=ROW_ACTION and action<ROW_ACTION+_rows.size()

func _slot_action(action: int) -> bool:
	return action>=SLOT_ACTION and action<SLOT_ACTION+_shortcuts.size()

func _allows(action: int) -> bool:
	return action==ACTIVE_CATEGORY or action==PASSIVE_CATEGORY or _slot_action(action) \
		or (_row_action(action) and equip_from==0 and category==ACTIVE_CATEGORY)

func reference_hit(p: Vector2) -> int:
	if not _active or not p.is_finite(): return 0
	for action in _targets.keys():
		if _allows(action) and action_rect(action).has_point(p): return action
	return 0

func sample_point(hover: int, hit: int, active: bool) -> void:
	_point_active=active
	if not _active: return
	var entered := hover!=_hover
	_category_submit.interrupt_pointer(_hover,hover)
	_hover=hover
	# 分类没有 PointerEnter 回调；主动 UI Point 的射线命中会触发
	# UIAbilityCategory.OnSelect 显示说明，不会替它执行 SelectCategory。
	if active and hit in [ACTIVE_CATEGORY, PASSIVE_CATEGORY]:
		if _focus!=hit: _select(hit)
		elif entered: _sync()
	elif entered:
		if _row_action(hover) or _slot_action(hover): _select(hover)
		else: _sync()

func pointer_down(action: int) -> void:
	set_pressed(action)
	if _pressed>0: _select(_pressed)

func pointer_release(action: int) -> int:
	var prior:=_pressed
	set_pressed(0)
	return prior if _active and prior==action else 0

func set_pressed(action: int) -> void:
	_pressed=action if _active and _allows(action) else 0
	if _pressed!=0 and _pressed==_category_submit.pressed: _category_submit.clear()
	_sync()

func _select(action: int) -> void:
	if _focus==action or not _allows(action): return
	_category_submit.clear()
	_focus=action
	if _row_action(action):
		_description.show_ability(_definition(_rows[action-ROW_ACTION]))
	elif _slot_action(action):
		_description.show_ability(_definition(int(_shortcuts[action-SLOT_ACTION].formal_gas_ability_code)))
	else:
		_description.show_message(_spec.layout.categories[action-1].description)
	_sync()

func activate(action: int, from_submit := false) -> bool:
	if not _active or not _allows(action): return false
	if action==ACTIVE_CATEGORY or action==PASSIVE_CATEGORY:
		category=action
		category_changed.emit(category)
		# uGUI Button.OnSubmit presses after onClick, and only if still enabled.
		# Rows disable on assignment and slots have no Button transition.
		if from_submit and _active and is_inside_tree(): _category_submit.start(action,get_tree(),_sync)
		_sync()
		return true
	if _row_action(action):
		equip_from=action
		if not _point_active: _select(SLOT_ACTION)
		_sync()
		return true
	var index:=action-SLOT_ACTION
	if equip_from==0:
		_owner.clear_equipped_ability_slot(index)
	else:
		_owner.try_equip_formal_ability_to_slot(_rows[equip_from-ROW_ACTION],index)
		_exit_equip()
	return true

func _exit_equip() -> void:
	var prior:=equip_from
	equip_from=0
	if not _point_active: _select(prior)
	_sync()

func _on_slots_changed(rows: Array) -> void:
	_shortcuts=rows
	_sync()

func _sync() -> void:
	if _center==null: return
	var layout: Dictionary=_spec.layout
	for i in range(_category_art.size()):
		var action:=i+1
		var sprite: String="selected" if action==category else "unselected"
		if _pressed==action or _category_submit.pressed==action: sprite="m_PressedSprite"
		elif _focus==action: sprite="m_SelectedSprite"
		elif _hover==action: sprite="m_HighlightedSprite"
		_category_art[i].show_sprite(_texture,layout.category_sprites[sprite],true)
	for i in range(_row_labels.size()):
		var show_row:=category==ACTIVE_CATEGORY
		_row_labels[i].visible=show_row
		_row_icons[i].visible=show_row
		var action:=ROW_ACTION+i
		var state: String="m_NormalColor"
		if equip_from!=0: state="m_DisabledColor"
		elif _pressed==action: state="m_PressedColor"
		elif _focus==action: state="m_SelectedColor"
		elif _hover==action: state="m_HighlightedColor"
		_set_row_tint(i,state)
	for i in range(_bar_icons.size()):
		var code: int=int(_shortcuts[i].formal_gas_ability_code) if i<_shortcuts.size() else 0
		_bar_icons[i].visible=code>0
		if code>0: _bar_icons[i].show_sprite(_icon_for(code),{},false)
	for view in _equip_art: view.visible=equip_from!=0
	# UINavigationCursor reads the selected button, not its icon or which
	# device selected it. List rows and categories have no cursor target.
	if _slot_cursor!=null:
		_slot_cursor.visible=_active and _slot_action(_focus)
		if _slot_cursor.visible:
			var box: Rect2=_targets[_focus]
			_slot_cursor.position=box.position-SLOT_CURSOR_PADDING*.5
			_slot_cursor.size=box.size+SLOT_CURSOR_PADDING

func _set_row_tint(index: int,state: String) -> void:
	if _row_colors.get(index)==state: return
	var label:=_row_labels[index]
	var previous: Tween=_row_fades.get(index)
	if previous!=null and previous.is_valid(): previous.kill()
	var dest:=_rgba(_spec.layout.rows[index].label.color)*_rgba(_spec.layout.list_colors[state])
	if not is_inside_tree():
		label.modulate=dest
	else:
		var t:=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
		t.tween_property(label,"modulate",dest,float(_spec.layout.list_colors.m_FadeDuration))
		_row_fades[index]=t
	_row_colors[index]=state

func move_selection(direction: Vector2i) -> bool:
	if not _active or absi(direction.x)+absi(direction.y)!=1: return false
	if not _allows(_focus): return try_focus_default_target()
	var step:=Vector2(direction)
	var origin: Rect2=_targets[_focus]
	var point:=origin.get_center()+origin.size*step*.5
	var best:=0
	var score:=0.0
	for action: int in _targets:
		if action==_focus or not _allows(action): continue
		var rect: Rect2=_targets[action]
		var d:=rect.get_center()-point
		var dot:=d.dot(step)
		if dot<=0.0: continue
		var weight:=dot/d.length_squared()
		if weight>score: best=action; score=weight
	if best==0: return false
	_select(best)
	return true
