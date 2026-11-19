extends Node
## 原树 SpriteRenderer 的独立捕获画布；以已实测的源叠加保留预乘 RGB 和 alpha。
## 仅捕获原 Tree 和实际主角本体，不复制影子、假人或其他主场景节点。
const Math = preload("res://gameplay/clickmovetest/water_reflection_capture_math.gd")
const Composite = preload("res://gameplay/clickmovetest/water_reflection_composite.gdshader")
const MASK_SHA256 := "e3aafd4401d1b85b9013f61f6c9fe5cb5c5296b38160ada565ba3f381504dbf9"

var _color_target: SubViewport
var _material: ShaderMaterial
var _elapsed := 0.0
const TREE_ANCHOR := Vector2(-.4375,9.75)
var _tree: WeakRef
var _tree_proxy: Sprite2D
var _tree_quality := Vector2.ZERO
var _player: WeakRef
var _player_proxy: Sprite2D
var _player_material: ShaderMaterial
var _player_uniforms: Array[StringName] = []
var _player_quality := Vector2.ZERO
var _player_swimming := false

func configure(mask_path: String) -> bool:
	if _material != null or not FileAccess.file_exists(mask_path) \
			or FileAccess.get_sha256(mask_path) != MASK_SHA256:
		return false
	var mask := Image.load_from_file(mask_path)
	if mask == null or mask.get_size() != Vector2i(552,176): return false
	_color_target = _new_target()
	_material = ShaderMaterial.new()
	_material.shader = Composite
	_material.set_shader_parameter("water_mask", ImageTexture.create_from_image(mask))
	_material.set_shader_parameter("capture_color", _color_target.get_texture())
	return true

func _new_target() -> SubViewport:
	var target := SubViewport.new()
	target.world_2d = World2D.new()
	target.size = Vector2i(64,64)
	target.transparent_bg = true
	target.disable_3d = true
	target.gui_disable_input = true
	target.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(target)
	return target

func water_material() -> ShaderMaterial:
	return _material

func synchronize_main_projection(world_to_capture_uv: Transform2D, camera_pixels: Vector2i,
		scaled_delta: float) -> void:
	var size := Math.capture_size(camera_pixels)
	var px := Vector2(size)
	var scale_to_size := Transform2D(Vector2(px.x,0),Vector2(0,px.y),Vector2.ZERO)
	if _color_target.size != size: _color_target.size = size
	_color_target.canvas_transform = scale_to_size * world_to_capture_uv
	_material.set_shader_parameter("world_to_capture_u", Vector3(world_to_capture_uv.x.x,
		world_to_capture_uv.y.x,world_to_capture_uv.origin.x))
	_material.set_shader_parameter("world_to_capture_v", Vector3(world_to_capture_uv.x.y,
		world_to_capture_uv.y.y,world_to_capture_uv.origin.y))
	_elapsed += scaled_delta
	_material.set_shader_parameter("unity_elapsed", _elapsed)


func bind_tree(source: Sprite2D) -> bool:
	if _color_target==null or _tree!=null or source==null or not source.is_inside_tree() or source.texture==null: return false
	_tree = weakref(source)
	_tree_proxy = Sprite2D.new()
	_tree_proxy.name = "原树捕获代理"
	_tree_proxy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tree_proxy.hide()
	_color_target.add_child(_tree_proxy)
	return true

