extends SceneTree
const Capture := preload("res://game_core/persistence/source_inventory_save_capture.gd")
const Bags := preload("res://game_core/inventory/source_inventory_bags.gd")
const Money := preload("res://game_core/inventory/source_party_money.gd")
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Character := preload("res://gameplay/clickmovetest/source_character_view.gd")
const Inventory := preload("res://gameplay/clickmovetest/source_inventory_view.gd")
const Gear := preload("res://game_core/inventory/source_character_equipment.gd")
var checked := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checked+=1
	if not ok:
		failed+=1
		printerr("FAIL ",label)

func run() -> void:
	var bags := Bags.new()
	var money := Money.new()
	var spear := Resource.new()
	spear.resource_name="fixture spear"
	var registry := {Gear.SPEAR:spear}
	check(Capture.capture(bags,money,registry)=={"ok":true,"block":{"inventories":[]}},"未实例化不生成虚假库存")
	check(money.money()==0 and owner_row(Capture.capture(bags,money,registry),0,"default").money==0,
		"原金钱查询按需创建默认队伍 inventory，即使为零")
	var party := bags.party_owner()
	var character := bags.character_owner("fixture")
	var corpse := bags.corpse_owner("fixture")
	money.add(8)
	bags.add(character,spear,2)
	bags.add(party,spear)
	bags.add(corpse,spear)
	var snapshot := Capture.capture(bags,money,registry)
	check(snapshot.get("ok",false) and owner_row(snapshot,0,"default").money==8
		and owner_row(snapshot,1,"fixture").items==[{"guid":Gear.SPEAR,"quantity":2}]
		and owner_row(snapshot,4,"fixture").items==[{"guid":Gear.SPEAR,"quantity":1}],"使用原 ownerKind/ownerId、钱和稳定物品标识")
	var impostor := Resource.new()
	impostor.resource_name=spear.resource_name
	bags.add(character,impostor)
	var refusal := Capture.capture(bags,money,registry)
	check(not refusal.ok and refusal.reason=="unregistered_item" and not refusal.has("block")
		and bags.count(character,impostor)==1 and owner_row(snapshot,1,"fixture").items.size()==1,
		"同名无登记资源拒绝整块，不改运行时包或上次快照")
	check(not Capture.capture(bags,money,{Gear.SPEAR:spear,Gear.CLOTH:spear}).ok,"同一资源的歧义登记拒绝")
	check_restore(bags,money,registry,snapshot)
	if not OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		await verify_f5()
	else:
		print("SKIP 私有原场景背包快照")
	print("%s 原背包快照采集与恢复：%d/%d（无磁盘）" % ["PASS" if failed==0 else "FAIL",checked-failed,checked])
	quit(1 if failed else 0)

func check_restore(bags: Bags,money: Money,registry: Dictionary,snapshot: Dictionary) -> void:
	var events := []
	bags.item_added.connect(func(_owner,_item,_quantity,_transfer): events.append("added"))
	bags.item_removed.connect(func(_owner,_item,_quantity,_transfer): events.append("removed"))
	money.changed.connect(func(_value): events.append("money"))
	money.amount_changed.connect(func(_added,_amount): events.append("money_transaction"))
	var spear: Resource = registry[Gear.SPEAR]
	check(Capture.restore(snapshot.block,bags,money,registry).ok
		and Capture.capture(bags,money,registry)==snapshot and events.is_empty(),"完整恢复清掉后来项，静默回环")
	var owner := bags.character_owner("fixture")
	check(bags.entries(owner)[0].item==spear,"恢复使用已登记原实例")
	var bad: Dictionary = snapshot.block.duplicate(true)
	# 先通过可写队伍金钱，再给晚到的未知物品；整块都不提交。
	bad.inventories.reverse()
	var party: Dictionary = owner_row({"block":bad},0,"default")
	party.money=999
	bad.inventories.erase(party)
	bad.inventories.push_front(party)
	bad.inventories[-1].items.append({"guid":"0".repeat(32),"quantity":1})
	check(not Capture.restore(bad,bags,money,registry).ok and Capture.capture(bags,money,registry)==snapshot
		and events.is_empty(),"晚到的未知 GUID 不部分恢复前面行或金钱")
	bad=snapshot.block.duplicate(true)
	bad.inventories.append(bad.inventories[0])
	check(not Capture.restore(bad,bags,money,registry).ok,"拒绝重复 owner")
	bad=snapshot.block.duplicate(true)
	bad.inventories[0].items.append(bad.inventories[0].items[0])
	check(not Capture.restore(bad,bags,money,registry).ok and Capture.capture(bags,money,registry)==snapshot,
		"拒绝重复 GUID，保留原库存")
	check(bags.remove(owner,spear,2) and bags.entries(owner).is_empty()
		and bags.add(owner,spear,3) and bags.count(owner,spear)==3 and bags.entries(owner).size()==1
		and events==["removed","added"],"恢复后实际增删仍使用重建索引并正常发事件")
	check(Capture.restore({"inventories":[]},bags,money,registry).ok
		and Capture.capture(bags,money,registry).block.inventories.is_empty(),"空快照清除全部，但不创建默认队伍")

