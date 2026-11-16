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
	trace.clear()
	var old_frame: Variant = runtime.cursor.cached_frame
	runtime.set_animation_context_override(" \tWalk\n", "Idle", sprite, false)
	check(runtime.animation_context_override_key == "Walk" and runtime.action_key == "Walk", "设置先 Trim 并立即解析覆盖，不改调用方动作")
	check(trace == [["uv",other,other]], "autoRefresh=false 仅更新动作 UV，不刷新装备")
	check(runtime.cursor.last_sprite == sprite and is_same(runtime.cursor.cached_frame,old_frame), "同 Sprite 覆盖暂不重采样或刷新帧缓存")
	trace.clear()
	runtime.late_sync_from_owner("Idle",sprite)
	check(trace.is_empty(), "坐骑式相同 Sprite 的 LateUpdate 不补造刷新")
	runtime.sync_current_sprite_from_owner("Idle",sprite)
	check(trace.has("reset") and trace.has("appearance"), "调用方显式同步才刷新同 Sprite 装备")
	trace.clear()
	runtime.set_animation_context_override("Walk", "Missing", sprite)
	check(trace.is_empty() and runtime.action_key == "Walk", "重复规范化键即使 autoRefresh=true 也不解析和刷新")
	runtime.action_key = "Idle"
	runtime.set_animation_context_override(" \tWalk\n", "Missing", sprite)
	check(trace.is_empty() and runtime.action_key == "Idle", "规范化重复设置连 owner 解析也不执行")
	runtime.action_key = "Walk"
	runtime.clear_animation_context_override("Idle",sprite,false)
	check(runtime.animation_context_override_key == "" and runtime.action_key == "Idle" and trace == [["uv",texture,texture]], "清除覆盖先恢复代码 owner，false 不刷新")
	trace.clear()
	runtime.clear_animation_context_override("Walk",sprite)
	check(trace.is_empty() and runtime.action_key == "Idle", "重复清除不解析新的代码键，不刷新")
	runtime.set_animation_context_override(null,"Walk",sprite)
	check(trace.is_empty() and runtime.action_key == "Idle", "null 规范化为空，空覆盖等值直接退出")
	runtime.set_animation_context_override("Walk","Idle",sprite)
	check(trace.has("reset") and runtime.action_key == "Walk", "默认设置自动刷新")
	trace.clear()
	runtime.set_animation_context_override(null,"Idle",sprite)
	check(runtime.animation_context_override_key.is_empty() and runtime.action_key == "Idle" and trace.has("reset"), "null 清已有覆盖并默认刷新")
	trace.clear()
	runtime.set_animation_context_override("Walk","Idle",sprite,false)
	trace.clear()
	runtime.clear_animation_context_override("Idle",sprite)
	check(trace.has("reset") and runtime.action_key == "Idle", "默认清除自动刷新")
	trace.clear()
	runtime.set_animation_context_override("walk","Idle",sprite,false)
	check(runtime.action_key == "walk" and runtime.cursor.current_animation.is_empty(), "等值按大小写精确比较，不把未知键变成 Walk")
	trace.clear()
	runtime.set_animation_context_override("Walk","Idle",null)
	check(runtime.action_key == "Walk" and runtime.cursor.last_sprite == sprite and trace.has("reset"), "空 Sprite 设置仍先解析 owner，再 Refresh 保留上次 Sprite")
	trace.clear()
	runtime.clear_animation_context_override("Idle",null)
	check(runtime.action_key == "Idle" and trace.has("reset"), "空 Sprite 清除同样先解析 owner")
	trace.clear()
	runtime.original_sprite_direct = true
	runtime.set_animation_context_override("Walk","Idle",sprite,false)
	check(trace == [["uv",other,other]] and runtime.action_key == "Walk", "直显设置 false 仍先解析，不调用直显 Refresh")
	trace.clear()
	runtime.clear_animation_context_override("Idle",sprite)
	check(trace == [["uv",texture,texture],"reset","disable","original"], "直显清除默认解析后进入直显 Refresh，而非 LateUpdate")
	runtime.original_sprite_direct = false
	trace.clear()
	runtime.set_animation_context_override(String.chr(0x1c), "Idle", sprite, false)
	check(runtime.action_key == String.chr(0x1c) and runtime.cursor.current_animation.is_empty(), "U+001C 非 .NET 空白，覆盖和 ApplyAnimationKey 均保留")
	runtime.clear_animation_context_override("Idle",sprite,false)
	runtime.sync_animation_owner(String.chr(0xa0))
	check(runtime.action_key == "Idle", "NBSP-only 代码键为空白，无 Animator 保留已有动作")
	runtime.sync_animation_owner(String.chr(0x1c))
	check(runtime.action_key == String.chr(0x1c), "U+001C 代码键不是空白，保留精确键")
	runtime.sync_animation_owner("Idle")
	trace.clear()
	runtime.frame_data = null
	runtime.set_animation_context_override("Walk","Idle",sprite,false)
	check(runtime.animation_context_override_key == "Walk" and runtime.action_key == "Idle" and trace.is_empty(), "无帧数据仍存覆盖，但不解析动作")
	runtime.clear_animation_context_override("Walk",null)
	check(runtime.animation_context_override_key.is_empty() and trace == ["warn","reset"], "无帧数据空 Sprite 自动刷新执行缺数据分支")
	# 验证 .NET 空白边界，不把零宽空格、BOM 和其它 ASCII 控制字符剪掉。
	var whitespace := ""
	for cp in [0x09,0x0a,0x0b,0x0c,0x0d,0x20,0x85,0xa0,0x1680,0x2000,0x2001,0x2002,0x2003,0x2004,0x2005,0x2006,0x2007,0x2008,0x2009,0x200a,0x2028,0x2029,0x202f,0x205f,0x3000]:
		whitespace += String.chr(cp)
	runtime.set_animation_context_override(whitespace + "Walk" + whitespace,"",null,false)
	check(runtime.animation_context_override_key == "Walk", "完整 .NET 空白集合只裁两端")
	runtime.set_animation_context_override(whitespace,"",null,false)
	check(runtime.animation_context_override_key.is_empty(), "全 Unicode 空白规范化为空")
	for cp in [0x01,0x08,0x0e,0x1f,0x180e,0x200b,0xfeff]:
		var key := String.chr(cp) + "Walk" + String.chr(cp)
		runtime.set_animation_context_override(key,"",null,false)
		check(runtime.animation_context_override_key == key, "非 .NET 空白保留 U+%04X" % cp)
	runtime.set_animation_context_override(" Walk Run ","",null,false)
	check(runtime.animation_context_override_key == "Walk Run", "中间空白原样保留")
	if failures == 0: print("PASS 换装动作覆盖设置与清除生命周期：%d 项" % checks)
	quit(1 if failures else 0)
