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
	_finish()

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
	_check("披风\n当前为空" in details.text and mat.get_shader_parameter("enabled_cloth"), "选披风类别不改默认布衣")
	await _click("EquipTravelCloak")
	_check("旅行披风" in details.text and "体质 +1" in details.text and "魔力 +2" in details.text, "旅行披风显示原属性")
	_check(mat.get_shader_parameter("enabled_cloak") and mat.get_shader_parameter("cloak_map") == textures[uid["clock1.png"]], "旅行披风穿上原图")
	if DisplayServer.get_name() != "headless":
		_check(original != await _avatar_pixels(human), "实际渲染穿披风像素变化")
	await _click("EquipHeavyCloak")
	_check("厚斗篷" in details.text and "体质 +2" in details.text and "生命 +4" in details.text and "魔力 +2" not in details.text, "相同 numeric id 的厚斗篷完全替换该槽")
	_check(mat.get_shader_parameter("enabled_cloth") and mat.get_shader_parameter("cloak_map") == textures[uid["斗篷.png"]], "披风替换不影响布衣")
	await _click("Dmg")
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
	_check(not mat.get_shader_parameter("enabled_cloak") and mat.get_shader_parameter("enabled_cloth") and "披风\n当前为空" in details.text, "重选人类恢复原默认装备，保留所选类别")

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
