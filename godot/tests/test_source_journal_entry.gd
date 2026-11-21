extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Journal := preload("res://gameplay/clickmovetest/source_journal_view.gd")
const Pause := preload("res://gameplay/clickmovetest/source_pause_focus_view.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func tap(k: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode=k
		event.pressed=down
		root.push_input(event,true)
		if k==KEY_DOWN or (not down and k==KEY_ENTER):
			await process_frame
			await process_frame

func click(b: MouseButton,p: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.device=0
	event.button_index=b
	event.position=p
	event.pressed=true
	root.push_input(event,true)
	event.pressed=false
	root.push_input(event,true)

func finish() -> void:
	print("%s ClickMoveTest initial Journal: %d/%d"%["PASS" if failures==0 else "FAIL",checks-failures,checks])
	quit(1 if failures!=0 else 0)

func run() -> void:
	var directory := OS.get_environment("FORMAL_PAUSE_SOURCE")
	if directory.is_empty() or not FileAccess.file_exists(directory.path_join("journal-layout.json")):
		print("SKIP source Journal graphics require the pinned private contracts")
		finish()
		return
	root.size=Vector2i(960,540)
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"normal main scene")
	await scene_changed
	await process_frame
	var startup := current_scene as Boot
	check(startup!=null and startup.pause_root!=null,"runtime opens authored Pause")
	if startup==null or startup.pause_root==null: finish(); return
	var shell := startup.pause_root
	var neutral := Vector2(460,252)
	click(MOUSE_BUTTON_LEFT,neutral)
	var actor: Node = startup.scene.actor
	check(actor.execution.has_move_order(),"real move order before menus")
	await tap(KEY_ESCAPE)
	var menu := shell.stack.top() as Pause
	check(menu!=null and paused,"actual Escape opens source Pause")
	if menu==null: finish(); return
	var icon := Vector2.INF
	for row: Dictionary in menu._entries:
		if row.action==2:
			icon=row.icon.get_center()*.5
	check(icon.is_finite(),"source action 2 has a real hit box")
	click(MOUSE_BUTTON_LEFT,icon)
	var journal := shell.stack.top() as Journal
	check(journal!=null and paused and shell.stack.depth()==2 and not menu.visible,"pointer opens registered Journal EMenu4")
	if journal==null: finish(); return
	var titles: Array[String]=[]
	for line in journal._lines: titles.append(line._line.text)
	check(titles==["Journal","Select","Back","On-going Quests","Description"],"only source headings/footer, no editor placeholder tasks")
	check(journal._frames[0].position==Vector2(120,308) and journal._frames[2].position==Vector2(968,308)
			and journal._frames[0].size==Vector2(832,688),"original divided force expansion gives y308 rather than y300")
	check(journal._viewports.size()==2 and journal._viewports[0].position==Vector2(165,353)
			and journal._viewports[1].position==Vector2(1013,353) and journal._viewports[0].size==Vector2(742,598)
			and journal._viewports[0].clip_contents and journal._viewports[1].clip_contents
			and journal._viewports[0].get_child_count()==0 and journal._viewports[1].get_child_count()==0,
		"empty source lists inside two invisible clips with no shown scrollbar or quest placeholders")
	check(not journal.try_focus_default_target(),"empty source list has no default button or synthetic choice")
	await tap(KEY_ENTER)
	await tap(KEY_DOWN)
	click(MOUSE_BUTTON_LEFT,neutral)
	check(shell.stack.top()==journal and paused and actor.execution.has_move_order(),
		"empty Journal ignores submit, movement, and background click")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(count_dark(image,Rect2i(60,118,416,38))>50 and count_dark(image,Rect2i(484,118,416,38))>50,
			"both authored headings actually draw")
		var left_fill := image.get_pixel(150,245)
		var right_fill := image.get_pixel(590,245)
		check(not left_fill.is_equal_approx(right_fill) and image.get_pixel(150,285).is_equal_approx(left_fill)
			and image.get_pixel(590,285).is_equal_approx(right_fill),"native distinct sliced fills show through empty masks")
	root.size=Vector2i(880,540)
	await process_frame
	await process_frame
	check(journal._center.position.is_equal_approx(Vector2(-80,0))
		and journal._right.position.is_equal_approx(Vector2(-160,0)),"fit preserves centered columns and anchored footer")
	click(MOUSE_BUTTON_RIGHT,neutral)
	check(shell.stack.top()==menu and menu.selected_action()==2 and paused,"right Back restores Journal icon focus")
	await process_frame
	await tap(KEY_ENTER)
	check(shell.stack.top() is Journal,"keyboard can reopen same actual entry after return")
	await tap(KEY_ESCAPE)
	check(shell.stack.top()==menu and menu.selected_action()==2,"Escape restores parent focus")
	await tap(KEY_ESCAPE)
	check(shell.stack.depth()==0 and not paused and Engine.time_scale==1.0 and actor.execution.has_move_order(),
		"final Back restores existing gameplay order and time")
	finish()

func count_dark(image: Image, box: Rect2i) -> int:
	var count := 0
	for y in range(box.position.y,box.end.y):
		for x in range(box.position.x,box.end.x):
			var c := image.get_pixel(x,y)
			if c.r<.36 and c.g<.23 and c.b<.27: count+=1
	return count
