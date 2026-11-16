extends RefCounted
## Movable.TryPush 只决定是否发出推力申请，不负责位移或扣血。
const Combat = preload("res://game_core/combat/combat_rules.gd")
enum Mode { DEFAULT, DISABLED, OVERRIDE }

# config 键：regular / critical / missed / silent。
# request 在 DEFAULT 只接 direction，保留 NativeMotionBody 的默认 5/10；
# OVERRIDE 另传从效果读取的强度、阻力。返回值表示申请已发出，不保证位移。
static func try_push(damage_input: Dictionary, source_is_target: bool,
		velocity: Vector2, mode: int, config: Dictionary, request: Callable,
		override_intensity: float = 0.0, override_resistance: float = 0.0) -> bool:
	var flags: int = damage_input.flags
	if mode == Mode.DISABLED or source_is_target 			or (damage_input.silent and not config.silent) 			or (flags == 0 and not config.regular) 			or ((flags & Combat.CRITICAL) != 0 and not config.critical) 			or ((flags & Combat.MISS) != 0 and not config.missed):
		return false
	# Unity Vector2.normalized 保留 1e-5 阈值；零方向也可发出源申请。
	var magnitude: float = velocity.length()
	var direction := velocity / magnitude if magnitude > 0.00001 else Vector2.ZERO
	if mode == Mode.OVERRIDE:
		request.call(direction, maxf(0.0, override_intensity), maxf(0.0, override_resistance))
	else:
		request.call(direction)
	return true
