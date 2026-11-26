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
	_check_green(screen,picker,actions,category)
	picker.get_node("Dwarf").pressed.emit()
	need(screen._race_views.Dwarf.cloak_selected==-1, "矮人重新进场清除旧披风")
	var original_sets: Array = screen._cloak.options[1].sprite_sets
	need(Cloak.resolve_guid(original_sets,3,3)=="7efd31b604e44b0438114300f978b497", "厚斗篷 Left/NW 用 clock8")
	need(Cloak.resolve_guid(original_sets,3,4)=="2da18e60080354143b107b6875d7151e", "厚斗篷 Right 未启用，NW 回 Base SW")
	if not OS.get_environment("FANTASYWORD_WORKBENCH_BAG").is_empty():
		_check_backpack(screen,picker,actions,truth)
	screen.free()
	_finish()

func _check_green(screen: Control, picker: Node, actions: Node, category: Button) -> void:
	for race in ["Goblin","Orc"]:
		picker.get_node(race).pressed.emit()
		var actor: Node2D = screen._race_views[race]
		var material: ShaderMaterial = actor.composite
		need(screen._category==1 and actor.supports_cloak() and not category.disabled
			and actor.cloak_selected==-1 and screen._cloak_badges[0].visible, race+" 保留原类别且清空前角色的装备")
		if not actor.supports_cloak(): continue
		for option in 2:
			var sets: Array = screen._cloak.options[option].sprite_sets
			var expect := [sets[0][0],sets[0][1],sets[0][2] if sets[0][2]!=null else sets[0][0],
				sets[0][3] if sets[0][3]!=null else (sets[0][1] if sets[0][1]!=null else sets[0][0])]
			screen._cloak_slots.get_node(["EquipTravelCloak","EquipHeavyCloak"][option]).pressed.emit()
			need(actor.cloak_selected==option and screen._cloak_badges[option+1].visible
				and material.get_shader_parameter("enabled_cloak"), race+" 原目录装备状态与标记")
			for action_key in actor._maps:
				actions.get_node(action_key).pressed.emit()
				for direction in 4:
					screen._select_direction(direction)
					need(actor.cloak_texture_guid==expect[direction], race+" "+action_key+" 显式方向换图")
					var sequence: Dictionary = actor.playback._actions[action_key]
					for frame in range(1,sequence.times.size()):
						var prev: Texture2D = actor.sprite.texture
						actor.animator.seek(float(sequence.times[frame])+0.00001,true)
						var row := direction if prev == actor.sprite.texture else floori(actor.sprite.texture.region.position.y/32.0)
						# 一直重复同一 Sprite 时保留前次实际行，不强制套用方向号。
						var current: String = actor.cloak_texture_guid
						if prev != actor.sprite.texture:
							need(current==expect[row], race+" "+action_key+" 源 Sprite 变化后采用实际行")
						var tex: Texture2D = material.get_shader_parameter("cloak_map")
						need(tex!=null and tex==screen._cloak._textures.get(current) and tex.get_image().get_pixel(0,31).a==0.0,
							race+" 原零 UV 采样角透明")
		screen._cloak_slots.get_node("RemoveCloak").pressed.emit()
		need(actor.cloak_selected==-1 and not material.get_shader_parameter("enabled_cloak")
			and screen._cloak_badges[0].visible and material.get_shader_parameter("enabled_cloth"), race+" 卸下不改布衣")

func _check_backpack(screen: Control, picker: Node, actions: Node, truth: Dictionary) -> void:
	var category := screen.find_child("BagCategory",true,false) as Button
	var equip := screen.find_child("EquipBag",true,false) as Button
	var remove := screen.find_child("RemoveBag",true,false) as Button
	need(category != null and equip != null and remove != null,"原工作台小背包入口")
	if category == null or equip == null or remove == null: return
	# Unity Backpack asset uses these four locked bottom-origin 32x32 slices
	# from two 160x128 atlases. This oracle is independent of the binder table.
	var bottoms := [0.75,0.5,0.25,0.0]
	var expected_front: Texture2D
	var expected_back: Texture2D
	picker.get_node("Human").pressed.emit()
	category.pressed.emit()
	# Compare actual atlas hashes through the original Human binding (shares
	# asset ownership), but independently assert every facing rectangle.
	equip.pressed.emit()
	expected_front = screen._material.get_shader_parameter("bag_map")
	screen._select_direction(2)
	expected_back = screen._material.get_shader_parameter("bag_map")
	need(expected_front != null and expected_back != null and expected_front != expected_back,"原独立前后图集")
	for race in ["Dwarf","Elf"]:
		picker.get_node(race).pressed.emit()
		var actor: Node2D = screen._race_views[race]
		var material: ShaderMaterial = actor.composite
		need(not category.disabled and screen._bag_slots.visible and not actor.bag_worn
			and not material.get_shader_parameter("enabled_bag"),race+" 进场背包栏保持且新角色为空")
		equip.pressed.emit()
		need(actor.bag_worn and screen._bag_badges[1].visible and "小背包" in screen._details.text,
			race+" 点击装上显示原名称与装备标记")
		need(material.get_shader_parameter("enabled_cloth") and not material.get_shader_parameter("enabled_cloak"),
			race+" 背包不改布衣和披风槽")
		for key in truth[race]:
			actions.get_node(key).pressed.emit()
			for entry in truth[race][key]:
				var label := int(entry[1])
				var facing := int(entry[4])
				actor.playback.set_direction(int(entry[0]))
				if label == 0: actor.play(key)
				else: actor.animator.seek(float(actor.playback._actions[key].times[label])+0.00001,true)
				var rect: Vector4 = material.get_shader_parameter("bag_rect")
				var expected_rect := Vector4(0,bottoms[facing],0.2,bottoms[facing]+0.25)
				need(actor.playback.current_label==label and material.get_shader_parameter("enabled_bag") and
					rect.is_equal_approx(expected_rect) and
					material.get_shader_parameter("bag_map") == (expected_front if facing < 2 else expected_back),
					"%s %s %s:%s 原躯干朝向背包裁切" % [race,key,entry[0],label])
		remove.pressed.emit()
		need(not actor.bag_worn and not material.get_shader_parameter("enabled_bag") and screen._bag_badges[0].visible,
			race+" 卸下仅清除背包槽")
	picker.get_node("Goblin").pressed.emit()
	need(category.disabled and not screen._race_views.Goblin.supports_bag(),"零UV角色还不算背包呈现验收")

func _finish() -> void:
	print(("PASS" if fails==0 else "FAIL")+" 换装工作台披风采样：%d/%d" % [checks-fails,checks])
	quit(int(fails!=0))
