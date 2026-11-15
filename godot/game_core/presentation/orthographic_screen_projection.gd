extends RefCounted
## Unity orthographic XY → Godot viewport contract, one physics unit per source world unit.
## Screen input is already local to the viewport, with a top-left pixel origin.
## No UI routing, camera selection, damping, letterboxing or physical device input here.


static func zoom_for_view_height(view_pixels: float, source_orthographic_size: float) -> Vector2:
	if not is_finite(view_pixels) or not is_finite(source_orthographic_size) \
			or view_pixels <= 0.0 or source_orthographic_size <= 0.0:
		return Vector2.ZERO
	return Vector2.ONE * (view_pixels / (2.0 * source_orthographic_size))


static func project(camera: Camera2D, screen: Vector2) -> Variant:
	if not is_instance_valid(camera) or not camera.is_inside_tree() or not screen.is_finite():
		return null
	var viewport := camera.get_viewport()
	if viewport == null or viewport.get_camera_2d() != camera:
		return null
	var transform := viewport.get_canvas_transform()
	if not transform.is_finite() or transform.determinant() == 0.0:
		return null
	# Camera2D.global_position is not necessarily the canvas center: limits and
	# smoothing can change output without changing the authored node position.
	var world := transform.affine_inverse() * screen
	return Vector2(world.x, -world.y) if world.is_finite() else null
