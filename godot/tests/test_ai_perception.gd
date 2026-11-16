extends SceneTree
const Perception = preload("res://game_core/ai/ai_perception.gd")
const Lifecycle = preload("res://game_core/ai/ai_target_lifecycle.gd")
var perception = Perception.new()
var checks := 0
var failures := 0
var scene: Node2D
func _initialize(): call_deferred("_run")
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func body(parent: Node2D, xy: Vector2, layer: int, trigger := false) -> CollisionObject2D:
	var node: CollisionObject2D = Area2D.new() if trigger else StaticBody2D.new()
	node.collision_layer = layer
	node.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new(); shape.radius = 0.2
	cs.shape = shape; node.add_child(cs); parent.add_child(node)
	node.position = Vector2(xy.x,-xy.y)
	return node
func character(xy: Vector2, alignment: int) -> Node2D:
	var actor := Node2D.new(); scene.add_child(actor)
	actor.position = Vector2(xy.x,-xy.y)
	actor.set_meta(Perception.STATE_META,{"alignment":alignment,"dead":false,"invincible":false})
	body(actor,Vector2.ZERO,256)
	return actor
func sync():
	await physics_frame
	await physics_frame
func _run():
	scene = Node2D.new(); root.add_child(scene)
	var observer := {"alignment":0,"dead":false,"invincible":false}
	var own := body(scene,Vector2.ZERO,256)
	var enemy := character(Vector2(3,2),1)
	var neutral := character(Vector2(2,0),2)
	var friendly := character(Vector2(1,0),0)
	var unrelated := body(scene,Vector2(0,1),256)
	var trigger := body(scene,Vector2(0,2),256,true)
	await sync()
	var world := scene.get_world_2d()
	var found := Perception.detect(world,Vector2.ZERO,own,5,1,64)
	check(found.ok and found.colliders.size() == 4,"own body and trigger excluded, unrelated body retained")
	check(not found.colliders.has(own) and not found.colliders.has(trigger),"filters don't add own or trigger")
	check(Perception.character_parent(enemy.get_child(0)) == enemy,"child collider resolves nearest character parent")
	check(Perception.character_parent(unrelated) == null,"unrelated collider has no invented character")
	var ordered := perception.observe_ordered(world,observer,Vector2.ZERO,[unrelated,friendly.get_child(0),neutral.get_child(0),enemy.get_child(0),enemy.get_child(0)])
	check(ordered.size() == 4 and is_same(ordered[2],ordered[3]),"order and repeated collider identity preserved")
	check(not ordered[0].hostile and not ordered[1].hostile and ordered[2].hostile,"live source faction rules")
	check(ordered[2].position == Vector2(3,2) and ordered[2].visible,"reflected physics coordinates and clear LOS")
	var other_perception = Perception.new()
	var other_observer := {"alignment":1,"dead":false,"invincible":false}
	var other_view = other_perception.refresh_observation(world,other_observer,Vector2.ZERO,enemy)
	check(not other_view.hostile and ordered[2].hostile and not is_same(other_view,ordered[2]),"observer-relative state is isolated")
	check(not enemy.get_meta(Perception.STATE_META).has("hostile"),"shared actor state is not contaminated")
	var life := Lifecycle.new()
	life.tick(0,0,Vector2.ZERO,Vector2.ZERO,ordered,func(_a,_b): pass)
	check(is_same(life.target,ordered[2]),"native collider observation feeds actual target lifecycle")
	var blocker := body(scene,Vector2(1.5,1),8,true)
	await sync()
	perception.refresh_observation(world,observer,Vector2.ZERO,enemy)
	check(not life.target.visible,"visibility ray includes trigger despite filter useTriggers false")
	life.tick(0.02,3.1,Vector2.ZERO,Vector2.ZERO,[],func(_a,_b): pass)
	check(life.target.is_empty() and life.retarget_cooldown == 1,"native obstruction drives source lost-sight reset")
	blocker.collision_layer = 4096
	await sync()
	check(Perception.can_see(world,Vector2.ZERO,Vector2(3,2)),"movement-only layer doesn't block visibility")
	blocker.collision_layer = 8; blocker.position = Vector2(4,-3)
	await sync()
	check(Perception.can_see(world,Vector2.ZERO,Vector2(3,2)),"ray stops at target distance")
	blocker.position = Vector2.ZERO
	await sync()
	check(not Perception.can_see(world,Vector2.ZERO,Vector2(3,2)),"origin inside obstruction blocks; no invented self exclusion")
	blocker.queue_free(); await sync()
	enemy.position = Vector2(8,-2)
	perception.refresh_observation(world,observer,Vector2.ZERO,enemy)
	check(ordered[2].position == Vector2(8,2),"tracked identity refreshed outside detection radius")
	await sync()
	check(not Perception.detect(world,Vector2.ZERO,own,5,1,64).colliders.has(enemy.get_child(0)),"outside semantic/obstacle query radius excluded")
	check(Perception.detect(world,Vector2.ZERO,own,0,1,64).colliders.is_empty(),"zero semantic radius adds no detected colliders")
	check(Perception.detect(world,Vector2.ZERO,own,0,0,64).ok,"zero combined radius returns empty valid frame")
	# Source uses max probe/semantic radius and does NOT recheck semantic distance.
	check(Perception.detect(world,Vector2.ZERO,own,1,10,64).colliders.has(enemy.get_child(0)),"larger probe radius keeps semantic hits beyond nominal semantic radius")
	for i in range(8): body(scene,Vector2(0.5,0.02*i),8)
	await sync()
	var full := Perception.detect(world,Vector2.ZERO,own,5,1,1)
	check(not full.ok and full.error == "detection_buffer_full" and full.colliders.is_empty(),"min8 buffer saturation rejects before semantic filtering")
	scene.queue_free(); await process_frame
	if failures == 0: print("PASS AI perception native physics: %d checks" % checks)
	quit(1 if failures else 0)
