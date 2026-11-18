extends RefCounted
## ElementReactionSystem 首批点/锥施加：只装配原 Fire / Water、Burning / Wet 及对应到期规则。
## 规则与覆盖层由实际地图显式传入；不创建技能、伤害、渲染或持久化。
signal cell_changed(cell: Vector3i, previous: Dictionary, current: Dictionary, presentation_signal: int)
signal states_cleared
const RuleMap = preload("res://game_core/navigation/terrain_rule_map.gd")
const FIRE := 1
const WATER := 2
const WET := 1
const BURNING := 2
const APPLY := 0
const EXPIRE := 1
const ADD := 0
const REMOVE := 1
const SIGNAL := 4
const REMOVE_COVER := 5
var _tiles: Dictionary = {}
var _covers: Dictionary = {}
var _definitions: Dictionary = {}
var _rules: Array = []
var _runtime: Dictionary = {}
var _timed: Dictionary = {}
var _step := 0.0
var _accumulator := 0.0
var _updating := false

func configure(rows: Array, assets: Dictionary) -> bool:
	if _step > 0 or rows.is_empty() or not assets.get("cover_rows") is Array \
			or not assets.get("states") is Array or not assets.get("reactions") is Array:
		return false
	var step := _f32(float(assets.get("fixed_step",0)))
	if not is_finite(step) or step < _f32(.01): return false
	var tiles := {}
	var covers := {}
	var definitions := {}
	var unique := {}
	var rules: Array = []
	for row in rows:
		var cell := _key(row.cell)
		if tiles.has(cell): return false
		tiles[cell] = row.duplicate()
	for row in assets.cover_rows:
		if not row is Dictionary or not row.get("cell") is Array or row.cell.size()!=3 \
				or not row.has_all(["kind","traits","source_id"]): return false
		var cell := _key(row.cell)
		if covers.has(cell): return false
		covers[cell] = row.duplicate()
	for def in assets.states:
		if not def is Dictionary or not def.has_all(["m_stateKind","m_defaultDuration","m_mergePolicy","m_traversalCostMultiplier"]): return false
		var kind := int(def.m_stateKind)
		if kind not in [WET,BURNING] or definitions.has(kind) or int(def.m_mergePolicy) not in [0,1] \
				or not is_finite(float(def.m_defaultDuration)) or float(def.m_defaultDuration)<=0 \
				or not is_finite(float(def.m_traversalCostMultiplier)) or float(def.m_traversalCostMultiplier)<=0:
			return false
		definitions[kind] = def.duplicate()
	if definitions.size()!=2: return false
	for rule in assets.reactions:
		if not rule is Dictionary or not rule.get("m_operations") is Array or rule.m_operations.is_empty(): return false
		var trigger := int(rule.get("m_trigger",-1))
		if trigger not in [APPLY,EXPIRE]: return false
		var kind := int(rule.get("m_elementKind",0) if trigger==APPLY else rule.get("m_expiredStateKind",0))
		var key := Vector2i(trigger,kind)
		if unique.has(key) or (trigger==APPLY and kind not in [FIRE,WATER]) or (trigger==EXPIRE and kind!=BURNING): return false
		unique[key] = true
		for op in rule.m_operations:
			if not op is Dictionary or int(op.get("m_kind",-1)) not in [ADD,REMOVE,SIGNAL,REMOVE_COVER]: return false
			if int(op.m_kind) in [ADD,REMOVE] and not definitions.has(int(op.get("m_stateKind",0))): return false
		rules.append(rule.duplicate(true))
	if unique.size()!=3: return false
	_tiles = tiles
	_covers = covers
	_definitions = definitions
	_rules = rules
	_step = step
	return true

static func _key(cell: Array) -> Vector3i: return Vector3i(int(cell[0]),int(cell[1]),int(cell[2]))
static func _f32(value: float) -> float: return PackedFloat32Array([value])[0]

func sample(cell: Vector3i) -> Dictionary:
	if not _tiles.has(cell): return {}
	var tile: Dictionary = _tiles[cell]
	var cover: Dictionary = _covers.get(cell, {})
	var data: Dictionary = _runtime.get(cell,{})
	var active: Dictionary = data.get("states",{})
	var removed := bool(data.get("cover_removed",false))
	var kind := int(cover.get("kind",0))
	var multiplier := 1.0
	var flags := 0
	for state in active:
		multiplier = _f32(multiplier*_f32(float(_definitions[state].m_traversalCostMultiplier)))
		flags |= 1 << (int(state)-1)
	var lifecycle := 0 if kind==0 else (3 if removed else (2 if active.has(BURNING) else 1))
	return {"base_surface":int(tile.surface),"effective_surface":int(tile.surface),"base_cover":kind,
		"effective_cover":0 if removed else kind,"traits":0 if removed else int(cover.get("traits",0)),
		"cover_source_id":int(cover.get("source_id",-1)),"cover_lifecycle":lifecycle,"states":active.duplicate(true),"flags":flags,
		"traversal_cost":_f32(_f32(float(tile.cost))*maxf(.01,multiplier)) if bool(tile.walkable) else -1.0}

