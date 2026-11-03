class_name SoundBank
extends RefCounted
## Erzeugt Geräusche per Code als kurze WAV-Klänge (Platzhalter bis echte Sounds kommen).
## Jeder Klang wird einmal berechnet und dann wiederverwendet.

const RATE := 22050

static var _cache: Dictionary = {}


static func get_sound(id: String) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var s: PackedFloat32Array
	var loop := false
	match id:
		"knock": s = _knock()
		"bang": s = _bang()
		"glass_crack": s = _glass(0.25, 0.4)
		"glass_break": s = _glass(0.9, 1.0)
		"wood_crack": s = _wood_crack()
		"hammer": s = _hammer()
		"step_wood": s = _step(0.06, 0.25, 900.0)
		"step_grass": s = _step(0.09, 0.6, 2600.0)
		"step_creature": s = _step(0.14, 0.45, 1500.0)
		"twig": s = _twig()
		"generator":
			s = _generator()
			loop = true
		"static":
			s = _static()
			loop = true
		"creature_breath": s = _breath()
		"creature_shriek": s = _shriek()
		"switch": s = _click()
		"pickup": s = _click(0.6)
		"heartbeat": s = _heartbeat()
		"hurt": s = _hurt()
		_: s = PackedFloat32Array([0.0])
	var wav := _to_wav(s, loop)
	_cache[id] = wav
	return wav


