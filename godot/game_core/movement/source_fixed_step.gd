extends RefCounted
## 固定步长来源：锁定 Unity ProjectSettings/TimeManager.asset。
## Godot 原生调度只支持整数 Hz；近 50 Hz 的原版步长另用于玩法计算。
const UNITY_TICK_COUNT := 2822399
const UNITY_RATE_NUMERATOR := 141120000
const UNITY_RATE_DENOMINATOR := 1
const ENGINE_TICKS_PER_SECOND := 50

# float32(count * denominator / numerator), 与原版 float API 精度相符。
# 无运行期开销，不把默认 Godot delta=0.02 当成原序列化参数。
const GAMEPLAY_DELTA_SECONDS := 5368707.0 / 268435456.0
