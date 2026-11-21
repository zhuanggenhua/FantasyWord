extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Character := preload("res://gameplay/clickmovetest/source_character_view.gd")
const Pause := preload("res://gameplay/clickmovetest/source_pause_focus_view.gd")
const Point := preload("res://game_core/input/mouse_point_actions.gd")
var count := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	count+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)
func key(k: Key, on: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=k
	event.pressed=on
	root.push_input(event,true)
func button(b: MouseButton, on: bool, p: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.device=0
	event.button_index=b
	event.pressed=on
	event.position=p
	root.push_input(event,true)
func move(p: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.device=0
	event.position=p
	event.relative=Vector2.ONE
	root.push_input(event,true)
func tap(k: Key) -> void:
	key(k,true)
	if k in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		await process_frame
		await process_frame
	key(k,false)
	if k!=KEY_ESCAPE:
		await process_frame
		await process_frame

func finish() -> void:
	print("%s ClickMoveTest Character normal entry: %d/%d"%["PASS" if failures==0 else "FAIL",count-failures,count])
	quit(1 if failures else 0)

func run() -> void:
	var dir := OS.get_environment("FORMAL_PAUSE_SOURCE")
	if dir.is_empty():
		print("SKIP Character requires pinned private source files")
		finish()
		return
	root.size=Vector2i(960,540)
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"normal F5 scene")
	await scene_changed
	await process_frame
	var startup := current_scene as Boot
	check(startup!=null and startup.pause_root!=null,"startup loads original Pause plus Character admission")
	if startup==null or startup.pause_root==null:
		finish()
		return
	var shell := startup.pause_root
	var neutral := Vector2(460,255)
	move(neutral)
	button(MOUSE_BUTTON_LEFT,true,neutral); button(MOUSE_BUTTON_LEFT,false,neutral)
	var actor = startup.scene.actor
	var ordered: bool = actor.execution.has_move_order()
	check(ordered,"normal gameplay Point dispatch before opening")
	await tap(KEY_ESCAPE)
	var menu := shell.stack.top() as Pause
	check(menu!=null and menu.selected_action()==0 and paused,"Pause opens without invented default")
	if menu==null:
		finish()
		return
	await tap(KEY_ENTER)
	check(shell.stack.top()==menu,"blank focus cannot submit a Character request")
	var original := Vector2(40,150)
	move(original)
	await process_frame
	await process_frame
	check(menu.selected_action()==5,"real source Point chooses Character icon")
	key(KEY_ENTER,true)
	await process_frame
	await process_frame
	var panel := shell.stack.top() as Character
	check(panel!=null and not menu.visible and shell.stack.depth()==2 and paused,"pause action 5 mounts real registered Character")
	if panel==null:
		finish()
		return
	var state := panel.character_data()
	check(state.class=="玩家角色配置" and state.level=="1" and state.experience=="0" and state.skill_points=="0"
		and state.currency=="0" and state.rows==["100","40","10","6","6","4","8","4"] and state.apply=="应用 0 点",
		"live original primary actor and inventory owner, eight runtime attributes")
	check(panel.selected_action()==1 and panel.button_visual(1)=="selected","zero points still focuses Health decrease")
	key(KEY_F,true);key(KEY_F,false);key(KEY_ENTER,false)
	check(panel.character_data()==state,"held submit alias cannot chain into child")
	move(neutral)
	await tap(KEY_RIGHT);await tap(KEY_RIGHT)
	check(panel.selected_action()==17,"keyboard traverses row pair to Apply")
	await tap(KEY_LEFT)
	check(panel.selected_action()==14,"Apply left moves to Agility plus")
	await tap(KEY_RIGHT);await tap(KEY_UP)
	check(panel.selected_action()==2,"Apply up moves to Health plus")
	await tap(KEY_ENTER)
	await tap(KEY_LEFT);await tap(KEY_ENTER)
	check(panel.character_data()==state and panel.selected_action()==1,
		"zero-point keyboard minus and plus mutate neither state nor focus eligibility")
	var apply_at := Vector2(693.75,378.5)
	var outside := Vector2(700,465)
	button(MOUSE_BUTTON_LEFT,true,apply_at)
	check(panel.selected_action()==17 and panel.button_visual(17)=="pressed"
		and panel._apply._state=="pressed","real matching Apply hit and source pressed art")
	button(MOUSE_BUTTON_LEFT,false,outside)
	check(panel.character_data()==state and panel.button_visual(17)=="selected","outside release cancels, selection stays")
	button(MOUSE_BUTTON_LEFT,true,apply_at);button(MOUSE_BUTTON_LEFT,false,apply_at)
	check(panel.character_data()==state and panel._apply._state=="selected",
		"matching Apply click leaves zero budget unchanged")
	if DisplayServer.get_name()!="headless":
		var health_at := Vector2(347.75,174.5)
		button(MOUSE_BUTTON_LEFT,true,health_at); button(MOUSE_BUTTON_LEFT,false,health_at)
		await create_timer(.15,true,false,true).timeout
		await RenderingServer.frame_post_draw
		var pixels := root.get_texture().get_image()
		check(dark_pixels(pixels,Rect2i(370,50,220,62))>200
			and dark_pixels(pixels,Rect2i(370,116,220,25))<45,"native centered top title appears over source tiles")
		var icon := pixels.get_pixel(166,175)
		var arrow := dark_pixels(pixels,Rect2i(324,159,46,32))
		check(icon.is_equal_approx(Color.WHITE) and arrow>3,
			"source null sprite white and selected arrow pixels (%s, %d)"%[str(icon),arrow])
		check(dark_pixels(pixels,Rect2i(644,355,105,45))>45,"source Apply mixed live text drawn over sprite")
	root.size=Vector2i(1200,540)
	await process_frame
	await process_frame
	if root.get_visible_rect().size==Vector2(1200,540):
		check(panel._background.size.is_equal_approx(Vector2(2400,1080))
			and panel._background.patches(panel._background.size).size()>240
			and panel.reference_hit(panel.viewport_to_design(apply_at+Vector2(120,0)))==17,
			"wide Match Height canvas genuinely tiled and centered controls")
	var previous_panel_id := panel.get_instance_id()
	move(Vector2(280,504))
	await tap(KEY_ESCAPE)
	check(shell.stack.top()==menu and menu.visible and menu.selected_action()==5 and paused,
		"Back restores same live Pause and remembered Character")
	await tap(KEY_ENTER)
	var reopened := shell.stack.top() as Character
	check(reopened!=null and reopened.get_instance_id()!=previous_panel_id and reopened.selected_action()==1
		and reopened.character_data()==state,"reopen selects Health decrease and recomputes actor data")
	button(MOUSE_BUTTON_RIGHT,true,neutral);button(MOUSE_BUTTON_RIGHT,false,neutral)
	check(shell.stack.top()==menu and menu.selected_action()==5,"fresh right-click returns to Character entry")
	await tap(KEY_ESCAPE)
	check(shell.stack.depth()==0 and not paused and Engine.time_scale==1.0
		and actor.execution.has_move_order() and startup.point.read_active(Point.Map.UI)==null,
		"final close resumes ordinary gameplay, prior route and switches action map")
	finish()

func dark_pixels(pixels: Image, region: Rect2i) -> int:
	var n := 0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var c := pixels.get_pixel(x,y)
			if c.r<.37 and c.g<.28 and c.b<.32: n+=1
	return n
