extends SceneTree
const Runtime = preload("res://game_core/presentation/equipment_frame_runtime.gd")
const Materials = preload("res://gameplay/presentation/equipment_subset_material.gd")
var checks := 0
var failures := 0
var refreshes := 0
var binds := 0
var runtime := Runtime.new()
var material: ShaderMaterial
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func texture(size: Vector2i) -> Texture2D:
	return ImageTexture.create_from_image(Image.create_empty(size.x,size.y,false,Image.FORMAT_RGBA8))
func sprite(atlas: Texture2D, column: int) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = atlas
	result.region = Rect2(column * 32,0,32,32)
	return result
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var idle := [texture(Vector2i(512,128)),texture(Vector2i(512,128)),texture(Vector2i(512,128))]
	var walk := [texture(Vector2i(128,128)),texture(Vector2i(128,128)),texture(Vector2i(128,128))]
	var idle0 := sprite(idle[0],0)
	var walk1 := sprite(walk[0],1)
	var frames := [{"frame_index":0,"row_index":0,"hit_outline_frame":false},{"frame_index":1,"row_index":0,"hit_outline_frame":true}]
	runtime.frame_data = {
		"Idle":{"frame_size":Vector2i(32,32),"frames":frames,"body_uv":idle[1],"head_uv":idle[2]},
		"Walk":{"frame_size":Vector2i(32,32),"frames":frames.duplicate(true),"body_uv":walk[1],"head_uv":walk[2]},
	}
	var created := Materials.create(idle[0],idle[1],idle[2],true,{}, {}, {},true)
	check(created.ok,"有效初始材质")
	material = created.material
	var identity := material.get_instance_id()
	material.set_shader_parameter("enabled_cloth",true)
	material.set_shader_parameter("weapon0_enabled",true)
	material.set_shader_parameter("shadow_mode",3.0)
	Materials.apply_final_tint(material,Color(0.2,0.4,0.6,0.8),1)
	runtime.hooks = {
		"bind_uv_maps":func(b,h):
			binds += 1
			check(Materials.apply_action_uv_maps(material,b,h).ok,"有效动作双图写入同一材质"),
		"reset_layers":func(): refreshes += 1,
		"render_weapons":func(): pass,
		"disable_generated_weapon_renderers":func(): pass,
		"warn_missing_frame_data":func(): check(false,"本验证不能进入缺数据分支"),
		"apply_original_material":func(): check(false,"本验证不能进入直显分支"),
		"update_shadow_height":func(_f): pass,
		"set_hit_outline":func(_v): pass,
		"update_body_depth":func(_f): pass,
		"apply_appearance":func(): pass,
		"has_sequence":func(_e,_k): return false,
		"apply_sprite":func(_e,_c): pass,
		"apply_color":func(_e,_c): pass,
	}
	var actor := Sprite2D.new()
	actor.material = material
	root.add_child(actor)
	var player := AnimationPlayer.new()
	actor.add_child(player)
	var animation := Animation.new()
	animation.length = 1.0
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track,NodePath(".:texture"))
	animation.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
	animation.track_insert_key(track,0.0,idle0)
	animation.track_insert_key(track,0.5,walk1)
	var library := AnimationLibrary.new()
	library.add_animation("sample",animation)
	player.add_animation_library("",library)
	player.play("sample"); player.seek(0.0,true)
	check(actor.texture == idle0,"原生 AnimationPlayer 采样实际 Sprite 引用")
	runtime.late_sync_from_owner("Idle",actor.texture)
	check(refreshes == 1 and runtime.cursor.frame_index == 0,"首次 Sprite 完成 Refresh")
	check(binds == 2,"首次动作选择与 Refresh 分别写入 UV")
	var old_frame: Variant = runtime.cursor.cached_frame
	var old_parameters := {}
	for uniform in material.shader.get_shader_uniform_list():
		if uniform.name not in ["body_map","head_map"]:
			old_parameters[uniform.name] = material.get_shader_parameter(uniform.name)
	runtime.late_sync_from_owner("Walk",actor.texture)
	check(refreshes == 1 and binds == 3,"动作先切换，同 Sprite 不提前刷新")
	check(material.get_shader_parameter("body_map") == walk[1] and material.get_shader_parameter("head_map") == walk[2],"同 Sprite 立即更新独立双 UV 引用")
	check(material.get_shader_parameter("main_map") == idle[0],"owner 更新不替换上一实际底图")
	check(material.get_shader_parameter("main_map").get_size() != walk[1].get_size(),"有效过渡允许底图和新动作 UV 尺寸不同")
	check(is_same(runtime.cursor.cached_frame,old_frame),"同 Sprite 保留前次帧缓存")
	var untouched := true
	for key in old_parameters:
		if material.get_shader_parameter(key) != old_parameters[key]: untouched = false
	check(untouched,"有效动作写入只改变双 UV，全部其它参数逐项保持")

	check(material.get_shader_parameter("enabled_cloth") and material.get_shader_parameter("weapon0_enabled"),"UV 更新不清除已有装备和武器")
	check(material.get_shader_parameter("shadow_mode") == 3.0 and material.get_shader_parameter("final_tint_enabled"),"UV 更新保留阴影历史及最终乘色")
	runtime.late_sync_from_owner("Walk",actor.texture)
	check(binds == 3 and refreshes == 1,"重复 owner 和 Sprite 不产生多余写入")
	player.seek(0.5,true)
	check(actor.texture == walk1,"原生播放器下一采样确实更换 Sprite")
	# 主图来自真实 Sprite 采样，而非动作 owner；这是测试入口的显式职责。
	material.set_shader_parameter("main_map",actor.texture.atlas)
	runtime.late_sync_from_owner("Walk",actor.texture)
	check(refreshes == 2 and binds == 4 and runtime.cursor.frame_index == 1,"Sprite 改变才刷新新帧")
	check(material.get_shader_parameter("main_map") == walk[0],"当前主图确实来自采样 Sprite")
	check(material.get_instance_id() == identity and actor.material == material,"全过程保留同一个绑定材质实例")
	runtime.sync_current_sprite_from_owner("Walk",actor.texture)
	check(refreshes == 3 and binds == 5,"显式同 Sprite 同步仍能刷新")
	runtime.set_animation_context_override("Idle","Walk",actor.texture,false)
	check(refreshes == 3 and binds == 6 and material.get_shader_parameter("body_map") == idle[1],"覆盖 false 只改双 UV")
	runtime.clear_animation_context_override("Walk",actor.texture,true)
	check(refreshes == 4 and binds == 8 and material.get_shader_parameter("body_map") == walk[1],"清除覆盖先 owner 后显式刷新")
	var before_body: Texture2D = material.get_shader_parameter("body_map")
	var before_head: Texture2D = material.get_shader_parameter("head_map")
	for pair in [[null,walk[2]],[walk[1],null],[walk1,walk[2]],[idle[1],walk[2]]]:
		check(not Materials.apply_action_uv_maps(material,pair[0],pair[1]).ok,"未覆盖输入明确拒绝，不能假装源缺图分支")
		check(material.get_shader_parameter("body_map") == before_body and material.get_shader_parameter("head_map") == before_head,"拒绝输入不半写有效材质")
	check(not Materials.apply_action_uv_maps(null,walk[1],walk[2]).ok,"无材质拒绝")
	var unrelated := ShaderMaterial.new()
	check(not Materials.apply_action_uv_maps(unrelated,walk[1],walk[2]).ok,"不改其它着色器")
	var ordinary := Materials.create(idle[0],idle[1],idle[2],true,{}, {}, {})
	check(Materials.apply_action_uv_maps(ordinary.material,walk[1],walk[2]).ok,"默认无武器变体同样支持")
	check(ordinary.material.shader == Materials.SUBSET,"不升级着色器变体或采样器数")
	actor.free()
	runtime.hooks.clear()
	if failures == 0: print("PASS 持久装备材质动作 UV：%d 项；原生采样与参数证据，不是截图验收" % checks)
	quit(1 if failures else 0)
