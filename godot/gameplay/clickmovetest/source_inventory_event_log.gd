extends CanvasLayer
## ClickMoveTest 原 Overlay/Event Log 的队伍金钱与已锁定物品分支。
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
const Text := preload("res://gameplay/clickmovetest/source_character_text.gd")
const Bags := preload("res://game_core/inventory/source_inventory_bags.gd")
const Gear := preload("res://game_core/inventory/source_character_equipment.gd")
const Money := preload("res://game_core/inventory/source_party_money.gd")
const LIMIT := 5
const TYPING_SECONDS := 0.025
const DISPLAY_SECONDS := 3.0
const POINTS := 64.0
const LEFT_TOP := Vector2(30,160.87)
# 原 RPGSystem 单行 (67.5 + 16.875) × 64/90；TMP preferred 向上到百分位。
const LINE_HEIGHT := 60.01
const BASELINE := LINE_HEIGHT*.5 + (67.5-16.875)*.5*POINTS/90.0
const GOLD := Color(1,0.84313726,0,1)
const SHORT_TERM := "[INVALID_SHORTNAME]"
# Overlay prefab m_itemTransferTypesToLog: serialized int32 5, 6, 4.
const ITEM_TRANSFERS := [Bags.Transfer.CHARACTER_DROP, Bags.Transfer.COMMAND, Bags.Transfer.CHEST]
const ITEM_TYPES := {Gear.Slot.WEAPON: Gear.SPEAR, Gear.Slot.TORSO: Gear.CLOTH}
const ITEM_TEXT_STYLE := {"size":64,"horizontal":1,"vertical":512,"overflow":0,"style":0,"overflow_width":true}

var _owner: Money
var _bags: Bags
var _silver: FontFile
var _items := {}
var _pixel_scale := 1.0
var _atlas: Atlas
var _container: Control
var _rows: Array[Dictionary] = []
var _order: Array[int] = []
var _clock: Callable

func bind(owner: Money, source: Dictionary, alpha8_path: String) -> bool:
	if _owner!=null or owner==null: return false
	_atlas=Atlas.new()
	if not _atlas.bind(source,alpha8_path): return false
	for character in "+-0123456789 "+SHORT_TERM:
		if _atlas.layout_glyph(character.unicode_at(0),POINTS,Vector2.ZERO,false).is_empty():
			return false
	_owner=owner
	layer=7 # 原 Canvas Overlay 在 Menus 之后；Event Log 为最后的覆盖层同级项。
	name="原事件日志"
	process_mode=Node.PROCESS_MODE_ALWAYS
	_clock=func(): return Time.get_ticks_usec()/1_000_000.0
	_container=Control.new()
	_container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_container.position=LEFT_TOP
	add_child(_container)
	for i in LIMIT:
		var art:=Control.new()
		art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		art.self_modulate=GOLD
		art.hide()
		_container.add_child(art)
		art.draw.connect(_draw_row.bind(i))
		_rows.append({"art":art,"item_text":null,"item":false,"height":LINE_HEIGHT,
			"full":"","shown":"","due":0.0,"count":0,"last_wait":false})
	return true

## Only canonical items in this scene; no substitute name or font on unresolved input.
func bind_items(bags: Bags, gear: Gear, source: Dictionary, silver_path: String) -> bool:
	if _owner==null or _bags!=null or bags==null or gear==null or source.get("source_commit")!=Atlas.SOURCE:
		return false
	var rows: Variant=source.get("items")
	var silver := Text.load_silver(silver_path)
	if silver==null or not rows is Array or rows.size()!=ITEM_TYPES.size(): return false
	var names := {}
	for row: Variant in rows:
		if not row is Dictionary or not row.get("type") is float or not row.get("name") is String: return false
		var id: String = ITEM_TYPES.get(int(row.type),"")
		var item := gear.item_for_guid(id)
		var title: String = row.name
		if item==null or names.has(item) or title.is_empty() or title.contains("\n"): return false
		# ContentSizeFitter measures a single complete authored name and the
		# static plus/minus/digit prefix before any actual row can use it.
		var layout := Text.layout(_atlas,"+1 "+title,Rect2(0,0,1860,540),ITEM_TEXT_STYLE)
		if layout.is_empty(): return false
		for glyph: Dictionary in layout.glyphs:
			if glyph.silver and not silver.has_char(glyph.code): return false
		names[item]=title
	if names.size()!=ITEM_TYPES.size(): return false
	_bags=bags
	_silver=silver
	_items=names
	for row in _rows:
		var text := Text.new()
		text.hide()
		row.art.add_child(text)
		row.item_text=text
	if is_inside_tree(): _sync_subscription()
	return true

func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	visibility_changed.connect(_sync_subscription)
	_fit()
	_sync_subscription()

func _exit_tree() -> void: _disconnect_events()

func _sync_subscription() -> void:
	if visible:
		if not _owner.amount_changed.is_connected(_receive_amount):
			_owner.amount_changed.connect(_receive_amount)
		if _bags!=null and not _bags.item_added.is_connected(_receive_added):
			_bags.item_added.connect(_receive_added)
			_bags.item_removed.connect(_receive_removed)
	else:
		_disconnect_events()
		for i in _order.duplicate(): _hide_row(i)

