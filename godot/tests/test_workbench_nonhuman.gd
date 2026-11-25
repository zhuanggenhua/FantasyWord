extends SceneTree
const Preview := preload("res://gameplay/equipment_workbench/nonhuman_preview.gd")
const Scene := preload("res://gameplay/equipment_workbench/equipment_system_demo.tscn")
var checked := 0
var failed := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, desc: String) -> void:
	checked += 1
	if not ok:
		failed += 1
		printerr("FAIL ",desc)

func chip(parent: Node,key: String) -> void:
	var button: Button = parent.get_node(key)
	check(not button.disabled,key+" enabled")
	button.pressed.emit()

func run() -> void:
	if OS.get_environment("FANTASYWORD_WORKBENCH_NONHUMAN").is_empty():
		print("SKIP private pinned Orc/Goblin workbench assets not configured")
		quit()
		return
	var screen := Scene.instantiate()
	root.add_child(screen)
	await process_frame
	check(screen.ready_for_preview,"actual EquipmentSystemDemo boot: "+screen.last_error)
	var picker := screen.find_child("SourceCharacterPicker",true,false)
	if picker == null:
		screen.free()
		quit(1)
		return
	var action := screen.find_child("SourceActionRows",true,false)
	var terminal := {"Orc":"Die","Goblin":"SpinDie"}
	check(Array(picker.get_children()).map(func(n): return str(n.name))==["Human","Dwarf","Elf","Goblin","Orc"],"original catalog order")
	check(picker.get_node("Dwarf").disabled and picker.get_node("Elf").disabled,"no invented races")
	chip(action,"Attack")
	screen._set_cloth(false)
	var sample_textures := []
	var source := Preview.read_locked(OS.get_environment("FANTASYWORD_WORKBENCH_NONHUMAN"))
	for race in ["Orc","Goblin"]:
		chip(picker,race)
		var actor: Node2D = screen._race_views[race]
		check(actor.visible and not screen._human.visible and actor.playback.current_direction==0,"only new actor visible and direction reset")
		check(actor.playback.current_action=="Idle" and actor.playback.current_label==0,"new actor starts at original default Idle")
		check(actor.composite.get_shader_parameter("enabled_cloth") and actor.composite.get_shader_parameter("skin_color_count")==5,
			"logical default garment and five authored palette pairs independently owned by this actor")
		var idle: AtlasTexture = actor.sprite.texture
		sample_textures.append(idle.atlas)
		var p := Vector2i(17,13 if race=="Orc" else 14)
		var c := idle.atlas.get_image().get_pixelv(p)
		var expected := Color8(79,173,75) if race=="Orc" else Color8(135,198,79)
		check(c.is_equal_approx(expected),"original baked green is present in the underlying atlas, not fabricated by palette")
		screen._select_direction(3)
		check(actor.playback.current_direction==3 and actor.sprite.texture!=idle,"original separate NW Idle frames")
		chip(action,terminal[race])
		var body: Texture2D = actor.composite.get_shader_parameter("body_map")
		var head: Texture2D = actor.composite.get_shader_parameter("head_map")
		check(body.get_size()==Vector2(384,32) and head.get_size()==body.get_size(),"terminal sample owns its own two UV maps")
		check(body.get_image().get_pixel(0,0)==Color(0,0,0,0) and head.get_image().get_pixel(0,0)==Color(0,0,0,0),"authored zero channel control")
		actor.animator.seek(1.375,true)
		var final: Texture2D = actor.sprite.texture
		screen._select_direction(1)
		check(actor.playback.current_label==11 and actor.sprite.texture==final,"terminal label and sprite identity retained under direction switch")
		check(action.get_node("SlashAttack").disabled,"no unsupported Human-only body action offered")
		var actions: Dictionary = source.characters[race].actions
		check(actions.size()==14,"all authored distinct sprite actions admitted")
		for key in actions:
			chip(action,key)
			var spec: Dictionary = actions[key]
			var clip: Animation = actor.animator.get_animation(key)
			check(actor.playback.current_action==key and is_equal_approx(clip.length,spec.duration)
				and (clip.loop_mode==Animation.LOOP_LINEAR)==spec.loop,"original state duration and loop "+key)
			var atlas: Texture2D = actor.composite.get_shader_parameter("main_map")
			var map_body: Texture2D = actor.composite.get_shader_parameter("body_map")
			var map_head: Texture2D = actor.composite.get_shader_parameter("head_map")
			check(atlas.get_size()==Vector2(spec.body.size[0],spec.body.size[1])
				and map_body.get_size()==atlas.get_size() and map_head.get_size()==atlas.get_size()
				and actor.composite.get_shader_parameter("repeat_action_uv"),"action owns authored atlas and repeat maps "+key)
			var identities := {}
			for d in 4:
				screen._select_direction(d)
				for index in spec.times.size():
					var t: float = spec.times[index]
					if t >= spec.duration: continue
					actor.animator.seek(t,true)
					var label := int(spec.labels[index])
					var frame: AtlasTexture = actor.sprite.texture
					var entry: Dictionary = spec.directions[d][label]
					var rect: Array = entry.rect
					check(actor.playback.current_label==label and frame.atlas==atlas
						and frame.region==Rect2(rect[0],atlas.get_height()-rect[1]-rect[3],rect[2],rect[3]),
						"owner/frame "+race+" "+key+" "+str(d)+":"+str(label))
					if identities.has(entry.file_id):
						check(identities[entry.file_id]==frame,"authored identical Sprite shares frame resource "+key)
					identities[entry.file_id] = frame
			chip(action,key)
			check(actor.playback.current_label==int(spec.labels[0])
				and is_zero_approx(actor.animator.current_animation_position),"same action restarts at source time zero")
		screen._set_cloth(false)
		check(not actor.composite.get_shader_parameter("enabled_cloth"),"unequip only this character")
	check(sample_textures[0]!=sample_textures[1],"separate authored body atlases")
	chip(picker,"Human")
	check(screen._human.visible and screen._human.playback.current_direction==0 and screen._human.driver.current_animation_key=="Idle",
		"return to Human resets action, frame driver, and direction")
	check(screen._material.get_shader_parameter("enabled_cloth") and not action.get_node("Attack").disabled,"return to Human resets own gear and restores Human action buttons")
	chip(picker,"Orc")
	check(screen._race_views.Orc.composite.get_shader_parameter("enabled_cloth"),"reselect resets original Orc default gear")
	chip(picker,"Human")
	screen.free()
	print(("PASS " if failed == 0 else "FAIL ")+"Actual Orc/Goblin workbench picker: %d/%d passed" % [checked-failed,checked])
	quit(int(failed>0))
