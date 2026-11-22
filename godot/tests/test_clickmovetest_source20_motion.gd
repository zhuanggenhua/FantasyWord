extends SceneTree
const Startup := preload("res://gameplay/clickmovetest/source_startup.gd")
const Ground := preload("res://gameplay/clickmovetest/ground_layers.gd")
const Geometry := preload("res://gameplay/clickmovetest/source_static_geometry.gd")
const CLIFF_ID := 913349352
const FROM := Vector2(-3.55,3.5)
const TO := Vector2(-2.55,3.5)
var checks:=0
var failures:=0

func _initialize() -> void: call_deferred("run")

func check(value: bool,label: String) -> bool:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL ",label)
	return value

func finish() -> void:
	print("PASS source20 production mounting and movement: %d/%d"%[checks-failures,checks] if not failures else "FAIL source20 checks")
	quit(1 if failures else 0)

func key(code: Key,pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=pressed
	root.push_input(event,true)

func run() -> void:
	if OS.get_environment("FORMAL_STATIC_COLLIDERS").is_empty():
		print("SKIP requires locked private collider extraction")
		finish(); return
	check(Geometry.build(OS.get_environment("FORMAL_SURFACE_RULES"))==null,"unrelated source cannot stand in for the actual outline")
	root.size=Vector2i(960,540)
	if change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))!=OK:
		check(false,"real F5 path"); finish(); return
	await scene_changed
	for i in 4: await physics_frame
	var boot:=current_scene as Startup
	if not check(boot!=null and boot.scene!=null,"actual startup scene is mounted"):
		finish(); return
	var state:=root.world_2d.direct_space_state
	var body:=boot.scene.get_node_or_null("SourceStaticGeometry/SourceCollider%d"%CLIFF_ID) as StaticBody2D
	if not check(body!=null and body.collision_layer==1 and body.collision_mask==0
			and body.get_meta("source_file_id")==CLIFF_ID,"production host mounts the original Default geometry"):
		finish(); return
	var host:=body.get_parent()
	var source: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FORMAL_STATIC_COLLIDERS")))
	check(host.get_child_count()==35 and source.bodies.size()==35,"actual F5 mounts exactly the 35 original Default bodies")
	var boxes:=0
	var outlines:=0
	for row: Dictionary in source.bodies:
		var id := int(row.source_file_id)
		var part:=host.get_node_or_null("SourceCollider%d"%id) as StaticBody2D
		if not check(part!=null and part.get_meta("source_file_id")==id and part.collision_layer==1
				and part.collision_mask==0 and part.position.is_equal_approx(_source_position(row.origin)),
				"exact body identity, layer and origin %d"%id):
			continue
		var shape: Shape2D=part.get_child(0).shape
		if row.kind=="box":
			boxes+=1
			var box:=shape as RectangleShape2D
			check(box!=null and box.size.is_equal_approx(Vector2(row.size[0],row.size[1])),"exact box %d"%id)
		else:
			outlines+=1
			var expected:=PackedVector2Array()
			for loop: Array in row.paths:
				for i in loop.size():
					expected.append(_source_position(loop[i]))
					expected.append(_source_position(loop[(i+1)%loop.size()]))
			var outline:=shape as ConcavePolygonShape2D
			check(outline!=null and outline.segments==expected,"exact closed outline %d"%id)
	check(boxes==27 and outlines==8,"27 authored boxes and 8 composites")
	for id in [325078254,1275043674]:
		var pillar:=host.get_node("SourceCollider%d"%id) as StaticBody2D
		var point:=PhysicsPointQueryParameters2D.new()
		point.position=pillar.global_position
		point.collision_mask=1
		check(state.intersect_point(point).any(func(result: Dictionary):return result.collider==pillar),
			"Default physics queries reach the original pillar %d"%id)
		point.collision_mask=7752
		check(not state.intersect_point(point).any(func(result: Dictionary):return result.collider==pillar),
			"Movable mask still excludes original pillar %d"%id)
	var ground_path := OS.get_environment("FORMAL_GROUND_LAYERS").path_join("ground.json")
	var ground_sha:=FileAccess.get_sha256(ground_path)
	var all_structures := ground_sha in [Ground.WALL_AND_CLIFF_MANIFEST_SHA256,Ground.GROUPED_TREE_MANIFEST_SHA256,Ground.LOW_PROP_MANIFEST_SHA256]
	if all_structures or ground_sha in [Ground.PILLAR_MANIFEST_SHA256,Ground.HORIZONTAL_WALL_MANIFEST_SHA256]:
		var ground: Node2D=boot.scene.ground_layers
		check(ground!=null and ground.pillar_count()==14,"实际 F5 入口含 14 根原柱子及阴影")
		for id in [325078254,1275043674]:
			var pillar := ground.pillar_for_collider(id) as Node2D
			var collider := host.get_node_or_null("SourceCollider%d"%id) as StaticBody2D
			check(pillar!=null and collider!=null and pillar.global_position.is_equal_approx(collider.global_position),
				"原柱画面与独立 Default 碰撞盒位置对应 %d"%id)
	if all_structures or ground_sha==Ground.HORIZONTAL_WALL_MANIFEST_SHA256:
		var wall_display:=boot.scene.ground_layers.static_decoration_sprite(1289053702,Vector3i(6,-6,0)) as Sprite2D
		var wall_query:=host.get_node_or_null("SourceCollider1289053698") as StaticBody2D
		check(wall_display!=null and wall_query!=null and wall_query.collision_layer==1
			and wall_query.collision_mask==0,"实际 F5 同时显示原横墙且仍只保留原 Default 查询形状")
	if all_structures:
		for id in [163064786,2118149258,432984437,147438656]:
			var solid_shape:=host.get_node_or_null("SourceCollider%d"%(id-4)) as StaticBody2D
			check(boot.scene.ground_layers.static_decoration_count(id)>0 and solid_shape!=null
				and solid_shape.collision_layer==1 and solid_shape.collision_mask==0,
				"实际 F5 原结构显示与独立 Default 轮廓 %d"%id)
	if ground_sha in [Ground.GROUPED_TREE_MANIFEST_SHA256,Ground.LOW_PROP_MANIFEST_SHA256]:
		var ground: Node2D=boot.scene.ground_layers
		check(ground.tree_group_count()==13,"实际 F5 保留十三棵原树")
		var capture = boot.scene.water_reflection
		var source_tree := ground.tree_group_for_collider(987751659) as Node2D
		check(capture!=null and source_tree!=null and capture._tree.get_ref()==source_tree.get_node("body")
			and ground._reflection_tree==source_tree,"实际 F5 默认反射引用已挂载树体，不造重复树")
		for id in [987751659,1646161703,1606656678]:
			check(ground.tree_group_for_collider(id)!=null and host.has_node("SourceCollider%d"%id),
				"原树画面组与独立 Default 查询形状 %d"%id)
	if ground_sha==Ground.LOW_PROP_MANIFEST_SHA256:
		var ground: Node2D=boot.scene.ground_layers
		check(ground.low_prop_count()==32,"实际 F5 保留 32 个原静态藤蔓香蒲")
		for id in [1474770966,1655619244,1901380167]:
			check(ground.low_prop_for_object(id)!=null and not host.has_node("SourceCollider%d"%id),
				"原无碰撞装饰不在 Default 查询宿主 %d"%id)
	var ray:=PhysicsRayQueryParameters2D.create(Vector2(FROM.x,-FROM.y),Vector2(TO.x,-TO.y),1)
	var hit:=state.intersect_ray(ray)
	check(hit.get("collider")==body and is_equal_approx(float(hit.get("position",Vector2.ZERO).x),-3.0000253),
		"Default ray hits exact pinned edge")
	ray.collision_mask=7752
	check(state.intersect_ray(ray).is_empty(),"the same ray does not hit on actual Movable mask")
	check(boot.scene.route.graph.node_count()==649 		and not boot.scene.route.graph.contains_node(Vector4i(0,-5,11,0)),
		"authored stair stays outside the terrain navigation graph")
	var actor: Node=boot.scene.actor
	actor.request_move_position(FROM)
	for i in 4: await physics_frame
	if not check(actor.get_movement_position().is_equal_approx(FROM),"explicit fixture position before real input"):
		finish(); return
	var contacts:=[]
	boot.player.collision_reported.connect(func(other): contacts.append(other))
	key(KEY_TAB,true)
	key(KEY_TAB,false)
	await process_frame
	key(KEY_D,true)
	var crossed:=false
	for i in 35:
		await physics_frame
		if actor.get_movement_position().x>TO.x:
			crossed=true
			break
	key(KEY_D,false)
	for i in 3: await physics_frame
	var final: Vector2=actor.get_movement_position()
	check(crossed and final.x>TO.x and final.x<TO.x+.65 and absf(final.y-FROM.y)<.1 and contacts.is_empty(),
		"real WASD crosses Default edge without altering gameplay collision signal or motion")
	finish()

func _source_position(pair: Array) -> Vector2:
	return Vector2(pair[0],-pair[1])
