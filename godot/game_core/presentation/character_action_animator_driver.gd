extends Node
## Source: CharacterActionAnimatorDriver.cs at Unity 31629d5.
## Caller supplies the migrated action database and real AnimationPlayer clips.
## No placeholder animation is created when a state is unavailable.

signal animation_selected(key: String)

const FALLBACK_DAMAGE_RESTORE_DELAY := 0.35
const MINIMUM_AUTO_RESTORE_DELAY := 0.05
var animator: AnimationPlayer
var action_keys: Array[String] = []
var default_animation_key := "Idle"
var movement_animation_key := "Walk"
var damage_animation_key := "Dmg"
var current_animation_key := ""
var runtime_enabled := true
var game_time := 0.0
var pending_key := ""
var pending_fallback_key := ""
var pending_time := 0.0
var locked_key := ""
var is_moving := false

func _process(delta: float) -> void:
	# Godot process delta observes Engine.time_scale; paused nodes do not tick.
	advance_game_time(delta)

func advance_game_time(delta: float) -> void:
	game_time += delta
	if pending_key.is_empty() or game_time < pending_time:
		return
	if current_animation_key == pending_key:
		try_restore_animation(pending_key, pending_fallback_key)
	cancel_pending_restore()

func locomotion_key() -> String:
	return (movement_animation_key if is_moving else default_animation_key).strip_edges()

func set_movement(movement: Vector2) -> void:
	is_moving = movement.length_squared() > 0.0001
	var key := locomotion_key()
	if not pending_key.is_empty():
		pending_fallback_key = key
	if not locked_key.is_empty() or current_animation_key == key:
		return
	if not current_animation_key.is_empty() and current_animation_key not in [default_animation_key.strip_edges(), movement_animation_key.strip_edges()]:
		return
	_try_apply_animation(key)

func resolve_playable_state(key: String) -> String:
	if not is_instance_valid(animator) or key.is_empty() or key not in action_keys:
		return ""
	if animator.has_animation(key):
		return key
	var full_path := "Base Layer." + key
	return full_path if animator.has_animation(full_path) else ""

func _try_apply_animation(key: String) -> bool:
	var state := resolve_playable_state(key)
	if state.is_empty():
		return false
	# Source SetAnimation returns without changes when blocked by a lock.
	if not locked_key.is_empty() and key != locked_key:
		return true
	current_animation_key = key
	cancel_pending_restore()
	animation_selected.emit(key)
	animator.play(state)
	# play() alone may resume an already playing same-key animation.
	animator.seek(0.0, true)
	animator.advance(0.0)
	return true

func try_play_animation(key: String) -> bool:
	key = key.strip_edges()
	if not locked_key.is_empty() and key != locked_key:
		return true
	if not _try_apply_animation(key):
		return false
	if runtime_enabled and not damage_animation_key.strip_edges().is_empty() and key == damage_animation_key.strip_edges():
		pending_key = key
		# Source initially chooses Idle, not current locomotion; SetMovement updates it.
		pending_fallback_key = default_animation_key.strip_edges()
		pending_time = game_time + resolve_current_animation_duration_seconds()
	return true

func try_play_damage_animation() -> bool:
	return try_play_animation(damage_animation_key)

func try_restore_animation(expected: String, fallback: String) -> bool:
	if not locked_key.is_empty() or current_animation_key != expected.strip_edges():
		return true
	return _try_apply_animation(fallback.strip_edges())

## 原 TryRestoreDefaultAnimation 使用当前移动状态，不是固定 Idle。
func try_restore_default_animation(expected: String) -> bool:
	return try_restore_animation(expected, locomotion_key())

func try_lock_animation(key: String) -> bool:
	key = key.strip_edges()
	if not _try_apply_animation(key):
		return false
	cancel_pending_restore()
	locked_key = key
	return true

func clear_animation_lock() -> void:
	locked_key = ""

func cancel_pending_restore() -> void:
	pending_key = ""
	pending_fallback_key = ""
	pending_time = 0.0

func resolve_current_animation_duration_seconds() -> float:
	if not is_instance_valid(animator) or animator.assigned_animation.is_empty():
		return FALLBACK_DAMAGE_RESTORE_DELAY
	var clip := animator.get_animation(animator.assigned_animation)
	return validated_duration(clip.length if clip != null else NAN)

static func validated_duration(length: float) -> float:
	if is_nan(length) or is_inf(length) or length < MINIMUM_AUTO_RESTORE_DELAY:
		return FALLBACK_DAMAGE_RESTORE_DELAY
	return length
