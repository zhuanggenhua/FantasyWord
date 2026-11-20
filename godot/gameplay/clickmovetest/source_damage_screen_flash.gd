extends ColorRect
## 原 ClickMoveTest 2110012300：只显示当前控制角色（或主角回退）的已结算伤害。
const Combat := preload("res://game_core/combat/combat_rules.gd")
const NORMAL := Color(0.8,0.15,0.15,0.18)
const CRITICAL := Color(1,1,1,0.30)
const DURATION := 0.15
const NO_SCREEN_FLASH := 1 << 2

var _active := false
var _start := NORMAL
var _elapsed := 0.0
var _clock: Callable
var _last_tick := 0.0
var _frame_delta := 0.0


func _ready() -> void:
	# 每次渲染更新先采样，再由 Entry 的正式伤害回调读取同帧非缩放步长。
	process_priority = -1
	# 原闪屏使用 unscaledDeltaTime；菜单暂停玩法时仍完成淡出。
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not _clock.is_valid():
		_clock = func(): return Time.get_ticks_usec() / 1000000.0
	_last_tick = _clock.call()
	reset_flash()


func present(target: Node2D, controlled_or_primary: Node2D, input: Dictionary) -> bool:
	if not is_visible_in_tree() or not is_instance_valid(controlled_or_primary) or target != controlled_or_primary:
		return false
	var flags: int = input.flags
	if (flags & Combat.MISS) != 0 or input.silent or (int(input.get("visual_flags",0)) & NO_SCREEN_FLASH) != 0:
		return false
	_start = CRITICAL if (flags & Combat.CRITICAL) != 0 else NORMAL
	_elapsed = 0.0
	_active = true
	# Unity 的协程在第一次 yield 前用当帧非缩放步长前进一次。
	_advance(_frame_delta)
	return true


func _process(_delta: float) -> void:
	var now: float = _clock.call()
	_frame_delta = maxf(0.0,now - _last_tick)
	_last_tick = now
	if _active:
		_advance(_frame_delta)


func _advance(unscaled_delta: float) -> void:
	_elapsed += unscaled_delta
	if _elapsed >= DURATION:
		reset_flash()
		return
	color = Color(_start,_start.a * (1.0 - _elapsed / DURATION))


func reset_flash() -> void:
	_active = false
	color = Color(NORMAL,0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		reset_flash()
