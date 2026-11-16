extends SceneTree
const Observation = preload("res://gameplay/clickmovetest/click_observation.gd")
const Policy = preload("res://game_core/ui/pointer_blocker_policy.gd")
var reads := 0
func _initialize() -> void:
	var trace := Observation.new()
	var read := func():
		reads += 1
		return {"order": true, "position": Vector2(2, 3)}
	trace.advance(read)
	assert(reads == 0)
	trace.observe({"screen_position": Vector2.ONE})
	trace.advance(read)
	assert(reads == 0 and trace.pending_frames == 0)
	trace.observe({"screen_position": Vector2(5, 6)})
	trace.advance(read)
	assert(reads == 0)
	trace.advance(read)
	assert(reads == 1 and trace.latest.screen_position == Vector2(5, 6))
	assert(trace.latest.order_after_updates and trace.latest.position_after_updates == Vector2(2, 3))
	trace.advance(read)
	assert(reads == 1)
	var hit := {"object_present": true, "name": "Mask", "canvas_groups": [], "graphic_present": true, "raycast_target": true}
	assert(not Policy.is_blocking(hit))
	assert(Policy.is_blocking(hit, null))
	hit.name = "mask"
	assert(Policy.is_blocking(hit))
	hit.object_present = false
	assert(not Policy.is_blocking(hit))
	hit.object_present = true
	hit.canvas_groups = [{"blocks_raycasts": false, "ignore_parent_groups": true}]
	assert(not Policy.is_blocking(hit))
	var lower := hit.duplicate(true)
	lower.canvas_groups = []
	assert(Policy.is_over_ui([hit, lower], true), "上层穿透不隐藏另一个下层阻挡")
	assert(not Policy.is_over_ui([lower], false))
	hit.canvas_groups = [{"blocks_raycasts": true, "ignore_parent_groups": true}, {"blocks_raycasts": false, "ignore_parent_groups": false}]
	assert(Policy.is_blocking(hit))
	hit.canvas_groups[0].ignore_parent_groups = false
	assert(not Policy.is_blocking(hit))
	hit.canvas_groups = [{"blocks_raycasts": false, "ignore_parent_groups": false, "enabled": false}]
	assert(not Policy.is_blocking(hit), "已枚举组不因组件 enabled=false 被跳过")
	hit.canvas_groups = []
	hit.raycast_target = false
	assert(not Policy.is_blocking(hit))
	hit.graphic_present = false
	assert(Policy.is_blocking(hit))
	print("PASS 点击观察两次更新、最新覆盖、实际读回与原源 UI 命中策略")
	quit(0)
