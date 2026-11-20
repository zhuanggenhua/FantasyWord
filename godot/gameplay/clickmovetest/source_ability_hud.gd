extends CanvasLayer
## 原 Screen Space UI → HUD → Ability Bar。只读同一角色槽，不触发技能。
const Player := preload("res://gameplay/clickmovetest/single_player_actor.gd")
const Abilities := preload("res://gameplay/clickmovetest/source_abilities_view.gd")
const Message := preload("res://gameplay/clickmovetest/source_ability_hud_message.gd")
const Draw := preload("res://gameplay/clickmovetest/source_inventory_sprite.gd")
const Tile := preload("res://gameplay/clickmovetest/source_menu_tiled_image.gd")
const SIDE := 96.0
const GAP := 16.0
const ENTRY_IDS := [3500559439943725516,2482055604812022459,306918243132352108,
	5916395185588694261,4957606854609737821]

var message: Message
var _owner: Player
var _actor: Node2D
var _entries: Array[Control]=[]
var _icons: Array[Draw]=[]
var _bar: Control
var _attack: Texture2D
var _solid: Texture2D

func bind(owner: Player, dir: String, silver_path: String) -> bool:
	if _owner!=null or owner==null: return false
	var spec:=Abilities.load_layout(dir)
	if spec.is_empty(): return false
	var atlas_path:=dir.path_join("SPS_GUI.png")
	if not FileAccess.file_exists(atlas_path) or FileAccess.get_sha256(atlas_path)!=Tile.ATLAS_HASH:
		return false
	var image:=Image.load_from_file(atlas_path)
	_attack=Abilities.load_attack_icon(spec,dir)
	if image==null or _attack==null: return false
	var atlas:=ImageTexture.create_from_image(image)
	_solid=Abilities.create_null_sprite()
	_owner=owner
	# 与同一 Screen Space Canvas 的浮层排序一致，HUD 在闪屏、控制面板与菜单下。
	layer=3
	_bar=Control.new()
	_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	message=Message.new()
	_bar.add_child(message)
	if not message.bind(dir,silver_path): return false
	# 条目和菜单槽继承同一 Generic/Ability；只复用已校验的公共图块，不取菜单布局。
	var slot: Dictionary=spec.layout.bar[0]
	for i in ENTRY_IDS.size():
		var entry:=Control.new()
		entry.name="技能槽 %d"%(i+1)
		entry.set_meta("source_rect_id",ENTRY_IDS[i])
		entry.mouse_filter=Control.MOUSE_FILTER_STOP
		entry.size=Vector2(SIDE,SIDE)
		_bar.add_child(entry)
		_entries.append(entry)
		_picture(entry,Rect2(Vector2.ZERO,entry.size),atlas,slot.background.sprite,2)
		_picture(entry,Rect2(Vector2.ZERO,entry.size),atlas,slot.frame.sprite,1)
		_icons.append(_picture(entry,Rect2(24,24,48,48),_solid,{},0))
		entry.hide()
	return true

func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_owner.controlled_character_changed.connect(_bind_actor)
	# 原 OnEnable 首次读取控制角色或主角；之后回调按真实角色（可为 null）。
	_bind_actor(_owner.get_current_controlled_character_or_player_instance())

func _exit_tree() -> void:
	if _owner==null: return
	if _owner.controlled_character_changed.is_connected(_bind_actor):
		_owner.controlled_character_changed.disconnect(_bind_actor)
	_bind_actor(null)

func _bind_actor(actor: Node2D) -> void:
	if actor==_actor: return
	if _owner.equipped_abilities_changed.is_connected(_refresh):
		_owner.equipped_abilities_changed.disconnect(_refresh)
	if is_instance_valid(_actor) and _actor.tree_exiting.is_connected(_on_actor_exiting):
		_actor.tree_exiting.disconnect(_on_actor_exiting)
	_actor=actor
	if is_instance_valid(actor):
		actor.tree_exiting.connect(_on_actor_exiting)
		_owner.equipped_abilities_changed.connect(_refresh)
		_refresh(_owner.equipped_ability_menu_slots())
	else:
		_refresh([])

func _on_actor_exiting() -> void:
	_bind_actor(null)

func _refresh(slots: Array) -> void:
	for i in _entries.size():
		var has_source: bool=i<slots.size() and slots[i].has_display_source
		_entries[i].visible=has_source
		if has_source:
			var code: int=slots[i].formal_gas_ability_code
			# 本切片仅有两个原技能。喷火的 Sprite 为空，但 Image 仍启用。
			_icons[i].show_sprite(_attack if code==20001 else _solid,{},false)
	_layout()

func _layout() -> void:
	var viewport_size:=get_viewport().get_visible_rect().size
	if viewport_size.y<=0.0: return
	var unit:=viewport_size.y/1080.0
	_bar.scale=Vector2.ONE*unit
	var canvas_pixels:=get_viewport().get_final_transform().get_scale().y*unit
	message.fit(viewport_size.x/unit,canvas_pixels)
	var count:=0
	for entry in _entries:
		if entry.visible: count+=1
	var span:=SIDE*count+GAP*maxi(0,count-1)
	var x:=(viewport_size.x/unit-span)*.5
	# 原底部 y25、容器高度100，标准中对齐的子项高度96。
	for entry in _entries:
		if entry.visible:
			entry.position=Vector2(x,1080.0-25.0-100.0+2.0)
			x+=SIDE+GAP

func blocks_map_pointer(screen_point: Vector2) -> bool:
	# 原 GraphicRaycaster 命中可见提示和已占槽，不命中空槽或整个栏容器。
	if message.is_visible_in_tree() and message.get_rect().has_point(screen_point/_bar.scale): return true
	for entry in _entries:
		if entry.is_visible_in_tree() and entry.get_rect().has_point(screen_point/_bar.scale):
			return true
	return false

func _picture(parent: Control, box: Rect2, texture: Texture2D, sprite: Dictionary, type: int) -> Draw:
	var art:=Draw.new()
	art.position=box.position
	art.size=box.size
	art.show_sprite(texture,sprite,type==1,type==2)
	parent.add_child(art)
	return art
