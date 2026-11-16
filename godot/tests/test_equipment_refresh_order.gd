extends SceneTree
const Refresh = preload("res://game_core/presentation/equipment_refresh_order.gd")
const Mode = Refresh.RenderMode
var trace: Array = []
var checks := 0
var failures := 0
var mat := ShaderMaterial.new()
var body: ImageTexture
var head: ImageTexture
var frame := {"hit_outline_frame": true}
var configs := [
	{"type":"bag","mode":Mode.NONE}, {"type":"glove","mode":Mode.COLOR},
	{"type":"main","mode":Mode.WEAPON}, {"type":"coat","mode":Mode.SPRITE},
	{"type":"cloak","mode":Mode.SPRITE}, {"type":"empty","mode":Mode.SPRITE},
]
var slots := {"bag":"bag-1","glove":"glove-1","main":"sword-1","coat":"coat-seq","cloak":"cloak-static"}
var hooks: Dictionary

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D body_uv; uniform sampler2D head_uv;"
	mat.shader = shader
	body = ImageTexture.create_from_image(Image.create_empty(1,1,false,Image.FORMAT_RGBA8))
	head = ImageTexture.create_from_image(Image.create_empty(2,1,false,Image.FORMAT_RGBA8))
	hooks = {
		"reset_layers":func(): trace.append("reset"),
		"disable_generated_weapon_renderers":func(): trace.append("disable_generated_weapons"),
		"apply_original_material":func(): trace.append("source_material"),
		"warn_missing_frame_data":func(): trace.append("warn"),
		"bind_uv_maps":_bind,
		"render_weapons":func(): trace.append("weapons"),
		"update_shadow_height":func(value): trace.append(["shadow",value]),
		"set_hit_outline":func(value): trace.append(["outline",value]),
		"update_body_depth":func(value): trace.append(["depth",value]),
		"apply_appearance":func(): trace.append("appearance"),
		"has_sequence":func(equip,key): trace.append(["has_sequence",equip,key]); return equip == "coat-seq" and key == "Dmg",
		"apply_sprite":func(equip,config): trace.append(["sprite",equip,config.type]),
		"apply_color":func(equip,config): trace.append(["color",equip,config.type]),
	}
	_refresh(false, true, "Idle", frame, body, head)
	check(trace == [["shadow",frame],"reset","uv",["outline",true],["depth",frame],"weapons","appearance",
		["color","glove-1","glove"],["sprite","coat-seq","coat"],["sprite","cloak-static","cloak"]], "足够输入严格按原顺序刷新")
	check(mat.get_shader_parameter("body_uv") == body and mat.get_shader_parameter("head_uv") == head, "原生材质分别接 Body 和 Head")
	_refresh(false, true, "Dmg", frame, null, head)
	check(trace == ["reset","uv","weapons",["has_sequence","coat-seq","Dmg"],["sprite","coat-seq","coat"],
		["has_sequence","cloak-static","Dmg"]], "缺任一个 UV 关闭依赖层，只恢复独立武器和本动作序列")
	check(mat.get_shader_parameter("body_uv") == null and mat.get_shader_parameter("head_uv") == null, "两张旧 UV 一起清除")
	_refresh(false, true, "Walk", null, body, head)
	check(trace == ["reset","uv","weapons",["has_sequence","coat-seq","Walk"],["has_sequence","cloak-static","Walk"]],
		"无有效帧即使有两个资源也不进常规装备")
	_refresh(false, false, "Idle", frame, body, head)
	check(trace == ["warn","reset"], "整个帧数据缺失与本动作缺帧分开")
	_refresh(true, false, "Idle", frame, body, head)
	check(trace == ["reset","disable_generated_weapons","source_material"], "原精灵直显先于普通帧和 UV 门禁")
	_refresh(false, true, "Idle", {"hit_outline_frame":false}, body, head)
	check(trace[3] == ["outline",false], "命中描边只取当前帧旗标")
	if failures == 0: print("PASS 换装刷新顺序和双 UV 门禁：%d 项" % checks)
	quit(1 if failures else 0)

func _bind(body_map: Texture2D, head_map: Texture2D) -> void:
	trace.append("uv")
	mat.set_shader_parameter("body_uv",body_map)
	mat.set_shader_parameter("head_uv",head_map)

func _refresh(direct: bool, has_data: bool, key: String, sample_frame: Variant,
		body_map: Texture2D, head_map: Texture2D) -> void:
	trace.clear()
	Refresh.refresh(direct,has_data,key,sample_frame,body_map,head_map,configs,slots,hooks)
