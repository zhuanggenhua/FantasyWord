extends SceneTree
const Scene = preload("res://gameplay/clickmovetest/entry.tscn")
const Terrain = preload("res://game_core/movement/terrain_cast.gd")
const Binding = preload("res://gameplay/clickmovetest/human_motion_binding.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Playback = preload("res://game_core/presentation/directional_sprite_playback.gd")
const AnimatorDriver = preload("res://game_core/presentation/character_action_animator_driver.gd")
const Motion = preload("res://game_core/movement/motion_execution.gd")
# 源 MovementBased 门禁的明确测试宿主，不是完整生产角色 owner。
class Host extends RefCounted:
	signal look_at_direction_changed(value: Vector2)
	var direction := Vector2.ZERO
	var movement_based := true
	var allowed := true
	var hits: Array = []
	var intents: Array = []
	func can_move() -> bool: return allowed
	func calculate_move_speed() -> float: return 4.0
	func calculate_speed_multiplier() -> float: return 1.0
	func get_look_at_direction() -> Vector2: return direction
	func update_facing_from_intent(value: Vector2) -> void:
		intents.append(value)
		if movement_based and value.length_squared() > 0.05 * 0.05:
			approve_direction(value.normalized())
	func approve_direction(value: Vector2) -> void:
		if value.length() > 0 and value != direction:
			direction=value
			look_at_direction_changed.emit(value)
	func register_collision(body: Object) -> void: hits.append(body)
class TestView extends Node2D:
	var driver: Node
	var playback: Node
	var animator := AnimationPlayer.new()
	var sprite := Sprite2D.new()
	func initialize() -> void:
		add_child(sprite); add_child(animator)
		playback=Playback.new(); add_child(playback)
		var actions := {}
		for action in ["Idle","Walk"]:
			var count := 16 if action == "Idle" else 4
			var labels: Array[int]=[]
			var times := []
			var frames := []
			for i in count:
				labels.append(i); times.append(i*0.125)
				var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
				frames.append(ImageTexture.create_from_image(image))
			labels.append(count-1); times.append(count*0.125)
			actions[action]={"duration":count*0.125,"loop":true,"times":times,"labels":labels,"directions":[frames,frames,frames,frames]}
		assert(playback.configure(sprite,animator,actions))
		driver=AnimatorDriver.new(); add_child(driver)
		driver.animator=animator; driver.action_keys.assign(["Idle","Walk"])
		driver.try_play_animation("Idle")
	func set_movement(value: Vector2) -> void: driver.set_movement(value)
	func set_facing(value: Vector2) -> void: playback.set_facing_direction(value)
class Player extends RefCounted:
	signal controlled_character_changed(character: Node2D)
	var actor: Node2D
	func get_current_controlled_character_or_player_instance() -> Node2D: return actor
class MapEvents extends RefCounted:
	signal map_loaded
	signal map_unloaded
class PhysicsStep extends Node:
	var action: Callable
	signal step
	func _physics_process(_dt: float) -> void:
		if action.is_valid():
			var work := action; action = Callable(); work.call()
		step.emit()
var failed := 0
var checks := 0
var tick := PhysicsStep.new()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failed += 1; printerr("FAIL: ", text)
func _initialize() -> void: call_deferred("run")
func wall(source: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Terrain.to_physics(source)
	body.collision_layer = 8
	body.collision_mask = 0
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collider.shape = rectangle
	body.add_child(collider)
	root.add_child(body)
	return body
func run() -> void:
	var scene = Scene.instantiate()
	root.add_child(scene)
	root.add_child(tick)
	var owner := Host.new()
	var view := TestView.new()
	root.add_child(view); view.initialize()
	# 失败 start_human_logic 不提前应用非零初始方向，也不遗留订阅。
	scene.human_presentation=view
	owner.direction=Vector2(-1,-1)
	check(not scene.start_human_logic(owner,{},Callable(),Callable(),null,Callable()),"invalid entry dependencies fail")
	check(view.playback.current_direction == 0 and not owner.look_at_direction_changed.has_connections(),"entry rejection leaves direction and signal untouched")
	var deferred_binding := Binding.new()
	check(deferred_binding.configure(owner,view,false),"deferred configure")
	owner.direction=Vector2(1,1)
	deferred_binding.activate()
	check(view.playback.current_direction == 2,"activate reads fresh owner direction after providers")
	deferred_binding.detach()
	view.playback.set_direction(0)
	owner.direction=Vector2.ZERO
	var adapter := Binding.new()
	check(not adapter.configure(null,view),"missing owner rejected")
	check(not adapter.configure(owner,null),"missing presentation rejected")
	check(adapter.configure(owner,view),"explicit source owner wired")
	check(not adapter.configure(owner,view),"duplicate configure rejected")
	check(view.playback.current_direction == 0,"source initial zero preserves SE")
	var accepted := []
	adapter.accepted_movement.connect(func(value): accepted.append([value,scene.actor.get_movement_position()]))
	scene.actor.configure_movement(scene.actor_shape,Filter.new(Filter.Mode.FREE,false,0.05,10.0,10.0),adapter,7752)
	scene.set_physics_process(false)
	var corner := wall(Vector2(0.38,10.82),Vector2(0.08,0.08))
	var west := wall(Vector2(-0.45,20.42),Vector2(0.08,1.7))
	var south := wall(Vector2(0,19.93),Vector2(1.7,0.08))
	var a = scene.actor
	await frame(func():a.request_move_position(Vector2(0,10)))
	await frame()
	var slide = a.execution.move_to(Vector2(1,11))
	await frame(func():
		a.advance_movement(0.02)
		check(owner.hits.has(corner),"diagonal meets actual corner collider")
		check(accepted.back()[0].is_equal_approx(Vector2(4/sqrt(2),0)),"animation receives admitted axis velocity, not diagonal intent")
		check(accepted.back()[1] == Vector2(0,10),"animation observes pre-physics position")
		check(owner.direction.is_equal_approx(Vector2(1,1).normalized()),"approved facing receives intent separate from accepted motion")
		check(view.playback.current_action == "Walk" and view.playback.current_direction == 2,"native atlas Walk NE despite horizontal slide")
		check(slide.state == Motion.Completion.PENDING,"axis fallback keeps move order"))
	await frame()
	check(a.get_movement_position().is_equal_approx(Vector2(0.08/sqrt(2),10)),"actual synchronized position changes only x")
	await frame(func(): a.request_move_position(Vector2(0,20)))
	await frame()
	var blocked = a.execution.move_to(Vector2(-1,19))
	await frame(func():
		a.advance_movement(0.02)
		check(owner.hits.has(west) and owner.hits.has(south),"real west and south hit set")
		check(accepted.back()[0] == Vector2.ZERO,"full obstruction reports zero")
		check(accepted.back()[1] == Vector2(0,20),"full obstruction callback starts from stationary pose")
		check(owner.direction.is_equal_approx(Vector2(-1,-1).normalized()),"eligible blocked direction still changes facing")
		check(view.playback.current_action == "Idle" and view.playback.current_direction == 1,"blocked shows Idle SW, not Walk")
		check(blocked.state == Motion.Completion.FAILED,"full obstruction fails order"))
	await frame()
	check(a.get_movement_position() == Vector2(0,20),"full block retained actual pose")
	owner.movement_based=false
	owner.approve_direction(Vector2(1,1))
	adapter.update_facing_from_intent(Vector2(-1,-1))
	check(view.playback.current_direction == 2,"nonmovement facing policy rejects intent independently")
	adapter.update_movement_animation(Vector2(0,-4))
	check(view.playback.current_action == "Walk" and view.playback.current_direction == 2,"accepted motion never overwrites held NE")
	owner.movement_based=true
	adapter.update_facing_from_intent(Vector2(0.01,0))
	check(owner.direction == Vector2(1,1),"subthreshold intent leaves approved facing unchanged")
	owner.allowed=false
	await frame(func():
		scene.actor.move_to(Vector2(-1,19))
		scene.actor.advance_movement(0.02))
	check(view.playback.current_action == "Idle" and view.playback.current_direction == 2,"movement gate stops animation without changing facing")
	owner.allowed=true
	view.free()
	check(adapter.can_move(),"presentation removal does not revoke owner gameplay capability")
	adapter.update_movement_animation(Vector2.ZERO)
	adapter.detach()
	check(not owner.look_at_direction_changed.has_connections(),"detach removes owner signal")
	check(not adapter.can_move(),"detached binding cannot move")
	owner.approve_direction(Vector2(-1,-1))
	scene.free(); corner.free(); west.free(); south.free(); tick.queue_free()
	await process_frame
	print("PASS native Human motion binding: %d/%d; synthetic texture fixture, not visual acceptance" % [checks-failed,checks])
	quit(1 if failed else 0)
func frame(action: Callable = Callable()) -> void:
	tick.action = action
	await tick.step
