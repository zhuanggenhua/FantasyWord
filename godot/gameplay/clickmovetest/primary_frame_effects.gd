extends RefCounted
## Locked primary human EquipmentRenderer + EquipmentUV. Private authored inputs;
## selects frame data by the actual Sprite.rect, not resolver label or actor facing.
const Subset := preload("res://gameplay/presentation/equipment_subset_material.gd")
const Shadow := preload("res://gameplay/presentation/equipment_shadow_coverage.gd")
const CONTRACT_SHA := "cd8f7c39003d5e6377c3bd83115ca26938811b74a2c9f5f3b1371fb61ad0cd79"
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
var _frames := {}
var _atlas_sizes := {}
var _ground_y := 0
# The first actual Idle sample initializes all fields just as Unity does.
var _shadow := {}

func load_source(path: String) -> bool:
	if not _frames.is_empty() or FileAccess.get_sha256(path) != CONTRACT_SHA:
		return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data.source != SOURCE:
		return false
	_ground_y = int(data.ground_pixel_y)
	for action: String in data.actions:
		var spec: Dictionary = data.actions[action]
		var frames := {}
		for row: Array in spec.frames:
			frames[Vector2i(int(row[0]),int(row[1]))] = {
				"writes":Shadow.height_writes(row[2],row[3],_ground_y), "hit":float(row[4])}
		_frames[action] = frames
		_atlas_sizes[action] = Vector2(spec.size[0],spec.size[1])
	return true

func apply(material: ShaderMaterial, action: String, sample: AtlasTexture,
		frame_rect: Rect2, slot_flags: Array) -> Dictionary:
	var size := Vector2(32,32)
	var row: Dictionary = _frames.get(action,{}).get(Vector2i(sample.region.position/size),{})
	if row.is_empty() or sample.region.size != size or sample.atlas.get_size() != _atlas_sizes.get(action):
		return {"ok":false, "reason":"实际精灵无可核实的正式轮廓/阴影帧。"}
	# The original missing-feet branch only writes mode=-1; it neither clears
	# the other uniforms nor bypasses the shader's <.5 caster branch.
	var next := Shadow.apply_writes(_shadow,row.writes)
	if not next.has("base_y"):
		return {"ok":false, "reason":"正式轮廓/阴影缺少先前原始尺寸和基线。"}
	var result := Subset.apply_outline(material,frame_rect,size,next.base_y,slot_flags,
		Vector3(1.0,row.hit,0.0),Color(0.7059,0.0353,0.0353,1.0),Color.WHITE)
	if not result.ok:
		return result
	result = Subset.apply_shadow(material,frame_rect,next,1.0,Color(0,0,0,0.6))
	if result.ok: _shadow = next
	return result
