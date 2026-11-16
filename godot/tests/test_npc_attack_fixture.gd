extends SceneTree
const Scene = preload("res://validation/scenes/npc_attack_fixture.tscn")
var checks := 0
var failures := 0
func _initialize(): call_deferred("_run")
func check(ok: bool, detail: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
func _run():
	var fixture = Scene.instantiate()
	fixture.automatic_ai = false
	fixture.automatic_clock = false
	root.add_child(fixture)
	await physics_frame
	await physics_frame
	check(fixture.ai.target.is_empty() and fixture.defender.health == 100,"unassigned original-role health before detection")
	fixture.advance_ai(0.02)
	check(fixture.last_query_ok and is_same(fixture.ai.target,fixture.observation.refresh_observation(
		fixture.get_world_2d(),fixture.attacker.stats,Vector2(0,0.72),fixture.defender)),
		"natural native detection acquires player with no target injection")
	check(fixture.attack_requests == 0,"acquisition tick cannot attack")
	fixture.advance_ai(0.02)
	check(fixture.ai.waiting_for_attack_facing and fixture.attacker.facing == Vector2(0,-1),
		"first attack tick requests authored facing without firing")
	check(fixture.attack_requests == 0,"turn request doesn't fire on same tick")
	fixture.advance_ai(0.02)
	check(fixture.attack_requests == 1 and fixture.ai.attack_cooldown == 1.0,"next aligned tick accepts enrolled formal code")
	check(fixture.commands[-2] == ["stop",20001] and fixture.commands[-1] == ["fire_ai",20001],
		"same code stop precedes AI fire")
	check(not fixture.timeline.playing and fixture.defender.health == 100,"local action windup is not skipped")
	fixture.advance_action(0.02)
	check(fixture.timeline.playing and fixture.timeline.frame == -1,"windup commits timeline rather than directly applying HP")
	fixture.advance_action(0.12)
	check(fixture.defender.health == 100,"no early hit before source frame8")
	fixture.advance_action(0.02)
	check(fixture.hit_count == 1 and fixture.defender.health == 97,"real polygon hit and source stats resolve 3 damage")
	check(fixture.defender.max_health == 100 and fixture.attacker.health == 220 and fixture.outside.health == 100,
		"max HP, source NPC and outside hero unchanged")
	check(fixture.defender.callbacks.has("impact_disabled") and not fixture.defender.body.is_pushed(),
		"Effect2003 push disabled")
	fixture.advance_action(0.5)
	check(not fixture.timeline.playing,"timeline naturally ends")
	fixture.ai.attack_cooldown = 0
	fixture.enrolled_codes.clear()
	fixture.advance_ai(0.02)
	check(fixture.attack_requests == 1,"removing actual enrollment prevents invented NPC ability")
	fixture.enrolled_codes.append(20001)
	var wall := StaticBody2D.new()
	wall.collision_layer = 8
	wall.collision_mask = 0
	wall.position = Vector2(0,-0.36)
	var wall_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 0.1
	wall_shape.shape = circle
	wall.add_child(wall_shape)
	fixture.add_child(wall)
	await physics_frame
	await physics_frame
	fixture.advance_ai(0.02)
	check(fixture.attack_requests == 1 and not fixture.ai.target.visible,"actual blocker prevents attack on tracked player")
	wall.queue_free()
	await physics_frame
	await physics_frame
	fixture.advance_ai(0.02)
	check(fixture.attack_requests == 2,"restored enrollment can request next action")
	fixture.action_eligible = false
	fixture.advance_action(0.02)
	check(not fixture.timeline.playing and fixture.hit_count == 1,"commit recheck rejects lost action eligibility")
	fixture.queue_free()
	await process_frame
	if failures == 0: print("PASS native NPC observation to hit: %d checks" % checks)
	quit(1 if failures else 0)
