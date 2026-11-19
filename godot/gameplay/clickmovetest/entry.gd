extends Node2D
## ClickMoveTest 的可注入启动切片。无正式素材、GAS 和系统宿主时不自行补依赖。
const PointerSelection = preload("res://game_core/ui/pointer_selection.gd")
const MousePoints = preload("res://game_core/input/mouse_point_actions.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Movement = preload("res://game_core/movement/character_movement.gd")
const Commands = preload("res://game_core/movement/movement_commands.gd")
const CharacterExecutor = preload("res://game_core/interaction/character_command_executor.gd")
const SlotKeyboard = preload("res://game_core/combat/ability_slot_keyboard_input.gd")
const Keyboard = preload("res://game_core/movement/keyboard_movement_input.gd")
const SurfaceContact = preload("res://game_core/elements/terrain_surface_damage_system.gd")
const DamageLifecycle = preload("res://game_core/combat/deferred_damage_lifecycle.gd")
const FormalDamage = preload("res://game_core/combat/formal_damage_application.gd")
const CombatRules = preload("res://game_core/combat/combat_rules.gd")
const SurfacePresentation = preload("res://game_core/elements/terrain_surface_presentation.gd")
const GroundLayers = preload("res://gameplay/clickmovetest/ground_layers.gd")
const SurfaceFireLayer = preload("res://game_core/presentation/terrain_burning_tile_layer.gd")
const SurfaceElements = preload("res://game_core/elements/terrain_element_runtime.gd")
const Route = preload("res://game_core/navigation/terrain_world_route.gd")
const Binding = preload("res://game_core/presentation/player_camera_binding.gd")
const ScreenProjection = preload("res://game_core/presentation/orthographic_screen_projection.gd")
const Interaction = preload("res://game_core/interaction/character_button_activation.gd")
const Aim = preload("res://game_core/movement/idle_pointer_aim.gd")
const Step = preload("res://game_core/movement/source_fixed_step.gd")
const Observation = preload("res://gameplay/clickmovetest/click_observation.gd")
const TrainingTarget = preload("res://gameplay/clickmovetest/training_target.gd")
const TrainingAttributes = preload("res://gameplay/clickmovetest/training_damage_attributes.gd")
const FireVisual = preload("res://game_core/presentation/flamethrower_cue_visual.gd")
const FireAudio = preload("res://gameplay/combat/flamethrower_cue_audio.gd")
const FireTimeline = preload("res://gameplay/combat/flamethrower_timeline.gd")
const BasicTimeline = preload("res://gameplay/combat/basic_attack_timeline.gd")
const BasicDamage = preload("res://gameplay/combat/basic_damage_effect.gd")
const HitPolygon = preload("res://game_core/combat/polygon_hitbox_query.gd")
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
var ground_layers: Node2D
var human_presentation: Node2D
var human_motion_binding: RefCounted
var _human_damage_lifecycle := DamageLifecycle.new()
var _human_damage_destroyed: Callable
var _source_primary_death_owner: Object
const HumanPresentation = preload("res://gameplay/clickmovetest/human_presentation.gd")
var _human_interrupt_actions: Callable
var movement: RefCounted
var route: RefCounted
var _terrain_from_map: Callable
var binding: RefCounted
var blocked := false
var command_count := 0
var last_result: Variant
var click_observation := Observation.new()
var keyboard := Keyboard.new()
var human_gameplay_actions: RefCounted
var _normalized_click_bound := false
var _slot_keyboard: SlotKeyboard
var human_commands: RefCounted
var human_interaction: RefCounted
var _human_aim: RefCounted
var _aim_control: Object
var _aim_was_local := false
var _equipped_ability_dispatch: RefCounted
var _charged_actor_runtime: Node
var _charged_timeline: RefCounted
var _basic_timeline: RefCounted
var _fire_timeline: RefCounted
var flamethrower_visual: Node2D
var flamethrower_audio: Node
var _fire_cue_actor: WeakRef
var _fire_cue_png := ""
var _fire_cue_ogg := ""
var training_hit_cue := TrainingHitCue.new()
var _training_effects := ChargedEffects.new()
var training_target: Node2D
var training_attributes: RefCounted
var _training_tracking_stats: Callable
var _mouse_point_actions: RefCounted
var _pointer_selection: RefCounted
var _pointer_over_ui: Callable
var _ui_raycast: Callable
var last_ui_selection := "unbound"
var _ui_guard: Callable
var _player_provider: Callable
var _surface_map_events: Object
var _terrain_rule_rows: Array = []
var surface_elements: RefCounted
var surface_presentation: RefCounted
var surface_fire_tiles: TileMapLayer
var surface_contact_damage: RefCounted
var _contact_player_stats: Callable
var _contact_player_hooks: Dictionary = {}
var _contact_damage_pending: Array[Dictionary] = []

func _ready() -> void:
	# 与训练假人相同：受击盒将身份交回原玩家根，不能变成独立目标。
	if is_instance_valid(actor):
		actor.get_node("受击盒").set_meta("actor",actor)

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
	_terrain_rule_rows = data.rows.duplicate(true)
	_surface_map_events = map_events
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

## 实际 ClickMoveTest 规则格绑定首批元素运行时；私有作者投影不写入游戏仓库。
## 点施加复用原验证器语义，由显式战斗入口装配喷火；地表表现不在此绑定。
func start_surface_elements(assets: Dictionary) -> bool:
	if not is_inside_tree() or surface_elements != null or route==null or not is_instance_valid(_surface_map_events): return false
	if int(assets.get("schema",0))!=1 or assets.get("source_commit")!=SOURCE: return false
	var candidate := SurfaceElements.new()
	if not candidate.configure(_terrain_rule_rows,assets): return false
	surface_elements = candidate
	if surface_contact_damage != null: surface_contact_damage.on_map_loaded()
	_surface_map_events.map_unloaded.connect(_on_surface_map_unloaded)
	return true

## Source damage system is opt-in until the actual scene's formal actor is bound.
## The player must supply its existing ASC-like stats and hook port; no placeholder HP.
## Without it the training character still uses its real sheet, lifecycle and hooks.
func start_surface_contact_damage(player_stats: Callable = Callable(), player_hooks: Dictionary = {}) -> bool:
	if surface_elements == null or surface_contact_damage != null or not is_inside_tree(): return false
	if not player_hooks.is_empty():
		if not player_stats.is_valid(): return false
		for key in ["impact","provoke","has_formal_stats","current_health","prepare","apply_current_health_delta","complete"]:
			if not player_hooks.get(key) is Callable or not player_hooks[key].is_valid(): return false
	var system := SurfaceContact.new()
	if not system.configure(_active_surface,_current_contact_player,_read_contact_target,
			_submit_contact_damage,_resolve_contact_character): return false
	_contact_player_stats = player_stats
	_contact_player_hooks = player_hooks.duplicate()
	surface_contact_damage = system
	if is_instance_valid(training_target): system.register_target(training_target)
	return true

func _active_surface() -> RefCounted: return surface_elements

func _current_contact_player() -> Object:
	return actor if _owns_current_actor() else null

func _resolve_contact_character(entity: Object) -> Object:
	if is_instance_valid(entity) and (entity == actor or entity == training_target): return entity
	return null

func _contact_stats(entity: Object) -> Dictionary:
	if not is_instance_valid(entity): return {}
	if entity == actor and _contact_player_stats.is_valid(): return _contact_player_stats.call()
	if entity == training_target: return training_target.stats
	return {}

func _read_contact_target(target: Object) -> Dictionary:
	var stats := _contact_stats(target)
	if stats.is_empty(): return {}
	return {"dead":bool(stats.get("dead",true)), "position":target.get_movement_position()}

func _contact_hooks(target: Object, source: Object = null) -> Dictionary:
	if not is_instance_valid(target): return {}
	if target == training_target: return training_target.hooks(_resolve_contact_character(source))
	return _contact_player_hooks if target == actor else {}

func _submit_contact_damage(source: Object, target: Object, payload: Dictionary) -> bool:
	# Real receiver binding is required; missing caster binding is Entity.Null in Unity.
	var hooks := _contact_hooks(target)
	if hooks.is_empty() or not hooks.has_formal_stats.call(): return false
	var origin: Variant = weakref(source) if is_instance_valid(source) else null
	_contact_damage_pending.append({"source":origin,"target":weakref(target),"payload":payload})
	return true

func advance_surface_contact(delta: float, time_scale: float = 1.0) -> void:
	if surface_contact_damage != null: surface_contact_damage.advance(delta,time_scale)

func run_surface_contact_effects() -> void:
	# Source world system requests formal GAS effects; never mutate HP in map sampling.
	# Reentrant submissions belong to the next effect phase.
	var applying := _contact_damage_pending
	_contact_damage_pending = []
	for entry in applying:
		var source: Object = entry.source.get_ref() if entry.source != null else null
		var target: Object = entry.target.get_ref()
		var hooks := _contact_hooks(target,source)
		if hooks.is_empty(): continue
		var defender := _contact_stats(target)
		if defender.is_empty(): continue
		var attacker := defender if source == target else _contact_stats(source)
		var output := CombatRules.solve_damage_output(attacker if not attacker.is_empty() else null,
			entry.payload.descriptor,false,Callable())
		if source == target:
			# Original self-hit still damages, but Movable.TryPush rejects its own source.
			hooks = hooks.duplicate()
			hooks.impact = func(_input,_velocity): pass
		FormalDamage.execute_damage_output(defender,output,false,Callable(),hooks,entry.payload.impact_velocity)

## 必须在临时火焰层之前绑定，避免已存在的控制器继续持有空回调。
func bind_ground_layers(directory: String) -> bool:
	if surface_elements == null or ground_layers != null or surface_presentation != null or not is_inside_tree(): return false
	var layer := GroundLayers.new()
	if not layer.configure(directory):
		layer.free()
		return false
	layer.name = "原基础地面与草覆盖"
	add_child(layer)
	ground_layers = layer
	return true

## 原场景只有 Burning 临时瓦片，无 Steam 或替换地貌。
## 优先连接已装配的真实覆盖层；显式端口可由完整地图宿主提供。
func bind_surface_presentation(fire_path: String, cover_port: Dictionary = {}) -> bool:
	if surface_elements == null or surface_presentation != null or not is_inside_tree(): return false
	var layer := SurfaceFireLayer.new()
	if not layer.configure(fire_path):
		layer.free()
		return false
	var ports := cover_port.duplicate()
	if ports.is_empty() and is_instance_valid(ground_layers): ports = ground_layers.cover_port()
	if ports.is_empty():
		ports = {"mapped_cover_sources":func(_cell):return [],"source_available":func(_id):return false,
			"set_cover_alpha":func(_id,_cell,_alpha):pass,"unlock_cover_cell":func(_id,_cell):pass}
	ports.sample = surface_elements.sample
	ports.set_tile = layer.set_source_tile
	ports.clear_tiles = layer.clear
	var presentation := SurfacePresentation.new()
	if not presentation.configure([{"state":SurfaceElements.BURNING,
			"tile":SurfaceFireLayer.FIRE_TILE,"priority":100}],[],ports):
		layer.free()
		return false
	layer.name = "原地表临时效果瓦片层"
	add_child(layer)
	surface_fire_tiles = layer
	surface_presentation = presentation
	surface_elements.cell_changed.connect(presentation.on_cell_changed)
	surface_elements.states_cleared.connect(presentation.clear)
	return presentation.enable(surface_elements.runtime_cells())

func _unbind_surface_presentation() -> void:
	if surface_presentation != null:
		if surface_elements != null:
			surface_elements.cell_changed.disconnect(surface_presentation.on_cell_changed)
			surface_elements.states_cleared.disconnect(surface_presentation.clear)
		surface_presentation.disable()
		surface_presentation = null
	if is_instance_valid(surface_fire_tiles):
		surface_fire_tiles.hide()
		surface_fire_tiles.queue_free()
	surface_fire_tiles = null

func _on_surface_map_unloaded() -> void:
	if surface_contact_damage != null: surface_contact_damage.on_map_unloading()
	_contact_damage_pending.clear()
	if surface_elements != null: surface_elements.clear()
	_unbind_surface_presentation()
	if is_instance_valid(ground_layers):
		ground_layers.hide()
		ground_layers.queue_free()
	ground_layers = null
	surface_elements = null
	if is_instance_valid(_surface_map_events) and _surface_map_events.map_unloaded.is_connected(_on_surface_map_unloaded):
		_surface_map_events.map_unloaded.disconnect(_on_surface_map_unloaded)

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
		if _slot_keyboard != null:
			_slot_keyboard.handle_key(event,_dispatch_human_ability_key)
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
	# 相机可以回退主角，不代表该角色仍接受玩家命令。
	if is_instance_valid(_aim_control):
		if not _aim_control.is_current_controlled(actor):
			last_result = Commands.Failure.MISSING_INPUT_TARGET
			return last_result
		if not _aim_control.accepts_player_input(actor) or not _aim_control.can_be_player_controlled(actor):
			last_result = Commands.Failure.CONTROL_LOCKED
			return last_result
	command_count += 1
	last_result = Commands.submit_single_character(kind, direction, point, actor, true,
		actor, true, true, actor, movement, _resolve_active_terrain())
	return last_result

func _physics_process(_delta: float) -> void:
	if is_instance_valid(training_target):
		training_target.ai_controller.advance_target_step(Step.GAMEPLAY_DELTA_SECONDS)
	if movement != null:
		actor.advance_movement(Step.GAMEPLAY_DELTA_SECONDS)
	if is_instance_valid(training_target):
		training_target.advance_movement(Step.GAMEPLAY_DELTA_SECONDS)
		training_target.ai_controller.capture_detection_after_movement()

func _process(delta: float) -> void:
	advance_human_damage_lifecycle()
	click_observation.advance(func():
		var owned := _owns_current_actor()
		return {"order": owned and actor.execution.has_move_order(),
			"position": actor.get_movement_position() if owned else Vector2.ZERO})
	if binding != null: camera.advance_follow(delta)
	_update_human_aim()
	update_ui_pointer_selection()
	if is_instance_valid(flamethrower_visual): flamethrower_visual.advance(delta)
	run_surface_contact_effects()
	advance_human_charged_combat(delta)
	if surface_elements != null: surface_elements.advance(delta)
	if surface_presentation != null: surface_presentation.advance(delta)
	advance_surface_contact(delta,Engine.time_scale)
	if is_instance_valid(training_target):
		# 原 CharacterBase.Update 先消化本角色待处理受击/死亡，死亡后不再推进其技能。
		training_target.advance_damage_lifecycle()
		training_target.advance_formal_basic_attack(delta)

func _exit_tree() -> void:
	_on_surface_map_unloaded()
	if surface_contact_damage != null: surface_contact_damage.stop()
	surface_contact_damage = null
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
	var presentation := HumanPresentation.new()
	visual_body.add_child(presentation)
	if not presentation.configure(data, texture_directory):
		printerr(presentation.last_error)
		presentation.free()
		return null
	human_presentation = presentation
	return presentation

## 正式 MapInfo 存在时，执行点击才从同一地图拥有者取得当次导航。
## 旧夹具仍直接注入其作用域明确的 route，不反向注册场景。
func bind_active_terrain(resolver: Callable) -> bool:
	if route == null or _terrain_from_map.is_valid() or not resolver.is_valid(): return false
	if resolver.call() != route: return false
	_terrain_from_map = resolver
	return true

func _resolve_active_terrain() -> RefCounted:
	return _terrain_from_map.call() if _terrain_from_map.is_valid() else route


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
	if human_commands == null and not start_human_command_execution(owner): return false
	if human_commands.character != owner: return false
	human_interaction = candidate
	human_commands.interaction = candidate
	return true


## 原角色命令执行不要求虚构交互对象；已经存在的交互仍在同一执行者仲裁技能。
func start_human_command_execution(owner: Object) -> bool:
	if human_commands != null or _human_aim == null or _human_aim.target_owner != owner: return false
	human_commands = CharacterExecutor.new()
	human_commands.character = owner
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
		target_root: Callable, target_cell: Callable, notify_rejected: Callable,
		basic_hit_task: Callable = Callable(), fire_hit_task: Callable = Callable()) -> Node:
	if _charged_actor_runtime != null or human_commands == null or human_commands.character != owner: return null
	if _equipped_ability_dispatch != null or human_commands.has_bound_abilities(): return null
	if not is_instance_valid(human_presentation) or not is_instance_valid(human_presentation.driver) or not hit_task.is_valid(): return null
	var driver: Node = human_presentation.driver
	if driver.resolve_playable_state("ChargedAttack").is_empty(): return null
	var timeline := preload("res://gameplay/combat/charged_timeline_tasks.gd").new(hit_task, driver)
	var basic_timeline: RefCounted
	if basic_hit_task.is_valid():
		if driver.resolve_playable_state("Attack").is_empty(): return null
		basic_timeline = BasicTimeline.new(basic_hit_task,driver)
	var fire_timeline: RefCounted
	if fire_hit_task.is_valid():
		if surface_elements == null or not owner.has_method("get_look_at_direction") \
				or driver.resolve_playable_state("Attack").is_empty(): return null
		fire_timeline = FireTimeline.new(fire_hit_task,_apply_flamethrower_cone.bind(owner),driver)
	var runtime := preload("res://gameplay/combat/resolved_charged_ability.gd").new()
	add_child(runtime)
	if not runtime.configure(actor, owner, timeline, actor.get_movement_position) \
			or not runtime.take_clock_tick_ownership(timeline) \
			or (basic_timeline != null and not runtime.attach_basic(actor,owner,basic_timeline,actor.get_movement_position)) \
			or (fire_timeline != null and not runtime.attach_fire(actor,owner,fire_timeline,actor.get_movement_position)) \
			or not start_human_resolved_equipped_abilities(owner,loadout,runtime.resolve,runtime,target_root,target_cell,notify_rejected,true):
		runtime.free()
		return null
	_charged_actor_runtime = runtime
	_charged_timeline = timeline
	_basic_timeline = basic_timeline
	_fire_timeline = fire_timeline
	return runtime

