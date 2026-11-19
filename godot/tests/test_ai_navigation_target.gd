extends SceneTree
const Planner = preload("res://game_core/ai/ai_navigation_target.gd")
const State = preload("res://game_core/ai/ai_target_lifecycle.gd")
var n := 0
var faults := 0

func expect(ok: bool, label: String) -> void:
	n += 1
	if not ok:
		faults += 1
		printerr("FAIL ",label)

func _initialize() -> void:
	var plan := Planner.new()
	var state := State.new()
	state.path_invalidated.connect(plan.invalidate)
	state.target = {"visible":true}
	state.target_position = Vector2(10,0)
	var calls: Array = []
	var picked := func(origin, destination):
		calls.append([origin,destination])
		return PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2(4,0),destination])
	var selected := plan.select(state,Vector2.ZERO,picked)
	expect(selected.group=="transit" and selected.position==Vector2(1,0)
		and selected.arrival_stop==-1. and calls.size()==1,"路径含起点时在同一步跳过，途中 transit")
	expect(is_equal_approx(state.navigation_repath_timer,.5),"原重算计时器写入")
	var advanced := plan.select(state,Vector2(1,0),picked)
	expect(advanced.position==Vector2(4,0) and calls.size()==1,"不重建且光标连续前进")
	expect(plan.select(state,Vector2.ZERO,picked).position==Vector2(4,0),"不倒退到早先路径点")
	selected=plan.select(state,Vector2(4,0),picked)
	expect(selected.position==state.target_position and selected.group=="predictive-target"
		and selected.arrival_stop==1. and selected.final,"最后路径点保留，使用目标追击组")
	state.target_position.x += .499
	plan.select(state,Vector2.ZERO,picked)
	expect(calls.size()==1,"未及 .5 不重建")
	state.target_position.x = 10.5
	plan.select(state,Vector2.ZERO,picked)
	expect(calls.size()==2,"等于 .5 即重建")
	state.update_cooldowns(.5)
	plan.select(state,Vector2.ZERO,picked)
	expect(calls.size()==3,"定时器归零后重建，即使目标静止")
	plan.select(state,Vector2(8,0),picked)
	expect(plan.select(state,Vector2(8,0),picked).group=="combat-wander"
		and plan.select(state,Vector2(10,0),picked).group=="combat-wander" and calls.size()==3,
		"战斗游走在最终接近之前，即便处于近身")
	state.stop_chase(3.)
	state.target_position=Vector2(10,0)
	expect(plan.select(state,Vector2(9,0),picked).group=="default" and calls.size()==3,"无目标近距离归位用原默认组")
	selected=plan.select(state,Vector2.ZERO,picked)
	expect(calls.size()==4 and selected.position==Vector2(1,0),"StopChase 清光标重新开始")
	state.update_cooldowns(.5)
	var unavailable := func(a,b):
		calls.append([a,b])
		return null
	selected=plan.select(state,Vector2.ZERO,unavailable)
	expect(not selected.active and not selected.has("position") and is_equal_approx(state.navigation_repath_timer,.5),
		"存在地图但失败不发布位置，保留本次重算时间")
	expect(not plan.select(state,Vector2.ZERO,unavailable).active and calls.size()==6,"空路径下步原样重新尝试")
	state.target={"visible":true}
	selected=plan.select(state,Vector2.ZERO,Callable())
	expect(selected.active and selected.group=="default" and selected.position==state.target_position
		and state.navigation_repath_timer==0.,"原无活动地图分支不冒充有图但失败")
	if faults==0: print("PASS source trainer navigation target: %d checks" % n)
	quit(0 if faults==0 else 1)
