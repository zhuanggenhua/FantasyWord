extends Node2D
## 锁定 ClickMoveTest 活跃训练假人的物理接线；属性和表现由显式拥有者提供。
## 不创建替代 GAS 属性，不用诊断矩形或绘制占位图冒充作者角色。
signal formal_provoked(source: Object, source_stats: Dictionary)
const TrainingAI = preload("res://gameplay/clickmovetest/training_ai_controller.gd")
const Body = preload("res://game_core/movement/native_motion_body.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Lifecycle = preload("res://game_core/combat/deferred_damage_lifecycle.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
const Bags = preload("res://game_core/inventory/source_inventory_bags.gd")
const Gear = preload("res://game_core/inventory/source_character_equipment.gd")
const HumanView = preload("res://gameplay/clickmovetest/human_presentation.gd")
const MotionBinding = preload("res://gameplay/clickmovetest/human_motion_binding.gd")
const VISUAL_PREFAB := "dca23ea6afacc0647bfd10c5cefa4099"
const VISUAL_LIBRARIES := ["62c4a52ab213438419c93cc2d8427623","0602b79d46e41504a8117d1fdcc863b2",
	"aaefe509e84579b4782b521a1d156e71","9ea72d0165623924d891e3222ac25d48"]
const SOURCE_IDENTIFIER := "5c992e86-45d1-4152-ab59-4e245f2b5d9a"
const SOURCE_POSITION := Vector2(2.5, -2.75)
const BODY_SIZE := Vector2(.78, .86)
const BODY_OFFSET := Vector2(0, .42)
const HIT_SIZE := Vector2(.6, 1)
const HIT_OFFSET := Vector2(0, .5)
var body: AnimatableBody2D
var presentation: Node2D
var _presentation_motion: RefCounted
var source_gear: Gear
var _source_bags: Bags
var hitbox: Area2D
var lifecycle := Lifecycle.new()
var ai_controller := TrainingAI.new()
var _bindings: Dictionary = {}
var _external_health_signal := false
var _death_committed := false
var _verified_death_animation := false
var _movement_owner: Object
var formal_attack: Node
var _terrain_mask := 0
var _wall_recovery_distance := 0.0
var stats: Dictionary:
	get: return _bindings.stats.call()
var health: int:
	get: return _bindings.current_health.call()

static func initial_sheet() -> Dictionary:
	# EStat 数组顺序来自 Stats.cs；最后一项是攻击速度，不能遗漏为零。
	return {"alignment":Combat.Alignment.EVIL, "health":220, "mana":0,
		"physical_attack":0, "magical_attack":0, "physical_defense":0,
		"magical_defense":0, "agility":0, "luck":0, "attack_speed":100}

func configure(bindings: Dictionary, movement_owner: Object, terrain_mask: int, wall_recovery_distance: float) -> bool:
	if not _bindings.is_empty() or is_inside_tree() or not is_instance_valid(movement_owner):
		return false
	for key in ["stats","current_health","has_formal_stats","apply_current_health_delta",
			"impact","provoke","prepare","complete","is_destroyed","interrupt_actions","mark_death"]:
		if not bindings.get(key) is Callable or not bindings[key].is_valid():
			return false
	for method in ["can_move","calculate_move_speed","calculate_speed_multiplier",
			"update_movement_animation","update_facing_from_intent","register_collision"]:
		if not movement_owner.has_method(method): return false
	if terrain_mask <= 0 or not is_finite(wall_recovery_distance) or wall_recovery_distance < 0.0: return false
	_bindings = bindings.duplicate()
	_movement_owner = movement_owner
	_terrain_mask = terrain_mask
	_wall_recovery_distance = wall_recovery_distance
	position = Vector2(SOURCE_POSITION.x, -SOURCE_POSITION.y)
	return true

func _ready() -> void:
	assert(not _bindings.is_empty(), "训练假人缺少显式属性/控制器拥有者，不能在 Entry 中创建替代状态")
	body = Body.new()
	body.name = "训练假人物理身体"
	body.collision_layer = 256 # 0_Character_Base 对根对象的 m_Layer=8 覆盖。
	body.collision_mask = 0 # 地形查询由既有 TerrainCast 的显式 mask 负责。
	var capsule := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = BODY_SIZE.x / 2
	shape.height = BODY_SIZE.y
	capsule.shape = shape
	capsule.position = Vector2(BODY_OFFSET.x, -BODY_OFFSET.y)
	body.add_child(capsule)
	add_child(body)
	body.configure_movement(capsule, Filter.new(Filter.Mode.FREE,false,.05,10,10),
		self, _terrain_mask, _wall_recovery_distance)
	hitbox = Area2D.new()
	hitbox.name = "训练假人受击盒"
	hitbox.collision_layer = 128
	hitbox.collision_mask = 0
	hitbox.set_meta("actor", self)
	var hit_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = HIT_SIZE
	hit_shape.shape = rectangle
	hit_shape.position = Vector2(HIT_OFFSET.x, -HIT_OFFSET.y)
	hitbox.add_child(hit_shape)
	body.add_child(hitbox)
	# 源场景的活动实例以显式 AIController 覆盖默认控制器；OnEnable 启动。
	ai_controller.start(self)

## 锁定训练假人的 Runtime DirectionalSpriteLibraryDriver 使用原 Human 四向库，
## 表现挂在身体局部原点；不使用胶囊的中心偏移。
func start_presentation(animation: Dictionary, texture_directory: String, source_material: Dictionary = {}) -> Node2D:
	if _presentation_motion != null or not is_instance_valid(body) or not body.is_inside_tree(): return null
	var provenance: Variant = animation.get("training_target")
	if not provenance is Dictionary or provenance.get("prefab_guid") != VISUAL_PREFAB \
			or provenance.get("runtime_libraries") != VISUAL_LIBRARIES: return null
	var pivot: Variant = provenance.get("body_local_position")
	if not pivot is Array or pivot.size()!=2 or pivot[0]!=0 or pivot[1]!=0: return null
	var view := HumanView.new()
	body.add_child(view)
	if not view.configure(animation,texture_directory) or view.driver.resolve_playable_state("Dmg").is_empty():
		view.free()
		return null
	# 完整私有材质来自同一假人动作合同；传入却无效时不降级成原图直显。
	if not source_material.is_empty():
		var effects: String = source_material.get("effects", "")
		if not source_material.get("data") is Dictionary or not source_material.get("uv_directory") is String \
				or not source_material.get("appearance_directory") is String \
				or not view.bind_base_material(source_material.data,source_material.uv_directory,source_material.appearance_directory,not effects.is_empty()):
			view.free()
			return null
		if not effects.is_empty():
			var gear := Gear.new()
			var bags: Bags = source_material.get("bags")
			var canonical: Dictionary = source_material.get("items",{})
			if bags==null or canonical.is_empty() \
					or not gear.start(self,func():return health,func():return not _death_committed,false,canonical) \
					or not view.bind_source_cloth(gear,source_material.get("cloth","")) \
					or not view.bind_source_trainer_render(gear,source_material.get("spear",""),effects):
				printerr(view.last_error)
				view.free()
				return null
			source_gear = gear
			_source_bags = bags
	var motion := MotionBinding.new()
	if not motion.configure(_movement_owner,view,false):
		view.free()
		return null
	_verified_death_animation = provenance.get("death_animation_key") == "SpinDie"
	if _verified_death_animation and view.driver.resolve_playable_state("SpinDie").is_empty():
		view.free()
		return null
	_presentation_motion = motion
	presentation = view
	motion.activate()
	return view

func _exit_tree() -> void:
	ai_controller.stop()
	if _presentation_motion != null:
		_presentation_motion.detach()
		_presentation_motion = null

# 原动作拥有者仍裁决移动、碰撞和朝向；表现只收到实际接受的位移。
func can_move() -> bool: return not _death_committed and is_instance_valid(_movement_owner) and _movement_owner.can_move()
func calculate_move_speed() -> float: return _movement_owner.calculate_move_speed()
func calculate_speed_multiplier() -> float: return _movement_owner.calculate_speed_multiplier()
func update_facing_from_intent(value: Vector2) -> void: _movement_owner.update_facing_from_intent(value)
func register_collision(collider: Object) -> void: _movement_owner.register_collision(collider)
func update_movement_animation(value: Vector2) -> void:
	if _presentation_motion != null and is_instance_valid(presentation):
		_presentation_motion.update_movement_animation(value)
	elif is_instance_valid(_movement_owner):
		_movement_owner.update_movement_animation(value)

func uses_movement_owner(owner: Object) -> bool:
	return is_instance_valid(_movement_owner) and _movement_owner == owner

func get_movement_position() -> Vector2: return body.get_movement_position()
func source_position() -> Vector2: return get_movement_position()

func bind_formal_health_changes(properties: RefCounted) -> void:
	# CharacterBase subscribes to formal CurrentHealth, not to one attack.
	_external_health_signal = true
	properties.current_health_changed.connect(_on_formal_health_changed)

func _on_formal_health_changed(previous: int, current: int, _source: Variant) -> void:
	lifecycle.on_current_health_changed(previous,current)

func hooks(source_actor: Object = null) -> Dictionary:
	var result := _bindings.duplicate()
	var source_identity: WeakRef = weakref(source_actor) if is_instance_valid(source_actor) else null
	result.provoke = func(source_stats):
		# 执行器在影响/推力后、扣血前调用。未知来源不触发角色事件；
		# 快照用于当刻目标判定，不可作为 AI 存储的角色身份。
		var source: Object = source_identity.get_ref() if source_identity != null else null
		if is_instance_valid(source) and source_stats is Dictionary:
			formal_provoked.emit(source,source_stats)
		_bindings.provoke.call(source_stats)
	result.prepare = func(source, input):
		lifecycle.on_prepare_damage(input.silent)
		_bindings.prepare.call(source,input)
		if not input.silent and is_instance_valid(presentation):
			if not presentation.try_play_damage_animation():
				push_error("训练假人的正式 Dmg 动画无法播放")
	result.apply_current_health_delta = func(delta, minimum, maximum, source):
		var previous: int = health
		var value: Variant = _bindings.apply_current_health_delta.call(delta,minimum,maximum,source)
		if value is int and not _external_health_signal:
			lifecycle.on_current_health_changed(previous,value)
		return value
	return result

func advance_damage_lifecycle() -> void:
	lifecycle.tick_safe(_bindings.current_health, _bindings.is_destroyed,
		_interrupt_actions, _finish_death)

func bind_formal_basic_attack(player: Node2D, hitbox: Area2D, stats_reader: Callable,
		direction_reader: Callable, player_hooks: Dictionary, roll: Callable) -> Node:
	if formal_attack != null: return null
	var candidate := preload("res://gameplay/clickmovetest/training_formal_attack.gd").new()
	add_child(candidate)
	if not candidate.configure(self,_movement_owner,player,hitbox,stats_reader,direction_reader,player_hooks,roll) 			or not ai_controller.bind_formal_attack(candidate.attempt):
		candidate.free()
		return null
	formal_attack = candidate
	return formal_attack

func advance_formal_basic_attack(delta: float) -> void:
	if is_instance_valid(formal_attack) and ai_controller.running: formal_attack.advance(delta)

## 正式场景只问这个假人已有的 20001，不复制攻击状态，也不借主角技能。
func allows_basic_attack_target_direction() -> bool:
	if formal_attack == null: return true
	return is_instance_valid(formal_attack) and formal_attack.runtime.can_update_fresh_target_direction()

func allows_basic_attack_movement() -> bool:
	if formal_attack == null: return true
	return is_instance_valid(formal_attack) and formal_attack.runtime.allows_fresh_movement()

func _interrupt_actions() -> void:
	_bindings.interrupt_actions.call()
	if is_instance_valid(formal_attack): formal_attack.interrupt()

func _finish_death() -> void:
	# 原 Movable.Kill 先停活动控制器，再标记、重置移动、播放死亡动作。
	# mark_death 是之后的 CharacterActor.OnDeath 宿主回调。
	if _source_bags!=null: _source_bags.transfer_character_inventory_to_corpse(SOURCE_IDENTIFIER)
	ai_controller.stop()
	_death_committed = true
	if is_instance_valid(body): body.reset_movement()
	if _verified_death_animation and is_instance_valid(presentation):
		if not presentation.driver.try_lock_animation("SpinDie"):
			push_error("训练假人的正式 SpinDie 死亡动作无法锁定")
	_bindings.mark_death.call()
	if _source_bags!=null: _source_bags.transfer_character_equipment_to_corpse(self,SOURCE_IDENTIFIER,source_gear)
	# CharacterBase.Kill 在 Movable 死亡与宿主回调后仍发出 InterruptInstances。
	# 即使没有非静默受击的待打断标记，假人的实际 Timeline 也不能留在攻击中。
	if is_instance_valid(formal_attack): formal_attack.interrupt()

## 背刺只取逻辑方向，不能用绘制朝向或碰撞体方向代替。
func has_formal_target_direction() -> bool:
	return is_instance_valid(_movement_owner) and _movement_owner.has_method("get_target_direction")

func get_target_direction() -> Vector2:
	return _movement_owner.get_target_direction()

func advance_movement(delta: float, ramp_direction: Callable = Callable()) -> void:
	body.advance_movement(delta,ramp_direction)


# 转向前向和身体朝向走正式移动 owner；转向速度方向不替代 LookAt。
func has_transit_facing_owner() -> bool:
	return is_instance_valid(_movement_owner) and _movement_owner.has_method("get_look_at_direction") \
		and _movement_owner.has_method("set_look_at_direction")

func get_transit_look() -> Vector2:
	return _movement_owner.get_look_at_direction()

func set_transit_look(direction: Vector2) -> void:
	_movement_owner.set_look_at_direction(direction)