func owner_row(result: Dictionary, kind: int, id: String) -> Dictionary:
	for row: Dictionary in result.get("block",{}).get("inventories",[]):
		if row.ownerKind==kind and row.ownerId==id: return row
	return {"items":[],"money":-1}

func verify_f5() -> void:
	root.size=Vector2i(960,540)
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"正式 F5")
	await scene_changed
	await process_frame
	var boot := current_scene as Boot
	var gear: Gear = boot.player.source_equipment() if boot!=null and boot.player!=null else null
	if gear==null or boot.inventory_bags==null:
		check(false,"已挂载正式库存和角色装备")
		return
	var start := boot.capture_source_inventory()
	check(start.ok and owner_row(start,1,"player").items.is_empty(),"装备中的长矛还不是背包条目")
	var owner := boot.primary_bag_owner(boot.scene.actor)
	check(owner=="Character:player" and boot.inventory_bags.try_unequip(owner,gear,Gear.Slot.WEAPON)==Gear.Result.VALID,
		"实际装备操作把长矛放入正式原角色背包")
	var result := boot.capture_source_inventory()
	check(result.ok and owner_row(result,1,"player").items==[{"guid":Gear.SPEAR,"quantity":1}],
		"原登记长矛稳定 GUID 进入当前存档投影")
	boot.inventory_bags.transfer_character_inventory_to_corpse("player")
	var after := boot.capture_source_inventory()
	check(after.ok and owner_row(after,1,"player").items.is_empty()
		and owner_row(after,4,"player").items==[{"guid":Gear.SPEAR,"quantity":1}]
		and owner_row(result,1,"player").items.size()==1,"真实转移路径使用角色与尸体分别快照")
	boot.party_money.add(31)
	boot.inventory_bags.add(boot.inventory_bags.party_owner(),gear.item_for_guid(Gear.CLOTH))
	var changed := boot.capture_source_inventory()
	check(owner_row(changed,0,"default").money==31,"真实队伍库存变化")
	check(boot.restore_source_inventory(after.block).ok and boot.capture_source_inventory()==after
		and boot.inventory_bags.entries(boot.inventory_bags.corpse_owner("player"))[0].item==gear.item_for_guid(Gear.SPEAR),
		"正式 F5 所有者恢复已转移长矛和金钱快照，使用同一资源")

	if boot.pause_root==null or not FileAccess.file_exists(
			OS.get_environment("FORMAL_PAUSE_SOURCE").path_join("item-details-layout.json")):
		print("SKIP 暂停角色/背包及原物品日志恢复联测需要对应私有资源")
	else:
		await verify_pause_and_overlay(boot,owner,gear.item_for_guid(Gear.CLOTH))
	boot.scene.queue_free()
	check(boot.capture_source_inventory().get("reason")=="inventory_owner_unavailable"
		and boot.restore_source_inventory(after.block).get("reason")=="inventory_owner_unavailable",
		"原场景退出时不对残留库存采集或恢复")

