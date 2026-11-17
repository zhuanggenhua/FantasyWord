extends SceneTree
const Entry = preload("res://gameplay/clickmovetest/entry.gd")
const Points = preload("res://game_core/input/mouse_point_actions.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var entry := Entry.new()
	root.add_child(entry)
	entry.set_process(false)
	var panel := Control.new()
	root.add_child(panel)
	var previous := Control.new(); previous.focus_mode = Control.FOCUS_ALL; panel.add_child(previous)
	var button := Control.new(); button.focus_mode = Control.FOCUS_ALL; panel.add_child(button)
	var child := Control.new(); button.add_child(child)
	var overlay := Control.new(); panel.add_child(overlay)
	var behind := Control.new(); behind.focus_mode = Control.FOCUS_ALL; panel.add_child(behind)
	var inner := Control.new(); inner.focus_mode = Control.FOCUS_ALL; button.add_child(inner)
	var leaf := Control.new(); inner.add_child(leaf)
	var properties := {
		button: {"selectable":true,"active_and_enabled":true,"target_graphic_present":true,"target_raycast":true,"interactable":false},
		child: {"graphic_present":true,"raycast_target":true},
		overlay: {"graphic_present":true,"raycast_target":true},
		behind: {"selectable":true,"active_and_enabled":true},
		inner: {"selectable":true,"active_and_enabled":false},
		leaf: {"graphic_present":true,"raycast_target":false}
	}
	var hits: Array = [child]
	var over := [true]; var calls := [0,0]; var positions: Array = []
	check(entry.bind_ui_pointer_selection(properties,func():calls[0]+=1;return over[0],func(p):calls[1]+=1;positions.append(p);return hits),"绑定显式宿主")
	var points := Points.new(0)
	points.enable(Points.Map.GAMEPLAY)
	entry.bind_mouse_point_actions(points)
	previous.grab_focus()
	entry.update_ui_pointer_selection()
	check(root.gui_get_focus_owner()==previous and calls==[0,0],"UI Point 不活动时不查询宿主")
	var event := InputEventMouseMotion.new();event.position=Vector2(40,50);event.relative=Vector2(1,1);event.device=0
	root.push_input(event)
	entry.update_ui_pointer_selection()
	check(calls==[0,0],"Gameplay Point 不代替 UI Point")
	points.enable(Points.Map.UI)
	event.position=Vector2(41,52)
	root.push_input(event)
	over[0]=false
	entry.update_ui_pointer_selection()
	check(calls==[1,0] and root.gui_get_focus_owner()==previous,"先查 pointer-over，再决定是否射线")
	over[0]=true
	entry.update_ui_pointer_selection()
	check(root.gui_get_focus_owner()==button and entry.last_ui_selection=="selected","子图形优先选最近合格父级，早于图形遮挡")
	check(positions==[Vector2(41,52)],"射线读取 UI Point 而非 Gameplay 或全局鼠标")
	check(not properties[button].interactable and root.gui_get_focus_owner()==button,"源码没有交互性门禁")
	var focuses := [0]
	button.focus_entered.connect(func():focuses[0]+=1)
	entry.update_ui_pointer_selection()
	check(focuses[0]==0,"同一选中项不再次触发选中")
	hits.assign([overlay,behind]);entry.update_ui_pointer_selection()
	check(root.gui_get_focus_owner()==button and entry.last_ui_selection=="blocked","遮挡停止穿透且保留原焦点")
	properties[overlay].raycast_target=false
	entry.update_ui_pointer_selection()
	check(root.gui_get_focus_owner()==behind,"非射线图形继续后续命中")
	hits.assign([child,behind]);properties[button].target_raycast=false
	entry.update_ui_pointer_selection()
	check(entry.last_ui_selection=="blocked" and root.gui_get_focus_owner()==behind,"父级目标图形不可射线，转查当前命中图形遮挡")
	properties[button].target_graphic_present=false
	entry.update_ui_pointer_selection()
	check(root.gui_get_focus_owner()==button,"无 targetGraphic 仍可选")
	hits.assign([leaf,behind]);entry.update_ui_pointer_selection()
	check(root.gui_get_focus_owner()==behind,"最近停用 Selectable 不搜索更远合格祖先")
	hits.clear();entry.update_ui_pointer_selection()
	check(root.gui_get_focus_owner()==behind and entry.last_ui_selection=="unchanged","空命中不清焦点")
	hits.assign([child]);points.disable(Points.Map.UI);entry.update_ui_pointer_selection()
	check(root.gui_get_focus_owner()==behind and entry.last_ui_selection=="inactive_point","关闭 UI 图立即停止选择")
	points.enable(Points.Map.UI);entry.update_ui_pointer_selection()
	check(root.gui_get_focus_owner()==behind,"重新启用无初始 Point")
	event.position=Vector2.ZERO;root.push_input(event);entry.update_ui_pointer_selection()
	check(root.gui_get_focus_owner()==button and positions.back()==Vector2.ZERO,"零坐标活动 Point 有效")
	points.reset_device();behind.grab_focus();entry.update_ui_pointer_selection()
	check(root.gui_get_focus_owner()==behind,"设备重置不重用旧 Point")
	entry.unbind_ui_pointer_selection()
	event.position=Vector2(99,99);root.push_input(event);entry.update_ui_pointer_selection()
	check(root.gui_get_focus_owner()==behind and entry.last_ui_selection=="unbound","解绑退出，不新建替代宿主")
	entry.bind_ui_pointer_selection(properties,func():return true,func(_p):return [child])
	entry.set_process(true)
	await process_frame
	await process_frame
	check(root.gui_get_focus_owner()==button,"实际 _process 帧驱动选择")
	root.remove_child(entry)
	check(entry.last_ui_selection=="unbound","退出树释放 Viewport 与宿主引用")
	root.add_child(entry)
	entry.set_process(false)
	behind.grab_focus()
	entry.update_ui_pointer_selection()
	check(root.gui_get_focus_owner()==behind,"重新入树不复用原宿主")
	entry.bind_ui_pointer_selection(properties,func():points.disable(Points.Map.UI);return true,func(p):positions.append(p);return [])
	entry.update_ui_pointer_selection()
	check(positions.back()==Vector2(0,root.get_visible_rect().size.y),"pointer-over 期间禁用时按原顺序读取默认 Point")
	panel.free();entry.free()
	await process_frame
	print("PASS UI pointer selection: %d/%d" % [checks-failures,checks])
	quit(0 if failures==0 else 1)