## 锁定默认层的方格坐标；Point 不查扇区或相邻格。暴露时长不改作者规则的状态秒数。
func apply_point(kind: int, origin: Vector2, intensity: float, exposure: float,
		source_entity: Object = null, ability_code: int = 0) -> bool:
	if not _valid_application(kind,origin,intensity,exposure): return false
	var cell := Vector3i(floori(origin.x),floori(origin.y),0)
	return _apply_cells([cell],kind,intensity,source_entity,ability_code) if _walkable(cell) else false

## 原范围只沿当前锥形范围内的可通行四邻格搜索；不是定时火势扩散。
func apply_cone(kind: int, origin: Vector2, facing: Vector2, radius: float, half_angle: float,
		intensity: float, exposure: float, source_entity: Object = null, ability_code: int = 0) -> bool:
	if not _valid_application(kind,origin,intensity,exposure) or not facing.is_finite() \
			or facing.length_squared()<=.000001 or not is_finite(radius) or radius<=0 \
			or not is_finite(half_angle) or half_angle<=0 or half_angle>180:
		return false
	var origin_cell := Vector3i(floori(origin.x),floori(origin.y),0)
	if not _walkable(origin_cell): return false
	var queue: Array[Vector3i] = [origin_cell]
	var visited := {origin_cell:true}
	var cells: Array[Vector3i] = []
	var direction := facing.normalized()
	var radius_squared := _f32(_f32(_f32(radius)*_f32(radius)) + _f32(.0001))
	var min_dot := _f32(cos(_f32(_f32(half_angle)*_f32(PI/180.0))))
	var index := 0
	while index<queue.size():
		var cell: Vector3i = queue[index]
		index += 1
		if _within_cone(cell,origin,direction,radius_squared,min_dot): cells.append(cell)
		for cardinal in RuleMap.CARDINAL:
			var other: Vector3i = cell+cardinal
			if visited.has(other) or not _walkable(other) or not _within_cone(other,origin,direction,radius_squared,min_dot): continue
			if not RuleMap.can_traverse_elevation(cell,_tiles[cell],other,_tiles[other]): continue
			visited[other]=true
			queue.append(other)
	return _apply_cells(cells,kind,intensity,source_entity,ability_code)

func _valid_application(kind: int, origin: Vector2, intensity: float, exposure: float) -> bool:
	return _step>0 and not _updating and kind in [FIRE,WATER] and origin.is_finite() \
		and is_finite(intensity) and intensity>0 and is_finite(exposure)

func _walkable(cell: Vector3i) -> bool:
	return _tiles.has(cell) and bool(_tiles[cell].walkable)

static func _within_cone(cell: Vector3i, origin: Vector2, direction: Vector2, radius_squared: float, min_dot: float) -> bool:
	var offset := Vector2(cell.x+.5,cell.y+.5)-origin
	var sqr := offset.length_squared()
	return sqr<=radius_squared and (sqr<=.000001 or offset.normalized().dot(direction)>=min_dot)

func _apply_cells(cells: Array, kind: int, intensity: float, source: Object, code: int) -> bool:
	_updating = true
	var power := _f32(clampf(intensity,0,1))
	var changed := false
	for cell in cells:
		var previous := sample(cell)
		var rule := _match(APPLY,kind,power,previous)
		if rule.is_empty(): continue
		var result := _execute(cell,rule,power,source,code)
		if bool(result.changed) or int(result.presentation)!=0:
			changed=true
			cell_changed.emit(cell,previous,sample(cell),int(result.presentation))
	_updating = false
	return changed

