extends RefCounted
## 锁定 Unity CuePlayGameCoreAnimator 的运行期回调，不拥有 Timeline 或 ECS 调度。
## 调用者必须传入本 Cue 所属 ASC 的真实角色驱动；不能用目标或别的角色代替。
var _driver: WeakRef
var active_animation_key := ""
var last_error := ""

func on_add(owner_driver: Node) -> void:
	_driver = weakref(owner_driver) if is_instance_valid(owner_driver) else null
	active_animation_key = ""
	last_error = ""

func on_activate(animation_key: String) -> bool:
	var key := animation_key.strip_edges()
	if key.is_empty(): return true
	var driver = _driver.get_ref() if _driver != null else null
	if is_instance_valid(driver) and driver.has_method("try_play_animation") and driver.try_play_animation(key):
		active_animation_key = key
		return true
	last_error = "Cue 所属角色驱动或动作缺失：" + key
	return false

func on_remove() -> bool:
	var driver = _driver.get_ref() if _driver != null else null
	var restored := true
	if is_instance_valid(driver) and not active_animation_key.is_empty():
		restored = driver.has_method("try_restore_default_animation") and driver.try_restore_default_animation(active_animation_key)
		if not restored: last_error = "Cue 无法恢复原所属角色动作：" + active_animation_key
	active_animation_key = ""
	_driver = null
	return restored
