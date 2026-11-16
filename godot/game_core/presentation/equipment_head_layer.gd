extends RefCounted
## 锁定 Unity 31629d5 EquipmentUV.ApplyHeadLayers；仅 CPU 判据，非渲染入口。
const SRC_NONE := 0
const SRC_HELMET := 3
const SRC_FACE := 4
const SRC_BEARD := 5
const SRC_HAIR := 6
const SRC_MASK := 11
const CUTOFF := 0.5

# Caller samples each enabled layer at the already resolved authored UV.
# Return the source RGB write (preserves incoming alpha), its source ID, and
# independent layer coverage; do not blend this layer as partial opacity.
static func apply(base: Color, head_id: bool, hand_id: bool, enabled: Dictionary,
		sample: Callable) -> Dictionary:
	var result := {"color":base,"source_id":SRC_NONE,"layer_alpha":0.0}
	if not head_id or hand_id:
		return result
	if _try_write(result, &"helmet", SRC_HELMET, enabled, sample):
		return result
	if not _try_write(result, &"beard", SRC_BEARD, enabled, sample):
		if not _try_write(result, &"face_accessory", SRC_FACE, enabled, sample):
			_try_write(result, &"hair", SRC_HAIR, enabled, sample)
	_try_write(result, &"eye_decoration", SRC_FACE, enabled, sample)
	_try_write(result, &"mask", SRC_MASK, enabled, sample)
	return result

static func _try_write(result: Dictionary, key: StringName, source: int,
		enabled: Dictionary, sample: Callable) -> bool:
	if not bool(enabled.get(key,false)):
		return false
	var texel: Color = sample.call(key)
	if texel.a <= CUTOFF:
		return false
	result.color = Color(texel.r,texel.g,texel.b,result.color.a)
	result.source_id = source
	result.layer_alpha = 1.0
	return true
