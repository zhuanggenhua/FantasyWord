extends Node2D
## 31629d5 FlamethrowerCueVisual + 喷火-火焰表现 prefab 的原序列。
## 只接受私下提供的锁定原图，不生成替代火焰；不拥有玩法或音频。
## Default/order20 映射为局部 z20；Unity 默认 Sprite 材质/跨层排序仍待画面对照。
const ORIGINAL_SHA256 := "7d1ae4bc6e63000bb3f7d5060dda9e9f43189def0436d28484cdb14d2e60023e"
const FRAMES_PER_SECOND := 14.0
const FRAME_COUNT := 8
const PIXELS_PER_UNIT := 8.0
var sprite: Sprite2D
var last_error := ""
var _owner: Object
var _time := 0.0
var _frame := -1
var _mounted := false

func configure(original_png_path: String) -> bool:
	last_error = ""
	if is_instance_valid(sprite):
		last_error = "原图已配置，不覆盖现有序列。"
		return false
	if not FileAccess.file_exists(original_png_path) or FileAccess.get_sha256(original_png_path) != ORIGINAL_SHA256:
		last_error = "缺少锁定的原喷火序列 PNG，或内容摘要不符。"
		return false
	var original := Image.load_from_file(original_png_path)
	if original == null or original.get_size() != Vector2i(256,16):
		last_error = "原喷火序列尺寸不符。"
		return false
	sprite = Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(original)
	sprite.hframes = FRAME_COUNT
	sprite.centered = false
	sprite.offset = Vector2(0,-8)
	sprite.position = Vector2(.35,0)
	sprite.scale = Vector2.ONE / PIXELS_PER_UNIT
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	sprite.z_index = 20
	sprite.visible = false
	add_child(sprite)
	return true

func mount(direction_owner: Object) -> bool:
	unmount()
	if not is_instance_valid(sprite) or not is_instance_valid(direction_owner) or not direction_owner.has_method("get_target_direction") or not direction_owner.has_signal("target_direction_changed"):
		last_error = "缺少原图或正式目标朝向拥有者。"
		return false
	_owner = direction_owner
	_owner.connect("target_direction_changed", _apply_direction)
	_mounted = true
	sprite.visible = true
	_apply_direction(_owner.get_target_direction())
	_set_frame(0)
	# Instantiate/OnEnable 后 CueMountPrefab.ApplyTransform 再写入局部 identity。
	# 保留源顺序，不擅自用当前方向修正首帧；该 Unity 顺序仍待运行画面对照。
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	return true

func advance(delta: float) -> void:
	if not _mounted or not is_instance_valid(sprite) or not is_finite(delta) or delta < 0.0:
		return
	_time = _f32(_time + _f32(delta))
	_set_frame(int(floor(_f32(_time * FRAMES_PER_SECOND))) % FRAME_COUNT)

func unmount() -> void:
	if is_instance_valid(_owner) and _owner.is_connected("target_direction_changed", _apply_direction):
		_owner.disconnect("target_direction_changed", _apply_direction)
	_owner = null
	_mounted = false
	if is_instance_valid(sprite): sprite.visible = false

func current_frame() -> int: return _frame
func animation_time() -> float: return _time

func _apply_direction(direction: Vector2) -> void:
	if direction.length_squared() <= _f32(.0001): return
	# 项目世界位置采用 Godot y 向下；宿主正式方向仍是 Unity y 向上。
	rotation = -atan2(direction.y, direction.x)

func _set_frame(frame: int) -> void:
	if frame == _frame: return
	_frame = frame
	sprite.frame = frame

func _exit_tree() -> void: unmount()
func _f32(value: float) -> float: return PackedFloat32Array([value])[0]
