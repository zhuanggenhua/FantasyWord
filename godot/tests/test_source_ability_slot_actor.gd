extends SceneTree
## 真实 F5 的正式能力对象与热键回归，不构造或模拟角色能力。
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks+=1
	if value: return
	failures+=1
	printerr("FAIL ",label)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=down
	root.push_input(event,true)

func slot_codes(owner: RefCounted) -> Array:
	return owner.equipped_ability_menu_slots().map(func(row):return row.formal_gas_ability_code)

func run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 实际快捷能力换槽需要锁定关卡的私有素材。")
		quit()
		return
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"进入真正 F5 原关卡")
	await scene_changed
	await process_frame
	var startup := current_scene as Boot
	check(startup!=null and startup.player!=null,"原角色存在")
	if startup==null or startup.player==null:
		quit(1)
		return
	var player := startup.player
	startup.scene.training_target.ai_controller.stop()
	var runtime: Node = startup.scene._charged_actor_runtime
	var events: Array = []
	player.equipped_abilities_changed.connect(func(rows):events.append(rows))
	check(player.active_ability_menu_codes()==[20001,20010] and slot_codes(player)==[20001,20010,0,0,0],
		"真实能力实例按原顺序供菜单读取，快捷栏是同一已有运行时")
	check(player.try_equip_formal_ability_to_slot(20001,0) and events.is_empty(),
		"同技能已在该槽返回成功且不通知")
	check(not player.try_equip_formal_ability_to_slot(20004,4)
		and not player.try_equip_formal_ability_to_slot(20001,-1) and events.is_empty(),"未拥有或越界拒绝且不通知")
	check(player.try_equip_formal_ability_to_slot(20001,4)
		and slot_codes(player)==[0,20010,0,0,20001] and events.size()==1,
		"重装到第五槽时原第一槽清除，仅发一次快照")
	var basic: Node=runtime.resolve(20001)
	key(KEY_1,true)
	for i in range(6): await physics_frame
	key(KEY_1,false)
	check(not basic.local_active and startup.scene.human_presentation.driver.current_animation_key!="Attack",
		"实际原第一槽已空，按 1 不再触发普攻")
	key(KEY_5,true)
	for i in range(24):
		await physics_frame
		if startup.scene.human_presentation.driver.current_animation_key=="Attack": break
	check(startup.scene.human_presentation.driver.current_animation_key=="Attack",
		"同一个实际技能从第五槽按 5 触发真实 Attack 动画")
	key(KEY_5,false)
	check(player.clear_equipped_ability_slot(1) and player.active_ability_menu_codes()==[20001,20010]
		and slot_codes(player)==[0,0,0,0,20001] and events.size()==2,
		"卸下喷火快捷槽不撤销已持有技能")
	check(not player.clear_equipped_ability_slot(1) and events.size()==2,"再清空已空槽不通知")
	check(player.try_equip_formal_ability_to_slot(20010,4) and slot_codes(player)==[0,0,0,0,20010]
		and events.size()==3 and events[0][4].formal_gas_ability_code==20001,
		"原槽替换更新真实槽，先前事件快照不跟着改变")
	print("%s 原角色技能槽和真实热键：%d/%d"%["PASS" if not failures else "FAIL",checks-failures,checks])
	quit(1 if failures else 0)
