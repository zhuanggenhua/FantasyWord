extends SceneTree
const Detection = preload("res://game_core/ai/steering_detection.gd")
var checks := 0
var failures := 0
var scene: Node2D
func _initialize(): call_deferred("_run")
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func body(xy: Vector2, layer: int, shape: Shape2D, trigger := false) -> CollisionObject2D:
	var n: CollisionObject2D = Area2D.new() if trigger else StaticBody2D.new()
	n.collision_layer = layer; n.collision_mask = 0
	var cs := CollisionShape2D.new(); cs.shape = shape; n.add_child(cs); scene.add_child(n)
	n.position = Vector2(xy.x,-xy.y)
	return n
func circle(radius := 0.2) -> CircleShape2D:
	var shape := CircleShape2D.new(); shape.radius = radius; return shape
func entry(b: CollisionObject2D, id: int, active := true) -> Dictionary:
	return {"body":b,"colliders":[b],"agent_id":id,"active":active,"radius":0.35,"velocity":Vector2(1,2),"mass":2.0,"priority":0.4}
func sync():
	await physics_frame
	await physics_frame
func _run():
	scene = Node2D.new(); root.add_child(scene)
	var own := body(Vector2.ZERO,256,circle())
	var registered := body(Vector2(0,1),256 | 8,circle())
	var inactive := body(Vector2(1,0),256,circle())
	var far := body(Vector2(2.001,0),256,circle())
	var edge := body(Vector2(2,0),256,circle())
	var wrong := body(Vector2(-1,0),8,circle())
	var box := RectangleShape2D.new(); box.size = Vector2(1,2)
	var obstacle := body(Vector2(4,0),8,box)
	var trigger := body(Vector2(1,1),8,circle(),true)
	var registry := [entry(own,0),entry(registered,1),entry(inactive,2,false),entry(far,3),entry(edge,4),entry(wrong,5)]
	await sync()
	var frame := Detection.build_frame(scene.get_world_2d(),Vector2.ZERO,own,registry,1,5,2,1,64)
	check(frame.ok,"native query builds frame")
	check(frame.obstacles.size()==1,"registered colliders excluded including inactive/wrong layer; triggers excluded")
	check(frame.obstacles[0].point.is_equal_approx(Vector2(3.5,0)),"source uses closest point not center even beyond obstacle radius in union query")
	check(frame.obstacles[0].radius==0.0 and frame.obstacles[0].is_static,"obstacle point has zero radius")
	check(frame.detected_colliders.has(registered),"registered character still semantic detected")
	check(not frame.detected_colliders.has(own) and not frame.detected_colliders.has(trigger),"own body and triggers skipped")
	check(frame.neighbours.size()==2,"active registered neighbors exact inclusive radius and layer")
	check(frame.neighbours[0].agent_id==4 and frame.neighbours[1].agent_id==1,"spatial cell order Y then X not registration or distance order")
	check(frame.neighbours[0].velocity==Vector2(1,2) and frame.neighbours[0].mass==2 and frame.neighbours[0].priority==0.4,"authored neighbor values retained")
	var no_probe := Detection.build_frame(scene.get_world_2d(),Vector2.ZERO,own,registry,0,0,2,1)
	check(no_probe.ok and no_probe.obstacles.is_empty() and no_probe.neighbours.size()==2,"neighbors collected even no overlap radius")
	check(Detection.closest_point(obstacle,Vector2(4,0)).position==Vector2(4,0),"inside rectangle returns query point")
	var c := body(Vector2(3,4),8,circle(1))
	check(Detection.closest_point(c,Vector2(3,6)).position.is_equal_approx(Vector2(3,5)),"circle boundary Y reflection")
	check(Detection.closest_point(c,Vector2(3,4.5)).position.is_equal_approx(Vector2(3,4.5)),"inside circle query point")
	c.scale=Vector2(2,1)
	check(not Detection.closest_point(c,Vector2.ZERO).ok,"nonuniform circle rejected")
	var capsule := body(Vector2.ZERO,8,CapsuleShape2D.new())
	await sync()
	check(not Detection.build_frame(scene.get_world_2d(),Vector2.ZERO,own,[],2,0,0,1).ok,"unsupported queried geometry fails closed")
	capsule.queue_free(); c.queue_free()
	await sync()
	obstacle.rotation=PI/2
	check(Detection.closest_point(obstacle,Vector2(4,2)).position.is_equal_approx(Vector2(4,0.5)),"rotated rectangle exact nearest boundary")
	for i in range(8): body(Vector2(0.01*i,0),8,circle())
	await sync()
	var full := Detection.build_frame(scene.get_world_2d(),Vector2.ZERO,own,[],2,0,0,1,1)
	check(not full.ok and full.error=="detection_buffer_full","capacity minimum8 and full rejects before own filtering")
	scene.queue_free(); await process_frame
	if failures==0: print("PASS steering detection: %d checks" % checks)
	quit(1 if failures else 0)
