extends RefCounted
## 2004 无持续时间效果的阶段接线：技能只投递，效果阶段按请求顺序消费。
## 这不是通用 EX-GAS 调度器；原 2004 无申请标签、免疫标签、堆叠与长期状态。
var _pending: Array[Dictionary] = []
var _sequence := 0
var _running := false

func request(caster: Node2D, receiver: Node2D, damage: Callable) -> bool:
	if not is_instance_valid(caster) or not is_instance_valid(receiver) or caster==receiver or not damage.is_valid():
		return false
	_sequence += 1
	_pending.append({"caster":weakref(caster), "receiver":weakref(receiver), "serial":_sequence, "damage":damage})
	return true

func run_effects(queue_apply_cue: Callable) -> int:
	if _running: return 0
	_running = true
	# 回调阶段新增的请求下次更新消费，不能在当前同一个序列重入。
	var applying := _pending
	_pending = []
	var count := 0
	for entry in applying:
		var caster: Node2D = entry.caster.get_ref()
		var target: Node2D = entry.receiver.get_ref()
		if not is_instance_valid(caster) or not is_instance_valid(target) or not target.is_inside_tree():
			continue
		if queue_apply_cue.is_valid(): queue_apply_cue.call(target,entry.serial)
		if is_instance_valid(caster) and is_instance_valid(target) and target.is_inside_tree() and entry.damage.is_valid():
			entry.damage.call(caster,target)
			count += 1
		# 瞬时效果在本次阶段后终止；显示请求的目标身份不依赖瞬时效果继续存活。
	_running = false
	return count

func clear() -> void:
	_pending.clear()
