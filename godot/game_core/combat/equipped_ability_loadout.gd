extends RefCounted
## 对应锁定 CharacterEquippedAbilityLoadout；只管理代码占位，不授予技能或解析 GAS。
var _slots: Array[int] = []

func _init(slot_count: int) -> void:
	assert(slot_count >= 0)
	_slots.resize(slot_count)
	_slots.fill(0)

func get_slot_count() -> int: return _slots.size()
func get_formal_gas_ability_code(index: int) -> int:
	return _slots[index] if index >= 0 and index < _slots.size() else 0

func create_slot_data_snapshot() -> Array:
	var rows: Array = []
	for i in _slots.size():
		rows.append({"slotIndex":i,"formalGasAbilityCode":_slots[i]})
	return rows

func create_slot_view_snapshot() -> Array:
	var rows: Array = []
	for i in _slots.size():
		rows.append({"slot_index":i,"formal_gas_ability_code":_slots[i],
			"has_formal_gas_ability":_slots[i]>0,"has_display_source":_slots[i]>0})
	return rows

func contains_formal_gas_ability_code(code: int) -> bool:
	return code > 0 and _slots.has(code)

func clear_slot(index: int) -> bool:
	if index < 0 or index >= _slots.size() or _slots[index] <= 0: return false
	_slots[index] = 0
	return true

func remove_formal_gas_ability_code_from_all_slots(code: int) -> bool:
	if code <= 0: return false
	var changed := false
	for i in _slots.size():
		if _slots[i] == code: _slots[i] = 0; changed = true
	return changed

func try_auto_assign_formal_gas_ability_code(code: int) -> bool:
	if code <= 0 or contains_formal_gas_ability_code(code): return false
	for i in _slots.size():
		if _slots[i] <= 0: _slots[i] = code; return true
	return false

func try_assign_formal_gas_ability_code_to_slot(index: int, code: int) -> bool:
	if index < 0 or index >= _slots.size() or code <= 0 or _slots[index] == code: return false
	for i in _slots.size():
		if i != index and _slots[i] == code:
			_slots[i] = 0
			break
	_slots[index] = code
	return true

## 宿主交付已解码的原 CharacterAbilitySlotData；非法字典不是有效原槽位。
## 先完整验证形状，避免未知字段被强制转成索引 0；形状失败不改已有状态。
func restore_from_slot_data(rows: Variant) -> bool:
	if rows != null and not rows is Array: return false
	if rows != null:
		for row in rows:
			if row == null: continue
			if not row is Dictionary or not row.get("slotIndex") is int or not row.get("formalGasAbilityCode") is int: return false
	var snapshot: Array = [] if rows == null else rows.duplicate(true)
	_slots.fill(0)
	for row in snapshot:
		if row == null: continue
		var index: int = row.slotIndex
		if index >= 0 and index < _slots.size() and row.formalGasAbilityCode > 0:
			_slots[index] = row.formalGasAbilityCode
	return true
