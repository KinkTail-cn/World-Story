extends RefCounted

const RATE := 22050
static var _clips: Dictionary = {}

static func clip(kind: String) -> AudioStreamWAV:
	if _clips.has(kind): return _clips[kind]
	var duration := 2.0 if kind == "fire" else (0.48 if kind in ["water", "wood_open"] else 0.24)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var bytes := PackedByteArray()
	bytes.resize(int(RATE * duration) * 2)
	var filtered := 0.0
	var rumble := 0.0
	for i in bytes.size() / 2:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.17 if kind in ["water", "fire"] else 0.38)
		rumble = lerpf(rumble, noise, 0.02)
		var value := filtered * 0.22
		if kind.begins_with("wood"):
			value = rumble * 0.7 + sin(t * (135.0 + 28.0 * sin(t * 17.0)) * TAU) * 0.10 + filtered * 0.14
		elif kind == "water":
			value = filtered * 0.4 + sin(t * (640.0 - 320.0 * t) * TAU) * 0.07
		elif kind in ["metal", "switch"]:
			value = sin(t * 730.0 * TAU) * 0.13 + sin(t * 1167.0 * TAU) * 0.08 + filtered * 0.13
		elif kind == "fabric": value = filtered * 0.23 + rumble * 0.45
		elif kind == "plant": value = filtered * 0.2 + sin(t * 360.0 * TAU) * 0.06
		elif kind == "eat": value = filtered * 0.55 * (0.35 + absf(sin(t * 47.0))) + rumble * 0.3
		elif kind == "fire": value = filtered * 0.36 + rumble * 0.9 + noise * (0.23 if rng.randf() > 0.998 else 0.0)
		elif kind == "ignite": value = filtered * 0.65 * sin(clampf(t / duration, 0, 1) * PI)
		var envelope := minf(1.0, t / 0.012) * minf(1.0, (duration - t) / 0.03)
		if kind != "fire": envelope *= exp(-t * (6.0 if kind in ["water", "wood_open"] else 17.0))
		bytes.encode_s16(i * 2, roundi(clampf(value * envelope, -1, 1) * 26000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	if kind == "fire":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = bytes.size() / 2
	_clips[kind] = stream
	return stream