func _match(trigger: int, kind: int, intensity: float, row: Dictionary) -> Dictionary:
	for r in _rules:
		if int(r.m_trigger)!=trigger: continue
		if trigger==APPLY and (int(r.m_elementKind)!=kind or intensity<_f32(float(r.m_minimumIntensity))): continue
		if trigger==EXPIRE and int(r.m_expiredStateKind)!=kind: continue
		if bool(r.get("m_requireBaseSurface",false)) and int(r.m_baseSurface)!=int(row.base_surface): continue
		if bool(r.get("m_requireEffectiveSurface",false)) and int(r.m_effectiveSurface)!=int(row.effective_surface): continue
		if bool(r.get("m_requireSurfaceCover",false)) and int(r.m_surfaceCover)!=int(row.effective_cover): continue
		var traits := int(r.get("m_requiredSurfaceCoverTraits",0))
		var flags := int(r.get("m_requiredStates",0))
		if (int(row.traits)&traits)!=traits or (int(row.traits)&int(r.get("m_forbiddenSurfaceCoverTraits",0)))!=0: continue
		if (int(row.flags)&flags)!=flags or (int(row.flags)&int(r.get("m_forbiddenStates",0)))!=0: continue
		return r
	return {}

func _execute(cell: Vector3i, rule: Dictionary, power: float, source: Object, code: int) -> Dictionary:
	var data: Dictionary = _runtime.get(cell,{"states":{},"cover_removed":false})
	var active: Dictionary = data.states
	var changed := false
	var presentation := 0
	for op in rule.m_operations:
		var kind := int(op.get("m_stateKind",0))
		match int(op.m_kind):
			ADD:
				var def: Dictionary = _definitions[kind]
				var override := float(op.get("m_durationOverride",0))
				var duration := _f32(override if override>0 else float(def.m_defaultDuration))
				var strength := _f32(clampf(power*_f32(float(op.get("m_intensityMultiplier",1))),0,1))
				if active.has(kind):
					var old: Dictionary = active[kind]
					if int(def.m_mergePolicy)==1 and strength<=float(old.intensity): continue
					duration = maxf(float(old.remaining),duration)
					strength = maxf(float(old.intensity),strength)
					if _approximately(duration,float(old.remaining)) and _approximately(strength,float(old.intensity)): continue
				active[kind] = {"intensity":strength,"remaining":duration,
					"source_entity":weakref(source) if is_instance_valid(source) else null,"source_ability":code,
					"rule_id":str(rule.get("stable_id","")),"state_id":str(def.get("stable_id",""))}
				changed = true
			REMOVE: changed = active.erase(kind) or changed
			SIGNAL: presentation = int(op.get("m_presentationSignal",0))
			REMOVE_COVER:
				changed = not bool(data.cover_removed) or changed
				data.cover_removed = true
	_runtime[cell] = data
	_update_timed(cell)
	return {"changed":changed,"presentation":presentation}

static func _approximately(a: float,b: float) -> bool:
	return absf(b-a)<maxf(.000001*maxf(absf(a),absf(b)),1.1210387714598537e-44)

func _update_timed(cell: Vector3i) -> void:
	var data: Dictionary = _runtime[cell]
	for state in data.states.values():
		if float(state.remaining)>0:
			_timed[cell] = true
			return
	_timed.erase(cell)
	if data.states.is_empty() and not data.cover_removed: _runtime.erase(cell)

## 与 Unity scaled Update 同一积累时钟；Map 卸载不把本次战斗状态写回作者层。
func advance(delta: float) -> void:
	if _step<=0 or _updating or not is_finite(delta) or delta<=0: return
	_updating = true
	_accumulator = _f32(_accumulator+_f32(delta))
	while _accumulator>=_step:
		_accumulator = _f32(_accumulator-_step)
		for cell in _timed.keys(): _advance_cell(cell)
	_updating = false

func _advance_cell(cell: Vector3i) -> void:
	var previous := sample(cell)
	var active: Dictionary = _runtime[cell].states
	var expired: Array = []
	for kind in active:
		var state: Dictionary = active[kind]
		if float(state.remaining)<=0: continue
		state.remaining = maxf(0,_f32(float(state.remaining)-_step))
		if float(state.remaining)<=0: expired.append(kind)
	if expired.is_empty(): return
	var presentation := 0
	for kind in expired:
		if not active.has(kind): continue
		var saved: Dictionary = active[kind]
		var rule := _match(EXPIRE,int(kind),0,sample(cell))
		if not rule.is_empty():
			var origin: Object = saved.source_entity.get_ref() if saved.source_entity != null else null
			var result := _execute(cell,rule,float(saved.intensity),origin,int(saved.source_ability))
			if int(result.presentation)!=0: presentation = int(result.presentation)
		if active.has(kind) and float(active[kind].remaining)<=0: active.erase(kind)
	_update_timed(cell)
	cell_changed.emit(cell,previous,sample(cell),presentation)

## Source CollectRuntimeStateCells includes completed cover-removal records.
func runtime_cells() -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	cells.assign(_runtime.keys())
	return cells

func clear() -> void:
	_runtime.clear()
	_timed.clear()
	_accumulator = 0.0
	states_cleared.emit()
