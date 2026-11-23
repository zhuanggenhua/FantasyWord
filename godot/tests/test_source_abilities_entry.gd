extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Abilities := preload("res://gameplay/clickmovetest/source_abilities_view.gd")
const Pause := preload("res://gameplay/clickmovetest/source_pause_focus_view.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func key(k: Key, down: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=k
	event.physical_keycode=k
	event.pressed=down
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

func point(p: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.device=0
	event.position=p
	event.relative=Vector2(1,1)
	root.push_input(event,true)

func click(p: Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.device=0
		event.position=p
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		root.push_input(event,true)

func finish() -> void:
	print("%s ClickMoveTest 原技能菜单：%d/%d"%["PASS" if failures==0 else "FAIL",checks-failures,checks])
	quit(1 if failures else 0)

func codes(owner: RefCounted) -> Array:
	return owner.equipped_ability_menu_slots().map(func(row):return row.formal_gas_ability_code)

func visible_slots(hud: CanvasLayer) -> Array:
	var ids: Array=[]
	for i in hud._entries.size():
		if hud._entries[i].visible: ids.append(i+1)
	return ids

func run() -> void:
	var dir:=OS.get_environment("FORMAL_PAUSE_SOURCE")
	if dir.is_empty() or not FileAccess.file_exists(dir.path_join("abilities-layout.json")):
		print("SKIP 原技能菜单需要私有作者资源合同。")
		finish()
		return
	root.size=Vector2i(960,540)
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"从真实 F5 进入")
	await scene_changed
	await process_frame
	var startup := current_scene as Boot
	check(startup!=null and startup.pause_root!=null,"源暂停宿主正常加载")
	if startup==null or startup.pause_root==null: finish(); return
	startup.scene.training_target.ai_controller.stop()
	var shell:=startup.pause_root
	var hud:=startup.ability_hud
	check(is_instance_valid(hud) and visible_slots(hud)==[1,2],"正式启动同一角色的可见技能只有前两槽")
	if not is_instance_valid(hud): finish(); return
	check(hud._entries[0].get_rect()==Rect2(856,957,96,96)
		and hud._entries[1].get_rect()==Rect2(968,957,96,96)
		and hud._bar.scale==Vector2(.5,.5),"原高度缩放、中央间距和底部位置")
	check(hud.blocks_map_pointer(Vector2(508,500)) and not hud.blocks_map_pointer(Vector2(480,500))
		and not hud.blocks_map_pointer(Vector2(535,500)),"仅已装备的完整槽命中，不盖住间隔或空区")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var hud_image:=root.get_texture().get_image()
		check(hud_image.get_pixel(508,502).is_equal_approx(Color.WHITE)
			and not hud_image.get_pixel(508,484).is_equal_approx(Color.WHITE),"云截图真实显示喷火图标与不同的外框")
	point(Vector2(508,500))
	await process_frame
	var command_before: int=startup.scene.command_count
	click(Vector2(508,500))
	check(startup.scene.command_count==command_before and startup.scene.click_observation.latest.over_ui,
		"从真实 Gameplay Point 点击已占槽只拦截，不下达移动或启动技能")
	await tap(KEY_ESCAPE)
	var pause:=shell.stack.top() as Pause
	check(pause!=null,"正式原 Pause")
	if pause==null: finish(); return
	check(hud.layer<shell.layer and visible_slots(hud)==[1,2],"暂停暗幕叠加在 HUD 前方，不禁用 HUD 槽")
	var icon:=Vector2.INF
	for entry: Dictionary in pause._entries:
		if entry.action==4: icon=entry.icon.get_center()*.5
	check(icon.is_finite(),"原 action 4 的坐标存在")
	click(icon) # No Mouse Point movement: this also exercises original keyboard focus.
	var panel:=shell.stack.top() as Abilities
	check(panel!=null and shell.stack.depth()==2 and paused,"原 EMenu 2 作为二级面板挂载")
	if panel==null: finish(); return
	var owner:=startup.player
	check(panel.category==1 and panel._rows==[20001,20010] and panel.selected_action()==11
		and codes(owner)==[20001,20010,0,0,0],"主动分类和真实技能顺序，默认选中普攻")
	check(panel._list.position==Vector2(388,461) and panel._list.size==Vector2(454,438)
		and panel.action_rect(1)==Rect2(343,256,544,72) and panel.action_rect(2)==Rect2(343,336,544,72)
		and panel.action_rect(21)==Rect2(985,832,96,96) and panel.action_rect(25)==Rect2(1433,832,96,96),
		"原嵌套布局、独立分类高度、作者五格")
	check(panel._attack.get_image().get_used_rect()==Rect2i(12,12,8,7)
		and panel._row_icons[1]._texture==panel._solid and panel._bar_icons[1].visible
		and not panel._bar_icons[2].visible,"有图标普攻、无图标喷火与真正空槽是三种状态")
	check(panel._description.displayed_lines[0]=="玩家普通攻击" and not panel._description.truncated
		and panel._description._underlines.size()==8,"真实术语、换行和两条生成伤害说明")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image()
		check(image.get_pixel(200,266).is_equal_approx(Color.WHITE)
			and image.get_pixel(574,439).is_equal_approx(Color.WHITE),
			"原生视窗绘出无图但有效的喷火列表图与第二槽")
		var ink:=0
		for y in range(176,197):
			for x in range(550,707):
				var c:=image.get_pixel(x,y)
				if c.r<.30 and c.g<.21 and c.b<.25: ink+=1
		check(ink>20,"原生文字像素存在，不只是数据合同")
	await tap(KEY_DOWN)
	check(panel.selected_action()==12 and panel._description.truncated
		and panel._spec.abilities["20010"].damage.size()==14,"喷火显示原文本并按可视区域省略，保留 14 条单位效果")
	await tap(KEY_ENTER)
	check(panel.equip_from==12 and panel.selected_action()==21
		and panel._equip_art[0].visible and panel._equip_art[1].visible
		and not panel._allows(12),"无活动 UI Point 时进入选槽，箭头和禁用列表出现")
	await tap(KEY_ESCAPE)
	check(shell.stack.top()==panel and panel.equip_from==0 and panel.selected_action()==12
		and not panel._equip_art[0].visible,"选槽 Esc 只取消分配，回原项而不弹菜单")
	await tap(KEY_UP); await tap(KEY_ENTER)
	for i in range(4): await tap(KEY_RIGHT)
	check(panel.equip_from==11 and panel.selected_action()==25,"原五格可用键盘导航")
	await tap(KEY_ENTER)
	check(codes(owner)==[0,20010,0,0,20001] and not panel._bar_icons[0].visible
		and panel._bar_icons[4]._texture==panel._attack and panel.equip_from==0,
		"正式菜单换槽更新真实能力，不创建第二份栏位")
	check(visible_slots(hud)==[2,5] and hud._entries[4].position==Vector2(968,957)
		and hud._icons[4]._texture==hud._attack,"菜单改槽同帧更新其后方 HUD；逻辑第 5 槽紧排在第 2 槽后")
	var passive:=panel.action_rect(2).get_center()*.5
	point(passive)
	await process_frame
	await process_frame
	check(panel.selected_action()==2 and panel.category==1 and panel._row_icons[0].visible
		and panel._description.displayed_lines[0].begins_with("Passive abilities"),
		"主动 UI Point 聚焦被动分类立即显示原说明，但保留主动列表与快捷栏")
	var neutral := Vector2(470,460)
	point(neutral)
	await process_frame
	await process_frame
	check(panel.selected_action()==2 and panel.category==1 and codes(owner)==[0,20010,0,0,20001],
		"离开可选按钮仍保留说明焦点，不改实际快捷槽")
	await tap(KEY_ENTER)
	check(panel.category==2 and not panel._row_icons[0].visible and panel.selected_action()==2
		and panel._description.displayed_lines[0].begins_with("Passive abilities"),
		"移走后确认才切换被动类别，保留原说明")
	if panel.category!=2:
		await tap(KEY_ESCAPE) # 仅红测恢复：提交仍命中原技能时先退出装备模式。
		click(passive)
	await tap(KEY_ESCAPE)
	check(shell.stack.top()==pause,"回到父菜单后原技能面板已关闭")
	await tap(KEY_ENTER)
	panel=shell.stack.top() as Abilities
	check(panel!=null and panel.category==2 and panel.selected_action()==1 and not panel._row_icons[0].visible,
		"快速重开复用原分类偏好，无被动条目时退回首个原可选项")
	if panel==null: finish(); return
	var empty_slot:=panel.action_rect(21).get_center()*.5
	point(empty_slot)
	await process_frame
	await process_frame
	check(panel.selected_action()==21 and panel._description._glyphs.is_empty(),
		"被动分类仍可聚焦真实空槽，旧说明随之清空")
	var active:=panel.action_rect(1).get_center()*.5
	point(active)
	await process_frame
	await process_frame
	check(panel.selected_action()==1 and panel.category==2 and not panel._row_icons[0].visible
		and panel._description.displayed_lines[0].begins_with("Active abilities"),
		"返回再开后主动按钮悬停显示自己的原说明，不自动恢复主动列表")
	click(active)
	check(panel.category==1 and panel._row_icons[0].visible,
		"普通鼠标点击主动分类仍走原按钮回调")
	var fire:=panel.action_rect(12).get_center()*.5
	point(fire)
	await process_frame
	await process_frame
	click(fire)
	check(panel.equip_from==12 and panel.selected_action()==12,"指针活动时，进入选槽不强行切到第一格")
	var third:=panel.action_rect(23).get_center()*.5
	point(third)
	await process_frame
	await process_frame
	click(third)
	check(codes(owner)==[0,0,20010,0,20001] and panel.equip_from==0 and panel.selected_action()==23,
		"点击目标槽装入喷火且退出选择")
	check(visible_slots(hud)==[3,5] and hud._icons[2]._texture==hud._solid,"喷火跟随真实第三槽，仍是启用的空 Sprite")
	click(third)
	check(codes(owner)==[0,0,0,0,20001] and owner.active_ability_menu_codes()==[20001,20010],
		"未在选择态点击槽位清除；不撤销已持有技能")
	point(Vector2(469,240))
	await tap(KEY_ESCAPE)
	check(shell.stack.top()==pause and pause.selected_action()==4 and paused,"Back 返回 Pause，恢复真实 Abilities 入口焦点")
	await tap(KEY_ESCAPE)
	check(not paused and Engine.time_scale==1.0,"再退一层才恢复玩法")
	check(visible_slots(hud)==[5] and hud._entries[4].position==Vector2(912,957)
		and not hud.blocks_map_pointer(Vector2(509,500)),"清槽后仅余普攻并重排居中，旧点击区不残留")
	key(KEY_5,true)
	for i in range(35):
		await physics_frame
		if startup.scene.human_presentation.driver.current_animation_key=="Attack": break
	check(startup.scene.human_presentation.driver.current_animation_key=="Attack","游戏中按 5 触发由正式菜单换到该栏的普攻")
	key(KEY_5,false)
	check(owner.set_current_controlled(false) and visible_slots(hud).is_empty()
		and not owner.equipped_abilities_changed.is_connected(hud._refresh),"控制目标丢失清空并解绑，不接收旧槽变化")
	check(owner.set_current_controlled(true) and visible_slots(hud)==[5],"重新控制读取角色当前槽，而不是恢复旧预制体状态")
	finish()
