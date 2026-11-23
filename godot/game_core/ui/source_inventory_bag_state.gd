extends RefCounted
## Bag-slot data projection from UIInventoryBag / UIInventoryBagSlot.
## Not an Item.Use implementation, full menu, details window, or UI prefab.
const Bags := preload("res://game_core/inventory/source_inventory_bags.gd")
enum Category { CONSUMABLE, RESOURCE, GEAR, KEY }
enum Location { BAG, EQUIPMENT }
const SLOT_COUNT := 30
signal details_opened(item: Resource)
signal details_closed
var category := Category.CONSUMABLE
var selected := -1
var overflow := false
var _rows: Array[Dictionary] = []
var _bags: Bags
var _owner := ""
var _category_of: Callable
var _actor: WeakRef

func show(bags: Bags, owner: String, actor: Node, category_of: Callable) -> bool:
	if _bags!=null or bags==null or not bags.is_character_owner(owner) \
			or not is_instance_valid(actor) or not category_of.is_valid(): return false
	_bags=bags
	_actor=weakref(actor)
	_owner=owner
	_category_of=category_of
	category=Category.CONSUMABLE
	refresh()
	select(0)
	return true

func set_category(value: int) -> bool:
	if _bags==null or value<Category.CONSUMABLE or value>Category.KEY: return false
	category=value
	refresh()
	return true

func refresh() -> void:
	if _bags==null: return
	_rows.clear()
	overflow=false
	# Selected Clear emits an empty details request before Fill emits the
	# selected entry's new details, just as UIInventoryBag.UpdateSlots.
	if selected>=0: details_opened.emit(null)
	for row in _bags.entries(_owner):
		if _category_of.call(row.item)!=category: continue
		if _rows.size()==SLOT_COUNT:
			overflow=true
			break
		_rows.append(row)
	if selected>=0 and selected<_rows.size(): details_opened.emit(_rows[selected].item)

func cell(index: int) -> Dictionary:
	return _rows[index].duplicate() if index>=0 and index<_rows.size() else {}

func select(index: int) -> bool:
	if _bags==null or index < -1 or index>=SLOT_COUNT: return false
	if selected==index: return true
	if selected>=0: details_closed.emit()
	selected=index
	if index>=0: details_opened.emit(cell(index).get("item"))
	return true

func activation(index: int) -> Dictionary:
	return _use_request(cell(index).get("item"),Location.BAG)


## 装备格同样交给原 Item.Use，但使用位置是 Equipment，不是背包或卸装事务。
func equipped_activation(item: Resource) -> Dictionary:
	return _use_request(item,Location.EQUIPMENT)


func _use_request(item: Resource, location: Location) -> Dictionary:
	var actor: Object=_actor.get_ref() if _actor!=null else null
	if item==null or not is_instance_valid(actor): return {}
	# 原 ResolveItemUseTarget 对当前两件装备返回开包主角。
	# 接收方仍负责 ManageInventory 门禁、原对话、异步结束和界面刷新。
	return {"item":item,"actor":actor,"target":actor,"location":location}
