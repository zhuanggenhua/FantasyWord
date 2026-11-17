extends "res://validation/scenes/ability_slot_fixture.gd"
## 单20004原生请求更新诊断；不声明正式存档默认装配，不接入其他技能。
const Spec = preload("res://gameplay/combat/charged_timeline_spec.gd")
@export var automatic_spec_update := true
var charge_spec := Spec.new()

func _setup_charge_runtime() -> void:
	if not charge_spec.configure(attacker,timeline) or not charge_context.configure_timeline_rules(charge_spec,20004):
		push_error("单技能诊断缺少实际角色、Timeline或正式出手编排绑定。")
		set_process_input(false);return
	charge_gate=HoldRelease.new(_can_use_charge,_perform_release)
	if not charge_context.configure(attacker,charge_gate):
		push_error("单技能诊断无法绑定唯一输入门控。")
		set_process_input(false)

func _start_diagnostic_after_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	# 继承诊断命令也必须走真实输入门控和请求更新，不调用父类直接播放入口。
	charge_context.fire({"actor":attacker,"issuer_kind":3,"issuer_id":"diagnostic"},null,null)
	charge_context.stop_fire()

func _perform_release() -> bool:
	return charge_context.perform_timeline_use()

func _can_use_charge() -> bool:
	return charge_spec.validate_fire_point(20004).result==0

func _process(delta: float) -> void:
	if automatic_spec_update: charge_spec.process_update()
	var was_playing: bool=timeline.playing
	super._process(delta)
	# 原 ALTimelinePlayer.OnPlayEnd 在非ManualEnd配置下投递TryEndSelf。
	# 当前20004的36帧已有命中时钟没有独立信号，观察同一实例自然结束边界。
	if was_playing and not timeline.playing and charge_spec.active:
		charge_spec.request_end(20004)
	_label.text += "\n单技能延迟激活诊断：3003标签与后续请求更新，非完整GAS。"
