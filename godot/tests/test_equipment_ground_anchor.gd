extends SceneTree
const Geometry = preload("res://gameplay/presentation/equipment_frame_geometry.gd")
const Playback = preload("res://game_core/presentation/directional_sprite_playback.gd")
const Binder = preload("res://gameplay/presentation/equipment_subset_material.gd")
var checks := 0
var failures := 0
var reject := false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("verify")
func provide(_a: String,_l: int,_d: int,s: AtlasTexture) -> Dictionary:
	return {"ok":false} if reject else Binder.create(s.atlas,s.atlas,s.atlas,false,{},{},{})
func bounds_x(node: Polygon2D) -> float:
	var low := INF
	var high := -INF
	for v in node.polygon:
		var x: float = node.to_global(v).x
		low = minf(low,x); high = maxf(high,x)
	return (low+high)*0.5
func verify() -> void:
	var parent := Node2D.new()
	var body := Geometry.new()
	var playback := Playback.new()
	root.add_child(parent)
	parent.add_child(body); parent.add_child(playback)
	var tex := ImageTexture.create_from_image(Image.create(64,64,false,Image.FORMAT_RGBA8))
	var sample := AtlasTexture.new()
	sample.atlas=tex
	sample.region=Rect2(16,8,16,24)
	var shape := {"pivot_bottom":Vector2(3,9),"pixels_per_unit":4.0,"flip_h":false,"flip_v":false}
	check(body.configure(playback,{sample:shape},provide),"真实几何绑定")
	check(not body.query_ground_anchor(8,32,0).ok,"无采样不能求脚底")
	playback.sample_resolved.emit("Idle",0,0,sample)
	# 地面行 8：(1-8.5/32)*24 = 17.625，减轴点 9，除 PPU 4；
	# Godot Y 向下，所以局部 Y 为 -2.15625。边界 X 为 (8-3)/4=1.25。
	var p: Dictionary = body.query_ground_anchor(8,32,bounds_x(body))
	check(p.ok and p.position.is_equal_approx(Vector2(1.25,-2.15625)),"配置高不同于实际高，非中心轴点")
	check(p.position.x != body.global_position.x,"横坐标不是主体原点")
	check(body.query_ground_anchor(8,null,bounds_x(body)).position.is_equal_approx(Vector2(1.25,-1.625)),"无动作配置明确回退实际 Sprite 高")
	check(body.query_ground_anchor(-100,32,12.5).position.is_equal_approx(Vector2(12.5,-3.75)),"地面行低于零时夹到顶部")
	check(body.query_ground_anchor(100,32,-7.0).position.is_equal_approx(Vector2(-7.0,2.25)),"地面行超过配置高时夹到底部")
	for flip_h in [false,true]:
		for flip_v in [false,true]:
			shape.flip_h=flip_h; shape.flip_v=flip_v
			playback.sample_resolved.emit("Idle",0,0,sample)
			var x: float = -1.25 if flip_h else 1.25
			var y: float = 2.15625 if flip_v else -2.15625
			check(body.query_ground_anchor(8,32,bounds_x(body)).position.is_equal_approx(Vector2(x,y)),"双镜像有各自职责")
			for angle in [0.0,0.35,-0.9]:
				parent.position=Vector2(13,-7); parent.rotation=angle; parent.scale=Vector2(2,0.75)
				body.position=Vector2(-2,5); body.rotation=-0.2; body.scale=Vector2(0.6,1.7)
				var expected := body.to_global(Vector2(0,y))
				var supplied_x := bounds_x(body)
				p=body.query_ground_anchor(8,32,supplied_x)
				check(p.ok and p.position.is_equal_approx(Vector2(supplied_x,expected.y)),"实时父变换下纵坐标取局部 X=0")
				check(p.position.distance_to(body.to_global(Vector2(x,y)))>0.01,"不得把局部横向中心带入脚底纵坐标")
			parent.transform=Transform2D.IDENTITY; body.transform=Transform2D.IDENTITY
	# 查询本身不改变绘制、帧和材质。已核实 bounds 可以来自紧网格而不是完整 quad。
	var polygon_before: PackedVector2Array = body.polygon
	var material_before: Material = body.material
	p=body.query_ground_anchor(8,32,99.25)
	check(p.ok and p.position.x==99.25 and body.polygon==polygon_before and body.material==material_before,"显式 bounds 所有权与只读")
	for invalid in [null,8.5,"8"]:
		check(not body.query_ground_anchor(invalid,32,0).ok,"必须有帧数据里的整数地面行")
	for invalid in [0,-1,NAN,INF,"32",Vector2(32,32)]:
		check(not body.query_ground_anchor(8,invalid,0).ok,"非法配置高度拒绝")
	check(not body.query_ground_anchor(8,32,INF).ok,"非法 bounds 拒绝")
	reject=true
	playback.sample_resolved.emit("Idle",0,0,sample)
	check(body.polygon.is_empty() and body.material==null,"材质失败仍清画面")
	check(body.query_ground_anchor(8,32,99.25).ok,"材质失败不等于源 Sprite 不存在")
	# 配置元数据外部变化不冒充已经实际采样的几何。
	shape.flip_v=false
	check(is_equal_approx(body.query_ground_anchor(8,32,0).position.y,2.15625),"查询保留当前采样镜像")
	playback.sample_resolved.emit("Idle",0,0,sample)
	check(is_equal_approx(body.query_ground_anchor(8,32,0).position.y,-2.15625),"下一真实采样更新镜像，即使材质失败")
	reject=false
	playback.sample_resolved.emit("Idle",0,0,sample)
	check(body.query_ground_anchor(8,32,0).ok and not body.polygon.is_empty(),"恢复显示")
	playback.sample_resolved.emit("Idle",0,0,null)
	check(not body.query_ground_anchor(8,32,0).ok,"没有当前 Sprite 就不可复用旧脚底")
	playback.sample_resolved.emit("Idle",0,0,sample)
	sample.margin=Rect2(0,0,1,1)
	check(not body.query_ground_anchor(8,32,0).ok,"当前 Sprite 数据失效拒绝")
	sample.margin=Rect2()
	body.transform=Transform2D(Vector2(NAN,0),Vector2(0,1),Vector2.ZERO)
	check(not body.query_ground_anchor(8,32,0).ok,"坏变换拒绝")
	body.transform=Transform2D.IDENTITY
	parent.remove_child(body)
	check(not body.query_ground_anchor(8,32,0).ok,"没有世界节点拒绝")
	body.free(); parent.free()
	if failures==0: print("PASS equipment_ground_anchor ",checks," checks")
	quit(0 if failures==0 else 1)
