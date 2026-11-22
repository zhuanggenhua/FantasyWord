extends RefCounted
## ClickMoveTest 原静态 Default 几何；不改变 Movable 7752 查询或模拟接触回调。
const FILE_SHA := "b250e16bc4d5289ed36a6d5d4eb503e0834b82b82db8142130419cf89552ec3b"

static func build(path: String) -> Node2D:
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=FILE_SHA: return null
	var payload: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	var geometry:=Node2D.new()
	geometry.name="SourceStaticGeometry"
	for row: Dictionary in payload.bodies:
		var body:=StaticBody2D.new()
		body.name="SourceCollider%d"%int(row.source_file_id)
		body.position=_position(row.origin)
		body.collision_layer=1 # Unity Default (层索引 0)
		body.collision_mask=0
		body.set_meta("source_file_id",int(row.source_file_id))
		var node:=CollisionShape2D.new()
		node.shape=_shape(row)
		body.add_child(node)
		geometry.add_child(body)
	return geometry

static func _position(pair: Array) -> Vector2:
	return Vector2(float(pair[0]),-float(pair[1]))

static func _shape(row: Dictionary) -> Shape2D:
	if row.kind=="box":
		var box:=RectangleShape2D.new()
		box.size=Vector2(float(row.size[0]),float(row.size[1]))
		return box
	# 散列锁定的另一种类型是 Composite Outlines，保留每条闭环。
	var segments:=PackedVector2Array()
	for loop: Array in row.paths:
		for i in loop.size():
			segments.append(_position(loop[i]))
			segments.append(_position(loop[(i+1)%loop.size()]))
	var outline:=ConcavePolygonShape2D.new()
	outline.segments=segments
	return outline
