extends RefCounted
## Locked PersistenceSystem identifier owner (31629d53). External actor lifecycle
## registers and unregisters; only the fresh empty automatic snapshot is supported.
enum Kind { PRE_INSTANCED, CUSTOM_INSTANCED }

var _mappings: Dictionary
var _by_key := {}
var _by_actor := {}


func _init(identifier_mappings: Dictionary = {}) -> void:
	_mappings = identifier_mappings.duplicate()


func register_pre_instanced(actor: Node, identifier: String, automatically_persisted: bool) -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or identifier.strip_edges().is_empty():
		return false
	return _register(actor,identifier,Kind.PRE_INSTANCED,automatically_persisted)


## Explicit named RegisterCustomInstancedPersistable subset. The formal player
## supplies "player"; unkeyed generated dynamic instances are out of scope.
func register_custom_instanced(actor: Node, identifier: String) -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or identifier.strip_edges().is_empty():
		return false
	return _register(actor,identifier,Kind.CUSTOM_INSTANCED,false)


func _register(actor: Node, identifier: String, kind: Kind, automatic: bool) -> bool:
	var receipt: WeakRef = weakref(actor)
	_remove_owned_keys(actor)
	_by_actor[actor.get_instance_id()] = {"actor":receipt,"identifier":identifier,"kind":kind,"automatic":automatic}
	# GameConfig resolves an alias once; the raw identity on the actor stays unchanged.
	# Source assignment replaces the earlier lookup owner at an identical key.
	_by_key[_actual(identifier)] = receipt
	return true


func unregister(actor: Node) -> void:
	if not is_instance_valid(actor): return
	_remove_owned_keys(actor)
	_by_actor.erase(actor.get_instance_id())


func resolve(identifier: String) -> Node:
	if identifier.is_empty(): return null
	var key := _actual(identifier)
	if key.is_empty(): return null
	var receipt: WeakRef = _by_key.get(key)
	return receipt.get_ref() if receipt != null else null


func identifier_for(actor: Node) -> String:
	return str(_record(actor).get("identifier",""))


func automatically_persisted(actor: Node) -> bool:
	return bool(_record(actor).get("automatic",false))


## PersistenceSystem snapshots registered live actors, not the last owner of
## each lookup key. An active automatic object requires unmigrated serialization.
func capture_fresh_empty_automatic_block() -> Dictionary:
	for record: Dictionary in _by_actor.values():
		var actor: Node = record.actor.get_ref()
		if is_instance_valid(actor) and actor.is_inside_tree() and record.automatic:
			return {}
	return {"objects":[]}


func _record(actor: Node) -> Dictionary:
	if not is_instance_valid(actor): return {}
	var record: Dictionary = _by_actor.get(actor.get_instance_id(),{})
	if record.is_empty() or record.actor.get_ref() != actor: return {}
	return record


func _remove_owned_keys(actor: Node) -> void:
	for key in _by_key.keys():
		if _by_key[key].get_ref()==actor: _by_key.erase(key)


func _actual(identifier: String) -> String:
	return str(_mappings.get(identifier,identifier))
