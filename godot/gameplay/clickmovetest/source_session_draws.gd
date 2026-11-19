extends RefCounted
## 同一普通场景会话的游走、玩家及假人共享随机来源。保留源范围和调用语义，
## 不宣称 Godot 的随机状态可以与 Unity 引擎位流互换。
const CLOSED_STEPS := 1 << 24
var _stream: RandomNumberGenerator

func _init(stream: RandomNumberGenerator = null) -> void:
	if stream == null:
		_stream = RandomNumberGenerator.new()
		_stream.randomize()
	else:
		_stream = stream

func value() -> float:
	# 2^24 离散分数可直接以单精度表示，且保留原浮点接口的两个包含端点。
	return float(_stream.randi_range(0,CLOSED_STEPS))/float(CLOSED_STEPS)

func inclusive_range(minimum: float, maximum: float) -> float:
	var result: float=lerpf(minimum,maximum,value())
	return clampf(PackedFloat32Array([result])[0],minimum,maximum)

func resolve_damage() -> int:
	# Unity int Range(1,100) 的上限排除，命中和暴击消费顺序归正式求解器。
	return _stream.randi_range(1,99)
