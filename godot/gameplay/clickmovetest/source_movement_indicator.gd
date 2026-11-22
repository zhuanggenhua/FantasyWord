extends Node2D
## 31629d5 0_CharacterActor_Base → Polydirectional Pivot / Movement Indicator.
## 只读取正式目标方向和门控，不拥有目标、移动命令或 Static Pivot。
const ATLAS_SHA256 := "2db1269537f02431a2f433ecca936d72840962f8b8b765e44405839c1dcdc612"
const ATLAS_SIZE := Vector2i(152,112)
# SPS_GUI_19（1866868515）：Unity 图集底部起算 y=16，转成顶部起算 y=112-16-8。
const CROP := Rect2i(112,88,8,8)
const AUTHORED_ALPHA := .4509804
const TRANSITION_SPEED := 20.0
const PIVOT_OFFSET := Vector2(0,-.4)
var _owner: WeakRef
var _sprite: Sprite2D
var _last_tick_usec := 0

func bind(owner: Object,atlas_path: String) -> bool:
	if is_instance_valid(_sprite) or not is_instance_valid(owner) \
			or not owner.has_signal("target_direction_changed") \
			or not owner.has_method("get_target_direction") or not owner.has_method("can_update_target_direction") \
			or not FileAccess.file_exists(atlas_path) or FileAccess.get_sha256(atlas_path)!=ATLAS_SHA256:
		return false
	var original := Image.load_from_file(atlas_path)
	if original==null or original.get_size()!=ATLAS_SIZE:
		return false
	name="Polydirectional Pivot"
	process_mode=Node.PROCESS_MODE_ALWAYS
	_sprite=Sprite2D.new()
	_sprite.name="Movement Indicator"
	_sprite.texture=ImageTexture.create_from_image(original.get_region(CROP))
	_sprite.centered=true
	_sprite.position=Vector2(.682,0)
	_sprite.scale=Vector2.ONE/16.0
	_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	_sprite.z_index=0
	_sprite.self_modulate=Color(1,1,1,AUTHORED_ALPHA)
	add_child(_sprite)
	_owner=weakref(owner)
	owner.connect("target_direction_changed",_apply_direction)
	_apply_direction(owner.get_target_direction())
	_last_tick_usec=Time.get_ticks_usec()
	return true

func _apply_direction(direction: Vector2) -> void:
	# 原 NegativeScale 在 X=0 时也用 -1。Unity Y 向上，Godot 世界 Y 向下。
	# 直接写二维基，避免把 X 反射拆成 Y 反射加半圈旋转。
	var flip := 1.0 if direction.x>0.0 else -1.0
	var signed := -atan2(flip*direction.y,flip*direction.x) if direction!=Vector2.ZERO else 0.0
	var x_basis := Vector2.from_angle(signed)*flip
	var y_basis := Vector2.from_angle(signed+PI/2.0)
	transform=Transform2D(x_basis,y_basis,PIVOT_OFFSET)

func _process(_scaled_delta: float) -> void:
	var owner: Object = _owner.get_ref() if _owner!=null else null
	if not is_instance_valid(owner): return
	# 原 Time.unscaledDeltaTime 在 Time.timeScale=0 时仍然推进。
	var tick := Time.get_ticks_usec()
	var weight := clampf((tick-_last_tick_usec)*.000001*TRANSITION_SPEED,0.0,1.0)
	_last_tick_usec=tick
	var alpha := AUTHORED_ALPHA if owner.can_update_target_direction() else 0.0
	_sprite.self_modulate.a=lerpf(_sprite.self_modulate.a,alpha,weight)

func _exit_tree() -> void:
	var owner: Object = _owner.get_ref() if _owner!=null else null
	if is_instance_valid(owner) and owner.is_connected("target_direction_changed",_apply_direction):
		owner.disconnect("target_direction_changed",_apply_direction)
