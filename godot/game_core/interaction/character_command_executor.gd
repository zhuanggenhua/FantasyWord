extends RefCounted
## CharacterCommandExecutor (31629d5): routing, not input ownership or GAS.
const Movement = preload("res://game_core/movement/movement_commands.gd")
enum Kind { INTERACT, OPEN_GAME_MENU, MOVE, STOP_MOVE, CLICK_MOVE, TOGGLE_MOVEMENT_CONTROL_MODE, FIRE_ABILITY, STOP_FIRE_ABILITY }
enum Failure { NONE, INVALID_COMMAND, MISSING_INPUT_TARGET, INVALID_CONTROLLED_CHARACTER, INVALID_TARGET, ACTOR_MISMATCH, NOT_RUNNING, CONTROL_LOCKED, INTERACTION_LOCKED, BLOCKED_BY_STATE, MISSING_ABILITY, ABILITY_REJECTED }
var character: Object
var enabled := true
var interaction: RefCounted
var movement: RefCounted
var terrain_map: RefCounted
var _fire: Callable
var _stop: Callable
var _activation_context: Callable
var _notify_rejected: Callable

## Explicit formal ability owner boundary. No eligibility/GAS result is fabricated here.
## fire(index, original command_context, activation_context) returns the source result fields:
## has_ability_source, result (Valid=0), formal_gas_ability_code.
func bind_abilities(fire: Callable, stop: Callable, activation_context: Callable, notify_rejected: Callable) -> bool:
	if not fire.is_valid() or not stop.is_valid() or not activation_context.is_valid() or not notify_rejected.is_valid(): return false
	_fire = fire; _stop = stop; _activation_context = activation_context; _notify_rejected = notify_rejected
	return true

func execute(request: Dictionary) -> int:
	if not is_instance_valid(character): return Failure.INVALID_CONTROLLED_CHARACTER
	if not enabled: return Failure.NOT_RUNNING
	# actor is the resolved projection of GameCommandContext.Actor, never another owner.
	# Dictionary contexts may carry actor directly; opaque contexts must be projected by host.
	var requested_actor: Object = request.get("actor")
	var context: Variant = request.get("command_context")
	if context is Dictionary and context.has("actor"):
		if is_instance_valid(requested_actor) and requested_actor != context.actor: return Failure.ACTOR_MISMATCH
		requested_actor = context.actor
	if is_instance_valid(requested_actor) and requested_actor != character: return Failure.ACTOR_MISMATCH
	match request.get("kind", -1):
		Kind.INTERACT:
			# Explicit targets bypass resolver selection, never this outer action gate.
			if interaction == null or not character.can_interact(): return Failure.INTERACTION_LOCKED
			return Failure.NONE if interaction.try_interact(request.get("interaction_target")) else Failure.BLOCKED_BY_STATE
		Kind.FIRE_ABILITY:
			if interaction != null and interaction.interacted_this_frame: return Failure.BLOCKED_BY_STATE
			# Unbound formal host is an unsupported slice, not a fabricated MissingAbility result.
			if not _fire.is_valid(): return Failure.INVALID_COMMAND
			var result: Dictionary = _fire.call(request.get("ability_index",-1), request.get("command_context"), _activation_context.call(request))
			if not result.has_ability_source: return Failure.MISSING_ABILITY
			if result.result != 0:
				_notify_rejected.call(result.formal_gas_ability_code,result.result)
				return Failure.ABILITY_REJECTED
			return Failure.NONE
		Kind.STOP_FIRE_ABILITY:
			if not _stop.is_valid(): return Failure.INVALID_COMMAND
			return Failure.NONE if _stop.call(request.get("ability_index",-1)) else Failure.MISSING_ABILITY
		Kind.MOVE, Kind.STOP_MOVE, Kind.CLICK_MOVE, Kind.TOGGLE_MOVEMENT_CONTROL_MODE:
			return Movement.execute(request.kind,request.get("direction",Vector2.ZERO),request.get("world_position"),character,true,requested_actor,movement,terrain_map)
		_:
			return Failure.INVALID_COMMAND
