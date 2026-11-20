extends SceneTree
const State := preload("res://game_core/ui/source_character_panel_state.gd")
const Money := preload("res://game_core/inventory/source_party_money.gd")
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
var n := 0
var bad := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	n+=1
	if not ok: bad+=1; printerr("FAIL ",label)
func run() -> void:
	var owner := Money.new()
	var actor := Node.new()
	var updated := {"count":0,"used":0,"stats":[100,40,10,6,6,4,8,4]}
	var reader := func(_actor):
		return {"display_name":"Fixture","level":2,"experience":18,"next_level_experience":45,
			"available_points":3-updated.used,"base_stats":updated.stats}
	var state := State.new()
	check(state.bind(reader,owner.money,func(target,spent,changes):
		if target!=actor: return false
		updated.count+=1
		updated.used+=spent
		for i in changes.size(): updated.stats[i]+=changes[i]
		return true),"separate actor and party routes")
	check(state.show(actor) and state.visible_data().experience=="27"
		and state.visible_data().skill_points=="3" and state.visible_data().rows.size()==8,"actual panel field shapes")
	check(not state.apply() and not state.remove_point(0) and not state.add_point(8),"no empty writes, no attack speed row")
	check(state.add_point(0) and state.add_point(0) and state.add_point(2) and not state.add_point(1)
		and state.visible_data().rows[0]=="100 (+2)" and state.visible_data().apply=="应用 3 点"
		and updated.stats[0]==100 and updated.count==0,"preview consumes only temporary budget")
	check(state.remove_point(0) and state.visible_data().skill_points=="1" and state.apply()
		and updated.used==2 and updated.count==1 and state.visible_data().rows[0]=="101"
		and state.visible_data().rows[2]=="11" and state.visible_data().apply=="应用 0 点","Apply commits used points and refreshed actor value once")
	owner.add(23); owner.add(-3); owner.remove(999); owner.add(17)
	check(state.visible_data().currency=="17","currency belongs to party, with original positive-only and floor zero")
	check(state.add_point(7),"remaining point for pending preview")
	state.clear()
	check(state.visible_data().is_empty() and state.show(actor) and updated.stats[7]==4
		and state.visible_data().skill_points=="1","hide discards preview; reopening rereads actor budget")
	check(state.show(null) and state.visible_data()["class"]=="" and state.visible_data().level==""
		and state.visible_data().currency=="17" and state.visible_data().rows==["0","0","0","0","0","0","0","0"],
		"missing actor clears fields but does not hide global money")
	actor.free()
	var dir := OS.get_environment("FORMAL_PAUSE_SOURCE")
	if dir!="" and FileAccess.file_exists(dir.path_join("character-contract.json")) and OS.get_environment("FORMAL_SURFACE_RULES")!="":
		await live(dir)
	else:
		print("SKIP licensed original fresh player read")
	print("%s source UICharacter state: %d/%d"%["PASS" if bad==0 else "FAIL",n-bad,n])
	quit(1 if bad else 0)

func live(dir: String) -> void:
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("character-contract.json")))
	var main: String = ProjectSettings.get_setting("application/run/main_scene")
	check(change_scene_to_file(main)==OK,"real startup entry")
	await scene_changed
	await process_frame
	var startup := current_scene as Boot
	if startup==null or startup.player==null or startup.party_money==null:
		check(false,"actual source actor and party owners")
		return
	var owner := startup.player
	var actor := owner.get_current_controlled_character_or_player_instance()
	var state := State.new()
	check(state.bind(owner.character_menu_fresh_values.bind(profile),startup.party_money.money)
		and state.show(actor),"locked snapshot comes from real ClickMoveTest actor")
	var data := state.visible_data()
	check(data.get("class")=="玩家角色配置" and data.get("level")=="1" and data.get("experience")=="0"
		and data.get("skill_points")=="0" and data.get("currency")=="0"
		and data.get("rows")==["100","40","10","6","6","4","8","4"],"fresh asset name and all original displays")
	check(not state.add_point(1) and not state.apply(),"zero available points cannot invent actor growth")
	var hooks := owner.damage_hooks()
	hooks.apply_current_health_delta.call(-17,0,null,null)
	check(owner.current_health()==83 and state.visible_data().rows[0]=="100","Health row reads effective base, not damaged current HP")
	check(not state.show(startup.scene.training_target),"contract refuses an unrelated actor")
