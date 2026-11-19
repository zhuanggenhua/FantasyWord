extends RefCounted
## Projection and visibility isolated from author caster selection. Coordinates
## are Godot world (y down); the source uses Unity world (y up).

static func capture_size(camera_pixels: Vector2i) -> Vector2i:
	# Mathf.RoundToInt uses round-to-even, including odd pixel dimensions.
	var half := Vector2i(camera_pixels.x >> 1, camera_pixels.y >> 1)
	if (camera_pixels.x & 1) != 0 and (half.x & 1) != 0: half.x += 1
	if (camera_pixels.y & 1) != 0 and (half.y & 1) != 0: half.y += 1
	return half.max(Vector2i(64, 64))

static func reflection_transform(anchor: Vector2, length_scale: float) -> Transform2D:
	var reflected_y := -0.65 * length_scale
	# R * Unity reflection * R, with R flipping y.
	var transform := Transform2D(Vector2.RIGHT, Vector2(0.35 * reflected_y, reflected_y), Vector2.ZERO)
	transform.origin = anchor - transform.basis_xform(anchor)
	return transform

static func reflection_bounds(source_bounds: Rect2, anchor: Vector2) -> Rect2:
	return (reflection_transform(anchor, 1.0) * source_bounds).grow(0.5)

static func quality(reflected_bounds: Rect2, water_bounds: Rect2,
		camera_bounds: Rect2, camera_focus: Vector2, anchor: Vector2) -> Vector2:
	# Bounds.Intersects includes touching edges. x is strength; y is length.
	var distance := camera_focus.distance_to(anchor)
	if distance >= 12.0 or not reflected_bounds.intersects(water_bounds, true) \
			or not reflected_bounds.intersects(camera_bounds, true):
		return Vector2.ZERO
	var fraction := 1.0 - clampf((distance - 6.0) / 6.0, 0.0, 1.0)
	return Vector2(smoothstep(0.0, 1.0, fraction), lerpf(0.45, 1.0, fraction))

static func normalized_projection(main_world_to_pixel: Transform2D, camera_pixels: Vector2) -> Transform2D:
	# The two render targets expose the same orthographic world extents; only
	# output sampling dimensions change, not the normalized projection.
	var normalize := Transform2D(Vector2(1.0 / camera_pixels.x, 0.0),
		Vector2(0.0, 1.0 / camera_pixels.y), Vector2.ZERO)
	return normalize * main_world_to_pixel
