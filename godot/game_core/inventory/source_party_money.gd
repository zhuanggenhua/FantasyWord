extends RefCounted
## DefaultParty money field from InventorySystem. Fresh session starts with a
## new InventoryRuntime; item collections and serialization are not here.
signal changed(value: int)
var _money := 0

func money() -> int: return _money

func add(value: int) -> void:
	if value<=0: return
	_money+=value
	changed.emit(_money)

func remove(value: int) -> void:
	if value<=0: return
	_money=maxi(0,_money-value)
	changed.emit(_money)
