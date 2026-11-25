extends RefCounted
## DefaultParty money field from InventorySystem. Fresh session starts with a
## new InventoryRuntime; item collections and serialization are not here.
signal changed(value: int)
## 原金钱事件保留请求额；余额变化事件仍是独立接口。
signal amount_changed(added: bool, amount: int)
var _money := 0

func money() -> int: return _money

func add(value: int) -> void:
	if value<=0: return
	_money+=value
	amount_changed.emit(true,value)
	changed.emit(_money)

func remove(value: int) -> void:
	if value<=0: return
	_money=maxi(0,_money-value)
	amount_changed.emit(false,value)
	changed.emit(_money)
