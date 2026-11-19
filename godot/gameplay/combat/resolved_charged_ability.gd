extends Node
## 20004、20001 与 20010 的实例接线；组合时使用单一槽位派发和实际角色标签。
## 角色与 Timeline 必须由调用方传入；外部 Timeline 唯一负责 Tick、任务与自然结束。
const Spec = preload("res://gameplay/combat/charged_timeline_spec.gd")
const Context = preload("res://game_core/combat/active_ability_fire_context.gd")
const BasicGate = preload("res://game_core/combat/basic_semi_auto_gate.gd")
const BASIC := 20001
const FIRE := 20010
const FireGate = preload("res://game_core/combat/flamethrower_auto_gate.gd")
const Gate = preload("res://game_core/combat/hold_release_gate.gd")
const Clock = preload("res://game_core/combat/attack_hit_frame.gd")
var spec := Spec.new()
var context := Context.new()
var gate: RefCounted
var local_active := false
var _owned_clock: RefCounted
var _configured_timeline: RefCounted
var _basic: Node
var _fire: Node
var _processing_pair := false

func configure(actor: Node2D, character: Object, timeline: RefCounted, position_reader: Callable = Callable(), code: int = Spec.CODE,
		shared_tags: Spec.AttackingTags = null) -> bool:
	if gate != null or not is_instance_valid(character): return false
	if not spec.configure(actor,timeline,position_reader,code,shared_tags): return false
	if not context.configure_timeline_rules(spec,code): return false
	_configured_timeline=timeline
	match code:
		BASIC: gate=BasicGate.new(_can_start,_perform_use)
		FIRE: gate=FireGate.new(_can_start,_perform_use)
		_: gate=Gate.new(_can_start,_perform_use)
	return context.configure(character,gate)

func attach_basic(actor: Node2D, character: Object, timeline: RefCounted, position_reader: Callable) -> bool:
	if gate==null or _basic!=null or spec.ability_code!=Spec.CODE: return false
	var basic: Node = get_script().new()
	add_child(basic)
	if not basic.configure(actor,character,timeline,position_reader,BASIC,spec.attacking_tags) \
			or not basic.take_clock_tick_ownership(timeline):
		basic.free()
		return false
	_basic=basic
	return true

func attach_fire(actor: Node2D, character: Object, timeline: RefCounted, position_reader: Callable) -> bool:
	if gate==null or _fire!=null or spec.ability_code not in [Spec.CODE,BASIC]: return false
	var fire_ability: Node = get_script().new()
	add_child(fire_ability)
	if not fire_ability.configure(actor,character,timeline,position_reader,FIRE,spec.attacking_tags) \
			or not fire_ability.take_clock_tick_ownership(timeline):
		fire_ability.free()
		return false
	_fire=fire_ability
	return true

func resolve(code: int) -> Object:
	if code==spec.ability_code and gate!=null: return self
	if code==FIRE and is_instance_valid(_fire): return _fire
	return _basic if code==BASIC and is_instance_valid(_basic) else null

func _can_start() -> bool: return spec.validate_fire_point(spec.ability_code).result==0
func _perform_use() -> bool: return context.perform_timeline_use()
func _known(ability: Object) -> bool: return ability==self or (is_instance_valid(_basic) and ability==_basic) or (is_instance_valid(_fire) and ability==_fire)
func get_input_gate(ability: Object) -> Object: return ability.gate if _known(ability) else null
func get_formal_gas_ability_code(ability: Object) -> int: return ability.spec.ability_code if _known(ability) else 0
func evaluate_start_rule(code: int,ability: Object) -> Dictionary:
	return ability.spec.validate_fire_point(code) if _known(ability) else {"available":false,"result":4}
func get_ability_debug_name(ability: Object) -> String:
	return ability.spec.get_ability_debug_name() if _known(ability) else ""