## 源新玩家组合只装 20001/20010。角色自己的新槽按作者先后解析到这两个真实实例，
## 不持有沉默的 20004、不装载其时间轴，保留单一角色技能门禁与一次时钟所有权。
func start_human_fresh_training_combat(owner: Object, roll: Callable,
		target_root: Callable, target_cell: Callable, notify_rejected: Callable) -> Node:
	if _charged_actor_runtime != null or human_commands == null or human_commands.character != owner:
		return null
	if _equipped_ability_dispatch != null or human_commands.has_bound_abilities():
		return null
	if not is_instance_valid(owner) or not owner.has_method("stats") \
			or not owner.has_method("bind_fresh_ability_loadout") or not owner.has_method("bind_fresh_target_direction_guard") \
			or not owner.has_method("get_look_at_direction") \
			or not roll.is_valid() or not target_root.is_valid() or not target_cell.is_valid() or not notify_rejected.is_valid():
		return null
	if not is_instance_valid(training_target) or not training_target.has_formal_target_direction() \
			or surface_elements == null or not is_instance_valid(human_presentation):
		return null
	var driver: Node = human_presentation.driver
	if not is_instance_valid(driver) or driver.resolve_playable_state("Attack").is_empty():
		return null
	var runtime := preload("res://gameplay/combat/resolved_charged_ability.gd").new()
	var caster_stats := Callable(owner,"stats")
	var basic := BasicTimeline.new(_hit_basic_training_target.bind(owner,caster_stats,roll),driver)
	var fire := FireTimeline.new(_hit_effect_2003_training_target.bind(owner,caster_stats,roll,
		FireTimeline.ATTACK_POLYGON,FireTimeline.HIT_MASK),_apply_flamethrower_cone.bind(owner),driver)
	add_child(runtime)
	if not runtime.configure(actor,owner,basic,actor.get_movement_position,runtime.BASIC) \
			or not runtime.take_clock_tick_ownership(basic) \
			or not runtime.attach_fire(actor,owner,fire,actor.get_movement_position):
		runtime.free()
		return null
	var loadout: RefCounted = owner.bind_fresh_ability_loadout(runtime.resolve)
	if loadout == null or not owner.bind_fresh_target_direction_guard(runtime) \
			or not start_human_resolved_equipped_abilities(
			owner,loadout,runtime.resolve,runtime,target_root,target_cell,notify_rejected,true):
		runtime.free()
		return null
	_charged_actor_runtime = runtime
	_basic_timeline = basic
	_fire_timeline = fire
	return runtime