func synchronize_tree(water_bounds: Rect2, world_to_pixel: Transform2D, logical_pixels: Vector2,
		camera_pixels: Vector2i, camera_center: Vector2, delta: float) -> void:
	if _tree==null or logical_pixels.x<=0 or logical_pixels.y<=0 or camera_pixels.x<=0 or camera_pixels.y<=0: return
	synchronize_main_projection(Math.normalized_projection(world_to_pixel,logical_pixels),camera_pixels,delta)
	var source: Sprite2D = _tree.get_ref()
	_tree_quality = Vector2.ZERO
	if is_instance_valid(source) and source.is_visible_in_tree() and water_bounds.has_area():
		var world_bounds := source.global_transform * source.get_rect()
		var camera_bounds := world_to_pixel.affine_inverse() * Rect2(Vector2.ZERO,logical_pixels)
		_tree_quality = Math.quality(Math.reflection_bounds(world_bounds,TREE_ANCHOR),
			water_bounds,camera_bounds,camera_center,TREE_ANCHOR)
	_tree_proxy.visible = _tree_quality.x>.001
	if _tree_proxy.visible:
		_sync_sprite(_tree_proxy,source,TREE_ANCHOR,_tree_quality)
	if _player!=null:
		_synchronize_player(water_bounds,world_to_pixel.affine_inverse()*Rect2(Vector2.ZERO,logical_pixels),camera_center)


func bind_player(view: Node2D) -> bool:
	if _color_target==null or _player!=null or not is_instance_valid(view) or not view.is_inside_tree() \
			or not view.has_method("reflection_ground_anchor") or view.reflection_ground_anchor()==null:
		return false
	var source: Sprite2D = view.sprite
	if not source.material is ShaderMaterial: return false
	_player = weakref(view)
	_player_proxy = Sprite2D.new()
	_player_proxy.name = "原主角本体捕获代理"
	_player_proxy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_proxy.hide()
	_player_material = source.material.duplicate()
	_player_proxy.material = _player_material
	for uniform in _player_material.shader.get_shader_uniform_list():
		_player_uniforms.append(StringName(uniform.name))
	_color_target.add_child(_player_proxy)
	return true


func set_player_swimming(swimming: bool) -> void:
	# 原已配置 m_disableWhileSwimming。尚未迁移的游泳资格不由水格推断。
	_player_swimming = swimming
	if swimming and is_instance_valid(_player_proxy): _player_proxy.hide()


func _synchronize_player(water_bounds: Rect2, camera_bounds: Rect2, camera_center: Vector2) -> void:
	_player_quality = Vector2.ZERO
	var view: Node2D = _player.get_ref()
	if not is_instance_valid(view) or _player_swimming:
		_player_proxy.hide()
		return
	var anchor: Variant = view.reflection_ground_anchor()
	var sprite: Sprite2D = view.sprite
	if anchor!=null and sprite.is_visible_in_tree() and water_bounds.has_area() \
			and sprite.material is ShaderMaterial and sprite.material.shader==_player_material.shader:
		var bounds := sprite.global_transform*sprite.get_rect()
		_player_quality=Math.quality(Math.reflection_bounds(bounds,anchor),water_bounds,camera_bounds,camera_center,anchor)
	_player_proxy.visible = _player_quality.x>.001
	if not _player_proxy.visible: return
	# 原捕获代理使用源渲染器同一个材质及属性块，但单独减其顶点 alpha。
	# Godot 保持主材质不变；同步实际动作贴图、换装参数和采样后更新。
	var material: ShaderMaterial = sprite.material
	for key in _player_uniforms:
		if key not in [&"final_tint_enabled",&"final_material_tint"]:
			_player_material.set_shader_parameter(key,material.get_shader_parameter(key))
	var uses_tint: bool = material.get_shader_parameter("final_tint_enabled")==true
	_player_material.set_shader_parameter("final_tint_enabled",true)
	_player_material.set_shader_parameter("final_material_tint",
		material.get_shader_parameter("final_material_tint") if uses_tint else Color.WHITE)
	_sync_sprite(_player_proxy,sprite,anchor,_player_quality)
	if not uses_tint: _player_proxy.self_modulate=Color(1,1,1,_player_quality.x)


func _sync_sprite(proxy: Sprite2D,source: Sprite2D,anchor: Vector2,quality: Vector2) -> void:
	proxy.texture = source.texture
	proxy.centered = source.centered
	proxy.offset = source.offset
	proxy.flip_h = source.flip_h
	proxy.flip_v = source.flip_v
	proxy.self_modulate = source.self_modulate * Color(1,1,1,quality.x)
	proxy.transform = Math.reflection_transform(anchor,quality.y) * source.global_transform
