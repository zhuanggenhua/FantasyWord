extends SceneTree
const Gate = preload("res://game_core/combat/hold_release_gate.gd")
var checks := 0
var failures := 0
var eligible := true
var accepted := true
var starts := 0
var releases := 0
func _initialize(): call_deferred("_run")
func check(ok: bool, detail: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
func _run():
	var events: Array = []
	var gate = Gate.new(func(): starts += 1; return eligible,
		func(): releases += 1; return accepted)
	gate.sequence_started.connect(func():events.append("start"))
	gate.sequence_stopped.connect(func():events.append("stop"))
	gate.interrupted.connect(func():events.append("interrupt"))
	gate.state_changed.connect(func(s):events.append(s))
	check(not gate.release_use() and releases == 0,"空闲松手不释放")
	check(gate.request_use() and gate.is_charging(),"按下进入蓄力")
	check(events == ["start",Gate.State.START,Gate.State.CHARGING],"源启动通知顺序")
	gate.advance(100)
	check(gate.is_charging() and releases == 0,"长按任意时长不自动释放")
	check(not gate.request_use() and starts == 1,"蓄力重复按下拒绝且不重检")
	check(gate.release_use() and releases == 1,"松手独立执行一次")
	check(gate.state == Gate.State.DELAY_BETWEEN_USES,"成功进入36/60间隔")
	check(gate.timer == PackedFloat32Array([36.0 / 60.0])[0], "准确保留源 float32 后摇")
	check(not gate.request_use(),"后摇不缓冲按下")
	gate.advance(0.59)
	check(gate.state == Gate.State.DELAY_BETWEEN_USES,"未满源间隔不停止")
	gate.advance(0.02)
	check(gate.state == Gate.State.STOP,"满间隔仅到Stop")
	gate.advance(0)
	check(gate.state == Gate.State.IDLE and starts == 1 and releases == 1,"下一tick空闲，不消费忙时按下")
	eligible = false
	check(not gate.request_use() and not gate.is_charging(),"起手独立资格拒绝")
	eligible = true
	gate.request_use()
	accepted = false
	check(not gate.release_use() and gate.state == Gate.State.INTERRUPTED,"释放重新验证失败打断")
	check(events.slice(events.size()-3) == [Gate.State.INTERRUPTED,"interrupt","stop"],"失败中断和终止顺序")
	gate.advance(0)
	check(gate.state == Gate.State.IDLE,"打断下一tick回Idle")
	accepted = true
	gate.request_use()
	gate.interrupt()
	var before = releases
	check(not gate.release_use() and releases == before,"外部打断后松手不释放")
	gate.advance(0)
	gate.request_use()
	gate.release_use()
	check(not gate.release_use() and gate.state == Gate.State.STOP,"后摇松手依配置收束")
	check(gate.request_use(),"Stop可以立即接受新按下")
	gate.release_use()
	gate.set_time_scale(2)
	gate.advance(-1)
	check(gate.state == Gate.State.DELAY_BETWEEN_USES,"负delta不倒退计时")
	gate.advance(0.31)
	check(gate.state == Gate.State.STOP,"倍率影响本地后摇")
	if failures == 0: print("PASS HoldRelease源状态门：%d 项" % checks)
	quit(1 if failures else 0)
