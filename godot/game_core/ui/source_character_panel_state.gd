extends RefCounted
## UICharacter's temporary allocation, not the Actor growth or equipment owner.
## Actor port returns authored display info/effective base stats. Party money
## comes from its distinct inventory owner, not from the inspected actor.
const ROWS := [0,1,2,3,4,5,6,7] # EStat indexes of actual prefab receivers, excluding AttackSpeed.
var _read: Callable
var _get_money: Callable
var _commit: Callable
var _actor: WeakRef
var _pending := PackedInt32Array()
var _available := 0
var _total_available := 0
var _visible := false

func bind(actor_values: Callable, party_money: Callable, commit: Callable = Callable()) -> bool:
	if _read.is_valid() or not actor_values.is_valid() or not party_money.is_valid() \
			or (not commit.is_null() and not commit.is_valid()): return false
	_read=actor_values
	_get_money=party_money
	_commit=commit
	return true

## ViewCharacter binds a specific actor at show. It does not follow a
## different controlled actor later. Host owns the separate follow context.
func show(actor: Object) -> bool:
	if not _read.is_valid() or not _get_money.is_valid(): return false
	clear()
	_actor=weakref(actor) if is_instance_valid(actor) else null
	var state := _values()
	if _actor!=null and state.is_empty():
		clear()
		return false
	_pending.resize(ROWS.size())
	_available=int(state.get("available_points",0))
	_total_available=_available
	_visible=true
	return true

func clear() -> void:
	_visible=false
	_actor=null
	_pending.clear()
	_available=0
	_total_available=0

func visible_data() -> Dictionary:
	if not _visible: return {}
	var data := _values()
	var rows: Array[String] = []
	var stats: Array = data.get("base_stats",[])
	for i in ROWS:
		var v := str(int(stats[i])) if not data.is_empty() else "0"
		if _pending[i]>0: v+=" (+%d)"%_pending[i]
		rows.append(v)
	return {"class":data.get("display_name",""),
		"level":str(int(data.level)) if not data.is_empty() else "",
		"experience":str(int(data.next_level_experience)-int(data.experience)) if not data.is_empty() else "",
		"skill_points":str(_available) if not data.is_empty() else "0",
		"currency":str(int(_get_money.call())), "rows":rows,
		"apply":"应用 %d 点"%_pending_total()}

func add_point(stat: int) -> bool:
	if not _visible or stat not in ROWS or _available<=0 or not is_instance_valid(_target()): return false
	_pending[stat]+=1
	_available-=1
	return true

func remove_point(stat: int) -> bool:
	if not _visible or stat not in ROWS or _pending[stat]<=0 or not is_instance_valid(_target()): return false
	_pending[stat]-=1
	_available+=1
	return true

func apply() -> bool:
	if not _visible or not _commit.is_valid() or not is_instance_valid(_target()) or _pending_total()<=0: return false
	var delta := _total_available-_available
	# Actor owner implements the source used-points log and resolved stat refresh.
	if not bool(_commit.call(_target(),delta,_pending.duplicate())): return false
	_total_available=_available
	_pending.fill(0)
	return true

func _target() -> Object: return null if _actor==null else _actor.get_ref()

func _values() -> Dictionary:
	var actor := _target()
	if not is_instance_valid(actor): return {}
	var data: Variant = _read.call(actor)
	if not data is Dictionary or not data.get("base_stats") is Array or data.base_stats.size()!=ROWS.size(): return {}
	if not data.get("display_name") is String: return {}
	for key in ["level","experience","next_level_experience","available_points"]:
		if not data.get(key) is int: return {}
	for stat in data.base_stats:
		if not stat is int: return {}
	return data

func _pending_total() -> int:
	var total := 0
	for v in _pending: total+=v
	return total
