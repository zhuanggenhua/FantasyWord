extends RefCounted
## 对应 31629d5 EX-GAS AbilityActivationContext；保存 Unity 世界坐标，不持有技能执行职责。
var _origin: Vector3
var _direction := Vector3.ZERO
var _has_direction := false
var _main_target: Object
var aim_origin: Vector3:
	get: return _origin
var has_aim_direction: bool:
	get: return _has_direction
var main_target: Object:
	get: return _main_target

func _init(origin: Vector3, target: Object = null, direction: Variant = null) -> void:
	_origin = origin
	_main_target = target
	if direction != null:
		assert(direction is Vector3 and source_sqr_magnitude(direction) > PackedFloat32Array([0.0001])[0],
			"Ability activation aim direction must be non-zero.")
		_direction = direction.normalized()
		_has_direction = true

## 同原 TryGetAimDirection：缺省构造时同时返回 false 和零向量。
func try_get_aim_direction() -> Dictionary:
	return {"has_direction":_has_direction,"direction":_direction}

## Unity Vector3 的 float32 分量与乘加；Godot 标量为 double，边界比较不可直接提升精度。
static func source_sqr_magnitude(value: Vector3) -> float:
	var v := PackedFloat32Array([value.x,value.y,value.z])
	var products := PackedFloat32Array([v[0]*v[0],v[1]*v[1],v[2]*v[2]])
	var xy: float = PackedFloat32Array([products[0]+products[1]])[0]
	return PackedFloat32Array([xy+products[2]])[0]
