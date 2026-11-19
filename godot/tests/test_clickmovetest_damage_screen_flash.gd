extends SceneTree
const Flash = preload("res://gameplay/clickmovetest/source_damage_screen_flash.gd")
const Apply = preload("res://game_core/combat/formal_damage_application.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")

var _now := 30.0
var _checks := 0
var _failures := 0
var _health := 6
var _prepare_input: Dictionary


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var target := Node2D.new()
	root.add_child(target)
	var other := Node2D.new()
	root.add_child(other)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color(.2,.4,.6)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var flash := Flash.new()
	flash._clock = func(): return _now
	layer.add_child(flash)
	flash.set_process(false)
	if DisplayServer.get_name()=="headless": root.size = Vector2i(800,600)
	await process_frame
	_check(flash.size==Vector2(root.size) and flash.color.a==0.0
		and flash.mouse_filter==Control.MOUSE_FILTER_IGNORE,"全屏锚点与默认透明、不阻止输入")
	var normal := {"flags":0,"silent":false}
	_check(not flash.present(other,target,normal) and not flash.present(target,null,normal),
		"原来源掩码 1 排除其它受击目标和缺失的受控角色")
	_check(not flash.present(target,target,{"flags":Combat.MISS,"silent":false})
		and not flash.present(target,target,{"flags":0,"silent":true})
		and not flash.present(target,target,{"flags":0,"silent":false,"visual_flags":Flash.NO_SCREEN_FLASH}),
		"闪避、静默和独立 NoScreenFlash 表现位均拒绝")
	_now += .03
	flash._process(.0)
	_check(flash.present(target,target,normal) and flash.color.is_equal_approx(Color(.8,.15,.15,.144)),
		"普通红色首次让出前先衰减；未缩放步长 .03 秒")
	_now += .045
	flash._process(.002)
	_check(is_equal_approx(flash.color.a,.09),"下一帧线性非缩放衰减至一半")
	_check(flash.present(target,target,{"flags":Combat.CRITICAL,"silent":false})
		and flash.color.is_equal_approx(Color(1,1,1,.21)),"暴击换白并以 .30 重启，不与普通红叠加")
	_check(not flash.present(target,target,{"flags":Combat.CRITICAL,"silent":true})
		and is_equal_approx(flash.color.a,.21),"被过滤的新命中不清除已有反馈")
	_now += .11
	flash._process(.0)
	_check(flash.color.a==0.0,"独立于缩放时间的 0.15 秒结束")
	flash.present(target,target,normal)
	_now += .01
	flash._process(.0)
	flash.present(target,target,normal)
	flash.hide()
	_check(flash.color.a==0.0 and not flash.present(target,target,normal),"禁用时复位且不可重启")
	flash.show()
	var flags_after: Array = []
	var defender := {"snapshot":{}}
	var hooks := {"provoke":func(_s):pass,"has_formal_stats":func():return true,
		"current_health":func():return _health,"prepare":func(_s,input):_prepare_input=input,
		"apply_current_health_delta":func(delta,_min,_max,_s):
			_health=maxi(0,_health+delta)
			return _health,
		"complete":func(_s,input,previous,applied):
			flags_after.append([_health,previous,applied,input.visual_flags])
			flash.present(target,target,input)}
	var output := {"source":null,"snapshot":null,"damage":10,"flags":Combat.CRITICAL,"silent":false}
	_check(Apply.execute_damage_output(defender,output,false,Callable(),hooks,null,Flash.NO_SCREEN_FLASH)
		and flags_after==[[0,6,6,Flash.NO_SCREEN_FLASH]]
		and not _prepare_input.has("visual_flags") and flash.color.a==0.0,
		"正式扣血成功后才传独立表现位，致死但标记屏蔽时不闪")
	if DisplayServer.get_name()!="headless":
		# 真实 Viewport 读回验证两端像素实际混色；无头不冒充原生渲染。
		await RenderingServer.frame_post_draw
		var before := root.get_texture().get_image()
		flash.present(target,target,normal)
		await RenderingServer.frame_post_draw
		var after := root.get_texture().get_image()
		var expected := background.color.lerp(Color(.8,.15,.15),flash.color.a)
		for point in [Vector2i(5,5),root.size/2,root.size-Vector2i(6,6)]:
			_check(_rgb_near(before.get_pixelv(point),background.color)
				and _rgb_near(after.get_pixelv(point),expected),"原生全屏 RGB 混色 " + str(point))
	if _failures==0: print("PASS 原受伤闪屏：%d 项" % _checks)
	quit(1 if _failures else 0)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(label)

func _rgb_near(sample: Color, expected: Color) -> bool:
	return absf(sample.r-expected.r)<.013 and absf(sample.g-expected.g)<.013 and absf(sample.b-expected.b)<.013
