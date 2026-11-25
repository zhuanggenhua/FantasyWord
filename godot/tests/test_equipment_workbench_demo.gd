extends SceneTree

const DEMO := preload("res://gameplay/equipment_workbench/equipment_system_demo.tscn")

const CloakPreview := preload("res://gameplay/equipment_workbench/cloak_preview.gd")

var _failures := 0
var _checks := 0
var _demo: Control

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() != "headless": root.size = Vector2i(1600, 900)
	_demo = DEMO.instantiate()
	root.add_child(_demo)
	await process_frame
	await process_frame
	var has_source := not OS.get_environment("FANTASYWORD_WORKBENCH_SOURCE").is_empty()
	_check(_demo.ready_for_preview == has_source, "有配套素材才打开预览：" + _demo.last_error)
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://gameplay/clickmovetest/source_startup.tscn", "F5 保留 ClickMoveTest")
	if not has_source or not _demo.ready_for_preview:
		_check(_demo.find_child("EquipmentSystemDemoCharacter", false, false) == null, "资源不全时不放置假角色")
		_finish()
		return
	var human := _demo.get_node("EquipmentSystemDemoCharacter")
	var mat := human.sprite.material as ShaderMaterial
	var details := _demo.find_child("CurrentDetails", true, false) as Label
	_check(not details.text.is_empty() and "待机 | 方向 东南" in details.text, "起始显示待机东南")
	_check("生命 +6" in details.text and mat.get_shader_parameter("enabled_cloth"), "起始穿布衣，显示工作台加成")
	var rows := _demo.find_child("SourceActionRows",true,false) as GridContainer
	_check(rows!=null and rows.columns==3 and rows.get_children().map(func(b):return str(b.name))==[
		"Idle","Walk","Wait","Attack","ChargedAttack","Dmg","Dmg2","SlashAttack","Jump","SoulDie","SpinDie","Die",
		"Harvest","Harvesting","Chopping","Mining","Digging","TillingSoil","SowingSeeds","Watering","FillingBucket",
		"Butchering","Milking","Shearing","AnvilWorking","JewelryWorkshopWorking","LaboratoryWorking",
		"WoodworkBenchWorking"],"实际动作格维持 28 条原数据库顺序")
	if rows!=null:
		var wait_button := rows.get_node("Wait") as Button
		var die_button := rows.get_node("Die") as Button
		var charge := rows.get_node("ChargedAttack") as Button
		var harvesting := rows.get_node("Harvesting") as Button
		_check(not wait_button.disabled and wait_button.text=="Wait·缺帧" and \
			not die_button.disabled and die_button.text=="死亡·缺帧","原回退可选但没有独立帧")
		_check(charge.text=="蓄力" and charge.disabled != _demo._charged_enabled and \
			(not charge.disabled or "尚未接入" in charge.tooltip_text), "原蓄力标签和私有已接入状态")
		_check(harvesting.disabled and harvesting.text=="收获·无真人帧","原人类缺少工作帧照原标注")
		var before_detail := details.text
		for inert in ["Wait","Die"] + (["ChargedAttack"] if charge.disabled else []):
			await _click(inert)
			_check(human.playback.current_action=="Idle" and details.text==before_detail \
				and mat.get_shader_parameter("enabled_cloth"),"不可预览动作不改当前帧、详情或装备："+inert)
	if DisplayServer.get_name() != "headless":
		var before := await _avatar_pixels(human)
		await _click("RemoveCloth")
		var after := await _avatar_pixels(human)
		_check(before != after, "只截取角色像素作穿脱差分，不以材质参数冒充画面")
		await _click("EquipCloth")
		var restored := await _avatar_pixels(human)
		_check(before == restored, "同一源帧重穿恢复相同像素")
	await _click("RemoveCloth")
	_check("当前为空" in details.text and "生命 +6" not in details.text and not mat.get_shader_parameter("enabled_cloth"), "鼠标卸下后技术层和界面一起变化")
	for action in ["Walk", "Attack", "Idle"]:
		await _click(action)
		for direction in ["SW", "NE", "NW", "SE"]:
			await _click(direction)
			var index: int = ["SE", "SW", "NE", "NW"].find(direction)
			_check(human.playback.current_action == action and human.playback.current_direction == index and not mat.get_shader_parameter("enabled_cloth"), "原动作/方向真实采样，空槽不会复穿：" + action + direction)
	await _click("EquipCloth")
	_check("生命 +6" in details.text and mat.get_shader_parameter("enabled_cloth"), "点布衣重新装备")
	await _click("NW")
	await _click("Attack")
	await _click("RemoveCloth")
	await _click("Human")
	_check("待机 | 方向 东南" in details.text and mat.get_shader_parameter("enabled_cloth"), "重选人类还原该角色的原默认")
	if _demo.find_child("CloakCategory", true, false) != null:
		await _check_cloak(human, mat, details)
	if not OS.get_environment("FANTASYWORD_WORKBENCH_BAG").is_empty():
		_check(_demo.find_child("BagCategory", true, false) != null, "完整小背包合同启用原背包类别")
		await _check_bag(human, mat, details)
	if not OS.get_environment("FANTASYWORD_WORKBENCH_HEADWEAR").is_empty():
		await _check_headwear(human, mat, details)
	if not OS.get_environment("FANTASYWORD_WORKBENCH_WEAPONS").is_empty():
		await _check_weapons(human, mat, details)
	_finish()

