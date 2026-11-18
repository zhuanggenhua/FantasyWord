extends SceneTree
const System = preload("res://game_core/elements/terrain_surface_damage_system.gd")
class Target extends RefCounted:
	var dead := false
	var position := Vector2(.5,.5)
class Map extends RefCounted:
	var cells: Dictionary = {}
	func sample(cell: Vector3i) -> Dictionary: return cells.get(cell,{})
var checks := 0
var failures := 0
var submitted: Array = []
var player: Object
var active_map: Object
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr(label)
func _initialize(): call_deferred("run")
func run():
	var terrain:=Map.new()
	active_map=terrain
	var actor:=Target.new()
	var other:=Target.new()
	player=actor
	terrain.cells[Vector3i.ZERO]={"flags":2,"states":{2:{"source_entity":weakref(actor)}}}
	var runtime:=System.new()
	check(runtime.configure(func():return active_map,func():return player,
		func(t):return {"dead":t.dead,"position":t.position} if t is Target else {},
		func(source,target,data):submitted.append([source,target,data]);return true,
		func(s):return s if s is Target else null),"显式宿主可装配")
	runtime.register_target(actor);runtime.register_target(actor)
	check(runtime.advance(.49)==0 and submitted.is_empty(),"半秒前不投递")
	check(runtime.advance(.011)==1 and submitted.size()==1,"玩家与注册目标按身份去重")
	check(submitted[0][0]==actor and submitted[0][1]==actor,"原来源与目标可以同一角色")
	var payload: Dictionary=submitted[0][2]
	check(payload.descriptor.damage_type==2 and payload.descriptor.flat_damage==1
		and payload.descriptor.scale==0 and payload.descriptor.critical_behavior==2
		and payload.descriptor.miss_behavior==2 and payload.descriptor.ignore_defense
		and not payload.descriptor.silent and payload.visual_flags==0
		and payload.impact_velocity==Vector2.ZERO,"作者伤害载荷没有添音效推力或概率")
	runtime.register_target(other)
	check(runtime.advance(1.01)==4,"低帧率按原while补齐每个间隔每个目标")
	var before:=runtime.accumulated_time
	check(runtime.advance(8,0)==0 and runtime.accumulated_time==before,"暂停不积累或补发")
	actor.dead=true
	check(runtime.advance(.5)==1,"死亡玩家不受地表伤害")
	actor.dead=false
	other.position=Vector2(2.5,.5)
	check(runtime.advance(.5)==1,"每次取根位置，安全格不被旧位置伤害")
	terrain.cells[Vector3i.ZERO]={"flags":2,"states":{}}
	check(runtime.try_apply_contact(actor) and submitted.back()[0]==null,"无Burning来源快照允许环境伤害")
	var not_character:=RefCounted.new()
	terrain.cells[Vector3i.ZERO].states={2:{"source_entity":weakref(not_character)}}
	check(runtime.try_apply_contact(actor) and submitted.back()[0]==null,"非角色源不能假装CharacterBase")
	terrain.cells[Vector3i.ZERO].flags=1
	check(not runtime.try_apply_contact(actor),"湿润不造成燃烧伤害")
	terrain.cells[Vector3i.ZERO].flags=2
	runtime.on_map_unloading();active_map=null
	check(runtime.accumulated_time==0 and runtime.advance(10)==0,"卸载清时钟，缺地图不追时间")
	active_map=terrain
	runtime.on_map_loaded()
	player=null
	check(runtime.advance(.5)==1,"卸载保留已注册且存活的角色")
	runtime.unregister_target(actor)
	check(runtime.advance(.5)==0,"解除注册后不再采样原目标")
	other.position=Vector2(.5,.5)
	runtime.stop()
	check(runtime.advance(.5)==0,"系统停止清除注册，之后地图可由显式宿主重新绑定")
	var rejected:=System.new()
	check(rejected.configure(func():return terrain,func():return actor,
		func(t):return {"dead":t.dead,"position":t.position},
		func(_s,_t,_p):return false,func(s):return s)
		and not rejected.try_apply_contact(actor),"缺正式接收能力由提交宿主拒绝，不直接扣血")
	if failures==0:print("PASS 原地表周期伤害调度：%d 项" % checks)
	quit(0 if failures==0 else 1)
