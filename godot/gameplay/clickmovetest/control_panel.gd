extends ColorRect
## ClickMoveTest 明确的场景诊断面板，只观察移动所有者/点击，不提交玩法命令。
const Movement = preload("res://game_core/movement/character_movement.gd")
const SILVER_SHA := "7adcf56d93142ded08ff18196f78fcaaf552411b9a94dc559dac90eb5c91cef1"
const CJK_SHA := "763146584cf0710223441356b4395e279021b0806c196614377a7a0174ae074a"
@onready var title: Label = $Title
@onready var body: Label = $Body
var _last_order := false
var _last_position := Vector2.ZERO
var _source_bound := false


func bind_fonts(silver_path: String, cjk_path: String) -> bool:
	if _source_bound or not is_node_ready(): return false
	var silver := _load_exact_font(silver_path,SILVER_SHA)
	var cjk := _load_exact_font(cjk_path,CJK_SHA)
	if silver==null or cjk==null: return false
	silver.fallbacks = [cjk]
	var bold := FontVariation.new()
	bold.base_font = silver
	# Godot 原生加粗，不宣称等于原 TMP 的 SDF WeightBold 渲染。
	bold.variation_embolden = .75
	title.add_theme_font_override("font",bold)
	body.add_theme_font_override("font",silver)
	_source_bound = true
	return true


func _load_exact_font(path: String, expected: String) -> FontFile:
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=expected: return null
	var font := FontFile.new()
	font.allow_system_fallback = false
	return font if font.load_dynamic_font(path)==OK else null


func layout_for_height(pixels: float) -> void:
	if pixels<=0.0: return
	var factor := pixels/1080.0
	scale = Vector2.ONE*factor
	position = Vector2(28,28)*factor


func show_live_state(live: Dictionary, click: Dictionary) -> void:
	if click.has("order_after_updates"):
		_last_order = click.order_after_updates
		_last_position = click.position_after_updates
	var directional: bool = live.get("mode",-1)==Movement.Mode.DIRECTIONAL
	var mode := _mode(live.get("mode",-1))
	var runtime := "运行时状态：当前没有接到玩家控制组件"
	if live.get("has_body",false):
		runtime = "运行时状态：输入目标=%s，可移动=%s，当前有移动指令=%s，当前位置=%s" % [
			"CharacterPlayerControl" if live.get("had_input_target",false) else "无",
			_answer(live.could_move),_answer(live.order),_point(live.position)]
	var last := "最近一次点击：还没有收到 Gameplay 点击输入"
	if click.has("frame"):
		var screen: Vector2 = click.get("source_screen_position",click.screen_position)
		last = "最近一次点击：frame=%d，屏幕=(%.0f, %.0f)，世界=%s\n" % [click.frame,screen.x,screen.y,_point(click.world_position)]
		last += "点击诊断：命中UI=%s，有输入目标=%s，点击时模式=%s，点击时可移动=%s，点击后生成移动指令=%s，点击后角色位置=%s" % [
			_answer(click.over_ui),_answer(click.had_input_target),_mode(click.movement_mode),
			_answer(click.could_move),_answer(_last_order),_point(_last_position)]
	var updated := "当前移动模式：%s\n%s\n左键点地：点击移动\nTab：切换 点击移动 / WASD\nWASD / 方向键：方向移动对照\n镜头判断：如果角色总在屏幕中间，就看场景里的空白参照块是否相对屏幕滑动。\n%s\n%s" % [
		mode,runtime,
		"当前是方向移动模式，左键点地不会驱动角色移动。" if directional else "当前是点击移动模式，左键点地会让玩家前往目标点。",
		last]
	if body.text!=updated: body.text=updated


static func _mode(value: int) -> String:
	if value<0: return "未接到玩家控制组件"
	return "点击移动" if value==Movement.Mode.CLICK_TO_MOVE else "方向移动"


static func _answer(value: bool) -> String:
	return "是" if value else "否"


static func _point(value: Vector2) -> String:
	return "(%.2f, %.2f)" % [value.x,value.y]