func _check_weapons(human: Node2D, mat: ShaderMaterial, details: Label) -> void:
	_check(mat.shader.resource_path.ends_with("equipment_weapon_subset.gdshader"), "工作台显式启用原双槽武器材质")
	await _click("Human")
	var graphics := DisplayServer.get_name() != "headless"
	var bare := PackedByteArray()
	if graphics: bare = await _avatar_pixels(human)
	_check(not mat.get_shader_parameter("weapon_fill_enabled"), "空槽不启动可选武器填充")
	await _click("WeaponCategory")
	await _click("EquipSpear")
	_check("长矛" in details.text and "力量 +2" in details.text and "智力 +1" in details.text and mat.get_shader_parameter("weapon0_enabled"), "长矛进入独立主手且显示原增益")
	var spear_only := PackedByteArray()
	if graphics:
		spear_only = await _avatar_pixels(human)
		_check(bare != spear_only, "静态长矛实际改变原人形渲染")
	await _click("ShieldCategory")
	await _click("EquipShield")
	_check("重盾" in details.text and "体质 +2" in details.text and "生命 +8" in details.text and mat.get_shader_parameter("weapon1_enabled"), "重盾进入独立副手且显示原增益")
	if graphics: _check(spear_only != await _avatar_pixels(human), "同一待机帧同时渲染实际副手重盾")
	var shield_maps: Array[Texture2D] = []
	for i in 4:
		await _click(["SE", "SW", "NE", "NW"][i])
		var anchor_main: Vector4 = mat.get_shader_parameter("weapon0_anchor_frame_uv")
		var x := 17.5 if i % 2 == 0 else 14.5
		shield_maps.append(mat.get_shader_parameter("weapon1_map"))
		_check(is_equal_approx(anchor_main.x, x/32.0) and is_equal_approx(anchor_main.y, 1.0-17.5/32.0)
			and mat.get_shader_parameter("weapon0_flip_x") == (i%2==1)
			and mat.get_shader_parameter("weapon0_depth_mode") == float(i>=2)
			and mat.get_shader_parameter("weapon1_depth_mode") == float(i<2)
			and mat.get_shader_parameter("weapon1_hand_in_front") == float(i>=2), "源待机四向锚点、静态翻转与前后关系")
	_check(shield_maps[0] != shield_maps[1] and shield_maps[1] != shield_maps[2] and shield_maps[2] != shield_maps[3], "重盾四向使用实际四张原图")
	await _click("Walk")
	human.animator.pause()
	for d in ["SE","SW","NE","NW"]:
		await _click(d)
		for frame in 4:
			human.animator.seek(frame * 0.125,true)
			_check(human.playback.current_label == frame and mat.get_shader_parameter("weapon0_enabled")
				and mat.get_shader_parameter("weapon1_enabled") == (frame % 2 == 0)
				and ((mat.get_shader_parameter("weapon1_map") == null) == (frame % 2 == 1))
				and "重盾" in details.text, "行走锚点存在才显示重盾，但仍装备：" + d + str(frame))
	await _click("Attack")
	await _click("NE")
	human.animator.pause()
	human.animator.seek(0.125,true)
	var front_map: Texture2D = mat.get_shader_parameter("weapon0_map")
	_check(front_map != null and mat.get_shader_parameter("weapon0_depth_mode") == 1.0 and not mat.get_shader_parameter("weapon0_flip_x"), "东北攻击帧 1 使用原前层序列")
	human.animator.seek(0.25,true)
	var back_map: Texture2D = mat.get_shader_parameter("weapon0_map")
	_check(human.playback.current_label == 2 and back_map != null and back_map != front_map
		and mat.get_shader_parameter("weapon0_depth_mode") == 0.0 and mat.get_shader_parameter("weapon1_enabled"), "东北攻击帧 2 切到原后层图，保留重盾")
	_check(_demo._weapons.binding_error.is_empty(), "无绑定或帧坐标错误")
	await _click("RemoveShield")
	_check(mat.get_shader_parameter("weapon0_enabled") and not mat.get_shader_parameter("weapon1_enabled")
		and "当前为空" in details.text, "单卸盾牌不移除主手")
	await _click("WeaponCategory")
	await _click("RemoveSpear")
	_check(not mat.get_shader_parameter("weapon0_enabled") and not mat.get_shader_parameter("weapon_fill_enabled"), "卸主手清掉当前序列材质")
	await _click("Human")
	if graphics: _check(bare == await _avatar_pixels(human), "同一待机帧武器卸下后恢复基准像素")
	_check(mat.get_shader_parameter("enabled_cloth"), "原布衣仍在")
	if _demo.find_child("EquipAxe",true,false) != null:
		await _check_weapon_replacements(human, mat, details)

