extends SceneTree
## Private source verification; no source assets are tracked.
const ImageView := preload("res://gameplay/clickmovetest/source_character_apply_image.gd")
const Tiled := preload("res://gameplay/clickmovetest/source_menu_tiled_image.gd")

func _initialize() -> void:
	var p := OS.get_environment("FORMAL_PAUSE_SOURCE")
	if p.is_empty():
		print("SKIP UICharacter Apply sprite needs the authenticated private source")
		quit(0)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(p.path_join("character-layout.json")))
	var pause: Variant = JSON.parse_string(FileAccess.get_file_as_string(p.path_join("pause-contract.json")))
	if not data is Dictionary or not pause is Dictionary:
		push_error("Missing UICharacter layout and Pause contracts")
		quit(1)
		return
	var view := ImageView.new()
	var background := Tiled.new()
	root.add_child(view)
	root.add_child(background)
	pause.tiled_images["Settings Background"]={"sprite_id":"-1443275623","fill_center":true,"ppu_multiplier":1,
		"color":{"r":1,"g":1,"b":1,"a":1}}
	pause.sprites["-1443275623"]={"rect":{"x":96,"y":88,"width":24,"height":24},"border":{"x":3,"y":3,"z":3,"w":3}}
	if not background.bind(pause,p.path_join("SPS_GUI.png"),"Settings Background"):
		push_error("Original background/atlas not admitted")
		quit(1)
		return
	var failures := 0
	var tampered: Dictionary = data.apply.sprite_state.duplicate(true)
	tampered.pressed.border[3]=2
	if view.bind(tampered,background) or not view.bind(data.apply.sprite_state,background):
		push_error("Apply accepts only the original states")
		quit(1)
		return
	var states := {"normal":[73,1,2],"highlighted":[105,1,2],"pressed":[121,1,3],"selected":[105,1,2],"disabled":[121,17,2]}
	var atlas_height := background.get_atlas_texture().get_height()
	for key in states:
		view.show_button_state(key)
		var spec: Array = states[key]
		var patches := view.patches(Vector2(448,112))
		if patches.size()!=9 or patches[0].destination!=Rect2(0,0,12,spec[2]*6) 				or patches[0].source!=Rect2(spec[0],atlas_height-spec[1]-14,2,spec[2]) 				or patches[4].destination!=Rect2(12,spec[2]*6,424,100-spec[2]*6) 				or patches[8].destination!=Rect2(436,100,12,12):
			push_error("Wrong sliced geometry "+key)
			failures+=1
	if failures==0: print("PASS UICharacter Apply authenticated five states, sliced mesh, source-axis flip, and rejection")
	quit(failures)