## Spielt einen Klang an einer Position in der Welt ab.
static func play_at(parent: Node, id: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = get_sound(id)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 4.0
	p.max_distance = 60.0
	p.attenuation_filter_cutoff_hz = 6000.0
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


## Spielt einen Klang ohne Position (z. B. Herzschlag, Benutzeroberfläche).
static func play_ui(parent: Node, id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = get_sound(id)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# --- Klang-Rezepte ------------------------------------------------------

static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func _knock() -> PackedFloat32Array:
	# Drei dumpfe Schläge auf Holz
	var b := _buf(1.1)
	var r := RandomNumberGenerator.new()
	r.seed = 1
	for hit in 3:
		var start := int((0.05 + hit * 0.32) * RATE)
		var lp := 0.0
		for i in int(0.25 * RATE):
			var t := float(i) / RATE
			var env := exp(-t * 28.0)
			var tone := sin(TAU * 95.0 * t) * 0.8 + sin(TAU * 190.0 * t) * 0.3
			lp += ((r.randf() * 2.0 - 1.0) - lp) * 0.15
			b[start + i] += (tone + lp * 1.5) * env * 0.9
	return b


static func _bang() -> PackedFloat32Array:
	var b := _buf(0.6)
	var r := RandomNumberGenerator.new()
	r.seed = 2
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var env := exp(-t * 14.0)
		lp += ((r.randf() * 2.0 - 1.0) - lp) * 0.25
		b[i] = (sin(TAU * 70.0 * t) * 0.9 + lp * 1.6) * env
	return b


static func _glass(strength: float, length: float) -> PackedFloat32Array:
	var b := _buf(length)
	var r := RandomNumberGenerator.new()
	r.seed = int(strength * 100)
	var prev := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var env := exp(-t * (9.0 / strength))
		var n := r.randf() * 2.0 - 1.0
		var hp := n - prev
		prev = n
		var ring := sin(TAU * (2400.0 + r.randf() * 30.0) * t) * 0.25 + sin(TAU * 3700.0 * t) * 0.15
		b[i] = (hp * 0.6 + ring) * env * strength
	# Nachrieselnde Splitter
	for k in int(18 * strength):
		var start := int(r.randf_range(0.05, length * 0.85) * RATE)
		for i in 300:
			if start + i < b.size():
				b[start + i] += (r.randf() * 2.0 - 1.0) * exp(-float(i) / 60.0) * 0.4
	return b


static func _wood_crack() -> PackedFloat32Array:
	var b := _buf(0.5)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in b.size():
		var t := float(i) / RATE
		var env := exp(-t * 10.0)
		var crackle := (r.randf() * 2.0 - 1.0) if r.randf() < 0.35 else 0.0
		b[i] = (crackle * 0.9 + sin(TAU * 140.0 * t) * 0.4) * env
	return b


static func _hammer() -> PackedFloat32Array:
	var b := _buf(0.9)
	for hit in 3:
		var start := int((0.05 + hit * 0.28) * RATE)
		for i in int(0.12 * RATE):
			var t := float(i) / RATE
			b[start + i] += (sin(TAU * 1800.0 * t) * 0.4 + sin(TAU * 240.0 * t) * 0.6) * exp(-t * 45.0)
	return b


static func _step(length: float, noise_amt: float, cutoff: float) -> PackedFloat32Array:
	var b := _buf(length)
	var r := RandomNumberGenerator.new()
	r.seed = int(cutoff)
	var lp := 0.0
	var k := clampf(cutoff / RATE * 6.0, 0.02, 0.9)
	for i in b.size():
		var t := float(i) / RATE
		var env := sin(PI * t / length) * exp(-t * 12.0)
		lp += ((r.randf() * 2.0 - 1.0) - lp) * k
		b[i] = (lp * noise_amt * 2.0 + sin(TAU * 80.0 * t) * 0.3) * env
	return b


static func _twig() -> PackedFloat32Array:
	var b := _buf(0.25)
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for i in b.size():
		var t := float(i) / RATE
		var c := (r.randf() * 2.0 - 1.0) if (r.randf() < 0.5 and t < 0.03) or (t > 0.06 and t < 0.08) else 0.0
		b[i] = c * exp(-t * 20.0)
	return b


static func _generator() -> PackedFloat32Array:
	# Nahtlos wiederholbares Motorbrummen (Länge = ganze Zahl an Perioden)
	var b := _buf(1.0)
	for i in b.size():
		var t := float(i) / RATE
		var s := sin(TAU * 30.0 * t) * 0.5 + sin(TAU * 60.0 * t) * 0.3 + sin(TAU * 90.0 * t) * 0.15
		var chug := 0.7 + 0.3 * sin(TAU * 6.0 * t)
		b[i] = s * chug * 0.6
	return b


static func _static() -> PackedFloat32Array:
	var b := _buf(1.0)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var lp := 0.0
	for i in b.size():
		lp += ((r.randf() * 2.0 - 1.0) - lp) * 0.6
		b[i] = lp * 0.25
	return b


static func _breath() -> PackedFloat32Array:
	# Tiefes, ungleichmäßiges Ein- und Ausatmen mit schwebendem Brummen
	var b := _buf(2.6)
	var r := RandomNumberGenerator.new()
	r.seed = 6
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var env := pow(sin(PI * fmod(t, 1.3) / 1.3), 2.0)
		lp += ((r.randf() * 2.0 - 1.0) - lp) * 0.05
		var hum := sin(TAU * (55.0 + sin(t * 7.0) * 4.0) * t) * 0.25
		b[i] = (lp * 2.5 + hum) * env * 0.8
	return b


static func _shriek() -> PackedFloat32Array:
	var b := _buf(1.4)
	var r := RandomNumberGenerator.new()
	r.seed = 8
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 520.0 + sin(t * 30.0) * 90.0 + t * 380.0
		phase += TAU * f / RATE
		var env := minf(t * 8.0, 1.0) * exp(-t * 1.6)
		var rough := 1.0 + (r.randf() - 0.5) * 0.6
		b[i] = (sin(phase) * 0.5 + sin(phase * 1.5) * 0.3 + sin(phase * 2.01) * 0.2) * env * rough * 0.7
	return b


static func _click(pitch: float = 1.0) -> PackedFloat32Array:
	var b := _buf(0.06)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 1600.0 * pitch * t) * exp(-t * 120.0) * 0.6
	return b


static func _heartbeat() -> PackedFloat32Array:
	var b := _buf(0.9)
	for beat in 2:
		var start := int((0.02 + beat * 0.22) * RATE)
		for i in int(0.18 * RATE):
			var t := float(i) / RATE
			b[start + i] += sin(TAU * 52.0 * t) * exp(-t * 22.0) * (1.0 if beat == 0 else 0.7)
	return b


static func _hurt() -> PackedFloat32Array:
	var b := _buf(0.5)
	var r := RandomNumberGenerator.new()
	r.seed = 11
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += ((r.randf() * 2.0 - 1.0) - lp) * 0.3
		b[i] = (sin(TAU * 110.0 * t) * 0.6 + lp) * exp(-t * 7.0)
	return b


static func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
