extends RefCounted
## 仅承载本场景原训练假人及玩家均为空反馈槽的 20001：目标侧 HitDamageable。
## 不是 Dmg 动画，不生成粒子、音效或替代资源；完整反馈资产运行器尚未迁移。
## 来源：31629d53 的 CuePlayGameCoreFeedback / SCueStart / 训练假人配置。

const CUE_ID := 20001
const FEEDBACK_KIND := 6
const TARGET_SIDE := 0

## 原独立 Cue 实体在即时效果销毁后仍存在；Display 只对待激活实例执行一次。
var _instances: Dictionary = {}
var activation_count := 0
var missing_slot_count := 0
var last_activation: Dictionary = {}

func request(target: Node2D, source_effect_identity: int) -> bool:
	if not is_instance_valid(target) or source_effect_identity <= 0:
		return false
	# Play(true) 将原 Cue 的 playing 清为 false，Display 前重放只保留最后一次绑定。
	_instances[source_effect_identity] = {"target":weakref(target), "pending":true,
		"playing":false}
	return true

func flush_display() -> int:
	var activated := 0
	for effect_identity in _instances:
		var instance: Dictionary = _instances[effect_identity]
		if not instance.pending:
			continue
		instance.pending = false
		instance.playing = true
		# 与目标侧 ResolveCharacter 一致，不依赖已经销毁的来源效果。
		var target = instance.target.get_ref()
		if not is_instance_valid(target):
			continue
		activation_count += 1
		activated += 1
		last_activation = {"cue_id":CUE_ID,"kind":FEEDBACK_KIND,"target_side":TARGET_SIDE,
			"source_effect_identity":effect_identity,"position":target.global_position,
			"feedback_slot_configured":false}
		# 原空槽无播放；独立计数记录源开发诊断，不把作者缺省当引擎故障。
		missing_slot_count += 1
	return activated

func is_playing(source_effect_identity: int) -> bool:
	return _instances.has(source_effect_identity) and _instances[source_effect_identity].playing

func dispose() -> void:
	# 场景 owner 退出后释放；不能将即时效果销毁误当成停止此 Cue。
	_instances.clear()
