class_name AudioManager
extends Node
## Plays all game sounds. Until real audio files exist, every sound is
## synthesised in code. To use real files later, call set_stream("jump", my_stream)
## or load them in _ready(): nothing else in the game needs to change.

const SAMPLE_RATE: int = 22050
const SOUND_VOLUMES_DB: Dictionary = {
	"jump": -8.0, "coffee": -8.0, "crash": -4.0, "click": -10.0, "footstep": -22.0, "turn": -10.0,
}

@export var player: PlayerController
@export var turn_controller: TurnController

var _players: Dictionary = {}  ## sound name -> AudioStreamPlayer
var _ambience: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Clicks must work while paused.
	set_stream("jump", _synth_jump())
	set_stream("coffee", _synth_coffee())
	set_stream("crash", _synth_crash())
	set_stream("click", _synth_click())
	set_stream("footstep", _synth_footstep())
	set_stream("turn", _synth_turn())
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = _synth_ambience()
	_ambience.volume_db = -20.0
	add_child(_ambience)
	player.jumped.connect(play.bind("jump"))
	player.crashed.connect(func(_obstacle: Node) -> void: play("crash"))
	player.collected.connect(func(_collectible: Collectible) -> void: play("coffee"))
	player.footstep.connect(play.bind("footstep"))
	turn_controller.turned.connect(func(_direction: int) -> void: play("turn"))


func set_stream(sound_name: String, stream: AudioStream) -> void:
	if not _players.has(sound_name):
		var audio_player := AudioStreamPlayer.new()
		audio_player.volume_db = SOUND_VOLUMES_DB.get(sound_name, -8.0)
		add_child(audio_player)
		_players[sound_name] = audio_player
	_players[sound_name].stream = stream


func play(sound_name: String) -> void:
	var audio_player: AudioStreamPlayer = _players.get(sound_name)
	if audio_player == null:
		return
	audio_player.pitch_scale = randf_range(0.92, 1.08) if sound_name == "footstep" else 1.0
	audio_player.play()


func start_ambience() -> void:
	if not _ambience.playing:
		_ambience.play()


func stop_ambience() -> void:
	_ambience.stop()


# --- Placeholder sound synthesis -------------------------------------------

func _synth_jump() -> AudioStreamWAV:
	var samples := _blank(0.2)
	var phase: float = 0.0
	for i in samples.size():
		var t: float = float(i) / samples.size()
		phase += TAU * lerpf(280.0, 720.0, t) / SAMPLE_RATE
		samples[i] = sin(phase) * (1.0 - t) * 0.5
	return _to_wav(samples)


func _synth_coffee() -> AudioStreamWAV:
	var samples := _blank(0.25)
	for i in samples.size():
		var t: float = float(i) / samples.size()
		var freq: float = 880.0 if t < 0.4 else 1320.0
		samples[i] = sin(TAU * freq * i / SAMPLE_RATE) * (1.0 - t) * 0.45
	return _to_wav(samples)


func _synth_crash() -> AudioStreamWAV:
	var samples := _blank(0.5)
	for i in samples.size():
		var t: float = float(i) / samples.size()
		var noise: float = randf_range(-1.0, 1.0)
		samples[i] = (noise * 0.6 + sin(TAU * 90.0 * i / SAMPLE_RATE) * 0.6) * exp(-5.0 * t)
	return _to_wav(samples)


func _synth_click() -> AudioStreamWAV:
	var samples := _blank(0.05)
	for i in samples.size():
		var t: float = float(i) / samples.size()
		samples[i] = sin(TAU * 1100.0 * i / SAMPLE_RATE) * (1.0 - t) * 0.4
	return _to_wav(samples)


func _synth_footstep() -> AudioStreamWAV:
	var samples := _blank(0.07)
	var smooth: float = 0.0
	for i in samples.size():
		var t: float = float(i) / samples.size()
		smooth = lerpf(smooth, randf_range(-1.0, 1.0), 0.25)  # Low-passed noise = soft thud.
		samples[i] = smooth * (1.0 - t) * 0.9
	return _to_wav(samples)


## Tyre squeal: a wobbling high tone mixed with noise.
func _synth_turn() -> AudioStreamWAV:
	var samples := _blank(0.4)
	var phase: float = 0.0
	for i in samples.size():
		var t: float = float(i) / samples.size()
		phase += TAU * (900.0 - 300.0 * t) / SAMPLE_RATE
		var envelope: float = sin(t * PI)
		samples[i] = (sin(phase) * 0.25 + randf_range(-1.0, 1.0) * 0.2) * envelope
	return _to_wav(samples)


## A 2-second loop: low traffic rumble. The tones complete whole cycles in
## 2 seconds so the loop point is seamless.
func _synth_ambience() -> AudioStreamWAV:
	var duration: float = 2.0
	var samples := _blank(duration)
	var smooth: float = 0.0
	for i in samples.size():
		var time: float = i / float(SAMPLE_RATE)
		smooth = lerpf(smooth, randf_range(-1.0, 1.0), 0.03)
		samples[i] = sin(TAU * 60.0 * time) * 0.18 + sin(TAU * 90.0 * time) * 0.1 \
				+ sin(TAU * 135.0 * time) * 0.06 + smooth * 0.5
	return _to_wav(samples, true)


func _blank(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(SAMPLE_RATE * seconds))
	return samples


func _to_wav(samples: PackedFloat32Array, looped: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav
