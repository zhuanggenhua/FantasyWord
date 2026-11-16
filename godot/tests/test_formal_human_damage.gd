extends SceneTree
## 原 Dmg 的显式表现请求；公共合成夹具只验合同，私有模式另核实作者像素。
const Scene = preload("res://gameplay/clickmovetest/entry.tscn")
const View = preload("res://gameplay/clickmovetest/human_presentation.gd")
const DIRECTIONS := ["SE","SW","NE","NW"]
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _put(dir: String, name: String, size: Vector2i, specs: Dictionary, color: Color) -> void:
	var path := dir.path_join(name)
	var image := Image.create_empty(size.x,size.y,false,Image.FORMAT_RGBA8)
	image.fill(color)
	assert(image.save_png(path) == OK)
	specs[name] = {"size":[size.x,size.y], "sha256":FileAccess.get_sha256(path), "pixels_per_unit":8}

func _fixture(dir: String) -> Array:
	var animation := {"schema":1,"source_commit":View.SOURCE,"textures":{},"actions":{}}
	var material := {"schema":1,"source_commit":View.SOURCE,"textures":{},"actions":{},"appearance":{}}
	var value := 0.01
	for action in ["Idle","Walk","Dmg"]:
		var n := 16 if action == "Idle" else 4
		var row_list := []
		var frame_list := []
		var size := Vector2i(32*n,128)
		var main: String = action+".png"
		_put(dir,main,size,animation.textures,Color(value,0,0))
		var body: String = action+"_body.png"
		var head: String = action+"_head.png"
		_put(dir,body,size,material.textures,Color(value,0.5,0,1))
		_put(dir,head,size,material.textures,Color(value,0.6,0,1))
		value += 0.05
		for row in range(4):
			var frames := []
			for col in range(n):
				frames.append({"rect":[col*32,(3-row)*32,32,32],"texture":main})
				# 合成测试有意区分图集行、头部和躯干朝向；不冒充作者素材。
				frame_list.append({"frame_index":col,"row_index":row,
					"body_regions":{"head":{"sprite_facing":(row+1)%4},"torso":{"sprite_facing":(row+2)%4}},
					"left_eye_closed":col == 2,"right_eye_closed":col == 1})
			row_list.append(frames)
		var labels := []
		var times := []
		for col in range(n):
			labels.append(col)
			times.append(float(col)*0.125)
		labels.append(n-1)
		times.append(float(n)*0.125)
		animation.actions[action] = {"directions":row_list,"labels":labels,"times":times,
			"duration":float(n)*0.125,"loop":action != "Dmg"}
		material.actions[action] = {"main_sha256":animation.textures[main].sha256,
			"frames":frame_list,"body":body,"head":head}
	for part in ["hair","beard"]:
		for direction in DIRECTIONS:
			var name: String = part+direction
			_put(dir,name+".png",Vector2i(32,32),material.textures,Color(value,0.5,0.9,1))
			material.appearance[name] = name+".png"
			value += 0.05
	for side in ["East","West"]:
		var name: String = "eyeDecoration"+side
		_put(dir,name+".png",Vector2i(8,8),material.textures,Color(value,0.9,0.3,1))
		material.appearance[name] = name+".png"
		value += 0.05
	material.appearance.leftEyeColor = [0,0,0,1]
	material.appearance.rightEyeColor = [0.6,0.2,0.8,1]
	return [animation,material]

