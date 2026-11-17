extends SceneTree
const Hit = preload("res://gameplay/combat/charged_attack_hit.gd")
const Scene = preload("res://validation/scenes/charged_attack_fixture.tscn")
var checks := 0
var failures := 0
func _initialize(): call_deferred("_run")
func check(ok: bool, why: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(why)
func create():
	var fixture = Scene.instantiate()
	fixture.automatic_clock = false
	root.add_child(fixture)
	return fixture
func _run():
	var f = create()
	f.motion_enabled = false
	await process_frame
	f.defender.add_hitbox()
	await physics_frame
	await physics_frame
	var observed: Array = []
	var resolver := func(collider): return collider.get_meta("actor", null)
	var apply := func(caster, target, effect_id): observed.append([caster, target, effect_id])
	var hit := Hit.run(f.get_world_2d(), f.attacker, f.attacker.source_position(), f.attacker.facing, resolver, apply)
	check(hit.ok and observed == [[f.attacker, f.defender, 2004]], "实际施法者、唯一目标和2004交给效果owner")
	check(f.defender.health == 50 and f.defender.push_requests == 0, "查询器不代持属性或推力，效果由显式owner写入")
	observed.clear()
	hit = Hit.run(f.get_world_2d(), f.attacker, Vector2(10, 10), f.attacker.facing, resolver, apply)
	check(hit.ok and observed.is_empty(), "查询使用命中时传入位置，不偷读诊断演员或缓存位置")
	hit = Hit.run(f.get_world_2d(), f.attacker, f.attacker.source_position(), f.attacker.facing, resolver, Callable())
	check(not hit.ok and not hit.error.is_empty(), "没有实际效果owner明确拒绝，不返回假成功")
	check(f.begin_accepted_release(), "允许后的释放启动")
	check(not f.begin_accepted_release(), "活动释放不重复")
	f.timeline.advance(0.19)
	check(f.hit_count == 0 and f.defender.health == 50,"第12帧前不打击")
	f.timeline.advance(0.02)
	check(f.last_hit.ok and f.last_hit.application_count == 1 and f.last_hit.targets == [f.defender], "共享命中入口保留实际目标身份且只派发一次")
	check(f.defender.health == 29,"7+10*1.5=22，经防御2 floor 得21")
	check(f.defender.max_health == 50,"仅改当前生命")
	check(f.hit_count == 1 and f.defender.push_requests == 1,"多个子框去重一次")
	check(f.defender.callbacks == ["impact","provoke","prepare","complete"],"源冲击先于挑衅和扣血")
	check(f.defender.body.is_pushed(),"默认模式申请真实推力")
	check(f.attacker.health == 30 and f.outside.health == 40,"自我及范围外排除")
	var before = f.defender.body.global_position
	f.motion_enabled = true
	for i in range(5): await physics_frame
	check(f.defender.body.global_position.distance_to(before)>0.1,"真实物理身体产生位移")
	var area = f.defender.body.get_child(1)
	check(area.global_position.distance_to(f.defender.body.global_position)<0.0001,"命中框跟随原生身体")
	f.timeline.advance(0.5)
	check(not f.timeline.playing and f.hit_count == 1,"36帧结束且不重复命中")
	f.queue_free()
	await process_frame
	f = create()
	f.force_miss = true
	f.motion_enabled = false
	await process_frame
	await physics_frame
	await physics_frame
	f.begin_accepted_release()
	f.timeline.advance(0.21)
	check(f.defender.health == 50,"闪避不扣血")
	check(f.defender.callbacks == ["impact","provoke"],"闪避依然先冲击再挑衅")
	check(f.defender.push_requests == 1 and f.defender.body.is_pushed(),"原配置允许闪避推力")
	f.queue_free()
	await process_frame
	f = create()
	f.motion_enabled = false
	await process_frame
	await physics_frame
	await physics_frame
	f.begin_accepted_release()
	f.timeline.advance(0.1)
	f.attacker.facing = Vector2.LEFT
	f.timeline.advance(0.11)
	check(f.defender.health == 50,"命中时当前朝向影响Box，而非起手缓存")
	f.queue_free()
	await process_frame
	f = create()
	await process_frame
	await physics_frame
	await physics_frame
	f.begin_accepted_release()
	f.timeline.advance(0.1)
	f.timeline.stop()
	f.timeline.advance(1.0)
	check(f.hit_count == 0,"命中前中断不执行")
	f.queue_free()
	await process_frame
	if failures == 0: print("PASS 蓄力释放原生命中与推力：%d 项" % checks)
	quit(1 if failures else 0)
