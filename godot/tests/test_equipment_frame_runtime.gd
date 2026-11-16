extends SceneTree
const Runtime = preload("res://game_core/presentation/equipment_frame_runtime.gd")
const Mode = preload("res://game_core/presentation/equipment_refresh_order.gd").RenderMode
const Playback = preload("res://game_core/presentation/directional_sprite_playback.gd")
const Driver = preload("res://game_core/presentation/character_action_animator_driver.gd")
var checks := 0
var failures := 0
var trace: Array = []
var runtime := Runtime.new()
var current_maps: Array = []
var actor := Node.new()
var sprite := Sprite2D.new()
var playback := Playback.new()
var player := AnimationPlayer.new()
var driver := Driver.new()
var frame2 := {"frame_index":3,"row_index":2,"hit_outline_frame":false}
var alternate := {"frame_index":3,"row_index":3,"hit_outline_frame":true}
var frame6 := {"frame_index":6,"row_index":3,"hit_outline_frame":true}

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _run() -> void:
	root.add_child(actor)
	for n in [sprite,playback,player,driver]: actor.add_child(n)
	driver.set_process(false)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var img := ImageTexture.create_from_image(Image.create_empty(64,32,false,Image.FORMAT_RGBA8))
	var other := ImageTexture.create_from_image(Image.create_empty(64,32,false,Image.FORMAT_RGBA8))
	var dirs: Array = []
	var dmg_dirs: Array = []
	for direction in range(4):
		dirs.append([region(img,3,direction),region(img,6,direction)])
		dmg_dirs.append([region(other,3,direction),region(other,6,direction)])
	var idle := {"duration":0.5,"loop":true,"times":[0.0,0.25],"labels":[0,1],"directions":dirs}
	var dmg := {"duration":0.5,"loop":false,"times":[0.0,0.25],"labels":[0,1],"directions":dmg_dirs}
	check(playback.configure(sprite,player,{"Idle":idle,"Dmg":dmg,"Wait":idle}),"原生动作离散配置")
	driver.animator = player
	driver.action_keys = ["Idle","Dmg","Wait"]
	runtime.frame_data = {
		"Idle":{"frame_size":Vector2i(8,8),"frames":[frame2,alternate,frame6],"body_uv":img,"head_uv":img},
		"Dmg":{"frame_size":Vector2i(8,8),"frames":[frame6],"body_uv":other},
	}
	runtime.configs = [{"mode":Mode.SPRITE,"type":"coat"}]
	runtime.slots = {"coat":"coat-1"}
	runtime.hooks = {
		"bind_uv_maps":_uv,
		"reset_layers":func(): trace.append("reset"),
		"render_weapons":func(): trace.append("weapons"),
		"disable_generated_weapon_renderers":func(): trace.append("disable"),
		"warn_missing_frame_data":func(): trace.append("warn"),
		"apply_original_material":func(): trace.append("original"),
		"update_shadow_height":func(_f): trace.append("shadow"),
		"set_hit_outline":func(v): trace.append(["outline",v]),
		"update_body_depth":func(_f): pass,
		"apply_appearance":func(): trace.append("appearance"),
		"has_sequence":func(_equip,key): return key == "Dmg",
		"apply_sprite":func(_equip,_cfg): trace.append("sprite"),
		"apply_color":func(_equip,_cfg): pass,
	}
	playback.direction_applied.connect(runtime.set_preview_direction)
	driver.set_movement(Vector2.ZERO)
	playback.set_direction(3)
	runtime.late_sync(driver.current_animation_key,sprite.texture)
	check(is_same(runtime.cursor.cached_frame,alternate) and playback.current_label == 0 and runtime.cursor.frame_index == 3,
		"标签0选中的实际图集是第3列，不把标签当帧索引")
	check(current_maps == [img,img] and trace.find(["outline",true]) >= 0,"绑定已解析动作双图及帧标志")
	trace.clear()
	runtime.late_sync(driver.current_animation_key,sprite.texture)
	check(trace.is_empty(),"LateUpdate 不重复刷新同一 Sprite 引用")
	player.advance(0.3)
	runtime.late_sync(driver.current_animation_key,sprite.texture)
	check(is_same(runtime.cursor.cached_frame,frame6) and playback.current_label == 1 and runtime.cursor.frame_index == 6,
		"新采样标签1落在第6列")
	driver.try_play_damage_animation()
	trace.clear()
	runtime.late_sync(driver.current_animation_key,sprite.texture)
	check(runtime.action_key == "Dmg" and runtime.cursor.cached_frame == null and current_maps == [null,null],
		"切入缺有效帧及 Head UV 的 Dmg，不残留旧动作双贴图")
	check(trace == [["uv",other,null],"reset",["uv",null,null],"weapons","sprite"],
		"源动作先写独立 UV，再根据帧检查清双 UV，仅留本动作序列")
	driver.try_play_animation("Wait")
	trace.clear()
	runtime.late_sync(driver.current_animation_key,sprite.texture)
	check(runtime.action_key == "Wait" and is_same(runtime.cursor.cached_frame,alternate) and current_maps == [img,img],
		"Wait 仅借用 Idle 帧数据，动作键不改写")
	check(Runtime.resolve_body_data({"SpinDie":{"id":1},"Idle":{"id":2}},"Die").id == 1
		and Runtime.resolve_body_data({"Idle":{"id":2}},"Dmg").is_empty(),
		"限定的死亡帧兼容顺序；无 Dmg 来源不假定 Idle")
	trace.clear()
	runtime.original_sprite_direct = true
	runtime.late_sync("Dmg",sprite.texture)
	check(trace == ["original"] and runtime.action_key == "Wait","原图直显 LateUpdate 只保持材质")
	actor.free()
	if failures == 0: print("PASS 原生离散精灵至换装帧/UV 刷新：%d 项" % checks)
	quit(1 if failures else 0)

func region(tex: Texture2D, col: int, row: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(col*8,row*8,8,8)
	return a

func _uv(body: Texture2D, head: Texture2D) -> void:
	current_maps = [body,head]
	trace.append(["uv",body,head])
