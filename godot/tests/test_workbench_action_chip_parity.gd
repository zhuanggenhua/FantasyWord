extends SceneTree

const Scene := preload("res://gameplay/equipment_workbench/equipment_system_demo.tscn")
# 独立读取锁定 FrameData 和动作数据库后生成。位序为人类、矮人、精灵、地精、兽人。
const RACES := ["Human","Dwarf","Elf","Goblin","Orc"]
const EXPECTED := [
	["Idle","待机","",31,31],
	["Walk","行走","",31,31],
	["Wait","","Wait·缺帧",0,31],
	["Attack","攻击","",31,31],
	["ChargedAttack","蓄力","",31,31],
	["Dmg","受击","",31,31],
	["Dmg2","Dmg2","Dmg2·缺帧",1,1],
	["SlashAttack","挥砍","挥砍·缺帧",1,1],
	["Jump","跳跃","",31,31],
	["SoulDie","灵魂消散","灵魂消散·缺帧",1,31],
	["SpinDie","旋转死亡","旋转死亡·缺帧",15,31],
	["Die","死亡","死亡·缺帧",16,31],
	["Harvest","采集","",31,31],
	["Harvesting","","收获·无真人帧",0,0],
	["Chopping","砍伐","",31,31],
	["Mining","挖矿","",31,31],
	["Digging","","挖掘·无真人帧",0,0],
	["TillingSoil","","耕地·无真人帧",0,0],
	["SowingSeeds","","播种·无真人帧",0,0],
	["Watering","","浇水·无真人帧",0,0],
	["FillingBucket","","装水·无真人帧",0,0],
	["Butchering","","屠宰·无真人帧",0,0],
	["Milking","","挤奶·无真人帧",0,0],
	["Shearing","","剪毛·无真人帧",0,0],
	["AnvilWorking","铁砧工作","",31,31],
	["JewelryWorkshopWorking","珠宝工作","",31,31],
	["LaboratoryWorking","炼金工作","",31,31],
	["WoodworkBenchWorking","木工台工作","",31,31],
]
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func expect(ok: bool, item: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",item)

func run() -> void:
	if OS.get_environment("FANTASYWORD_WORKBENCH_DWARF_ELF").is_empty() or OS.get_environment("FANTASYWORD_WORKBENCH_NONHUMAN").is_empty():
		print("SKIP 原五角色动作格需锁定私有原素材")
		quit()
		return
	var screen := Scene.instantiate()
	root.add_child(screen)
	await process_frame
	if not screen.ready_for_preview:
		printerr("Could not start original fixture: ", screen.last_error)
		quit(2)
		return
	var picker := screen.find_child("SourceCharacterPicker", true, false)
	var actions := screen.find_child("SourceActionRows", true, false)
	for race in ["Goblin","Orc","Dwarf","Elf","Human"]:
		picker.get_node(race).pressed.emit()
		var actor: Node2D = screen._human if race=="Human" else screen._race_views[race]
		var defs := {}
		var mask := 1 << RACES.find(race)
		for row in EXPECTED:
			var exact: bool = (int(row[3]) & mask) != 0
			defs[row[0]] = {"exact":exact, "enabled":(int(row[4]) & mask) != 0, "text":row[1] if exact else row[2]}
		expect(actions.get_children().map(func(n):return str(n.name))==defs.keys(),race+" 原动作顺序")
		for key in defs:
			var expected: Dictionary = defs[key]
			var button: Button = actions.get_node(key)
			expect(button.text==expected.text and button.tooltip_text==expected.text, race+" "+key+" 原标签及提示")
			expect(button.disabled!=expected.enabled, race+" "+key+" 可选性")
			var font_size: int = button.get_theme_font_size("font_size")
			var width: float = screen._font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			expect(font_size>=11 and font_size<=16 and (font_size==11 or width<=76.0), race+" "+key+" 字号适配")
		actions.get_node("Walk").pressed.emit()
		screen._select_direction(3)
		screen._set_cloth(false)
		actor.animator.seek(0.1,true)
		expect(actor.playback.current_action=="Walk" and actor.playback.current_direction==3,race+" 动作和方向控制")
		var exact := "Die" if race=="Orc" else "SpinDie"
		for key in defs:
			if not defs[key].enabled or defs[key].exact: continue
			var current_details: String = screen._details.text
			var texture: Texture2D = actor.sprite.texture
			var position: float = actor.animator.current_animation_position
			var state: StyleBoxFlat = actions.get_node("Walk").get_theme_stylebox("normal")
			actions.get_node(key).pressed.emit()
			expect(actor.playback.current_action=="Walk" and actor.playback.current_direction==3
				and actor.sprite.texture==texture and actor.animator.current_animation_position==position
				and current_details==screen._details.text and actions.get_node("Walk").get_theme_stylebox("normal")==state
				and not actor.sprite.material.get_shader_parameter("enabled_cloth"), race+" "+key+" 回退点击不得改变状态")
		actor.animator.advance(0.15)
		expect(actor.animator.current_animation_position>0.1 and actor.playback.current_action=="Walk",race+" 回退点击不暂停当前动画")
		actions.get_node(exact).pressed.emit()
		expect(actor.playback.current_action==exact,race+" 独立原死亡动作可播放")
	screen.free()
	print(("PASS" if failures==0 else "FAIL")+" 原五角色动作格：%d/%d" % [checks-failures,checks])
	quit(int(failures!=0))