## Bind original presentation after the actual 20010 ability is installed.
## Exact source assets are supplied privately; missing assets do not fabricate cues.
func bind_flamethrower_cues(direction_owner: Object, png_path: String, ogg_path: String) -> bool:
	if _fire_timeline == null or human_commands == null or not is_instance_valid(direction_owner) \
			or human_commands.character != direction_owner or _fire_cue_actor != null: return false
	if not direction_owner.has_signal("target_direction_changed") or not direction_owner.has_method("get_target_direction"): return false
	var visual := FireVisual.new()
	var asset_valid := visual.configure(png_path)
	visual.free()
	if not asset_valid: return false
	var existing := is_instance_valid(flamethrower_audio)
	if existing and _fire_cue_ogg != ogg_path: return false
	var audio: Node = flamethrower_audio if existing else FireAudio.new()
	if not existing:
		add_child(audio)
		if not audio.configure_locked_clip(ogg_path):
			audio.free()
			return false
	if not _fire_timeline.bind_spray_cues(_activate_flamethrower_cues,_remove_flamethrower_visual):
		if not existing: audio.free()
		return false
	flamethrower_audio = audio
	_fire_cue_ogg = ogg_path
	_fire_cue_actor = weakref(direction_owner)
	_fire_cue_png = png_path
	return true

