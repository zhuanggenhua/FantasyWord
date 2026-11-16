extends RefCounted
## 锁定 Unity 31629d5：只迁移实际精灵到装备帧坐标和缓存，不拥有动作、素材或材质。
signal refresh_requested
var frame_index := 0
var row_index := 0
var cached_frame: Variant = null
var last_sprite: Texture2D
var current_animation: Dictionary = {}
var _tables: Array = []

func configure_animation(animation: Dictionary) -> void:
	# 调用方先按源动作键和源回退规则解析数据；本层不能把缺失动作替成 Idle。
	current_animation = animation

func late_sync(texture: Texture2D) -> void:
	# 对应 LateUpdate：引用未变就不因图集区域被原地编辑而自动重采样。
	if texture != last_sprite:
		last_sprite = texture
		_sync_from_sprite()

func sync_current_sprite(texture: Texture2D) -> void:
	# 对应显式 SyncCurrentSpriteAndRefresh：空 Sprite 仍 Refresh，保留原坐标。
	if texture == null:
		refresh_requested.emit()
		return
	last_sprite = texture
	_sync_from_sprite()

func _sync_from_sprite() -> void:
	if last_sprite == null or current_animation.is_empty():
		return
	var frame_size: Vector2i = current_animation.frame_size
	if frame_size.x <= 0 or frame_size.y <= 0:
		return
	# 本适配器只接收实际区域明确的 AtlasTexture，不用标签或方向号猜区域。
	if not last_sprite is AtlasTexture:
		return
	var region: Rect2 = last_sprite.region
	# Unity 的底起 rect 经导入反转为 Godot 顶起区域，因此 row 为区域 y / frameH。
	frame_index = floori(region.position.x / float(frame_size.x))
	row_index = floori(region.position.y / float(frame_size.y))
	refresh_requested.emit()

func set_preview_direction(index: int, auto_refresh: bool = true) -> void:
	var clamped := clampi(index, 0, 3)
	if row_index == clamped:
		return
	row_index = clamped
	cached_frame = null
	if auto_refresh:
		refresh_requested.emit()

func refresh_frame() -> Variant:
	cached_frame = null
	if current_animation.is_empty():
		return null
	var table: Dictionary = {}
	for candidate in _tables:
		if is_same(candidate.animation, current_animation):
			table = candidate
			break
	if table.is_empty():
		table = {"animation":current_animation,"count":-1,"lookup":{}}
		_tables.append(table)
	var frames: Array = current_animation.frames
	# 源 AnimationData.EnsureFrameLookup 只按数量失效，不按内容版本失效。
	if table.count != frames.size():
		table.lookup.clear()
		for frame in frames:
			if frame == null:
				continue
			var key := Vector2i(int(frame.frame_index),int(frame.row_index))
			if not table.lookup.has(key):
				table.lookup[key] = frame
		table.count = frames.size()
	cached_frame = table.lookup.get(Vector2i(frame_index,row_index))
	return cached_frame
