extends SceneTree

# Source GameConfig.asset: terrain casts use this mask, Character is separate.
# Synthetic Godot bodies establish query behavior, not Unity scene equivalence.
const MASK := 7752
const CHARACTER_MASK := 256

func _initialize() -> void:
	call_deferred("_run")

func _solid(position: Vector2, layer: int) -> void:
	var body := StaticBody2D.new()
	body.position = position
	body.collision_layer = layer
	body.add_child(_shape_node())
	root.add_child(body)

func _shape_node() -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 0.125
	shape.shape = circle
	return shape

func _query(position: Vector2, motion: Vector2) -> PhysicsShapeQueryParameters2D:
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 0.125
	query.shape = circle
	query.transform = Transform2D(0.0, position)
	query.motion = motion
	query.collision_mask = MASK
	query.collide_with_areas = false
	return query

func _run() -> void:
	_solid(Vector2(0.41, 0.0), 1 << 3)
	_solid(Vector2(0.41, 2.0), CHARACTER_MASK)
	_solid(Vector2(0.0, 6.0), 1 << 3)
	var area := Area2D.new()
	area.position = Vector2(0.41, 4.0)
	area.collision_layer = 1 << 3
	area.add_child(_shape_node())
	root.add_child(area)
	await physics_frame
	await physics_frame
	var state := root.world_2d.direct_space_state
	var failures: Array[String] = []
	for i in range(4):
		var pos := Vector2(0.0, 2.0 * i)
		var fractions := state.cast_motion(_query(pos, Vector2(0.2, 0)))
		var overlaps := state.intersect_shape(_query(pos, Vector2.ZERO))
		var hit: bool = fractions.size() == 2 and fractions[0] < 1.0
		if fractions.size() != 2 or hit != (i == 0) or (not overlaps.is_empty()) != (i == 3):
			failures.append(str(i))
		print("Probe ", i, ": fractions=", fractions, " initial overlaps=", overlaps.size())
	if failures.is_empty():
		print("PASS terrain sweep API boundary: 4 cases")
	else:
		push_error("unexpected probe results %s" % [failures])
	quit(int(not failures.is_empty()))
