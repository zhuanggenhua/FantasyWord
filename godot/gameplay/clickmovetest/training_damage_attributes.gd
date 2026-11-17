extends RefCounted
## ClickMoveTest 角色表在无活动属性修饰的受击切片中的单一属性真相。
## 对应 FormalAttributeCatalog.CreateAttributeSetConfig 与
## FormalGameplayEffectResourceModifier.TryApplyCurrentStatDelta 的生命下降分支。
## 不创建 ASC/Effect 实体，不支持 Buff 聚合、装备加成、同步或存档。
signal current_health_changed(previous: int, current: int, source: Variant)
const Combat = preload("res://game_core/combat/combat_rules.gd")
const SNAPSHOT_KEYS := ["physical_attack", "magical_attack", "physical_defense",
		"magical_defense", "agility", "luck"]

var _sheet := PackedInt32Array()
var _alignment := -1
var _health_base := 0
var _health_current := 0
var _lifecycle: Callable
var _invincibility: Callable

func configure(sheet: PackedInt32Array, alignment: int, is_dead: Callable, is_invincible: Callable) -> bool:
	if has_formal_stats() or sheet.size() != 9 or sheet[0] <= 0 \
			or alignment not in [Combat.Alignment.GOOD, Combat.Alignment.EVIL] \
			or not is_dead.is_valid() or not is_invincible.is_valid(): return false
	_sheet = sheet.duplicate()
	_alignment = alignment
	_lifecycle = is_dead
	_invincibility = is_invincible
	# 初始 CurrentHealth、该资源的 BaseValue 和 MaxHealth 属性同取表初值。
	_health_base = _sheet[0]
	_health_current = _health_base
	return true

func has_formal_stats() -> bool:
	return not _sheet.is_empty() and _lifecycle.is_valid() and _invincibility.is_valid()

func stats() -> Dictionary:
	if not has_formal_stats(): return {}
	var read := {}
	for i in SNAPSHOT_KEYS.size():
		read[SNAPSHOT_KEYS[i]] = _sheet[i+2]
	return {"snapshot":read, "alignment":_alignment, "dead":_lifecycle.call(), "invincible":_invincibility.call()}

func current_health() -> int:
	return _health_current

func max_health() -> int:
	return 0 if _sheet.is_empty() else _sheet[0]

func apply_current_health_delta(delta: int, minimum: Variant, maximum: Variant, source: Variant) -> Variant:
	# 正式执行器的伤害调用：只允许负增量、下限0、没有额外上限。
	# 未迁移治疗/耗蓝/活动修饰，以拒绝而不是第二套公式处理。
	if not has_formal_stats() or delta > 0 or minimum != 0 or maximum != null: return null
	var previous := _health_current
	var applied_modifier := maxi(0, previous + delta) - previous
	if applied_modifier != 0:
		_health_base += applied_modifier
		# 无活动修饰时，原属性重算是新的 BaseValue；上限是另一独立属性。
		_health_current = _health_base
		current_health_changed.emit(previous,_health_current,source)
	return _health_current
