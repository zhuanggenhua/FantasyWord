extends RefCounted
## 原 Gameplay/UI Click 共用的配对左键。动作图切换时保留物理状态，
## 将未释放的一次按压留在旧动作图，而不是从新动作图补一次点击。
enum Edge { OTHER, HELD, PRESS, RELEASE }
var _device: int
var _held := false
var _blocked := false

func _init(device: int) -> void: _device=device

func observe(event: InputEvent) -> Edge:
	if not event is InputEventMouseButton or event.device!=_device or event.button_index!=MOUSE_BUTTON_LEFT:
		return Edge.OTHER
	if not event.pressed:
		var was_held:=_held
		reset_device_state()
		return Edge.RELEASE if was_held else Edge.HELD
	if _held: return Edge.HELD
	_held=true
	return Edge.PRESS

func arm_action_map() -> void: _blocked=_held

func is_blocked() -> bool: return _blocked

func reset_device_state() -> void:
	_held=false
	_blocked=false
