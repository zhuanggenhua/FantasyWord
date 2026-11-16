extends SceneTree
const Materials = preload("res://gameplay/presentation/equipment_subset_material.gd")
const Runtime = preload("res://game_core/presentation/equipment_frame_runtime.gd")
const Refresh = preload("res://game_core/presentation/equipment_refresh_order.gd")
var checks := 0
var failures := 0
var events: Array = []
var material: ShaderMaterial
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func tex(color: Color) -> Texture2D:
	var image := Image.create_empty(2,2,false,Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
func is_black(texture: Texture2D) -> bool:
	return texture != null and texture.get_size() == Vector2.ONE and texture.get_image().get_pixel(0,0) == Color(0,0,0,1)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main := tex(Color.WHITE)
	var body := tex(Color.RED)
	var head := tex(Color.GREEN)
	var next := tex(Color.BLUE)
	material = Materials.create(main,body,head,true,{}, {}, {},true).material
	var identity := material.get_instance_id()
	material.set_shader_parameter("enabled_cloth",true)
	material.set_shader_parameter("enabled_helmet",true)
	material.set_shader_parameter("weapon0_enabled",true)
	var r := Runtime.new()
	var frame := {"frame_index":0,"row_index":0,"hit_outline_frame":false}
	r.frame_data = {
		"Idle":{"frame_size":Vector2i(2,2),"frames":[frame],"body_uv":body,"head_uv":head},
		"Partial":{"frame_size":Vector2i(2,2),"frames":[frame],"body_uv":next,"head_uv":null},
		"Missing":{"frame_size":Vector2i(2,2),"frames":[],"body_uv":body,"head_uv":head},
	}
	r.configs = [
		{"type":"ordinary","mode":Refresh.RenderMode.SPRITE},
		{"type":"sequence","mode":Refresh.RenderMode.SPRITE},
		{"type":"color","mode":Refresh.RenderMode.COLOR},
		{"type":"weapon","mode":Refresh.RenderMode.WEAPON},
	]
	r.slots = {"ordinary":"plain","sequence":"seq","color":"color","weapon":"weapon"}
	r.hooks = {
		"bind_uv_maps":func(b,h):
			events.append("uv")
			check(Materials.apply_nullable_action_uv_maps(material,b,h).ok,"可空动作写入"),
		"reset_layers":func():
			events.append("reset")
			# 只模拟本测试关注的普通层与武器，不声称正式完整 Reset 接线。
			material.set_shader_parameter("enabled_cloth",false)
			material.set_shader_parameter("enabled_helmet",false)
			material.set_shader_parameter("weapon0_enabled",false),
		"render_weapons":func():
			events.append("weapons")
			material.set_shader_parameter("weapon0_enabled",true),
		"disable_generated_weapon_renderers":func(): events.append("disable"),
		"warn_missing_frame_data":func(): events.append("warn"),
		"apply_original_material":func(): events.append("original"),
		"update_shadow_height":func(_f): events.append("shadow"),
		"set_hit_outline":func(_v): events.append("hit"),
		"update_body_depth":func(_f): events.append("depth"),
		"apply_appearance":func(): events.append("appearance"),
		"has_sequence":func(e,_k): events.append("sequence:"+e); return e=="seq",
		"apply_sprite":func(e,_c): events.append("sprite:"+e),
		"apply_color":func(e,_c): events.append("color:"+e),
	}
	var sprite := AtlasTexture.new()
	sprite.atlas = main
	sprite.region = Rect2(0,0,2,2)
	r.late_sync_from_owner("Idle",sprite)
	check(events == ["uv","shadow","reset","uv","hit","depth","weapons","appearance","sprite:plain","sprite:seq","color:color"],"完整帧初次刷新顺序")
	events.clear()
	material.set_shader_parameter("enabled_cloth",true)
	material.set_shader_parameter("enabled_helmet",true)
	r.late_sync_from_owner("Partial",sprite)
	check(events==["uv"],"同 Sprite 只写动作 UV，不提前刷新")
	check(material.get_shader_parameter("body_map")==next and is_black(material.get_shader_parameter("head_map")),"有效 Body 和缺失 Head 独立写入")
	check(material.get_shader_parameter("enabled_cloth") and material.get_shader_parameter("enabled_helmet"),"缺失 Head 不等同关闭上一普通层")
	check(material.get_shader_parameter("main_map")==main and material.get_shader_parameter("weapon0_enabled"),"动作写入不改变主图和独立武器")
	var partial_black: Texture2D = material.get_shader_parameter("head_map")
	events.clear()
	r.sync_current_sprite_from_owner("Partial",sprite)
	check(events==["reset","uv","weapons","sequence:plain","sequence:seq","sprite:seq"],"完整 Refresh 缺图分支先重置再双清再武器及匹配序列")
	check(is_black(material.get_shader_parameter("body_map")) and is_black(material.get_shader_parameter("head_map")),"双清均使用明确不透明黑 RGBA")
	check(not material.get_shader_parameter("enabled_cloth") and not material.get_shader_parameter("enabled_helmet") and material.get_shader_parameter("weapon0_enabled"),"普通层关闭，独立武器按原分支尝试恢复")
	check(material.get_shader_parameter("head_map")==partial_black,"反复缺图复用同一黑资源而非重新造材质")
	events.clear()
	r.frame_data = null
	material.set_shader_parameter("body_map",body)
	material.set_shader_parameter("head_map",head)
	r.refresh()
	check(events==["warn","reset"],"完全缺 frameData 早退只警告和重置")
	check(material.get_shader_parameter("body_map")==body and material.get_shader_parameter("head_map")==head,"完全缺 frameData 不伪造双清")
	r.frame_data = {"Idle":{"frame_size":Vector2i(2,2),"frames":[frame],"body_uv":body,"head_uv":head},"Missing":{"frame_size":Vector2i(2,2),"frames":[],"body_uv":body,"head_uv":head}}
	events.clear()
	r.sync_current_sprite_from_owner("Missing",sprite)
	check(events==["uv","reset","uv","weapons","sequence:plain","sequence:seq","sprite:seq"],"双 UV 有效但帧缺失仍走完整 Refresh 双清")
	check(is_black(material.get_shader_parameter("body_map")) and is_black(material.get_shader_parameter("head_map")),"缺帧双清")
	events.clear()
	r.sync_current_sprite_from_owner("Idle",sprite)
	check(material.get_shader_parameter("body_map")==body and material.get_shader_parameter("head_map")==head,"同 Sprite 显式恢复有效动作双图")
	check(material.get_instance_id()==identity,"缺图/缺帧/恢复一直是同一原生材质")
	check(not Materials.apply_action_uv_maps(material,null,head).ok,"原严格双图 API 不变")
	check(material.get_shader_parameter("body_map")==body,"严格 API 拒绝缺图且不写")
	var atlas := AtlasTexture.new()
	atlas.atlas = head
	for pair in [[7,head],[body,"bad"],[atlas,head],[null,atlas]]:
		check(not Materials.apply_nullable_action_uv_maps(material,pair[0],pair[1]).ok,"错误非空对象拒绝，不能转成 null")
		check(material.get_shader_parameter("body_map")==body and material.get_shader_parameter("head_map")==head,"整对验证失败不半写")
	check(Materials.apply_nullable_action_uv_maps(material,null,next).ok,"缺 Body 与有效 Head 独立方向")
	check(is_black(material.get_shader_parameter("body_map")) and material.get_shader_parameter("head_map")==next,"缺 Body 与新 Head 正确绑定")
	var ordinary: ShaderMaterial = Materials.create(main,body,head,true,{}, {}, {}).material
	check(Materials.apply_nullable_action_uv_maps(ordinary,null,null).ok and ordinary.shader==Materials.SUBSET,"普通变体支持，不新增 sampler")
	check(not Materials.apply_nullable_action_uv_maps(null,null,null).ok,"空材质拒绝")
	check(not Materials.apply_nullable_action_uv_maps(ShaderMaterial.new(),null,null).ok,"未知着色器拒绝")
	r.hooks.clear()
	if failures == 0: print("PASS 可空装备动作 UV：%d 项；参数与 CPU RGBA 证据，非原生渲染截图" % checks)
	quit(1 if failures else 0)
