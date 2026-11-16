extends SceneTree
const Geometry = preload("res://gameplay/presentation/equipment_frame_geometry.gd")
const Playback = preload("res://game_core/presentation/directional_sprite_playback.gd")
const Cursor = preload("res://game_core/presentation/equipment_frame_cursor.gd")
const Binder = preload("res://gameplay/presentation/equipment_subset_material.gd")
var checks := 0
var failures := 0
var seen: Array = []
var reject := false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_verify")

func provide(action: String, label: int, direction: int, sample: AtlasTexture) -> Dictionary:
	seen.append([action, label, direction, sample])
	if reject: return {"ok":false}
	return Binder.create(sample.atlas, sample.atlas, sample.atlas, true, {}, {}, {})

func _verify() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var playback := Playback.new()
	var player := AnimationPlayer.new()
	var sprite := Sprite2D.new()
	var node := Geometry.new()
	for child in [playback, player, sprite, node]: owner.add_child(child)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var sheet := ImageTexture.create_from_image(Image.create(32, 24, false, Image.FORMAT_RGBA8))
	var records := {}
	var directions: Array = []
	for direction in 4:
		var frames: Array = []
		for column in [3, 1]:
			var sample := AtlasTexture.new()
			sample.atlas = sheet
			sample.region = Rect2(column * 4, (direction + 1) * 4, 4, 4)
			frames.append(sample)
			records[sample] = {"pivot_bottom":Vector2(1,3),"pixels_per_unit":2.0,"flip_h":false,"flip_v":false}
		directions.append(frames)
	var cursor := Cursor.new()
	cursor.configure_animation({"frame_size":Vector2i(4,4),"frames":[]})
	playback.sample_resolved.connect(func(_a,_l,_d,s): cursor.late_sync(s))
	check(node.configure(playback, records, provide), "显式身份表接入")
	check(not node.configure(playback, records, provide), "不重复连接")
	check(playback.configure(sprite, player, {"Walk":{"duration":1.0,"loop":true,"times":[0.0,0.5],"labels":[0,1],"directions":directions}}), "原生动画库")
	player.play("Walk")
	player.advance(0)
	check(sprite.texture == directions[0][0] and seen[-1] == ["Walk",0,0,directions[0][0]], "动画身份到材质回调")
	check(node.texture == sheet and node.material.get_shader_parameter("main_map") == sheet, "显示节点持有整图而非帧纹理")
	check(node.uv == PackedVector2Array([Vector2(12,4),Vector2(16,4),Vector2(16,8),Vector2(12,8)]), "非零行列 UV 实际区域")
	check(node.polygon == PackedVector2Array([Vector2(-0.5,-0.5),Vector2(1.5,-0.5),Vector2(1.5,1.5),Vector2(-0.5,1.5)]), "非中心底起轴点与 PPU")
	check(sprite.visible, "不擅自隐藏采样节点")
	player.advance(0.6)
	check(cursor.frame_index == 1 and cursor.row_index == 1 and sprite.texture == directions[0][1], "实际动画阶段同步游标而非标签猜列")
	var phase := player.current_animation_position
	playback.set_direction(3)
	check(node.uv[0] == Vector2(4,16) and cursor.row_index == 4, "方向切换取实际区域不猜方向行")
	check(player.current_animation_position == phase and node.polygon[0] == Vector2(-0.5,-0.5), "不重置阶段或自动镜像")
	records[directions[3][1]].flip_h = true
	records[directions[3][1]].flip_v = true
	playback.sample_resolved.emit("Walk",1,3,directions[3][1])
	check(node.polygon[0] == Vector2(0.5,0.5) and node.uv[0] == Vector2(4,16), "源显式双镜像只改轴点几何")
	reject = true
	playback.sample_resolved.emit("Walk",1,3,directions[3][1])
	check(node.polygon.is_empty() and node.material == null and node.texture == null, "材质失败不留下旧画面")
	reject = false
	playback.sample_resolved.emit("Walk",1,3,directions[3][1])
	check(not node.polygon.is_empty(), "后续有效采样恢复")
	playback.sample_resolved.emit("Walk",0,0,sheet)
	check(node.polygon.is_empty() and not node.last_error.is_empty(), "无身份依据帧停止渲染")
	for mutation in [{"pixels_per_unit":0},{"pixels_per_unit":NAN},{"pivot_bottom":Vector2(INF,0)},{"flip_h":1}]:
		var bad := records.duplicate(true)
		bad[directions[0][0]].merge(mutation,true)
		var other := Geometry.new()
		check(not other.configure(playback,bad,provide), "非法几何拒绝配置")
		other.free()
	directions[0][0].margin = Rect2(0,0,1,1)
	playback.sample_resolved.emit("Walk",0,0,directions[0][0])
	check(node.polygon.is_empty(), "拒绝未经迁移的 margin 语义")
	owner.free()
	if failures == 0: print("PASS equipment frame geometry: ", checks)
	quit(0 if failures == 0 else 1)
