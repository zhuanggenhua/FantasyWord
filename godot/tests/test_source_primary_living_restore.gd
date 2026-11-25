extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const APPLY := "restore_source_primary_living_state"
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func key(down: bool, code: Key = KEY_1) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=down
	root.push_input(event,true)

func finish() -> void:
	print("%s F5 主角组合局部恢复：%d/%d"%["FAIL" if failures else "PASS",checks-failures,checks])
	quit(1 if failures else 0)

func run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 需要锁定原关卡")
		quit()
		return
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"正式 F5 入口")
	await scene_changed
	await process_frame
	var boot := current_scene as Boot
	check(boot!=null and boot.scene!=null and boot.player!=null,"实际原主角")
	if failures: finish(); return
	check(boot.has_method(APPLY),"宿主公开单次组合恢复")
	if failures: finish(); return
	boot.scene.training_target.ai_controller.stop()
	var player := boot.player
	var gear = player.source_equipment()
	var ability := boot.capture_source_primary_ability_runtime()
	var source: Dictionary = player.capture_source_player_save_fields().fields
	var bag := boot.capture_source_inventory()
	var target := source.duplicate(true)
	target.currentResources={"health":73,"mana":20}
	target.equipmentSlots=target.equipmentSlots.filter(func(row): return row.slotType==gear.Slot.TORSO)
	target.quickAbilitySlots=[{"slotIndex":0,"formalGasAbilityCode":20010},
		{"slotIndex":4,"formalGasAbilityCode":20001}]
	var host: Node=boot.scene._charged_actor_runtime
	var basic: Node=host.resolve(20001)
	var fire: Node=host.resolve(20010)
	var first := []
	var on_gear := func():
		first.append(["equipment",player.current_health(),basic.gate._trigger_released,
			gear.equipped(gear.Slot.WEAPON)==null,boot.call(APPLY,target,ability)])
	var on_health := func(_prior,_next,_source):
		first.append(["life",player.current_health(),basic.gate._trigger_released,
			player.equipped_ability_menu_slots()[0].formal_gas_ability_code])
	var on_slots := func(_rows):
		first.append(["slots",player.current_health(),basic.gate._trigger_released])
	gear.loadout_changed.connect(on_gear)
	player.bind_current_health_changed(on_health)
	player.equipped_abilities_changed.connect(on_slots)
	key(true)
	for i in range(24):
		await physics_frame
		if basic.spec.active: break
	check(basic.spec.active and not boot.call(APPLY,target,ability) and first.is_empty(),
		"实际施法期间整次拒绝，未修改任何域")
	for i in range(90):
		await physics_frame
		if host.is_idle_for_living_save_restore(): break
	check(host.is_idle_for_living_save_restore() and not basic.gate._trigger_released,
		"真实攻击自然结束但保留按键锁")
	var activated: Array = []
	basic.spec.activation_result.connect(func(result): activated.append([20001,result]))
	fire.spec.activation_result.connect(func(result): activated.append([20010,result]))
	var prior_fire_gate := [fire.gate.state,fire.gate.timer,fire.gate.trigger_held,fire.context.casting]
	var bad := ability.duplicate(true)
	bad.abilityRuntimeStates[1].inputGate.currentAmmoLoaded=1
	check(not boot.call(APPLY,target,bad) and first.is_empty()
		and player.capture_source_player_save_fields().fields==source and not basic.gate._trigger_released
		and [fire.gate.state,fire.gate.timer,fire.gate.trigger_held,fire.context.casting]==prior_fire_gate
		and activated.is_empty(),"不合法 GAS 后行不写装备、资源、槽位或任一输入门，不启动施法")
	var invalid := target.duplicate(true)
	invalid.quickAbilitySlots.append({"slotIndex":4,"formalGasAbilityCode":20004})
	check(not boot.call(APPLY,invalid,ability) and first.is_empty()
		and player.capture_source_player_save_fields().fields==source and not basic.gate._trigger_released,
		"不合法快捷槽拒绝整批，也不先解开 GAS")
	check(boot.call(APPLY,target,ability),"单次恢复真实主角")
	check(first==[["equipment",100,false,true,false],["life",73,true,20001],["slots",73,true]],
		"装备通知时 GAS 旧值；GAS 静默先于资源；快捷槽通知最后；递归拒绝")
	check(player.resource_bar_values(boot.scene.actor)==PackedInt32Array([73,100,20,40])
		and int(player.equipped_ability_menu_slots()[0].formal_gas_ability_code)==20010
		and int(player.equipped_ability_menu_slots()[4].formal_gas_ability_code)==20001
		and not player.is_destroyed() and boot.capture_source_inventory()==bag,
		"真实资源及快捷槽已恢复，而背包没有改变")
	check(boot.capture_source_primary_ability_runtime()==ability and host.resolve(20001)==basic,
		"恢复保留真实技能实例")
	gear.loadout_changed.disconnect(on_gear)
	player.unbind_current_health_changed(on_health)
	player.equipped_abilities_changed.disconnect(on_slots)
	for i in 6: await physics_frame
	check(activated.is_empty() and not basic.local_active and not fire.local_active,
		"键 1 尚未松开，恢复本身也没有启动任一实际能力")
	key(true,KEY_5)
	for i in 90:
		await physics_frame
		if not activated.is_empty() and host.is_idle_for_living_save_restore(): break
	check(activated==[[20001,0]] and host.resolve(20001)==basic,
		"未预先松开键 1，恢复到第五槽后键 5 精确触发一次同一原技能")
	key(false,KEY_5)
	key(false)
	finish()
