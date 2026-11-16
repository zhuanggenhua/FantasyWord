extends SceneTree
const Pose = preload("res://gameplay/presentation/equipment_weapon_pose.gd")
var checks := 0
var failures := 0

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)

func _initialize() -> void:
	# 合成纹理只供绑定合同测试，不冒充原图或视觉验收截图。
	var texture := ImageTexture.create_from_image(Image.create_empty(64, 64, false, Image.FORMAT_RGBA8))
	var se := {"texture":texture, "rect":Rect2(13, 23, 8, 12)}
	var sw := {"texture":texture, "rect":Rect2(29, 3, 10, 14)}
	var nw := {"texture":texture, "rect":Rect2(41, 31, 6, 16)}
	var equip := {"sprites":{"se":se}, "is_shield":false, "hide_outline_on_body":true}
	var anchor := {"position":Vector2i(3, 11), "direction":6}
	var size := Vector2(32, 48)
	var main_front := [false, false, true, true]
	for facing in range(4):
		for main in [true, false]:
			var pose := Pose.resolve(facing, main, size, anchor, equip, false)
			check(pose.enabled and pose.write_slot and pose.disable_generated_renderer, "有效静态绑定并禁子渲染器")
			check(pose.slot_is_front == (main_front[facing] if main else not main_front[facing]), "实际锚点左右表，而非过时注释的主手前后")
			check(pose.flip_x == (facing == 1 or facing == 3), "没有 SW 才镜像西向")
			check(pose.anchor_frame_uv.is_equal_approx(Vector2(3.5/32.0, 1.0-11.5/48.0)), "非中心锚点含半像素和源 Y 反向")
			check(pose.hand_local_uv.is_equal_approx(Vector2(0.4375, 0.5-0.5/12.0)), "非方形武器取实际 rect 尺寸而非整图")
			check(pose.sprite.rect == Rect2(13,23,8,12), "非零 atlas 原点不裁剪、不改写")
			check(pose.rot_cos_sin.is_equal_approx(Vector2(0, -1 if pose.flip_x else 1)), "锚点 East 正九十度，仅镜像时取反")
			check(pose.hand_in_front and pose.hide_outline_on_body, "普通武器手部遮挡与描边标记")
			for back in [true, false]:
				var seq := Pose.resolve(facing, main, size, anchor, equip, true, {"sprite":nw,"depth_back":back})
				check(seq.enabled and seq.is_sequence and seq.slot_is_front == not back, "序列取作者深度不取默认手排序")
				check(not seq.flip_x and seq.rot_cos_sin == Vector2(1,0), "序列不继承静态镜像和旋转")
				check(seq.sprite == nw and seq.anchor_frame_uv == pose.anchor_frame_uv, "序列仍绑定作者锚点和指定帧")
				check(seq.hand_local_uv.is_equal_approx(Vector2(0.5-0.5/6.0,0.46875)), "序列也取其自身 rect 的手偏移")
			var shield := equip.duplicate()
			shield.is_shield = true
			check(Pose.resolve(facing,main,size,anchor,shield,false).hand_in_front == (facing >= 2), "盾牌南向盾在手前，北向手在前")
	var center := Pose.resolve(3,true,size,null,equip,true,{"sprite":se})
	check(center.anchor_frame_uv == Vector2(0.5,0.5) and center.enabled, "无锚序列合法并使用帧中心")
	var absent := Pose.resolve(0,true,size,null,equip,false)
	check(absent == Pose.clear_slot(), "静态缺锚明确清槽")
	for bad in [null, {"texture":null,"rect":se.rect}, {"texture":texture,"rect":se.rect,"invalid_layer":true}]:
		check(Pose.resolve(0,true,size,anchor,equip,true,{"sprite":bad}) == Pose.clear_slot(), "序列错帧清槽，绝不退静态")
	check(Pose.resolve(0,true,size,anchor,equip,true) == Pose.clear_slot(), "配置序列但该帧缺失清槽")
	var authored := {"sprites":{"se":se,"nw":nw}}
	check(Pose.resolve(3,true,size,anchor,authored,false).flip_x, "NW 存在仍依据 SW 缺失镜像")
	authored.sprites.sw = sw
	var western := Pose.resolve(3,true,size,anchor,authored,false)
	check(not western.flip_x and western.sprite == nw, "SW 配置阻止西向镜像，同时仍选 NW")
	authored.sprites.erase("nw")
	check(Pose.resolve(3,true,size,anchor,authored,false).sprite == sw, "NW 缺失先取 SW")
	for direction in range(8):
		var a := {"position":Vector2i.ZERO,"direction":direction}
		for facing in [0,1]:
			var pose := Pose.resolve(facing,true,size,a,equip,false)
			var angles := [0.0,-45.0,-90.0,-135.0,180.0,135.0,90.0,45.0]
			var rad := deg_to_rad(angles[direction] * (-1 if facing == 1 else 1))
			check(pose.rot_cos_sin.is_equal_approx(Vector2(cos(rad),sin(rad))), "八方向角度按源枚举，西向取负")
	for key in ["ui_icon","whole_character_action"]:
		var bad := se.duplicate()
		bad[key] = true
		check(not Pose.resolve(0,true,size,anchor,{"sprites":{"se":bad}},false).write_slot, "静态非法贴图沿用源直接返回")
	check(not Pose.resolve(0,true,size,anchor,{},false).write_slot, "空装备不写槽")
	check(not Pose.resolve(0,true,size,anchor,{"sprites":{}},false).write_slot, "静态缺图不写槽")
	print("PASS equipment_weapon_pose %d checks" % checks if failures == 0 else "FAIL equipment_weapon_pose")
	quit(1 if failures else 0)
