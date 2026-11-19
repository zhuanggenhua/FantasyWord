extends SceneTree
const Effect = preload("res://gameplay/combat/basic_damage_effect.gd")
var hp := 220
var trace: Array = []
var count := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failed += 1
		printerr("FAIL: ",label)

func run() -> void:
	var source := {"dead":false,"invincible":false,"snapshot":{"physical_attack":10,"magical_attack":0,
		"physical_defense":0,"magical_defense":0,"luck":0,"agility":0}}
	var target := {"dead":false,"invincible":false,"snapshot":{"physical_attack":0,"magical_attack":0,
		"physical_defense":0,"magical_defense":0,"luck":0,"agility":0}}
	var hooks := {"has_formal_stats":func(): return true,
		"current_health":func(): return hp,
		"provoke":func(_s): trace.append("provoke"),
		"impact":func(_i,_v): trace.append("undesired_push"),
		"prepare":func(_s,input): trace.append(input.damage),
		"apply_current_health_delta":func(delta,_min,_max,_s):
			hp = maxi(0,hp+delta)
			return hp,
		"complete":func(_s,_i,previous,applied): trace.append([previous,applied])}
	var roll := func(): return 50
	Effect.execute_damage_phase(source,target,hooks,func(): return {
		"source_root":Vector2.ZERO,"target_root":Vector2.RIGHT,"target_direction":Vector2.LEFT
	},true,true,roll)
	check(hp==206 and trace==["provoke",14,[220,14]],"正面扣十四且无推力")
	hp=220
	trace.clear()
	Effect.execute_damage_phase(source,target,hooks,func(): return {
		"source_root":Vector2.ZERO,"target_root":Vector2.RIGHT,
		"target_direction":Vector2.RIGHT if hp==206 else Vector2.LEFT
	},true,true,roll)
	check(hp==203 and trace==["provoke",14,[220,14],"provoke",3,[206,3]],
		"背刺阶段读取基础提交后的状态，并单独结算原三点伤害")
	hp=1
	trace.clear()
	var draws: Array[int]=[]
	Effect.execute_damage_phase(source,target,hooks,func(): return {
		"source_root":Vector2.ZERO,"target_root":Vector2.RIGHT,"target_direction":Vector2.RIGHT
	},true,true,func():
		draws.append(50)
		return 50,
		func():
			var live := target.duplicate()
			live.dead = hp==0
			return [source,live])
	check(hp==0 and trace==["provoke",14,[1,1]] and draws.size()==3,
		"首段致死后背刺输出仍判暴击，但新鲜死亡门禁拦截闪避抽样和二次反馈")
	check(not Effect.is_backstab(Vector2.ZERO,Vector2.ZERO,Vector2.RIGHT),"重合根不构成背刺")
	check(Effect.is_backstab(Vector2.ZERO,Vector2.RIGHT,Vector2.ZERO),"零方向按源码使用右方")
	check(not Effect.is_backstab(Vector2.ZERO,Vector2.RIGHT,Vector2.UP),"垂直于攻击方向不是背刺")
	check(Effect.is_backstab(Vector2(-.351,.936),Vector2.ZERO,Vector2.RIGHT)
		and not Effect.is_backstab(Vector2(-.349,.937),Vector2.ZERO,Vector2.RIGHT),"原点积阈值两侧")
	if failed == 0: print("PASS 普通攻击正式伤害：%d 项" % count)
	quit(0 if failed==0 else 1)
