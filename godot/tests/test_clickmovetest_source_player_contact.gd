extends SceneTree
## 在正式启动的真实地图上提交正式 Fire；不擅自给正常玩法添一个自动点火者。
const Inventory := preload("res://gameplay/clickmovetest/source_inventory_view.gd")
const Startup := preload("res://gameplay/clickmovetest/source_startup.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 原图火焰接触：需要正式启动的原资源")
		quit()
		return
	root.size=Vector2i(800,600)
	if change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))!=OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var startup := current_scene as Startup
	var scene := startup.scene
	var player := startup.player
	var actor: Node2D = scene.actor
	var flash := startup.damage_screen_flash
	# 使用闪屏自带的时钟注入口，避免软件渲染超过 0.15 秒时首帧即结束。
	# 正式伤害仍由同一个场景接收器发布，生产时钟不变。
	var flash_time: float = flash._clock.call()
	flash._clock = func(): return flash_time
	flash._last_tick = flash_time
	var terrain: RefCounted = scene.surface_elements
	_check(is_instance_valid(scene.surface_contact_damage)
		and scene._source_primary_death_owner==player and not scene.bind_source_player_surface_contact(player),
		"正常项目已装配唯一地表接收器和同一主角正式死亡")
	if failures:
		quit(1)
		return
	scene.set_process(false)
	var health := player.current_health()
	var bags := startup.inventory_bags
	var gear := player.source_equipment()
	var shirt := gear.item_for_guid(gear.CLOTH)
	var spear := gear.item_for_guid(gear.SPEAR)
	var primary_owner := startup.primary_bag_owner(actor)
	var corpse := bags.corpse_owner("player")
	var trainer_owner := bags.character_owner(scene.training_target.SOURCE_IDENTIFIER)
	var party := bags.party_owner()
	# 原开局背包为空；仅测试预置已持有的物品，检验死亡保留数量与库存隔离。
	bags.add(primary_owner,spear,2)
	bags.add(party,spear)
	bags.add(trainer_owner,shirt)
	var transfers := []
	bags.item_removed.connect(func(owner,item,count,transfer):
		transfers.append(["remove",owner,item,count,transfer,player.is_destroyed()]))
	bags.item_added.connect(func(owner,item,count,transfer):
		transfers.append(["add",owner,item,count,transfer,player.is_destroyed()]))
	var contacts := []
	var starts := []
	scene.human_presentation.driver.animation_selected.connect(func(key):
		if key=="Dmg": starts.append(startup.player.current_health()))
	player.damage_completed.connect(func(origin,_input,previous,applied):
		contacts.append([origin,previous,applied,startup.player.current_health(),flash.color.a]))
	var grass := Vector2(.5,.5)
	actor.request_move_position(grass)
	await physics_frame
	await physics_frame
	await process_frame
	scene.set_physics_process(false)
	_check(actor.get_movement_position().is_equal_approx(grass),"原地图中角色根位于准备采样的格")
	scene.advance_surface_contact(.5)
	scene.run_surface_contact_effects()
	_check(player.current_health()==health and contacts.is_empty(),"未着火格不减血")
	scene.surface_contact_damage.register_target(actor)
	_check(terrain.apply_point(terrain.FIRE,grass,1,.1),"同一真实草地由原 Fire 提交点燃")
	actor.push_motion(Vector2.LEFT,8,3)
	var original: Dictionary=actor.execution._push_order.duplicate()
	scene.advance_surface_contact(.49)
	scene.advance_surface_contact(.5,0)
	scene.run_surface_contact_effects()
	_check(contacts.is_empty() and actor.execution._push_order==original,
		"未满 0.5 缩放秒，暂停不累计，不覆盖真实已有推力")
	scene.advance_surface_contact(.01)
	_check(player.current_health()==health and actor.execution._push_order==original,
		"采样只提交正式效果，实际效果消费前不写生命和推力")
	scene.run_surface_contact_effects()
	var order: Dictionary=actor.execution._push_order
	_check(actor.is_pushed() and order.direction==Vector2.ZERO
		and order.intensity==5.0 and order.resistance==10.0
		and actor.get_movement_linear_velocity().is_zero_approx(),
		"非自伤零冲量仍清速度并以原 5/10 的零向量替换")
	_check(contacts.size()==1 and contacts[0][0]==null and contacts[0].slice(1,4)==[health,1,health-1]
		and contacts[0][4]>0.0 and starts==[health] and not player.is_destroyed(),
		"注册与主角回退去重；受击动作先于扣血，闪屏在正式完成后")
	scene.advance_human_damage_lifecycle()
	_check(not player.is_destroyed() and player.is_current_controlled(actor),"非致死受击不清除原控制身份")
	_check(terrain.apply_point(terrain.WATER,grass,1,.1),"原 Water 规则熄灭本格")
	scene.advance_surface_contact(.5)
	scene.run_surface_contact_effects()
	_check(contacts.size()==1 and player.current_health()==health-1,"熄火不再创建伤害")
	# 下一格自伤来源必须是同一真实玩家，而非第二份属性或角色。
	var other := Vector2(-.5,.5)
	actor.request_move_position(other)
	await physics_frame
	await physics_frame
	await process_frame
	_check(actor.get_movement_position().is_equal_approx(other)
		and terrain.apply_point(terrain.FIRE,other,1,.1,actor),"原邻格接收实际玩家作为施法来源")
	actor.push_motion(Vector2.RIGHT,7,4)
	original=actor.execution._push_order.duplicate()
	scene.advance_surface_contact(.5)
	scene.run_surface_contact_effects()
	_check(contacts.size()==2 and player.current_health()==health-2
		and actor.execution._push_order==original,"自伤正常扣血且不替换既有推力")
	# 测试只把正式属性置为 1；最终一击必须由同一 Fire 采样产生。
	player._attributes.apply_current_health_delta(3-health,0,null,null)
	_check(player.current_health()==1 and not player.is_destroyed(),"致死验证预置同一属性剩一命")
	scene.advance_surface_contact(.5)
	var check_menus := OS.get_environment("FW_TEST_SOURCE_DEATH_MENU")=="1"
	var shell := startup.pause_root
	var menu_root: Control
	var child_panel: Control
	var close_events := []
	if check_menus:
		# 只交错已经排队的地表效果和 UI；不让暂停时的地表时钟推进。
		if shell==null:
			_check(false,"死亡菜单测例需要原根与背包面板")
			quit(1)
			return
		_escape_edge()
		menu_root=shell.stack.top()
		if menu_root==null:
			_check(false,"原 ESC 实际挂载根菜单")
			quit(1)
			return
		# 原 Items 行参考坐标；由实际 Pointer 路由发布，非测试直调子菜单。
		var item_position := Vector2(40,190)*root.get_visible_rect().size.y/540.0
		for down in [true,false]:
			var mouse := InputEventMouseButton.new()
			mouse.device=0
			mouse.button_index=MOUSE_BUTTON_LEFT
			mouse.pressed=down
			mouse.position=item_position
			root.push_input(mouse,true)
		child_panel=shell.stack.top()
		_check(shell.stack.depth()==2 and child_panel is Inventory and paused
			and Engine.time_scale==0.0 and scene._source_ui_action_layer,
			"原暂停根、背包页和 UI 动作图均已挂载")
		scene.source_primary_killed.connect(func():
			close_events.append([shell.stack.depth(),paused,gear.equipped(gear.Slot.WEAPON),
				transfers.size(),scene.human_presentation.driver.current_animation_key]))
	scene.run_surface_contact_effects()
	_check(contacts.size()==3 and contacts.back().slice(1,4)==[1,1,0]
		and not player.is_destroyed() and flash.color.a>0.0
		and transfers.is_empty() and bags.count(primary_owner,spear)==2
		and bags.entries(corpse).is_empty() and gear.equipped(gear.Slot.WEAPON)==spear,
		"致死接触先正式结算并闪屏，再等待安全死亡阶段")
	if check_menus: _check(paused and shell.stack.depth()==2,"归零仍未进入死亡阶段，暂不关闭菜单")
	scene.advance_human_damage_lifecycle()
	if check_menus:
		_check(close_events==[[0,false,spear,2,"SpinDie"]]
			and Engine.time_scale==1.0 and not scene._source_ui_action_layer,
			"锁定原死亡动作后清空菜单、恢复动作图，并且装备尚未开始转移")
		_check(shell.stack.cached_root()==menu_root and not menu_root.visible
			and is_instance_valid(child_panel) and child_panel.is_queued_for_deletion(),
			"根仅隐藏缓存，背包页按原逐层关闭路径释放")
		_escape_edge()
		_check(shell.stack.depth()==0,"已失去控制的尸体不能重开暂停菜单")
		if is_instance_valid(startup.ability_hud):
			var menu_message = startup.ability_hud.message
			_check(menu_message.visible and menu_message.value=="当前没有可控制角色。"
				and not paused and not scene._source_ui_action_layer,
				"真实死亡后的新 Esc 走正式菜单命令失败及原 HUD，不改变时钟或动作图")
	_check(player.is_destroyed() and not player.is_current_controlled(actor)
		and scene.camera.follow==actor and startup.persistables.resolve("player")==actor
		and scene.human_presentation.driver.current_animation_key=="SpinDie",
		"原死亡动作、禁用当前控制、镜头和持久化身份均保留同一身体")
	var corpse_transfer := bags.Transfer.CORPSE
	_check(transfers.size()==4 and transfers.slice(0,2)==[
		["remove",primary_owner,spear,2,corpse_transfer,false],
		["add",corpse,spear,2,corpse_transfer,false]],
		"原背包数量和事件在 Movable 销毁之前转到已注册的 player 尸体")
	var equipment_rows_ok := transfers.slice(2).all(func(row):
		return row[0]=="add" and row[1]==corpse and row[3]==1 and row[4]==corpse_transfer and row[5])
	_check(equipment_rows_ok
		and bags.count(corpse,spear)==3 and bags.count(corpse,shirt)==1
		and bags.entries(primary_owner).is_empty()
		and gear.equipped(gear.Slot.WEAPON)==null and gear.equipped(gear.Slot.TORSO)==null,
		"原强制卸下的两件装备在销毁后入同一尸体，原背包同物品合计三件")
	_check(bags.count(party,spear)==1 and bags.count(trainer_owner,shirt)==1
		and bags.entries(bags.corpse_owner(player.SOURCE_PREINSTANCED_IDENTIFIER)).is_empty(),
		"队伍和假人不参与转移，场景预放 UUID 不是主角尸体键")
	scene.advance_human_damage_lifecycle()
	_check(transfers.size()==4 and bags.count(corpse,spear)==3,"重复安全阶段不再转移")
	scene.advance_surface_contact(1.5)
	scene.run_surface_contact_effects()
	_check(player.current_health()==0 and contacts.size()==3 and actor==scene.actor,
		"死亡目标不重伤，不虚构重生或换图")
	if DisplayServer.get_name()!="headless":
		# 实际致死事件启动的闪屏保持一个渲染采样；不另派发手造表现事件。
		flash.set_process(false)
		var amount: float=flash.color.a
		await RenderingServer.frame_post_draw
		var shown := root.get_texture().get_image()
		flash.hide()
		await RenderingServer.frame_post_draw
		var hidden := root.get_texture().get_image()
		var match_count := 0
		for y in range(shown.get_height()/2,shown.get_height()-8,19):
			for x in range(8,shown.get_width()-8,19):
				var before := hidden.get_pixel(x,y)
				var after := shown.get_pixel(x,y)
				var expected := before.lerp(Color(.8,.15,.15),amount)
				if absf(after.r-expected.r)<.012 and absf(after.g-expected.g)<.012 and absf(after.b-expected.b)<.012 \
						and (absf(after.r-before.r)+absf(after.g-before.g)+absf(after.b-before.b))>.02:
					match_count+=1
		_check(amount>0.0 and match_count>50,"真实致死接触的原生全屏 RGB 已混色")
		print("燃烧致死闪屏原生像素样本：",match_count)
	if not failures: print("PASS 原场景玩家地表受击：%d 项（%s）" % [checks,DisplayServer.get_name()])
	quit(1 if failures else 0)

func _escape_edge() -> void:
	for down in [true,false]:
		var key := InputEventKey.new()
		key.physical_keycode=KEY_ESCAPE
		key.pressed=down
		root.push_input(key,true)

func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)