func _activate_flamethrower_cues() -> void:
	if _fire_cue_actor == null or not is_instance_valid(actor): return
	var owner: Object = _fire_cue_actor.get_ref()
	if not is_instance_valid(owner): return
	_remove_flamethrower_visual()
	var visual := FireVisual.new()
	if visual.configure(_fire_cue_png):
		actor.add_child(visual)
		if visual.mount(owner):
			flamethrower_visual = visual
		else:
			visual.free()
	else:
		visual.free()
	if is_instance_valid(flamethrower_audio): flamethrower_audio.activate()

func _remove_flamethrower_visual() -> void:
	if is_instance_valid(flamethrower_visual):
		flamethrower_visual.unmount()
		flamethrower_visual.queue_free()
	flamethrower_visual = null
	# CuePlayGameCoreAudio has no stop handler; existing voices run to completion.

## 绑定场景中唯一活动训练假人的受击逻辑。缺少正式控制/生命周期回调时拒绝；
## 不自动加进默认场景，不假造尚未迁移的 AI 移动、攻击或素材。
func start_training_damage_target(motion_owner: Object, target_hooks: Dictionary, terrain_mask: int) -> Node2D:
	if training_target != null or not is_inside_tree(): return null
	if not target_hooks.get("is_invincible") is Callable or not target_hooks.is_invincible.is_valid(): return null
	var sheet := TrainingTarget.initial_sheet()
	var properties := TrainingAttributes.new()
	if not properties.configure(PackedInt32Array([sheet.health, sheet.mana, sheet.physical_attack,
			sheet.magical_attack, sheet.physical_defense, sheet.magical_defense, sheet.agility,
			sheet.luck, sheet.attack_speed]), sheet.alignment, target_hooks.is_invincible):
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
	target.bind_formal_health_changes(properties)
	add_child(target)
	training_target = target
	training_attributes = properties
	if surface_contact_damage != null: surface_contact_damage.register_target(target)
	return target

