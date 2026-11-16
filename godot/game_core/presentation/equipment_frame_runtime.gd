extends RefCounted
## 锁定 31629d5 EquipmentRenderer 的动作数据选择、精灵坐标与 Refresh 连接。
## 支持已解析动作键及源动作 owner 的显式采样。原材质、槽位、武器、头部表现仍由调用方拥有。
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

# Animator 描述由调用方提供，顺序必须保留源 parameters 顺序；不是 body 数据键集合。
var animation_context_override_key := ""
var animator_present := false
var animator_parameters: Array = [] # {name:String,type:"bool"}；其它类型不参与
var animator_bool_values: Dictionary = {}
var animation_database_keys: Array = [] # AnimationTypeDatabase 的非空条目 name
var _valid_anim_params: Array = []
var _anim_params_cached := false
var _next_sample_sync_pending := false

# 显式传入调用方当前动作和 Sprite；不接管 Animator、坐骑时钟或动作真相。
func set_animation_context_override(animation_key: Variant, code_key: String, sprite: Texture2D, auto_refresh: bool = true) -> void:
	assert(animation_key == null or animation_key is String, "动作覆盖仅接受 String 或 null")
	var normalized := "" if animation_key == null else _trim_dotnet_whitespace(animation_key)
	if animation_context_override_key == normalized:
		return
	animation_context_override_key = normalized
	sync_animation_owner(code_key)
	if auto_refresh:
		sync_current_sprite_from_owner(code_key, sprite)

func clear_animation_context_override(code_key: String, sprite: Texture2D, auto_refresh: bool = true) -> void:
	if animation_context_override_key.is_empty():
		return
	animation_context_override_key = ""
	sync_animation_owner(code_key)
	if auto_refresh:
		sync_current_sprite_from_owner(code_key, sprite)

static func _trim_dotnet_whitespace(value: String) -> String:
	# 源 string.Trim 使用 Char.IsWhiteSpace；不能用 strip_edges 的 ASCII 控制字符范围代替。
	var start := 0
	var end := value.length()
	while start < end and _is_dotnet_whitespace(value.unicode_at(start)):
		start += 1
	while end > start and _is_dotnet_whitespace(value.unicode_at(end - 1)):
		end -= 1
	return value.substr(start, end - start)

static func _is_dotnet_whitespace(codepoint: int) -> bool:
	return (codepoint >= 0x09 and codepoint <= 0x0d) or codepoint in [0x20, 0x85, 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000] or (codepoint >= 0x2000 and codepoint <= 0x200a)

func invalidate_animation_owner_cache() -> void:
	# 对应源 SetFrameData 清空参数缓存；不代替完整帧数据切换/刷新职责。
	_valid_anim_params.clear()
	_anim_params_cached = false

func sync_animation_owner(code_key: String) -> void:
	if frame_data == null:
		return
	if not _trim_dotnet_whitespace(animation_context_override_key).is_empty():
		apply_animation_key(animation_context_override_key)
		return
	if not _trim_dotnet_whitespace(code_key).is_empty():
		apply_animation_key(code_key)
		return
	if not animator_present:
		return
	if not _anim_params_cached:
		for parameter in animator_parameters:
			if parameter.get("type") == "bool" and parameter.get("name") in animation_database_keys:
				_valid_anim_params.append(parameter.name)
		_anim_params_cached = true
	for key in _valid_anim_params:
		if animator_bool_values.get(key, false):
			apply_animation_key(key)
			return
	apply_animation_key("Idle")

func late_sync_from_owner(code_key: String, sprite: Texture2D) -> void:
	if original_sprite_direct:
		hooks.apply_original_material.call()
		return
	sync_animation_owner(code_key)
	cursor.late_sync(sprite)

func sync_current_sprite_from_owner(code_key: String, sprite: Texture2D) -> void:
	# 原显式入口在直显模式也会读动作；空 Sprite 则先 Refresh，不读动作。
	if sprite != null:
		sync_animation_owner(code_key)
	cursor.sync_current_sprite(sprite)

func request_sync_after_next_sample(active_and_enabled: bool) -> bool:
	# RefCounted 不拥有 Animator 时钟；调用方在下一帧完成采样后消费一次。
	# 重复请求替代未执行请求，不排多个刷新；禁用时拒绝新增请求。
	if not active_and_enabled:
		return false
	_next_sample_sync_pending = true
	return true

func sync_after_next_sample(code_key: String, sprite: Texture2D) -> bool:
	if not _next_sample_sync_pending:
		return false
	sync_current_sprite_from_owner(code_key, sprite)
	_next_sample_sync_pending = false
	return true

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
	if _trim_dotnet_whitespace(requested_key).is_empty() or frame_data == null:
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
