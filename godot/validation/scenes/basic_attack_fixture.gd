extends Node2D
## 显式伤害诊断，不是 GAS 替代属性系统或正式角色场景。
const Combat = preload("res://game_core/combat/combat_rules.gd")
const Apply = preload("res://game_core/combat/formal_damage_application.gd")
const Query = preload("res://game_core/combat/polygon_hitbox_query.gd")
const Clock = preload("res://game_core/combat/attack_hit_frame.gd")
const Body = preload("res://game_core/movement/native_motion_body.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Step = preload("res://game_core/movement/source_fixed_step.gd")
const POINTS = [Vector2(0.175,-0.25), Vector2(1.125,-0.25), Vector2(1.125,0.55), Vector2(0.175,0.55)]
@export var automatic_clock := true
var timeline: RefCounted
var attacker: Node2D
var defender: Node2D
var outside: Node2D
var hit_count := 0
var _label: Label

class Actor extends Node2D:
	var stats: Dictionary
	var health: int
	var max_health: int
	var facing := Vector2.RIGHT # 原 lookAtDirection，与 transform.rotation 分开。
	var body: AnimatableBody2D
	var callbacks: Array = []
	func can_move(): return true
	func calculate_move_speed(): return 0.0
	func calculate_speed_multiplier(): return 1.0
	func update_movement_animation(_value): pass
	func update_facing_from_intent(_value): pass
	func register_collision(_value): pass
	func _ready() -> void:
		body = Body.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2.ONE # 原 EditMode 辅助角色的默认 BoxCollider2D。
		body.add_child(shape)
		add_child(body)
		body.configure_movement(shape, Filter.new(Filter.Mode.FREE,false,0.05,10,10),self,7752)
		add_hitbox()
	func add_hitbox() -> Area2D:
		var hitbox := Area2D.new()
		hitbox.collision_layer = 128
		hitbox.collision_mask = 0
		hitbox.set_meta("actor", self) # 显式绑定，等价目标身份不是根身体命中。
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2.ONE
		hitbox.add_child(shape)
		add_child(hitbox)
		return hitbox
	func hooks() -> Dictionary:
		return {"impact": func(_input,_velocity): callbacks.append("impact_disabled"),
			"provoke": func(_source): callbacks.append("provoke"),
			"has_formal_stats": func(): return true,
			"current_health": func(): return health,
			"prepare": func(_source,_input): callbacks.append("prepare"),
			"apply_current_health_delta": func(delta, minimum, _maximum, _source):
				health = maxi(minimum, health + delta)
				return health,
			"complete": func(_source,_input,_before,_applied): callbacks.append("complete")}

func _ready() -> void:
	attacker = _actor(Vector2.ZERO, 30, 10, 0)
	defender = _actor(Vector2(0.6,0.2), 40, 0, 2)
	defender.facing = Vector2.LEFT
	outside = _actor(Vector2(4,0), 40, 0, 2)
	timeline = Clock.new(8, 30, _hit_frame)
	var camera := Camera2D.new()
	camera.zoom = Vector2(90,90)
	add_child(camera)
	camera.make_current()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	_label = Label.new()
	_label.position = Vector2(12,12)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_label)
	if "--diagnose-attack" in OS.get_cmdline_user_args():
		_start_diagnostic_after_physics()

func _start_diagnostic_after_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	begin_accepted_attack()

func _actor(source_position: Vector2, hp: int, attack: int, defense: int) -> Actor:
	var actor := Actor.new()
	actor.position = Vector2(source_position.x,-source_position.y)
	actor.health = hp
	actor.max_health = hp
	actor.stats = {"snapshot":{"physical_attack":attack,"physical_defense":defense,
		"magical_attack":0,"magical_defense":0,"luck":0,"agility":0},"dead":false,"invincible":false}
	add_child(actor)
	return actor

func begin_accepted_attack() -> bool:
	# 原激活已被允许后的切片；未移植输入 buffer、状态标签或技能赋予。
	if timeline.playing: return false
	timeline.play()
	return true

func _hit_frame() -> void:
	hit_count += 1
	var targets := Query.query(get_world_2d(), Vector2(attacker.position.x,-attacker.position.y),
		attacker.facing, PackedVector2Array(POINTS),128,attacker,
		func(collider): return collider.get_meta("actor",null))
	for target in targets:
		_apply(target,4,1.0)
		var delta: Vector2 = attacker.position-target.position
		var facing: Vector2 = Vector2(target.facing.x,-target.facing.y)
		if facing.length_squared() <= 0.0001: facing = Vector2.RIGHT
		if delta.length_squared()>0.0001 and facing.normalized().dot(delta.normalized()) <= -0.35:
			_apply(target,3,0.0)

func _apply(target: Actor, flat: int, scale: float) -> void:
	var descriptor := {"flat_damage":flat,"scale":scale,"damage_type":Combat.DamageType.PHYSICAL,
		"critical_behavior":Combat.Resolution.DEFAULT,"miss_behavior":Combat.Resolution.DEFAULT,
		"ignore_defense":false,"silent":false}
	# 诊断取 roll=50、luck=agility=0，明确非暴击非闪避，不代持正式随机源。
	var output := Combat.solve_damage_output(attacker.stats,descriptor,true,func():return 50)
	var impact := Vector2(target.position.x-attacker.position.x,attacker.position.y-target.position.y)
	Apply.execute_damage_output(target.stats,output,true,func():return 50,target.hooks(),impact)

func _process(delta: float) -> void:
	if automatic_clock: timeline.advance(delta)
	_label.text = "普通攻击命中诊断：非正式 GAS / 美术场景\n仅执行已经允许激活后的 Timeline 101 命中切片\n帧 %d | 目标 HP %d / %d | 命中帧次数 %d" % [timeline.frame,defender.health,defender.max_health,hit_count]
	queue_redraw()
	if "--verify-attack" in OS.get_cmdline_user_args() and hit_count > 0 and not timeline.playing:
		var ok: bool = defender.health == 27 and defender.max_health == 40 			and not defender.body.is_pushed() and attacker.health == 30 and outside.health == 40 and hit_count == 1
		if ok: print("PASS 直接启动攻击诊断：真实命中一次、扣13、最大生命不变、无推力")
		else: push_error("直接启动攻击诊断未达到作者测试判据")
		get_tree().quit(0 if ok else 1)
func _physics_process(_native_delta: float) -> void:
	for actor in [attacker,defender,outside]: actor.body.advance_movement(Step.GAMEPLAY_DELTA_SECONDS)
func _draw() -> void:
	for actor in [attacker,defender,outside]:
		if is_instance_valid(actor): draw_rect(Rect2(actor.position-Vector2(0.5,0.5),Vector2.ONE),Color(0.3,0.5,0.6),false,0.02)
