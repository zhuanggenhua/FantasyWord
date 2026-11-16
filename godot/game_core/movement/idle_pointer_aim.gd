extends RefCounted
## Source 31629d5 CharacterMovement probe and the eligible target-update portion
## of CharacterPlayerControl.Update. The host still owns local-control selection.
const ScreenProjection = preload("res://game_core/presentation/orthographic_screen_projection.gd")
var actor: Object
var target_owner: Object
var direction_pivot: Node2D
var enabled := false

func configure(body: Object, owner: Object, pivot: Node2D, source_enabled: bool) -> bool:
	if actor != null or not is_instance_valid(body) or not is_instance_valid(owner):
		return false
	if not body.has_method("has_active_movement_intent") or not body.has_method("get_movement_position"):
		return false
	for method in ["can_update_target_direction","set_target_direction","reset_target_direction"]:
		if not owner.has_method(method): return false
	if pivot != null and (not is_instance_valid(pivot) or not pivot.is_inside_tree()):
		return false
	actor = body
	target_owner = owner
	direction_pivot = pivot
	enabled = source_enabled
	return true

func try_update(camera: Camera2D, pointer_screen: Vector2, pointer_active: bool) -> bool:
	if not is_instance_valid(actor) or not is_instance_valid(target_owner) or not enabled \
			or actor.has_active_movement_intent() or not pointer_active:
		return false
	var world: Variant = ScreenProjection.project(camera,pointer_screen)
	if not world is Vector2: return false
	var pivot: Vector2 = actor.get_movement_position()
	if is_instance_valid(direction_pivot):
		var position := direction_pivot.global_position
		pivot = Vector2(position.x,-position.y)
	var direction: Vector2 = world-pivot
	if direction.length_squared() <= PackedFloat32Array([0.0001])[0]: return false
	target_owner.set_target_direction(direction.normalized())
	return true

## Invoke only after source local-control/capability gates and target refresh.
## A forbidden update must preserve the old override, not reset it.
func update_eligible(camera: Camera2D, pointer_screen: Vector2, pointer_active: bool) -> void:
	if not is_instance_valid(target_owner) or not target_owner.can_update_target_direction():
		return
	if not try_update(camera,pointer_screen,pointer_active):
		target_owner.reset_target_direction()
