extends RefCounted
## 锁定 31629d5 EquipmentRenderer 的动作数据选择、精灵坐标与 Refresh 连接。
## 只接已解析的实际动作键。原材质、槽位、武器、头部表现仍由调用方拥有。
const Cursor = preload("res://game_core/presentation/equipment_frame_cursor.gd")
const Refresh = preload("res://game_core/presentation/equipment_refresh_order.gd")
const BODY_FALLBACKS := {
	"Wait":["Idle"],
	"Die":["SoulDie","SpinDie","Idle"],
	"SoulDie":["SpinDie","Die","Idle"],
	"SpinDie":["Die","SoulDie","Idle"],
}
var cursor := Cursor.new()
var frame_data: Variant = null # 已授权的帧数据，按源动作键索引，null 表示没有资源。
var action_key := ""
var original_sprite_direct := false
var hooks: Dictionary = {}
var configs: Array = []
var slots: Dictionary = {}

func _init() -> void:
	cursor.refresh_requested.connect(refresh)

func late_sync(actual_key: String, sprite: Texture2D) -> void:
	if original_sprite_direct:
		hooks.apply_original_material.call()
		return
	if frame_data != null:
		apply_animation_key(actual_key)
	cursor.late_sync(sprite)

func sync_current_sprite(actual_key: String, sprite: Texture2D) -> void:
	# 原显式入口在空 Sprite 时直接 Refresh，不从 Animator 重读动作。
	if sprite != null and frame_data != null:
		apply_animation_key(actual_key)
	cursor.sync_current_sprite(sprite)

func set_preview_direction(index: int, auto_refresh: bool = true) -> void:
	cursor.set_preview_direction(index, auto_refresh)

func apply_animation_key(requested_key: String) -> void:
	if requested_key.strip_edges().is_empty() or frame_data == null:
		return
	var next: Dictionary = resolve_body_data(frame_data, requested_key)
	var should_apply := requested_key != action_key or (not next.is_empty() and not is_same(next, cursor.current_animation))
	if not should_apply:
		return
	action_key = requested_key
	cursor.configure_animation(next)
	# ApplyAnimationKey 先分别写 UV；Refresh 在缺正式帧或一张 UV 时一起清除。
	hooks.bind_uv_maps.call(next.get("body_uv"), next.get("head_uv"))

func refresh() -> void:
	# Direct / no data branches historically bypass frame resolution.
	var frame: Variant = null
	if not original_sprite_direct and frame_data != null:
		if cursor.current_animation.is_empty():
			cursor.configure_animation(resolve_body_data(frame_data, action_key))
		frame = cursor.refresh_frame()
	var data: Dictionary = cursor.current_animation
	Refresh.refresh(original_sprite_direct, frame_data != null, action_key, frame,
		data.get("body_uv"), data.get("head_uv"), configs, slots, hooks)

static func resolve_body_data(animations: Dictionary, key: String) -> Dictionary:
	if key.is_empty():
		return {}
	var exact: Dictionary = animations.get(key, {})
	if not exact.is_empty():
		return exact
	for alternate in BODY_FALLBACKS.get(key, []):
		var body: Dictionary = animations.get(alternate, {})
		if not body.is_empty():
			return body
	return {}
