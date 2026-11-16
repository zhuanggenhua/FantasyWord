extends RefCounted
## EquipmentUV 第二、三步之间的武器填充合成合同；不是采样器或描边器。
## 输入人物 coverage 必须是身体/头部合成后的 charAlpha，而不是底图 alpha。
const CUTOFF := 0.5
const SRC_WEAPON0 := 7
const SRC_WEAPON1 := 8
const SRC_BAG := 10

static func compose(character: Dictionary, parts: Dictionary, weapon0: Dictionary,
		weapon1: Dictionary, body_in_front: float, enable_bag: float,
		sample_bag: Callable) -> Dictionary:
	assert(character.has("color") and character.has("coverage") and character.has("source_id"),
		"武器填充缺少人物颜色、独立覆盖或来源")
	_validate_slot(weapon0)
	_validate_slot(weapon1)
	var char_alpha: float = character.coverage
	var result := {"color":character.color,"coverage":char_alpha,"source_id":character.source_id}
	# 后景是主手先写、副手后写；遮挡始终检查原人物覆盖，不检查刚写入的武器。
	_rear(result,weapon0,SRC_WEAPON0,char_alpha)
	_rear(result,weapon1,SRC_WEAPON1,char_alpha)
	var hand := bool(parts.get(&"left_hand",false)) or bool(parts.get(&"right_hand",false))
	# 前景顺序相反；原实现没有脚遮挡谓词，不把注释里的脚规则补成新效果。
	_front(result,weapon1,SRC_WEAPON1,hand)
	_front(result,weapon0,SRC_WEAPON0,hand)
	# 此处只复现第二次北向背包采样；没有额外部位、UV alpha、人物覆盖门槛。
	# 调用方提供当前 bodyUV.rg 对应的原始 texel，包含实际纹理 alpha。
	if body_in_front > CUTOFF and enable_bag > CUTOFF:
		assert(sample_bag.is_valid(),"北向背包填充缺少当前身体 UV 的采样入口")
		var bag: Color = sample_bag.call()
		if bag.a > CUTOFF:
			_write_rgb(result,bag,SRC_BAG)
			result.coverage = maxf(result.coverage,1.0)
	var color: Color = result.color
	color.a = result.coverage
	result.color = color
	return result

static func _validate_slot(slot: Dictionary) -> void:
	assert(slot.has("sampled") and slot.has("color") and slot.has("depth_mode") and slot.has("hand_in_front"),
		"武器槽缺少采样成功标记、颜色、深度或手部遮挡配置")
	# sampled 是 TrySampleWeapon 成功结果，已经包含启用、坐标范围与 alpha 门槛。
	assert(not slot.sampled or slot.color.a > CUTOFF,"成功的武器采样必须超过 alpha 截止值")

static func _rear(result: Dictionary, slot: Dictionary, source: int, char_alpha: float) -> void:
	if slot.sampled and slot.depth_mode < CUTOFF:
		if char_alpha <= CUTOFF:
			_write_rgb(result,slot.color,source)
		# 被人物遮住的后景武器仍贡献覆盖；不得移进上面的 RGB 分支。
		result.coverage = maxf(result.coverage,slot.color.a)

static func _front(result: Dictionary, slot: Dictionary, source: int, hand: bool) -> void:
	if slot.sampled and slot.depth_mode > CUTOFF:
		if not (hand and slot.hand_in_front > CUTOFF):
			_write_rgb(result,slot.color,source)
			result.coverage = maxf(result.coverage,slot.color.a)

static func _write_rgb(result: Dictionary, color: Color, source: int) -> void:
	result.color = Color(color.r,color.g,color.b,result.color.a)
	result.source_id = source
