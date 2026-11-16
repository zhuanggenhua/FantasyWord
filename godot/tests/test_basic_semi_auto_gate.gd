extends SceneTree
const Gate = preload("res://game_core/combat/basic_semi_auto_gate.gd")
var checks := 0
var failures := 0
var starts := 0
var commits := 0
var eligible := true
var can_commit := true
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gate := Gate.new(_check_start, _commit)
	var stopped := [0]
	gate.sequence_stopped.connect(func():stopped[0] += 1)
	_check(gate.request_use() and gate.state == Gate.State.WINDUP, "按下先进入前摇")
	_check(gate.timer == PackedFloat32Array([1.0/60.0])[0], "前摇用源 float32 帧时长")
	gate.advance(0.01)
	_check(commits == 0, "不足一帧不提交")
	gate.release_use()
	_check(gate.state == Gate.State.INTERRUPTED and commits == 0 and stopped[0] == 1, "前摇松手中断")
	gate.advance(0.0)
	gate.request_use()
	can_commit = false
	gate.advance(0.02)
	_check(commits == 1 and gate.state == Gate.State.INTERRUPTED, "出手时重新校验，提交拒绝则中断")
	gate.release_use()
	gate.advance(0.0)
	can_commit = true
	gate.request_use()
	gate.advance(0.02)
	_check(commits == 2 and gate.timer == 0.5 and gate.state == Gate.State.RECOVERY, "正常提交一次并进入30/60后摇")
	_check(not gate.request_use() and gate.buffered, "未松开时只缓存，不重复出手")
	gate.release_use()
	_check(gate.state == Gate.State.STOP, "后摇松手中止")
	eligible = false
	var before := starts
	gate.advance(0.01)
	_check(starts == before + 1 and not gate.buffered and gate.state == Gate.State.IDLE and commits == 2, "缓冲到期消费重检，资格撤销不再次提交")
	eligible = true
	gate.request_use()
	gate.advance(0.02)
	gate.request_use()
	gate.release_use()
	before = starts
	gate.advance(0.25)
	_check(starts == before and not gate.buffered, "同帧先过期，不消费")
	gate.request_use()
	gate.advance(0.02)
	gate.request_use()
	gate.advance(0.15)
	gate.request_use()
	gate.release_use()
	gate.advance(0.15)
	_check(gate.state == Gate.State.WINDUP, "原配置用新请求延长有效缓冲")
	if failures == 0:
		print("PASS 普攻半自动门控：%d 项" % checks)
	quit(1 if failures else 0)
func _check_start() -> bool:
	starts += 1
	return eligible
func _commit() -> bool:
	commits += 1
	return can_commit
func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
