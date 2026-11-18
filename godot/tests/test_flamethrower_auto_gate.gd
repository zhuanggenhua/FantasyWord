extends SceneTree
const Gate = preload("res://game_core/combat/flamethrower_auto_gate.gd")
var checks := 0
var failures := 0
var eligible := true
var commits := 0
var can_commit := true
var starts := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gate := Gate.new(func(): return eligible, _commit)
	var stopped := [0]
	gate.sequence_started.connect(func(): starts += 1)
	gate.sequence_stopped.connect(func(): stopped[0] += 1)
	_check(gate.request_use() and gate.state == Gate.State.WINDUP and gate.is_busy(), "按下进入前摇")
	_check(gate.timer == PackedFloat32Array([1.0/60.0])[0], "前摇源首玩法帧1/60")
	gate.advance(0.01)
	_check(commits == 0, "前摇未到不释放")
	gate.release_use()
	_check(gate.state == Gate.State.INTERRUPTED and stopped[0] == 1 and not gate.is_busy(), "松开前摇中断")
	gate.advance(0.0)
	gate.request_use()
	gate.advance(20.0)
	_check(commits == 1 and gate.state == Gate.State.RECOVERY, "大步长也只从前摇提交一次，不吃剩余时间")
	_check(gate.timer == PackedFloat32Array([65.0/60.0])[0], "后摇源整条Timeline65/60")
	_check(not gate.request_use(), "忙碌输入无缓冲")
	gate.advance(Gate.RECOVERY_SECONDS)
	_check(starts == 3 and commits == 1 and gate.state == Gate.State.WINDUP and stopped[0] == 1, "按住到期直接再次起手，不先发停止事件")
	gate.advance(Gate.WINDUP_SECONDS)
	_check(commits == 2, "再次起手仍需完整前摇")
	eligible = false
	gate.advance(Gate.RECOVERY_SECONDS)
	_check(gate.state == Gate.State.STOP and stopped[0] == 2, "连发资格被撤销则停止")
	gate.advance(0.0)
	eligible = true
	gate.advance(10.0)
	_check(gate.state == Gate.State.IDLE and commits == 2, "停止后持按不会自行重试或消费不存在的缓冲")
	gate.request_use()
	can_commit = false
	gate.advance(Gate.WINDUP_SECONDS)
	_check(gate.state == Gate.State.INTERRUPTED and stopped[0] == 3, "出手重检失败会打断")
	gate.release_use()
	gate.advance(0.0)
	can_commit = true
	gate.request_use()
	gate.advance(Gate.WINDUP_SECONDS)
	gate.release_use()
	_check(gate.state == Gate.State.STOP and stopped[0] == 4 and not gate.trigger_held, "松开后摇停止生命周期")
	gate.advance(0.0)
	gate.request_use()
	gate.set_time_scale(0.0)
	gate.advance(-1.0)
	_check(gate.timer == Gate.WINDUP_SECONDS, "负delta不倒退")
	gate.advance(0.1)
	_check(gate.state == Gate.State.WINDUP, "时间缩放下限0.05")
	gate.advance(0.3)
	_check(gate.state == Gate.State.RECOVERY, "按缩放推进前摇")
	print("%s 喷火自动门控：%d 项" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(1 if failures else 0)
func _commit() -> bool:
	commits += 1
	return can_commit
func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
