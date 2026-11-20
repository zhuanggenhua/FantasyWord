extends RefCounted
## ClickMoveTest AudioSystem owns one listener gain and four serialized channels.
## Missing playback for a channel does not invent an audio player for it.
const MASTER := -1
const CHANNEL_NAMES := ["BackgroundMusic","BackgroundSound","InterfaceSoundFX","GameplaySoundFX"]
const GROUP := "AudioSystem"
const PREF_PREFIX := "M2D_AudioSystem_Volume_"
const STEP := 0.1
const DISPLAY_MAX := 10
const DISPLAY_SUFFIX := " / 10"
var _volumes := [0.5,0.5,0.5,0.5,0.5]
var _ports: Dictionary = {}
var _storage_path := ""
var _started := false

func start(storage_path: String, listener: Callable, channel_ports: Dictionary = {}) -> bool:
	if _started or storage_path.is_empty() or not listener.is_valid(): return false
	for id in channel_ports:
		if not id is int or id<0 or id>=CHANNEL_NAMES.size() or not channel_ports[id] is Callable \
				or not channel_ports[id].is_valid(): return false
	_storage_path = storage_path
	_ports = channel_ports.duplicate()
	_ports[MASTER] = listener
	var values := ConfigFile.new()
	var loaded := values.load(_storage_path)==OK
	for id in range(MASTER,CHANNEL_NAMES.size()):
		var saved: Variant = values.get_value(GROUP,preference_key(id),0.5) if loaded else 0.5
		# Format is private Godot storage, not a parser for Unity PlayerPrefs.
		_volumes[id+1] = _float32(float(saved)) if _is_volume(saved) else 0.5
	_started = true
	for id in _ports: _ports[id].call(volume(id))
	return true

func stop() -> Error:
	if not _started: return ERR_UNCONFIGURED
	var values := ConfigFile.new()
	for id in range(MASTER,CHANNEL_NAMES.size()):
		values.set_value(GROUP,preference_key(id),volume(id))
	var result := values.save(_storage_path)
	_started = false
	_ports.clear()
	return result

static func preference_key(id: int) -> String:
	if id==MASTER: return PREF_PREFIX+"Master"
	if id>=0 and id<CHANNEL_NAMES.size(): return PREF_PREFIX+"Channel_"+CHANNEL_NAMES[id]
	return ""

func volume(id: int) -> float:
	return _volumes[id+1] if not preference_key(id).is_empty() else 0.0

func display(id: int) -> String:
	if preference_key(id).is_empty(): return ""
	return str(int(round_ties_even(_float32(volume(id)*DISPLAY_MAX))))+DISPLAY_SUFFIX

func adjust(id: int, sign: int) -> bool:
	if not _started or preference_key(id).is_empty() or sign not in [-1,1]: return false
	var step := _float32(STEP*sign)
	var bumped := _float32(volume(id)+step)
	var ratio := _float32(bumped*_float32(1.0/step))
	_volumes[id+1] = clampf(_float32(round_ties_even(ratio)*step),0.0,1.0)
	if _ports.has(id) and _ports[id].is_valid(): _ports[id].call(volume(id))
	return true

static func round_ties_even(value: float) -> float:
	var lower := floorf(value)
	var rest := value-lower
	return lower+1.0 if rest>0.5 or (rest==0.5 and int(lower)%2!=0) else lower

static func _float32(value: float) -> float: return PackedFloat32Array([value])[0]

static func _is_volume(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value) and value>=0.0 and value<=1.0
