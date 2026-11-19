extends Node
## ClickMoveTest 活动假人预制体额外正式能力 20001。复用原正式门禁、Timeline101、
## 实际角色受击盒与 Effect2003，不为假人设置玩家装备槽或构造替代接收者。
const AttackGate = preload("res://game_core/ai/ai_attack_gate.gd")
const Dispatch = preload("res://game_core/combat/equipped_ability_dispatch.gd")
const Timeline = preload("res://gameplay/combat/basic_attack_timeline.gd")
const Ability = preload("res://gameplay/combat/resolved_charged_ability.gd")
const HitPolygon = preload("res://game_core/combat/polygon_hitbox_query.gd")
const BasicDamage = preload("res://gameplay/combat/basic_damage_effect.gd")
const Effects = preload("res://gameplay/combat/charged_effect_application.gd")
const Feedback = preload("res://gameplay/clickmovetest/training_hit_feedback_cue.gd")
const CODE := 20001
var _subject: WeakRef
var _player: WeakRef
var _hitbox: WeakRef
var _direction_owner: Object
var _player_stats: Callable
var _player_direction: Callable
var _roll: Callable
var _player_hooks: Dictionary
var _gate := AttackGate.new()
var _effects := Effects.new()
var hit_feedback := Feedback.new()
var runtime: Node
var timeline: RefCounted

func configure(subject: Node2D, direction_owner: Object, player: Node2D, hitbox: Area2D,
		read_stats: Callable, read_direction: Callable, hooks: Dictionary, roll: Callable) -> bool:
	if runtime != null or not is_instance_valid(subject) or not is_instance_valid(player) \
			or not is_instance_valid(direction_owner) or not is_instance_valid(hitbox):
		return false
	if hitbox.get_parent()!=player or hitbox.collision_layer!=Timeline.HIT_MASK \
			or not read_stats.is_valid() or not read_direction.is_valid() or not roll.is_valid():
		return false
	for method in ["get_look_at_direction","set_look_at_direction","set_target_direction"]:
		if not direction_owner.has_method(method): return false
	for key in ["provoke","has_formal_stats","current_health","prepare","apply_current_health_delta","complete"]:
		if not hooks.get(key) is Callable or not hooks[key].is_valid(): return false
	if not is_instance_valid(subject.presentation) or subject.presentation.driver.resolve_playable_state("Attack").is_empty():
		return false
	_subject = weakref(subject)
	_player = weakref(player)
	_hitbox = weakref(hitbox)
	_direction_owner = direction_owner
	_player_stats = read_stats
	_player_direction = read_direction
	_roll = roll
	_player_hooks = hooks.duplicate()
	timeline = Timeline.new(_hit,subject.presentation.driver)
	runtime = Ability.new()
	add_child(runtime)
	return runtime.configure(subject,direction_owner,timeline,subject.get_movement_position,CODE) \
		and runtime.take_clock_tick_ownership(timeline)

func attempt(target: Dictionary, distance: float) -> void:
	var subject: Node2D = _subject.get_ref()
	if not is_instance_valid(subject) or target.actor.get_ref() != _player.get_ref(): return
	_gate.try_attack(subject.ai_controller.behaviour,target.visible,distance,
		target.position-subject.get_movement_position(),_first_triggerable,
		_direction_owner.set_target_direction,_direction_owner.get_look_at_direction,_direction_owner.set_look_at_direction,
		_stop,_fire)

func _first_triggerable() -> int:
	return CODE if Dispatch.can_fire_resolved(runtime,runtime,true)==0 else 0

func _stop(code: int) -> void:
	if code==CODE: runtime.stop_fire(runtime)

func _fire(code: int) -> bool:
	if code!=CODE: return false
	var subject: Node2D = _subject.get_ref()
	return Dispatch.fire_resolved(runtime,_direction_owner,runtime,true,
		{"actor":subject,"issuer_kind":2,"issuer_id":"ai"},null)==0

func advance(delta: float) -> void:
	runtime.process_requests()
	runtime.advance_owned_clock(delta)
	_effects.run_effects(hit_feedback.request)
	runtime.advance_input(delta)
	timeline.flush_display()
	hit_feedback.flush_display()

func interrupt() -> void:
	if runtime != null and runtime.gate != null:
		runtime.gate.interrupt()
		runtime.process_requests()
	_effects.clear()

func _exit_tree() -> void:
	if timeline != null: timeline.stop()
	_effects.clear()
	hit_feedback.dispose()

func _hit() -> void:
	var subject: Node2D = _subject.get_ref()
	var player: Node2D = _player.get_ref()
	if not is_instance_valid(subject) or not is_instance_valid(player): return
	var facing: Vector2 = _direction_owner.get_look_at_direction()
	var position: Vector2 = subject.get_movement_position()
	if not facing.is_finite() or not position.is_finite() or facing.length_squared()<=.0001: return
	for receiver in HitPolygon.query(subject.get_world_2d(),position,facing,
			PackedVector2Array(Timeline.ATTACK_POLYGON),Timeline.HIT_MASK,subject,
			func(collider): return player if is_instance_valid(_hitbox.get_ref()) and collider==_hitbox.get_ref() else null):
		_effects.request(subject,receiver,_apply_damage)

func _apply_damage(source: Node2D, target: Node2D) -> void:
	if not _player_stats.is_valid() or not _roll.is_valid(): return
	var current: Variant = _player_stats.call()
	if not current is Dictionary or not current.get("snapshot") is Dictionary: return
	var pose := func() -> Dictionary:
		if not is_instance_valid(source) or not is_instance_valid(target) or not _player_direction.is_valid(): return {}
		return {"source_root":source.get_movement_position(),"target_root":target.get_movement_position(),
			"target_direction":_player_direction.call()}
	BasicDamage.execute_damage_phase(source.stats,current,_player_hooks,pose,true,true,_roll,
		func(): return [source.stats,_player_stats.call()] if is_instance_valid(source) and is_instance_valid(target) else [])
