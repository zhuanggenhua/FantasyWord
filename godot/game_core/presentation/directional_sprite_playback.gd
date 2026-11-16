extends Node
## 四向精灵库切换和共享动作采样；动作状态与恢复计时仍由动作驱动拥有。
## 注入的是已核实的标签序列，不在运行时猜测图集行列、补帧或加载原素材。
const Directions = preload("res://game_core/presentation/character_animation_directions.gd")

signal sample_resolved(action: String, label: int, direction: int, texture: Texture2D)
signal direction_applied(direction: int)

var sprite: Sprite2D
var animator: AnimationPlayer
var current_direction := 0
var current_action := ""
var current_label := -1
var last_error := ""
var _actions: Dictionary = {}
var _samples: Dictionary = {}
var sample_id := "":
	set(value):
		sample_id = value
		if _samples.has(value):
			current_action = _samples[value].action
			current_label = _samples[value].label
			_resolve_sample()

func configure(target: Sprite2D, player: AnimationPlayer, actions: Dictionary) -> bool:
	last_error = ""
	if not is_instance_valid(target) or not is_instance_valid(player):
		return _fail("缺少显式绑定的 Sprite2D 或 AnimationPlayer。")
	if not is_inside_tree() or not player.is_inside_tree():
		return _fail("播放节点和 AnimationPlayer 必须先进入同一场景树。")
	if not _actions.is_empty() or not player.get_animation_library_list().is_empty():
		return _fail("播放入口已配置，不能覆盖已有动画库。")
	if actions.is_empty():
		return _fail("缺少动作资源清单。")
	# 先验证完整资源，避免部分写入动画库后才发现另一个方向缺失。
	for action in actions:
		if not action is String or action.is_empty() or action.contains("/") or action.contains(":") or action.contains(",") or action.contains("["):
			return _fail("动作名称不是有效的 AnimationLibrary 动画名。")
		if not actions[action] is Dictionary:
			return _fail("每个动作必须提供资源字典。")
		var data: Dictionary = actions[action]
		if not data.has_all(["duration","loop","times","labels","directions"]):
			return _fail("动作资源清单缺少时长、循环、关键帧或四向纹理。")
		if typeof(data.duration) not in [TYPE_INT,TYPE_FLOAT] or not data.loop is bool:
			return _fail("动作时长必须为数值，循环标记必须为布尔值。")
		if not data.times is Array or not data.labels is Array or not data.directions is Array:
			return _fail("关键帧、标签和四向库必须为数组。")
		var duration := float(data.duration)
		if not is_finite(duration) or duration <= 0.0 or data.times.is_empty() or data.times.size() != data.labels.size():
			return _fail("动作时长或关键帧数量无效。")
		if data.directions.size() != 4:
			return _fail("动作必须提供完整 SE/SW/NE/NW 四向纹理。")
		for direction in data.directions:
			if not direction is Array:
				return _fail("每个方向必须为按标签排列的纹理数组。")
		var previous := -1.0
		for i in data.times.size():
			if typeof(data.times[i]) not in [TYPE_INT,TYPE_FLOAT] or not data.labels[i] is int:
				return _fail("关键帧时间必须为数值，标签必须为整数。")
			var time := float(data.times[i])
			var label: int = data.labels[i]
			if not is_finite(time) or time < 0.0 or time > duration or time <= previous or (i == 0 and time != 0.0):
				return _fail("动作关键帧必须从零开始严格递增且不超过时长。")
			previous = time
			for direction in data.directions:
				if label < 0 or label >= direction.size() or not direction[label] is Texture2D:
					return _fail("动作标签在至少一个方向缺少纹理。")
	var library := AnimationLibrary.new()
	var sequence := 0
	var samples: Dictionary = {}
	for action: String in actions:
		var data: Dictionary = actions[action]
		var animation := Animation.new()
		animation.length = data.duration
		animation.loop_mode = Animation.LOOP_LINEAR if data.loop else Animation.LOOP_NONE
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track,NodePath(".:sample_id"))
		animation.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
		for i in data.times.size():
			var token := str(sequence) + ":" + str(i)
			samples[token] = {"action":action,"label":int(data.labels[i])}
			animation.track_insert_key(track,float(data.times[i]),token)
		if library.add_animation(action,animation) != OK:
			return _fail("无法建立动作动画资源。")
		sequence += 1
	if player.add_animation_library("",library) != OK:
		return _fail("无法向 AnimationPlayer 安装动作库。")
	sprite = target
	animator = player
	_samples = samples
	_actions = actions.duplicate(true)
	animator.root_node = animator.get_path_to(self)
	return true

func set_direction(index: int) -> bool:
	if index < 0 or index >= 4:
		return false
	if _actions.is_empty() or not is_instance_valid(sprite):
		return _fail("缺少已配置的四向纹理或目标 Sprite2D。")
	current_direction = index
	# 仅更换库并立即解析当前标签，不重播、seek 或改动动作驱动期限。
	_resolve_sample()
	direction_applied.emit(index)
	return true

func set_facing_direction(direction: Vector2) -> void:
	# 原驱动对近零向量直接返回，不重新解析精灵或通知换装渲染器。
	if Directions.has_facing(direction):
		set_direction(Directions.resolve_index(direction,current_direction))

func _resolve_sample() -> void:
	if current_action.is_empty() or current_label < 0 or not is_instance_valid(sprite):
		return
	var texture: Texture2D = _actions[current_action].directions[current_direction][current_label]
	sprite.texture = texture
	sample_resolved.emit(current_action,current_label,current_direction,texture)

func _fail(message: String) -> bool:
	last_error = message
	return false
