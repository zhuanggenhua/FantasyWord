extends RefCounted
## InventorySystem owner-keyed item rows. Item resources are canonical database
## instances, not display names, and the per-category UI cap is not a bag cap.
const Equipment := preload("res://game_core/inventory/source_character_equipment.gd")
signal item_added(owner: String, item: Resource, quantity: int, transfer: int)
signal item_removed(owner: String, item: Resource, quantity: int, transfer: int)
enum Transfer { EQUIPMENT, CRAFTING, TRADING, USE, CHEST, CHARACTER_DROP, COMMAND, UNKNOWN, CORPSE }
const PARTY_OWNER := "Party:default"
const CHARACTER_PREFIX := "Character:"
var _bags: Dictionary = {}

func party_owner() -> String: return PARTY_OWNER

func character_owner(persistent_identifier: String) -> String:
	var normalized := persistent_identifier.strip_edges()
	return "" if normalized.is_empty() else CHARACTER_PREFIX+normalized

func is_character_owner(owner: String) -> bool:
	return owner.begins_with(CHARACTER_PREFIX) and owner.length()>CHARACTER_PREFIX.length()

func _valid(owner: String) -> bool:
	return owner==PARTY_OWNER or is_character_owner(owner)

func _bag(owner: String) -> Dictionary:
	if not _bags.has(owner): _bags[owner]={"indices":{},"rows":[],"free":[]}
	return _bags[owner]

func entries(owner: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not _valid(owner): return result
	for row in _bag(owner).rows:
		if row!=null: result.append(row.duplicate())
	return result

func count(owner: String, item: Resource) -> int:
	if not _valid(owner) or item==null: return 0
	var bag := _bag(owner)
	var index: int=bag.indices.get(item,-1)
	return int(bag.rows[index].quantity) if index>=0 else 0

func add(owner: String, item: Resource, quantity: int = 1, transfer: int = Transfer.UNKNOWN) -> bool:
	if not _valid(owner) or item==null or quantity<=0: return false
	var bag := _bag(owner)
	var index: int=bag.indices.get(item,-1)
	if index>=0:
		bag.rows[index].quantity+=quantity
	else:
		var row := {"item":item,"quantity":quantity}
		# Dictionary entry slots are traversed in index order. Removing a
		# row frees its slot for the next insertion, rather than moving it
		# to the end of the display order.
		if bag.free.is_empty():
			index=bag.rows.size()
			bag.rows.append(row)
		else:
			index=bag.free.pop_back()
			bag.rows[index]=row
		bag.indices[item]=index
	item_added.emit(owner,item,quantity,transfer)
	return true

func remove(owner: String, item: Resource, quantity: int = 1, transfer: int = Transfer.UNKNOWN) -> bool:
	if not _valid(owner) or item==null or quantity<=0: return false
	var bag := _bag(owner)
	var index: int=bag.indices.get(item,-1)
	if index<0: return false
	var current: int=bag.rows[index].quantity
	var removed := mini(current,quantity)
	if removed==current:
		bag.indices.erase(item)
		bag.rows[index]=null
		bag.free.append(index)
	else:
		bag.rows[index].quantity-=removed
	item_removed.emit(owner,item,removed,transfer)
	return true

## InventorySystem 先提交角色槽位，再按原顺序写所属背包。
## 原无效 owner 异常在 Godot API 显式返回，不允许先变更槽位。
func try_equip(source_owner: String, target: Equipment, item: Resource) -> int:
	if target==null or not target.live(): return Equipment.Result.INVALID_TARGET
	if not target.can_change(): return Equipment.Result.ACTION_LOCKED
	if not _valid(source_owner): return Equipment.Result.INVALID_OWNER
	if count(source_owner,item)<1: return Equipment.Result.MISSING_ITEM
	var change := target.try_apply(target.slot_for_item(item),item)
	if change.result==Equipment.Result.VALID:
		remove(source_owner,item,1,Transfer.EQUIPMENT)
		if change.previous!=null: add(source_owner,change.previous,1,Transfer.EQUIPMENT)
	return change.result

func try_unequip(destination_owner: String, target: Equipment, slot: int) -> int:
	if not _valid(destination_owner): return Equipment.Result.INVALID_OWNER
	if target==null or not target.live(): return Equipment.Result.INVALID_TARGET
	if not target.can_change(): return Equipment.Result.ACTION_LOCKED
	var change := target.try_apply(slot,null)
	if change.result==Equipment.Result.VALID and change.previous!=null:
		add(destination_owner,change.previous,1,Transfer.EQUIPMENT)
	return change.result
