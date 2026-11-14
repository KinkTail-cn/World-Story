extends Node

const RATE: int = 22050
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var voice_index: int = 0
var ambience: AudioStreamPlayer
var _last: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for i in range(6):
		var voice := AudioStreamPlayer.new()
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		voice.volume_db = -15.0
		add_child(voice)
		voices.append(voice)
	for kind in ["mine", "place", "hurt", "craft", "step", "water"]:
		sounds[kind] = _make_sound(kind)
	ambience = AudioStreamPlayer.new()
	ambience.stream = _make_ambience()
	ambience.volume_db = -33.0
	add_child(ambience)
	ambience.play()

func play(kind: String) -> void:
	if not sounds.has(kind) or voices.is_empty() or (get_tree().paused and kind != "craft"):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(kind, -10000)) < (220 if kind == "step" else 90):
		return
	_last[kind] = now
	var voice := voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	voice.stream = sounds[kind]
	voice.pitch_scale = 1.0 if kind == "craft" else randf_range(0.94, 1.06)
	voice.volume_db = -25.0 if kind in ["step", "water"] else -15.0
	voice.play()

func _make_sound(kind: String) -> AudioStreamWAV:
	var duration := 0.13
	var notes: Array[float] = [240.0]
	match kind:
		"mine": notes = [145.0]
		"place": notes = [310.0]
		"hurt": notes = [130.0, 100.0]; duration = 0.25
		"craft": notes = [440.0, 660.0]; duration = 0.28
		"step": notes = [100.0]; duration = 0.08
		"water": notes = [290.0]; duration = 0.16
	var bytes := PackedByteArray()
	bytes.resize(int(RATE * duration) * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	for i in bytes.size() / 2:
		var t := float(i) / RATE
		var segment := duration / notes.size()
		var note_index := mini(notes.size() - 1, int(t / segment))
		var local := fposmod(t, segment)
		var envelope := minf(local / 0.008, 1.0) * exp(-local * (9.0 if notes.size() > 2 else 25.0)) * minf((duration - t) / 0.02, 1.0)
		var frequency: float = notes[note_index]
		var value := sin(t * frequency * TAU) * 0.55 + sin(t * frequency * 2.0 * TAU) * 0.14
		if kind in ["mine", "step", "water"]:
			value = value * 0.4 + rng.randf_range(-0.3, 0.3)
		bytes.encode_s16(i * 2, int(clampf(value * envelope, -1.0, 1.0) * 22000))
	return _wave(bytes)

func _make_ambience() -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(RATE * 4 * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var filtered := 0.0
	for i in RATE * 4:
		var t := float(i) / RATE
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.035)
		# Fade the loop seam; four-second swell is quiet under player actions.
		var wave := (0.55 + 0.35 * sin(t * TAU / 4.0)) * filtered
		wave *= minf(1.0, minf(t, 4.0 - t) * 12.0)
		bytes.encode_s16(i * 2, int(wave * 24000))
	var stream := _wave(bytes)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = RATE * 4
	return stream

func _wave(bytes: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	return stream
