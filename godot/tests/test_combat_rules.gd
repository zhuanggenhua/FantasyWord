extends SceneTree
const Rules = preload("res://game_core/combat/combat_rules.gd")
var checks := 0
var failures := 0
var draws := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("失败：", label)

func roll() -> int:
	draws += 1
	return 99

func actor(alignment: int) -> Dictionary:
	return {"alignment": alignment, "dead": false, "invincible": false, "snapshot": {"physical_attack": 3, "magical_attack": 7, "physical_defense": 100, "magical_defense": 0, "agility": 0, "luck": 0}}

func _initialize() -> void:
	for pair in [[0.5, 0], [1.5, 2], [2.5, 2], [3.5, 4], [-0.5, 0], [-1.5, -2], [-2.5, -2]]:
		check(Rules.calculate_damage_out(0, pair[0], 1) == pair[1], "中点取偶数")
	check(Rules.calculate_damage_out(5, 0.1, 16777217) == 1677727, "单精度整数转浮点")
	check(Rules.calculate_damage_in(101, 100) == 50, "减伤向下取整")
	check(Rules.calculate_damage_in(101, 0) == 101, "零防御")
	for sample in range(1, 100):
		check(Rules.evaluate_critical(50, sample) == (sample < 50), "暴击严格小于")
		check(Rules.evaluate_miss(0, 0, sample) == (sample > 90), "闪避严格大于")
	for a_alignment in range(3):
		for b_alignment in range(3):
			var a := actor(a_alignment)
			var b := actor(b_alignment)
			check(Rules.are_allies(a,b) == (a_alignment == b_alignment), "同阵营")
			check(Rules.are_enemies(a,b) == (a_alignment != b_alignment), "不同阵营")
			check(Rules.is_hostile_towards(a,b) == (a_alignment != b_alignment and a_alignment != 2 and b_alignment != 2), "中立不主动敌对")
	var a := actor(0)
	var b := actor(1)
	b.invincible = true
	check(not Rules.can_target(a,b), "无敌拒绝他人")
	check(Rules.can_target(b,b), "无敌自作用允许")
	check(not Rules.can_target(b.duplicate(true),b), "值相同不代表同一角色")
	b.dead = true
	check(not Rules.can_target(b,b), "死亡拒绝自身")
	check(Rules.can_target_output({"source":null},b), "未知来源重载保留原版直通")
	b = actor(1)
	var input := {"flat_damage": 10, "scale": 0.5, "damage_type": 1, "critical_behavior": 1, "miss_behavior": 1, "ignore_defense": false, "silent": true}
	var output: Dictionary = Rules.solve_damage_output(a,input,true,roll)
	check(output.damage == 24 and output.flags == 1 and draws == 0, "强制暴击不抽样")
	a.snapshot.agility = 999
	check(output.snapshot.agility == 0, "攻击来源保留当刻快照")
	var incoming: Dictionary = Rules.solve_damage_input(b,output,true,roll)
	check(incoming.damage == 0 and incoming.flags == 3 and draws == 0 and incoming.silent, "强制闪避保留暴击标记")
	check(Rules.solve_damage_input(b,output,false,roll).damage == 12 and draws == 0, "全局关闭优先于强制闪避")
	input.critical_behavior = 2
	check(Rules.solve_damage_output(a,input,true,roll).flags == 0 and draws == 0, "禁止暴击不抽样")
	input.critical_behavior = 0
	Rules.solve_damage_output(a,input,true,roll)
	check(draws == 1, "默认暴击抽一次")
	input.ignore_defense = true
	output = Rules.solve_damage_output(null,input,true,roll)
	check(output.damage == 10 and output.ignore_defense == false and output.miss_behavior == 0 and draws == 1, "未知来源分支默认字段")
	check(Rules.solve_damage_input(b,output,true,roll).damage == 10 and draws == 1, "未知来源不减伤不抽样")
	print("PASS 战斗纯规则：" if failures == 0 else "FAIL 战斗纯规则：", checks, " 项，失败 ", failures)
	quit(0 if failures == 0 else 1)
