extends RefCounted
## 原版 CombatSolver / DamageSolver 的纯计算切片，不拥有角色属性或伤害提交。
## 属性由调用方提供当刻快照；随机值提供器仅在原版真正抽样的分支调用。

enum DamageType { NONE, PHYSICAL, MAGICAL }
enum Resolution { DEFAULT, ALWAYS, NEVER }
enum Alignment { GOOD, EVIL, NEUTRAL }
const CRITICAL := 1
const MISS := 2

static func _f32(value: float) -> float:
	# Unity.Mathematics 的 float 运算不能直接替换成 GDScript 双精度运算。
	return PackedFloat32Array([value])[0]

static func _round_even(value: float) -> int:
	var lower := floori(value)
	var fraction := value - float(lower)
	if fraction < 0.5:
		return lower
	if fraction > 0.5:
		return lower + 1
	return lower if lower % 2 == 0 else lower + 1

static func calculate_damage_out(flat_damage: int, scale: float, stat: int) -> int:
	return flat_damage + _round_even(_f32(_f32(float(stat)) * _f32(scale)))

static func calculate_damage_in(damage: int, stat: int) -> int:
	return floori(_f32(_f32(float(damage)) * _f32(100.0 / _f32(100.0 + _f32(float(stat))))))

static func calculate_critical_damage(damage: int) -> int:
	return damage * 2

static func calculate_miss_damage(_damage: int) -> int:
	return 0

static func evaluate_critical(luck: int, roll: int) -> bool:
	assert(roll >= 1 and roll < 100, "暴击抽样必须来自原版 1 到 99 的整数范围")
	return roll < luck

static func evaluate_miss(attacker_agility: int, defender_agility: int, roll: int) -> bool:
	assert(roll >= 1 and roll < 100, "闪避抽样必须来自原版 1 到 99 的整数范围")
	var chance := clampi(floori(_f32(_f32(90.0 + _f32(float(attacker_agility))) * _f32(100.0 / _f32(100.0 + _f32(float(defender_agility)))))), 0, 100)
	return roll > chance

static func _stat(snapshot: Dictionary, damage_type: int, offense: bool) -> int:
	match damage_type:
		DamageType.PHYSICAL:
			return snapshot["physical_attack" if offense else "physical_defense"]
		DamageType.MAGICAL:
			return snapshot["magical_attack" if offense else "magical_defense"]
	return 0

static func _roll(provider: Callable) -> int:
	assert(provider.is_valid(), "随机解析缺少显式抽样入口，不能自动替换随机序列")
	return provider.call()

static func solve_damage_output(attacker: Variant, input: Dictionary, can_critical: bool, roll: Callable) -> Dictionary:
	if attacker == null:
		# 原版未知来源分支不复制 missBehavior 和 ignoreDefense；保留结构体默认值。
		return {"source": null, "snapshot": null, "damage": input.flat_damage, "type": input.damage_type, "flags": 0, "miss_behavior": Resolution.DEFAULT, "ignore_defense": false, "silent": input.silent}
	var snapshot: Dictionary = attacker.snapshot.duplicate(true)
	var damage := calculate_damage_out(input.flat_damage, input.scale, _stat(snapshot, input.damage_type, true))
	var critical: bool = can_critical and input.critical_behavior != Resolution.NEVER and (input.critical_behavior == Resolution.ALWAYS or evaluate_critical(snapshot.luck, _roll(roll)))
	return {"source": attacker, "snapshot": snapshot, "damage": calculate_critical_damage(damage) if critical else damage, "type": input.damage_type, "flags": CRITICAL if critical else 0, "miss_behavior": input.miss_behavior, "ignore_defense": input.ignore_defense, "silent": input.silent}

static func solve_damage_input(defender: Dictionary, output: Dictionary, can_miss: bool, roll: Callable) -> Dictionary:
	var damage: int = output.damage
	var flags: int = output.flags
	if output.snapshot != null:
		var attacker_stats: Dictionary = output.snapshot
		var defender_stats: Dictionary = defender.snapshot
		damage = calculate_damage_in(damage, 0 if output.ignore_defense else _stat(defender_stats, output.type, false))
		var missed: bool = can_miss and output.miss_behavior != Resolution.NEVER and (output.miss_behavior == Resolution.ALWAYS or evaluate_miss(attacker_stats.agility, defender_stats.agility, _roll(roll)))
		if missed:
			damage = calculate_miss_damage(damage)
			flags |= MISS
	return {"source": output.source, "damage": damage, "flags": flags, "silent": output.silent}

static func can_target(attacker: Variant, defender: Dictionary) -> bool:
	return (not defender.invincible or is_same(attacker, defender)) and (attacker == null or not attacker.dead) and not defender.dead

static func can_target_output(output: Dictionary, defender: Dictionary) -> bool:
	# 原版该重载在来源角色解析失败时直接返回 true，而非复用目标死亡检查。
	return true if output.source == null else can_target(output.source, defender)

static func are_allies(a: Dictionary, b: Dictionary) -> bool:
	return a.alignment == b.alignment

static func are_enemies(a: Dictionary, b: Dictionary) -> bool:
	return a.alignment != b.alignment

static func is_hostile_towards(a: Dictionary, b: Dictionary) -> bool:
	return are_enemies(a, b) and a.alignment != Alignment.NEUTRAL and b.alignment != Alignment.NEUTRAL

static func is_judicious_target(a: Dictionary, b: Dictionary) -> bool:
	return can_target(a, b) and are_enemies(a, b)
