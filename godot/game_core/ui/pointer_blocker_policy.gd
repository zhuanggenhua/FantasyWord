extends RefCounted
## UIPointerUtility 的命中后策略。输入为已由宿主枚举的原源元数据，不执行射线查询。
## canvas_groups 是 includeInactive:false 返回的近到远顺序；不按 enabled 再过滤。
static func is_blocking(hit: Dictionary, ignored_name: Variant = "Mask") -> bool:
	if not hit.object_present or hit.name == ignored_name: return false
	for group in hit.canvas_groups:
		if not group.blocks_raycasts: return false
		if group.ignore_parent_groups: break
	return not hit.graphic_present or hit.raycast_target

static func is_over_ui(hits: Array, event_system_present: bool, ignored_name: Variant = "Mask") -> bool:
	if not event_system_present: return false
	for hit in hits:
		if is_blocking(hit, ignored_name): return true
	return false
