extends RefCounted
## 锁定 ClickMoveTest 的活动假人 AIController：启动、挑衅、选敌与停止。
## 只运行已验证可提交活动探测的分支；不借侦测接口替代路径、转向或攻击。
const TargetLifecycle = preload("res://game_core/ai/ai_target_lifecycle.gd")
const Perception = preload("res://game_core/ai/ai_perception.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
const SOURCE_SCENE_INSTANCE := "735002000000000003"
const SOURCE_CONTROLLER := "4536545658951696519"
const DETECTION_RADIUS := 5.0
const OBSTACLE_PROBE_RADIUS := 1.0
const WORLD_DETECTION_CAPACITY := 128
const FINAL_APPROACH_DISTANCE := 1.350000023841858 # 1 + max(.2, .35, .3)，源 float32
const COMBAT_WANDER_RANGE := 3.0

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

func start(subject: Node) -> void:
	if _running: return
	_subject = weakref(subject)
	_home = subject.get_movement_position()
	_running = true
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
	behaviour.stop_controller()

func current_target() -> Object:
	var actor: WeakRef = behaviour.target.get("actor")
	return actor.get_ref() if actor != null else null

## 仅接受 Entry 实际玩家身体及其既有正式属性入口，不在控制器内造角色状态。
func bind_player(player: AnimatableBody2D, read_stats: Callable, map_collision: Node2D) -> bool:
	if not _running or not is_instance_valid(player) or not read_stats.is_valid():
		return false
	if not player.is_inside_tree() or not player.has_method("get_movement_position"):
		return false
	if not is_instance_valid(map_collision) or not map_collision.is_inside_tree() \
			or map_collision.get_world_2d() != player.get_world_2d(): return false
	if _map_collision != null:
		var previous: Node2D = _map_collision.get_ref()
		if is_instance_valid(previous) and previous.is_inside_tree(): return false
	_detected_player = false
	_map_collision = weakref(map_collision)
	_player = weakref(player)
	_player_stats = read_stats
	return true

func advance_target_step(fixed_delta: float) -> void:
	_sample_pending = false
	if not _running or _player == null: return
	var subject: Node2D = _subject.get_ref()
	if not is_instance_valid(subject): return
	var map_collision: Node2D = _map_collision.get_ref()
	if not is_instance_valid(map_collision) or not map_collision.is_inside_tree():
		_detected_player = false
		return
	var player: AnimatableBody2D = _player.get_ref()
	if not is_instance_valid(player) or not player.is_inside_tree():
		_detected_player = false
		if current_target() == player: behaviour.target = {}
		return
	if not _player_stats.is_valid():
		_detected_player = false
		return
	var stats: Variant = _player_stats.call()
	if not stats is Dictionary or not stats.has_all(["alignment", "dead", "invincible"]):
		_detected_player = false
		return
	var existing: Object = current_target()
	if existing != null and existing != player: return # 此切片不能评价未绑定角色。
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
	# Unity Simulation 的执行顺序为 10000：本步产出的碰撞列表供下一步选敌。
	# 归位和最终接近（含已配置的战斗游走范围）必进 active 分支；
	# 远距转向提交可能取决于尚未接线的路径游标，不能伪造该分支的新观测。
	var distance := origin.distance_to(behaviour.target_position)
	_sample_pending = (distance <= FINAL_APPROACH_DISTANCE
		or (not behaviour.target.is_empty() and distance <= COMBAT_WANDER_RANGE))

func capture_detection_after_movement() -> void:
	if not _running or not _sample_pending: return
	_sample_pending = false
	var subject: Node2D = _subject.get_ref()
	var player: AnimatableBody2D = _player.get_ref()
	if not is_instance_valid(subject) or not is_instance_valid(player): return
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
