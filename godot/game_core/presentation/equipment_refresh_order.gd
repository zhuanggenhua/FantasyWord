extends RefCounted
## Locked Unity 31629d5 EquipmentRenderer.Refresh, binding order only.
## Caller owns real material, active action/frame, ordered config and equipped slots.
enum RenderMode { NONE, SPRITE, COLOR, WEAPON }

static func refresh(original_sprite_direct: bool, has_frame_data: bool,
		action_key: String, frame: Variant, body_uv: Texture2D, head_uv: Texture2D,
		configs: Array, slots: Dictionary, hooks: Dictionary) -> void:
	if original_sprite_direct:
		hooks.reset_layers.call()
		hooks.disable_generated_weapon_renderers.call()
		hooks.apply_original_material.call()
		return
	if not has_frame_data:
		hooks.warn_missing_frame_data.call()
		hooks.reset_layers.call()
		return

	# Frame absent includes unresolved action data; both UV maps are required.
	if frame == null or body_uv == null or head_uv == null:
		hooks.reset_layers.call()
		hooks.bind_uv_maps.call(null, null)
		hooks.render_weapons.call()
		_apply_slots(configs, slots, action_key, true, hooks)
		return

	hooks.update_shadow_height.call(frame)
	hooks.reset_layers.call()
	hooks.bind_uv_maps.call(body_uv, head_uv)
	hooks.set_hit_outline.call(bool(frame.hit_outline_frame))
	hooks.update_body_depth.call(frame)
	hooks.render_weapons.call()
	hooks.apply_appearance.call()
	_apply_slots(configs, slots, action_key, false, hooks)

static func _apply_slots(configs: Array, slots: Dictionary, action_key: String,
		sequence_only: bool, hooks: Dictionary) -> void:
	for config: Dictionary in configs:
		var mode: int = config.mode
		if mode == RenderMode.NONE or mode == RenderMode.WEAPON:
			continue
		var equipment: Variant = slots.get(config.type)
		if equipment == null:
			continue
		match mode:
			RenderMode.SPRITE:
				if not sequence_only or bool(hooks.has_sequence.call(equipment, action_key)):
					hooks.apply_sprite.call(equipment, config)
			RenderMode.COLOR:
				if not sequence_only:
					hooks.apply_color.call(equipment, config)
