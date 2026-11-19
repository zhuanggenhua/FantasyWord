extends SceneTree
const Capture = preload("res://gameplay/clickmovetest/water_reflection_capture_math.gd")
const CaptureNode = preload("res://gameplay/clickmovetest/water_reflection_capture.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: return
	failures += 1
	push_error(label)

func run() -> void:
	check(Capture.capture_size(Vector2i(1281,723)) == Vector2i(640,362), "0.5x; ties to even both ways")
	check(Capture.capture_size(Vector2i(79,131)) == Vector2i(64,66), "minimum RT size per axis")
	var anchor := Vector2(-0.4375,9.75)
	var reflection := Capture.reflection_transform(anchor,1.0)
	check((reflection * anchor).is_equal_approx(anchor), "source caster anchor fixed")
	check((reflection * (anchor+Vector2(0, -2))).is_equal_approx(anchor+Vector2(0.455,1.3)),
		"original skew and inverted y after Unity conversion")
	check((Capture.reflection_transform(anchor,0.45) * (anchor+Vector2(0, -2))).is_equal_approx(
		anchor+Vector2(0.20475,0.585)), "original geometry length scaling")
	var proxy := Capture.reflection_bounds(Rect2(-1,7,2,3),anchor)
	var water := Rect2(-9,9,20,12)
	var view := Rect2(-16,0,32,18)
	check(Capture.quality(proxy,water,view,anchor+Vector2(6,0),anchor).is_equal_approx(Vector2.ONE),
		"near boundary full contribution")
	check(Capture.quality(proxy,water,view,anchor+Vector2(9,0),anchor).is_equal_approx(Vector2(.5,.725)),
		"distance ramp matches SmoothStep/linear length")
	check(Capture.quality(proxy,water,view,anchor+Vector2(12,0),anchor)==Vector2.ZERO,
		"far boundary excluded")
	check(Capture.quality(proxy,Rect2(200,0,10,10),view,anchor,anchor)==Vector2.ZERO,
		"outside water renderer bounds")
	check(Capture.quality(proxy,water,Rect2(200,0,10,10),anchor,anchor)==Vector2.ZERO,
		"outside capture frustum")
	var proj := Capture.normalized_projection(Transform2D(Vector2(40,0),Vector2(0,40),Vector2(640,360)),
		Vector2(1280,720))
	check((proj*Vector2(-16,-9)).is_equal_approx(Vector2.ZERO)
		and (proj*Vector2(16,9)).is_equal_approx(Vector2.ONE),
		"world-to-capture projection maps correct orthographic extents y-down")
	var pass_node := CaptureNode.new()
	root.add_child(pass_node)
	check(not pass_node.configure("res://missing.png") and pass_node.get_child_count()==0,
		"unverified mask refuses capture construction")
	var mask_path := OS.get_environment("FORMAL_WATER_REFLECTION_MASK")
	if not mask_path.is_empty():
		check(pass_node.configure(mask_path), "authored original mask accepted")
		if pass_node.water_material() != null:
			pass_node.synchronize_main_projection(proj,Vector2i(1280,720),0.125)
			check(not pass_node.configure(mask_path), "duplicate configuration rejected")
			check(pass_node.get_child_count()==1, "Sprites-Default uses a single source-over capture")
			var first := pass_node.get_child(0) as SubViewport
			check(first.world_2d != root.world_2d,
				"capture cannot mirror unintended main canvas nodes or recurse")
			check(first.size==Vector2i(640,360)
				and (first.canvas_transform*Vector2.ZERO).is_equal_approx(Vector2(320,180)),
				"capture targets share projected position and physical resolution")
			check(pass_node.water_material().get_shader_parameter("unity_elapsed")==0.125,
				"water phase follows explicitly supplied scaled time")
	pass_node.free()
	if failures==0: print("PASS water reflection capture: %s checks; no graphical acceptance" % checks)
	quit(failures)
