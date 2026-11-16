extends SceneTree
const Directions = preload("res://game_core/presentation/character_animation_directions.gd")
var checked := 0
var failures := 0

func check(ok: bool, context: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		push_error(context)

func _initialize() -> void:
	check(Directions.copy_names() == ["SE", "SW", "NE", "NW"], "四向素材顺序")
	var copy := Directions.copy_names()
	copy[0] = "x"
	check(Directions.copy_names()[0] == "SE", "返回的名称副本不可篡改素材约定")
	for index in Directions.COUNT:
		var vector := Directions.get_direction_vector(index)
		check(Directions.resolve_index(vector, 3-index) == index, "对角方向覆盖两个旧朝向位")
		check(Directions.resolve_index(Vector2.ZERO, index) == index, "零向量保持合法方向")
		check(Directions.resolve_index(Vector2(0.0001, 0.0), index) == index, "极短方向保持")
		var expected_east := 0 if index < 2 else 2
		var expected_west := 1 if index < 2 else 3
		check(Directions.resolve_index(Vector2.RIGHT, index) == expected_east, "纯东只改变东西位")
		check(Directions.resolve_index(Vector2.LEFT, index) == expected_west, "纯西只改变东西位")
		check(Directions.resolve_index(Vector2(0.0001, 1), index) == 2 + index % 2, "正近轴边界保留东西位")
		check(Directions.resolve_index(Vector2(-0.0001, -1), index) == index % 2, "负近轴边界保留东西位")
		check(Directions.resolve_index(Vector2(-1, 0.0001), index) == expected_west, "正近轴边界保留南北位")
		check(Directions.resolve_index(Vector2(1, -0.0001), index) == expected_east, "负近轴边界保留南北位")
	check(not Directions.has_facing(Vector2(0.01, 0)), "近零长度平方阈值")
	check(Directions.has_facing(Vector2(0.01001, 0)), "长度平方越过阈值")
	check(Directions.resolve_index(Vector2(0.00011, -1), 1) == 0, "越过轴阈值更新东西位")
	check(Directions.resolve_index(Vector2(1, 0.00011), 0) == 2, "越过轴阈值更新南北位")
	check(Directions.resolve_index(Vector2.ZERO, -1) == 0, "静止且非法旧索引回退 SE")
	check(Directions.resolve_index(Vector2(0, 1), 99) == 3, "有朝向且非法旧索引不伪造旧 east 位")
	check(Directions.get_direction_name(4) == "SE" and Directions.get_direction_vector(-1) == Vector2(1, -1),
		"只读约定查询的非法索引回退 SE")
	if failures == 0:
		print("PASS 角色四向素材约定：%d 项" % checked)
	quit(1 if failures else 0)
