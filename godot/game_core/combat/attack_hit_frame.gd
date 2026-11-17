extends RefCounted
## ALTimelinePlayer 的命中任务时钟切片；不代持 GAS 激活、消耗、Cue 或输入缓冲。
var playing := false
var frame := -1
var _elapsed := 0.0
var _hit_frame: int
var _life_time: int
var _hit: Callable
func _init(hit_frame: int, life_time: int, hit: Callable) -> void:
	_hit_frame = hit_frame
	_life_time = life_time
	_hit = hit
func play() -> void:
	frame = -1
	_elapsed = 0.0
	playing = true
func stop() -> void: playing = false
func advance(delta: float) -> void:
	if not playing: return
	_elapsed = _f32(_elapsed + _f32(delta))
	var target := int(_f32(_elapsed * 60.0)) # GASTimer.FrameRate，不是物理帧率。
	while frame < target:
		frame += 1
		_on_frame_crossed(frame)
		if frame == _hit_frame: _hit.call()
	if frame >= _life_time:
		frame += 1
		playing = false
## 只报告同一时间轴跨过的帧；具体任务由技能时间轴拥有者调度。
func _on_frame_crossed(_frame: int) -> void:
	pass
static func _f32(value: float) -> float: return PackedFloat32Array([value])[0]
