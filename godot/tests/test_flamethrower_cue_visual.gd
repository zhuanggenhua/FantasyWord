extends SceneTree
const Visual = preload("res://game_core/presentation/flamethrower_cue_visual.gd")
const Direction = preload("res://game_core/presentation/movable_direction_state.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var visual := Visual.new()
	root.add_child(visual)
	check(not visual.configure("user://missing-original.png"),"拒绝缺失原图，不生成替代图")
	var wrong := FileAccess.open("user://wrong-original.png",FileAccess.WRITE)
	wrong.store_string("不是真正的原喷火序列")
	wrong.close()
	check(not visual.configure("user://wrong-original.png"),"摘要不符时拒绝加载")
	check(not visual.mount(Direction.new()),"原图缺失不能挂载")
	var path := OS.get_environment("FORMAL_FLAMETHROWER_PNG")
	if path.is_empty():
		print("原图未提供：仅拒绝路径检查；原序列/方向/生命周期未验收")
		visual.free()
		quit(1 if failures else 0)
		return
	check(visual.configure(path),"读取摘要锁定的原图")
	if visual.sprite == null:
		visual.free()
		quit(1)
		return
	var owner := Direction.new()
	owner.set_look_at_direction(Vector2(0,1))
	check(visual.mount(owner),"正式目标朝向信号挂载")
	check(visual.rotation == 0 and visual.current_frame() == 0,"OnEnable后mount identity覆盖，首帧0")
	check(visual.sprite.get_rect() == Rect2(0,-8,32,16),"原32x16左中枢轴，不拉伸")
	check(visual.sprite.scale == Vector2(.125,.125) and visual.sprite.position == Vector2(.35,0),"原PPU8和+.35偏移即4x2范围")
	owner.set_target_direction(Vector2(0,1),true)
	check(is_equal_approx(visual.rotation,-PI/2),"目标方向信号使用y翻转")
	owner.set_look_at_direction(Vector2.LEFT)
	check(is_equal_approx(visual.rotation,-PI/2),"有目标覆盖时不跟随玩法look方向")
	owner.set_target_direction(Vector2.ZERO,true)
	check(is_equal_approx(visual.rotation,-PI/2),"零目标方向不旋转")
	for i in range(1,17):
		visual.advance(1.0/14.0)
		var expected := int(floor(PackedFloat32Array([visual.animation_time()*14])[0])) % 8
		check(visual.current_frame()==expected and visual.sprite.frame==expected,"原14fps八帧序列%d"%i)
	visual.unmount()
	var time := visual.animation_time()
	visual.advance(1)
	check(not visual.sprite.visible and visual.animation_time()==time,"移除同步隐藏且停止推进")
	check(owner.get_signal_connection_list("target_direction_changed").is_empty(),"移除解绑正式信号")
	check(visual.mount(owner) and visual.current_frame()==0 and visual.animation_time()==time,"源OnEnable仅设首帧，不重置累计时间")
	visual.free()
	check(owner.get_signal_connection_list("target_direction_changed").is_empty(),"宿主树销毁解绑")
	print("原喷火表现合同 %d/%d；未等同Unity材质/排序截图验收"%[checks-failures,checks])
	quit(1 if failures else 0)
