extends "res://validation/scenes/basic_attack_fixture.gd"
## NPC formal-20001 observation -> facing gate -> local action -> hit diagnostic.
## Not the imported ClickMoveTest actors, animator, GAS owner, or chase acceptance.
const Perception = preload("res://game_core/ai/ai_perception.gd")
const Lifecycle = preload("res://game_core/ai/ai_target_lifecycle.gd")
const AttackGate = preload("res://game_core/ai/ai_attack_gate.gd")
const BasicGate = preload("res://game_core/combat/basic_semi_auto_gate.gd")
var observation := Perception.new()
var ai := Lifecycle.new()
var attack_gate := AttackGate.new()
var input_gate: RefCounted
var enrolled_codes: Array[int] = [20001]
var action_eligible := true
var automatic_ai := true
var commands: Array = []
var attack_requests := 0
var last_query_ok := true

func _ready() -> void:
	# Original validator places the NPC +0.72 Y above the real player.
	# Here use the same relative setup with explicit diagnostic bodies.
	attacker = _actor(Vector2(0,0.72),220,0,0)
	defender = _actor(Vector2.ZERO,100,10,6)
	outside = _actor(Vector2(8,0),100,10,6)
	attacker.stats.alignment = Combat.Alignment.EVIL
	for hero in [defender,outside]:
		hero.stats.alignment = Combat.Alignment.GOOD
		hero.stats.snapshot.magical_attack = 6
		hero.stats.snapshot.magical_defense = 4
		hero.stats.snapshot.agility = 8
		hero.stats.snapshot.luck = 4
		hero.facing = Vector2(0,1)
	for actor in [attacker,defender,outside]:
		actor.body.collision_layer = Perception.CHARACTER_MASK
		actor.set_meta(Perception.STATE_META,actor.stats)
	timeline = Clock.new(8,30,_hit_frame)
	input_gate = BasicGate.new(_can_start,_commit)
	input_gate.sequence_stopped.connect(func(): timeline.stop())
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

func _source_position(actor: Node2D) -> Vector2:
	return Vector2(actor.global_position.x,-actor.global_position.y)

func _can_start() -> bool:
	return action_eligible and not attacker.stats.dead and not timeline.playing

func _first_triggerable() -> int:
	for code in enrolled_codes:
		if code == 20001 and _can_start(): return code
	return 0

func _commit() -> bool:
	if not _can_start(): return false
	timeline.play()
	return true

func _stop_fire(code: int) -> void:
	commands.append(["stop",code])
	if code == 20001: input_gate.release_use()

func _fire_ai(code: int) -> bool:
	commands.append(["fire_ai",code])
	if code != 20001 or not enrolled_codes.has(code): return false
	var accepted: bool = input_gate.request_use()
	if accepted: attack_requests += 1
	return accepted

func _attempt(target: Dictionary, distance: float) -> void:
	attack_gate.try_attack(ai,target.visible,distance,target.position-_source_position(attacker),
		_first_triggerable,func(direction): commands.append(["target_direction",direction]),
		func(): return attacker.facing,
		func(direction):
			commands.append(["look_direction",direction])
			attacker.facing = direction,
		_stop_fire,_fire_ai)

func advance_ai(delta: float) -> void:
	var origin := _source_position(attacker)
	# Explicitly refresh tracked actors even outside the detection circle.
	for actor in [defender,outside]:
		observation.refresh_observation(get_world_2d(),attacker.stats,origin,actor)
	var found := Perception.detect(get_world_2d(),origin,attacker.body,5.0,1.0,64)
	last_query_ok = found.ok
	if not found.ok: return
	var detected := observation.observe_ordered(get_world_2d(),attacker.stats,origin,found.colliders)
	ai.tick(delta,delta,origin,Vector2(0,0.72),detected,_attempt)

func advance_action(delta: float) -> void:
	# Keep established local action/Timeline update ordering.
	timeline.advance(delta)
	input_gate.advance(delta)

func _physics_process(_delta: float) -> void:
	if automatic_ai: advance_ai(Step.GAMEPLAY_DELTA_SECONDS)

func _process(delta: float) -> void:
	if automatic_clock: advance_action(delta)
	_label.text = "NPC 选敌到普攻命中诊断，非原版场景验收\n实际重叠/视线、正式能力20001局部门禁、Timeline101\n玩家 HP %d/%d | NPC HP %d/%d | 请求 %d | 命中帧 %d\n没有 Dmg 动画、追击、正式 GAS 属性和原美术。" % [
		defender.health,defender.max_health,attacker.health,attacker.max_health,attack_requests,hit_count]
	queue_redraw()
