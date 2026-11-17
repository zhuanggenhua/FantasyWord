extends Node2D
## 显式伤害诊断，不是 GAS 替代属性系统或正式角色场景。
const Combat = preload("res://game_core/combat/combat_rules.gd")
const Apply = preload("res://game_core/combat/formal_damage_application.gd")
const Hit = preload("res://gameplay/combat/charged_attack_hit.gd")
const Push = preload("res://game_core/combat/damage_push_policy.gd")
const Clock = preload("res://game_core/combat/attack_hit_frame.gd")
const Body = preload("res://game_core/movement/native_motion_body.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Step = preload("res://game_core/movement/source_fixed_step.gd")
const DamageLifecycle = preload("res://game_core/combat/deferred_damage_lifecycle.gd")

@export var automatic_clock := true
var timeline: RefCounted
var attacker: Node2D
var defender: Node2D
var outside: Node2D
var hit_count := 0
var last_hit: Dictionary = {}
var force_miss := false
var motion_enabled := true
var _label: Label

class Actor extends Node2D:
	signal action_interrupt_requested
	signal death_marked
	var stats: Dictionary
	var health: int
	var max_health: int
	var facing := Vector2.RIGHT # 原 lookAtDirection，与 transform.rotation 分开。
	var body: AnimatableBody2D
	var callbacks: Array = []
	var push_requests := 0
	var lifecycle := DamageLifecycle.new()
	var lifecycle_events: Array = []
	var marked_destroyed := false
	func source_position() -> Vector2: return body.get_movement_position()
	func can_move(): return not marked_destroyed
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
		body.add_child(hitbox)
		return hitbox
	func hooks() -> Dictionary:
		return {"impact": func(input,velocity):
				callbacks.append("impact")
				Push.try_push(input,false,velocity,Push.Mode.DEFAULT,
					{"regular":true,"critical":true,"missed":true,"silent":false},
					func(direction):
						push_requests += 1
						body.push_motion(direction)),
			"provoke": func(_source): callbacks.append("provoke"),
			"has_formal_stats": func(): return true,
			"current_health": func(): return health,
			"prepare": func(_source,input):
				callbacks.append("prepare")
				lifecycle.on_prepare_damage(input.silent),
			"apply_current_health_delta": func(delta, minimum, _maximum, _source):
				var previous := health
				health = maxi(minimum, health + delta)
				# Source dead is derived immediately, independent of delayed death owner.
				stats.dead = health == 0
				lifecycle.on_current_health_changed(previous, health)
				return health,
			"complete": func(_source,_input,_before,_applied): callbacks.append("complete")}

	func advance_damage_lifecycle() -> void:
		lifecycle.tick_safe(func(): return health, func(): return marked_destroyed,
			func():
				lifecycle_events.append("interrupt")
				action_interrupt_requested.emit(),
			func():
				marked_destroyed = true
				body.reset_movement()
				lifecycle_events.append("death")
				death_marked.emit())

func _ready() -> void:
	attacker = _actor(Vector2.ZERO, 30, 10, 0)
	defender = _actor(Vector2(0.75,0.2), 50, 0, 2)
	defender.facing = Vector2.LEFT
	outside = _actor(Vector2(4,0), 40, 0, 2)
	timeline = Clock.new(12, 36, _hit_frame)
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
	begin_accepted_release()

func _actor(source_position: Vector2, hp: int, attack: int, defense: int) -> Actor:
	var actor := Actor.new()
	actor.position = Vector2(source_position.x,-source_position.y)
	actor.health = hp
	actor.max_health = hp
	actor.stats = {"snapshot":{"physical_attack":attack,"physical_defense":defense,
		"magical_attack":0,"magical_defense":0,"luck":0,"agility":0},"dead":false,"invincible":false}
	add_child(actor)
	return actor

func begin_accepted_release() -> bool:
	# 原激活已被允许后的切片；未移植输入 buffer、状态标签或技能赋予。
	if timeline.playing: return false
	timeline.play()
	return true

func _hit_frame() -> void:
	hit_count += 1
	last_hit = Hit.run(get_world_2d(), attacker, attacker.source_position(),
		attacker.facing, func(collider): return collider.get_meta("actor", null),
		_apply_effect)
	if not last_hit.ok: push_error(last_hit.error)

func _apply_effect(caster: Object, target: Object, effect_id: int) -> void:
	# 诊断拥有合成属性和固定随机样本，不把它们冒充正式 ClickMoveTest 数据。
	assert(caster == attacker and effect_id == Hit.EFFECT_ID)
	_apply(target, 7, 1.5)

func _apply(target: Actor, flat: int, scale: float) -> void:
	var descriptor := {"flat_damage":flat,"scale":scale,"damage_type":Combat.DamageType.PHYSICAL,
		"critical_behavior":Combat.Resolution.DEFAULT,"miss_behavior":Combat.Resolution.DEFAULT,
		"ignore_defense":false,"silent":false}
	# 诊断取 roll=50、luck=agility=0，明确非暴击非闪避，不代持正式随机源。
	var output := Combat.solve_damage_output(attacker.stats,descriptor,true,func():return 50)
	var impact: Vector2 = target.source_position()-attacker.source_position()
	Apply.execute_damage_output(target.stats,output,true,func():return 99 if force_miss else 50,target.hooks(),impact)

func _process(delta: float) -> void:
	if automatic_clock: timeline.advance(delta)
	for actor in [attacker, defender, outside]:
		actor.advance_damage_lifecycle()
	_label.text = "蓄力释放命中诊断：非正式 GAS / 美术场景\n仅执行已经允许激活后的 Timeline 20004 命中切片\n帧 %d | 目标 HP %d / %d | 命中帧次数 %d" % [timeline.frame,defender.health,defender.max_health,hit_count]
	queue_redraw()
	if "--verify-attack" in OS.get_cmdline_user_args() and hit_count > 0 and not timeline.playing:
		var ok: bool = defender.health == 29 and defender.max_health == 50 \
			and defender.push_requests == 1 \
			and defender.body.get_movement_position().distance_to(Vector2(0.75,0.2)) > 0.1 \
			and attacker.health == 30 and outside.health == 40 and hit_count == 1
		if ok: print("PASS 直接启动攻击诊断：真实命中一次、扣21、最大生命不变、原生位移")
		else: push_error("直接启动攻击诊断未达到作者测试判据")
		get_tree().quit(0 if ok else 1)
func _physics_process(_native_delta: float) -> void:
	if motion_enabled:
		for actor in [attacker,defender,outside]: actor.body.advance_movement(Step.GAMEPLAY_DELTA_SECONDS)
func _draw() -> void:
	for actor in [attacker,defender,outside]:
		if is_instance_valid(actor): draw_rect(Rect2(actor.body.global_position-Vector2(0.5,0.5),Vector2.ONE),Color(0.3,0.5,0.6),false,0.02)
