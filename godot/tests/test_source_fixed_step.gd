extends SceneTree
const SourceFixedStep = preload("res://game_core/movement/source_fixed_step.gd")
const Fixture = preload("res://validation/scenes/keyboard_motion_fixture.tscn")
class Observer extends Node:
	var samples: Array[float] = []
	func _physics_process(delta: float) -> void:
		samples.append(delta)
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var source := PackedFloat32Array([2822399.0 / 141120000.0])
	_check(SourceFixedStep.GAMEPLAY_DELTA_SECONDS == source[0], "玩法步长等于锁定序列化比例转 float32")
	_check(SourceFixedStep.GAMEPLAY_DELTA_SECONDS != PackedFloat32Array([0.02])[0], "不可用 0.02 替换原浮点值")
	_check(Engine.physics_ticks_per_second == SourceFixedStep.ENGINE_TICKS_PER_SECOND, "项目原生调度启用了 50 Hz")
	var observer := Observer.new()
	root.add_child(observer)
	var host := Fixture.instantiate()
	root.add_child(host)
	for frame in range(5): await physics_frame
	_check(observer.samples.size() >= 4 and host.steps >= 4, "实际场景和观察器都收到固定步")
	_check(observer.samples.all(func(delta: float) -> bool: return absf(delta - 0.02) < 0.0000000001), "实际回调每步 0.02 秒")
	observer.queue_free()
	host.queue_free()
	await process_frame
	if failures == 0: print("PASS 固定步长：%d 项" % checks)
	quit(1 if failures else 0)
func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
