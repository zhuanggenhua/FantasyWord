extends RefCounted
## 锁定 Unity 31629d5 EquipmentUV 中基础人物本体、身体层与头部层的顺序。
## CPU 判据，不包含肤色、武器、地面阴影、描边或最终透明裁剪。
const Head = preload("res://game_core/presentation/equipment_head_layer.gd")
const SRC_MAIN := 1
const SRC_CLOAK := 2
const SRC_OTHER := 9
const SRC_BAG := 10
const CUTOFF := 0.5

static func compose(base: Color, parts: Dictionary, head_alpha: float, body_in_front: bool,
		enabled: Dictionary, colors: Dictionary, sample_body: Callable, sample_head: Callable) -> Dictionary:
	var hand := _flag(parts,&"left_hand") or _flag(parts,&"right_hand")
	var head_id := _flag(parts,&"head")
	var head_core := head_id and head_alpha > CUTOFF
	var head: Dictionary
	var body: Dictionary
	var final_color: Color
	if body_in_front:
		head = Head.apply(base,head_id,hand,enabled,sample_head)
		body = _body(head.color,base.a,parts,head_core,true,enabled,colors,sample_body)
		final_color = body.color
	else:
		body = _body(base,base.a,parts,head_core,false,enabled,colors,sample_body)
		head = Head.apply(body.color,head_id,hand,enabled,sample_head)
		final_color = head.color
	var top := body if body_in_front else head
	var lower := head if body_in_front else body
	var source: int = top.source_id if top.layer_alpha > CUTOFF else lower.source_id if lower.layer_alpha > CUTOFF else Head.SRC_NONE
	if source == Head.SRC_NONE and base.a > CUTOFF:
		source = SRC_MAIN
	var coverage := maxf(final_color.a,maxf(body.layer_alpha,head.layer_alpha))
	return {"color":final_color,"coverage":coverage,"source_id":source,"body_layer":body,"head_layer":head}

static func _body(prior: Color, base_alpha: float, parts: Dictionary, head_core: bool,
		front: bool, enabled: Dictionary, colors: Dictionary, sample: Callable) -> Dictionary:
	var result := {"color":prior,"layer_alpha":0.0,"source_id":Head.SRC_NONE}
	var hand := _flag(parts,&"left_hand") or _flag(parts,&"right_hand")
	var foot := _flag(parts,&"left_foot") or _flag(parts,&"right_foot")
	if _flag(parts,&"torso") or (front and (hand or foot)):
		if not front and head_core:
			return result
		if not front and base_alpha <= CUTOFF:
			_try_texture(result,&"bag",SRC_BAG,enabled,sample)
		_try_texture(result,&"pants",SRC_OTHER,enabled,sample)
		_try_texture(result,&"cloth",SRC_OTHER,enabled,sample)
		_try_texture(result,&"cloak",SRC_CLOAK,enabled,sample)
	elif hand and _flag(enabled,&"gloves"):
		_write(result,colors[&"left_hand" if _flag(parts,&"left_hand") else &"right_hand"],SRC_OTHER)
	elif foot and _flag(enabled,&"shoes"):
		_write(result,colors[&"left_foot" if _flag(parts,&"left_foot") else &"right_foot"],SRC_OTHER)
	elif _flag(parts,&"left_eye") and _flag(enabled,&"left_eye"):
		_write(result,colors[&"left_eye"],SRC_OTHER)
	elif _flag(parts,&"right_eye") and _flag(enabled,&"right_eye"):
		_write(result,colors[&"right_eye"],SRC_OTHER)
	return result

static func _try_texture(result: Dictionary, key: StringName, source: int,
		enabled: Dictionary, sample: Callable) -> void:
	if _flag(enabled,key):
		var texel: Color = sample.call(key)
		if texel.a > CUTOFF:
			_write(result,texel,source)

static func _write(result: Dictionary, color: Color, source: int) -> void:
	result.color = Color(color.r,color.g,color.b,result.color.a)
	result.source_id = source
	result.layer_alpha = 1.0

static func _flag(values: Dictionary, key: StringName) -> bool:
	return bool(values.get(key,false))
