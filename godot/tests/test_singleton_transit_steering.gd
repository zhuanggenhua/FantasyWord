extends SceneTree

const Steering = preload("res://game_core/ai/singleton_transit_steering.gd")
const Transit = preload("res://game_core/ai/transit_steering.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",label)

func rectangle(layer: int, at: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.position = at
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(.2,.2)
	shape_node.shape = shape
	body.add_child(shape_node)
	root.add_child(body)
	return body

func run() -> void:
	var agent := rectangle(256,Vector2.ZERO)
	var player := rectangle(256,Vector2(2,0))
	var obstacle := rectangle(8,Vector2(.45,0))
	await physics_frame
	await physics_frame
	var runtime := Steering.new()
	var duplicate := Steering.new()
	check(runtime.configure(agent) and not duplicate.configure(player),"single registered agent in the world")
	check(runtime.consume(4.0).safe_direction == Vector2.ZERO and runtime.consume(4.0).speed_scale == 0.0,
		"new handle has default result before late simulation")
	var frame := runtime.sample(Vector2.ZERO,Vector2.RIGHT,Vector2(3,0),4.0)
	check(frame.ok and frame.detected_colliders == [player] and frame.neighbours.is_empty(),
		"unregistered player is a detected actor, not a registered neighbour")
	check(frame.obstacles.size() == 1 and Vector2(frame.obstacles[0].point).is_equal_approx(Vector2(.35,0.0)),
		"native obstacle layer query uses closest point, not origin")
	var expected: Dictionary = Transit.solve(frame,4.0)
	var safe: Vector2 = runtime.latest.safe_velocity
	check(safe.is_equal_approx(expected.preferred_velocity) and safe.y < 0.0,
		"source Transit obstacle steering survives zero-pair RVO")
	check(runtime.consume(1.0).speed_scale == clampf(safe.length(),0.0,1.0)
		and runtime.consume(8.0).speed_scale == clampf(safe.length()/8.0,0.0,1.0)
		and runtime.consume(8.0).push_correction == Vector2.ZERO,
		"previous safe velocity is applied against the newly submitted max speed")
	runtime.reset_result()
	check(runtime.consume(4.0).safe_direction == Vector2.ZERO,"withdrawal discards previous result")
	runtime.dispose()
	check(duplicate.configure(player),"disposing unregisters the authored handle")
	duplicate.dispose()
	for node: Node in [obstacle,player,agent]: node.free()
	print("FantasyWord singleton Transit: ",checks-failures,"/",checks)
	quit(1 if failures else 0)
