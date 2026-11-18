extends SceneTree
const CueAudio = preload("res://gameplay/combat/flamethrower_cue_audio.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var audio := CueAudio.new()
	root.add_child(audio)
	check(audio.get_child_count() == 4, "Original four voices prewarmed")
	check(audio.volume_scale == 0.5, "Original channel volume default")
	check(not audio.activate(), "Missing private asset cannot manufacture playback")
	check(not audio.configure_locked_clip("res://project.godot"), "Reject wrong content hash")
	var path := OS.get_environment("FORMAL_FLAMETHROWER_AUDIO")
	if path.is_empty():
		print("SKIP exact original OGG playback: FORMAL_FLAMETHROWER_AUDIO unset")
	else:
		check(audio.configure_locked_clip(path), "Locked original Vorbis loads")
		for index in 6:
			check(audio.activate(), "Overlapping activation %s" % index)
		check(audio.active_voice_count() == 6 and audio.get_child_count() == 6, "Multiple mode unlimited, no voice stealing")
		for voice in audio.get_children():
			check(voice is AudioStreamPlayer and not voice is AudioStreamPlayer2D, "Non-spatial Play route")
			check(voice.stream != null and not voice.stream.loop and voice.pitch_scale == 1, "Non-loop pitch1")
			check(is_equal_approx(voice.volume_linear, 0.5), "Single channel gain, not squared")
		audio.remove_cue()
		check(audio.active_voice_count() == 6, "Cue removal does not stop voices")
		audio.set_volume_scale(0.2)
		for voice in audio.get_children():
			check(is_equal_approx(voice.volume_linear, 0.2), "Live host channel volume propagated")
		audio.pause()
		check(audio.activate(), "Can activate while channel paused")
		for voice in audio.get_children():
			check(voice.stream_paused, "Existing and new voices share pause")
		audio.resume()
		await create_timer(2.3).timeout
		check(audio.active_voice_count() == 0, "Natural clip completion recycles all voices")
		check(audio.activate() and audio.get_child_count() == 7, "Pool reused")
		audio.stop_channel()
		check(audio.active_voice_count() == 0, "Channel stop differs from cue removal")
	audio.free()
	# Let AudioServer retire its final stopped playback reference.
	await create_timer(0.1).timeout
	print("Flamethrower audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
