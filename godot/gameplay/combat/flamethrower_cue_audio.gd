extends Node
## 31629d53 CuePlayGameCoreAudio -> GameplaySoundFX Multiple fallback channel.
## Own this node at scene/audio-system scope, NOT at the disposable cue instance.
## AudioSystem's preference owner supplies the channel override via set_volume_scale;
## the separate master/listener preference remains the host's responsibility.
const CLIP_SHA256 := "2e4edee4ff8d7898198f1ab5213e086965e14a665cb947d53759505e28ddd3e4"
const CHANNEL_VOLUME_PREF_KEY := "M2D_AudioSystem_Volume_Channel_GameplaySoundFX"
const DEFAULT_VOLUME_SCALE := 0.5
const PREWARM_COUNT := 4
var volume_scale := DEFAULT_VOLUME_SCALE
var _clip: AudioStreamOggVorbis
var _voices: Array[AudioStreamPlayer] = []
var _active: Array[AudioStreamPlayer] = []
var _paused := false

func _init() -> void:
	# 原 Menu 只冻结玩法时间，不调用 AudioSystem 的显式通道暂停。
	# 让已经播放的声部跨越场景树暂停；pause() 仍独立控制通道。
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	for index in PREWARM_COUNT:
		_create_voice()

func configure_locked_clip(path: String) -> bool:
	# Reject unknown/substitute data before decoding; caller handles unavailable assets.
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != CLIP_SHA256:
		return false
	var candidate := AudioStreamOggVorbis.load_from_file(path)
	if candidate == null:
		return false
	candidate.loop = false
	_clip = candidate
	return true

func activate() -> bool:
	if _clip == null or not is_inside_tree():
		return false
	var voice: AudioStreamPlayer
	for existing in _voices:
		if not _active.has(existing):
			voice = existing
			break
	if voice == null:
		voice = _create_voice()
	voice.stream = _clip
	voice.volume_linear = volume_scale
	voice.pitch_scale = 1.0
	_active.append(voice)
	voice.play()
	voice.stream_paused = _paused
	return true

func remove_cue() -> void:
	# Original cue has no OnRemove stop. A cast may end while its sound continues.
	pass

func set_volume_scale(value: float) -> void:
	volume_scale = clampf(value, 0.0, 1.0)
	for voice in _active:
		voice.volume_linear = volume_scale

func active_voice_count() -> int:
	return _active.size()

func pause() -> void:
	_paused = true
	for voice in _active:
		voice.stream_paused = true

func resume() -> void:
	_paused = false
	for voice in _active:
		voice.stream_paused = false

func stop_channel() -> void:
	_paused = false
	for voice in _active:
		voice.stop()
		voice.stream = null
	_active.clear()

func _create_voice() -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.autoplay = false
	voice.finished.connect(_recycle.bind(voice))
	add_child(voice)
	_voices.append(voice)
	return voice

func _recycle(voice: AudioStreamPlayer) -> void:
	_active.erase(voice)
	voice.stream = null

func _exit_tree() -> void:
	stop_channel()