func report_start_rule_error(message: String,_ability: Object) -> void: push_error(message)
func should_update_look_at_direction_on_fire(ability: Object) -> bool:
	return _known(ability) and ability.spec.ability_code!=BASIC
func uses_automatic_runtime_state_management(ability: Object) -> bool: return _known(ability)
func set_ability_active(ability: Object,value: bool) -> void:
	if _known(ability): ability.local_active=value
func fire(ability: Object,command: Dictionary,activation: Variant,completion: Variant) -> void:
	if _known(ability): ability.context.fire(command,activation,completion)
func stop_fire(ability: Object) -> void:
	if _known(ability): ability.context.stop_fire()

## 新玩家仅拥有这两条 Timeline。原 AttackEvent 以及每个实例的输入阶段分别门禁。
func can_update_fresh_target_direction() -> bool:
	if spec.has_attacking_tag() or _locks_fresh_target_direction(): return false
	return not is_instance_valid(_fire) or not _fire._locks_fresh_target_direction()

func _locks_fresh_target_direction() -> bool:
	var activation: Variant = context.activation_context
	var has_aim: bool = activation != null and activation.has_aim_direction
	if not should_update_look_at_direction_on_fire(self) and not has_aim: return false
	match spec.ability_code:
		BASIC: return gate.state in [BasicGate.State.START,BasicGate.State.WINDUP,BasicGate.State.USE]
		FIRE: return gate.state in [FireGate.State.START,FireGate.State.WINDUP,FireGate.State.USE]
	return false

## CharacterAbilitySet 通知每个持有的 IActionInterruptReceiver，空闲也由自身 gate 处理。
## GAS Cancel/End 仍留给后续原安全阶段，既不重置移动也不合成松键。
func interrupt_owned_actions() -> void:
	if gate!=null: gate.interrupt()
	if is_instance_valid(_basic): _basic.interrupt_owned_actions()
	if is_instance_valid(_fire): _fire.interrupt_owned_actions()

## 明确分离后续 GAS 请求处理与输入门控 Tick；不得在 Fire 中立即激活。
func process_requests() -> void:
	if not is_instance_valid(_basic) and not is_instance_valid(_fire):
		spec.process_update()
		return
	if _processing_pair:
		push_error("同一角色技能请求处理不能重入。")
		return
	_processing_pair=true
	# 源系统先处理激活，再处理取消和结束；同帧多个激活的 ECS 实体次序未验收。
	spec.process_activation()
	if is_instance_valid(_basic): _basic.spec.process_activation()
	if is_instance_valid(_fire): _fire.spec.process_activation()
	spec.process_cancellation()
	if is_instance_valid(_basic): _basic.spec.process_cancellation()
	if is_instance_valid(_fire): _fire.spec.process_cancellation()
	spec.process_end()
	if is_instance_valid(_basic): _basic.spec.process_end()
	if is_instance_valid(_fire): _fire.spec.process_end()
	_processing_pair=false
func advance_input(delta: float) -> void:
	if gate!=null: gate.advance(delta)
	if is_instance_valid(_basic): _basic.advance_input(delta)
	if is_instance_valid(_fire): _fire.advance_input(delta)
func request_natural_end() -> void: spec.request_end(spec.ability_code)

## 可选接管已有20004命中时钟；调用方不得再对该时钟重复Tick。
## 通用Timeline不接受本入口，仍使用外部唯一宿主与request_natural_end。
func take_clock_tick_ownership(clock: RefCounted) -> bool:
	if _owned_clock!=null or not clock is Clock: return false
	if clock!=_configured_timeline: return false
	_owned_clock=clock
	return true
func advance_owned_clock(delta: float) -> void:
	if is_instance_valid(_basic): _basic.advance_owned_clock(delta)
	if is_instance_valid(_fire): _fire.advance_owned_clock(delta)
	if _owned_clock==null: return
	var was_playing: bool=_owned_clock.playing
	_owned_clock.advance(delta)
	if was_playing and not _owned_clock.playing: request_natural_end()
