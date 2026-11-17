extends "res://validation/scenes/charged_attack_fixture.gd"
## 独立诊断装备表，不声明原项目默认存档装有蓄力技能。
const SlotKeys = preload("res://game_core/combat/ability_slot_keyboard_input.gd")
const HoldRelease = preload("res://game_core/combat/hold_release_gate.gd")
const CHARGED_ABILITY := 20004

var equipped_slots := {1: CHARGED_ABILITY}
var ability_eligible := true
var interacted_this_frame := false
var charge_gate: RefCounted
var charge_context := preload("res://game_core/combat/active_ability_fire_context.gd").new()
var _slot_keys := SlotKeys.new()

func _ready() -> void:
	super._ready()
	_setup_charge_runtime()

func _setup_charge_runtime() -> void:
	charge_gate = HoldRelease.new(_can_use_charge, _commit_released_charge)
	charge_gate.sequence_stopped.connect(_stop_diagnostic_timeline)
	if not charge_context.configure(attacker, charge_gate):
		push_error("蓄力诊断场景缺少实际攻击者或门控绑定。")
		set_process_input(false)
		return

func _input(event: InputEvent) -> void:
	if charge_gate != null and event is InputEventKey:
		_slot_keys.handle_key(event, _dispatch_slot_edge)

func _dispatch_slot_edge(index: int, pressed: bool) -> void:
	# 每次收到命令重新看当前装备，不缓存按下时的槽位技能。
	if equipped_slots.get(index, 0) != CHARGED_ABILITY:
		return
	if pressed:
		# 原 CharacterCommandExecutor 的同帧交互挡住 Fire，但不挡 StopFire。
		if not interacted_this_frame:
			charge_context.fire({"actor":attacker,"issuer_kind":1,"issuer_id":"local"}, null, null)
	else:
		charge_context.stop_fire()

func _can_use_charge() -> bool:
	# 模拟正式属性、状态、消耗绑定提供的资格断言；这不是这些拥有者的移植。
	return ability_eligible and not timeline.playing

func _commit_released_charge() -> bool:
	# 原 ActiveAbilityBase 出手前重新校验、提交，才进入 Timeline。
	return _can_use_charge() and begin_accepted_release()

func _stop_diagnostic_timeline() -> void:
	# 原 AbilitySpec.TryEnd/ALTimeline.OnEnd 会终止时间轴；不模拟其他 GAS 副作用。
	timeline.stop()

func _process(delta: float) -> void:
	super._process(delta)
	charge_gate.advance(delta)
	_label.text += "\n诊断配置：槽位 2（Q / 2）装配蓄力；按住蓄力、松开出手。"
	if charge_gate.is_charging():
		_label.text += " 正在蓄力"
