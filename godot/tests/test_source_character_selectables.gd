extends SceneTree
const Selectables := preload("res://gameplay/clickmovetest/source_character_selectables.gd")
const ActorState := preload("res://game_core/ui/source_character_panel_state.gd")
var count := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	count+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func _initialize() -> void:
	var dir := OS.get_environment("FORMAL_PAUSE_SOURCE")
	if dir.is_empty():
		print("SKIP Character selectables need the private source layout contract")
		quit(0)
		return
	var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("character-layout.json")))
	if not layout is Dictionary:
		printerr("FAIL Character layout is required")
		quit(1)
		return
	var state := ActorState.new()
	var actor := Node.new()
	root.add_child(actor)
	check(state.bind(func(_target): return {"display_name":"玩家角色配置","level":1,
		"experience":0,"next_level_experience":0,"available_points":0,"base_stats":[100,40,10,6,6,4,8,4]},
		func(): return 0) and state.show(actor),"bind actual zero-point case")
	var view := Selectables.new()
	check(view.bind(layout,state) and not view.focus_default(),"no focus before UI stack activation")
	view.set_active(true)
	check(view.focus_default() and view.selected_action()==1 and view.visual(1)=="selected",
		"first row decrease is default at zero points")
	var restore := state.visible_data()
	check(not view.activate(1) and state.visible_data()==restore and view.selected_action()==1,
		"minus remains selected but does not change state")
	check(view.move(Vector2i.RIGHT) and view.selected_action()==2 and not view.activate(2)
		and state.visible_data()==restore,"plus receives navigation but does not change state")
	check(view.move(Vector2i.RIGHT) and view.selected_action()==17
		and not view.move(Vector2i.RIGHT) and not view.move(Vector2i.DOWN),"plus goes to Apply, with no wrap right/down")
	check(view.move(Vector2i.LEFT) and view.selected_action()==14,
		"Apply goes left to the closest Agility plus, not the last row")
	check(view.move(Vector2i.RIGHT) and view.selected_action()==17 and view.move(Vector2i.UP)
		and view.selected_action()==2, "Apply up returns to Health plus by edge-to-center score")
	check(view.move(Vector2i.LEFT) and view.selected_action()==1 and not view.move(Vector2i.UP),
		"row pair returns to Health decrease without wrap")
	var apply_point := Vector2(1400,750)
	check(view.hit(apply_point)==17,"Apply image is the real hit target")
	view.pointer_down(17)
	check(view.visual(17)=="pressed" and view.pointer_release(0)==0
		and view.selected_action()==17 and view.visual(17)=="selected",
		"outside release cancels capture only")
	view.pointer_down(17)
	var action := view.pointer_release(view.hit(apply_point))
	check(action==17 and not view.activate(action) and state.visible_data()==restore,
		"matching Apply release gives ordinary feedback and no-op at zero points")
	var directions := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
	for start in range(1,18):
		var expected: Array[int] = []
		if start==17:
			expected.assign([14,17,2,17])
		else:
			expected.assign([start if start%2==1 else start-1, start+1 if start%2==1 else 17,
				start if start<=2 else start-2, start if start>=15 else start+2])
		for i in range(directions.size()):
			view.sample_point(0,start,true)
			var moved := view.move(directions[i])
			check(view.selected_action()==expected[i] and moved==(start!=expected[i]),
				"source automatic focus edge %d/%s: %d"%[start,str(directions[i]),expected[i]])
	view.set_active(false)
	check(view.hit(apply_point)==0 and view.selected_action()==0,"hide clears hit and focus")
	view.set_active(true)
	check(view.focus_default() and view.selected_action()==1,"reopen restores Health Decrease")
	actor.free()
	print("%s UICharacter selectables: %d/%d" % ["PASS" if failures==0 else "FAIL",count-failures,count])
	quit(1 if failures else 0)
