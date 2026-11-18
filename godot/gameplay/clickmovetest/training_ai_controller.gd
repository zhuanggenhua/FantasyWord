extends RefCounted
## 锁定 ClickMoveTest 的活动假人 AIController：仅接入启动、挑衅选敌、停止。
## 侦测、路径规划、转向、游走与攻击还未接入，不能加入替代行为。
const TargetLifecycle = preload("res://game_core/ai/ai_target_lifecycle.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
const SOURCE_SCENE_INSTANCE := "735002000000000003"
const SOURCE_CONTROLLER := "4536545658951696519"

var running: bool:
	get: return _running
var _running := false
var _subject: WeakRef
var behaviour := TargetLifecycle.new()

func start(subject: Node) -> void:
	if _running: return
	_subject = weakref(subject)
	_running = true
	subject.formal_provoked.connect(_on_provoked)

func stop() -> void:
	if not _running: return
	_running = false
	var subject: Node = _subject.get_ref()
	if is_instance_valid(subject): subject.formal_provoked.disconnect(_on_provoked)
	behaviour.stop_controller()

func current_target() -> Object:
	var actor: WeakRef = behaviour.target.get("actor")
	return actor.get_ref() if actor != null else null

func _on_provoked(source: Object, source_stats: Dictionary) -> void:
	var subject: Node = _subject.get_ref()
	if not _running or not is_instance_valid(subject) or not is_instance_valid(source) or source == subject: return
	var subject_stats: Dictionary = subject.stats
	if not Combat.is_judicious_target(subject_stats,source_stats): return
	# 保留角色对象身份，不保留临时属性快照；未接入追击的位置/可见性字段。
	behaviour.try_handle_provoked({"actor":weakref(source),"judicious":true})
