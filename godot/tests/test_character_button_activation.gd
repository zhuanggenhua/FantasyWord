extends SceneTree
const Activation = preload("res://game_core/interaction/character_button_activation.gd")
class Owner extends RefCounted:
	var allowed := true
	var direction := Vector2.RIGHT
	func can_interact() -> bool: return allowed
	func get_target_direction() -> Vector2: return direction
class Receiver extends RefCounted:
	var calls := 0
	var last: Object
	func on_interact(owner: Object) -> void:
		calls += 1
		last = owner
var failures := 0
var checks := 0
var audio_count := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr(label)
func audio() -> void: audio_count += 1
func _initialize() -> void: call_deferred("run")
func collider(parent: Node, position: Vector2, area: bool = true, mask: int = 64) -> CollisionObject2D:
	var body: CollisionObject2D = Area2D.new() if area else StaticBody2D.new()
	body.position = position
	body.collision_layer = mask
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 0.04
	body.add_child(shape)
	parent.add_child(body)
	return body
func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var pivot := Node2D.new()
	pivot.position = Vector2(0,-0.4)
	world.add_child(pivot)
	var owner := Owner.new()
	var activation := Activation.new()
	check(activation.configure(owner,pivot,audio),"显式配置")
	var behind := collider(world,Vector2(-0.1,-0.4))
	var ahead := collider(world,Vector2(0.3,-0.4),false)
	var far := collider(world,Vector2(0.6,-0.4))
	var excluded := collider(world,Vector2(0.01,-0.4),true,1)
	for body in [behind,ahead,far]: activation.register_collider(body,body,Vector2.ZERO)
	await physics_frame
	await physics_frame
	check(activation.resolve_target()==ahead,"原生 body 和 area 查询、layer=64、排除后方")
	check(not activation.try_interact(),"近目标无接收者不能跳到远目标")
	check(audio_count==0 and not activation.interacted_this_frame,"失败无音效且不设闩锁")
	var a := Receiver.new()
	var b := Receiver.new()
	var c := Receiver.new()
	activation.register_receivers(ahead,[a,b],func(): return true)
	activation.register_receivers(world,[c],func(): return true)
	activation.refresh_current_target()
	check(not activation.interacted_this_frame,"refresh 清除帧闩锁")
	check(activation.get_current_target_position()==Vector2(0.3,0.4),"缓存位置为原物体坐标")
	check(activation.try_interact(),"有效派发")
	check(a.calls==1 and b.calls==1 and c.calls==1 and a.last==owner,"同物体及父级全部组件")
	check(audio_count==1 and activation.interacted_this_frame,"成功才音效及闩锁")
	owner.direction=Vector2.LEFT
	check(activation.try_interact() and activation.current_target==ahead and a.calls==1 and c.calls==2,"执行时重查而不是缓存")
	owner.allowed=false
	check(activation.resolve_target()==null,"自动查询门禁")
	check(activation.try_interact(ahead),"底层显式目标绕过搜索门禁，不是命令入口")
	activation.reset_state()
	check(not activation.interacted_this_frame and activation.get_current_target_position()==null,"reset 清除")
	owner.allowed=true
	owner.direction=Vector2.RIGHT
	# origin 在前但原始 offset 将点移到后方；形状仍与查询圆重叠。
	activation.register_collider(ahead,ahead,Vector2(-0.5,0))
	check(activation.resolve_target()==far,"dot 使用原始 offset")
	activation.register_collider(ahead,ahead,Vector2(-0.3,0))
	check(activation.resolve_target()==far,"dot 等于零不接收")
	activation.register_collider(ahead,ahead,Vector2(0.4,0))
	check(activation.resolve_target()==ahead,"排序用 origin 而非 offset 中心")
	activation.register_receivers(world,[c],func(): return false)
	var before := c.calls
	check(activation.try_interact(ahead) and c.calls==before,"跳过 inactive 父级组件")
	activation.register_receivers(ahead,[a,b],func(): return false)
	var start_calls := a.calls
	check(activation.try_interact(ahead) and a.calls==start_calls+1,"inactive 起点仍检查")
	owner.direction=Vector2.ZERO
	check(activation.resolve_target()==null,"零方向无前方目标")
	owner.direction=Vector2.RIGHT
	# 超过引擎默认上限；均在后方，唯一前方目标须仍可查到。
	for i in range(40):
		var extra := collider(world,Vector2(-0.2,-0.4))
		activation.register_collider(extra,extra,Vector2.ZERO)
	await physics_frame
	await physics_frame
	check(activation.resolve_target()==ahead,"超过32碰撞结果不截断")
	check(is_instance_valid(excluded),"其他层夹具仍存在")
	world.free()
	if failures==0: print("PASS character_button_activation ",checks)
	quit(1 if failures else 0)
