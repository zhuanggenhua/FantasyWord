extends SceneTree
const Driver = preload("res://game_core/presentation/character_action_animator_driver.gd")
var failures := 0
var checks := 0
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var driver := Driver.new()
	root.add_child(driver)
	driver.set_process(false)
	var player := AnimationPlayer.new()
	driver.add_child(player)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := AnimationLibrary.new()
	# Empty test clips only: Dmg duration is source shared clip's 0.5 seconds.
	# These do NOT reconstruct SpriteResolver hashes, sprites, or visual acceptance.
	for key in ["Idle", "Walk", "Dmg", "SpinDie", "Base Layer.Attack"]:
		var clip := Animation.new()
		clip.length = 0.5
		library.add_animation(key, clip)
	player.add_animation_library("", library)
	driver.animator = player
	driver.action_keys.assign(["Idle", "Walk", "Dmg", "SpinDie", "Attack", "Missing"])
	check(driver.try_play_animation(" Idle ") and player.current_animation == "Idle", "native idle playback")
	check(not driver.try_play_animation("Missing") and player.current_animation == "Idle", "missing state fails without substitute")
	check(not driver.try_play_animation("dmg"), "case sensitive database")
	check(driver.try_play_animation("Attack") and player.current_animation == "Base Layer.Attack", "full state path resolution")
	driver.set_movement(Vector2.RIGHT)
	check(driver.current_animation_key == "Attack", "movement cannot steal non-locomotion action")
	check(driver.try_play_damage_animation() and player.current_animation == "Dmg", "damage plays real native AnimationPlayer state")
	check(driver.pending_fallback_key == "Idle" and is_equal_approx(driver.pending_time, 0.5), "source initial default and active clip duration")
	player.advance(0.2)
	check(is_equal_approx(player.current_animation_position, 0.2), "native playback position advances")
	driver.advance_game_time(0.499)
	check(driver.current_animation_key == "Dmg", "not restored before deadline")
	driver.set_movement(Vector2.RIGHT)
	driver.advance_game_time(0.001)
	check(driver.current_animation_key == "Walk" and player.current_animation == "Walk" and driver.pending_key.is_empty(), "deadline restores latest movement and clears timer")
	driver.try_play_damage_animation()
	driver.advance_game_time(0.3)
	player.advance(0.3)
	check(is_equal_approx(player.current_animation_position, 0.3), "repeat starts from actually advanced native position")
	driver.try_play_damage_animation()
	check(is_zero_approx(player.current_animation_position), "repeated damage restarts native clip")
	driver.advance_game_time(0.3)
	check(driver.current_animation_key == "Dmg", "repeated damage reschedules deadline")
	driver.advance_game_time(0.2)
	check(driver.current_animation_key == "Idle", "repeat restores initial default without subsequent movement callback")
	driver.try_play_damage_animation()
	var saved_deadline: float = driver.pending_time
	check(not driver.try_play_animation("Missing") and driver.pending_time == saved_deadline, "failed action preserves pending damage restore")
	driver.advance_game_time(0.0)
	check(driver.current_animation_key == "Dmg", "zero scaled delta cannot expire timer")
	driver.try_play_animation("Attack")
	driver.advance_game_time(1.0)
	check(driver.current_animation_key == "Attack" and driver.pending_key.is_empty(), "later explicit action cancels stale restoration")
	driver.try_play_damage_animation()
	driver.try_lock_animation("SpinDie")
	check(driver.try_play_damage_animation() and driver.current_animation_key == "SpinDie", "death lock acknowledges but rejects damage")
	driver.advance_game_time(1.0)
	check(player.current_animation == "SpinDie" and driver.pending_key.is_empty(), "no timer restores locked death")
	driver.clear_animation_lock()
	driver.runtime_enabled = false
	driver.try_play_damage_animation()
	check(driver.pending_key.is_empty(), "editor preview does not queue restore")
	driver.runtime_enabled = true
	player.get_animation("Dmg").length = 0.8
	driver.try_play_damage_animation()
	check(is_equal_approx(driver.pending_time - driver.game_time, 0.8), "timer reads current native clip rather than hardcoded shared duration")
	player.get_animation("Dmg").length = 0.5
	driver.try_play_damage_animation()
	driver.action_keys.erase("Idle")
	driver.advance_game_time(0.5)
	check(driver.current_animation_key == "Dmg" and driver.pending_key.is_empty(), "missing fallback fails once without fabricated idle")
	for value in [NAN, INF, -INF, -1.0, 0.0, 0.049]:
		check(is_equal_approx(Driver.validated_duration(value), 0.35), "invalid or too short duration uses source fallback")
	check(is_equal_approx(Driver.validated_duration(0.05), 0.05), "minimum duration inclusive")
	check(is_equal_approx(Driver.validated_duration(2.0), 2.0), "valid current clip length not hardcoded to damage default")
	driver.free()
	if failures == 0:
		print("PASS native character action driver: %d checks (no sprite acceptance)" % checks)
	quit(0 if failures == 0 else 1)
