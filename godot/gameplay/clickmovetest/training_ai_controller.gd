extends RefCounted
## 锁定 ClickMoveTest 的活动假人 AIController：启动、挑衅、选敌与停止。
## 源路径与检测；显式接通唯一活动假人的路线、默认归位和可追溯战斗游走。
const TargetLifecycle = preload("res://game_core/ai/ai_target_lifecycle.gd")
const Perception = preload("res://game_core/ai/ai_perception.gd")
const Navigation = preload("res://game_core/ai/ai_navigation_target.gd")
const SingletonTransit = preload("res://game_core/ai/singleton_transit_steering.gd")
const WanderSubmission = preload("res://game_core/ai/combat_wander_submission.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
const SOURCE_SCENE_INSTANCE := "735002000000000003"
const SOURCE_CONTROLLER := "4536545658951696519"
const DETECTION_RADIUS := 5.0
const OBSTACLE_PROBE_RADIUS := 1.0
const WORLD_DETECTION_CAPACITY := 128

var running: bool:
	get: return _running
var _running := false
var _subject: WeakRef
var _home := Vector2.ZERO
var _map_collision: WeakRef
var _player: WeakRef
var _player_stats: Callable
var _detected_player := false
var _sample_pending := false
var behaviour := TargetLifecycle.new()
var _try_formal_attack: Callable
var _build_path: Callable
var _navigator := Navigation.new()
var steering_target: Dictionary = {}
var _transit: SingletonTransit
var _transit_submission: Dictionary = {}
var _transit_average := Vector2.ZERO
var _wander: WanderSubmission
var _wander_random_value: Callable
var _wander_random_range: Callable
var transit_latest: Dictionary:
	get: return _transit.latest.duplicate(true) if _transit != null else {}

func bind_transit_steering() -> bool:
	if not _running or _player == null or _transit != null: return false
	var subject: Node2D = _subject.get_ref()
	var player: AnimatableBody2D = _player.get_ref()
	if not is_instance_valid(subject) or not subject.has_transit_facing_owner() \
			or not is_instance_valid(player) or not player.has_method("get_movement_linear_velocity"): return false
	var transit := SingletonTransit.new()
	if not transit.configure(subject.body): return false
	_transit = transit
	return true

func bind_combat_wander(random_value: Callable, random_range: Callable) -> bool:
	if not _running or _transit == null or _wander != null: return false
	if not random_value.is_valid() or not random_range.is_valid(): return false
	_wander_random_value = random_value
	_wander_random_range = random_range
	_wander = WanderSubmission.new()
	return true

func _stop_transit(subject: Node2D) -> void:
	if _transit == null: return
	_transit_submission = {}
	_transit.reset_result()
	if is_instance_valid(subject) and is_instance_valid(subject.body):
		subject.body.execution.set_steering_motion(1.0,Vector2.ZERO)
		subject.body.execution.set_movement_direction(Vector2.ZERO,false)

func _transform_right(subject: Node2D) -> Vector2:
	var game_right := subject.global_transform.x.normalized()
	return Vector2(game_right.x,-game_right.y)

func _subject_forward(subject: Node2D) -> Vector2:
	var look: Vector2 = subject.get_transit_look()
	return look.normalized() if look != Vector2.ZERO else _transform_right(subject)

func _submit_route_steering(subject: Node2D, origin: Vector2, player: AnimatableBody2D) -> void:
	var max_speed: float = maxf(0.0,subject.calculate_move_speed()*subject.calculate_speed_multiplier())
	if not is_finite(max_speed):
		_stop_transit(subject)
		return
	var destination: Vector2 = steering_target.position
	var execution: RefCounted = subject.body.execution
	var forward: Vector2
	if steering_target.mode == "approach":
		forward = _subject_forward(subject)
	else:
		# 远目标未有活动地图仍走 TryResolveSteeringTarget 后的相同前向规则。
		forward = _transit_average if execution.get_last_successful_movement().length() > 0.0 else destination-origin
		if forward.length_squared() <= .0001: forward = _subject_forward(subject)
	var target_velocity := Vector2.ZERO
	if steering_target.final and current_target() == player:
		var physics_velocity: Variant = player.get_movement_linear_velocity()
		if not physics_velocity is Vector2 or not physics_velocity.is_finite():
			_stop_transit(subject)
			return
		target_velocity = physics_velocity
	_transit_submission = {"target":destination,"forward":forward,"max_speed":max_speed,
		"group":steering_target.group,"target_velocity":target_velocity,"arrival_stop_radius":steering_target.arrival_stop}
	# Submit sets current MaxSpeed; ApplyLatestResult uses previous simulation velocity.
	var previous := _transit.consume(max_speed)
	execution.set_steering_motion(previous.speed_scale,previous.push_correction)
	execution.set_movement_direction(previous.safe_direction,false)
	_transit_average = previous.safe_direction
	if subject.body.can_move():
		if current_target() != null:
			var toward: Vector2 = behaviour.target_position-origin
			if toward.length() > 0.0: subject.set_transit_look(toward)
		elif not behaviour.waiting_for_attack_facing and _transit_average != Vector2.ZERO:
			subject.set_transit_look(_transit_average)

func _submit_wander_steering(subject: Node2D, origin: Vector2, player: AnimatableBody2D,
		fixed_delta: float) -> void:
	_transit_submission = {}
	var speed: float = maxf(0.0,subject.calculate_move_speed()*subject.calculate_speed_multiplier())
	var target_velocity: Variant = player.get_movement_linear_velocity()
	if not is_finite(speed) or not target_velocity is Vector2 or not target_velocity.is_finite():
		_sample_pending = false
		_stop_transit(subject)
		return
	var execution: RefCounted = subject.body.execution
	# 原游走不改身体朝向；攻击前对准由先执行的正式攻击判断拥有。
	var selected := _wander.try_apply(behaviour,origin,fixed_delta,target_velocity,subject.get_transit_look(),_transform_right(subject),
		speed,_wander_random_value,_wander_random_range,_receive_wander_intent,_transit.latest_safe_result,
		Callable(execution,"set_steering_motion"),Callable(execution,"set_movement_direction").bind(false),
		subject.body.can_move,Callable(),subject.set_transit_look)
	if not selected:
		_sample_pending = false
		_stop_transit(subject)
	elif _transit_submission.is_empty():
		# 无有效源抽样，本步不生成新的检测或复用旧安全输出；仍然选中原游走组。
		_sample_pending = false
		_transit.reset_result()
	else:
		_transit_average = _wander.average_output

func _receive_wander_intent(submission: Dictionary) -> void:
	if not submission.active: return
	_transit_submission = {"target":submission.target_position,"forward":submission.forward,
		"max_speed":submission.max_speed,"group":submission.group_id,
		"target_velocity":submission.target_velocity,"arrival_stop_radius":submission.arrival_stop_radius,
		"wander_intent":submission.wander_intent,"semantic_radius":submission.semantic_query_radius}

func start(subject: Node) -> void:
	if _running: return
	_subject = weakref(subject)
	_home = subject.get_movement_position()
	_running = true
	behaviour.path_invalidated.connect(_navigator.invalidate)
	subject.formal_provoked.connect(_on_provoked)

func stop() -> void:
	if not _running: return
	_running = false
	_detected_player = false
	_sample_pending = false
	_player = null
	_map_collision = null
	_player_stats = Callable()
	_try_formal_attack = Callable()
	var subject: Node = _subject.get_ref()
	if is_instance_valid(subject): subject.formal_provoked.disconnect(_on_provoked)
	if _transit != null:
		_stop_transit(subject)
		_transit.dispose()
		_transit = null
		_transit_average = Vector2.ZERO
	if _wander != null:
		_wander.reset_intent()
		_wander = null
	_wander_random_value = Callable()
	_wander_random_range = Callable()
	behaviour.stop_controller()
	behaviour.path_invalidated.disconnect(_navigator.invalidate)
	steering_target = {}
	_build_path = Callable()

func current_target() -> Object:
	var actor: WeakRef = behaviour.target.get("actor")
	return actor.get_ref() if actor != null else null

## 仅接受 Entry 实际玩家身体及其既有正式属性入口，不在控制器内造角色状态。
func bind_player(player: AnimatableBody2D, read_stats: Callable, map_collision: Node2D, build_path: Callable) -> bool:
	# 空 Callable 代表明确没有导航地图；无效的非空入口不是这个情况。
	if not _running or not is_instance_valid(player) or not read_stats.is_valid() \
			or (not build_path.is_null() and not build_path.is_valid()):
		return false
	if not player.is_inside_tree() or not player.has_method("get_movement_position"):
		return false
	if not is_instance_valid(map_collision) or not map_collision.is_inside_tree() \
			or map_collision.get_world_2d() != player.get_world_2d(): return false
	if _map_collision != null:
		var previous: Node2D = _map_collision.get_ref()
		if is_instance_valid(previous) and previous.is_inside_tree(): return false
	_detected_player = false
	_navigator.invalidate()
	behaviour.navigation_repath_timer = 0.0
	_build_path = build_path
	_map_collision = weakref(map_collision)
	_player = weakref(player)
	_player_stats = read_stats
	return true

func advance_target_step(fixed_delta: float) -> void:
	_sample_pending = false
	steering_target = {}
	if not _running or _player == null: return
	var subject: Node2D = _subject.get_ref()
	if not is_instance_valid(subject): return
	var map_collision: Node2D = _map_collision.get_ref()
	if not is_instance_valid(map_collision) or not map_collision.is_inside_tree():
		_detected_player = false
		_navigator.invalidate()
		behaviour.navigation_repath_timer = 0.0
		_stop_transit(subject)
		return
	var player: AnimatableBody2D = _player.get_ref()
	if not is_instance_valid(player) or not player.is_inside_tree():
		_detected_player = false
		if current_target() == player: behaviour.target = {}
		_stop_transit(subject)
		return
	if not _player_stats.is_valid():
		_detected_player = false
		_stop_transit(subject)
		return
	var stats: Variant = _player_stats.call()
	if not stats is Dictionary or not stats.has_all(["alignment", "dead", "invincible"]):
		_detected_player = false
		_stop_transit(subject)
		return
	var existing: Object = current_target()
	if existing != null and existing != player:
		_stop_transit(subject)
		return # 此切片不能评价未绑定角色。
	var origin: Vector2 = subject.get_movement_position()
	var player_position: Vector2 = player.get_movement_position()
	var world := subject.get_world_2d()
	var observer: Dictionary = subject.stats
	if existing == null:
		behaviour.target = {}
	var observed: Dictionary = behaviour.target if existing == player else {"actor":weakref(player)}
	observed.merge({
		"dead":stats.dead, "position":player_position,
		"judicious":Combat.is_judicious_target(observer,stats),
		"hostile":Combat.is_hostile_towards(observer,stats),
		"visible":Perception.can_see(world,origin,player_position),
	},true)
	# Unity FixedUpdate 内 Time.deltaTime 返回固定步时长；不使用显示帧的 delta。
	# 旧目标先尝试宿主已绑定的正式能力，再核对目标越界。
	behaviour.tick(fixed_delta,fixed_delta,origin,_home,[observed] if _detected_player else [],
		_advance_attack)
	if not _build_path.is_null() and not _build_path.is_valid():
		_navigator.invalidate()
		behaviour.navigation_repath_timer = 0.0
		_stop_transit(subject)
		return
	# Unity Simulation 的执行顺序为 10000：本步产出的碰撞列表供下一步选敌。
	# 活动路径/靠近分支才生成新的检测帧；no_path 保留上次检测，不伪造位移。
	steering_target = _navigator.select(behaviour,origin,_build_path)
	_sample_pending = steering_target.active
	if _transit != null:
		if steering_target.active and steering_target.group == Navigation.WANDER and _wander != null:
			_submit_wander_steering(subject,origin,player,fixed_delta)
		elif steering_target.active and (steering_target.group == Navigation.TRANSIT and not steering_target.final \
				or steering_target.group in [Navigation.PREDICTIVE,Navigation.DEFAULT] and steering_target.final):
			_submit_route_steering(subject,origin,player)
		else:
			_stop_transit(subject)

func capture_detection_after_movement() -> void:
	if not _running or not _sample_pending: return
	_sample_pending = false
	var subject: Node2D = _subject.get_ref()
	var player: AnimatableBody2D = _player.get_ref()
	if not is_instance_valid(subject) or not is_instance_valid(player): return
	if _transit != null and not _transit_submission.is_empty():
		var sampled := _transit.sample(subject.get_movement_position(),_transit_submission.forward,
			_transit_submission.target,_transit_submission.max_speed,_transit_submission.group,
			_transit_submission.target_velocity,_transit_submission.arrival_stop_radius,
			_transit_submission.get("wander_intent",{}),
			_transit_submission.get("semantic_radius",SingletonTransit.SEMANTIC_RADIUS))
		if not sampled.ok:
			_detected_player = false
			push_error("路径转向探测未获验证：" + String(sampled.error))
		else:
			_detected_player = sampled.detected_colliders.has(player)
		return
	var snapshot := Perception.detect(subject.get_world_2d(),subject.get_movement_position(),
		subject.body,DETECTION_RADIUS,OBSTACLE_PROBE_RADIUS,WORLD_DETECTION_CAPACITY)
	_detected_player = snapshot.ok and snapshot.colliders.has(player)
	if not snapshot.ok: push_error("训练假人原探测缓冲已满，不能截断选敌列表")

func bind_formal_attack(attack: Callable) -> bool:
	if not _running or _player == null or _try_formal_attack.is_valid() or not attack.is_valid(): return false
	_try_formal_attack = attack
	return true

func _advance_attack(target: Dictionary, distance: float) -> void:
	if _try_formal_attack.is_valid():
		_try_formal_attack.call(target,distance)


func _on_provoked(source: Object, source_stats: Dictionary) -> void:
	var subject: Node = _subject.get_ref()
	if not _running or not is_instance_valid(subject) or not is_instance_valid(source) or source == subject: return
	var subject_stats: Dictionary = subject.stats
	if not Combat.is_judicious_target(subject_stats,source_stats): return
	# 保留角色对象身份，不保留临时属性快照；未接入追击的位置/可见性字段。
	behaviour.try_handle_provoked({"actor":weakref(source),"judicious":true})
