extends RefCounted
## CharacterBase 的属性变更后安全阶段，不负责完整 ECS、尸体、掉落和表现。
var pending_interrupt := false
var pending_death := false

func on_prepare_damage(silent: bool) -> void:
	if not silent:
		pending_interrupt = true

func on_current_health_changed(previous_health: int, current_health: int) -> void:
	# CharacterBase.StateApi.DidReachZeroHealth：不对加载为零或重复值重复入队。
	if previous_health > 0 and current_health == 0:
		pending_death = true

func tick_safe_interrupt(is_destroyed: Callable, interrupt_actions: Callable) -> void:
	if pending_interrupt and not is_destroyed.call():
		pending_interrupt = false
		interrupt_actions.call()

func tick_safe(current_health: Callable, is_destroyed: Callable,
		interrupt_actions: Callable, mark_death: Callable) -> void:
	# 原 Update / AdvanceCharacterRuntime 先处理行动打断，后重读死亡资格。
	tick_safe_interrupt(is_destroyed,interrupt_actions)
	if pending_death and not is_destroyed.call() and current_health.call() == 0:
		pending_death = false
		mark_death.call()
