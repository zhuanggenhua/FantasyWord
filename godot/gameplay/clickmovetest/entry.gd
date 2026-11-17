extends Node2D
## ClickMoveTest 的可注入启动切片。无正式素材、GAS 和系统宿主时不自行补依赖。
const PointerSelection = preload("res://game_core/ui/pointer_selection.gd")
const MousePoints = preload("res://game_core/input/mouse_point_actions.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Movement = preload("res://game_core/movement/character_movement.gd")
const Commands = preload("res://game_core/movement/movement_commands.gd")
const Keyboard = preload("res://game_core/movement/keyboard_movement_input.gd")
const Route = preload("res://game_core/navigation/terrain_world_route.gd")
const Binding = preload("res://game_core/presentation/player_camera_binding.gd")
const ScreenProjection = preload("res://game_core/presentation/orthographic_screen_projection.gd")
const Interaction = preload("res://game_core/interaction/character_button_activation.gd")
const Aim = preload("res://game_core/movement/idle_pointer_aim.gd")
const Step = preload("res://game_core/movement/source_fixed_step.gd")
const Observation = preload("res://gameplay/clickmovetest/click_observation.gd")
const TrainingTarget = preload("res://gameplay/clickmovetest/training_target.gd")
const TrainingAttributes = preload("res://gameplay/clickmovetest/training_damage_attributes.gd")
const ChargedHit = preload("res://gameplay/combat/charged_attack_hit.gd")
const TrainingHitCue = preload("res://gameplay/clickmovetest/training_hit_feedback_cue.gd")
const ChargedEffects = preload("res://gameplay/combat/charged_effect_application.gd")
const ChargedDamage = preload("res://gameplay/combat/charged_damage_effect.gd")
const DamagePush = preload("res://game_core/combat/damage_push_policy.gd")
# 锁定 GameConfig.asset 的原 Push 门禁；不是诊断的推力记录器。
const TRAINING_PUSH_FLAGS := {"regular":true, "critical":true, "missed":true, "silent":false}
const SOURCE := "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
@export var actor: AnimatableBody2D
@export var actor_shape: CollisionShape2D
@export var visual_body: Node2D
@export var camera: Camera2D
@export var aim_pivot: Node2D
var human_presentation: Node2D
var human_motion_binding: RefCounted
var movement: RefCounted
var route: RefCounted
var binding: RefCounted
var blocked := false
var command_count := 0
var last_result: Variant
var click_observation := Observation.new()
var keyboard := Keyboard.new()
var human_gameplay_actions: RefCounted
var _normalized_click_bound := false
var human_commands: RefCounted
var human_interaction: RefCounted
var _human_aim: RefCounted
var _aim_control: Object
var _aim_was_local := false
var _equipped_ability_dispatch: RefCounted
var _charged_actor_runtime: Node
var _charged_timeline: RefCounted
var training_hit_cue := TrainingHitCue.new()
var _training_effects := ChargedEffects.new()
var training_target: Node2D
var training_attributes: RefCounted
var _mouse_point_actions: RefCounted
var _pointer_selection: RefCounted
var _pointer_over_ui: Callable
var _ui_raycast: Callable
var last_ui_selection := "unbound"
var _ui_guard: Callable
var _player_provider: Callable

## 宿主明确选中的玩家、地图事件、动作能力与 UI 门禁均由调用者提供。
## 此阶段不宣称提供完整 PlayerSystem、GAS、地图加载或视觉资源。
func start_logic(owner: Object, data: Dictionary, player_provider: Callable,
		map_provider: Callable, map_events: Object, ui_guard: Callable) -> bool:
	if movement != null or not is_inside_tree() or not is_instance_valid(owner) \
			or not player_provider.is_valid() or not map_provider.is_valid() \
			or not is_instance_valid(map_events) or not ui_guard.is_valid():
		return false
	if not valid_rules(data) or not map_events.has_signal("map_loaded") \
			or not map_events.has_signal("map_unloaded"): return false
	var player: Object = player_provider.call()
	if not is_instance_valid(player) or not player.has_signal("controlled_character_changed") \
			or not player.has_method("get_current_controlled_character_or_player_instance") \
			or player.get_current_controlled_character_or_player_instance() != actor: return false
	for method in ["can_move", "calculate_move_speed", "calculate_speed_multiplier",
			"update_movement_animation", "update_facing_from_intent", "register_collision"]:
		if not owner.has_method(method): return false
	var candidate := Route.new(data.rows, int(data.nearest_radius),
		func(layer, world): return Vector3i(floori(world.x), floori(world.y), 0) if layer == 0 else null,
		func(cell): return Vector2(cell.y + 0.5, cell.z + 0.5))
	if candidate.graph.node_count() != 649: return false
	# 不将表现 Body 错接成运动主体，也不将场景静态相机姿态当运行期跟随目标。
	if not is_instance_valid(actor) or not is_instance_valid(actor_shape) \
			or not is_instance_valid(camera) or not is_instance_valid(visual_body): return false
	actor.configure_movement(actor_shape, Filter.new(Filter.Mode.FREE, false, 0.05, 10.0, 10.0), owner, 7752)
	route = candidate
	movement = Movement.new(actor, 0.05)
	movement.set_movement_control_mode(Movement.Mode.CLICK_TO_MOVE)
	_ui_guard = ui_guard
	_player_provider = player_provider
	binding = Binding.new(camera, null, player_provider, map_provider, map_events)
	binding.on_enable()
	binding.start_binding()
	camera.make_current()
	_resize_camera()
	camera.advance_follow(0.0)
	get_viewport().size_changed.connect(_resize_camera)
	return true

func _resize_camera() -> void:
	camera.zoom = ScreenProjection.zoom_for_view_height(get_viewport_rect().size.y, 5.0)
	camera.force_update_scroll()

func _input(event: InputEvent) -> void:
	if _mouse_point_actions != null: _mouse_point_actions.observe(event)
	if movement == null: return
	# Raw compatibility diagnostic only, not the normalized Point command sample.
	# 原生 GUI 可能在 _unhandled_input 前消费点击；观察必须先于该阶段。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var owned := _owns_current_actor()
		var projected: Variant = ScreenProjection.project(camera, event.position) if owned else null
		click_observation.observe({
			"frame": Engine.get_process_frames(), "screen_position": event.position,
			"over_ui": bool(_ui_guard.call(event.position)),
			"had_input_target": owned, "could_move": owned and actor.can_move(),
			"movement_mode": movement.mode,
			"projection_valid": projected is Vector2,
			"world_position": projected if projected is Vector2 else Vector2.ZERO,
			"order_before_dispatch": owned and actor.execution.has_move_order(),
		})
	if event is InputEventKey:
		if event.physical_keycode == KEY_TAB and event.pressed and not event.echo:
			Commands.on_toggle_performed(_submit)
		keyboard.handle_key(event, blocked, _submit)

func _unhandled_input(event: InputEvent) -> void:
	if movement == null: return
	# Explicit formal host owns Click; never also submit the legacy button position.
	if _normalized_click_bound and event is InputEventMouseButton: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Commands.on_click_performed(event.position, blocked, camera, actor, _ui_guard,
			func(cam, _actor, point): return ScreenProjection.project(cam, point), _submit)

func _submit(kind: int, direction: Vector2, point: Variant) -> int:
	if not _owns_current_actor():
		last_result = Commands.Failure.ACTOR_MISMATCH
		return last_result
	command_count += 1
	last_result = Commands.submit_single_character(kind, direction, point, actor, true,
		actor, true, true, actor, movement, route)
	return last_result

func _physics_process(_delta: float) -> void:
	if movement != null:
		actor.advance_movement(Step.GAMEPLAY_DELTA_SECONDS)
	if is_instance_valid(training_target):
		training_target.advance_movement(Step.GAMEPLAY_DELTA_SECONDS)

func _process(delta: float) -> void:
	click_observation.advance(func():
		var owned := _owns_current_actor()
		return {"order": owned and actor.execution.has_move_order(),
			"position": actor.get_movement_position() if owned else Vector2.ZERO})
	if binding != null: camera.advance_follow(delta)
	_update_human_aim()
	update_ui_pointer_selection()
	advance_human_charged_combat(delta)
	if is_instance_valid(training_target):
		training_target.advance_damage_lifecycle()

func _exit_tree() -> void:
	_training_effects.clear()
	training_hit_cue.dispose()
	unbind_ui_pointer_selection()
	stop_human_aim()
	if human_motion_binding != null:
		human_motion_binding.detach()
		human_motion_binding = null
	if binding != null:
		binding.on_disable()
		binding = null

func _owns_current_actor() -> bool:
	var player: Object = _player_provider.call()
	return is_instance_valid(player) and player.has_method("get_current_controlled_character_or_player_instance") \
		and player.get_current_controlled_character_or_player_instance() == actor

## 外部派生文件在构造导航图前验证结构，避免部分启动后才触发断言。
static func valid_rules(data: Dictionary) -> bool:
	if data.get("schema") != 1 or data.get("source_commit") != SOURCE \
			or data.get("rule_tilemap") != 1361196487 or not data.get("rows") is Array \
			or data.rows.size() != 900 or data.get("nearest_radius") != 2: return false
	var seen := {}
	for row in data.rows:
		if not row is Dictionary or not row.get("cell") is Array or row.cell.size() != 3 \
				or not row.get("walkable") is bool: return false
		for value in row.cell:
			if not _integer(value): return false
		if row.cell[2] != 0: return false
		var cell := Vector3i(row.cell[0], row.cell[1], row.cell[2])
		if seen.has(cell): return false
		seen[cell] = true
		for field in ["elevation", "transition", "ramp", "surface"]:
			if not _integer(row.get(field)): return false
		var cost: Variant = row.get("cost")
		if not (cost is float or cost is int) or not is_finite(float(cost)): return false
	return true

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

## 可选正式 Human 图集切片；逻辑入口不默默生成素材或启用占位角色。
## 调用者仍须把权威 owner 的实际位移/身体朝向通知接到返回节点。
func start_human_presentation(data: Dictionary, texture_directory: String) -> Node2D:
	if human_presentation != null or not is_instance_valid(visual_body) or not visual_body.is_inside_tree(): return null
	var presentation = preload("res://gameplay/clickmovetest/human_presentation.gd").new()
	visual_body.add_child(presentation)
	if not presentation.configure(data, texture_directory):
		printerr(presentation.last_error)
		presentation.free()
		return null
	human_presentation = presentation
	return presentation

## 显式正式主图切片：调用前先 start_human_presentation；依赖仍由宿主提供。
func start_human_logic(owner: Object, data: Dictionary, player_provider: Callable,
		map_provider: Callable, map_events: Object, ui_guard: Callable) -> bool:
	if human_motion_binding != null or movement != null: return false
	var candidate = preload("res://gameplay/clickmovetest/human_motion_binding.gd").new()
	if not candidate.configure(owner,human_presentation,false): return false
	if not start_logic(candidate,data,player_provider,map_provider,map_events,ui_guard):
		candidate.detach()
		return false
	candidate.activate()
	human_motion_binding=candidate
	return true


## 原场景 Static Pivot + 显式本地控制宿主。既不猜选玩家，也不打开假 GAS。
func start_human_aim(owner: Object, control: Object) -> bool:
	if _human_aim != null or human_motion_binding == null or not human_motion_binding.uses_owner(owner):
		return false
	if not is_instance_valid(control) or not is_instance_valid(aim_pivot) or aim_pivot.get_parent() != actor:
		return false
	for method in ["accepts_player_input","is_current_controlled","can_be_player_controlled",
			"refresh_interaction_target","reset_interaction_target","read_active_gameplay_pointer"]:
		if not control.has_method(method): return false
	var candidate := Aim.new()
	# 锁定 Actor/Hero/ClickMoveTest 保留 m_castAbilitiesInPointerDirection=true。
	if not candidate.configure(actor,owner,aim_pivot,true): return false
	_aim_control = control
	_human_aim = candidate
	return true

## 可选鼠标 Point 入口。调用者显式持有动作图生命周期，不影响既有点击链。
func bind_mouse_point_actions(actions: RefCounted) -> bool:
	if actions == null or not actions is MousePoints: return false
	_mouse_point_actions = actions
	return true

func unbind_mouse_point_actions() -> void:
	unbind_human_click_action()
	_mouse_point_actions = null

## 可选：把原 CharacterButtonActivation 绑定到同一个已启动的权威角色和 Static Pivot。
## 不登记未从原场景迁移的目标，也不在这里接管按键、角色命令或音频系统。
func start_human_interaction(owner: Object, audio_request: Callable) -> bool:
	if human_interaction != null or _human_aim == null or _human_aim.target_owner != owner:
		return false
	var candidate := Interaction.new()
	if not candidate.configure(owner,aim_pivot,audio_request): return false
	human_interaction = candidate
	human_commands = preload("res://game_core/interaction/character_command_executor.gd").new()
	human_commands.character = owner
	human_commands.interaction = candidate
	human_commands.movement = movement
	human_commands.terrain_map = route
	return true

## 可选正式技能宿主：保留真实 Cell 身份，不生成 GAS 或目标组件。
## target_root(target) 返回目标根的 Unity Vector3；target_cell(target) 返回真实 ASC.Cell 或 null。
## 请求 direction/world_position 与角色方向状态统一为 Unity 坐标，不接受 Godot 屏幕坐标。
func start_human_abilities(owner: Object, fire: Callable, stop: Callable,
		target_root: Callable, target_cell: Callable, notify_rejected: Callable) -> bool:
	if _charged_actor_runtime != null or human_commands == null or human_commands.character != owner: return false
	if not target_root.is_valid() or not target_cell.is_valid(): return false
	var bound: bool = human_commands.bind_abilities(fire,stop,func(request):
		# 锁定 ClickMoveTest 的 Actor 根 Z=0；Static Pivot 与 Body 偏移均不能参与。
		var root := Vector3(actor.global_position.x,-actor.global_position.y,0)
		return preload("res://game_core/interaction/ability_activation_builder.gd").build(
			request,root,owner.get_target_direction,target_root,target_cell),notify_rejected)
	if bound: _equipped_ability_dispatch = null
	return bound

## 可选正式槽位入口；槽位对象由原角色宿主持有，不创建默认技能或独立副本。
func start_human_equipped_abilities(owner: Object, loadout: RefCounted,
		resolve_active: Callable, fire_resolved: Callable, stop_resolved: Callable,
		target_root: Callable, target_cell: Callable, notify_rejected: Callable) -> bool:
	var dispatch := preload("res://game_core/combat/equipped_ability_dispatch.gd").new()
	if not dispatch.configure(loadout,resolve_active,fire_resolved,stop_resolved): return false
	if not start_human_abilities(owner,dispatch.fire,dispatch.stop,target_root,target_cell,notify_rejected): return false
	_equipped_ability_dispatch = dispatch
	return true

## 已解析能力的原调度入口；resolver 与实际 GAS 操作必须由显式正式宿主提供。
func start_human_resolved_equipped_abilities(owner: Object, loadout: RefCounted,
		resolve_active: Callable, ability_host: Object,
		target_root: Callable, target_cell: Callable, notify_rejected: Callable, use_source_start_rules: bool = false) -> bool:
	var dispatch := preload("res://game_core/combat/equipped_ability_dispatch.gd").new()
	if not dispatch.configure_resolved_fire(loadout,resolve_active,owner,ability_host,use_source_start_rules): return false
	if not start_human_abilities(owner,dispatch.fire,dispatch.stop,target_root,target_cell,notify_rejected): return false
	_equipped_ability_dispatch = dispatch
	return true

## 在同一实际角色上显式装配已核实的 20004 闭环；不赋予技能、不接管已有能力宿主。
## hit_task 仍由正式目标/伤害拥有者接入；本入口不创建目标、数值或替代动作。
func start_human_charged_combat(owner: Object, loadout: RefCounted, hit_task: Callable,
		target_root: Callable, target_cell: Callable, notify_rejected: Callable) -> Node:
	if _charged_actor_runtime != null or human_commands == null or human_commands.character != owner: return null
	if _equipped_ability_dispatch != null or human_commands.has_bound_abilities(): return null
	if not is_instance_valid(human_presentation) or not is_instance_valid(human_presentation.driver) or not hit_task.is_valid(): return null
	var driver: Node = human_presentation.driver
	if driver.resolve_playable_state("ChargedAttack").is_empty(): return null
	var timeline := preload("res://gameplay/combat/charged_timeline_tasks.gd").new(hit_task, driver)
	var runtime := preload("res://gameplay/combat/resolved_charged_ability.gd").new()
	add_child(runtime)
	if not runtime.configure(actor, owner, timeline, actor.get_movement_position) \
			or not runtime.take_clock_tick_ownership(timeline) \
			or not start_human_resolved_equipped_abilities(owner,loadout,runtime.resolve,runtime,target_root,target_cell,notify_rejected,true):
		runtime.free()
		return null
	_charged_actor_runtime = runtime
	_charged_timeline = timeline
	return runtime

## 绑定场景中唯一活动训练假人的受击逻辑。缺少正式控制/生命周期回调时拒绝；
## 不注册假 AI、不自动加进默认场景、不创建美术或替代碰撞资源。
func start_training_damage_target(motion_owner: Object, target_hooks: Dictionary, terrain_mask: int) -> Node2D:
	if training_target != null or not is_inside_tree(): return null
	for key in ["is_dead", "is_invincible"]:
		if not target_hooks.get(key) is Callable or not target_hooks[key].is_valid(): return null
	var sheet := TrainingTarget.initial_sheet()
	var properties := TrainingAttributes.new()
	if not properties.configure(PackedInt32Array([sheet.health, sheet.mana, sheet.physical_attack,
			sheet.magical_attack, sheet.physical_defense, sheet.magical_defense, sheet.agility,
			sheet.luck, sheet.attack_speed]), sheet.alignment, target_hooks.is_dead, target_hooks.is_invincible):
		return null
	var hooks := target_hooks.duplicate()
	hooks.stats = properties.stats
	hooks.current_health = properties.current_health
	hooks.has_formal_stats = properties.has_formal_stats
	hooks.apply_current_health_delta = properties.apply_current_health_delta
	var target := TrainingTarget.new()
	# 相异实际 Actor；按原 PushMode.Default 路径只在一个拥有者提交推力。
	hooks.impact = func(input,velocity):
		if is_instance_valid(target) and is_instance_valid(target.body):
			DamagePush.try_push(input,false,velocity,DamagePush.Mode.DEFAULT,
				TRAINING_PUSH_FLAGS,target.body.push_motion)
	if not target.configure(hooks,motion_owner,terrain_mask):
		target.free()
		return null
	add_child(target)
	training_target = target
	training_attributes = properties
	return target

## 显式导入源图集；空资源不让角色获得假表现。
func start_training_target_presentation(animation: Dictionary, texture_directory: String) -> Node2D:
	if not is_instance_valid(training_target): return null
	return training_target.start_presentation(animation,texture_directory)

## 兼容现有显式槽位契约：假人只在此入口担任已绑定的受击者。
## Caster 当前快照、掷骰和 ASC Cell 属于正式宿主；暴击/闪避来自锁定 GameConfig.asset。
func start_human_charged_training_combat(owner: Object, loadout: RefCounted, caster_stats: Callable,
		roll: Callable, target_root: Callable, target_cell: Callable, notify_rejected: Callable) -> Node:
	if not is_instance_valid(training_target) or not caster_stats.is_valid() or not roll.is_valid() \
			or not target_root.is_valid() or not target_cell.is_valid(): return null
	var hit_task := _hit_training_target.bind(owner,caster_stats,roll)
	var resolve_root := func (target):
		if not is_instance_valid(training_target) or target != training_target: return target_root.call(target)
		var at: Vector2 = training_target.get_movement_position()
		return Vector3(at.x,at.y,0)
	return start_human_charged_combat(owner,loadout,hit_task,resolve_root,target_cell,notify_rejected)

func _hit_training_target(owner: Object, caster_stats: Callable, roll: Callable) -> void:
	if not is_instance_valid(training_target) or not is_instance_valid(owner) or not is_instance_valid(actor): return
	var start: Vector2 = actor.get_movement_position()
	ChargedHit.run(actor.get_world_2d(), actor, start, owner.get_look_at_direction(),
		func(collider): return training_target if is_instance_valid(training_target) and collider == training_target.hitbox else null,
		func(caster,target,effect_id):
			if effect_id == ChargedHit.EFFECT_ID:
				_training_effects.request(caster,target,_execute_training_damage.bind(caster_stats,roll)))

func _execute_training_damage(caster: Node2D, target: Node2D, caster_stats: Callable, roll: Callable) -> void:
	if caster != actor or target != training_target or not caster_stats.is_valid() or not roll.is_valid(): return
	var current: Variant = caster_stats.call()
	if not current is Dictionary or not current.get("snapshot") is Dictionary: return
	# 目标在第12帧确定，根位置和角色属性由后续瞬时效果重新读取。
	ChargedDamage.execute_damage_phase(current,target.stats,target.hooks(),caster.get_movement_position(),
		target.get_movement_position(),true,true,roll)

## SGAbility 的时间轴先提交请求；同次逻辑更新的 SGEffect 再消费。
## 现有技能更新可以合并多个原时间轴帧，不等同于全局 Unity FixedUpdate。
func advance_human_charged_combat(delta: float) -> void:
	var runtime: Node = _charged_actor_runtime
	if is_instance_valid(runtime):
		runtime.process_requests()
		if runtime == _charged_actor_runtime: runtime.advance_owned_clock(delta)
	_training_effects.run_effects(training_hit_cue.request)
	if is_instance_valid(runtime) and runtime == _charged_actor_runtime:
		runtime.advance_input(delta)
		if runtime == _charged_actor_runtime: _charged_timeline.flush_display()
	training_hit_cue.flush_display()

## 显式归一化 InputSystem 回调；不自造 PlayerInput 动作图切换或 GAS。
## resolve_context 返回 null 或当前输入目标的 {actor, command_context}。
func bind_human_gameplay_actions(resolve_context: Callable, interact_blocked: Callable, notify_failed: Callable) -> bool:
	if human_commands == null: return false
	var candidate := preload("res://game_core/input/gameplay_command_actions.gd").new()
	if not candidate.configure(resolve_context,submit_human_command,interact_blocked,notify_failed): return false
	human_gameplay_actions = candidate
	_normalized_click_bound = false
	return true

## Host dispatches normalized Click explicitly; this does not route raw events.
func bind_human_click_action(click_blocked: Callable) -> bool:
	if human_gameplay_actions == null or _mouse_point_actions == null: return false
	if not human_gameplay_actions.configure_click(click_blocked,_resolve_human_click_world): return false
	_normalized_click_bound = true
	return true

func unbind_human_click_action() -> void:
	_normalized_click_bound = false
	# Drop the callback too; the remaining Interact/Fire callbacks stay bound.
	if human_gameplay_actions != null:
		human_gameplay_actions.unbind_click()

func _resolve_human_click_world() -> Variant:
	if _mouse_point_actions == null: return null
	var current_camera = camera
	var player: Object = _player_provider.call() if _player_provider.is_valid() else null
	var controlled: Object = player.get_current_controlled_character_or_player_instance() if is_instance_valid(player) and player.has_method("get_current_controlled_character_or_player_instance") else null
	# Original reads Point even when camera/actor are absent; never check activeControl.
	var screen: Vector2 = _mouse_point_actions.read_value_local(MousePoints.Map.GAMEPLAY,get_viewport_rect())
	if not is_instance_valid(current_camera) or not is_instance_valid(controlled): return null
	if not _ui_guard.is_valid() or bool(_ui_guard.call(screen)): return null
	return ScreenProjection.project(current_camera,screen)

func receive_human_gameplay_action(action_map: String, action: String, phase: String) -> Variant:
	if human_gameplay_actions == null: return null
	return human_gameplay_actions.receive(action_map,action,phase)

func unbind_human_gameplay_actions() -> void:
	_normalized_click_bound = false
	human_gameplay_actions = null

## Already resolved commands only. Player ownership is checked before executor dispatch;
## raw input, menu and formal GAS setup remain explicit host responsibilities.
func submit_human_command(request: Dictionary) -> int:
	if human_commands == null: return Commands.Failure.NOT_RUNNING
	if not _owns_current_actor(): return Commands.Failure.ACTOR_MISMATCH
	if not is_instance_valid(_aim_control) or not _aim_control.is_current_controlled(actor): return Commands.Failure.MISSING_INPUT_TARGET
	if not is_instance_valid(_aim_control) or not _aim_control.accepts_player_input(actor) or not _aim_control.can_be_player_controlled(actor):
		return Commands.Failure.CONTROL_LOCKED
	command_count += 1
	last_result = human_commands.execute(request)
	return last_result

func _update_human_aim() -> void:
	if _human_aim == null or not is_instance_valid(_aim_control) or not _aim_control.accepts_player_input(actor):
		return
	if not _aim_control.is_current_controlled(actor) or not _aim_control.can_be_player_controlled(actor):
		if _aim_was_local: _reset_human_aim_control()
		return
	_aim_was_local = true
	if human_interaction != null: human_interaction.refresh_current_target()
	else: _aim_control.refresh_interaction_target(actor)
	# Only ask for an input sample when the source target/idle gates allow it.
	var owner: Object = _human_aim.target_owner
	if not is_instance_valid(owner) or not owner.can_update_target_direction(): return
	var point: Variant = null
	if not actor.has_active_movement_intent():
		point = _mouse_point_actions.read_active(MousePoints.Map.GAMEPLAY) if _mouse_point_actions != null else _aim_control.read_active_gameplay_pointer()
	if not _human_aim.try_update(camera,point if point is Vector2 else Vector2.ZERO,point is Vector2):
		owner.reset_target_direction()

func _reset_human_aim_control() -> void:
	var owner: Object = _human_aim.target_owner
	if is_instance_valid(owner): owner.reset_target_direction()
	if is_instance_valid(actor): actor.reset_movement()
	if human_interaction != null: human_interaction.reset_state()
	elif is_instance_valid(_aim_control): _aim_control.reset_interaction_target(actor)
	_aim_was_local = false

## 宿主应用 SetAcceptsPlayerInput(false) 时调用；保留绑定供以后重新启用。
func notify_human_aim_input_disabled() -> void:
	if _human_aim != null: _reset_human_aim_control()

func stop_human_aim() -> void:
	if _charged_timeline != null:
		_charged_timeline.stop()
		_charged_timeline = null
	if is_instance_valid(_charged_actor_runtime): _charged_actor_runtime.queue_free()
	_charged_actor_runtime = null
	_equipped_ability_dispatch = null
	unbind_human_gameplay_actions()
	if _human_aim == null: return
	_reset_human_aim_control()
	human_commands = null
	human_interaction = null
	_human_aim = null
	_aim_control = null

## 可选原 UI 宿主；命中由原 GraphicRaycaster 等价宿主按既有顺序提供。
## 不复用 Gameplay 点击阻挡策略，也不为诊断面板创造可选按钮。
func bind_ui_pointer_selection(authored_components: Dictionary, pointer_over: Callable, raycast: Callable) -> bool:
	if not is_inside_tree() or not pointer_over.is_valid() or not raycast.is_valid(): return false
	_pointer_selection = PointerSelection.new(get_viewport(),authored_components)
	_pointer_over_ui = pointer_over
	_ui_raycast = raycast
	return true

func unbind_ui_pointer_selection() -> void:
	_pointer_selection = null
	_pointer_over_ui = Callable()
	_ui_raycast = Callable()
	last_ui_selection = "unbound"

func update_ui_pointer_selection() -> void:
	if _pointer_selection == null: return
	if _mouse_point_actions == null or not _mouse_point_actions.read_active(MousePoints.Map.UI) is Vector2:
		last_ui_selection = "inactive_point"
		return
	if not _pointer_over_ui.is_valid() or not _ui_raycast.is_valid():
		last_ui_selection = "missing_host"
		return
	if not _pointer_over_ui.call():
		last_ui_selection = "not_over_ui"
		return
	# 原源码在 pointer-over 后 ReadValue；期间禁用图时读取默认值，不再重做 activeControl 检查。
	if _pointer_selection == null or _mouse_point_actions == null or not _ui_raycast.is_valid():
		last_ui_selection = "missing_host"
		return
	var point: Vector2 = _mouse_point_actions.read_value_local(MousePoints.Map.UI,get_viewport_rect())
	last_ui_selection = _pointer_selection.apply_hits(_ui_raycast.call(point))