## 给活动假人连接实际玩家身体和正式属性读取；未绑定时仅保留原挑衅。
func start_training_target_tracking(player_stats: Callable, map_collision: Node2D) -> bool:
	if movement == null or route == null or not is_instance_valid(training_target) or not _owns_current_actor():
		return false
	if not training_target.ai_controller.bind_player(actor,player_stats,map_collision,route.try_build_world_path): return false
	_training_tracking_stats = player_stats
	return true

## 唯一活动假人的原路径转向；缺正式朝向、玩家物理速度或世界注册时拒绝启用。
func start_training_transit_steering() -> bool:
	if not is_instance_valid(training_target) or not _owns_current_actor(): return false
	return training_target.ai_controller.bind_transit_steering()

## 同一单体世界接通源码的交替抽样入口；没有调用方提供的抽样值，不绑定新游走。
func start_training_combat_wander(random_value: Callable, random_range: Callable) -> bool:
	if not is_instance_valid(training_target) or not _owns_current_actor(): return false
	return training_target.ai_controller.bind_combat_wander(random_value,random_range)

## 只挂同一真实玩家的 Dmg 与延迟打断；实际玩家宿主持有行动和死亡。
func bind_human_damage_lifecycle(is_destroyed: Callable, interrupt_actions: Callable) -> bool:
	if _human_interrupt_actions.is_valid() or not is_destroyed.is_valid() or not interrupt_actions.is_valid():
		return false
	if human_motion_binding == null or not is_instance_valid(human_presentation) \
			or human_presentation.driver.resolve_playable_state("Dmg").is_empty():
		return false
	if is_instance_valid(training_target) and is_instance_valid(training_target.formal_attack): return false
	_human_damage_destroyed = is_destroyed
	_human_interrupt_actions = interrupt_actions
	return true

