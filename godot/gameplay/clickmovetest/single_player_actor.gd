extends RefCounted
## ClickMoveTest 原主玩家的单角色运行合同，锁定 31629d53。
## PlayerSystem 提供实体身份；CharacterPlayerControl 和 Movable 分别裁决控制与朝向。
## 不实例化 Actor、不接队伍/存档/ASC，不执行尚未迁移的玩家死亡行动。
const PlayerBody = preload("res://gameplay/clickmovetest/actor.gd")
const Direction = preload("res://game_core/presentation/movable_direction_state.gd")
const Attributes = preload("res://gameplay/clickmovetest/training_damage_attributes.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
const Equipment = preload("res://game_core/inventory/source_character_equipment.gd")
const Loadout = preload("res://game_core/combat/equipped_ability_loadout.gd")
const PersistenceRegistry = preload("res://game_core/persistence/persistable_identity_registry.gd")
const SOURCE_ACTOR := "735002000000000004"
const SOURCE_PREFAB := "f32187b1edab1484a99d97ef54021bf5"
const SOURCE_SHEET := "13245a7230bedbe4da633d5325872ce1"
const SOURCE_PREINSTANCED_IDENTIFIER := "6b7f0021-a37d-413c-ad2e-947903b4e6f5"
const UNIQUE_PLAYER_IDENTIFIER := "player"
# Locked CharacterSheet displayName falls back to the asset name; this port
# models only the fresh level, not progression or old-save restoration.
const _FRESH_DISPLAY_NAME := "玩家角色配置"
const _FRESH_LEVEL := 1
const BASE_MOVE_SPEED := 4.0
const BASE_SPEED_MULTIPLIER := 1.0
# 31629d53：玩家角色配置在初始等级 1 授予 20001，玩家角色.prefab 再声明 20001、20010。
const _LEVEL_ONE_SHEET_ABILITIES := [20001]
const _PREFAB_EXTRA_ABILITIES := [20001,20010]
const _ABILITY_SLOT_COUNT := 5
# 原 0.05f * 0.05f；显式舍入避免脚本文字浮点解析在相等边界产生误差。
static var _movement_idle_squared: float = PackedFloat32Array([0.002500000176951289])[0]

signal controlled_character_changed(actor: Node2D)
signal equipped_abilities_changed(slots: Array)
signal player_input_disabled
signal look_at_direction_changed(value: Vector2)
signal target_direction_changed(value: Vector2)
signal accepted_movement(velocity: Vector2)
signal collision_reported(collider: Object)
signal provoked(source: Variant)
signal damage_prepared(source: Variant, input: Dictionary)
signal damage_completed(source: Variant, input: Dictionary, previous_health: int, applied: int)

var _primary: WeakRef
var _primary_exited := false
var _primary_death_committed := false
var _selected := false
var _accepts := true
var _directions := Direction.new()
var _attributes := Attributes.new()
var _equipment: Equipment
var _change_equipment_enabled := true
var _read_pointer: Callable
var _refresh_interaction: Callable
var _reset_interaction: Callable
var _read_destroyed: Callable
var _persistence_registry: PersistenceRegistry
var _fresh_loadout: Loadout
var _fresh_owned_ability_codes: Array[int] = []
var _fresh_ability_host: WeakRef
var _binding_initial_loadout := false
var _restoring_living_save := false

func configure(actor: Node2D, pointer_reader: Callable = Callable(),
		refresh_interaction: Callable = Callable(), reset_interaction: Callable = Callable(),
		read_destroyed: Callable = Callable()) -> bool:
	if _primary != null or not is_instance_valid(actor) or not actor is PlayerBody or not actor.is_inside_tree():
		return false
	# 缺能力可以显式不安装；失效的非空引用不能冒充未安装。
	for callback: Callable in [pointer_reader,refresh_interaction,reset_interaction,read_destroyed]:
		if not callback.is_null() and not callback.is_valid(): return false
	# 玩家角色配置.asset m_baseStats：按 Stats.cs 的原顺序解码，未开启等级成长。
	if not _attributes.configure(PackedInt32Array([100,40,10,6,6,4,8,4,100]),
			Combat.Alignment.GOOD,_no_active_invincibility):
		return false
	_primary = weakref(actor)
	_read_pointer = pointer_reader
	_refresh_interaction = refresh_interaction
	_reset_interaction = reset_interaction
	_read_destroyed = read_destroyed
	_directions.look_at_direction_changed.connect(_on_look_changed)
	_directions.target_direction_changed.connect(_on_target_changed)
	actor.tree_exiting.connect(_on_actor_exiting,CONNECT_ONE_SHOT)
	# 原 PlayerSystem.OnSystemStart 把当前控制恢复为显式主角。
	_selected = true
	controlled_character_changed.emit(actor)
	return true

## PlayerSystem.OnSystemStart: after validating the actual loaded primary and
## configured input, reset control and replace its authored handler with player.
func register_primary_persistence(registry: PersistenceRegistry) -> bool:
	var actor := _get_primary()
	if registry == null or _persistence_registry != null or not is_instance_valid(actor) \
			or not accepts_player_input(actor) or not can_be_player_controlled(actor):
		return false
	if not set_current_controlled(true): return false
	if not registry.register_custom_instanced(actor,UNIQUE_PLAYER_IDENTIFIER): return false
	_persistence_registry = registry
	return true


## 原动作位独立于控制对象、暂停、移动和技能的门禁。
func set_change_equipment_enabled(enabled: bool) -> void:
	_change_equipment_enabled=enabled

func _can_change_source_equipment() -> bool:
	return _change_equipment_enabled

func start_source_equipment() -> bool:
	if _equipment!=null: return false
	var gear := Equipment.new()
	if not gear.start(_get_primary(),current_health,_can_change_source_equipment): return false
	_equipment=gear
	return true

func source_equipment() -> Equipment:
	return _equipment


func get_player_provider() -> RefCounted: return self

func get_current_controlled_character_or_player_instance() -> Node2D:
	# 单角色切片只有主角可注册。失控时主角仍可作为相机的 fallback。
	return _get_primary()

func is_current_controlled(actor: Node2D) -> bool:
	return _selected and is_instance_valid(actor) and actor == _get_primary()

func set_current_controlled(selected: bool) -> bool:
	var actor := _get_primary()
	if not is_instance_valid(actor): return false
	if selected and not can_be_player_controlled(actor): return false
	if _selected == selected and not selected: return true
	_selected = selected
	controlled_character_changed.emit(actor if selected else null)
	return true

func accepts_player_input(actor: Node2D) -> bool:
	return _accepts and is_instance_valid(actor) and actor == _get_primary()

func set_accepts_player_input(accepts: bool) -> void:
	_accepts = accepts
	# CharacterPlayerControl.SetAcceptsPlayerInput(false) 立即清理；Entry 已有正式重置入口。
	if not accepts: player_input_disabled.emit()

func can_be_player_controlled(actor: Node2D) -> bool:
	# 当前没有未迁移的 Alteration 运行时，不能把这个切片当成一般控制组。
	return is_instance_valid(actor) and actor == _get_primary() and current_health() > 0

func refresh_interaction_target(actor: Node2D) -> void:
	if is_current_controlled(actor) and _refresh_interaction.is_valid(): _refresh_interaction.call(actor)

func reset_interaction_target(actor: Node2D) -> void:
	if is_instance_valid(actor) and actor == _get_primary() and _reset_interaction.is_valid():
		_reset_interaction.call(actor)

func read_active_gameplay_pointer() -> Variant:
	var actor := _get_primary()
	if not accepts_player_input(actor) or not is_current_controlled(actor) or not _read_pointer.is_valid():
		return null
	return _read_pointer.call()

func can_move() -> bool:
	if not is_instance_valid(_get_primary()) or is_destroyed(): return false
	var host: Object = _fresh_ability_host.get_ref() if _fresh_ability_host != null else null
	return not is_instance_valid(host) or host.allows_fresh_movement()
func calculate_move_speed() -> float: return BASE_MOVE_SPEED
func calculate_speed_multiplier() -> float: return BASE_SPEED_MULTIPLIER
func can_update_target_direction() -> bool:
	if not is_instance_valid(_get_primary()) or is_destroyed(): return false
	var host: Object = _fresh_ability_host.get_ref() if _fresh_ability_host != null else null
	return not is_instance_valid(host) or host.can_update_fresh_target_direction()

func bind_fresh_target_direction_guard(host: Node) -> bool:
	if _fresh_loadout == null or _fresh_ability_host != null or not is_instance_valid(host) \
			or not host.has_method("can_update_fresh_target_direction"):
		return false
	if not host.has_method("allows_fresh_movement"): return false
	_fresh_ability_host = weakref(host)
	return true

func can_interact() -> bool: return is_instance_valid(_get_primary()) and not is_destroyed()

func update_facing_from_intent(value: Vector2) -> void:
	# 原 MovementBased：用原方向阈值，速度和指针目标不会替代身体朝向。
	if value.length_squared() > _movement_idle_squared:
		set_look_at_direction(value.normalized())

func set_look_at_direction(value: Vector2) -> void: _directions.set_look_at_direction(value)
func get_look_at_direction() -> Vector2: return _directions.get_look_at_direction()
func set_target_direction(value: Vector2) -> void: _directions.set_target_direction(value,can_update_target_direction())
func get_target_direction() -> Vector2: return _directions.get_target_direction()
func reset_target_direction() -> void: _directions.reset_target_direction()
func update_movement_animation(velocity: Vector2) -> void: accepted_movement.emit(velocity)
func register_collision(collider: Object) -> void: collision_reported.emit(collider)
func stats() -> Dictionary: return _attributes.stats()
## SaveSystem reads PlayerSystem's explicit primary, even when unselected.
func source_primary_save_title_fields() -> Dictionary:
	var actor := _get_primary()
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or _persistence_registry==null \
			or _persistence_registry.identifier_for(actor)!=UNIQUE_PLAYER_IDENTIFIER \
			or _persistence_registry.resolve(UNIQUE_PLAYER_IDENTIFIER)!=actor \
			or not _attributes.has_formal_stats():
		return {}
	return {"display_name":_FRESH_DISPLAY_NAME,"level":_FRESH_LEVEL}

## The numbered ClickMoveTest actor has no migrated level-up/save mutations.
## Admit only its pinned fresh profile, and read stats from the same live owner
## used for combat. This does not inspect an unrelated actor or HUD HP value.
func character_menu_fresh_values(target: Object, profile: Dictionary) -> Dictionary:
	if not is_instance_valid(target) or target!=_get_primary() or profile.get("source_commit")!= \
			"31629d53a110dd4c87d4c85e6ad5a387fbafb931" or profile.get("actor_file_id")!="735002000000000004" \
			or profile.get("sheet_guid")!="13245a7230bedbe4da633d5325872ce1": return {}
	var authored: Variant = profile.get("fresh")
	if not authored is Dictionary or authored.get("level")!=_FRESH_LEVEL or authored.get("minimum_level")!=1 \
			or authored.get("points_per_level")!=5 or authored.get("used_points")!=0 \
			or authored.get("experience")!=0 or authored.get("next_level_experience")!=0 \
			or authored.get("display_name")!=_FRESH_DISPLAY_NAME: return {}
	var stats_array := _attributes.menu_base_stats()
	var expected: Variant = authored.get("base_stats")
	if stats_array.size()!=8 or not expected is Array or expected.size()!=9: return {}
	for i in range(8):
		if expected[i]!=stats_array[i]: return {}
	var stats: Array = []
	for stat in stats_array: stats.append(stat)
	return {"display_name":str(authored.display_name),"level":int(authored.level),"experience":int(authored.experience),
		"next_level_experience":int(authored.next_level_experience),
		"available_points":int(authored.points_per_level)*(int(authored.level)-int(authored.minimum_level))-int(authored.used_points),
		"base_stats":stats}

## Inventory UIStat reads effective values. This actor's fresh two equipped
## entries have zero stat modifiers; this slice admits no buffs or nonzero gear bonuses.
func inventory_fresh_stats(actor: Node) -> Array[int]:
	if not is_instance_valid(actor) or actor!=_get_primary(): return []
	return _attributes.menu_base_stats()

func current_health() -> int: return _attributes.current_health()

## 原 UIStatBar 从当前目标的正式属性所有者同时读取当前值、上限。
func resource_bar_values(actor: Node2D) -> PackedInt32Array:
	if not is_instance_valid(actor) or actor!=_get_primary(): return PackedInt32Array()
	return PackedInt32Array([_attributes.current_health(),_attributes.max_health(),
		_attributes.current_mana(),_attributes.max_mana()])

# Only the source primary's already ported save fields. A partial receipt
# is never admitted as CharacterActorRuntimeStateData or sent to file storage.
func capture_source_player_save_fields() -> Dictionary:
	var actor := _get_primary()
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or _persistence_registry==null \
			or _persistence_registry.identifier_for(actor)!=UNIQUE_PLAYER_IDENTIFIER \
			or _persistence_registry.resolve(UNIQUE_PLAYER_IDENTIFIER)!=actor or is_destroyed() \
			or _attributes.current_health()<=0 or not _attributes.has_formal_stats() \
			or _equipment==null or not _equipment.belongs_to(actor):
		return {"ok":false,"reason":"primary_state_outside_supported_scope"}
	var slots: Array[Dictionary] = []
	for slot in range(Equipment.Slot.WEAPON,Equipment.Slot.MOUNT+1):
		var item := _equipment.equipped(slot)
		if item==null: continue
		var guid := ""
		if slot==Equipment.Slot.WEAPON and item==_equipment.item_for_guid(Equipment.SPEAR): guid=Equipment.SPEAR
		if slot==Equipment.Slot.TORSO and item==_equipment.item_for_guid(Equipment.CLOTH): guid=Equipment.CLOTH
		if guid.is_empty(): return {"ok":false,"reason":"equipment_outside_source_registry"}
		slots.append({"slotType":slot,"equipment":{"guid":guid}})
	return {"ok":true,"fields":{"identifier":UNIQUE_PLAYER_IDENTIFIER,
		"currentResources":{"health":_attributes.current_health(),"mana":_attributes.current_mana()},
		"equipmentSlots":slots}}

# Logical living subset; never apply a half snapshot from an original file.
# Stats are already resolved for these exact zero-contribution items. The
# source makes equipment visible as one loadout change before rebuilding HP/MP.
func restore_source_player_save_fields(fields: Variant) -> bool:
	if _restoring_living_save or not fields is Dictionary or fields.size()!=3 \
			or fields.get("identifier")!=UNIQUE_PLAYER_IDENTIFIER \
			or not fields.get("currentResources") is Dictionary or not fields.get("equipmentSlots") is Array:
		return false
	if not capture_source_player_save_fields().ok: return false
	var actor := _get_primary() as PlayerBody
	var host: Object = _fresh_ability_host.get_ref() if _fresh_ability_host!=null else null
	if not is_current_controlled(actor) or not accepts_player_input(actor) or actor.is_pushed() \
			or actor.execution.has_active_movement_intent() or not actor.get_movement_linear_velocity().is_zero_approx() \
			or not is_instance_valid(host) or not host.has_method("is_idle_for_living_save_restore") \
			or not host.is_idle_for_living_save_restore():
		return false
	var resources: Dictionary = fields.currentResources
	if resources.size()!=2 or not resources.get("health") is int or not resources.get("mana") is int:
		return false
	var health := clampi(resources.health,0,_attributes.max_health())
	var mana := clampi(resources.mana,0,_attributes.max_mana())
	if health<=0: return false
	var parsed := {}
	for row: Variant in fields.equipmentSlots:
		if not row is Dictionary or row.size()!=2 or not row.get("slotType") is int \
				or not row.get("equipment") is Dictionary or row.equipment.size()!=1:
			return false
		var slot: int = row.slotType
		var guid: Variant = row.equipment.get("guid")
		if parsed.has(slot) or not guid is String: return false
		if not ((slot==Equipment.Slot.WEAPON and guid==Equipment.SPEAR) \
				or (slot==Equipment.Slot.TORSO and guid==Equipment.CLOTH)): return false
		var item := _equipment.item_for_guid(guid)
		if item==null: return false
		parsed[slot]=item
	_restoring_living_save=true
	_equipment._replace_saved_living_slots(parsed)
	_attributes._restore_living_resources(health,mana,actor)
	_restoring_living_save=false
	return true

func unbind_current_health_changed(callback: Callable) -> void:
	if _attributes.current_health_changed.is_connected(callback):
		_attributes.current_health_changed.disconnect(callback)

func is_destroyed() -> bool:
	# HP 归零是源 dead，真正销毁须等待外部安全死亡所有者。
	return _primary_death_committed or (not _read_destroyed.is_null() \
		and (not _read_destroyed.is_valid() or bool(_read_destroyed.call())))

func bind_current_health_changed(callback: Callable) -> bool:
	if not is_instance_valid(_get_primary()) or not callback.is_valid() or _attributes.current_health_changed.is_connected(callback):
		return false
	_attributes.current_health_changed.connect(callback)
	return true

## Movable.MarkAsDestroyed 在动作锁定之前；只保留实际主角，不删除绑定和持久标识。
func mark_source_primary_death(actor: Node2D) -> bool:
	if actor==null or actor!=_get_primary() or current_health()!=0 or is_destroyed(): return false
	_primary_death_committed = true
	return true

func damage_hooks() -> Dictionary:
	return {"provoke":_on_provoked,"has_formal_stats":_attributes.has_formal_stats,
		"current_health":_attributes.current_health,"prepare":_on_damage_prepared,
		"apply_current_health_delta":_attributes.apply_current_health_delta,"complete":_on_damage_completed}

## CharacterBase.InitializeAbilities → CharacterAbilitySet 的新角色分配切片。
## 调用方的正式角色能力宿主负责构建/解析活跃实例；本入口不创建 ASC 或幽灵技能。
## 不自动执行在移动/假人诊断，也不能代替存档的槽位覆盖流程。
func bind_fresh_ability_loadout(create_or_resolve_owned_active: Callable) -> Loadout:
	if not is_instance_valid(_get_primary()) or _fresh_loadout != null or _binding_initial_loadout \
			or not create_or_resolve_owned_active.is_valid():
		return null
	_binding_initial_loadout = true
	var candidate := Loadout.new(_ABILITY_SLOT_COUNT)
	var requested := {}
	var owned: Array[int] = []
	for code: int in _LEVEL_ONE_SHEET_ABILITIES + _PREFAB_EXTRA_ABILITIES:
		if requested.has(code): continue
		requested[code] = true
		var runtime: Variant = create_or_resolve_owned_active.call(code)
		if not is_instance_valid(_get_primary()): break
		if runtime is Object and is_instance_valid(runtime):
			owned.append(code)
			candidate.try_auto_assign_formal_gas_ability_code(code)
	_binding_initial_loadout = false
	if not is_instance_valid(_get_primary()): return null
	_fresh_loadout = candidate
	_fresh_owned_ability_codes = owned
	return _fresh_loadout

## CharacterBase.Abilities 只投影实际角色的能力实例和同一个可操作的快捷槽。
## 初始菜单不从槽位反推所有能力；卸槽不会撤销已持有能力。
func active_ability_menu_codes() -> Array[int]:
	var codes: Array[int] = []
	for code in _fresh_owned_ability_codes:
		if _has_fresh_owned_ability(code): codes.append(code)
	return codes

func equipped_ability_menu_slots() -> Array:
	return _fresh_loadout.create_slot_view_snapshot() if _has_fresh_ability_owner() else []

func try_equip_formal_ability_to_slot(code: int, index: int) -> bool:
	if not _has_fresh_owned_ability(code): return false
	# 原 CharacterAbilitySet 同一技能已在目标槽时返回成功，不发第二次变化。
	if _fresh_loadout.get_formal_gas_ability_code(index)==code: return true
	if not _fresh_loadout.try_assign_formal_gas_ability_code_to_slot(index,code): return false
	equipped_abilities_changed.emit(equipped_ability_menu_slots())
	return true

func clear_equipped_ability_slot(index: int) -> bool:
	if not _has_fresh_ability_owner() or not _fresh_loadout.clear_slot(index): return false
	equipped_abilities_changed.emit(equipped_ability_menu_slots())
	return true

func _has_fresh_ability_owner() -> bool:
	return _fresh_loadout!=null and is_instance_valid(_get_primary()) \
		and _fresh_ability_host!=null and is_instance_valid(_fresh_ability_host.get_ref())

func _has_fresh_owned_ability(code: int) -> bool:
	if not _has_fresh_ability_owner() or not _fresh_owned_ability_codes.has(code): return false
	var host: Node = _fresh_ability_host.get_ref()
	return is_instance_valid(host.resolve(code))


func _get_primary() -> Node2D:
	if _primary_exited: return null
	var actor: Node2D = _primary.get_ref() if _primary != null else null
	return actor if is_instance_valid(actor) and actor.is_inside_tree() else null

func _on_actor_exiting() -> void:
	if _persistence_registry != null:
		var actor: Node2D = _primary.get_ref() if _primary != null else null
		_persistence_registry.unregister(actor)
		_persistence_registry = null
	var was_selected := _selected
	_primary_exited = true
	_selected = false
	if was_selected: controlled_character_changed.emit(null)

func _on_look_changed(value: Vector2) -> void: look_at_direction_changed.emit(value)
func _on_target_changed(value: Vector2) -> void: target_direction_changed.emit(value)
func _on_provoked(source: Variant) -> void: provoked.emit(source)
func _on_damage_prepared(source: Variant, input: Dictionary) -> void: damage_prepared.emit(source,input)
func _on_damage_completed(source: Variant, input: Dictionary, previous: int, applied: int) -> void:
	damage_completed.emit(source,input,previous,applied)

static func _no_active_invincibility() -> bool: return false
