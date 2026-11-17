extends SceneTree
## 用显式测试属性拥有者验证生产伤害阶段；不是正式 GAS/场景验收。
const Effect = preload("res://gameplay/combat/charged_damage_effect.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
var checks := 0
var errors := 0
var health := 220
var order: Array = []
var observed_source: Variant
var impact := Vector2.ZERO
var rolls := 0
var permit_stats := true
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		errors += 1
		printerr("FAIL: ", label)
func role(attack: int, defense: int) -> Dictionary:
	return {"snapshot":{"physical_attack":attack,"physical_defense":defense,
		"magical_attack":0,"magical_defense":0,"agility":0,"luck":0},
		"dead":false,"invincible":false}
func hooks() -> Dictionary:
	return {"impact":func(_input, vector): order.append("impact"); impact=vector,
		"provoke":func(source): order.append("provoke"); observed_source=source,
		"has_formal_stats":func():return permit_stats,
		"current_health":func():return health,
		"prepare":func(_source,_input):order.append("prepare"),
		"apply_current_health_delta":func(delta,minimum,_maximum,_source):
			order.append("apply"); health=maxi(minimum,health+delta); return health,
		"complete":func(_source,_input,_before,_applied):order.append("complete")}
func roll() -> int:
	rolls += 1
	return 50
func _init() -> void:
	var caster := role(10,0)
	var target := role(0,0)
	check(Effect.execute_damage_phase(caster,target,hooks(),Vector2(2,3),Vector2(4,6),true,true,roll),"生产伤害阶段成功")
	check(health==198,"220减去7+10*1.5，不改最大生命")
	check(is_same(observed_source,caster),"来源仍为显式角色身份，不生成副本")
	check(impact==Vector2(2,3),"执行帧根坐标之差，不归一化两次")
	check(order==["impact","provoke","prepare","apply","complete"],"源执行器回调顺序")
	check(rolls==2,"暴击与闪避各按源分支抽样")
	order.clear()
	permit_stats=false
	check(not Effect.execute_damage_phase(caster,target,hooks(),Vector2.ZERO,Vector2.ONE,false,false,Callable()),"无属性提交能力拒绝扣血")
	check(health==198 and order==["impact","provoke"],"缺属性时先有冲击与挑衅，不伪造属性存储")
	permit_stats=true
	order.clear()
	target.dead=true
	check(not Effect.execute_damage_phase(caster,target,hooks(),Vector2.ZERO,Vector2.ONE,false,false,Callable()) and order.is_empty(),"已死亡目标无后续副作用")
	target.dead=false
	order.clear()
	check(not Effect.execute_damage_phase(caster,target,hooks(),Vector2.ZERO,Vector2.ONE,false,true,func():return 99),"真实闪避返回false")
	check(health==198 and order==["impact","provoke"],"闪避有源冲击路径但不扣血")
	order.clear()
	check(Effect.execute_damage_phase(null,target,hooks(),Vector2(99,99),Vector2(4,6),true,true,Callable()),"无来源不抽样仍执行作者固定值")
	check(health==191 and impact==Vector2(4,6) and observed_source==null,"无来源使用作者零位置与固定7")
	print("PASS charged damage phase: %d/%d" % [checks-errors,checks])
	quit(0 if errors==0 else 1)
