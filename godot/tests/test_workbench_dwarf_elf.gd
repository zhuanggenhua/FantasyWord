extends SceneTree
const Scene := preload("res://gameplay/equipment_workbench/equipment_system_demo.tscn")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",msg)
func click(group: Node,key: String) -> void:
	var b: Button = group.get_node(key)
	check(not b.disabled,key+" source-bound chip enabled")
	b.pressed.emit()

func run() -> void:
	if OS.get_environment("FANTASYWORD_WORKBENCH_DWARF_ELF").is_empty():
		print("SKIP private pinned Dwarf/Elf workbench assets not configured")
		quit()
		return
	var screen := Scene.instantiate()
	root.add_child(screen)
	await process_frame
	check(screen.ready_for_preview,"EquipmentSystemDemo booted both pairs: "+screen.last_error)
	var picker := screen.find_child("SourceCharacterPicker",true,false)
	if picker == null:
		screen.free()
		quit(1)
		return
	var actions := screen.find_child("SourceActionRows",true,false)
	var count := 0
	for name_key in ["Dwarf","Elf"]:
		click(picker,name_key)
		var actor: Node2D = screen._race_views[name_key]
		check(actor.visible and not screen._human.visible and actor.playback.current_action=="Idle"
			and actor.playback.current_direction==0,"independent source actor reset")
		check(actor.composite.get_shader_parameter("enabled_cloth") and
			not actor.composite.get_shader_parameter("skin_palette_enabled"),"original Cloth with unmodified human-base appearance domain")
		check(actor.composite.get_shader_parameter("enabled_hair") and actor.composite.get_shader_parameter("enabled_beard"),
			"original base appearance textures bind")
		var idle: AtlasTexture = actor.sprite.texture
		check(actor._maps.size()==14,"all and only authored body actions")
		for key in actor._maps:
			click(actions,key)
			count += 1
			var maps: Dictionary=actor._maps[key]
			check(actor.playback.current_action==key and actor.composite.get_shader_parameter("main_map")==maps.atlas
				and actor.composite.get_shader_parameter("body_map")==maps.body
				and actor.composite.get_shader_parameter("head_map")==maps.head,
				"each actual chip binds its own original atlas and UV maps")
			for d in 4:
				screen._select_direction(d)
				var f = actor._cursor.cached_frame
				check(f is Dictionary and actor._cursor.last_sprite==actor.sprite.texture and actor.playback.current_direction==d,
					"actual sprite owns selectable direction and corresponding equipment frame")
				var head: int=f.body_regions.get("head",{}).get("sprite_facing",actor._cursor.row_index)
				check(actor.composite.get_shader_parameter("enabled_left_eye")==((head in [0,1]) and not f.left_eye_closed)
					and actor.composite.get_shader_parameter("enabled_eye_decoration")==(head in [0,1]),
					"material uses authored head and eyelid flags")
		click(actions,"SpinDie")
		check(actor.sprite.texture.atlas!=idle.atlas,"death and idle owner are different authored atlases")
		actor.animator.seek(1.25,true)
		var penultimate: Texture2D=actor.sprite.texture
		actor.animator.seek(1.375,true)
		check(actor.playback.current_label==11 and (actor.sprite.texture==penultimate)==(name_key=="Dwarf")
			and actor._cursor.frame_index==(10 if name_key=="Dwarf" else 11),"Dwarf repeats its own penultimate sprite; Elf does not")
		screen._set_cloth(false)
		check(not actor.composite.get_shader_parameter("enabled_cloth"),"unwear writes current race cloth slot")
	check(count==28,"both complete source body-preview sets exercised")
	if screen._race_views.has("Goblin"):
		click(picker,"Goblin")
		check(screen._race_views.Goblin.composite.get_shader_parameter("skin_palette_enabled")
			and not screen._race_views.Goblin.composite.get_shader_parameter("enabled_hair"),"green appearance remains isolated")
	click(picker,"Human")
	check(screen._human.visible and screen._material.get_shader_parameter("enabled_cloth")
		and screen._human.driver.current_animation_key=="Idle","Human returns to its independent default action and outfit")
	screen.free()
	print(("PASS " if failures==0 else "FAIL ")+"Actual Dwarf/Elf workbench: %d/%d passed"%[checks-failures,checks])
	quit(int(failures!=0))
