extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Gear := preload("res://game_core/inventory/source_character_equipment.gd")
const TAKE := "capture_source_primary_living_state"
const APPLY := "restore_source_primary_living_snapshot"
var total := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	total+=1
	if not ok:
		failed+=1
		printerr("FAIL ",label)

func finish() -> void:
	print("%s F5 主角局部快照冷重开：%d/%d"%["FAIL" if failed else "PASS",total-failed,total])
	quit(1 if failed else 0)

func run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 需要锁定原关卡")
		quit()
		return
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"正式 F5 入口")
	await scene_changed
	await process_frame
	var boot := current_scene as Boot
	check(boot!=null and boot.scene!=null and boot.player!=null,"实际主角与原场景")
	if failed: finish(); return
	check(boot.has_method(TAKE) and boot.has_method(APPLY),"单次采集及恢复边界")
	if failed: finish(); return
	var unstarted := Boot.new()
	check(unstarted.call(TAKE)=={} and not unstarted.call(APPLY, {}),"未启动宿主不能接受该边界")
	unstarted.free()
	boot.scene.training_target.ai_controller.stop()
	var cold_start: Dictionary = boot.call(TAKE)
	check(not cold_start.is_empty(),"新会话可采集")
	if failed: finish(); return
	var player := boot.player
	var refs := boot.capture_source_controlled_references()
	var gear := player.source_equipment()
	var owner := boot.primary_bag_owner(boot.scene.actor)
	check(boot.inventory_bags.try_unequip(owner,gear,Gear.Slot.WEAPON)==Gear.Result.VALID,
		"实际卸装让长矛进入背包而不留在装备槽")
	var damage := player.damage_hooks()
	check(damage.apply_current_health_delta.call(-11,0,null,null)==89 and player.clear_equipped_ability_slot(1),
		"真实属性写入和快捷栏操作")
	var snapshot: Dictionary = boot.call(TAKE)
	check(snapshot.get("fields",{}).get("currentResources",{})=={"health":89,"mana":40}
		and snapshot.fields.equipmentSlots==[{"slotType":Gear.Slot.TORSO,"equipment":{"guid":Gear.CLOTH}}]
		and snapshot.fields.quickAbilitySlots[1].formalGasAbilityCode==0
		and snapshot.abilities.abilityRuntimeStates.map(func(row): return row.formalGasAbilityCode)==[20001,20010],
		"一次采集实际装备资源与快捷行，清空槽不丢失仍然拥有的能力")
	if failed: finish(); return
	var altered := snapshot.duplicate(true)
	altered.abilities.abilityRuntimeStates[1].inputGate.currentAmmoLoaded=9
	altered.fields.currentResources.health=2
	check(boot.call(TAKE)==snapshot,"采集不暴露仍可改写的所有者引用")
	check(player.set_current_controlled(false) and boot.call(TAKE)==snapshot
		and not boot.call(APPLY,snapshot),"主角采集不取当前选中，受限恢复仍要求实际输入属主")
	check(player.set_current_controlled(true),"恢复原控制绑定")
	var host: Node=boot.scene._charged_actor_runtime
	var fire: Node=host.resolve(20010)
	fire.queue_free()
	check(boot.call(TAKE)=={},"等候释放的第二所有者使整块拒绝，不输出半包")
	check(reload_current_scene()==OK,"实际重开同一 F5 场景")
	await scene_changed
	await process_frame
	boot=current_scene as Boot
	check(boot!=null and boot.player!=null and boot.player!=player and boot.call(TAKE)==cold_start,
		"新会话拥有不同主角和默认状态，尚未恢复")
	if failed: finish(); return
	boot.scene.training_target.ai_controller.stop()
	var bag := boot.capture_source_inventory()
	var pose := boot.capture_source_primary_actor_pose()
	check(not boot.call(APPLY,altered) and boot.call(TAKE)==cold_start,
		"后到的非法能力块拒绝整次恢复，即使前面的生命已经被更改")
	var gear_capture := []
	var life_capture := []
	var slot_capture := []
	var new_player := boot.player
	var new_gear := new_player.source_equipment()
	var separate_capture := []
	var on_gear := func():
		gear_capture.append(boot.call(TAKE))
		separate_capture.append([new_player.capture_source_player_save_fields().get("ok",true),
			boot.capture_source_primary_ability_runtime()])
	var on_life := func(_a,_b,_c): life_capture.append(boot.call(TAKE))
	var on_slots := func(_rows): slot_capture.append(boot.call(TAKE))
	new_gear.loadout_changed.connect(on_gear)
	new_player.bind_current_health_changed(on_life)
	new_player.equipped_abilities_changed.connect(on_slots)
	check(boot.call(APPLY,snapshot) and boot.call(TAKE)==snapshot,
		"实际运行结果在冷会话通过一次调用恢复后可再次捕获")
	check(gear_capture==[{}] and life_capture==[{}] and slot_capture==[{}],
		"同步恢复通知中不会暴露旧/新混合状态")
	check(separate_capture==[[false,{}]],"单独采集入口也拒绝暴露中途资源或技能")
	check(new_player.set_current_controlled(false) and boot.capture_source_controlled_references().is_empty()
		and boot.restore_source_controlled_references(refs)
		and boot.capture_source_controlled_references()==refs and boot.call(TAKE)==snapshot,
		"同一次冷重开后按原 PlayerSystem 尾段恢复真实控制，保持刚恢复的角色状态")
	check(boot.capture_source_inventory()==bag and boot.capture_source_primary_actor_pose()==pose,
		"不恢复背包、姿态或地图；仅此支持的主角子集")
	new_gear.loadout_changed.disconnect(on_gear)
	new_player.unbind_current_health_changed(on_life)
	new_player.equipped_abilities_changed.disconnect(on_slots)
	boot.scene.queue_free()
	check(boot.call(TAKE)=={} and not boot.call(APPLY,snapshot),"会话下线时拒绝整个读写边界")
	finish()
