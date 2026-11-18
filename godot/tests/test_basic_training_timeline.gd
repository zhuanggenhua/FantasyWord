extends "res://tests/test_clickmovetest_training_damage.gd"
const Timeline = preload("res://gameplay/combat/basic_attack_timeline.gd")

class TargetDirection extends TargetMotion:
	# 显式移动 owner 的逻辑方向，本案不同于绘制向下。
	var direction := Vector2.LEFT
	func get_target_direction() -> Vector2: return direction

class TestCueDriver extends Node:
	# 只记录调度回调；不假装加载原 Attack 精灵。
	var events: Array[String] = []
	func try_play_animation(key: String) -> bool:
		events.append(key)
		return true
	func try_restore_default_animation(key: String) -> bool:
		events.append("remove:" + key)
		return true

func run() -> void:
	var scene = Entry.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var owner := FacingOwner.new()
	var player := Player.new()
	player.actor = scene.actor
	var directory := ProjectSettings.globalize_path("user://basic-training-timeline")
	var pack := fixtures(scene,directory)
	var events := MapEvents.new()
	if scene.start_human_presentation(pack[1],directory) == null \
			or not scene.start_human_logic(owner,pack[0],func():return player,func():return null,events,func(_p):return false):
		printerr("未配置原测试场景角色")
		quit(1)
		return
	var target_owner := TargetDirection.new()
	var target: Node2D = scene.start_training_damage_target(target_owner,target_owner.hooks(),7752)
	if not is_instance_valid(target):
		printerr("未配置训练假人")
		quit(1)
		return
	var caster := Attributes.new()
	check(caster.configure(PackedInt32Array([100,40,10,6,6,4,8,4,100]),Combat.Alignment.GOOD,
		func():return false,func():return false),"原玩家数值投影")
	owner.set_look_at_direction(Vector2.RIGHT)
	scene.actor.request_move_position(Vector2(1.75,-2.35))
	await physics_frame
	await physics_frame
	await process_frame
	check(scene.actor.get_movement_position().is_equal_approx(Vector2(1.75,-2.35)),"使用实际根位置")
	var driver := TestCueDriver.new()
	root.add_child(driver)
	var timeline := Timeline.new(scene._hit_basic_training_target.bind(owner,caster.stats,func():return 50),driver)
	timeline.play()
	timeline.advance(.04)
	check(timeline.frame==2 and driver.events.is_empty(),"第2帧仅请求Cue")
	check(timeline.flush_display() and driver.events==["Attack"],"显示阶段只消费一次")
	timeline.advance(.08)
	scene.advance_human_charged_combat(0)
	check(timeline.frame==7 and target.health==220,"第8帧前不伤害")
	timeline.advance(.02)
	check(timeline.frame==8 and target.health==220,"命中帧只投递")
	scene.advance_human_charged_combat(0)
	check(target.health==206 and target_owner.trace[1]==["prepare",14],"面向攻击者时只结算基础伤害")
	check(not target.body.is_pushed() and scene.training_hit_cue.activation_count==1,"普通攻击不推且触发一次原Cue")
	target_owner.direction=Vector2.RIGHT
	timeline.advance(.264)
	check(timeline.frame==24 and driver.events==["Attack","remove:Attack"],"第24帧移除Cue")
	timeline.advance(.1)
	check(not timeline.playing,"第30帧自然完成")
	timeline.play()
	timeline.advance(.14)
	scene.advance_human_charged_combat(0)
	check(target.health==189 and scene.training_hit_cue.activation_count==2,"背刺两段伤害只提交一次效果Cue")
	timeline.stop()
	check(timeline.flush_display() and driver.events.size()==2,"停止时取消未播放Cue")
	owner.set_look_at_direction(Vector2.LEFT)
	timeline.play()
	timeline.advance(.52)
	scene.advance_human_charged_combat(0)
	check(timeline.flush_display() and driver.events.size()==2 and target.health==189,
		"背向假人的相对多边形不命中；跨过Cue窗口不补播")
	driver.free()
	scene.free()
	await process_frame
	if failed==0: print("PASS basic training timeline: %d checks" % n)
	quit(0 if failed==0 else 1)