func _check_weapon_replacements(human: Node2D, mat: ShaderMaterial, details: Label) -> void:
	var graphics := DisplayServer.get_name() != "headless"
	await _click("Human")
	await _click("WeaponCategory")
	var order: Array = _demo.find_child("EquipAxe",true,false).get_parent().get_children()
	_check(order[1].name == "EquipAxe" and order[2].name == "EquipSpear", "武器列表采用原目录战斧、长矛顺序")
	await _click("EquipSpear")
	var spear: Texture2D = mat.get_shader_parameter("weapon0_map")
	await _click("ShieldCategory")
	await _click("EquipShield")
	var heavy: Texture2D = mat.get_shader_parameter("weapon1_map")
	await _click("WeaponCategory")
	await _click("EquipAxe")
	var axe: Texture2D = mat.get_shader_parameter("weapon0_map")
	_check(axe != null and axe != spear and mat.get_shader_parameter("weapon1_map") == heavy and "力量 +3" in details.text
		and "智力" not in details.text, "替换为战斧保留副手并清掉旧长矛属性")
	await _click("EquipAxe")
	_check(mat.get_shader_parameter("weapon0_enabled") and mat.get_shader_parameter("weapon0_map") == axe, "同项再点不是切换卸下")
	await _click("SW")
	_check(mat.get_shader_parameter("weapon0_flip_x") and mat.get_shader_parameter("weapon0_map") == axe, "战斧未设置西向：静态原东南贴图镜像")
	await _click("Attack")
	await _click("NE")
	human.animator.pause()
	var silver := Color8(198,219,230)
	human.animator.seek(0.0,true)
	var atlas_front: Texture2D = mat.get_shader_parameter("weapon0_map")
	_check(atlas_front != axe and mat.get_shader_parameter("weapon0_rect").is_equal_approx(Vector4(.25,.25,.5,.5))
		and mat.get_shader_parameter("weapon0_depth_mode")==1.0, "NE Attack 标签 0 以有符号原 fileID 取 x=32")
	if graphics:
		await RenderingServer.frame_post_draw
		_check(_near_color(_avatar_texel(human,Vector2(25.5,15.5)),silver), "原东北第一帧战斧命中真实采样色")
	human.animator.seek(.125,true)
	_check(human.playback.current_label==1 and mat.get_shader_parameter("weapon0_map")==atlas_front
		and mat.get_shader_parameter("weapon0_rect").is_equal_approx(Vector4(0,.25,.25,.5)), "NE Attack 标签 1 以原 fileID 取 x=0")
	if graphics:
		await RenderingServer.frame_post_draw
		_check(_near_color(_avatar_texel(human,Vector2(23.5,12.5)),silver), "东北第二帧不会误读第一帧像素")
	human.animator.seek(.25,true)
	_check(mat.get_shader_parameter("weapon0_map")!=atlas_front and mat.get_shader_parameter("weapon0_depth_mode")==0.0
		and mat.get_shader_parameter("weapon1_enabled"), "东北后两帧进入原后层图，盾牌仍在")
	await _click("Idle")
	await _click("SE")
	await _click("ShieldCategory")
	await _click("EquipRoundShield")
	var round_east: Texture2D = mat.get_shader_parameter("weapon1_map")
	_check(round_east != null and round_east != heavy and mat.get_shader_parameter("weapon0_map")==axe
		and "生命 +6" in details.text and "生命 +8" not in details.text,"圆盾替换重盾，战斧与原属性不串槽")
	await _click("SW")
	var round_west: Texture2D = mat.get_shader_parameter("weapon1_map")
	_check(round_west!=null and round_west!=round_east and not mat.get_shader_parameter("weapon1_flip_x"), "源圆盾西南图已配置，不镜像")
	await _click("NE")
	_check(mat.get_shader_parameter("weapon1_map")==round_east and mat.get_shader_parameter("weapon1_hand_in_front")==1.0, "圆盾 NE 缺图精确回退 SE")
	if graphics:
		await _avatar_pixels(human)
		_check(_near_color(_avatar_texel(human,Vector2(12.5,16.5)),Color8(204,0,0)), "圆盾 NE 真实像素辨别回退与旧重盾")
	await _click("NW")
	_check(mat.get_shader_parameter("weapon1_map")==round_west and not mat.get_shader_parameter("weapon1_flip_x"), "圆盾 NW 缺图精确回退 SW，不镜像")
	if graphics:
		await _avatar_pixels(human)
		_check(_near_color(_avatar_texel(human,Vector2(19.5,16.5)),Color8(255,102,59)), "圆盾 NW 真实像素辨别错误东向图")
	await _click("WeaponCategory")
	await _click("RemoveSpear")
	_check(not mat.get_shader_parameter("weapon0_enabled") and mat.get_shader_parameter("weapon1_map")==round_west, "主手卸下对当前副手圆盾无影响")
	await _click("WeaponCategory")
	await _click("EquipAxe")
	await _click("ShieldCategory")
	await _click("RemoveShield")
	_check(mat.get_shader_parameter("weapon0_map")==axe and not mat.get_shader_parameter("weapon1_enabled"), "副手卸下对当前主手战斧无影响")