## 仅接 ClickMoveTest 明确的主角所有者与空死亡动作配置；碰撞体和相机不换宿主。
func bind_source_primary_death(owner: Object, material: Dictionary) -> bool:
	var source: Variant = material.get("primary_death")
	if _source_primary_death_owner!=null or not _human_interrupt_actions.is_valid() \
			or human_motion_binding==null or not human_motion_binding.uses_owner(owner) \
			or owner!=_aim_control or not is_instance_valid(human_presentation) \
			or human_presentation.driver.resolve_playable_state("SpinDie").is_empty() \
			or material.get("source_commit")!=SOURCE or not source is Dictionary:
		return false
	if not HumanPresentation.valid_primary_death(source): return false
	if not owner.bind_current_health_changed(_queue_source_primary_death): return false
	_source_primary_death_owner = owner
	return true

func _queue_source_primary_death(previous: int, current: int, _source: Variant) -> void:
	_human_damage_lifecycle.on_current_health_changed(previous,current)

func _commit_source_primary_death() -> void:
	var owner := _source_primary_death_owner
	if not owner.mark_source_primary_death(actor): return
	actor.reset_movement()
	if not human_presentation.driver.try_lock_animation("SpinDie"):
		push_error("原 ClickMoveTest 主角无法锁定 SpinDie。")
	# 该诊断没有对话、菜单或库存宿主；锁定场景的死亡动作本身确为空。
	# NotifyCharacterDied 清掉唯一控制对象，但镜头继续跟随实际主角。
	owner.set_current_controlled(false)
	notify_human_aim_input_disabled()
	_human_interrupt_actions.call()

func _prepare_human_training_damage(source: Variant, input: Dictionary, prepare: Callable) -> void:
	# 宿主记录原受击来源；仅非静默命中送表现和安全阶段，不在扣血前取消动作。
	prepare.call(source,input)
	if input.silent: return
	_human_damage_lifecycle.on_prepare_damage(false)
	if is_instance_valid(human_presentation) and not human_presentation.try_play_damage_animation():
		push_error("玩家正式 Dmg 动作无法播放")

