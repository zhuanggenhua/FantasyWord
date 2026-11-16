extends RefCounted
## Unity 31629d5 CharacterAnimationDirections; input vectors are Y-up.
const SOUTH_EAST := 0
const SOUTH_WEST := 1
const NORTH_EAST := 2
const NORTH_WEST := 3
const COUNT := 4
const NAMES: Array[String] = ["SE", "SW", "NE", "NW"]
const VECTORS: Array[Vector2] = [Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]
const AXIS_EPSILON := 0.0001 # Round to Unity Single at comparison.

static func is_valid_index(index: int) -> bool:
	return index >= 0 and index < COUNT

static func get_direction_name(index: int) -> String:
	return NAMES[index] if is_valid_index(index) else NAMES[SOUTH_EAST]

static func copy_names() -> Array[String]:
	return NAMES.duplicate()

static func get_direction_vector(index: int) -> Vector2:
	return VECTORS[index] if is_valid_index(index) else VECTORS[SOUTH_EAST]

static func _f32(value: float) -> float:
	return PackedFloat32Array([value])[0]

static func _length_squared_f32(direction: Vector2) -> float:
	var x := _f32(direction.x)
	var y := _f32(direction.y)
	return _f32(_f32(x * x) + _f32(y * y))

static func has_facing(direction: Vector2) -> bool:
	return _length_squared_f32(direction) > _f32(AXIS_EPSILON)

static func resolve_index(direction: Vector2, current_index: int) -> int:
	if not has_facing(direction):
		return current_index if is_valid_index(current_index) else SOUTH_EAST
	var currently_east := current_index == SOUTH_EAST or current_index == NORTH_EAST
	var currently_north := current_index == NORTH_EAST or current_index == NORTH_WEST
	var east := direction.x >= 0.0 if absf(_f32(direction.x)) > _f32(AXIS_EPSILON) else currently_east
	var north := direction.y > 0.0 if absf(_f32(direction.y)) > _f32(AXIS_EPSILON) else currently_north
	if north:
		return NORTH_EAST if east else NORTH_WEST
	return SOUTH_EAST if east else SOUTH_WEST
