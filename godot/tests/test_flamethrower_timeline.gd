extends SceneTree
const Timeline = preload("res://gameplay/combat/flamethrower_timeline.gd")
var failures := 0
var checks := 0
var timeline: RefCounted
var hits: Array = []
var surfaces: Array = []
var ordering: Array = []
var pose := Vector2.RIGHT
class Driver extends Node:
	var events: Array = []
	func try_play_animation(key: String) -> bool:
		events.append(key)
		return true
	func try_restore_default_animation(key: String) -> bool:
		events.append("remove:"+key)
		return true
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var driver := Driver.new()
	root.add_child(driver)
	timeline = Timeline.new(func(): hits.append([timeline.frame,pose]); ordering.append("hit"),
		func(): surfaces.append([timeline.frame,pose]); ordering.append("surface"),driver)
	var spray_events: Array[String] = []
	check(timeline.bind_spray_cues(func():spray_events.append("start"),func():spray_events.append("remove")),
		"原喷流与音频请求只绑定一次")
	timeline.play()
	timeline.advance(0)
	check(hits.is_empty() and surfaces.is_empty(),"第零帧不命中也不施加元素")
	timeline.advance(.02)
	check(hits==[[1,Vector2.RIGHT]] and surfaces==[[1,Vector2.RIGHT]],"第一帧只提交一次，不重复Begin与Tick")
	check(ordering==["surface","hit"],"同帧地表先于角色命中")
	check(driver.events.is_empty() and spray_events.is_empty(),"逻辑阶段不提前激活Cue")
	check(timeline.flush_display() and driver.events==["Attack"],"显示阶段消费Attack")
	timeline.flush_display()
	check(driver.events==["Attack"] and spray_events==["start"],"同一个Cue不重复播放")
	pose=Vector2.UP
	timeline.advance(.05)
	check(surfaces.back()==[4,Vector2.UP],"后续提交读取当前朝向而非起手快照")
	timeline.advance(1.1)
	var hit_frames: Array=[]
	var surface_frames: Array=[]
	for row in hits: hit_frames.append(row[0])
	for row in surfaces: surface_frames.append(row[0])
	check(hit_frames==[1,10,20,30,40,50,60],"原七个命中片段含第60帧")
	check(surface_frames==Array(range(1,60,3)),"地表恰好20次，不延长到61帧")
	check(not timeline.playing and driver.events==["Attack","remove:Attack"] and spray_events==["start","remove"],"自然结束且60帧移除Cue")
	timeline.advance(10)
	check(hits.size()==7 and surfaces.size()==20,"结束后不补执行")
	timeline.play()
	timeline.advance(.02)
	timeline.flush_display()
	timeline.stop()
	var counts := [hits.size(),surfaces.size()]
	timeline.advance(1)
	check(counts==[hits.size(),surfaces.size()] and driver.events.back()=="remove:Attack","中断停止未来任务并清理Cue")
	driver.events.clear()
	spray_events.clear()
	timeline.play()
	timeline.advance(2)
	check(timeline.flush_display() and driver.events.is_empty() and spray_events.is_empty(),"同一更新跨过整个窗口不补播已删除Cue")
	check(Timeline.EFFECT_ID==2003 and Timeline.HIT_MASK==128 and Timeline.ATTACK_POLYGON.size()==6,"正式效果与六点查询合同")
	driver.free()
	print("喷火时间轴：%s/%s" % [checks-failures,checks])
	quit(1 if failures else 0)