func advance_human_damage_lifecycle() -> void:
	if not _human_damage_destroyed.is_valid() or not _human_interrupt_actions.is_valid(): return
	if is_instance_valid(_source_primary_death_owner):
		_human_damage_lifecycle.tick_safe(_source_primary_death_owner.current_health,_human_damage_destroyed,
			_human_interrupt_actions,_commit_source_primary_death)
	else:
		_human_damage_lifecycle.tick_safe_interrupt(_human_damage_destroyed,_human_interrupt_actions)

## 同一实际玩家的正式属性接收端；不依赖可选地表系统。
func start_training_basic_attack(player_direction: Callable, player_hooks: Dictionary, roll: Callable) -> Node:
	if not is_instance_valid(training_target) or not _training_tracking_stats.is_valid(): return null
	var hooks := player_hooks
	var prepare: Variant = hooks.get("prepare")
	if _human_interrupt_actions.is_valid() and prepare is Callable and prepare.is_valid():
		hooks = player_hooks.duplicate()
		hooks.prepare = _prepare_human_training_damage.bind(prepare)
	return training_target.bind_formal_basic_attack(actor,actor.get_node("受击盒"),
		_training_tracking_stats,player_direction,hooks,roll)

## 显式导入源图集；空资源不让角色获得假表现。
func start_training_target_presentation(animation: Dictionary, texture_directory: String,
		source_material: Dictionary = {}) -> Node2D:
	if not is_instance_valid(training_target): return null
	return training_target.start_presentation(animation,texture_directory,source_material)

## 兼容现有显式槽位契约：假人只在此入口担任已绑定的受击者。
## Caster 当前快照、掷骰和 ASC Cell 属于正式宿主；暴击/闪避来自锁定 GameConfig.asset。
func start_human_charged_training_combat(owner: Object, loadout: RefCounted, caster_stats: Callable,
		roll: Callable, target_root: Callable, target_cell: Callable, notify_rejected: Callable,
		include_basic: bool = false, include_flamethrower: bool = false) -> Node:
	if not is_instance_valid(training_target) or not caster_stats.is_valid() or not roll.is_valid() \
			or not target_root.is_valid() or not target_cell.is_valid(): return null
	var basic_hit_task := Callable()
	if include_basic:
		if not training_target.has_formal_target_direction(): return null
		basic_hit_task = _hit_basic_training_target.bind(owner,caster_stats,roll)
	var fire_hit_task := Callable()
	if include_flamethrower:
		if not training_target.has_formal_target_direction(): return null
		fire_hit_task = _hit_effect_2003_training_target.bind(owner,caster_stats,roll,FireTimeline.ATTACK_POLYGON,FireTimeline.HIT_MASK)
	var hit_task := _hit_training_target.bind(owner,caster_stats,roll)
	var resolve_root := func (target):
		if not is_instance_valid(training_target) or target != training_target: return target_root.call(target)
		var at: Vector2 = training_target.get_movement_position()
		return Vector3(at.x,at.y,0)
	return start_human_charged_combat(owner,loadout,hit_task,resolve_root,target_cell,notify_rejected,basic_hit_task,fire_hit_task)

func _hit_training_target(owner: Object, caster_stats: Callable, roll: Callable) -> void:
	if not is_instance_valid(training_target) or not is_instance_valid(owner) or not is_instance_valid(actor): return
	var start: Vector2 = actor.get_movement_position()
	ChargedHit.run(actor.get_world_2d(), actor, start, owner.get_look_at_direction(),
		func(collider): return training_target if is_instance_valid(training_target) and collider == training_target.hitbox else null,
		func(caster,target,effect_id):
			if effect_id == ChargedHit.EFFECT_ID:
				_training_effects.request(caster,target,_execute_training_damage.bind(caster_stats,roll)))

## Timeline 101 的命中任务使用真实角色和层 128 的子受击盒；
## 只连接本场景已有目标，不创建技能、角色、属性或方向。
func _hit_basic_training_target(owner: Object, caster_stats: Callable, roll: Callable) -> void:
	_hit_effect_2003_training_target(owner,caster_stats,roll,BasicTimeline.ATTACK_POLYGON,BasicTimeline.HIT_MASK)

