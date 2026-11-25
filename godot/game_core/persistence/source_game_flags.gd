extends RefCounted
## 锁定 GameFlagSystem：集合成员即 true；不把 false 写成记录。
signal flag_changed(flag_name: Variant, value: bool)
var _true_flags := {}

func get_flag(flag_name: Variant) -> bool:
	return _valid_name(flag_name) and _true_flags.has(flag_name)

func set_flag(flag_name: Variant, value: bool) -> bool:
	if not _valid_name(flag_name): return false
	if value:
		_true_flags[flag_name]=true
	else:
		_true_flags.erase(flag_name)
	# Unity 每次 Set 都在修改完成后通知，哪怕值没有变化。
	flag_changed.emit(flag_name,value)
	return true

func create_data_block() -> Dictionary:
	return {"flags":_true_flags.keys()}

func load_data_block(block: Variant) -> bool:
	if not block is Dictionary or not block.get("flags") is Array: return false
	var restored := {}
	for flag_name: Variant in block.flags:
		if not _valid_name(flag_name): return false
		restored[flag_name]=true
	# 原 LoadDataBlock 替换集合，不重放每一项 Set 的事件。
	_true_flags=restored
	return true

static func _valid_name(flag_name: Variant) -> bool:
	# HashSet<string> 接受 null；空字符串和带空格/不同大小写的原键不归一化。
	return flag_name==null or flag_name is String
