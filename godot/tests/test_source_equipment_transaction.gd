extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Gear := preload("res://game_core/inventory/source_character_equipment.gd")
const Bags := preload("res://game_core/inventory/source_inventory_bags.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if ok: return
	failures+=1
	printerr("FAIL ",message)

func run() -> void:
	await verify_pinned_transactions()
	if OS.get_environment("FORMAL_PAUSE_SOURCE").is_empty():
		print("SKIP 实际 ClickMoveTest 装备合同需要未公开作者资源。")
	else:
		await verify_actual_start()
	print("%s 原版背包与初始装备槽事务：%d/%d"%["PASS" if failures==0 else "FAIL",checks-failures,checks])
	quit(1 if failures else 0)

func verify_pinned_transactions() -> void:
	var actor := Node.new()
	root.add_child(actor)
	var bag := Bags.new()
	var gear := Gear.new()
	var control := {"can_change":true,"health":100}
	check(gear.start(actor,func():return control.health,func():return control.can_change),
		"原始两件装备的角色组件挂到有效目标")
	var spear := gear.item_for_guid(Gear.SPEAR)
	var cloth := gear.item_for_guid(Gear.CLOTH)
	var primary := bag.character_owner("player")
	var party := bag.party_owner()
	check(spear!=null and cloth!=null and spear!=cloth and gear.equipped(Gear.Slot.WEAPON)==spear
		and gear.equipped(Gear.Slot.TORSO)==cloth and gear.equipped(Gear.Slot.HEAD)==null,"真实资源标识及初始槽")
	var trace: Array = []
	var loadout_log := func():
		trace.append(["槽",gear.equipped(Gear.Slot.WEAPON),bag.count(primary,spear),bag.count(party,spear)])
	gear.loadout_changed.connect(loadout_log)
	bag.item_added.connect(func(owner,item,count,source): trace.append(["入",owner,item,count,source]))
	bag.item_removed.connect(func(owner,item,count,source): trace.append(["出",owner,item,count,source]))
	check(bag.try_unequip("",gear,Gear.Slot.WEAPON)==Gear.Result.INVALID_OWNER
		and gear.equipped(Gear.Slot.WEAPON)==spear and trace.is_empty(),"无效回包目标在角色状态写入之前被拒绝")
	control.can_change=false
	check(bag.try_equip(primary,gear,spear)==Gear.Result.ACTION_LOCKED
		and bag.try_unequip(primary,gear,Gear.Slot.WEAPON)==Gear.Result.ACTION_LOCKED and trace.is_empty(),
		"独立动作锁先于缺货或资源判断")
	control.can_change=true
	check(bag.try_equip(primary,gear,spear)==Gear.Result.MISSING_ITEM and trace.is_empty(),"已装备不会自动复制到背包")
	control.health=0
	check(bag.try_unequip(primary,gear,Gear.Slot.WEAPON)==Gear.Result.NOT_ENOUGH_HEALTH
		and gear.equipped(Gear.Slot.WEAPON)==spear and trace.is_empty(),"零生命且未死亡处理时，资源下限拒绝事务")
	control.health=1
	check(bag.try_unequip(primary,gear,Gear.Slot.WEAPON)==Gear.Result.VALID
		and trace==[["槽",null,0,0],["入",primary,spear,1,Bags.Transfer.EQUIPMENT]],
		"正好 1 生命允许卸下；先发角色槽位变化，再回包")
	trace.clear()
	check(bag.try_unequip(primary,gear,Gear.Slot.WEAPON)==Gear.Result.VALID
		and trace==[["槽",null,1,0]],"空槽卸下仍发槽变化，不重复回包")
	trace.clear()
	check(bag.try_equip(party,gear,spear)==Gear.Result.MISSING_ITEM and trace.is_empty(),
		"不同 owner 不借用角色库存")
	check(bag.try_equip(primary,gear,spear)==Gear.Result.VALID
		and trace==[["槽",spear,1,0],["出",primary,spear,1,Bags.Transfer.EQUIPMENT]],
		"重装备先写槽再从原背包扣除")
	# 这里显式用测试库存准备同一真实装备的第二份，不是开局配置或 UI 入口。
	bag.add(party,spear)
	trace.clear()
	check(bag.try_equip(party,gear,spear)==Gear.Result.VALID
		and trace==[["槽",spear,0,1],["出",party,spear,1,Bags.Transfer.EQUIPMENT],
			["入",party,spear,1,Bags.Transfer.EQUIPMENT]],"替换时扣新件，再向同一个来源包返还旧件")
	var other := Resource.new()
	bag.add(party,other)
	trace.clear()
	check(bag.try_equip(party,gear,other)==Gear.Result.INVALID_TARGET and trace.is_empty() and bag.count(party,other)==1,
		"未接作者资源不伪造槽位或消费库存")
	actor.free()
	check(bag.try_unequip(primary,gear,Gear.Slot.WEAPON)==Gear.Result.INVALID_TARGET and trace.is_empty(),
		"角色卸载后不接受装备操作")
	gear.loadout_changed.disconnect(loadout_log)
	await process_frame

func verify_actual_start() -> void:
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"从 F5 原场景进入")
	await scene_changed
	await process_frame
	var startup := current_scene as Boot
	check(startup!=null and startup.player!=null and startup.inventory_bags!=null,"正式宿主已安装角色与背包")
	if startup==null or startup.player==null or startup.inventory_bags==null: return
	var actor: Node=startup.scene.actor
	var owner := startup.primary_bag_owner(actor)
	var gear := startup.player.source_equipment()
	var bag := startup.inventory_bags
	check(gear!=null and owner=="Character:player","原主角的独立装备及持久角色背包")
	if gear==null: return
	var spear := gear.item_for_guid(Gear.SPEAR)
	var cloth := gear.item_for_guid(Gear.CLOTH)
	var before := startup.player.inventory_fresh_stats(actor)
	check(gear.equipped(Gear.Slot.WEAPON)==spear and gear.equipped(Gear.Slot.TORSO)==cloth
		and bag.entries(owner).is_empty(),"实际初始槽占用与空背包")
	check(bag.try_unequip(owner,gear,Gear.Slot.WEAPON)==Gear.Result.VALID
		and gear.equipped(Gear.Slot.WEAPON)==null and bag.count(owner,spear)==1,
		"真实主角卸下长矛到自身背包")
	startup.player.set_accepts_player_input(false)
	check(bag.try_equip(owner,gear,spear)==Gear.Result.VALID
		and gear.equipped(Gear.Slot.WEAPON)==spear and bag.entries(owner).is_empty(),
		"禁止玩家输入不等于禁止换装，真实角色能由事务装回")
	startup.player.set_accepts_player_input(true)
	startup.player.set_change_equipment_enabled(false)
	check(bag.try_unequip(owner,gear,Gear.Slot.TORSO)==Gear.Result.ACTION_LOCKED
		and gear.equipped(Gear.Slot.TORSO)==cloth,"真实角色 ChangeEquipment 动作位禁止卸布衣")
	startup.player.set_change_equipment_enabled(true)
	check(startup.player.inventory_fresh_stats(actor)==before and before==[100,40,10,6,6,4,8,4],
		"两件真实初始资源没有属性加成，事务不改读数")
