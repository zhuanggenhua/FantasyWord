extends SceneTree
const Builder = preload("res://game_core/interaction/ability_activation_builder.gd")
const Context = preload("res://game_core/interaction/ability_activation_context.gd")
var n := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	n += 1
	if not ok: failed += 1; printerr(label)
func _initialize() -> void:
	var target := RefCounted.new()
	var cell := RefCounted.new()
	var root := Vector3(2,3,7)
	var position := [Vector3(2,8,99)]
	var cells := [cell]
	var geometry_calls := [0]
	var get_root := func(_target): geometry_calls[0]+=1; return position[0]
	var get_cell := func(_target): return cells[0]
	var request := {"target_character":target,"direction":Vector2(3,4),"world_position":Vector2(-4,3)}
	var c = Builder.build(request,root,func():return Vector2.LEFT,get_root,get_cell)
	check(c.aim_origin == root and c.main_target == cell and geometry_calls[0] == 0,"显式方向仍保留独立目标 Cell，原点完整保留 Z")
	check(c.has_aim_direction and c.try_get_aim_direction().direction.is_equal_approx(Vector3(.6,.8,0)),"显式方向先于目标/世界/当前方向并归一化")
	request.direction = Vector2.ZERO
	cells[0] = null
	c = Builder.build(request,root,func():return Vector2.LEFT,get_root,get_cell)
	check(c.main_target == null and c.try_get_aim_direction().direction == Vector3.UP,"无 ASC 的目标仍提供方向，目标 Z 不影响二维朝向")
	position[0] = root
	c = Builder.build(request,root,func():return Vector2(0,1),get_root,get_cell)
	check(c.try_get_aim_direction().direction == Vector3.LEFT,"重合目标退到世界点")
	request.world_position = Vector2(2,3)
	c = Builder.build(request,root,func():return Vector2(0,-4),get_root,get_cell)
	check(c.try_get_aim_direction().direction == Vector3.DOWN,"重合世界点退到当前目标朝向")
	cells[0] = cell
	c = Builder.build(request,root,func():return Vector2.ZERO,get_root,get_cell)
	check(not c.has_aim_direction and c.main_target == cell and c.try_get_aim_direction().direction == Vector3.ZERO,"无方向重载保留 Cell，绝不回填 Owner")
	request.erase("target_character")
	request.erase("world_position")
	request.direction = Vector2(.01,0)
	c = Builder.build(request,root,func():return Vector2(0,1),get_root,get_cell)
	check(c.try_get_aim_direction().direction == Vector3.UP,"float32 等于阈值必须退到后级")
	request.direction = Vector2(.010001,0)
	c = Builder.build(request,root,func():return Vector2(0,1),get_root,get_cell)
	check(c.try_get_aim_direction().direction == Vector3.RIGHT,"大于阈值有效")
	request.direction = Vector2(.009999,0)
	c = Builder.build(request,root,func():return Vector2.ZERO,get_root,get_cell)
	check(not c.has_aim_direction and c.main_target == null,"低于阈值且无方向无目标")
	var current_reads := [0]
	request.direction = Vector2(1,0)
	c = Builder.build(request,root,func():current_reads[0]+=1;return Vector2.ZERO,get_root,get_cell)
	check(current_reads[0] == 0,"高优先方向不查询角色当前朝向")
	request.direction = Vector2(NAN,0)
	c = Builder.build(request,root,func():return Vector2(0,1),get_root,get_cell)
	check(c.try_get_aim_direction().direction == Vector3.UP,"非有序方向按源代码大于判断进入后级")
	c = Context.new(root,cell,Vector3(0,0,5))
	check(c.try_get_aim_direction().direction == Vector3(0,0,1),"GAS 构造函数本身保留三维方向归一化")
	if failed == 0: print("PASS ability activation context: %d checks" % n)
	quit(0 if failed == 0 else 1)
