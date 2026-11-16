extends SceneTree
## Physics-backed intent -> obstacle detection -> preferred score boundary.
## No collision simulation backend is injected into motion outputs by this test.
const Detection = preload("res://game_core/ai/steering_detection.gd")
const Scoring = preload("res://game_core/ai/combat_wander_steering.gd")
const Intent = preload("res://game_core/ai/combat_wander_intent.gd")
var world := Node2D.new()
var checks := 0
var failures := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(what)

func wall(position: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position
	body.collision_layer = 8
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(0.2, 0.11)
	collision.shape = box
	body.add_child(collision)
	world.add_child(body)
	return body

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	root.add_child(world)
	var own := CharacterBody2D.new()
	world.add_child(own)
	wall(Vector2(0.28, -0.10))
	var second := wall(Vector2(0.28, 0.10))
	await physics_frame
	await physics_frame
	var frame := Detection.build_frame(world.get_world_2d(), Vector2.ZERO, own, [], 1.0, 5.0, 1.0, 2.0)
	check(frame.ok and frame.obstacles.size() == 2, "two real static obstructions detected")
	if frame.ok and frame.obstacles.size() == 2:
		check(frame.obstacles.all(func(row): return row.radius == 0.0 and is_equal_approx(row.point.x, 0.18)),
			"score the surface at x=0.18, not the shape centroid")
		var intent := Intent.new().tick(0.02, 1.0, 3.0, func(): return 0.8, func(_lo, _hi): return 1.0)
		frame.merge({"position":Vector2.ZERO, "target":Vector2(0,1), "forward":Vector2.RIGHT, "wander_intent":intent})
		var score := Scoring.solve(frame)
		check(score.resolved_side == -1.0 and score.preferred_velocity.x < 0.0, "two approaching shapes select the free side")
		check(not score.has("safe_velocity") and own.position == Vector2.ZERO, "preferred score does not claim or write safe motion")
		second.collision_layer = 0
		await physics_frame
		await physics_frame
		var fewer := Detection.build_frame(world.get_world_2d(), Vector2.ZERO, own, [], 1.0, 5.0, 1.0, 2.0)
		check(fewer.ok and fewer.obstacles.size() == 1, "one obstruction removed by layer filtering")
		if fewer.ok:
			frame.obstacles = fewer.obstacles
			check(Scoring.solve(frame).resolved_side == 1.0, "one full-proximity obstruction does not cross source flip threshold")
	world.free()
	if failures == 0:
		print("PASS combat wander native detection to preferred score: ", checks)
	quit(0 if failures == 0 else 1)
