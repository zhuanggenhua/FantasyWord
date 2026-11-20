extends SceneTree
const Bags := preload("res://game_core/inventory/source_inventory_bags.gd")
const Model := preload("res://game_core/ui/source_inventory_bag_state.gd")
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")

class ItemFixture extends Resource:
	var category: int
	func _init(kind: int) -> void: category=kind

var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if ok: return
	failures+=1
	printerr("FAIL ",message)

func kind_of(item: ItemFixture) -> int: return item.category

func run() -> void:
	var bags := Bags.new()
	var actor := Node2D.new()
	root.add_child(actor)
	var owner := bags.character_owner(" player ")
	var team := bags.party_owner()
	check(owner=="Character:player" and team=="Party:default"
		and bags.character_owner("default")!=team,"stable typed owner independent of party")
	var z := ItemFixture.new(Model.Category.CONSUMABLE)
	z.resource_name="Zulu"
	var a := ItemFixture.new(Model.Category.CONSUMABLE)
	a.resource_name="Alpha"
	var r := ItemFixture.new(Model.Category.RESOURCE)
	var events: Array = []
	var track := func(key: String,item: Resource,qty: int,transfer: int):
		events.append([key,item,qty,transfer])
	bags.item_added.connect(track)
	bags.item_removed.connect(track)
	check(bags.entries(owner).is_empty() and not bags.remove(owner,z),"unseeded fresh actor bag; no write on missing removal")
	check(not bags.add(owner,z,0) and not bags.add(owner,null,1) and not bags.add("",z)
		and events.is_empty(),"invalid writes rejected without event")
	check(bags.add(team,z,5,Bags.Transfer.CHEST) and bags.count(owner,z)==0,"shared party cannot seed the character owner")
	check(bags.add(owner,z,1) and bags.add(owner,r,3) and bags.add(owner,a,2)
		and bags.add(owner,z,2) and bags.count(owner,z)==3,"add accumulates exact item identity")
	var snapshot := bags.entries(owner)
	snapshot[0].quantity=500
	check(bags.count(owner,z)==3,"returned rows are a snapshot, not storage aliases")
	var model := Model.new()
	var details: Array = []
	model.details_opened.connect(func(item): details.append(item))
	model.details_closed.connect(func(): details.append("closed"))
	check(model.show(bags,owner,actor,kind_of) and model.selected==0 and details==[z],
		"fresh focus selects first reversed grid slot; selection reports but does not use")
	check(model.cell(0).item==z and model.cell(1).item==a and model.cell(2).is_empty(),
		"category filters runtime row order, not names")
	check(model.activation(0)=={"item":z,"actor":actor,"target":actor,"location":Model.Location.BAG}
		and model.activation(2).is_empty() and bags.count(owner,z)==3,"explicit use target and Bag location, no implicit consumption")
	check(model.select(2) and details.slice(-2)==["closed",null],"empty focus clears details")
	check(model.select(0) and model.set_category(Model.Category.RESOURCE)
		and details.slice(-2)==[null,r] and model.cell(0).quantity==3,
		"selection survives category refresh; clear then refill notifies details")
	check(not model.set_category(-1) and model.category==Model.Category.RESOURCE,"unknown category cannot rewrite state")
	check(bags.remove(owner,z,2,Bags.Transfer.USE) and bags.count(owner,z)==1
		and events.back()==[owner,z,2,Bags.Transfer.USE],"partial removal emits actual delta")
	check(bags.remove(owner,z,100,Bags.Transfer.USE) and bags.count(owner,z)==0
		and events.back()==[owner,z,1,Bags.Transfer.USE] and bags.count(team,z)==5,"clamped removal erases only matching owner")
	var replacement := ItemFixture.new(Model.Category.CONSUMABLE)
	check(bags.add(owner,replacement) and bags.entries(owner)[0].item==replacement,"reinsert uses freed dictionary row")
	for i in range(32): bags.add(owner,ItemFixture.new(Model.Category.CONSUMABLE))
	check(model.set_category(Model.Category.CONSUMABLE) and model.overflow and not model.cell(29).is_empty()
		and model.cell(30).is_empty() and bags.entries(owner).size()==35,"30 slots limit only rendered category, not storage")
	var empty := Model.new()
	check(empty.show(bags,bags.character_owner("another"),actor,kind_of) and empty.selected==0
		and empty.activation(0).is_empty() and not empty.overflow,"fresh no-item route remains focusable without fabricated loot")
	actor.free()
	check(model.activation(0).is_empty(),"destroyed opener cannot be sent to item use")

	if OS.get_environment("FORMAL_PAUSE_SOURCE").is_empty():
		print("SKIP Inventory live F5 requires pinned private source files")
	else:
		check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"normal F5 route")
		await scene_changed
		await process_frame
		var startup := current_scene as Boot
		check(startup!=null and startup.inventory_bags!=null and startup.player!=null,"live startup constructs a per-session bag")
		if startup!=null and startup.inventory_bags!=null and startup.player!=null:
			var primary: Node=startup.player.get_current_controlled_character_or_player_instance()
			var live_owner := startup.primary_bag_owner(primary)
			check(live_owner=="Character:player" and startup.persistables.identifier_for(primary)=="player"
				and startup.primary_bag_owner(startup).is_empty(),"live owner uses actual persistence binding, refuses other nodes")
			check(startup.inventory_bags.entries(live_owner).is_empty() and startup.party_money.money()==0,
				"actual startup seeds neither authored equipment into bag nor party purse")
	print("%s source Inventory bag runtime: %d/%d"%["PASS" if failures==0 else "FAIL",checks-failures,checks])
	quit(1 if failures else 0)
