extends RefCounted
## 锁定31629d5的单个20004/ALTimeline；无Cost/Cd、Owned/Blocked标签3003。
## 只承认该单技能、非重入更新；不是多技能 ECS、通用标签树或另一套输入门控。
const CODE := 20004
const ATTACKING := 3003
enum ActivationResult { SUCCESS, ALREADY_ACTIVE, TAG_REQUIREMENT }
signal activation_result(result: int)
signal cancelled
signal ended
var active := false
var pending_context: Variant
var activation_context: Variant
var activate_requested := false
var cancel_requested := false
var end_requested := false
var _fixed_attacking := false
var _temporary_sources: Dictionary={}
var _actor: WeakRef
var _timeline: RefCounted
var _processing := false
var _position_reader: Callable

func configure(actor: Node2D, timeline: RefCounted, position_reader: Callable = Callable()) -> bool:
	if _actor != null or not is_instance_valid(actor) or timeline == null: return false
	if (not position_reader.is_valid() and not actor.has_method("source_position")) or not timeline.has_method("play") or not timeline.has_method("stop"): return false
	_actor=weakref(actor);_timeline=timeline
	_position_reader=position_reader
	return true

## 3003 是唯一已接入标签；来源键对应原 BTemporaryTag.source，不因他源移除而丢失。
func set_fixed_attacking(value: bool) -> void: _fixed_attacking=value
func add_temporary_attacking(source: int) -> void: _temporary_sources[source]=true
func remove_temporary_attacking(source: int) -> void: _temporary_sources.erase(source)
func has_attacking_tag() -> bool: return _fixed_attacking or not _temporary_sources.is_empty()
func owns_attacking_tag() -> bool: return _temporary_sources.has(get_instance_id())
func check_activation() -> int:
	if active: return ActivationResult.ALREADY_ACTIVE
	if has_attacking_tag(): return ActivationResult.TAG_REQUIREMENT
	# 作者数据没有消耗或冷却组件；不发明本地mana/CD。
	return ActivationResult.SUCCESS
func validate_fire_point(code: int) -> Dictionary:
	if code != CODE or _actor == null or not is_instance_valid(_actor.get_ref()): return {"available":false,"result":4}
	return {"available":true,"result":0 if check_activation()==ActivationResult.SUCCESS else 3}
func commit_rule_use(code: int) -> Dictionary:
	# generated binding 不在项目端支付；仍独立重查，不能缓存起手结果。
	return validate_fire_point(code)
func create_activation_context(pending: Variant) -> Variant:
	var actor: Object=_actor.get_ref() if _actor != null else null
	if not is_instance_valid(actor): return null
	if pending != null: return pending
	var p: Vector2=_position_reader.call() if _position_reader.is_valid() else actor.source_position()
	return preload("res://game_core/interaction/ability_activation_context.gd").new(Vector3(p.x,p.y,0))
func request_begin(code: int, context: Variant) -> bool:
	if code != CODE or _timeline == null or _actor == null or not is_instance_valid(_actor.get_ref()): return false
	pending_context=context
	activate_requested=true
	return true
func request_cancel(code: int) -> void:
	if code==CODE: cancel_requested=true
func request_end(code: int) -> void:
	if code==CODE: end_requested=true
func get_ability_debug_name() -> String: return "蓄力释放技能"
func report_error(message: String) -> void: push_error(message)

## 显式的后续 GAS 更新边界，不强制等一个墙钟帧。回调限于观察，不支持重入/新增请求。
## 激活结果通知发生在逻辑调用之后、active/请求标记的结构变更提交之前。
func process_update() -> void:
	if _processing:
		push_error("单技能 GAS 更新不支持重入。")
		return
	_processing=true
	if activate_requested:
		var result:=check_activation()
		if result==ActivationResult.SUCCESS:
			add_temporary_attacking(get_instance_id())
			activation_context=pending_context
			pending_context=null
			_timeline.play()
		else:
			pending_context=null # 拒绝只丢pending，不擦除先前已激活上下文。
		activation_result.emit(result)
		if result==ActivationResult.SUCCESS: active=true
		activate_requested=false
	if cancel_requested:
		if active:
			remove_temporary_attacking(get_instance_id())
			_timeline.stop()
			pending_context=null;activation_context=null
			cancelled.emit()
			active=false
		cancel_requested=false
	if end_requested:
		if active:
			remove_temporary_attacking(get_instance_id())
			_timeline.stop()
			pending_context=null;activation_context=null
			ended.emit()
			active=false
		end_requested=false
	_processing=false
