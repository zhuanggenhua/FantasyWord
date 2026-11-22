extends SceneTree
## 从真实 ClickMoveTest GroundLayers 拿作者 Tree 和水层。不移动 Tree 或添加水格。
const Entry = preload("res://gameplay/clickmovetest/entry.tscn")
const Ground = preload("res://gameplay/clickmovetest/ground_layers.gd")
const Capture = preload("res://gameplay/clickmovetest/water_reflection_capture.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var atlas := OS.get_environment("FORMAL_GROUND_LAYERS")
	var mask := OS.get_environment("FORMAL_WATER_REFLECTION_MASK")
	if atlas.is_empty() or mask.is_empty():
		print("SKIP 实际树倒影：需要锁定场景的私有作者素材。")
		quit()
		return
	root.size = Vector2i(800,600)
	var scene := Entry.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.set_physics_process(false)
	var ground := Ground.new()
	scene.add_child(ground)
	if not ground.configure(atlas):
		fail(scene,"原静态地层与水层未装配")
		return
	scene.ground_layers = ground
	var grouped:=FileAccess.get_sha256(atlas.path_join("ground.json")) in [Ground.GROUPED_TREE_MANIFEST_SHA256,Ground.LOW_PROP_MANIFEST_SHA256]
	var prior:=ground.get_child_count()
	var expected_tree:=ground.tree_group_for_collider(987751659)
	if grouped and (ground.tree_group_count()!=13 or expected_tree==null or expected_tree.get_child_count()!=2):
		fail(scene,"未开反射也必须有十三棵原树与各自树影")
		return
	if scene.bind_static_tree_reflection("res://missing-mask.png") or ground._reflection_tree!=null:
		fail(scene,"错误掩码不应挂载原树与水层")
		return
	if not scene.bind_static_tree_reflection(mask) or scene.bind_static_tree_reflection(mask):
		fail(scene,"只装配一个明确的原树捕获")
		return
	var capture: Capture = scene.water_reflection
	var tree: Sprite2D = capture._tree.get_ref()
	if grouped and (tree!=expected_tree.get_node("body") or ground.get_child_count()!=prior or ground.tree_group_count()!=13):
		fail(scene,"启用反射仅引用已经挂载的原树身；不能再实例化树或反射树影")
		return
	var water: AnimatedSprite2D = ground.water_base_sprite(Vector3i(-8,-10,0))
	if tree.global_position!=Vector2(-.4375,8.1875) or ground._reflection_tree.get_child_count()!=2 \
			or capture._color_target.get_child_count()!=1 or water.material!=capture.water_material():
		fail(scene,"原树和影子显示，但只允许实际树参与捕获")
		return
	scene.camera.global_position=Capture.TREE_ANCHOR
	scene.camera.zoom=Vector2(100,100)
	scene.camera.make_current()
	scene.camera.force_update_scroll()
	scene.advance_static_tree_reflection(0)
	if capture._tree_quality!=Vector2.ONE or capture._tree_proxy.texture!=tree.texture \
			or not capture._tree_proxy.is_visible_in_tree():
		fail(scene,"原树实际代理未通过近处粗裁剪")
		return
	if DisplayServer.get_name()!="headless":
		for child in ground.get_children():
			if child is AnimatedSprite2D: child.pause()
		await process_frame
		await RenderingServer.frame_post_draw
		var with_proxy := capture._color_target.get_texture().get_image()
		var visible_bounds := with_proxy.get_used_rect()
		var with_water := root.get_texture().get_image()
		if visible_bounds.size.x<20 or visible_bounds.size.y<20:
			fail(scene,"实际树图集在独立捕获中未画出可见像素")
			return
		tree.hide()
		scene.advance_static_tree_reflection(0)
		tree.show() # 只在一次可控同步时移除代理，不改真实主画布。
		await process_frame
		await RenderingServer.frame_post_draw
		var without_proxy := capture._color_target.get_texture().get_image()
		var without_water := root.get_texture().get_image()
		if without_proxy.get_used_rect().has_area() or with_water.get_data()!=without_water.get_data():
			fail(scene,"实际树的倒影不得出现在原水格范围外")
			return
		print("实际树捕获像素矩形 ",visible_bounds,"，作者水域未伪造主画布变化。")
	scene.camera.global_position=Capture.TREE_ANCHOR+Vector2(12,0)
	scene.camera.force_update_scroll()
	scene.advance_static_tree_reflection(0)
	if capture._tree_proxy.visible or capture._tree_quality!=Vector2.ZERO:
		fail(scene,"达到原远距离上限后不得保留倒影")
		return
	scene._on_surface_map_unloaded()
	scene.advance_static_tree_reflection(0)
	if scene.water_reflection!=null or scene.ground_layers!=null or not capture.is_queued_for_deletion():
		fail(scene,"原地图卸载后停止水捕获，不再投影已释放的水层")
		return
	scene.free()
	print("PASS ClickMoveTest 作者 Tree、水面绑定与独立捕获；不含玩家倒影或 Unity 对照。")
	quit()

func fail(scene: Node, reason: String) -> void:
	printerr(reason)
	scene.free()
	quit(1)
