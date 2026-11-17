extends Node2D
## 锁定 ClickMoveTest 活跃训练假人的物理接线；属性、AI、表现仍由显式拥有者提供。
## 不创建替代 GAS 属性，不用诊断矩形或绘制占位图冒充作者角色。
const Body = preload("res://game_core/movement/native_motion_body.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Lifecycle = preload("res://game_core/combat/deferred_damage_lifecycle.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
const HumanView = preload("res://gameplay/clickmovetest/human_presentation.gd")
const MotionBinding = preload("res://gameplay/clickmovetest/human_motion_binding.gd")
const VISUAL_PREFAB := "dca23ea6afacc0647bfd10c5cefa4099"
const VISUAL_LIBRARIES := ["62c4a52ab213438419c93cc2d8427623","0602b79d46e41504a8117d1fdcc863b2",
	"aaefe509e84579b4782b521a1d156e71","9ea72d0165623924d891e3222ac25d48"]
const SOURCE_POSITION := Vector2(2.5, -2.75)
const BODY_SIZE := Vector2(.78, .86)
const BODY_OFFSET := Vector2(0, .42)
const HIT_SIZE := Vector2(.6, 1)
const HIT_OFFSET := Vector2(0, .5)
var body: AnimatableBody2D
var presentation: Node2D
var _presentation_motion: RefCounted
var hitbox: Area2D
var lifecycle := Lifecycle.new()
var _bindings: Dictionary = {}
var _movement_owner: Object
var _terrain_mask := 0
var stats: Dictionary:
	get: return _bindings.stats.call()
var health: int:
	get: return _bindings.current_health.call()

static func initial_sheet() -> Dictionary:
	# EStat 数组顺序来自 Stats.cs；最后一项是攻击速度，不能遗漏为零。
	return {"alignment":Combat.Alignment.EVIL, "health":220, "mana":0,
		"physical_attack":0, "magical_attack":0, "physical_defense":0,
		"magical_defense":0, "agility":0, "luck":0, "attack_speed":100}

func configure(bindings: Dictionary, movement_owner: Object, terrain_mask: int) -> bool:
	if not _bindings.is_empty() or is_inside_tree() or not is_instance_valid(movement_owner):
		return false
	for key in ["stats","current_health","has_formal_stats","apply_current_health_delta",
			"impact","provoke","prepare","complete","is_destroyed","interrupt_actions","mark_death"]:
		if not bindings.get(key) is Callable or not bindings[key].is_valid():
			return false
	for method in ["can_move","calculate_move_speed","calculate_speed_multiplier",
			"update_movement_animation","update_facing_from_intent","register_collision"]:
		if not movement_owner.has_method(method): return false
	if terrain_mask <= 0: return false
	_bindings = bindings.duplicate()
	_movement_owner = movement_owner
	_terrain_mask = terrain_mask
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
		self, _terrain_mask)
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

## 锁定训练假人的 Runtime DirectionalSpriteLibraryDriver 使用原 Human 四向库，
## 表现挂在身体局部原点；不使用胶囊的中心偏移。
func start_presentation(animation: Dictionary, texture_directory: String) -> Node2D:
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
	var motion := MotionBinding.new()
	if not motion.configure(_movement_owner,view,false):
		view.free()
		return null
	_presentation_motion = motion
	presentation = view
	motion.activate()
	return view

func _exit_tree() -> void:
	if _presentation_motion != null:
		_presentation_motion.detach()
		_presentation_motion = null

# 原动作拥有者仍裁决移动、碰撞和朝向；表现只收到实际接受的位移。
func can_move() -> bool: return is_instance_valid(_movement_owner) and _movement_owner.can_move()
func calculate_move_speed() -> float: return _movement_owner.calculate_move_speed()
func calculate_speed_multiplier() -> float: return _movement_owner.calculate_speed_multiplier()
func update_facing_from_intent(value: Vector2) -> void: _movement_owner.update_facing_from_intent(value)
func register_collision(collider: Object) -> void: _movement_owner.register_collision(collider)
func update_movement_animation(value: Vector2) -> void:
	if _presentation_motion != null and is_instance_valid(presentation):
		_presentation_motion.update_movement_animation(value)
	elif is_instance_valid(_movement_owner):
		_movement_owner.update_movement_animation(value)

func get_movement_position() -> Vector2: return body.get_movement_position()
func source_position() -> Vector2: return get_movement_position()

func hooks() -> Dictionary:
	var result := _bindings.duplicate()
	result.prepare = func(source, input):
		lifecycle.on_prepare_damage(input.silent)
		_bindings.prepare.call(source,input)
		if not input.silent and is_instance_valid(presentation):
			if not presentation.try_play_damage_animation():
				push_error("训练假人的正式 Dmg 动画无法播放")
	result.apply_current_health_delta = func(delta, minimum, maximum, source):
		var previous: int = health
		var value: Variant = _bindings.apply_current_health_delta.call(delta,minimum,maximum,source)
		if value is int:
			lifecycle.on_current_health_changed(previous,value)
		return value
	return result

func advance_damage_lifecycle() -> void:
	lifecycle.tick_safe(_bindings.current_health, _bindings.is_destroyed,
		_bindings.interrupt_actions, _bindings.mark_death)

func advance_movement(delta: float, ramp_direction: Callable = Callable()) -> void:
	body.advance_movement(delta,ramp_direction)
