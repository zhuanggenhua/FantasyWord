extends SceneTree
const Pipeline = preload("res://gameplay/combat/charged_effect_application.gd")
var n := 0
var errors := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	n += 1
	if not ok:
		errors += 1
		printerr(label)
func run() -> void:
	var pipe := Pipeline.new()
	var caster := Node2D.new()
	var victim := Node2D.new()
	var second := Node2D.new()
	root.add_child(caster)
	root.add_child(victim)
	root.add_child(second)
	var seen: Array = []
	var nested := func(a,b): seen.append(["inner",a,b])
	var damage := func(a,b):
		seen.append(["damage",a,b,b.position])
		if b==victim:
			pipe.request(caster,second,nested)
			check(pipe.run_effects(Callable())==0,"不能嵌套重复消耗")
	var cue := func(b,id): seen.append(["cue",b,id])
	check(not pipe.request(caster,caster,damage) and not pipe.request(caster,victim,Callable()),"拒绝自身或无作用执行入口")
	check(pipe.request(caster,victim,damage) and pipe.request(caster,second,damage),"只在能力阶段投递实际身份")
	check(seen.is_empty(),"投递未提前发 cue 或扣血")
	victim.position = Vector2(4,5)
	check(pipe.run_effects(cue)==2,"同次效果更新顺序消费两次")
	check(seen==[["cue",victim,1],["damage",caster,victim,Vector2(4,5)],
		["cue",second,2],["damage",caster,second,Vector2.ZERO]],"先 Cue 请求，后伤害读取作用时的真实位置")
	check(pipe.run_effects(cue)==1 and seen.slice(-2)==[["cue",second,3],["inner",caster,second]],"重入投递保留到下次更新")
	check(pipe.run_effects(cue)==0 and seen.size()==6,"瞬时请求不重复播放或伤害")
	check(pipe.request(caster,victim,damage),"有效请求可独立跟踪")
	victim.free()
	check(pipe.run_effects(cue)==0 and seen.size()==6,"消失的目标不改投其他节点")
	check(pipe.request(caster,second,damage),"可在宿主退出前收到请求")
	pipe.clear()
	check(pipe.run_effects(cue)==0 and seen.size()==6,"宿主销毁清空待应用请求")
	caster.free()
	second.free()
	if errors==0: print("PASS 蓄力瞬时效果阶段：%d 项" % n)
	quit(0 if errors==0 else 1)
