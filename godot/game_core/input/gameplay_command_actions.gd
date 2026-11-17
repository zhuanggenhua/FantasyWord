extends RefCounted
## 对应 31629d5 的 InputSystem.cs 回调。接收归一化 Gameplay 动作阶段，
## 不处理原始设备事件；动作图启用、配对和释放门禁属于正式宿主。
const Commands = preload("res://game_core/interaction/character_command_executor.gd")
const FIRE_ACTIONS := ["FireAbility1", "FireAbility2", "FireAbility3", "FireAbility4", "FireAbility5"]
var _resolve: Callable
var _submit: Callable
var _blocked: Callable
var _failed: Callable

func configure(resolve_context: Callable, submit: Callable, interact_blocked: Callable, notify_failed: Callable) -> bool:
	if not resolve_context.is_valid() or not submit.is_valid() or not interact_blocked.is_valid() or not notify_failed.is_valid(): return false
	_resolve = resolve_context; _submit = submit; _blocked = interact_blocked; _failed = notify_failed
	return true

## null 表示没有对应回调或被门禁阻止；整数表示实际命令结果。
## 解析器在没有输入目标时返回 null，否则返回 {actor, command_context}。
## 宿主必须解析当次输入目标，不得使用缓存的选中角色。
func receive(action_map: String, action: String, phase: String) -> Variant:
	if not _resolve.is_valid() or action_map != "Gameplay": return null
	var kind: int
	var slot := FIRE_ACTIONS.find(action)
	if action == "Interact":
		if phase != "performed" or bool(_blocked.call()): return null
		kind = Commands.Kind.INTERACT
	elif slot >= 0 and phase in ["performed", "canceled"]:
		kind = Commands.Kind.FIRE_ABILITY if phase == "performed" else Commands.Kind.STOP_FIRE_ABILITY
	else: return null
	var resolved: Variant = _resolve.call()
	var request := {"kind":kind,"ability_index":slot,"direction":Vector2.ZERO,
		"world_position":null,"target_character":null,"interaction_target":null,
		"actor":null,"command_context":{"actor":null,"issuer_kind":1,"issuer_id":"local"}}
	var result := Commands.Failure.MISSING_INPUT_TARGET
	if resolved != null:
		request.actor = resolved.actor
		request.command_context = resolved.command_context
		result = int(_submit.call(request))
	if result != Commands.Failure.NONE: _failed.call(request,result)
	return result