func _disconnect_events() -> void:
	if _owner!=null and _owner.amount_changed.is_connected(_receive_amount):
		_owner.amount_changed.disconnect(_receive_amount)
	if _bags!=null and _bags.item_added.is_connected(_receive_added):
		_bags.item_added.disconnect(_receive_added)
		_bags.item_removed.disconnect(_receive_removed)

func _fit() -> void:
	var viewport:=get_viewport()
	var unit:=viewport.get_visible_rect().size.y/1080.0
	if unit<=0: return
	_container.position=LEFT_TOP*unit
	_container.scale=Vector2.ONE*unit
	_pixel_scale=viewport.get_final_transform().get_scale().y*unit
	var face:=_atlas.face_material(false,POINTS/90.0*_pixel_scale)
	for row in _rows:
		row.art.material=face
		if row.item: row.item_text.set_canvas_pixel_scale(_pixel_scale)

func _receive_amount(added: bool, amount: int) -> void:
	_show_line("%s%d %s"%["+" if added else "-",amount,SHORT_TERM],false)

func _receive_added(owner: String, item: Resource, quantity: int, transfer: int) -> void:
	_receive_item(true,owner,item,quantity,transfer)

func _receive_removed(owner: String, item: Resource, quantity: int, transfer: int) -> void:
	_receive_item(false,owner,item,quantity,transfer)

func _receive_item(added: bool, owner: String, item: Resource, quantity: int, transfer: int) -> void:
	if (owner==Bags.PARTY_OWNER or _bags.is_character_owner(owner)) and transfer in ITEM_TRANSFERS \
			and _items.has(item):
		_show_line("%s%d %s"%["+" if added else "-",quantity,_items[item]],true)

func _show_line(text: String, item: bool) -> void:
	# Unity FindAvailableLine 按池数组取首个隐藏槽；全占时固定取数组第 0 项，
	# 不取视觉顺序最早的条目。重新展示后把它挂到兄弟节点末尾。
	var i:=0
	for candidate in LIMIT:
		if not _order.has(candidate):
			i=candidate
			break
	_order.erase(i)
	_order.append(i)
	var row:=_rows[i]
	row.full=text
	row.item=item
	row.height=LINE_HEIGHT
	row.art.self_modulate=Color.WHITE if item else GOLD
	if row.item_text!=null: row.item_text.visible=item
	row.shown=""
	row.count=0
	row.last_wait=false
	row.art.show()
	_container.move_child(row.art,-1)
	_place_rows()
	_advance_row(i,_clock.call())

func _process(_delta: float) -> void: _tick(_clock.call())

func _tick(now: float) -> void:
	for i in _order.duplicate():
		if now<_rows[i].due: continue
		if _rows[i].last_wait: _hide_row(i)
		else: _advance_row(i,now)

func _advance_row(i: int, now: float) -> void:
	var row:=_rows[i]
	while row.shown.length()<row.full.length():
		var character: String=row.full[row.shown.length()]
		row.shown+=character
		if character!=" ":
			row.count+=1
			row.due=now+TYPING_SECONDS
			_update_row_art(i)
			return
	_update_row_art(i)
	row.last_wait=true
	row.due=now+maxf(0.0,DISPLAY_SECONDS-row.count*TYPING_SECONDS)

func _hide_row(i: int) -> void:
	var row:=_rows[i]
	row.art.hide()
	if row.item_text!=null: row.item_text.hide()
	row.item=false
	row.shown=""
	row.full=""
	_order.erase(i)
	_place_rows()

func _place_rows() -> void:
	var top := 0.0
	for i in _order:
		_rows[i].art.position=Vector2(0,top)
		top+=_rows[i].height

func _update_row_art(i: int) -> void:
	var row := _rows[i]
	if row.item:
		# The size fitter follows preferred ascent/descent of visible text;
		# introducing a Silver glyph can change row height during typing.
		var sample := Text.layout(_atlas,row.shown,Rect2(0,0,1860,540),ITEM_TEXT_STYLE)
		if sample.is_empty(): return
		var ascent := 0.0
		var descent := 0.0
		for glyph: Dictionary in sample.glyphs:
			ascent=maxf(ascent,glyph.face.x)
			descent=minf(descent,glyph.face.y)
		var height := (floorf((ascent-descent)*100.0)+1.0)/100.0
		if row.item_text.configure(_atlas,_silver,row.shown,Rect2(0,0,1860,height),ITEM_TEXT_STYLE,_pixel_scale):
			row.height=height
			_place_rows()
	row.art.queue_redraw()

func _draw_row(i: int) -> void:
	var row:=_rows[i]
	if row.item: return
	var x:=0.0
	for step in row.shown.length():
		var glyph:=_atlas.layout_glyph(row.shown.unicode_at(step),POINTS,Vector2(x,BASELINE),false)
		if glyph.destination.has_area():
			row.art.draw_texture_rect_region(_atlas.texture,glyph.destination,glyph.region,Color.WHITE,false,false)
		x+=glyph.advance