func _check_headwear(human: Node2D, mat: ShaderMaterial, details: Label) -> void:
	var mask_tab := _demo.find_child("MaskCategory", true, false) as Button
	_check(mask_tab != null and mask_tab.get_parent().columns == 3, "原工作台的分类网格为三列")
	if mask_tab == null: return
	await _click("Human")
	var has_cloak := _demo.find_child("CloakCategory", true, false) != null
	if has_cloak:
		await _click("CloakCategory")
		await _click("EquipTravelCloak")
	if _demo.find_child("BagCategory", true, false) != null:
		await _click("BagCategory")
		await _click("EquipBag")
	var bare := PackedByteArray()
	var graphics := DisplayServer.get_name() != "headless"
	if graphics: bare = await _avatar_pixels(human)
	_check(_head_flags(mat, false, false, true, true), "人类原发和须都出现，且不默认戴头饰")
	await _click("MaskCategory")
	await _click("EquipGoggles")
	_check(_head_flags(mat, false, true, true, true) and "智力 +2" in details.text and "魔力 +2" in details.text, "护目镜使用面罩层，原智力和魔力都存在")
	if graphics:
		_check(bare != await _avatar_pixels(human), "护目镜附着在原头部纹理的真实画面")
		_check(_near_color(_avatar_texel(human, Vector2(14.5, 14.5)), Color8(136, 14, 14)), "护目镜准确覆盖原东南头部像素")
	var mask_textures: Array[Texture2D] = []
	for d in ["SE", "SW", "NE", "NW"]:
		await _click(d)
		mask_textures.append(mat.get_shader_parameter("mask_map"))
		_check(_head_flags(mat, false, true, true, true), "方向刷新保留面罩与两个外观层：" + d)
	_check(mask_textures[0] != mask_textures[1] and mask_textures[1] != mask_textures[2] and mask_textures[2] == mask_textures[3], "北面护目镜原使用同一贴图引用")
	await _click("HelmetCategory")
	_check("头盔\n当前为空" in details.text and _head_flags(mat, false, true, true, true), "切到其他分类不改变身上的头饰")
	await _click("RemoveHelmet")
	_check(_head_flags(mat, false, true, true, true), "在空头盔类别卸下不移除面罩")
	await _click("EquipIronHelmetI")
	_check(_head_flags(mat, true, false, false, false) and "生命 +4" in details.text and mat.get_shader_parameter("mask_map") == null, "铁盔 I 替换面罩，隐藏发须，清空旧贴图")
	await _click("Walk")
	await _click("SW")
	human.animator.pause()
	human.animator.seek(0.125, true)
	_check(human.playback.current_action == "Walk" and human.playback.current_label == 1 and _head_flags(mat, true, false, false, false), "真实行走下一帧不会重新启用发须")
	var iron_i: Vector4 = mat.get_shader_parameter("helmet_rect")
	_check(iron_i.is_equal_approx(Vector4(0, 544.0/608.0, 32.0/512.0, 576.0/608.0)), "铁盔 I 行走 SW 原裁切")
	var under_beard := Color.TRANSPARENT
	if graphics:
		await _click("Idle")
		await _click("SE")
		await _avatar_pixels(human)
		under_beard = _avatar_texel(human, Vector2(14.5, 16.5))
	await _click("EquipIronHelmetII")
	if graphics:
		await _avatar_pixels(human)
		var beard := _avatar_texel(human, Vector2(14.5, 16.5))
		var lower_matches := _near_color(under_beard, Color8(128, 0, 36)) if has_cloak else not _near_color(under_beard, beard)
		_check(lower_matches and _near_color(beard, Color8(151, 151, 151)),
			"待机东南同帧恢复原胡须像素：%s / %s" % [under_beard, beard])
	await _click("Walk")
	await _click("SW")
	human.animator.pause()
	human.animator.seek(0.125, true)
	var iron_ii: Vector4 = mat.get_shader_parameter("helmet_rect")
	_check(iron_ii.is_equal_approx(Vector4(64.0/512.0, 544.0/608.0, 96.0/512.0, 576.0/608.0)), "同数值 ID 的不同资产使用铁盔 II 裁切")
	_check(human.playback.current_label == 1 and _head_flags(mat, true, false, false, true) and "生命 +6" in details.text, "铁盔 I 换 II 后只恢复胡须，下一帧仍正确")
	await _click("EquipHornedHelmet")
	_check(_head_flags(mat, true, false, false, true) and "力量 +2" in details.text, "角饰头盔替换铁盔，并保持原胡须")
	await _click("HatCategory")
	await _click("EquipLightHat")
	_check(_head_flags(mat, true, false, false, true) and "智力 +1" in details.text, "轻帽使用相同材质层并全量替换头盔状态")
	await _click("HelmetCategory")
	await _click("RemoveHelmet")
	_check(_head_flags(mat, true, false, false, true) and "头盔\n当前为空" in details.text, "空头盔分类不会删除轻帽")
	await _click("HatCategory")
	await _click("RemoveHat")
	_check(_head_flags(mat, false, false, true, true) and "帽子\n当前为空" in details.text
		and mat.get_shader_parameter("helmet_map") == null, "从正确类别卸下后，两种原外观层再次出现")
	await _click("Idle")
	await _click("SE")
	if graphics: _check(bare == await _avatar_pixels(human), "在其他装备不变时整人同帧恢复原像素")
	_check(mat.get_shader_parameter("enabled_cloth") and (not has_cloak or mat.get_shader_parameter("enabled_cloak"))
		and (_demo.find_child("BagCategory", true, false) == null or mat.get_shader_parameter("enabled_bag")), "头饰链不影响原服装、斗篷、可选背包")
	await _click("MaskCategory")
	await _click("EquipGoggles")
	await _click("Human")
	_check(_head_flags(mat, false, false, true, true) and mat.get_shader_parameter("enabled_cloth"), "重选角色恢复原无头饰默认")

