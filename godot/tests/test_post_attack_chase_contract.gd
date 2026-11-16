extends SceneTree

const Contract = preload("res://validation/post_attack_chase_contract.gd")
var checks := 0
var failures := 0
var attempted: Array[Vector2] = []


func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)


func path_pick(_origin: Vector2, candidate: Vector2) -> PackedVector2Array:
	attempted.append(candidate)
	match attempted.size():
		1: return PackedVector2Array([Vector2(-1, 0)]) # snapped, but too short
		2: return PackedVector2Array()
		3: return PackedVector2Array([Vector2(-2, 0)]) # accepted at exactly 2.0
	return PackedVector2Array()


func _initialize() -> void:
	var npc := Contract.setup_npc_position(Vector2.ZERO)
	check(npc.is_equal_approx(Vector2(0, 0.72)), "source setup uses +Y on the Unity plane")
	var fallback := Contract.relocation(Vector2.ZERO, Vector2.ZERO, Callable())
	check(fallback.status == "no_map" and fallback.position.is_equal_approx(Vector2(0, -2.6)),
		"overlap uses source down direction and no-map fallback")
	var chosen := Contract.relocation(Vector2.ZERO, npc, path_pick)
	check(chosen.status == "fallback_path" and chosen.fallback_index == 2
		and chosen.position == Vector2(-2, 0), "first reachable sufficiently distant snapped endpoint wins")
	check(attempted.size() == 3 and attempted[0].is_equal_approx(Vector2(0, -2.6))
		and attempted[1].is_equal_approx(Vector2(2.6, 0))
		and attempted[2].is_equal_approx(Vector2(-2.6, 0)), "preserves source desired/right/left attempt order")
	var refused := Contract.relocation(Vector2.ZERO, npc,
		func(_from, _to): return null)
	check(refused.status == "no_reachable_candidate" and refused.position == refused.desired,
		"exhausted fallback uses original desired point; does not invent route")
	check(Contract.await_hit(240, "Idle") == "pending", "hit timeout strictly after 240")
	check(Contract.await_hit(241, "Idle") == "hit_timeout", "hit times out without Dmg")
	check(Contract.await_hit(241, "Dmg") == "hit_observed", "source checks Dmg before hit deadline")
	check(Contract.await_hit(5, "dmg") == "pending", "case sensitive actual Dmg key")
	check(not Contract.evaluate(240, 10, "Idle", true, true, Vector2.ZERO, Vector2.RIGHT,
		Vector2(4, 0)).complete, "chase window cannot complete early")
	var displaced := Contract.evaluate(241, 10, "Idle", true, true, Vector2.ZERO,
		Vector2(0.2, 0), Vector2(4, 0))
	check(displaced.complete and displaced.success, "inclusive displacement branch of actual source predicate")
	var close := Contract.evaluate(241, 10, "Idle", true, true, Vector2.ZERO, Vector2.ZERO,
		Vector2(1.45, 0))
	check(close.success, "inclusive final distance is an independent alternative")
	var failed := Contract.evaluate(241, 0, "Dmg", false, false, Vector2.ZERO, Vector2.ZERO,
		Vector2(4, 0))
	check(not failed.success and failed.failures == ["no_dmg_observed", "player_stuck_in_dmg",
		"npc_movement_locked", "npc_lost_target", "npc_did_not_resume_chase"],
		"missing actual hit, stuck Dmg, locked move, lost target or insufficient chase never pass")
	if failures == 0:
		print("PASS post-attack chase validation contract: %d checks" % checks)
	quit(0 if failures == 0 else 1)
