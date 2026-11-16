extends RefCounted
## Unity 31629d5 CharacterBase.PrepareFormalDamageHit / CharacterActor.TryPlayHitAnimation.
## This is the target-side prepare hook, not a second damage or health owner.
const Lifecycle = preload("res://game_core/combat/deferred_damage_lifecycle.gd")

var lifecycle: Lifecycle
var owner_identity: Variant
var last_effective_source: Variant
var formal_driver_assigned := false
var play_formal_damage: Callable
var play_legacy_damage: Callable
var report_formal_animation_error: Callable

func prepare(source: Variant, input: Dictionary) -> void:
	if source != null and not is_same(source, owner_identity):
		last_effective_source = source
	if input.silent:
		return
	# InterruptActions itself occurs only when the actor's safe phase drains this flag.
	lifecycle.on_prepare_damage(false)
	try_play_hit_animation()

func try_play_hit_animation() -> bool:
	if not formal_driver_assigned:
		return play_legacy_damage.is_valid() and bool(play_legacy_damage.call())
	if play_formal_damage.is_valid() and bool(play_formal_damage.call()):
		return true
	if report_formal_animation_error.is_valid():
		report_formal_animation_error.call()
	else:
		push_error("角色无法通过已绑定的正式动画驱动播放受击动作。")
	# The formal animation failure is reported, but it never invokes a legacy strategy
	# or aborts an otherwise applicable positive HP modifier in the calling executor.
	return false
