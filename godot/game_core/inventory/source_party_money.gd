extends RefCounted
## DefaultParty money field from InventorySystem. Fresh session starts with a
## new InventoryRuntime; item collections and serialization are not here.
signal changed(value: int)
## 原金钱事件保留请求额；余额变化事件仍是独立接口。
signal amount_changed(added: bool, amount: int)
var _money := 0
var _materialized := false

func money() -> int:
	_materialized=true # Unity GetMoney lazily creates the default inventory.
	return _money

func save_money_if_materialized() -> Variant:
	return _money if _materialized else null

# Restore assigns source fields; no transactional or balance-change signal.
func _restore_saved_money(value: Variant) -> void:
	_materialized=value!=null
	_money=int(value) if _materialized else 0

func add(value: int) -> void:
	if value<=0: return
	_materialized=true
	_money+=value
	amount_changed.emit(true,value)
	changed.emit(_money)

func remove(value: int) -> void:
	if value<=0: return
	_materialized=true
	_money=maxi(0,_money-value)
	amount_changed.emit(false,value)
	changed.emit(_money)
