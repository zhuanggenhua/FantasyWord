extends SceneTree
const View = preload("res://gameplay/clickmovetest/human_presentation.gd")
const DIRECTIONS := ["SE","SW","NE","NW"]
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(what)

func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

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
	for action in ["Idle","Walk"]:
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
				# This fixture intentionally separates row, head and torso facing.
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
			"duration":float(n)*0.125,"loop":true}
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
	var dir := ProjectSettings.globalize_path("user://formal-material")
	DirAccess.make_dir_recursive_absolute(dir)
	var private_dir := OS.get_environment("FORMAL_HUMAN_PRIVATE")
	var animation: Dictionary
	var data: Dictionary
	var uv_dir := dir
	var appearance_dir := dir
	if private_dir.is_empty():
		var fixture := _fixture(dir)
		animation = fixture[0]
		data = fixture[1]
	else:
		animation = _read(private_dir.path_join("private-formal-human-verification/animation-final.json"))
		data = _read(private_dir.path_join("private-formal-human-verification/material.json"))
		dir = private_dir.path_join("private-human-source")
		uv_dir = private_dir.path_join("private-formal-human-generated-uv")
		appearance_dir = private_dir.path_join("private-formal-player-appearance")
	var view := View.new()
	root.add_child(view)
	if not view.configure(animation,dir):
		printerr(view.last_error)
		quit(1); return
	var bad := data.duplicate(true)
	bad.actions.Walk.main_sha256 = "not the main texture"
	_check(not view.bind_base_material(bad,uv_dir,appearance_dir) and view.sprite.material == null,
		"Rejected cross-linked manifest must leave live base sprite untouched.")
	bad = data.duplicate(true)
	bad.actions.Idle.frames.pop_back()
	_check(not view.bind_base_material(bad,uv_dir,appearance_dir) and view.sprite.material == null,
		"Missing original frame must not install a partial material.")
	bad = data.duplicate(true)
	bad.textures[bad.actions.Idle.body].sha256 = "0".repeat(64)
	_check(not view.bind_base_material(bad,uv_dir,appearance_dir) and view.sprite.material == null,
		"Modified UV inputs must be rejected before touching the sprite.")
	if not view.bind_base_material(data,uv_dir,appearance_dir):
		printerr(view.last_error)
		quit(1); return
	var material := view.sprite.material as ShaderMaterial
	var previous := {}
	var old_main: Texture2D = material.get_shader_parameter("main_map")
	var old_body: Texture2D = material.get_shader_parameter("body_map")
	var old_head: Texture2D = material.get_shader_parameter("head_map")
	view.driver.animation_selected.connect(func(key: String):
		if key == "Walk":
			_check(material.get_shader_parameter("main_map") == old_main and material.get_shader_parameter("hair_map") == previous.hair,
				"Selecting the action must not refresh the old Sprite identity.")
			_check(material.get_shader_parameter("body_map") != old_body and material.get_shader_parameter("head_map") != old_head,
				"Both newly selected action UV maps must precede Sprite refresh.")
	)
	var expected_maps := {}
	for action: String in ["Idle","Walk"]:
		previous.hair = material.get_shader_parameter("hair_map")
		view.set_movement(Vector2(1,0) if action == "Walk" else Vector2.ZERO)
		var spec: Dictionary = data.actions[action]
		for part in ["body","head"]:
			var texture: Texture2D = material.get_shader_parameter(part+"_map")
			var expected := Image.load_from_file(uv_dir.path_join(spec[part]))
			var actual := texture.get_image()
			_check(actual.get_size() == expected.get_size() and actual.get_data() == expected.get_data(),"Exact "+action+" "+part+" RGBA bytes.")
			expected_maps[action+part] = texture
		for row in range(4):
			view.playback.set_direction(row)
			for label in range(16 if action == "Idle" else 4):
				view.animator.seek(label*0.125,true)
				view.animator.advance(0.0)
				var frame: Dictionary = {}
				for record in spec.frames:
					if record.row_index == row and record.frame_index == label:
						frame = record
						break
				var tags := action+":"+str(row)+":"+str(label)
				var texture := view.sprite.texture as AtlasTexture
				_check(view.sprite.material == material and material.get_shader_parameter("main_map") == texture.atlas
					and texture.region == Rect2(label*32,row*32,32,32),tags+" persistent material and actual region")
				_check(material.get_shader_parameter("body_map") == expected_maps[action+"body"]
					and material.get_shader_parameter("head_map") == expected_maps[action+"head"],tags+" persistent action textures")
				var head_facing: int = frame.body_regions.get("head",{}).get("sprite_facing",row)
				var torso_facing: int = frame.body_regions.get("torso",{}).get("sprite_facing",row)
				_check(material.get_shader_parameter("body_in_front") == (torso_facing >= 2)
					and material.get_shader_parameter("enabled_left_eye") == (head_facing < 2 and not frame.left_eye_closed)
					and material.get_shader_parameter("enabled_right_eye") == (head_facing < 2 and not frame.right_eye_closed)
					and material.get_shader_parameter("enabled_eye_decoration") == (head_facing < 2),tags+" body depth and authored eyelids")
				var hair := Image.load_from_file(appearance_dir.path_join(data.appearance["hair"+DIRECTIONS[head_facing]]))
				var beard := Image.load_from_file(appearance_dir.path_join(data.appearance["beard"+DIRECTIONS[head_facing]]))
				var actual_hair: Texture2D = material.get_shader_parameter("hair_map")
				var actual_beard: Texture2D = material.get_shader_parameter("beard_map")
				_check(actual_hair.get_image().get_data() == hair.get_data() and actual_beard.get_image().get_data() == beard.get_data(),tags+" head-specific cosmetics")
	view.set_movement(Vector2.ZERO)
	_check(view.sprite.material == material and material.get_shader_parameter("body_map") == old_body and material.get_shader_parameter("head_map") == old_head,
		"Return to Idle must restore original UV textures without replacing the material.")
	_check(not material.get_shader_parameter("skin_palette_enabled")
		and not material.get_shader_parameter("enabled_face_accessory")
		and material.get_shader_parameter("right_eye_color") == Color(0.6,0.2,0.8,1),"Authored base look with no accessory or palette.")
	view.free()
	if failures == 0: print("PASS formal Human live material (%d checks)" % checks)
	quit(0 if failures == 0 else 1)