func _head_flags(mat: ShaderMaterial, helmet: bool, mask: bool, hair: bool, beard: bool) -> bool:
	return mat.get_shader_parameter("enabled_helmet") == helmet and mat.get_shader_parameter("enabled_mask") == mask \
		and mat.get_shader_parameter("enabled_hair") == hair and mat.get_shader_parameter("enabled_beard") == beard

func _avatar_texel(human: Node2D, texel_center: Vector2) -> Color:
	var sprite := human.sprite as Sprite2D
	var q: Vector2 = sprite.get_global_transform_with_canvas() * (sprite.get_rect().position + texel_center)
	return root.get_texture().get_image().get_pixel(floori(q.x),floori(q.y))

func _check_bag(human: Node2D, mat: ShaderMaterial, details: Label) -> void:
	if OS.get_environment("FANTASYWORD_WORKBENCH_WEAPONS").is_empty():
		_check(mat.shader.resource_path.ends_with("/equipment_character_subset.gdshader"), "无武器材质仍应保留原背包层")
	else:
		_check(not mat.get_shader_parameter("weapon_fill_enabled"), "已加载武器材质但武器未装备，北向背包仍绘制")
	await _click("CloakCategory")
	await _click("EquipTravelCloak")
	await _click("BagCategory")
	_check("背包\n当前为空" in details.text and not mat.get_shader_parameter("enabled_bag"), "原人类默认无背包")
	var graphics := DisplayServer.get_name() != "headless"
	for i in 4:
		await _click(["SE", "SW", "NE", "NW"][i])
		human.animator.pause()
		human.animator.seek(0.0, true)
		var base: Array[Color] = []
		var before := PackedByteArray()
		if graphics:
			before = await _avatar_pixels(human)
			base = _bag_witness_pixels(human)
		await _click("EquipBag")
		_check("小背包" in details.text and "生命 +2" in details.text and "魔力 +3" in details.text, "原小背包选项及属性")
		var rect := Vector4(0, (3 - i) / 4.0, 0.2, (4 - i) / 4.0)
		_check(mat.get_shader_parameter("enabled_bag") and mat.get_shader_parameter("bag_rect").is_equal_approx(rect)
			and mat.get_shader_parameter("body_in_front") == (i >= 2), "对应当前帧躯干朝向和原图集矩形")
		_check(mat.get_shader_parameter("enabled_cloak") and mat.get_shader_parameter("enabled_cloth"), "背包未覆盖两槽状态")
		if graphics:
			var worn: PackedByteArray = await _avatar_pixels(human)
			var after := _bag_witness_pixels(human)
			_check(worn != before, "实渲染此方向能看到背包")
			if i == 0:
				_check(_near_color(after[1], base[1]) and not _near_color(after[1], Color8(163, 95, 53)), "南向有覆盖的同一处不会被背包贴图盖住")
			if i == 2:
				_check(_near_color(base[0], Color8(128, 0, 36)) and _near_color(after[0], Color8(208, 126, 53)), "无武器时北向晚绘制覆盖同一处披风，像素取自原背包")
		await _click("RemoveBag")
		_check("当前为空" in details.text and not mat.get_shader_parameter("enabled_bag") and mat.get_shader_parameter("enabled_cloak")
			and mat.get_shader_parameter("enabled_cloth"), "只卸下背包")
		if graphics:
			_check(before == await _avatar_pixels(human), "四向卸下恢复该原帧像素")
	await _click("EquipBag")
	await _click("Human")
	_check(not mat.get_shader_parameter("enabled_bag") and not mat.get_shader_parameter("enabled_cloak")
		and mat.get_shader_parameter("enabled_cloth"), "人类重置移除背包和披风，恢复默认布衣")