func _hit_effect_2003_training_target(owner: Object, caster_stats: Callable, roll: Callable,
		polygon: Array, mask: int) -> void:
	if not is_instance_valid(training_target) or not is_instance_valid(owner) or not is_instance_valid(actor): return
	if not training_target.has_formal_target_direction() or not owner.has_method("get_look_at_direction") \
			or not caster_stats.is_valid() or not roll.is_valid():
		push_error("原 2003 命中缺少实际玩家出招朝向、目标逻辑方向、当前属性或随机源。")
		return
	var start: Vector2 = actor.get_movement_position()
	var facing: Vector2 = owner.get_look_at_direction()
	if not start.is_finite() or not facing.is_finite() or facing.length_squared() <= .0001: return
	for target in HitPolygon.query(actor.get_world_2d(),start,facing,PackedVector2Array(polygon),
			mask,actor,func(collider):
				return training_target if is_instance_valid(training_target) and collider == training_target.hitbox else null):
		_training_effects.request(actor,target,_execute_basic_training_damage.bind(caster_stats,roll))

## 每次任务都从场景施法者根和实际 look-at 重新读取，不使用按下 Q 时的指针。
func _apply_flamethrower_cone(owner: Object) -> void:
	if surface_elements == null or not is_instance_valid(actor) or not is_instance_valid(owner): return
	var facing: Vector2 = owner.get_look_at_direction()
	if not facing.is_finite() or facing.length_squared() <= .0001: return
	surface_elements.apply_cone(SurfaceElements.FIRE,actor.get_movement_position(),facing,
		FireTimeline.CONE_RANGE,FireTimeline.HALF_ANGLE,FireTimeline.INTENSITY,FireTimeline.EXPOSURE,
		actor,FireTimeline.SOURCE_ABILITY)

func _execute_basic_training_damage(caster: Node2D, target: Node2D, caster_stats: Callable, roll: Callable) -> void:
	if not is_instance_valid(actor) or caster != actor or not is_instance_valid(training_target) or target != training_target:
		return
	if not caster_stats.is_valid() or not roll.is_valid(): return
	var current: Variant = caster_stats.call()
	if not current is Dictionary or not current.get("snapshot") is Dictionary: return
	var read_pose := func() -> Dictionary:
		if not is_instance_valid(caster) or not is_instance_valid(target) or not target.has_formal_target_direction(): return {}
		return {"source_root":caster.get_movement_position(),"target_root":target.get_movement_position(),
			"target_direction":target.get_target_direction()}
	BasicDamage.execute_damage_phase(current,target.stats,target.hooks(caster),read_pose,true,true,roll)

func _execute_training_damage(caster: Node2D, target: Node2D, caster_stats: Callable, roll: Callable) -> void:
	if caster != actor or target != training_target or not caster_stats.is_valid() or not roll.is_valid(): return
	var current: Variant = caster_stats.call()
	if not current is Dictionary or not current.get("snapshot") is Dictionary: return
	# 目标在第12帧确定，根位置和角色属性由后续瞬时效果重新读取。
	ChargedDamage.execute_damage_phase(current,target.stats,target.hooks(caster),caster.get_movement_position(),
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
		if runtime == _charged_actor_runtime and _charged_timeline != null: _charged_timeline.flush_display()
		if runtime == _charged_actor_runtime and _basic_timeline != null: _basic_timeline.flush_display()
		if runtime == _charged_actor_runtime and _fire_timeline != null: _fire_timeline.flush_display()
	training_hit_cue.flush_display()

## 显式归一化 InputSystem 回调；不自造 PlayerInput 动作图切换或 GAS。
## resolve_context 返回 null 或当前输入目标的 {actor, command_context}。
func bind_human_gameplay_actions(resolve_context: Callable, interact_blocked: Callable, notify_failed: Callable) -> bool:
	if human_commands == null or _slot_keyboard != null: return false
	var candidate := preload("res://game_core/input/gameplay_command_actions.gd").new()
	if not candidate.configure(resolve_context,submit_human_command,interact_blocked,notify_failed): return false
	human_gameplay_actions = candidate
	_normalized_click_bound = false
	return true

## 键盘只接入已绑定的正式能力命令。普通移动预览不安装快捷键。
func bind_human_ability_keyboard() -> bool:
	if _slot_keyboard != null or human_gameplay_actions == null or _equipped_ability_dispatch == null:
		return false
	_slot_keyboard = SlotKeyboard.new()
	return true

func _dispatch_human_ability_key(slot: int, down: bool) -> void:
	receive_human_gameplay_action("Gameplay","FireAbility%d" % (slot+1),"performed" if down else "canceled")

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
	_slot_keyboard = null
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
	if request.get("kind")==CharacterExecutor.Kind.CLICK_MOVE:
		human_commands.terrain_map = _resolve_active_terrain()
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
	if _fire_timeline != null:
		_fire_timeline.stop()
		_fire_timeline = null
	_remove_flamethrower_visual()
	_fire_cue_actor = null
	_fire_cue_png = ""
	if _basic_timeline != null:
		_basic_timeline.stop()
		_basic_timeline = null
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
