extends RefCounted
## 锁定原图的 JournalSystem：正式 F5 尚无作者任务，只支持空状态。
## 四组存档数组属于本系统；可接取任务由原条件派生，不是存档字段。
const SAVED_FIELDS := ["unlockedQuests","activeQuests","fullfilledQuests","completedQuests"]
var _data := _fresh_data()

static func _fresh_data() -> Dictionary:
	var rows := {}
	for field: String in SAVED_FIELDS:
		rows[field] = []
	return rows

func create_data_block() -> Dictionary:
	return _data.duplicate(true)

func load_data_block(block: Variant) -> bool:
	if block!=null and not block is Dictionary: return false
	if block is Dictionary:
		# 尚未迁移任务引用和进度恢复，不能接受后静默丢失真实条目。
		for field: Variant in block:
			if field not in SAVED_FIELDS: return false
			var list: Variant = block[field]
			if list!=null and (not list is Array or not list.is_empty()): return false
	# 验证整个输入后才替换；原系统对空块及缺字段都恢复为空。
	_data = _fresh_data()
	return true

func visible_quest_count() -> int:
	# 原 UIJournal 先读取已达成、再读取进行中，不显示已解锁或已完成。
	return _data.fullfilledQuests.size() + _data.activeQuests.size()
