extends SceneTree
const Runtime = preload("res://game_core/presentation/equipment_frame_runtime.gd")
var checks := 0
var failures := 0
var trace: Array = []
var runtime := Runtime.new()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var texture := ImageTexture.create_from_image(Image.create_empty(16,16,false,Image.FORMAT_RGBA8))
	var other := ImageTexture.create_from_image(Image.create_empty(16,16,false,Image.FORMAT_RGBA8))
	var sprite := AtlasTexture.new()
	sprite.atlas = texture
	sprite.region = Rect2(0,0,8,8)
	var frames := [{"frame_index":0,"row_index":0,"hit_outline_frame":false}]
	runtime.frame_data = {
		"Idle":{"frame_size":Vector2i(8,8),"frames":frames,"body_uv":texture,"head_uv":texture},
		"Walk":{"frame_size":Vector2i(8,8),"frames":frames,"body_uv":other,"head_uv":other},
	}
	runtime.hooks = {
		"bind_uv_maps":func(b,h): trace.append(["uv",b,h]),
		"reset_layers":func(): trace.append("reset"),
		"render_weapons":func(): trace.append("weapons"),
		"disable_generated_weapon_renderers":func(): trace.append("disable"),
		"warn_missing_frame_data":func(): trace.append("warn"),
		"apply_original_material":func(): trace.append("original"),
		"update_shadow_height":func(_f): trace.append("shadow"),
		"set_hit_outline":func(_v): pass,
		"update_body_depth":func(_f): pass,
		"apply_appearance":func(): trace.append("appearance"),
		"has_sequence":func(_e,_k): return false,
		"apply_sprite":func(_e,_c): pass,
		"apply_color":func(_e,_c): pass,
	}
	runtime.late_sync_from_owner("Idle",sprite)
	check(runtime.action_key == "Idle" and trace.has("reset"),"代码 owner 无 Animator 仍可首次刷新")
	trace.clear()
	runtime.late_sync_from_owner("Walk",sprite)
	check(runtime.action_key == "Walk" and trace == [["uv",other,other]],"同 Sprite 换动作立即更新双 UV，不刷新槽位")
	trace.clear()
	runtime.late_sync_from_owner("Missing",sprite)
	check(runtime.action_key == "Missing" and runtime.cursor.current_animation.is_empty() and trace == [["uv",null,null]],"未知键同 Sprite 立即清旧 UV，不伪造 Idle 或 Refresh")
	trace.clear()
	runtime.sync_current_sprite_from_owner("Walk",sprite)
	check(runtime.action_key == "Walk" and trace.has("reset"),"显式同步同 Sprite 刷新槽位")
	trace.clear()
	runtime.sync_current_sprite_from_owner("Idle",null)
	check(runtime.action_key == "Walk" and trace.has("reset") and runtime.cursor.last_sprite == sprite,"显式空 Sprite 保留动作与上次 Sprite，只 Refresh")
	trace.clear()
	runtime.late_sync_from_owner(" \t",sprite)
	check(runtime.action_key == "Walk" and trace.is_empty(),"无 Animator 且代码空白保留动作")
	runtime.animation_context_override_key = "Idle"
	runtime.late_sync_from_owner("Walk",sprite)
	check(runtime.action_key == "Idle","覆盖优先代码")
	runtime.animation_context_override_key = " \t"
	runtime.animator_present = true
	runtime.animation_database_keys = ["Idle","Walk","Missing"]
	runtime.animator_parameters = [{"name":"Ignore","type":"bool"},{"name":"Idle","type":"float"},{"name":"Missing","type":"bool"},{"name":"Walk","type":"bool"},{"name":"Idle","type":"bool"}]
	runtime.animator_bool_values = {"Ignore":true,"Idle":true,"Missing":true,"Walk":true}
	runtime.late_sync_from_owner("Walk",sprite)
	check(runtime.action_key == "Walk","代码优先激活 Bool")
	runtime.late_sync_from_owner("",sprite)
	check(runtime.action_key == "Missing","首个数据库认可 Bool 按 Animator 顺序，即使缺 body 数据")
	runtime.animator_bool_values.Missing = false
	runtime.late_sync_from_owner("",sprite)
	check(runtime.action_key == "Walk","忽略未认可名及非 Bool 类型")
	runtime.animator_parameters.reverse()
	runtime.late_sync_from_owner("",sprite)
	check(runtime.action_key == "Walk","缓存建立后不每帧重排参数")
	runtime.invalidate_animation_owner_cache()
	runtime.late_sync_from_owner("",sprite)
	check(runtime.action_key == "Idle","帧数据切换边界使缓存失效后按新顺序读取")
	runtime.animator_bool_values.clear()
	runtime.late_sync_from_owner("",sprite)
	check(runtime.action_key == "Idle","有 Animator 无激活参数才回 Idle")
	runtime.animator_parameters.clear()
	runtime.invalidate_animation_owner_cache()
	runtime.late_sync_from_owner("",sprite)
	check(runtime.action_key == "Idle","锁定正式共享 Controller 空参数走 Idle")
	runtime.late_sync_from_owner(" Walk ",sprite)
	check(runtime.action_key == " Walk " and runtime.cursor.current_animation.is_empty(),"非空代码键不擅自 Trim")
	trace.clear()
	runtime.original_sprite_direct = true
	runtime.late_sync_from_owner("Idle",sprite)
	check(trace == ["original"] and runtime.action_key == " Walk ","直显 LateUpdate 绕过 owner 与槽位")
	trace.clear()
	runtime.sync_current_sprite_from_owner("Idle",sprite)
	check(runtime.action_key == "Idle" and trace.has("original") and trace.has("reset"),"直显显式同步仍解析 owner 再执行直显 Refresh")
	runtime.original_sprite_direct = false
	trace.clear()
	check(not runtime.request_sync_after_next_sample(false),"禁用组件拒绝延迟请求")
	check(not runtime.sync_after_next_sample("Walk",sprite) and trace.is_empty(),"无请求不刷新")
	check(runtime.request_sync_after_next_sample(true) and runtime.request_sync_after_next_sample(true),"重复请求仅保留一项")
	check(trace.is_empty() and runtime.action_key == "Idle","请求阶段不提前读旧 Sprite 或新动作")
	check(runtime.sync_after_next_sample("Walk",sprite) and runtime.action_key == "Walk" and trace.has("reset"),"下一采样后显式入口刷新最新动作与 Sprite")
	trace.clear()
	check(not runtime.sync_after_next_sample("Idle",sprite) and trace.is_empty(),"延迟刷新只消费一次")
	runtime.frame_data = null
	runtime.animation_context_override_key = "Idle"
	runtime.late_sync_from_owner("Idle",sprite)
	check(runtime.action_key == "Walk" and trace.is_empty(),"无帧数据不解析覆盖或代码")
	if failures == 0: print("PASS 换装动作 owner 与实际刷新入口：%d 项" % checks)
	quit(1 if failures else 0)
