extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Inventory := preload("res://gameplay/clickmovetest/source_inventory_view.gd")
const Pause := preload("res://gameplay/clickmovetest/source_pause_focus_view.gd")
const Point := preload("res://game_core/input/mouse_point_actions.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if ok: return
	failures+=1
	printerr("FAIL ",label)
func key(code: Key, on: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code; event.pressed=on
	root.push_input(event,true)
func tap(code: Key) -> void:
	key(code,true); key(code,false)
func button(code: MouseButton, on: bool, p: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.device=0; event.button_index=code; event.pressed=on; event.position=p
	root.push_input(event,true)
func move(p: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.device=0; event.position=p; event.relative=Vector2.ONE
	root.push_input(event,true)
func finish() -> void:
	print("%s ClickMoveTest fresh Inventory: %d/%d"%["PASS" if failures==0 else "FAIL",checks-failures,checks])
	quit(1 if failures else 0)

func run() -> void:
	var dir := OS.get_environment("FORMAL_PAUSE_SOURCE")
	if dir.is_empty():
		print("SKIP live inventory source graphics require private locked contracts.")
		finish()
		return
	root.size=Vector2i(960,540)
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"regular F5 entry")
	await scene_changed
	await process_frame
	var startup := current_scene as Boot
	check(startup!=null and startup.pause_root!=null,"normal startup opens exact source-owner path")
	if startup==null or startup.pause_root==null: finish(); return
	var shell := startup.pause_root
	var actor: Node = startup.scene.actor
	var owner := startup.primary_bag_owner(actor)
	var neutral := Vector2(470,245)
	move(neutral);button(MOUSE_BUTTON_LEFT,true,neutral);button(MOUSE_BUTTON_LEFT,false,neutral)
	tap(KEY_ESCAPE)
	var menu := shell.stack.top() as Pause
	check(menu!=null and paused,"original Pause opens")
	if menu==null: finish(); return
	var items := Vector2(40,190)
	move(items)
	await process_frame
	await process_frame
	check(menu.selected_action()==1,"regular pointer finds authored Items entry")
	tap(KEY_ENTER)
	var panel := shell.stack.top() as Inventory
	check(panel!=null and shell.stack.depth()==2 and not menu.visible,"action 1 / registration 3 mounts Inventory on existing stack")
	if panel==null: finish(); return
	check(panel.model.category==0 and panel.selected_action()==1 and panel.model.cell(0).is_empty(),
		"fresh Consumable, focus on first empty slot, no fabricated starter items")
	check(panel.action_rect(1)==Rect2(968.5,340,96,96) and panel.action_rect(30)==Rect2(1488.5,756,96,96)
		and panel.cursor_rect()==Rect2(960.5,332,112,112),"6x5 original grid and cursor extents")
	check(panel.action_rect(31)==Rect2(864.5,340,96,96) and panel.action_rect(33)==Rect2(864.5,548,96,96)
		and startup.player.inventory_fresh_stats(actor)==[100,40,10,6,6,4,8,4],"original equip geometry and live eight stat values")
	tap(KEY_ENTER)
	check(startup.inventory_bags.entries(owner).is_empty(),"empty submit does not perform item use")
	tap(KEY_UP)
	check(panel.selected_action()==36 and panel.model.category==0 and not panel.cursor_rect().has_area(),
		"auto navigation from first grid button enters category but cursor not installed there")
	tap(KEY_RIGHT)
	check(panel.selected_action()==37 and panel.model.category==0,"category focus does not change active category")
	tap(KEY_ENTER)
	check(panel.model.category==1,"explicit submit changes actual projection")
	tap(KEY_DOWN)
	check(panel.selected_action()==3 and panel.model.selected==2,"category down uses uGUI rect-edge score to source grid")
	var cat_centre := panel.action_rect(38).get_center()*.5
	move(cat_centre)
	await process_frame
	await process_frame
	check(panel.selected_action()==3 and panel.model.category==1,"category hover never selects or changes category")
	button(MOUSE_BUTTON_LEFT,true,cat_centre);button(MOUSE_BUTTON_LEFT,false,neutral)
	check(panel.selected_action()==38 and panel.model.category==1,"pointer down focuses; release outside doesn't activate")
	button(MOUSE_BUTTON_LEFT,true,cat_centre);button(MOUSE_BUTTON_LEFT,false,cat_centre)
	check(panel.model.category==2 and panel.selected_action()==38,"matching source button release changes category")
	check(panel.reference_hit(Vector2(1112,282))==37,"later sibling wins in overlapping category strip")
	move(panel.action_rect(2).get_center()*.5)
	await process_frame
	await process_frame
	check(panel.selected_action()==2 and panel.model.selected==1,"real bag moves focus on pointer enter without click")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var pixels := root.get_texture().get_image()
		check(pixels.get_pixel(176,184).is_equal_approx(Color.WHITE)
			and pixels.get_pixel(481,143).is_equal_approx(Color.WHITE),"native source null-term icon quads are present")
		check(dark_count(pixels,Rect2i(370,52,220,58))>160,"native original title glyphs render")
		var spear := Rect2i(444,182,24,24)
		var cloth := Rect2i(444,286,24,24)
		check(source_colour(pixels,spear,[Color("#564379"),Color("#aeaeae")])
			and source_colour(pixels,cloth,[Color("#6a8bb7"),Color("#51659d"),Color("#394080")]),
			"native actual gear sprites painted in dedicated slots")
	if FileAccess.file_exists(dir.path_join("item-details-layout.json")):
		await exercise_details(shell,panel)
	else:
		print("SKIP Item Details needs the private locked overlay contract.")
	move(neutral);tap(KEY_ESCAPE)
	check(shell.stack.top()==menu and menu.selected_action()==1 and paused,"Back restores same Pause Items focus")
	if shell.item_details!=null: check(not shell.item_details.visible,"Back closes the shared overlay")
	tap(KEY_ENTER)
	var reopened := shell.stack.top() as Inventory
	check(reopened!=null and reopened!=panel and reopened.model.category==0 and reopened.selected_action()==1,
		"reopen resets source default and rereads real owner")
	button(MOUSE_BUTTON_RIGHT,true,neutral);button(MOUSE_BUTTON_RIGHT,false,neutral)
	check(shell.stack.top()==menu and menu.selected_action()==1,"Right-button Back does not change parent focus")
	tap(KEY_ESCAPE)
	check(shell.stack.depth()==0 and not paused and Engine.time_scale==1.0
		and actor.execution.has_move_order() and startup.point.read_active(Point.Map.UI)==null,
		"last pop restores gameplay input and existing movement")
	finish()

func dark_count(pixels: Image, rect: Rect2i) -> int:
	var n := 0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var c := pixels.get_pixel(x,y)
			if c.r<.37 and c.g<.28 and c.b<.32: n+=1
	return n

func source_colour(pixels: Image, rect: Rect2i, colors: Array) -> bool:
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var c := pixels.get_pixel(x,y)
			for expected: Color in colors:
				if Vector3(c.r,c.g,c.b).distance_to(Vector3(expected.r,expected.g,expected.b))<.025: return true
	return false

func exercise_details(shell: CanvasLayer,panel: Inventory) -> void:
	var details: Control=shell.item_details
	check(details!=null and details.get_parent()==shell and details.get_index()>shell.stack.get_index(),
		"shared overlay renders after Menus, not inside Inventory")
	if details==null: return
	check(not details.visible,"empty bag focus never opens details")
	var weapon := panel.action_rect(31).get_center()*.5
	move(weapon)
	await process_frame
	await process_frame
	check(details.visible and details.shown_type==0 and panel.selected_action()==31,"pointer enters real weapon")
	check(details._title._line.text.is_empty() and
		details._description._line.text==details._items[0].description and
		absf(details._description._line.width-636.6316)<.01,"source title overflows vertically; exact spear description fits")
	var spec: Dictionary = details._definition.name
	var measured: Dictionary = details.Text.layout(details._atlas,details._items[0].name,Rect2(801,863,368,56),spec)
	check(measured.text==details._items[0].name and absf(measured.width-60.6316)<.01,
		"actual name is present and measured; only the locked 50-unit Ellipsis rect suppresses it")
	check(details._icon.size==Vector2(50,50) and details._icon.position==Vector2(743.5,863.5)
		and details._icon._texture==details._items[0].texture,"source header icon independent of inventory sprite size")
	check(details.intercepts_point(Vector2(480,430)) and not details.intercepts_point(Vector2(350,430)),
		"only graphics raycast; details listener doesn't fill the window")
	button(MOUSE_BUTTON_LEFT,true,Vector2(480,450));button(MOUSE_BUTTON_LEFT,false,Vector2(480,450))
	check(details.visible and panel.selected_action()==31,"clicking nonselectable overlay leaves focus")
	move(panel.action_rect(36).get_center()*.5)
	await process_frame
	await process_frame
	check(details.visible and panel.selected_action()==31,"off-slot and category hover do not deselect")
	tap(KEY_DOWN)
	check(panel.selected_action()==32 and not details.visible and details.shown_type==-1,
		"keyboard deselect and empty equipment publish close")
	tap(KEY_DOWN)
	check(panel.selected_action()==33 and details.visible and details.shown_type==2 and
		details._title._line.text.is_empty() and details._description._line.text==details._items[2].description
		and absf(details._description._line.width-257.6842)<.01 and details._icon._texture==details._items[2].texture,
		"keyboard focuses actual torso and replaces all details")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var pixels := root.get_texture().get_image()
		check(source_colour(pixels,Rect2i(372,432,25,24),[Color("#6a8bb7"),Color("#51659d"),Color("#394080")])
			and not source_colour(pixels,Rect2i(445,437,96,16),[Color(1,.73973227,0,1)])
			and source_colour(pixels,Rect2i(412,471,137,18),[Color.WHITE]),"native cloth and white description; no invented gold text in clipped name")
	root.size=Vector2i(880,540)
	await process_frame
	await process_frame
	check(details.visible and details.position.is_equal_approx(Vector2(-40,0))
		and details.intercepts_point(Vector2(440,430)) and not details.intercepts_point(Vector2(310,430)),
		"height-matched overlay remains bottom-centred when window narrows")
	root.size=Vector2i(960,540)
	await process_frame
	await process_frame
	var category := panel.action_rect(36).get_center()*.5
	button(MOUSE_BUTTON_LEFT,true,category);button(MOUSE_BUTTON_LEFT,false,category)
	check(panel.selected_action()==36 and not details.visible,"actual category focus closes overlay")
	move(panel.action_rect(33).get_center()*.5)
	await process_frame
	await process_frame
	check(details.visible,"reselect opens before Back")
