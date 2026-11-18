extends RefCounted
## 对应 Unity 31629d5 TerrainSurfacePresentation 与其配置的临时表现合同。
## 宿主提供作者映射与实际图层回调；不生成素材、不修改规则或永久地貌。
signal missing_mapping(key: String)
var _states: Array = []
var _signals: Array = []
var _callbacks: Dictionary = {}
var _timers: Dictionary = {}
var _hidden: Dictionary = {}
var _reported: Dictionary = {}
var _enabled := false

func configure(state_mappings: Array, signal_mappings: Array, callbacks: Dictionary) -> bool:
	if not _callbacks.is_empty(): return false
	for key in ["sample", "mapped_cover_sources", "source_available", "set_cover_alpha", "unlock_cover_cell", "set_tile", "clear_tiles"]:
		if not callbacks.get(key) is Callable or not callbacks[key].is_valid(): return false
	for row in state_mappings:
		if not row is Dictionary or not row.has_all(["state", "tile", "priority"]): return false
	for row in signal_mappings:
		if not row is Dictionary or not row.has_all(["signal", "tile", "duration"]): return false
		if not is_finite(float(row.duration)): return false
	_states = state_mappings.duplicate(true)
	_signals = signal_mappings.duplicate(true)
	_callbacks = callbacks.duplicate()
	return true

func enable(runtime_cells: Array) -> bool:
	if _callbacks.is_empty(): return false
	_enabled = true
	_callbacks.clear_tiles.call()
	_restore_all()
	for cell in runtime_cells:
		var current: Dictionary = _callbacks.sample.call(cell)
		if not current.is_empty(): _refresh(cell, current)
	return true

## 对应 OnDisable：取消信号并恢复草层，但原脚本此处不清临时效果层。
func disable() -> void:
	_enabled = false
	_timers.clear()
	_restore_all()

## 对应 RuntimeSurfaceStatesCleared：取消信号、清临时层、恢复草层。
func clear() -> void:
	_timers.clear()
	if not _callbacks.is_empty(): _callbacks.clear_tiles.call()
	_restore_all()

func on_cell_changed(cell: Vector3i, _previous: Dictionary, current: Dictionary, presentation_signal: int) -> void:
	if not _enabled: return
	_refresh(cell, current)
	if presentation_signal != 0: _play_signal(cell, presentation_signal)

## delta 必须由宿主提供受游戏暂停/时间缩放影响的秒数，对应 WaitForSeconds。
func advance(delta: float) -> void:
	if not _enabled or not is_finite(delta) or delta < 0: return
	for cell in _timers.keys():
		_timers[cell] -= delta
		if _timers[cell] > 0: continue
		_timers.erase(cell)
		var current: Dictionary = _callbacks.sample.call(cell)
		if current.is_empty(): _callbacks.set_tile.call(cell, null)
		else: _refresh(cell, current)

func _refresh(cell: Vector3i, current: Dictionary) -> void:
	_refresh_cover(cell, current)
	var tile = null
	var priority := -9223372036854775807
	var states: Dictionary = current.get("states", {})
	# 同优先级时后遇到者胜出，遍历顺序同原快照与作者映射。
	for state in states:
		for row in _states:
			if int(row.state) == int(state) and row.tile != null and int(row.priority) >= priority:
				priority = int(row.priority)
				tile = row.tile
	_callbacks.set_tile.call(cell, tile)
	if tile == null and not states.is_empty(): _report("state:%s" % current.get("flags", 0))

func _refresh_cover(cell: Vector3i, current: Dictionary) -> void:
	var source := int(current.get("cover_source_id", -1))
	if int(current.get("base_cover", 0)) == 0 or source < 0: return
	if not _callbacks.source_available.call(source):
		_report("surface-source:%s" % source)
		return
	var hide := int(current.get("effective_cover", 0)) == 0 or int(current.get("cover_lifecycle", 0)) == 3
	# 回调只返回有效且在该格确有非空覆盖的作者图层，而非只返回最上层。
	for mapped_source in _callbacks.mapped_cover_sources.call(cell):
		if hide:
			if not _hidden.has(mapped_source): _hidden[mapped_source] = {}
			if not _hidden[mapped_source].has(cell):
				_hidden[mapped_source][cell] = true
				_callbacks.unlock_cover_cell.call(mapped_source, cell)
			_callbacks.set_cover_alpha.call(mapped_source, cell, 0.0)
		elif _hidden.has(mapped_source) and _hidden[mapped_source].has(cell):
			_hidden[mapped_source].erase(cell)
			_callbacks.set_cover_alpha.call(mapped_source, cell, 1.0)
			if _hidden[mapped_source].is_empty(): _hidden.erase(mapped_source)

func _restore_all() -> void:
	for source in _hidden:
		if not _callbacks.source_available.call(source): continue
		for cell in _hidden[source]: _callbacks.set_cover_alpha.call(source, cell, 1.0)
	_hidden.clear()

func _play_signal(cell: Vector3i, kind: int) -> void:
	for row in _signals:
		if int(row.signal) != kind or row.tile == null: continue
		_callbacks.set_tile.call(cell, row.tile)
		_timers[cell] = maxf(0.01, float(row.duration))
		return
	# 原场景 Steam 无映射也不会补图；缺失后重新采样，不取消旧信号计时。
	_report("signal:%s" % kind)
	var current: Dictionary = _callbacks.sample.call(cell)
	if not current.is_empty(): _refresh(cell, current)

func _report(key: String) -> void:
	if _reported.has(key): return
	_reported[key] = true
	missing_mapping.emit(key)
