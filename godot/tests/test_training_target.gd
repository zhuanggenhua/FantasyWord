extends SceneTree
const Target = preload("res://gameplay/clickmovetest/training_target.gd")
const Apply = preload("res://game_core/combat/formal_damage_application.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
var checks := 0
var failed := 0
class Owner extends RefCounted:
	var hp := 220
	var destroyed := false
	var events: Array = []
	var role := {"snapshot":{"physical_attack":0,"physical_defense":0,"magical_attack":0,"magical_defense":0,"luck":0,"agility":0},"dead":false,"invincible":false,"alignment":1}
	func can_move(): return not destroyed
	func calculate_move_speed(): return 4.0
	func calculate_speed_multiplier(): return 1.0
	func update_movement_animation(_v): pass
	func update_facing_from_intent(_v): pass
	func register_collision(_v): pass
	func bindings() -> Dictionary:
		return {"stats":func():return role,
			"current_health":func():return hp,
			"has_formal_stats":func():return true,
			"apply_current_health_delta":func(delta, minimum, _maximum, _source):
				hp=maxi(minimum,hp+delta)
				role.dead=hp==0
				return hp,
			"impact":func(_i,_v):events.append("impact"),
			"provoke":func(_s):events.append("provoke"),
			"prepare":func(_s,_i):events.append("prepare"),
			"complete":func(_s,_i,_p,_a):events.append("complete"),
			"is_destroyed":func():return destroyed,
			"interrupt_actions":func():events.append("interrupt"),
			"mark_death":func():destroyed=true;events.append("death")}
func check(ok:bool, label:String):
	checks+=1
	if not ok:
		failed+=1
		printerr("FAIL: ",label)
func _init(): call_deferred("run")
func run():
	var owner:=Owner.new()
	var target:=Target.new()
	check(not target.configure({},owner,7752),"拒绝缺属性拥有者")
	check(target.configure(owner.bindings(),owner,7752),"绑定显式属性/动作拥有者")
	check(not target.configure(owner.bindings(),owner,7752),"不重复初始化")
	root.add_child(target)
	await physics_frame
	await physics_frame
	check(target.source_position().is_equal_approx(Vector2(2.5,-2.75)),"真实源实例坐标")
	check(target.body.collision_layer==256,"源根对象 Character 层")
	check(target.hitbox.collision_layer==128 and target.hitbox.get_meta("actor")==target,"唯一角色身份，正确受击层")
	var hs:CollisionShape2D=target.hitbox.get_child(0)
	check(hs.shape is RectangleShape2D and hs.shape.size==Vector2(.6,1) and hs.position==Vector2(0,-.5),"源受击盒尺寸与偏移")
	var bs:CollisionShape2D=target.body.get_child(0)
	check(bs.shape is CapsuleShape2D and is_equal_approx(bs.shape.radius,.39) and is_equal_approx(bs.shape.height,.86),"源身体胶囊不是诊断矩形")
	check(bs.position.is_equal_approx(Vector2(0,-.42)),"源身体中心")
	var query:=PhysicsPointQueryParameters2D.new()
	query.position=Vector2(2.5,2.25)
	query.collision_mask=128
	query.collide_with_areas=true
	query.collide_with_bodies=false
	var hits:=target.get_world_2d().direct_space_state.intersect_point(query)
	check(hits.size()==1 and hits[0].collider==target.hitbox,"原生物理真实受击盒内命中")
	query.position=Vector2(2.5,2.85)
	check(target.get_world_2d().direct_space_state.intersect_point(query).is_empty(),"脚下不扩展为诊断单位方框")
	check(Target.initial_sheet().health==220 and Target.initial_sheet().attack_speed==100,"完整源属性包括攻击速度")
	var output:Dictionary={"source":null,"snapshot":null,"damage":30,"type":1,"flags":0,"miss_behavior":0,"ignore_defense":false,"silent":false}
	check(Apply.execute_damage_output(target.stats,output,false,Callable(),target.hooks()),"既有伤害管线使用显式真实拥有者")
	check(owner.hp==190 and target.health==190 and owner.events==["provoke","prepare","complete"],"唯一属性状态且无同步副本")
	target.advance_damage_lifecycle()
	check(owner.events[-1]=="interrupt" and not owner.destroyed,"安全阶段打断非立即死亡")
	output.damage=1000
	Apply.execute_damage_output(target.stats,output,false,Callable(),target.hooks())
	check(target.health==0 and target.stats.dead and not owner.destroyed,"血量即刻为零，延迟死亡")
	target.advance_damage_lifecycle()
	check(owner.destroyed and owner.events.slice(-2)==["interrupt","death"],"原安全阶段先打断再死亡")
	var n:=owner.events.size()
	target.advance_damage_lifecycle()
	check(owner.events.size()==n,"死亡不重复处理")
	target.free()
	if failed==0: print("PASS 训练假人角色切片: %d/%d" % [checks-failed,checks])
	quit(0 if failed==0 else 1)
