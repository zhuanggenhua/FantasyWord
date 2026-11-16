extends SceneTree
const Playback = preload("res://game_core/presentation/directional_sprite_playback.gd")
const Driver = preload("res://game_core/presentation/character_action_animator_driver.gd")
var checks := 0
var failures := 0
var events: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func atlas_at(x: int, y: int) -> AtlasTexture:
	var image := Image.create(8,8,false,Image.FORMAT_RGBA8)
	image.fill(Color(float(x)/8.0,float(y)/8.0,0.5))
	var texture := AtlasTexture.new()
	texture.atlas = ImageTexture.create_from_image(image)
	texture.region = Rect2(x,y,1,1)
	return texture

func actions() -> Dictionary:
	var directions: Array = []
	for i in 4:
		# 标签 0/1 映射稀疏图集位置 1/6；末尾不足的方向已由源生成器补成重复纹理。
		var a := atlas_at(1,i)
		var b := atlas_at(6,i)
		directions.append([a,b,b])
	return {
		"Dmg":{"duration":0.5,"loop":false,"times":[0.0,0.125,0.25,0.375,0.5],
			"labels":[0,1,2,2,2],"directions":directions},
		"Idle":{"duration":0.5,"loop":true,"times":[0.0,0.5],"labels":[0,0],"directions":directions},
		"Walk":{"duration":0.5,"loop":true,"times":[0.0,0.5],"labels":[1,1],"directions":directions},
	}

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var owner := Node.new()
	root.add_child(owner)
	var playback := Playback.new()
	var player := AnimationPlayer.new()
	var sprite := Sprite2D.new()
	var driver := Driver.new()
	for node in [playback,player,sprite,driver]:
		owner.add_child(node)
	driver.set_process(false)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var data := actions()
	var invalid := data.duplicate(true)
	invalid.Dmg.directions.pop_back()
	check(not playback.configure(sprite,player,invalid) and player.get_animation_library_list().is_empty(), "缺方向时不能写入部分动画")
	for bad in [{1:data.Dmg}, {"a/b":data.Dmg}, {"a:b":data.Dmg}, {"a,b":data.Dmg}, {"a[b":data.Dmg}, {"bad":2}]:
		check(not playback.configure(sprite,player,bad) and player.get_animation_library_list().is_empty(), "非法名称或动作类型不部分写入")
	for mutation in [["duration","0.5"],["duration",NAN],["loop",1],["times","bad"],["labels",[0,1.5,2,2,2]],["directions",[1,2,3,4]]]:
		var bad := data.duplicate(true)
		bad.Dmg[mutation[0]] = mutation[1]
		check(not playback.configure(sprite,player,bad) and player.get_animation_library_list().is_empty(), "非法资源类型不截断或部分写入")
	check(playback.configure(sprite,player,data), "完整四向库配置")
	check(not playback.configure(sprite,player,data), "不覆盖既有库")
	driver.animator = player
	driver.action_keys.assign(["Idle","Walk","Dmg"])
	playback.sample_resolved.connect(func(action,label,direction,texture):
		events.append(["sample",action,label,direction,texture]))
	playback.direction_applied.connect(func(direction): events.append(["direction",direction]))
	check(driver.try_play_damage_animation(), "动作驱动开始原生动画")
	check(playback.current_action == "Dmg" and playback.current_label == 0, "原生动画采样动作和标签")
	var deadline := driver.pending_time
	player.advance(0.1875)
	driver.advance_game_time(0.1875)
	check(playback.current_label == 1 and sprite.texture.region.position.x == 6, "时间标签与稀疏图集位置分离")
	var position := player.current_animation_position
	events.clear()
	check(playback.set_direction(3), "中途切换四向库")
	check(player.current_animation_position == position and player.current_animation == "Dmg" and player.is_playing(), "切向不修改动画阶段或播放状态")
	check(driver.pending_time == deadline and driver.pending_key == "Dmg", "切向不修改自动恢复期限")
	check(sprite.texture == data.Dmg.directions[3][1] and sprite.texture.region.position == Vector2(6,3), "同标签立即解析新方向的实际纹理")
	check(events.size() == 2 and events[0][0] == "sample" and events[1] == ["direction",3], "先解析精灵后通知换装方向")
	events.clear()
	playback.set_facing_direction(Vector2.ZERO)
	check(events.is_empty() and playback.current_direction == 3, "静止方向不重新通知")
	playback.set_facing_direction(Vector2.RIGHT)
	check(playback.current_direction == 2 and sprite.texture == data.Dmg.directions[2][1], "向东保留北半区位")
	check(player.current_animation_position == position and driver.pending_time == deadline, "朝向事件不重新计时")
	playback.set_direction(3)
	check(not playback.set_direction(-1) and not playback.set_direction(4) and playback.current_direction == 3, "非法方向不变更")
	player.advance(0.1)
	check(playback.current_label == 2 and sprite.texture == data.Dmg.directions[3][2], "补帧标签不误当图集列")
	driver.set_movement(Vector2.RIGHT)
	driver.advance_game_time(0.3124)
	check(driver.current_animation_key == "Dmg", "临近原期限保持伤害动作")
	driver.advance_game_time(0.0002)
	check(driver.current_animation_key == "Walk" and playback.current_action == "Walk" and playback.current_label == 1, "原期限恢复当前移动动作")
	check(playback.current_direction == 3, "动作恢复不重置方向")
	check(driver.try_play_damage_animation(), "可以再次触发伤害")
	check(player.current_animation_position == 0.0 and playback.current_label == 0, "真正重播才回零")
	player.advance(0.5)
	check(playback.current_label == 2 and sprite.texture == data.Dmg.directions[3][2], "终点重复保持末帧")
	owner.free()
	if failures == 0: print("PASS directional sprite playback: ", checks)
	quit(0 if failures == 0 else 1)