func verify_pause_and_overlay(boot: Boot, owner: String, cloth: Resource) -> void:
	var log := boot.inventory_event_log
	if not is_instance_valid(log):
		check(false,"正式 F5 原库存日志已安装")
		return
	log.hide()
	log.show()
	log.set_process(false)
	var money := boot.party_money
	var bags := boot.inventory_bags
	money.add(8)
	bags.add(owner,cloth,2,Bags.Transfer.CHEST)
	var saved := boot.capture_source_inventory()
	if not saved.ok:
		check(false,"正式 F5 在真实库存事件之后采集")
		return
	# Actual panel show first reads unsaved values; its cached instance must
	# re-read the same owners during the next show after silent restore.
	money.add(22)
	bags.remove(owner,cloth,2,Bags.Transfer.COMMAND)
	var neutral:=Vector2(460,255)
	pointer(neutral)
	click(neutral)
	tap(KEY_ESCAPE)
	await choose(Vector2(40,150))
	var character := boot.pause_root.stack.top() as Character
	check(character!=null and character.character_data().currency=="30","角色页读取正式队伍余额")
	tap(KEY_ESCAPE)
	log.hide()
	log.show()
	var event_counts := [0,0,0,0]
	money.changed.connect(func(_value): event_counts[0]+=1)
	money.amount_changed.connect(func(_add,_amount): event_counts[1]+=1)
	bags.item_added.connect(func(_owner,_item,_quantity,_transfer): event_counts[2]+=1)
	bags.item_removed.connect(func(_owner,_item,_quantity,_transfer): event_counts[3]+=1)
	check(boot.restore_source_inventory(saved.block).ok and boot.capture_source_inventory()==saved
		and log._order.is_empty() and event_counts==[0,0,0,0],
		"原字段/背包替换不发任何事务或余额事件、不污染正式原日志")
	await choose(Vector2(40,150))
	var restored := boot.pause_root.stack.top() as Character
	check(restored!=null and restored.character_data().currency=="8","重新打开原角色页读取恢复后的余额")
	tap(KEY_ESCAPE)
	await choose(Vector2(40,190))
	var panel := boot.pause_root.stack.top() as Inventory
	if panel==null:
		check(false,"打开实际 Items 面板")
		return
	var p := panel.action_rect(38).get_center()*.5
	click(p)
	var row := panel.model.cell(0)
	check(panel.model.category==2 and row.get("item")==cloth and row.get("quantity")==2,
		"原 Items 页按 Gear 分类读取恢复后的正式背包行")
	tap(KEY_ESCAPE)
	tap(KEY_ESCAPE)
	money.add(3)
	bags.add(owner,cloth,4,Bags.Transfer.CHEST)
	check(not paused and money.money()==11 and bags.count(owner,cloth)==6
		and event_counts==[1,1,1,0] and log._order==[0,1]
		and log._rows[0].full=="+3 [INVALID_SHORTNAME]" and log._rows[1].full=="+4 基础布衣",
		"恢复后实际金钱和物品增量各进入原日志一次，未丢失监听")

func choose(p: Vector2) -> void:
	pointer(p)
	await process_frame
	await process_frame
	tap(KEY_ENTER)
	await process_frame
	await process_frame

func pointer(p: Vector2) -> void:
	var move:=InputEventMouseMotion.new()
	move.device=0
	move.position=p
	move.relative=Vector2.ONE
	root.push_input(move,true)

func click(p: Vector2) -> void:
	for down in [true,false]:
		var mouse:=InputEventMouseButton.new()
		mouse.device=0
		mouse.button_index=MOUSE_BUTTON_LEFT
		mouse.position=p
		mouse.pressed=down
		root.push_input(mouse,true)

func tap(code: Key) -> void:
	for down in [true,false]:
		var e:=InputEventKey.new()
		e.physical_keycode=code
		e.pressed=down
		root.push_input(e,true)