func _run() -> void:
	var dir := ProjectSettings.globalize_path("user://human-damage")
	DirAccess.make_dir_recursive_absolute(dir)
	var values := _fixture(dir)
	var animation: Dictionary = values[0]
	var material: Dictionary = values[1]
	var uv_dir := dir
	var appearance_dir := dir
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		assert(args.size() == 5)
		animation = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
		material = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
		dir = args[2]; uv_dir = args[3]; appearance_dir = args[4]
	var host = Scene.instantiate()
	root.add_child(host)
	await process_frame
	var view = host.start_human_presentation(animation,dir)
	if view == null:
		printerr("不能创建原角色表现入口")
		quit(1); return
	view.driver.set_process(false)
	view.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var bad := material.duplicate(true)
	bad.actions.erase("Dmg")
	_check(not view.bind_base_material(bad,uv_dir,appearance_dir) and view.sprite.material == null,"Dmg 入口不能绑定仅 Idle/Walk 的旧材质")
	if not view.bind_base_material(material,uv_dir,appearance_dir):
		printerr(view.last_error)
		quit(1); return
	var shader: ShaderMaterial = view.sprite.material
	var clip: Animation = view.animator.get_animation("Dmg")
	_check(clip.length == 0.5 and clip.loop_mode == Animation.LOOP_NONE,"Dmg 必须为作者 0.5 秒非循环片段")
	_check(clip.track_get_key_count(0) == 5,"Dmg 包含四个帧及末尾重复帧")
	for i in range(5):
		_check(clip.track_get_key_time(0,i) == i*0.125,"Dmg 的原 8Hz 精确关键帧时间")
	for row in range(4):
		_check(view.try_play_damage_animation(),"显式受击请求必须使用已配置片段")
		view.playback.set_direction(row)
		var deadline: float = view.driver.pending_time
		for label in range(4):
			if label > 0: view.animator.advance(0.125)
			var tex: AtlasTexture = view.sprite.texture
			_check(view.playback.current_action == "Dmg" and view.playback.current_label == label,"Dmg 帧标签")
			_check(tex.region == Rect2(label*32,row*32,32,32),"Dmg 四向图集区域")
			var original := Image.load_from_file(dir.path_join(animation.actions.Dmg.directions[row][label].texture))
			_check(tex.get_image().get_data() == original.get_region(Rect2i(label*32,row*32,32,32)).get_data(),"Dmg 原 RGBA 区域逐字一致")
			_check(shader == view.sprite.material and shader.get_shader_parameter("main_map") == tex.atlas,"Dmg 使用同一个实时材质及当前主图集")
			for part in ["body","head"]:
				var expected := Image.load_from_file(uv_dir.path_join(material.actions.Dmg[part]))
				var actual: Texture2D = shader.get_shader_parameter(part+"_map")
				_check(actual.get_image().get_data() == expected.get_data(),"Dmg 绑定作者动作的 "+part+" UV，不复用旧动作")
		var position: float = view.animator.current_animation_position
		view.playback.set_direction((row+1)%4)
		_check(view.animator.current_animation_position == position and view.driver.pending_time == deadline,"转向不重播 Dmg 也不延长恢复时间")
		view.animator.advance(0.2)
		_check(view.playback.current_label == 3,"非循环 Dmg 结束后保持作者末帧，等待动作 owner 恢复")
	# 没有新的 SetMovement 时，受击排队恢复初值必须是 Idle，即使之前正在 Walk。
	view.driver.try_play_animation("Walk")
	view.try_play_damage_animation()
	_check(view.driver.pending_fallback_key == "Idle","受击初始恢复为 DefaultAnimationKey")
	view.driver.advance_game_time(0.499)
	_check(view.driver.current_animation_key == "Dmg","到期前不提前恢复")
	view.driver.advance_game_time(0.0011)
	_check(view.driver.current_animation_key == "Idle" and view.playback.current_action == "Idle","到期回到默认 Idle")
	view.try_play_damage_animation()
	view.set_movement(Vector2.RIGHT)
	_check(view.driver.current_animation_key == "Dmg" and view.driver.pending_fallback_key == "Walk","移动 owner 只更新恢复目标，不抢占 Dmg")
	view.driver.advance_game_time(0.5)
	_check(view.driver.current_animation_key == "Walk" and view.playback.current_action == "Walk","受击后恢复 owner 后续裁决的 Walk")
	view.try_play_damage_animation()
	view.set_movement(Vector2.RIGHT)
	view.set_movement(Vector2.ZERO)
	view.driver.advance_game_time(0.5)
	_check(view.driver.current_animation_key == "Idle","恢复目标取最后一次实际移动状态")
	view.try_play_damage_animation()
	view.animator.advance(0.25)
	view.driver.advance_game_time(0.25)
	view.try_play_damage_animation()
	_check(view.playback.current_label == 0 and view.animator.current_animation_position == 0.0,"重复受击从首帧重播")
	view.driver.advance_game_time(0.25)
	_check(view.driver.current_animation_key == "Dmg","旧恢复期限不得截断新受击")
	view.driver.advance_game_time(0.25)
	_check(view.driver.current_animation_key == "Idle","重复受击使用新期限恢复")
	view.try_play_damage_animation()
	view.driver.try_play_animation("Walk")
	_check(view.driver.pending_key.is_empty(),"显式切换别的动作取消旧受击恢复")
	view.driver.advance_game_time(1.0)
	_check(view.driver.current_animation_key == "Walk","旧计时器不能改写新动作")
	view.driver.try_lock_animation("Idle")
	_check(view.try_play_damage_animation() and view.driver.current_animation_key == "Idle" and view.driver.pending_key.is_empty(),"保持原动作锁的成功但不切换语义")
	view.driver.clear_animation_lock()
	view.driver.runtime_enabled = false
	view.try_play_damage_animation()
	view.driver.advance_game_time(1.0)
	_check(view.driver.pending_key.is_empty() and view.driver.current_animation_key == "Dmg","非运行预览不排队自动恢复")
	host.free()
	# 旧二动作合同仍可用，但不能假装提供未导入的受击片段。
	var legacy := animation.duplicate(true)
	legacy.actions.erase("Dmg")
	var old_view := View.new()
	root.add_child(old_view)
	_check(old_view.configure(legacy,dir),"保留已有 Idle/Walk 私有合同兼容")
	_check(not old_view.try_play_damage_animation() and old_view.driver.current_animation_key == "Idle","缺少 Dmg 不生成占位受击")
	old_view.free()
	if failures == 0:
		print("PASS formal Human damage: "+str(checks)+" checks; explicit presentation only, NOT damage/GAS or renderer parity acceptance")
	quit(0 if failures == 0 else 1)