func _bag_witness_pixels(human: Node2D) -> Array[Color]:
	var pixels: Array[Color] = []
	var sprite := human.sprite as Sprite2D
	var image := root.get_texture().get_image()
	for texel in [Vector2(13.5, 15.5), Vector2(14.5, 16.5)]:
		var q: Vector2 = sprite.get_global_transform_with_canvas() * (sprite.get_rect().position + texel)
		pixels.append(image.get_pixel(floori(q.x), floori(q.y)))
	return pixels

func _near_color(value: Color, target: Color) -> bool:
	return Vector3(value.r, value.g, value.b).distance_to(Vector3(target.r, target.g, target.b)) < 0.01

func _check_cloak(human: Node2D, mat: ShaderMaterial, details: Label) -> void:
	var textures: Dictionary = _demo._cloak._textures
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		OS.get_environment("FANTASYWORD_WORKBENCH_SOURCE").path_join("cloak.json")))
	var uid := {}
	for key in source.textures:
		uid[source.textures[key].file] = key
	var original := PackedByteArray()
	if DisplayServer.get_name() != "headless":
		original = await _avatar_pixels(human)
	await _click("CloakCategory")
	_check("斗篷\n当前为空" in details.text and mat.get_shader_parameter("enabled_cloth"), "选披风类别不改默认布衣")
	await _click("EquipTravelCloak")
	_check("旅行披风" in details.text and "体质 +1" in details.text and "魔力 +2" in details.text, "旅行披风显示原属性")
	_check(mat.get_shader_parameter("enabled_cloak") and mat.get_shader_parameter("cloak_map") == textures[uid["clock1.png"]], "旅行披风穿上原图")
	if DisplayServer.get_name() != "headless":
		_check(original != await _avatar_pixels(human), "实际渲染穿披风像素变化")
	await _click("EquipHeavyCloak")
	_check("厚斗篷" in details.text and "体质 +2" in details.text and "生命 +4" in details.text and "魔力 +2" not in details.text, "相同 numeric id 的厚斗篷完全替换该槽")
	_check(mat.get_shader_parameter("enabled_cloth") and mat.get_shader_parameter("cloak_map") == textures[uid["斗篷.png"]], "披风替换不影响布衣")
	var dmg_button := _demo.find_child("Dmg",true,false) as Button
	_check(dmg_button!=null and dmg_button.text=="受击","原动作按钮的 Dmg 文案为受击")
	await _click("Dmg")
	_check("动作 受击" in details.text and "身体动画 受击" in details.text,"当前动作与身体标签沿用原受击文案")
	human.animator.pause()
	for direction in ["SE", "SW", "NE", "NW"]:
		await _click(direction)
		var index: int = ["SE", "SW", "NE", "NW"].find(direction)
		for frame in range(4):
			human.animator.seek(frame * 0.125, true)
			var name: String = ["斗篷.png", "斗篷1.png", "斗篷.png", "斗篷1.png"][index] if frame >= 2 else "clock%d.png" % (5 + index)
			_check(human.playback.current_action == "Dmg" and human.playback.current_label == frame
				and mat.get_shader_parameter("cloak_map") == textures[uid[name]], "真实受伤帧随躯干切换：" + direction + str(frame))
	human.animator.seek(0.5, true)
	human.driver.advance_game_time(0.6)
	_check(human.playback.current_action == "Dmg" and human.playback.current_label == 3 and human.driver.pending_key.is_empty(), "工作台最终受伤姿态停留，不按正式战斗逻辑还原")
	for index in range(4):
		var sets: Array = _demo._cloak.options[1].sprite_sets
		_check(CloakPreview.resolve_guid(sets, index, 4) == CloakPreview.resolve_guid(sets, index, 0), "原 Right 缺 SE 时整套回退，不拿其他方向绕过")
	await _click("Idle")
	await _click("SE")
	await _click("RemoveCloak")
	_check("当前为空" in details.text and not mat.get_shader_parameter("enabled_cloak") and mat.get_shader_parameter("enabled_cloth"), "仅卸下披风，布衣保留")
	if DisplayServer.get_name() != "headless":
		_check(original == await _avatar_pixels(human), "卸下披风恢复同一原帧像素")
	await _click("EquipTravelCloak")
	await _click("ClothCategory")
	await _click("RemoveCloth")
	_check(mat.get_shader_parameter("enabled_cloak") and not mat.get_shader_parameter("enabled_cloth"), "另一个类别卸下也不影响披风")
	await _click("CloakCategory")
	await _click("Human")
	_check(not mat.get_shader_parameter("enabled_cloak") and mat.get_shader_parameter("enabled_cloth") and "斗篷\n当前为空" in details.text, "重选人类恢复原默认装备，保留所选类别")

func _avatar_pixels(human: Node2D) -> PackedByteArray:
	human.animator.pause()
	human.animator.seek(0.0, true)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var focus := Rect2i(Vector2i(human.position) - Vector2i(112,112), Vector2i(224,224))
	return image.get_region(focus).get_data()

func _click(node_name: String) -> void:
	var button := _demo.find_child(node_name, true, false) as Button
	var center := button.get_global_transform_with_canvas() * (button.size * 0.5)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = center
		event.global_position = center
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)

func _finish() -> void:
	print("EquipmentSystemDemo：%s/%s；%s" % [_checks - _failures, _checks, DisplayServer.get_name()])
	quit(0 if _failures == 0 else 1)
