extends Control
## 正式 HUD 两类失败事件的提示；不自行决定命令能否成功。
const Commands := preload("res://game_core/interaction/character_command_executor.gd")
const Ability := preload("res://game_core/combat/active_ability_start_rules.gd")
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
const Text := preload("res://gameplay/clickmovetest/source_character_text.gd")
const HOLD := 1.5
const FADE := .5
# 锁定 HUD.prefab 的三个 Inspector 值，未知检查结果原样静默。
const REASONS := {Ability.Result.ON_COOLDOWN:"Ability on cooldown",
	Ability.Result.NOT_ENOUGH_MANA:"Not enough mana",
	Ability.Result.INCAPACITATED:"You cannot use abilities right now"}
# 原动态 Silver.ttf 的 hmtx；本提示的实际字符均由 Silver 覆盖。
const SILVER_DEFAULT := "不个互交位到制前动可在备对开当我打技控放施有标槽没现用界的移组能色装象这那里面"
var _atlas: Atlas
var _silver: FontFile
var _label: Text
var _spec: Dictionary
var _prior_tick := 0
var _shown_frame := 0
var _hold_left := 0.0
var _fade_time := 0.0
var _fading := false
var _pixels := 1.0
var value := ""

func bind(atlas: Atlas, silver_path: String) -> bool:
	if atlas==null or atlas.texture==null: return false
	_atlas=atlas
	_silver=Text.load_silver(silver_path)
	if _silver==null: return false
	var advances := {0x3002:600,0x76ee:1100,0x89d2:1100}
	for i in SILVER_DEFAULT.length(): advances[SILVER_DEFAULT.unicode_at(i)]=1200
	for code in advances:
		if not _silver.has_char(code): return false
	_spec={"size":32,"horizontal":2,"vertical":512,"overflow":0,"style":0,"hud_silver_advance":advances,
		"overflow_width":true}
	_label=Text.new()
	add_child(_label)
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_STOP
	hide()
	return true

func fit(width: float, pixels: float) -> void:
	position=Vector2(0,899)
	size=Vector2(width,32)
	_pixels=pixels
	if not value.is_empty(): _paint()

func on_ability_rejected(_code: int, reason: int) -> void:
	var message: String=REASONS.get(reason,"")
	if not message.is_empty(): present(message)

func on_command_failed(request: Dictionary, result: int) -> void:
	var message:=command_message(int(request.get("kind",-1)),result)
	if not message.is_empty(): present(message)

static func command_message(kind: int, reason: int) -> String:
	match reason:
		Commands.Failure.MISSING_INPUT_TARGET, Commands.Failure.INVALID_CONTROLLED_CHARACTER:
			return "" if kind in [Commands.Kind.MOVE,Commands.Kind.STOP_MOVE] else "当前没有可控制角色。"
		Commands.Failure.ACTOR_MISMATCH: return "这个角色不在当前控制组。"
		Commands.Failure.CONTROL_LOCKED: return "我现在不能控制这个角色。"
		Commands.Failure.INTERACTION_LOCKED:
			return "我现在不能交互。" if kind==Commands.Kind.INTERACT else ""
		Commands.Failure.MISSING_ABILITY:
			return "这个槽位没有装备技能。" if kind==Commands.Kind.FIRE_ABILITY else ""
		Commands.Failure.INVALID_TARGET:
			if kind==Commands.Kind.CLICK_MOVE: return "没有可用的移动目标。"
			if kind==Commands.Kind.INTERACT: return "没有可交互对象。"
		Commands.Failure.BLOCKED_BY_STATE:
			match kind:
				Commands.Kind.INTERACT: return "没有可交互对象。"
				Commands.Kind.CLICK_MOVE: return "我现在不能移动到那里。"
				Commands.Kind.OPEN_GAME_MENU: return "我现在不能打开这个界面。"
				Commands.Kind.FIRE_ABILITY: return "我现在不能施放技能。"
		Commands.Failure.NOT_RUNNING:
			if kind==Commands.Kind.OPEN_GAME_MENU: return "我现在不能打开这个界面。"
			if kind==Commands.Kind.FIRE_ABILITY: return "我现在不能施放技能。"
	return ""

func present(message: String) -> void:
	value=message
	if not _paint():
		_clear()
		push_error("技能失败提示无法使用锁定的原字体合同。")
		return
	modulate.a=1.0
	_show_clock()
	show()

func _paint() -> bool:
	return _label.configure(_atlas,_silver,value,Rect2(Vector2.ZERO,size),_spec,_pixels)

func _show_clock() -> void:
	_hold_left=HOLD
	_fade_time=0.0
	_fading=false
	_shown_frame=Engine.get_process_frames()
	_prior_tick=Time.get_ticks_usec()

func _process(delta: float) -> void:
	var next:=Time.get_ticks_usec()
	var elapsed:=float(next-_prior_tick)/1000000.0
	_prior_tick=next
	if value.is_empty() or _shown_frame==Engine.get_process_frames(): return
	advance(get_tree().paused or Engine.time_scale<=0.0,delta,elapsed)

func advance(paused: bool, scaled_delta: float, real_delta: float) -> void:
	if value.is_empty(): return
	if not _fading:
		if not paused: _hold_left=maxf(0.0,_hold_left-scaled_delta)
		if _hold_left<=0.0: _fading=true
		# 等待结束帧的第一步 α=1；等待尾部不穿越到不同比例的淡出。
		return
	_fade_time=minf(FADE,_fade_time+real_delta)
	modulate.a=1.0-_fade_time/FADE
	if _fade_time>=FADE: _clear()

func _clear() -> void:
	value=""
	modulate.a=0.0
	_fading=false
	hide()
