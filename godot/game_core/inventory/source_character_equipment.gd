extends RefCounted
## 锁定 ClickMoveTest 的 CharacterEquipment：初始长矛、基础布衣皆不提供属性或附加能力。
## 正式入口仍只初始化这两件。独立坐骑验收可显式注册战马，不写玩法库存。
signal loadout_changed

enum Slot { WEAPON, HEAD, TORSO, HANDS, FEET, MOUNT }
enum Result { VALID, NOT_ENOUGH_HEALTH, NOT_ENOUGH_MANA, INVALID_TARGET, MISSING_ITEM, ACTION_LOCKED, INVALID_OWNER }

const SPEAR := "e75ab3eda87066246bf3a27034a417bd"
const CLOTH := "34d275c797e85434d84f523ede167208"
const WAR_HORSE := "a9a7433e642af8744b2e309dc15ce611"
const _PINNED_SLOTS := {CLOTH:Slot.TORSO,SPEAR:Slot.WEAPON,WAR_HORSE:Slot.MOUNT}

var _items := {}
var _slots := {}
var _actor: WeakRef
var _read_health: Callable
var _can_change: Callable

func start(actor: Node, read_health: Callable, can_change: Callable, mount_validation := false) -> bool:
	if _actor!=null or not is_instance_valid(actor) or not actor.is_inside_tree() \
			or not read_health.is_valid() or not can_change.is_valid(): return false
	_actor=weakref(actor)
	_read_health=read_health
	_can_change=can_change
	for guid: String in ([WAR_HORSE] if mount_validation else [CLOTH, SPEAR]):
		var item := Resource.new()
		_items[guid]=item
		if not mount_validation: _slots[_PINNED_SLOTS[guid]]=item
	return true

func live() -> bool:
	var actor: Node=_actor.get_ref() if _actor!=null else null
	return is_instance_valid(actor) and actor.is_inside_tree() and _read_health.is_valid() and _can_change.is_valid()

func can_change() -> bool:
	return live() and bool(_can_change.call())

func item_for_guid(guid: String) -> Resource:
	return _items.get(guid)

func slot_for_item(item: Resource) -> int:
	if item==null: return -1
	for guid: String in _items:
		if _items[guid]==item: return _PINNED_SLOTS[guid]
	return -1

func equipped(slot: int) -> Resource:
	return _slots.get(slot)

## 保持原 CharacterEquipment 的资源优先级；仅此切片差量为 0、当前法力固定非负。
func try_apply(slot: int, item: Resource) -> Dictionary:
	if not live() or slot<Slot.WEAPON or slot>Slot.MOUNT \
			or (item!=null and slot_for_item(item)!=slot):
		return {"result":Result.INVALID_TARGET}
	if not can_change(): return {"result":Result.ACTION_LOCKED}
	if int(_read_health.call())<1: return {"result":Result.NOT_ENOUGH_HEALTH}
	var previous := equipped(slot)
	if item==null:
		_slots.erase(slot)
	else:
		_slots[slot]=item
	# 已锁定的正式装备资源没有属性/技能差量；槽位事件仍然先于 InventorySystem 转包。
	loadout_changed.emit()
	return {"result":Result.VALID,"previous":previous}
