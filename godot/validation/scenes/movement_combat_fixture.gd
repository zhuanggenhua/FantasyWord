extends "res://validation/scenes/ability_slot_fixture.gd"
## 源规则组合诊断，不是正式玩家场景。无目标override，不自动朝敌人瞄准。
const ChargedFixture = preload("res://validation/scenes/charged_attack_fixture.gd")
const Keyboard = preload("res://game_core/movement/keyboard_movement_input.gd")
const Commands = preload("res://game_core/movement/movement_commands.gd")
const Movement = preload("res://game_core/movement/character_movement.gd")
const Follow = preload("res://game_core/presentation/world_space_camera_follow.gd")
const ScreenProjection = preload("res://game_core/presentation/orthographic_screen_projection.gd")
const BasicGate = preload("res://game_core/combat/basic_semi_auto_gate.gd")
const PolygonQuery = preload("res://game_core/combat/polygon_hitbox_query.gd")
const BASIC_POINTS = [Vector2(0.175,-0.25),Vector2(1.125,-0.25),Vector2(1.125,0.55),Vector2(0.175,0.55)]
const BASIC_ABILITY := 20001
var basic_gate: RefCounted
var basic_timeline: RefCounted
var basic_hit_count := 0
var keyboard := Keyboard.new()
var movement: RefCounted
var camera: Camera2D
var blocked := false
var _created_actors := 0
class MovingActor extends ChargedFixture.Actor:
	var movement_allowed: Callable
	var is_controlled_actor := false
	func can_move(): return not movement_allowed.is_valid() or movement_allowed.call()
	func calculate_move_speed(): return 4.0 if is_controlled_actor else 0.0
	func update_facing_from_intent(value: Vector2):
		# 原基础预制体MovementBased=0，idleThreshold=.05。
		if value.length_squared() > 0.05*0.05: facing = value.normalized()

func _actor(source_position: Vector2, hp: int, attack: int, defense: int) -> ChargedFixture.Actor:
	var actor := MovingActor.new()
	# 隔离验收起点用于证明先移动入范围；不是原关卡出生点。
	# The parent setup builds the attacker first; its fixture control role
	# is independent of combat stats or later changes to equipment.
	actor.is_controlled_actor = _created_actors == 0
	_created_actors += 1
	var start := Vector2(-2,0) if actor.is_controlled_actor else source_position
	actor.position = Vector2(start.x,-start.y)
	actor.health = hp
	actor.max_health = hp
	actor.stats = {"snapshot":{"physical_attack":attack,"physical_defense":defense,
		"magical_attack":0,"magical_defense":0,"luck":0,"agility":0},"dead":false,"invincible":false}
	add_child(actor)
	return actor

func _ready():
	super._ready()
	equipped_slots[0] = BASIC_ABILITY # 原 ClickMoveTestGasBasicAttackValidator 赋予的槽位，不是自动生成装备。
	basic_timeline = Clock.new(8,30,_basic_hit_frame)
	basic_gate = BasicGate.new(_can_use_basic,_commit_basic)
	basic_gate.sequence_stopped.connect(func(): basic_timeline.stop())
	attacker.movement_allowed = func(): return not timeline.playing and not basic_timeline.playing
	movement = Movement.new(attacker.body,0.05)
	movement.set_movement_control_mode(Movement.Mode.CLICK_TO_MOVE)
	# 父战斗诊断固定镜头不再生效，复用源Follow适配器。
	for child in get_children():
		if child is Camera2D: child.enabled = false
	camera = Follow.new()
	add_child(camera)
	camera.follow = attacker.body
	camera.make_current()
	_resize()
	camera.advance_follow(0)
	get_viewport().size_changed.connect(_resize)

func _resize():
	camera.zoom = ScreenProjection.zoom_for_view_height(get_viewport_rect().size.y,5.0)
	camera.force_update_scroll()

func _input(event: InputEvent):
	super._input(event)
	if movement != null and event is InputEventKey:
		if event.physical_keycode == KEY_TAB and event.pressed and not event.echo:
			Commands.on_toggle_performed(_submit)
		keyboard.handle_key(event,blocked,_submit)

func _submit(kind: int, direction: Vector2, point: Variant) -> int:
	return Commands.submit_single_character(kind,direction,point,attacker.body,true,
		attacker.body,true,true,attacker.body,movement,null)

func _dispatch_slot_edge(index: int, pressed: bool) -> void:
	if index == 0:
		if equipped_slots.get(0,0) != BASIC_ABILITY: return
		if pressed:
			if not interacted_this_frame: basic_gate.request_use()
		else: basic_gate.release_use()
		return
	super._dispatch_slot_edge(index,pressed)

func _can_use_basic() -> bool:
	return equipped_slots.get(0,0) == BASIC_ABILITY and ability_eligible and not timeline.playing and not basic_timeline.playing

func _commit_basic() -> bool:
	if not _can_use_basic(): return false
	basic_timeline.play()
	return true

func _can_use_charge() -> bool:
	return super._can_use_charge() and (basic_timeline == null or not basic_timeline.playing)

func _basic_hit_frame() -> void:
	basic_hit_count += 1
	var targets := PolygonQuery.query(get_world_2d(),attacker.source_position(),
		attacker.facing,PackedVector2Array(BASIC_POINTS),128,attacker,
		func(collider): return collider.get_meta("actor",null))
	for target in targets:
		_apply_basic(target,4,1.0)
		var toward_attacker: Vector2 = attacker.source_position()-target.source_position()
		var facing: Vector2 = target.facing
		if facing.length_squared() <= 0.0001: facing = Vector2.RIGHT
		if toward_attacker.length_squared()>0.0001 and facing.normalized().dot(toward_attacker.normalized())<=-0.35:
			_apply_basic(target,3,0.0)

func _apply_basic(target, flat: int, scale: float) -> void:
	var descriptor := {"flat_damage":flat,"scale":scale,"damage_type":Combat.DamageType.PHYSICAL,
		"critical_behavior":Combat.Resolution.DEFAULT,"miss_behavior":Combat.Resolution.DEFAULT,
		"ignore_defense":false,"silent":false}
	var output := Combat.solve_damage_output(attacker.stats,descriptor,true,func():return 50)
	var hooks: Dictionary = target.hooks()
	# Effect2003 两段 PushMode=Disabled，不能复用蓄力默认冲击。
	hooks.impact = func(_input,_velocity): target.callbacks.append("impact_disabled")
	Apply.execute_damage_output(target.stats,output,true,func():return 50,hooks,
		target.source_position()-attacker.source_position())

func _process(delta):
	super._process(delta)
	if basic_timeline != null and automatic_clock: basic_timeline.advance(delta)
	if basic_gate != null: basic_gate.advance(delta)
	if camera != null: camera.advance_follow(delta)
	_label.text += "\n移动+战斗规则诊断：Tab切换方向模式，WASD/方向键移动；1按住完成普攻，Q/2按住后松开蓄力。\n没有原地图，点击停用；无鼠标自动瞄准；攻击期间本地映射Event.Attacking移动锁。\n普攻为显式测试装备20001/槽0；未接正式技能开销、属性与冷却。"
