extends SceneTree
## 私有原图采样验收；不是 Unity/Godot 渲染截图一致性验收。
const Scene = preload("res://gameplay/clickmovetest/entry.tscn")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2, "需要私有 animation.json 和原图目录")
	var data = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	assert(data is Dictionary)
	var host = Scene.instantiate()
	root.add_child(host)
	await process_frame
	var view = host.start_human_presentation(data,args[1])
	assert(view != null)
	assert(view.get_parent() == host.visual_body)
	assert(host.visual_body.position == Vector2(0.75,3.1))
	assert(host.actor.position == Vector2.ZERO)
	assert(view.sprite.scale == Vector2.ONE/8.0)
	assert(view.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	var checked := 0
	for action in ["Idle","Walk"]:
		var count := 16 if action == "Idle" else 4
		var duration := 2.0 if action == "Idle" else 0.5
		var anim: Animation = view.animator.get_animation(action)
		assert(anim.length == duration and anim.loop_mode == Animation.LOOP_LINEAR)
		assert(anim.track_get_key_count(0) == count+1)
		assert(anim.track_get_key_time(0,count) == duration)
		view.driver.try_play_animation(action)
		for direction in 4:
			view.driver.try_play_animation(action)
			view.playback.set_direction(direction)
			for label in count:
				assert(anim.track_get_key_time(0,label) == label*0.125)
				if label > 0: view.animator.advance(0.125)
				assert(view.playback.current_label == label)
				var tex: AtlasTexture = view.sprite.texture
				# 此映射独立 FileID/.meta join 核实，非据图猜测。
				assert(tex.region == Rect2(label*32,direction*32,32,32))
				var original := Image.load_from_file(args[1].path_join(data.actions[action].directions[direction][label].texture))
				assert(tex.get_image().get_data() == original.get_region(Rect2i(label*32,direction*32,32,32)).get_data())
				checked += 1
		view.animator.advance(0.124)
		assert(view.playback.current_label == count-1)
		var position: float = view.animator.current_animation_position
		view.playback.set_direction(0)
		assert(view.animator.current_animation_position == position)
		view.animator.advance(0.002)
		assert(view.playback.current_label == 0)
	view.set_movement(Vector2.ZERO)
	assert(view.animator.current_animation == "Idle")
	view.set_movement(Vector2(1,0))
	assert(view.animator.current_animation == "Walk")
	view.set_movement(Vector2.ZERO)
	assert(view.animator.current_animation == "Idle")
	assert(checked == 80)
	host.free()
	print("PASS formal Human private source: 80 atlas crops, exact clip keys, loop, direction continuity, explicit entry attachment; NOT full render acceptance")
	quit()
