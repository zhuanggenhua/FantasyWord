extends RefCounted
## InputSystem.Update 的命中后选择逻辑；宿主必须提供原顺序命中和原组件属性。
## 不猜测 Canvas 排序、GraphicRaycaster、设备状态或默认菜单。
var components: Dictionary
var viewport: Viewport

func _init(target_viewport: Viewport, authored_components: Dictionary) -> void:
	viewport = target_viewport
	components = authored_components

func apply_hits(ordered_hits: Array) -> String:
	for hit in ordered_hits:
		if not is_instance_valid(hit) or not hit is Control: return "unsupported_hit"
		var candidate: Node = hit
		# 对应 GetComponentInParent：最近的 Selectable 即使停用，也不换找更远祖先。
		while candidate != null and not components.get(candidate,{}).get("selectable",false):
			candidate = candidate.get_parent()
		if candidate != null:
			var source: Dictionary = components[candidate]
			if source.get("active_and_enabled",false) and (not source.get("target_graphic_present",false) or source.get("target_raycast",false)):
				# 原源码没有 IsInteractable 门禁。无法承载原选中项的原生控件不冒充成功。
				if not candidate is Control or not candidate.is_inside_tree() or not candidate.is_visible_in_tree() or candidate.get_viewport() != viewport or candidate.focus_mode == Control.FOCUS_NONE:
					return "unsupported_selection"
				if viewport.gui_get_focus_owner() != candidate: candidate.grab_focus()
				return "selected" if viewport.gui_get_focus_owner() == candidate else "unsupported_selection"
		var graphic: Dictionary = components.get(hit,{})
		if graphic.get("graphic_present",false) and graphic.get("raycast_target",false):
			return "blocked"
	# 源码没有清空旧选中项，空命中、无合格项和遮挡都保留焦点。
	return "unchanged"
