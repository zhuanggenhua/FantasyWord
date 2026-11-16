extends RefCounted
## 只记录观察结果，不派发命令；延迟读回不代表该点击创建了新命令。
var latest: Dictionary = {}
var pending_frames := -1

func observe(snapshot: Dictionary) -> void:
	latest = snapshot.duplicate(true)
	pending_frames = 1

func advance(read_current: Callable) -> void:
	if pending_frames < 0: return
	if pending_frames > 0:
		pending_frames -= 1
		return
	var current: Dictionary = read_current.call()
	latest["order_after_updates"] = current.order
	latest["position_after_updates"] = current.position
	pending_frames = -1
