extends SceneTree
const Prefs := preload("res://game_core/audio/source_audio_preferences.gd")
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func key_edge(pressed: bool) -> void:
	var k := InputEventKey.new()
	k.physical_keycode=KEY_ESCAPE
	k.pressed=pressed
	root.push_input(k,true)

func run() -> void:
	var receiver := {"master":-1.0, "sfx":-1.0, "calls":0}
	var prefs := Prefs.new()
	var path := "user://prefs-test-%s.cfg"%Time.get_ticks_usec()
	var listener := func(g): receiver.master=g
	var sfx := func(g): receiver.sfx=g; receiver.calls+=1
	check(prefs.start(path,listener,{3:sfx}) and receiver.master==0.5 and receiver.sfx==0.5,"distinct master and channel default ports")
	check(prefs.display(-1)=="5 / 10" and prefs.display(0)=="5 / 10" and prefs.display(1)=="5 / 10"
		and prefs.display(2)=="5 / 10" and prefs.display(3)=="5 / 10","five original values and suffix")
	check(prefs.adjust(-1,-1) and prefs.display(-1)=="4 / 10" and is_equal_approx(receiver.master,.4)
		and receiver.sfx==.5,"master set separately from channel")
	check(prefs.adjust(3,1) and prefs.display(3)=="6 / 10" and is_equal_approx(receiver.sfx,.6)
		and prefs.display(0)=="5 / 10","only channel 3 changes")
	check(not prefs.adjust(4,1) and not prefs.adjust(3,0) and prefs.display(4)=="","unconfigured miscellaneous cannot become a row")
	check(Prefs.round_ties_even(2.5)==2.0 and Prefs.round_ties_even(-2.5)==-2.0
		and Prefs.round_ties_even(3.5)==4.0 and Prefs.round_ties_even(-3.5)==-4.0,"original midpoint pair")
	for i in range(12): prefs.adjust(1,-1); prefs.adjust(2,1)
	check(prefs.display(1)=="0 / 10" and prefs.display(2)=="10 / 10","source steps saturate")
	check(not FileAccess.file_exists(path),"changing settings does not save before AudioSystem stop")
	check(prefs.stop()==OK and FileAccess.file_exists(path) and not prefs.adjust(-1,1),"save on stop and reject inactive edits")
	check(prefs.start(path,listener,{3:sfx}) and prefs.display(-1)=="4 / 10" and prefs.display(3)=="6 / 10"
		and prefs.display(1)=="0 / 10" and prefs.display(2)=="10 / 10","next original session reads its five own values")
	check(prefs.stop()==OK,"stop closes second session")
	if OS.get_environment("FORMAL_SURFACE_RULES")!="" and OS.get_environment("FORMAL_PAUSE_SOURCE")!="":
		await live()
	else:
		print("SKIP locked source live audio")
	print("Source Settings AudioSystem: %d/%d" % [checks-failures,checks])
	quit(1 if failures else 0)

func live() -> void:
	var master_before := AudioServer.get_bus_volume_linear(0)
	root.size=Vector2i(960,540)
	var main: String=ProjectSettings.get_setting("application/run/main_scene")
	check(change_scene_to_file(main)==OK,"start real ClickMoveTest")
	await scene_changed
	await process_frame
	var startup := current_scene as Boot
	if startup==null or startup.audio_preferences==null or startup.pause_root==null:
		check(false,"real AudioSystem and pause owner exist")
		return
	var prefs := startup.audio_preferences
	var flames: Node = startup.scene.flamethrower_audio
	var path := "user://fantasyword-source-audio.cfg"
	var had_file := FileAccess.file_exists(path)
	var stored_before := FileAccess.get_file_as_string(path) if had_file else ""
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0),prefs.volume(-1))
		and is_equal_approx(flames.volume_scale,prefs.volume(3)) and flames.activate(),"original cue bound to actual master and GameplaySoundFX")
	var first := flames.get_child(0) as AudioStreamPlayer
	key_edge(true); key_edge(false)
	check(paused and first.playing and not first.stream_paused,"real pause does not freeze audio")
	var channel_before := prefs.volume(3)
	prefs.adjust(-1,-1 if prefs.volume(-1)>0.0 else 1)
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0),prefs.volume(-1))
		and is_equal_approx(first.volume_linear,channel_before),"native master leaves active channel gain unchanged")
	var next_direction := 1 if prefs.volume(3)<1.0 else -1
	prefs.adjust(3,next_direction)
	check(is_equal_approx(first.volume_linear,prefs.volume(3)) and flames.activate(),"live change reaches active and subsequent pooled voice")
	var second := flames.get_child(1) as AudioStreamPlayer
	check(second.playing and is_equal_approx(second.volume_linear,prefs.volume(3)),"next warmed voice uses current channel gain")
	key_edge(true); key_edge(false)
	check(not paused and FileAccess.file_exists(path)==had_file
		and (not had_file or FileAccess.get_file_as_string(path)==stored_before),"popping Pause does not resave or reinitialize preferences")
	var new_values := [prefs.volume(-1),prefs.volume(3)]
	# Drain actual audio voices instead of racing the audio thread at teardown.
	var deadline := Time.get_ticks_usec()+3500000
	while flames.active_voice_count()>0 and Time.get_ticks_usec()<deadline:
		await process_frame
	check(flames.active_voice_count()==0,"actual pooled voices naturally finish")
	await create_timer(0.12,true,false,true).timeout
	startup.free()
	await process_frame
	var saved := ConfigFile.new()
	check(saved.load(path)==OK and is_equal_approx(saved.get_value(Prefs.GROUP,Prefs.preference_key(-1),-1),new_values[0])
		and is_equal_approx(saved.get_value(Prefs.GROUP,Prefs.preference_key(3),-1),new_values[1]),
		"the real source host persists both gains on AudioSystem stop")
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0),master_before),"teardown releases listener ownership")
