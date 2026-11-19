extends RefCounted
## 31629d5 ContextSteeringSimulation2D: one registered agent, verified authored groups only.
## No pair correction or ORCA constraint can exist for a verified singleton.
## Queries real colliders; excludes static obstacles from RVO, not from scoring.
const Detection = preload("res://game_core/ai/steering_detection.gd")
const Transit = preload("res://game_core/ai/transit_steering.gd")
const Predictive = preload("res://game_core/ai/predictive_target_steering.gd")
const Wander = preload("res://game_core/ai/combat_wander_steering.gd")
const Navigation = preload("res://game_core/ai/ai_navigation_target.gd")
const SEMANTIC_RADIUS := 5.0
const DETECTION_CAPACITY := 128

static var _by_world: Dictionary = {}
var _world_id := 0
var _body: WeakRef
var latest: Dictionary = {}

func configure(body: CollisionObject2D) -> bool:
	if _body != null or not is_instance_valid(body) or not body.is_inside_tree(): return false
	var world_id := body.get_world_2d().get_instance_id()
	var registry: Dictionary = _by_world.get(world_id,{})
	_prune(registry)
	var id := body.get_instance_id()
	if not registry.is_empty(): return false # no unported multi-agent simulation
	_world_id = world_id
	_body = weakref(body)
	registry[id] = {"body":_body,"agent_id":id}
	_by_world[_world_id] = registry
	return true

static func _prune(registry: Dictionary) -> void:
	for id in registry.keys():
		var body: CollisionObject2D = registry[id].body.get_ref()
		if not is_instance_valid(body) or not body.is_inside_tree(): registry.erase(id)

func dispose() -> void:
	var registry: Dictionary = _by_world.get(_world_id,{})
	var body: CollisionObject2D = _body.get_ref() if _body != null else null
	if is_instance_valid(body): registry.erase(body.get_instance_id())
	_prune(registry)
	if registry.is_empty(): _by_world.erase(_world_id)
	_world_id = 0
	_body = null
	reset_result()

func reset_result() -> void:
	latest = {}

func latest_safe_result() -> Dictionary:
	return {"safe_velocity":latest.get("safe_velocity",Vector2.ZERO),
		"push_correction":latest.get("push_correction",Vector2.ZERO)}

func consume(max_speed: float) -> Dictionary:
	var velocity: Vector2 = latest.get("safe_velocity",Vector2.ZERO)
	return {"speed_scale":clampf(velocity.length()/maxf(max_speed,.0001),0.0,1.0),
		"safe_direction":latest.get("safe_direction",Vector2.ZERO),
		"push_correction":Vector2.ZERO}

func sample(position: Vector2, forward: Vector2, target: Vector2, max_speed: float,
		group: String = Navigation.TRANSIT, target_velocity: Vector2 = Vector2.ZERO,
		arrival_stop_radius: float = -1.0, wander_intent: Dictionary = {},
		semantic_radius: float = SEMANTIC_RADIUS) -> Dictionary:
	reset_result()
	if group not in [Navigation.TRANSIT,Navigation.PREDICTIVE,Navigation.WANDER]:
		return {"ok":false,"error":"unported_steering_group"}
	if group == Navigation.WANDER and not wander_intent.has_all(["side_sign","follow_distance"]):
		return {"ok":false,"error":"missing_combat_wander_intent"}
	var body: CollisionObject2D = _body.get_ref() if _body != null else null
	var registry: Dictionary = _by_world.get(_world_id,{})
	if not is_instance_valid(body) or not body.is_inside_tree() or body.get_world_2d().get_instance_id() != _world_id:
		return {"ok":false,"error":"steering_world_changed"}
	_prune(registry)
	if registry.size() != 1 or not registry.has(body.get_instance_id()):
		return {"ok":false,"error":"unverified_steering_registry"}
	var registered_agent: Dictionary = {"body":body,"colliders":[body],"agent_id":body.get_instance_id()}
	# collect_neighbours excludes own body before any state fields are read.
	var frame := Detection.build_frame(body.get_world_2d(),position,body,[registered_agent],
		Transit.PROBE_RADIUS,semantic_radius,Transit.NEIGHBOUR_RADIUS,Transit.NEIGHBOUR_RADIUS,DETECTION_CAPACITY)
	if not frame.ok: return frame
	if not frame.neighbours.is_empty(): return {"ok":false,"error":"not_singleton"}
	frame.merge({"position":position,"forward":forward,"target":target,
		"target_velocity":target_velocity,"arrival_stop_radius":arrival_stop_radius})
	var scored: Dictionary
	match group:
		Navigation.WANDER:
			frame.wander_intent = wander_intent
			scored = Wander.solve(frame,max_speed)
		Navigation.PREDICTIVE:
			scored = Predictive.solve(frame,max_speed)
		_:
			scored = Transit.solve(frame,max_speed)
	# RVO2 linearProgram2 with zero constraints selects the preferred velocity
	# limited to the submitted speed. PositionBasedContactResolver has no pair.
	var safe: Vector2 = (scored.preferred_velocity as Vector2).limit_length(max_speed)
	var direction := safe.normalized() if safe.length_squared() > Transit.f32(.0001) else Vector2.ZERO
	latest = {"safe_velocity":safe,"safe_direction":direction,"speed_scale":clampf(safe.length()/maxf(max_speed,.0001),0.0,1.0),
		"push_correction":Vector2.ZERO,"max_speed":max_speed,"target":target,"origin":position,
		"group":group,"target_velocity":target_velocity,"arrival_stop_radius":arrival_stop_radius,
		"detected_colliders":frame.detected_colliders,"obstacle_count":frame.obstacles.size(),"neighbour_count":0}
	if group == Navigation.WANDER:
		latest.wander_intent = wander_intent.duplicate()
		latest.resolved_wander_side = scored.resolved_side
	return frame
