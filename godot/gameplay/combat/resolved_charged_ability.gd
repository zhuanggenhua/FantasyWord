extends Node
## 20004 的显式装配对象兼 resolved 宿主；不修改作者槽位，不制造 Timeline 效果。
## 角色与 Timeline 必须由调用方传入；外部 Timeline 唯一负责 Tick、任务与自然结束。
const Spec = preload("res://gameplay/combat/charged_timeline_spec.gd")
const Context = preload("res://game_core/combat/active_ability_fire_context.gd")
const Gate = preload("res://game_core/combat/hold_release_gate.gd")
const Clock = preload("res://game_core/combat/attack_hit_frame.gd")
var spec := Spec.new()
var context := Context.new()
var gate: RefCounted
var local_active := false
var _owned_clock: RefCounted
var _configured_timeline: RefCounted

func configure(actor: Node2D, character: Object, timeline: RefCounted, position_reader: Callable = Callable()) -> bool:
	if gate != null or not is_instance_valid(character): return false
	if not spec.configure(actor,timeline,position_reader): return false
	if not context.configure_timeline_rules(spec,Spec.CODE): return false
	_configured_timeline=timeline
	gate=Gate.new(_can_start,_perform_use)
	return context.configure(character,gate)

func resolve(code: int) -> Object:
	return self if code==Spec.CODE and gate!=null else null
func _can_start() -> bool: return spec.validate_fire_point(Spec.CODE).result==0
func _perform_use() -> bool: return context.perform_timeline_use()
func get_input_gate(ability: Object) -> Object: return gate if ability==self else null
func get_formal_gas_ability_code(ability: Object) -> int: return Spec.CODE if ability==self else 0
func evaluate_start_rule(code: int,ability: Object) -> Dictionary:
	return spec.validate_fire_point(code) if ability==self else {"available":false,"result":4}
func get_ability_debug_name(_ability: Object) -> String: return spec.get_ability_debug_name()
func report_start_rule_error(message: String,_ability: Object) -> void: push_error(message)
func should_update_look_at_direction_on_fire(ability: Object) -> bool: return ability==self
func uses_automatic_runtime_state_management(ability: Object) -> bool: return ability==self
func set_ability_active(ability: Object,value: bool) -> void:
	if ability==self: local_active=value
func fire(ability: Object,command: Dictionary,activation: Variant,completion: Variant) -> void:
	if ability==self: context.fire(command,activation,completion)
func stop_fire(ability: Object) -> void:
	if ability==self: context.stop_fire()

## 明确分离后续 GAS 请求处理与输入门控 Tick；不得在 Fire 中立即激活。
func process_requests() -> void: spec.process_update()
func advance_input(delta: float) -> void:
	if gate!=null: gate.advance(delta)
func request_natural_end() -> void: spec.request_end(Spec.CODE)

## 可选接管已有20004命中时钟；调用方不得再对该时钟重复Tick。
## 通用Timeline不接受本入口，仍使用外部唯一宿主与request_natural_end。
func take_clock_tick_ownership(clock: RefCounted) -> bool:
	if _owned_clock!=null or not clock is Clock: return false
	if clock!=_configured_timeline: return false
	_owned_clock=clock
	return true
func advance_owned_clock(delta: float) -> void:
	if _owned_clock==null: return
	var was_playing: bool=_owned_clock.playing
	_owned_clock.advance(delta)
	if was_playing and not _owned_clock.playing: request_natural_end()
