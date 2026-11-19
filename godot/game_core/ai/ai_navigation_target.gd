extends RefCounted
## 31629d53 的 CharacterSteeringPathCursor2D + TryResolveSteeringTarget。
## 输入是地图当前可用的原默认层实际路径，不生成转向、速度或位移。
const Lifecycle = preload("res://game_core/ai/ai_target_lifecycle.gd")
const CombatWander = preload("res://game_core/ai/combat_wander_intent.gd")
const TRANSIT := "transit"
const PREDICTIVE := "predictive-target"
const WANDER := "combat-wander"
const DEFAULT := "default"
const REPATH_INTERVAL := 0.5
const DESTINATION_THRESHOLD := 0.5
const WAYPOINT_TOLERANCE := 0.3499999940395355 # max(源 .2, AgentRadius .35, .3)
const FINAL_APPROACH := 1.350000023841858
const WANDER_RANGE := CombatWander.CLICK_MOVE_TEST_WANDER_RANGE

var _path := PackedVector2Array()
var _cursor := 0
var _planned := false
var _destination := Vector2.ZERO

func invalidate() -> void:
	_path.clear()
	_cursor = 0
	_planned = false
	_destination = Vector2.ZERO

func _destination_moved(destination: Vector2) -> bool:
	return not _planned or (destination-_destination).length_squared() 		>= Lifecycle.f32(DESTINATION_THRESHOLD*DESTINATION_THRESHOLD)

## 不偷换“地图存在但无有效路径”和“没有活动寻路地图”。
func select(state: Lifecycle, origin: Vector2, build_world_path: Callable) -> Dictionary:
	var destination := state.target_position
	var has_enemy := not state.target.is_empty()
	var distance := origin.distance_to(destination)
	var final_group := PREDICTIVE if has_enemy else DEFAULT
	if CombatWander.should_use(true,has_enemy,distance,WANDER_RANGE):
		return {"active":true,"position":destination,"group":WANDER,"final":true,"arrival_stop":-1.0,"mode":"wander"}
	if distance <= FINAL_APPROACH:
		return {"active":true,"position":destination,"group":final_group,"final":true,"arrival_stop":1.0,"mode":"approach"}
	if not build_world_path.is_valid():
		invalidate()
		state.navigation_repath_timer = 0.0
		# 原 TryResolve 无地图返回默认组，不偷换成追击组。
		return {"active":true,"position":destination,"group":DEFAULT,"final":true,"arrival_stop":1.0,"mode":"no_map"}
	if _path.is_empty() or _destination_moved(destination) or state.navigation_repath_timer <= 0.0:
		state.navigation_repath_timer = REPATH_INTERVAL
		var path: Variant = build_world_path.call(origin,destination)
		if not path is PackedVector2Array or path.is_empty():
			invalidate()
			return {"active":false,"mode":"no_path"}
		_path = path
		_cursor = 0
		_destination = destination
		_planned = true
	while _cursor < _path.size()-1 and origin.distance_to(_path[_cursor]) <= WAYPOINT_TOLERANCE:
		_cursor += 1
	var final := _cursor == _path.size()-1
	return {"active":true,"position":_path[_cursor],"group":final_group if final else TRANSIT,
		"final":final,"arrival_stop":1.0 if final else -1.0,"mode":"route"}
