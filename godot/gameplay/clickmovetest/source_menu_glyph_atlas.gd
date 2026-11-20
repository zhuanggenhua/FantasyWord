extends RefCounted
## 原 RPGSystem 的唯一字形来源是私有 TMP Alpha8；无 TTF 替代。
## 此层只提供字形基线几何、字距和材质，不承担 TMP 文本框换行、对齐或大小写规则。
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
const HASH := "b0468b35c8ea552ce88c7a496c12ef0d5d4914efff5f19f5ea6c9c01f7514c7e"
const ATLAS_EDGE := 1024
const SHADER := preload("res://gameplay/clickmovetest/source_menu_distance_field.gdshader")
var texture: ImageTexture
var _letters: Dictionary
var _glyphs: Dictionary
var _face: Dictionary
var _material: Dictionary

func bind(data: Dictionary, alpha_path: String) -> bool:
	if texture != null or data.get("source_commit") != SOURCE or data.get("schema") != 1 \
			or data.get("font_alpha_sha256") != HASH or not FileAccess.file_exists(alpha_path) \
			or FileAccess.get_sha256(alpha_path) != HASH:
		return false
	var face: Variant = data.get("font_face")
	var style: Variant = data.get("font_material")
	var characters: Variant = data.get("font_letters")
	var glyphs: Variant = data.get("font_glyphs")
	if not face is Dictionary or face.get("m_FamilyName") != "RPGSystem" \
			or not _has_finite_fields(face,["m_PointSize","m_Scale","m_AscentLine","m_DescentLine"]) \
			or face.m_PointSize <= 0 or face.m_Scale <= 0 \
			or not style is Dictionary or not _has_finite_fields(style,["gradient","normal_weight","bold_weight","scale_ratio","atlas_padding"]) \
			or style.gradient <= 0 or style.atlas_padding != floorf(style.atlas_padding) or style.atlas_padding < 0 \
			or not characters is Dictionary or characters.is_empty() or not glyphs is Array or glyphs.is_empty():
		return false
	var index: Dictionary = {}
	for row in glyphs:
		if not row is Dictionary or row.get("m_AtlasIndex") != 0 \
				or not _has_finite_fields(row,["m_Index","m_Scale"]) or row.m_Index != floorf(row.m_Index) or row.m_Scale <= 0:
			return false
		var dims: Variant = row.get("m_GlyphRect")
		var metrics: Variant = row.get("m_Metrics")
		if not _has_finite_fields(dims,["m_X","m_Y","m_Width","m_Height"]) \
				or not _has_finite_fields(metrics,["m_Width","m_Height","m_HorizontalBearingX","m_HorizontalBearingY","m_HorizontalAdvance"]):
			return false
		if index.has(int(row.m_Index)) or dims.m_Width < 0 or dims.m_Height < 0:
			return false
		var pixels := Rect2(dims.m_X,dims.m_Y,dims.m_Width,dims.m_Height)
		if pixels.has_area() and not Rect2(0,0,ATLAS_EDGE,ATLAS_EDGE).encloses(pixels.grow(style.atlas_padding)):
			return false
		index[int(row.m_Index)] = {"pixels":pixels,"metrics":metrics.duplicate(),"scale":float(row.m_Scale)}
	for value in characters.values():
		if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(value) or value != floorf(value) \
				or not index.has(int(value)):
			return false
	var raw := FileAccess.get_file_as_bytes(alpha_path)
	if raw.size() != ATLAS_EDGE * ATLAS_EDGE: return false
	# Unity 的 Texture2D 数据第一行为底行，Godot 第一行为顶行。
	var flipped := PackedByteArray()
	for y in range(ATLAS_EDGE - 1, -1, -1):
		flipped.append_array(raw.slice(y * ATLAS_EDGE, (y+1) * ATLAS_EDGE))
	var image := Image.create_from_data(ATLAS_EDGE,ATLAS_EDGE,false,Image.FORMAT_R8,flipped)
	if image == null or image.is_empty(): return false
	texture = ImageTexture.create_from_image(image)
	if texture == null: return false
	_face = face.duplicate()
	_material = style.duplicate()
	_letters = characters.duplicate()
	_glyphs = index
	return true

func glyph(code: int, size_points: float, baseline: Vector2) -> Dictionary:
	return _glyph_quad(code,size_points,baseline,float(_material.get("atlas_padding",0)),0.0)

## TMP 2.0 UGUI face-only materials: mesh pad is 1.25, not the SDF allocation pad.
## Synthetic bold expands geometry horizontally, but expands the UV box on both axes.
func layout_glyph(code: int, size_points: float, baseline: Vector2, bold: bool) -> Dictionary:
	if texture == null: return {}
	var style := float(_material.bold_weight) * 0.25 * float(_material.gradient) * float(_material.scale_ratio) if bold else 0.0
	return _glyph_quad(code,size_points,baseline,1.25,style)

func top_baseline(top_y: float, glyph_scale: float) -> float:
	return top_y + float(_face.m_AscentLine)*glyph_scale

func middle_baseline(center_y: float, glyph_scale: float) -> float:
	return center_y + (float(_face.m_AscentLine)+float(_face.m_DescentLine))*glyph_scale/2.0

func _glyph_quad(code: int, size_points: float, baseline: Vector2, pad: float, style: float) -> Dictionary:
	if texture == null or not is_finite(size_points) or size_points <= 0.0 or not baseline.is_finite(): return {}
	var index: Variant = _letters.get(str(code))
	if index == null: return {}
	var row: Dictionary = _glyphs[int(index)]
	var scale := size_points / float(_face.m_PointSize) * float(_face.m_Scale) * float(row.scale)
	var m: Dictionary = row.metrics
	var pixels: Rect2 = row.pixels
	var result := {"advance":float(m.m_HorizontalAdvance) * scale, "glyph_scale":scale, "destination":Rect2(), "region":Rect2()}
	if pixels.has_area():
		result.destination = Rect2(baseline+Vector2(m.m_HorizontalBearingX-pad-style,-m.m_HorizontalBearingY-pad)*scale,
			Vector2(m.m_Width+2.0*(pad+style),m.m_Height+2.0*pad)*scale)
		var top_down := Rect2(pixels.position.x, ATLAS_EDGE-pixels.end.y,pixels.size.x,pixels.size.y)
		result.region = top_down.grow(pad+style)
	return result

## 正交、等比画布的实际屏幕像素 / 字体单位，由调用者随画布尺寸更新。
## 不从字形 UV 倒推比例：如 L 的字形几何宽 29，但原图集区域仅 28。
func face_material(bold: bool, pixels_per_font_unit: float) -> ShaderMaterial:
	if texture == null or not is_finite(pixels_per_font_unit) or pixels_per_font_unit <= 0.0: return null
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("screen_distance_scale",sqrt(2.0) * float(_material.gradient) * pixels_per_font_unit)
	var weight: float = _material.bold_weight if bold else _material.normal_weight
	mat.set_shader_parameter("face_weight",weight * float(_material.scale_ratio) / 8.0)
	return mat

static func _has_finite_fields(data: Variant, keys: Array) -> bool:
	if not data is Dictionary: return false
	for key in keys:
		var value: Variant = data.get(key)
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(value): return false
	return true
