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

func _process(delta: float) -> void:
	click_observation.advance(func():
		var owned := _owns_current_actor()
		return {"order": owned and actor.execution.has_move_order(),
			"position": actor.get_movement_position() if owned else Vector2.ZERO})
	if binding != null: camera.advance_follow(delta)
	_update_human_aim()
	update_ui_pointer_selection()

func _exit_tree() -> void:
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
	if human_commands == null or human_commands.character != owner: return false
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
