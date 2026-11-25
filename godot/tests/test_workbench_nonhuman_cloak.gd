extends SceneTree
const Cloak := preload("res://gameplay/equipment_workbench/cloak_preview.gd")
const Scene := preload("res://gameplay/equipment_workbench/equipment_system_demo.tscn")
var checks := 0
var fails := 0

func _initialize() -> void: call_deferred("run")

func need(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		if fails < 20: printerr("FAIL ", label)
		fails += 1

func run() -> void:
	# 无私有资源时仍覆盖变体门槛；贴图身份与矩阵只验原资源模式。
	var sets := [["base-se","base-sw",null,null], [null,null,null,null], [null,null,null,null],
		["left-se","left-sw","left-ne","left-nw"], [null,"right-sw","right-ne","right-nw"]]
	need(Cloak.resolve_guid(sets,3,3)=="left-nw", "Left 有 SE 时允许选自己的 NW")
	need(Cloak.resolve_guid(sets,3,4)=="base-sw", "Right 缺 SE 整组禁用，NW 回退 Base SW")
	need(Cloak.resolve_guid(sets,2,0)=="base-se", "Base 无 NE 则回 SE")
	var path := OS.get_environment("FANTASYWORD_WORKBENCH_CLOAK_ORACLE")
	if path.is_empty():
		_finish()
		return
	if FileAccess.get_sha256(path)!="b636146f453a02ce5357563083ee1395eb104795f3a5f15947ed66eb9659372d":
		need(false, "矮人和精灵披风原帧验算合同不匹配")
		_finish()
		return
	var truth: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var screen := Scene.instantiate()
	root.add_child(screen)
	await process_frame
	need(screen.ready_for_preview, screen.last_error)
	var category := screen.find_child("CloakCategory", true, false) as Button
	var picker := screen.find_child("SourceCharacterPicker", true, false)
	var actions := screen.find_child("SourceActionRows", true, false)
	if not screen.ready_for_preview or category==null or picker==null or actions==null:
		quit(2)
		return
	category.pressed.emit()
	for race in ["Dwarf","Elf"]:
		picker.get_node(race).pressed.emit()
		var actor: Node2D = screen._race_views[race]
		need(screen._category==1 and not category.disabled and screen._cloak_slots.visible, race+" 原披风类别仍打开")
		need(actor.cloak_selected==-1 and not actor.composite.get_shader_parameter("enabled_cloak") and
			actor.composite.get_shader_parameter("enabled_cloth"), race+" 更换角色恢复默认布衣")
		for option in 2:
			screen._cloak_slots.get_node(["EquipTravelCloak","EquipHeavyCloak"][option]).pressed.emit()
			need(actor.cloak_selected==option and screen._cloak_badges[option+1].visible
				and screen._cloak.options[option].name in screen._details.text, "实点披风选择与详情")
			for key in truth[race]:
				actions.get_node(key).pressed.emit()
				for row in truth[race][key]:
					var d := int(row[0])
					var label := int(row[1])
					var times: Array = actor.playback._actions[key].times
					actor.playback.set_direction(d)
					if label==0: actor.play(key)
					else: actor.animator.seek(float(times[label])+0.00001, true)
					var guid: String = row[6+option]
					need(actor.playback.current_label==label and actor._cursor.row_index==int(row[2]) and
						actor._cursor.frame_index==int(row[3]) and actor.cloak_texture_guid==guid and
						actor.composite.get_shader_parameter("enabled_cloak") and
						actor.composite.get_shader_parameter("cloak_map")==screen._cloak._textures[guid] and
						actor.composite.get_shader_parameter("body_map")==actor._maps[key].body,
						"%s %s d%d f%d opt%d expected:%s actual:%s label:%s row:%s col:%s" % [race,key,d,label,option,guid,actor.cloak_texture_guid,actor.playback.current_label,actor._cursor.row_index,actor._cursor.frame_index])
		if race=="Elf":
			screen._cloak_slots.get_node("RemoveCloak").pressed.emit()
			need(actor.cloak_selected==-1 and not actor.composite.get_shader_parameter("enabled_cloak")
				and screen._cloak_badges[0].visible, "卸下披风且不动布衣")
	picker.get_node("Human").pressed.emit()
	need(screen._category==1 and screen._cloak.selected==-1, "回到人类仍在披风栏，无旧披风")
	picker.get_node("Goblin").pressed.emit()
	need(category.disabled and screen._category==0 and not screen._race_views.Goblin.supports_cloak(), "地精暂不作为披风画面已验收")
	picker.get_node("Dwarf").pressed.emit()
	need(screen._race_views.Dwarf.cloak_selected==-1, "矮人重新进场清除旧披风")
	var original_sets: Array = screen._cloak.options[1].sprite_sets
	need(Cloak.resolve_guid(original_sets,3,3)=="7efd31b604e44b0438114300f978b497", "厚斗篷 Left/NW 用 clock8")
	need(Cloak.resolve_guid(original_sets,3,4)=="2da18e60080354143b107b6875d7151e", "厚斗篷 Right 未启用，NW 回 Base SW")
	screen.free()
	_finish()

func _finish() -> void:
	print(("PASS" if fails==0 else "FAIL")+" 换装工作台披风采样：%d/%d" % [checks-fails,checks])
	quit(int(fails!=0))
