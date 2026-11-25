extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Gear := preload("res://game_core/inventory/source_character_equipment.gd")
var total := 0
var failed := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	total+=1
	if not ok:
		failed+=1
		printerr("FAIL ",label)

func codes(rows: Array) -> Array:
	return rows.map(func(row): return row.formal_gas_ability_code)

func run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 原场景主角存档验证需要私有原资源")
		finish()
		return
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"正式 F5")
	await scene_changed
	await process_frame
	var boot := current_scene as Boot
	if boot==null or boot.scene==null:
		check(false,"必须真实启动原场景")
		finish()
		return
	var player := boot.player
	var actor: Node2D = boot.scene.actor
	var gear: Gear=player.source_equipment()
	var original: Dictionary=player.capture_source_player_save_fields()
	if not original.ok:
		check(false,"读到已绑定单人主角字段")
		finish()
		return
	check(not player.restore_source_player_save_fields({"identifier":"player"}),"拒绝残缺字段")
	var target: Dictionary=original.fields.duplicate(true)
	target.currentResources={"health":73,"mana":-2}
	target.equipmentSlots = target.equipmentSlots.filter(func(row): return row.slotType==Gear.Slot.TORSO)
	var events := []
	var bag_before := boot.capture_source_inventory()
	var on_gear := func():
		events.append(["gear",player.current_health(),gear.equipped(Gear.Slot.WEAPON)==null,
			player.restore_source_player_save_fields(target)])
	var on_health := func(prior: int,next: int,source: Variant):
		events.append(["health",prior,next,source==actor,player.resource_bar_values(actor)[2]])
	var on_damage := func(_source,_input,_prior,_applied): events.append(["damage"])
	gear.loadout_changed.connect(on_gear)
	player.bind_current_health_changed(on_health)
	player.damage_completed.connect(on_damage)
	var invalid := target.duplicate(true)
	invalid.equipmentSlots.append({"slotType":Gear.Slot.WEAPON,"equipment":{"guid":Gear.CLOTH}})
	check(not player.restore_source_player_save_fields(invalid) and events.is_empty()
		and player.capture_source_player_save_fields()==original,"后到的错槽位不改装备、当前资源或事件")
	invalid=target.duplicate(true)
	invalid.currentResources.health=0
	check(not player.restore_source_player_save_fields(invalid) and events.is_empty(),"不伪造死亡/复活恢复")
	check(player.restore_source_player_save_fields(target),"真实单主角所有者接受原形状")
	check(events==[["gear",100,true,false],["health",100,73,true,40]],"先单次新装备通知，再生命，递归恢复拒绝")
	check(player.resource_bar_values(actor)==PackedInt32Array([73,100,0,40])
		and boot.capture_source_inventory()==bag_before and player.is_current_controlled(actor),
		"恢复钳制法力但不改属性上限、背包或控制")
	events.clear()
	check(player.restore_source_player_save_fields(target) and events==[["gear",73,true,false]],
		"同值不重复写生命，原装备通知仍一次")
	gear.loadout_changed.disconnect(on_gear)
	player.unbind_current_health_changed(on_health)
	player.damage_completed.disconnect(on_damage)
	var over: Dictionary=original.fields.duplicate(true)
	over.currentResources={"health":140,"mana":50}
	check(player.restore_source_player_save_fields(over) and player.capture_source_player_save_fields()==original,
		"高于上限按原钳制且还原原登记长矛")
	var owner := boot.primary_bag_owner(actor)
	var spear := gear.item_for_guid(Gear.SPEAR)
	check(boot.inventory_bags.try_unequip(owner,gear,Gear.Slot.WEAPON)==Gear.Result.VALID,
		"通过实际装备事务制作武器在背包的快照")
	var hand := player.capture_source_player_save_fields()
	var bag := boot.capture_source_inventory()
	check(hand.ok and bag.ok and hand.fields.equipmentSlots==target.equipmentSlots
		and boot.inventory_bags.count(owner,spear)==1,
		"同一个原登记武器只在背包，不在装备快照")
	check(boot.inventory_bags.try_equip(owner,gear,spear)==Gear.Result.VALID
		and boot.inventory_bags.count(owner,spear)==0,"用正常事务改变装备与背包")
	check(player.restore_source_player_save_fields(hand.fields) and boot.restore_source_inventory(bag.block).ok
		and player.capture_source_player_save_fields()==hand and boot.capture_source_inventory()==bag
		and gear.equipped(Gear.Slot.WEAPON)==null and boot.inventory_bags.count(owner,spear)==1,
		"两个边界各自精确回环，不重复生成原武器")
	check(player.restore_source_player_save_fields(original.fields),"返回原装备和快捷槽作为形状验证基线")
	check(original.fields.quickAbilitySlots.map(func(row): return row.formalGasAbilityCode)
		==[20001,20010,0,0,0],"快照按原五槽记录正式能力代码，不混用显示名")
	var order := []
	gear.loadout_changed.connect(func(): order.append("gear"))
	player.bind_current_health_changed(func(_prior,_next,_source): order.append("health"))
	player.equipped_abilities_changed.connect(func(rows): order.append(codes(rows)))
	var layout: Dictionary=target.duplicate(true)
	layout.quickAbilitySlots=[null,{"slotIndex":-1,"formalGasAbilityCode":20004},
		{"slotIndex":4,"formalGasAbilityCode":20010},{"slotIndex":4,"formalGasAbilityCode":20001},
		{"slotIndex":4,"formalGasAbilityCode":0},{"slotIndex":2,"formalGasAbilityCode":20001}]
	invalid=layout.duplicate(true)
	invalid.quickAbilitySlots.append({"slotIndex":0,"formalGasAbilityCode":20004})
	check(not player.restore_source_player_save_fields(invalid) and order.is_empty()
		and player.capture_source_player_save_fields()==original,"未知有效槽内的能力拒绝整块，连资源与装备也不动")
	invalid=layout.duplicate(true)
	invalid.quickAbilitySlots.append({"slotIndex":"4","formalGasAbilityCode":20001})
	check(not player.restore_source_player_save_fields(invalid) and order.is_empty()
		and player.capture_source_player_save_fields()==original,"最后一行形状错误仍须原子拒绝")
	check(player.restore_source_player_save_fields(layout)
		and order==["gear","health",[0,0,20001,0,20001]],"原序资源后仅一次槽位通知；支持原重复代码与末个正值")
	var missing: Dictionary = layout.duplicate(true)
	missing.erase("quickAbilitySlots")
	order.clear()
	check(player.restore_source_player_save_fields(missing)
		and order==["gear",[0,0,0,0,0]] and player.active_ability_menu_codes()==[20001,20010],
		"缺失字段清空旧槽，不撤销正式技能")
	missing.quickAbilitySlots=null
	order.clear()
	check(player.restore_source_player_save_fields(missing) and order==["gear",[0,0,0,0,0]],
		"显式 null 清空；布局未变仍恰好通知一次")
	var damage := player.damage_hooks()
	check(player.restore_source_player_save_fields(target)
		and damage.apply_current_health_delta.call(-1,0,null,null)==72,
		"下次正式伤害仍基于已经恢复的同一个生命属性")
	actor.execution.move_to(Vector2(1,0))
	check(actor.execution.has_move_order() and not player.restore_source_player_save_fields(over)
		and player.current_health()==72,"存在移动订单时保留现态，不冒充完整运行时读档")
	actor.queue_free()
	check(not player.capture_source_player_save_fields().ok,"不捕获待退出的原主角")
	finish()

func finish() -> void:
	print("%s 原主角存档子块：%d/%d（仅存活单人，无磁盘）" % ["PASS" if failed==0 else "FAIL",total-failed,total])
	quit(1 if failed else 0)
