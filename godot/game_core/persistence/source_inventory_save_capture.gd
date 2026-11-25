extends RefCounted
## InventorySystem.CreateOwnerDataBlocks 的逻辑形状；不是 Unity JsonUtility 字节格式。
const Bags := preload("res://game_core/inventory/source_inventory_bags.gd")
const Money := preload("res://game_core/inventory/source_party_money.gd")
const PARTY := 0
const CHARACTER := 1
const CORPSE := 4
const INT32_MAX := 2147483647

static func capture(bags: Bags, party_money: Money, registered_items: Dictionary) -> Dictionary:
	if bags==null or party_money==null: return _fail("inventory_owner_unavailable")
	var by_item: Variant = _reverse_registry(registered_items)
	if by_item==null: return _fail("ambiguous_database_registry")
	var materials := bags.save_bag_rows()
	var current_money: Variant = party_money.save_money_if_materialized()
	if current_money!=null and not materials.has(Bags.PARTY_OWNER): materials[Bags.PARTY_OWNER]=[]
	if current_money!=null and (current_money<0 or current_money>INT32_MAX): return _fail("invalid_money")
	var snapshot: Array[Dictionary] = []
	for owner: String in materials:
		var identity := _identity(owner)
		if identity.is_empty(): return _fail("unsupported_inventory_owner",owner)
		var items: Array[Dictionary] = []
		for row: Dictionary in materials[owner]:
			var item: Variant = row.get("item")
			var quantity: Variant = row.get("quantity")
			if not item is Resource or not quantity is int or quantity<=0 or quantity>INT32_MAX:
				return _fail("invalid_item_or_quantity",owner)
			if not by_item.has(item):
				# 0068 forbids a silently incomplete new save. The pinned C#
				# instead logs/skips here; no output is safer than partial data.
				return _fail("unregistered_item",owner)
			items.append({"guid":by_item[item],"quantity":quantity})
		snapshot.append({"ownerKind":identity.kind,"ownerId":identity.id,
			"money":int(current_money) if owner==Bags.PARTY_OWNER and current_money!=null else 0,"items":items})
	return {"ok":true,"block":{"inventories":snapshot}}

# Only our validated logical model is admitted here. Legacy Unity file
# tolerance and serializer field names are handled outside this adapter.
static func restore(block: Variant, bags: Bags, party_money: Money, registered_items: Dictionary) -> Dictionary:
	if bags==null or party_money==null: return _fail("inventory_owner_unavailable")
	if not block is Dictionary or not block.get("inventories") is Array: return _fail("invalid_inventory_block")
	if _reverse_registry(registered_items)==null: return _fail("ambiguous_database_registry")
	var staged := {}
	var restored_money: Variant = null
	for entry: Variant in block.inventories:
		if not entry is Dictionary or not entry.get("ownerKind") is int or not entry.get("ownerId") is String:
			return _fail("invalid_inventory_owner")
		var owner := _owner(entry.ownerKind,entry.ownerId)
		if owner.is_empty() or staged.has(owner): return _fail("ambiguous_or_unsupported_owner",owner)
		var amount: Variant = entry.get("money")
		if not amount is int or amount<0 or amount>INT32_MAX or (owner!=Bags.PARTY_OWNER and amount!=0):
			return _fail("unsupported_money",owner)
		if owner==Bags.PARTY_OWNER: restored_money=amount
		if not entry.get("items") is Array: return _fail("invalid_items",owner)
		var rows: Array[Dictionary] = []
		var seen := {}
		for item_row: Variant in entry.items:
			if not item_row is Dictionary or not _guid(item_row.get("guid")): return _fail("invalid_guid",owner)
			var guid: String = item_row.guid
			if not registered_items.has(guid) or seen.has(guid): return _fail("unresolved_or_duplicate_guid",owner)
			var quantity: Variant = item_row.get("quantity")
			if not quantity is int or quantity<=0 or quantity>INT32_MAX: return _fail("invalid_item_quantity",owner)
			seen[guid]=true
			rows.append({"item":registered_items[guid],"quantity":quantity})
		staged[owner]=rows
	bags._replace_saved_rows(staged)
	party_money._restore_saved_money(restored_money)
	return {"ok":true}

static func _reverse_registry(registered_items: Dictionary) -> Variant:
	var identities := {}
	for guid: Variant in registered_items:
		var item: Variant = registered_items[guid]
		if not _guid(guid) or not item is Resource or identities.has(item): return null
		identities[item]=guid
	return identities

static func _owner(kind: int, id: String) -> String:
	if id.is_empty() or id!=id.strip_edges(): return ""
	match kind:
		PARTY: return Bags.PARTY_OWNER if id=="default" else ""
		CHARACTER: return Bags.CHARACTER_PREFIX+id
		CORPSE: return Bags.CORPSE_PREFIX+id
	return ""

static func _identity(owner: String) -> Dictionary:
	if owner==Bags.PARTY_OWNER: return {"kind":PARTY,"id":"default"}
	for row: Array in [[Bags.CHARACTER_PREFIX,CHARACTER],[Bags.CORPSE_PREFIX,CORPSE]]:
		if not owner.begins_with(row[0]): continue
		var id := owner.substr(row[0].length())
		if not id.is_empty() and id==id.strip_edges(): return {"kind":row[1],"id":id}
	return {}

static func _guid(value: Variant) -> bool:
	if not value is String or value.length()!=32: return false
	for i in range(value.length()):
		if "0123456789abcdef".find(value[i])<0: return false
	return true

static func _fail(reason: String, owner := "") -> Dictionary:
	return {"ok":false,"reason":reason,"owner":owner}
