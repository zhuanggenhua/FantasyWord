extends SceneTree
## 私有作者图集验证，不用合成占位声明外观验收。
const View = preload("res://gameplay/clickmovetest/human_presentation.gd")
const Cue = preload("res://game_core/presentation/cue_play_character_animation.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr(message)
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		print("SKIP 私有 ChargedAttack 验证需要合同及原图集目录")
		quit(0); return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var view := View.new()
	root.add_child(view)
	if not view.configure(data,args[1]):
		printerr(view.last_error); quit(1); return
	view.driver.set_process(false)
	view.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clip: Animation = view.animator.get_animation("ChargedAttack")
	check(clip.length == 0.75 and clip.loop_mode == Animation.LOOP_NONE,"作者片段 0.75 秒、不循环，不按 Cue 窗口拉伸")
	check(clip.track_get_key_count(0) == 7,"六帧及末尾重复标签")
	for i in range(7): check(clip.track_get_key_time(0,i) == i*0.125,"作者 8Hz 时间")
	var cue := Cue.new()
	for row in range(4):
		cue.on_add(view.driver)
		check(cue.on_activate(" ChargedAttack "),"原 Cue 去空格并调用真实驱动")
		view.playback.set_direction(row)
		for label in range(6):
			if label > 0: view.animator.advance(0.125)
			var tex: AtlasTexture = view.sprite.texture
			var record: Dictionary = data.actions.ChargedAttack.directions[row][label]
			var original := Image.load_from_file(args[1].path_join(record.texture))
			var expected := Rect2i(int(record.rect[0]),original.get_height()-int(record.rect[1])-32,32,32)
			check(view.playback.current_label == label,"原六帧标签顺序")
			check(tex.get_image().get_data() == original.get_region(expected).get_data(),"四向实际作者 RGBA 像素一致")
		view.animator.advance(0.5)
		view.driver.advance_game_time(1.0)
		check(view.driver.current_animation_key == "ChargedAttack" and view.playback.current_label == 5,"ChargedAttack 自然结束不自创自动恢复")
		check(cue.on_remove() and view.driver.current_animation_key == "Idle","Cue 移除恢复默认")
	cue.on_add(view.driver); cue.on_activate("ChargedAttack")
	view.set_movement(Vector2.RIGHT)
	view.animator.advance(28.0/60.0)
	check(view.playback.current_label == 3,"假定同轮激活后经过帧 2 至 30 的 28/60 秒，尚未自然结束")
	check(cue.on_remove() and view.driver.current_animation_key == "Walk","移除恢复当前 locomotion，不固定 Idle")
	cue.on_add(view.driver); cue.on_activate("ChargedAttack")
	view.driver.try_play_animation("Idle")
	check(cue.on_remove() and view.driver.current_animation_key == "Idle","旧 Cue 不覆盖后来的不同动作")
	view.driver.try_lock_animation("Idle")
	cue.on_add(view.driver)
	check(cue.on_activate("ChargedAttack") and cue.on_remove() and view.driver.current_animation_key == "Idle","保留原动作锁成功但不切换语义")
	view.driver.clear_animation_lock()
	cue.on_add(view.driver)
	check(not cue.on_activate("NotImported") and cue.active_animation_key.is_empty(),"缺少动作不得生成替代")
	check(cue.on_remove() and cue.on_remove(),"未激活及重复移除没有恢复副作用")
	view.free()
	if failures == 0: print("PASS formal Human charged: "+str(checks)+" checks; real private atlas; NOT ECS/display scheduling or full migration acceptance")
	quit(0 if failures == 0 else 1)
