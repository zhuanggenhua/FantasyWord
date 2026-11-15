extends SceneTree

const Filter = preload("res://game_core/movement/motion_filter.gd")
const M = Filter.Mode
var checks := 0
var failures := 0
var ramp_calls := 0


func _initialize() -> void:
	# Base actor prefab: free direction, digital input, accel/decel 10, idle .05.
	var digital = Filter.new(M.FREE, false, 0.05, 10.0, 10.0)
	_check(digital.resolve(Vector2.RIGHT, 0.02).is_equal_approx(Vector2(0.2, 0)), "首个固定步骤")
	_check(digital.resolve(Vector2.RIGHT, 0.02).is_equal_approx(Vector2(0.36, 0)), "第二步累加加速量")
	_check(digital.resolve(Vector2.UP, 0.02).is_equal_approx(Vector2(0, -0.488)), "换方向不缓插方向向量")
	# 上一步 .488；零输入后加速量 .3904，插值结果 .42850304。
	_check(digital.resolve(Vector2.ZERO, 0.02).is_equal_approx(Vector2(0, -0.42850304)), "自然减速按原公式")
	digital.reset()
	_check(digital.resolve(Vector2.ZERO, 0.02).is_zero_approx(), "显式停令清除缓动")
	_check(digital.resolve(Vector2(1e-7, 0), 0.02).is_zero_approx(), "极小数字意图不归一成移动")
	_check(digital.resolve(Vector2(1, -1), 0.5).is_equal_approx(Vector2(1, -1).normalized()), "插值上限及对角归一")

	var analog = Filter.new(M.FREE, true, 0.05, 0.0, 10.0)
	_check(analog.resolve(Vector2(0.03, 0.03), 0.02).is_zero_approx(), "模拟输入低于闲置阈值")
	_check(analog.resolve(Vector2(0.2, 0), 0.02).is_equal_approx(Vector2(0.2, 0)), "未启用完整缓动时保留模拟幅值")
	_check(analog.resolve(Vector2(2, 0), 0.02).is_equal_approx(Vector2.RIGHT), "模拟幅值上界")
	_check(analog.resolve(Vector2(0.4, 0), 0.02, _ramp).is_equal_approx(Vector2(0, 0.4)), "坡道方向保留输入强度")
	_check(analog.resolve(Vector2.ZERO, 0.02, _ramp).is_zero_approx() and ramp_calls == 1, "零输入不查地图")
	_check(analog.resolve(Vector2(0.4, 0), 0.02, func(_v): return null).is_equal_approx(Vector2(0.4, 0)), "地图不改向时保留原意图")

	_check(Filter.new(M.HORIZONTAL, true, 0, 0, 0).resolve(Vector2(0.3, 0.4), 0.02).is_equal_approx(Vector2(0.3, 0)), "横向限制")
	_check(Filter.new(M.VERTICAL, true, 0, 0, 0).resolve(Vector2(0.3, 0.4), 0.02).is_equal_approx(Vector2(0, 0.4)), "纵向限制")
	var four = Filter.new(M.FOUR_WAY, true, 0, 0, 0)
	_check(four.resolve(Vector2(0.5, -0.5), 0.02).is_equal_approx(Vector2(0, -0.5)), "四向相等时保留纵向")
	_check(four.resolve(Vector2(0.6, -0.5), 0.02).is_equal_approx(Vector2(0.6, 0)), "四向横向更大时保留横向")
	var eight = Filter.new(M.EIGHT_WAY, true, 0, 0, 0)
	_check(eight.resolve(Vector2(-0.5, 0.5), 0.02).is_zero_approx(), "八向舍入中点取偶")
	_check(eight.resolve(Vector2(-0.6, 0.49), 0.02).is_equal_approx(Vector2.LEFT), "八向逐轴舍入")
	_check(is_equal_approx(Filter.effective_stop_distance(0.05), 0.1), "请求 0.05 不等于执行容差")
	_check(is_equal_approx(Filter.effective_stop_distance(0.3), 0.3), "较大的请求容差保留")
	if failures == 0:
		print("PASS 角色移动意图过滤：%d 项" % checks)
	quit(1 if failures else 0)


func _ramp(_v: Vector2) -> Vector2:
	ramp_calls += 1
	return Vector2.DOWN


func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("移动意图过滤断言失败：" + detail)
