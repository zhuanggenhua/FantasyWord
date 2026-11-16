extends RefCounted
## 仅迁移原肤色参数绑定与颜色域内的查表。不是纹理导入或 framebuffer 证明。
const MAX_COLORS := 16
const SRC_MAIN := 1
const EPSILON := 1.0 / 255.0

# source/target 是作者 sRGB 颜色数组；空或 null 关闭，不继承先前绑定。
# 归一化颜色以外尚未验证，明确拒绝，不偷偷截断或猜测 HDR 转换。
static func bind_palette(source: Variant, target: Variant, linear: bool) -> Dictionary:
	var result := {"ok":true,"enabled":false,"count":0,
		"source":PackedColorArray(),"target":PackedColorArray(),"linear":linear}
	if source == null or target == null:
		return result
	if not (source is Array or source is PackedColorArray) or not (target is Array or target is PackedColorArray):
		return {"ok":false,"error":"肤色配置必须是作者颜色数组"}
	var count := mini(MAX_COLORS, mini(source.size(), target.size()))
	if count <= 0:
		return result
	var sources := PackedColorArray()
	var targets := PackedColorArray()
	sources.resize(MAX_COLORS)
	targets.resize(MAX_COLORS)
	for index in count:
		for color in [source[index],target[index]]:
			if not color is Color or not _normalized(color):
				return {"ok":false,"error":"仅支持已验证的有限归一化作者颜色"}
		sources[index] = source[index].srgb_to_linear() if linear else source[index]
		targets[index] = target[index].srgb_to_linear() if linear else target[index]
	result.enabled = true
	result.count = count
	result.source = sources
	result.target = targets
	return result

static func _normalized(color: Color) -> bool:
	for component in [color.r,color.g,color.b,color.a]:
		if not is_finite(component) or component < 0.0 or component > 1.0:
			return false
	return true

## char_color 是同一颜色域中的“本体合成后但独立覆盖率写入前”的 RGBA。
## 来源由身体/头部合成 owner 提供，不由 RGB 或最终 alpha 猜测。
static func apply(char_color: Color, source_id: int, palette: Dictionary) -> Color:
	if not palette.get("ok",false) or not palette.get("enabled",false) or source_id != SRC_MAIN or char_color.a <= 0.5:
		return char_color
	var gray := char_color.r * 0.299 + char_color.g * 0.587 + char_color.b * 0.114
	if gray <= 0.15:
		return char_color
	var count := clampi(int(palette.count),0,MAX_COLORS)
	for index in count:
		var src: Color = palette.source[index]
		if absf(char_color.r-src.r) < EPSILON and absf(char_color.g-src.g) < EPSILON and absf(char_color.b-src.b) < EPSILON:
			var dst: Color = palette.target[index]
			return Color(dst.r,dst.g,dst.b,char_color.a)
	return char_color
