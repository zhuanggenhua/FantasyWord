extends "res://tests/test_clickmovetest_training_damage.gd"

class TrackingOwner extends Owner:
	func update_movement_animation(_direction: Vector2) -> void: pass

# 使用真实 Entry、实际 AnimatableBody2D、固定步和碰撞世界。
# 遮挡与位移只用于隔离验证，不把它们当成作者场景的碰撞部署。
func ticks(count: int) -> void:
	for i in range(count): await physics_frame

func add_visibility_fixture(parent: Node2D, at: Vector2, layer: int) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = layer
	area.collision_mask = 0
	area.position = Vector2(at.x, -at.y)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(.15,1.2)
	shape.shape = box
	area.add_child(shape)
	parent.add_child(area)
	return area

func run() -> void:
	var scene = Entry.instantiate()
	root.add_child(scene)
	var owner := TrackingOwner.new()
	var player := Player.new()
	player.actor = scene.actor
	var events := MapEvents.new()
	var private_rules := OS.get_environment("FORMAL_SURFACE_RULES")
	var rules: Dictionary = (read(private_rules) if not private_rules.is_empty()
		else fixtures(scene,ProjectSettings.globalize_path("user://training-tracking"))[0])
	check(scene.start_logic(owner,rules,func():return player,func():return null,events,func(_p):return false),
		"Entry 实际绑定玩家与原固定步")
	var target_owner := TargetMotion.new()
	var target = scene.start_training_damage_target(target_owner,target_owner.hooks(),7752)
	check(is_instance_valid(target),"Entry 实际生成源活动训练假人")
	if not is_instance_valid(target):
		scene.free()
		quit(1)
		return
	var ai = target.ai_controller
	var caster := Attributes.new()
	check(caster.configure(PackedInt32Array([100,40,10,6,6,4,8,4,100]),Combat.Alignment.GOOD,
		func():return false),"玩家采用源角色表的初始属性")
	check(not scene.start_training_target_tracking(caster.stats,null),"无可见性世界拥有者时不启动")
	var world_owner := Node2D.new()
	scene.add_child(world_owner)
	var ignored := add_visibility_fixture(world_owner,Vector2(1.5,-2.75),128)
	var blocker := add_visibility_fixture(world_owner,Vector2(1.5,-2.75),64)
	scene.actor.request_move_position(Vector2(.5,-2.75))
	await ticks(4)
	check(scene.actor.get_movement_position().is_equal_approx(Vector2(.5,-2.75)),"玩家的真实身体而非表现子节点在检测范围")
	check(ai.current_target()==null,"未绑定时视线不自动改变挑衅状态")
	check(scene.start_training_target_tracking(caster.stats,world_owner),"实际 Entry 仅显式装配一次")
	check(not scene.start_training_target_tracking(caster.stats,world_owner),"不能替换活动入口")
	await ticks(1)
	check(ai.current_target()==null,"首个固定步只生成碰撞快照")
	await ticks(2)
	check(ai.current_target()==null,"源射线层触发器遮挡，未预先选择对手")
	blocker.free()
	await ticks(4)
	check(ai.current_target()==scene.actor and ai.behaviour.target_position.is_equal_approx(Vector2(.5,-2.75)),
		"穿过无关层，选中原场景玩家根身体，记录实际位置")
	scene.actor.request_move_position(Vector2(.75,-2.75))
	await ticks(4)
	var last: Vector2 = ai.behaviour.target_position
	check(last.is_equal_approx(Vector2(.75,-2.75)),"目标移动时从实际物理位置刷新")
	blocker = add_visibility_fixture(world_owner,Vector2(1.5,-2.75),64)
	scene.actor.request_move_position(Vector2(.9,-2.75))
	await ticks(5)
	check(ai.current_target()==scene.actor and ai.behaviour.target_position==last
		and ai.behaviour.time_since_target_last_seen>0,"失去视线保留目标与上次可见位置")
	for i in range(161):
		if ai.current_target()==null: break
		await physics_frame
	check(ai.current_target()==null and is_equal_approx(ai.behaviour.retarget_cooldown,1.)
		and ai.behaviour.target_position==last,"首次累计严格超过源 3 秒后丢失，在同一步保留最后位置")
	await ticks(1)
	check(ai.behaviour.target_position==target.SOURCE_POSITION,"下一固定步返回出生归位点")
	blocker.free()
	await ticks(40)
	check(ai.current_target()==null and ai.behaviour.retarget_cooldown>0,"视线恢复不绕过重选冷却")
	await ticks(15)
	check(ai.current_target()==scene.actor,"冷却结束后从下一步可用碰撞快照重新选敌")
	scene.actor.request_move_position(Vector2(-9,-2.75))
	for i in range(8):
		if ai.current_target()==null: break
		await physics_frame
	check(ai.current_target()==null and is_equal_approx(ai.behaviour.retarget_cooldown,3.)
		and ai.behaviour.target_position==target.SOURCE_POSITION,"超过原严格 10 的距离当步清目标并归位")
	ignored.free()
	world_owner.free()
	await ticks(2)
	check(is_equal_approx(ai.behaviour.retarget_cooldown,3.),"世界拥有者卸载，停止读残留碰撞世界")
	scene.free()
	await process_frame
	if failed == 0: print("PASS ClickMoveTest training tracking: %d checks" % n)
	quit(0 if failed==0 else 1)
