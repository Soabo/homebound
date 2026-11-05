class_name SoundBank
extends RefCounted
## Geräusche des Spiels. Gibt es zu einer ID echte Aufnahmen (assets/audio/sfx/<id>_NN.ogg,
## aufbereitet mit tools/audio/sfx.py), wird zufällig eine davon gespielt. Sonst erzeugt der Code
## einen Ersatzklang (WAV), der einmal berechnet und dann wiederverwendet wird.

const RATE := 22050
const SFX_DIR := "res://assets/audio/sfx"
## Klangflächen, die endlos wiederholt werden
const LOOP_IDS := ["generator", "radio", "crickets", "birds", "frogs", "brook", "wind", "gusts", "silence",
		"drip", "monitor_hum", "fire", "static"]
## Lautstärke-Ausgleich der Aufnahmen (dB) – feinjustiert nach Gehör
const GAIN := {"knock": 0.0, "door_open": -6.0, "door_close": -4.0, "door_lock": -4.0, "rattle": -2.0,
		"floor_creak": -4.0, "light_buzz": -8.0, "pickup": -4.0, "place": -2.0, "menu_click": -6.0, "backpack": -4.0,
		"camera_switch": -12.0, "light_switch": -4.0, "clatter": -2.0, "twig": 2.0, "owl": -2.0, "music_box": -2.0,
		"sting_creature": -4.0, "sting_dawn": -8.0, "sting_dusk": -8.0, "faucet": -6.0, "workbench": -4.0}

static var _cache: Dictionary = {}
static var _recorded: Dictionary = {}
static var _last: Dictionary = {}


## Alle Aufnahmen zu einer ID (leer = keine, dann Ersatzklang).
static func recorded(id: String) -> Array:
	if _recorded.has(id):
		return _recorded[id]
	var list: Array = []
	for i in range(1, 25):
		var path := "%s/%s_%02d.ogg" % [SFX_DIR, id, i]
		if not ResourceLoader.exists(path):
			break
		var st := load(path) as AudioStream
		if id in LOOP_IDS and st is AudioStreamOggVorbis:
			st = st.duplicate()
			(st as AudioStreamOggVorbis).loop = true
		list.append(st)
	_recorded[id] = list
	return list


static func has_recording(id: String) -> bool:
	return not recorded(id).is_empty()


## Ein Klang zur ID: echte Aufnahme (zufällige Variante, nie zweimal dieselbe hintereinander) oder Ersatzklang.
static func get_sound(id: String) -> AudioStream:
	var list := recorded(id)
	if not list.is_empty():
		var idx := randi() % list.size()
		if list.size() > 1 and idx == int(_last.get(id, -1)):
			idx = (idx + 1 + randi() % (list.size() - 1)) % list.size()
		_last[id] = idx
		return list[idx]
	return get_generated(id)


## Immer der per Code erzeugte Klang (z. B. für das Summen der Drohne).
static func get_generated(id: String) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var s: PackedFloat32Array
	var loop := false
	match id:
		"knock", "thud": s = _knock()
		"door_break", "fence_break": s = _bang()
		"plank_break", "chop": s = _wood_crack()
		"door_open", "door_close", "door_lock", "light_switch", "menu_click", "camera_switch", "motion_click": s = _click()
		"place", "workbench", "collect_metal", "collect_stone": s = _hammer()
		"backpack": s = _click(0.6)
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
		"crickets":
			s = _crickets()
			loop = true
		"birds":
			s = _birds()
			loop = true
		"owl": s = _owl()
		"scratch": s = _scratch()
		"roof_steps": s = _roof_steps()
		"rattle": s = _rattle()
		"signal": s = _signal()
		"music_box": s = _music_box()
		"radio":
			s = _radio()
			loop = true
		"clatter": s = _clatter()
		_: s = PackedFloat32Array([0.0])
	var wav := _to_wav(s, loop)
	_cache[id] = wav
	return wav


## Spielt einen Klang an einer Position in der Welt ab.
## Bei echten Aufnahmen wird die Tonhöhe nur leicht verändert (die Werte waren für die Ersatzklänge gedacht).
static func play_at(parent: Node, id: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if has_recording(id):
		play_stream_at(parent, get_sound(id), pos, volume_db + float(GAIN.get(id, 0.0)), clampf(pitch, 0.9, 1.1))
	else:
		play_stream_at(parent, get_sound(id), pos, volume_db, pitch)


## Wie play_at, aber mit einer fertigen Tondatei (z. B. echte Aufnahmen).
static func play_stream_at(parent: Node, stream: AudioStream, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 4.0
	p.max_distance = 60.0
	p.attenuation_filter_cutoff_hz = 6000.0
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	# Klangflächen (Schleifen) an einer Stelle nur kurz anspielen, sonst laufen sie endlos
	var loops := (stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED) \
			or (stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).loop)
	if loops:
		p.get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.queue_free())


## Spielt einen Klang ohne Position (z. B. Herzschlag, Benutzeroberfläche).
static func play_ui(parent: Node, id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = get_sound(id)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	if has_recording(id):
		p.volume_db += float(GAIN.get(id, 0.0))
		p.pitch_scale = clampf(pitch, 0.9, 1.1)
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


## Grillenzirpen (nahtlose Schleife)
static func _crickets() -> PackedFloat32Array:
	var b := _buf(2.0)
	var r := RandomNumberGenerator.new()
	r.seed = 21
	for c in 5:
		var f := r.randf_range(4200.0, 5600.0)
		var rate := r.randf_range(13.0, 19.0)
		var off := r.randf()
		var vol := r.randf_range(0.04, 0.09)
		for i in b.size():
			var t := float(i) / RATE
			var chirp := fmod(t * rate + off, 1.0)
			var env := 1.0 if chirp < 0.35 else 0.0
			var burst := 1.0 if fmod(t + off * 2.0, 1.0) < 0.6 else 0.0
			b[i] += sin(TAU * f * t) * env * burst * vol
	return b


## Vogelgezwitscher am Tag (Schleife)
static func _birds() -> PackedFloat32Array:
	var b := _buf(5.0)
	var r := RandomNumberGenerator.new()
	r.seed = 33
	for k in 14:
		var start := r.randf_range(0.0, 4.6)
		var base := r.randf_range(2200.0, 4200.0)
		var notes := r.randi_range(2, 5)
		var vol := r.randf_range(0.05, 0.12)
		for n in notes:
			var ns := int((start + n * 0.09) * RATE)
			var phase := 0.0
			for i in int(0.07 * RATE):
				if ns + i >= b.size():
					break
				var t := float(i) / RATE
				var f := base + sin(t * 90.0) * 400.0 + (n % 2) * 300.0
				phase += TAU * f / RATE
				b[ns + i] += sin(phase) * sin(PI * t / 0.07) * vol
	return b


static func _owl() -> PackedFloat32Array:
	var b := _buf(1.8)
	for hoot in 3:
		var start := int((0.05 + hoot * (0.5 if hoot < 2 else 0.4)) * RATE)
		var len := 0.42 if hoot != 1 else 0.25
		for i in int(len * RATE):
			var t := float(i) / RATE
			var f := 380.0 - t * 60.0
			b[start + i] += sin(TAU * f * t) * sin(PI * t / len) * 0.5
	return b


## Krallen kratzen über Holz
static func _scratch() -> PackedFloat32Array:
	var b := _buf(1.6)
	var r := RandomNumberGenerator.new()
	r.seed = 41
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var stroke := fmod(t, 0.55)
		var env := sin(PI * clampf(stroke / 0.45, 0.0, 1.0)) if stroke < 0.45 else 0.0
		lp += ((r.randf() * 2.0 - 1.0) - lp) * 0.5
		var grit := 1.0 + sin(TAU * 38.0 * t) * 0.6
		b[i] = lp * env * grit * 0.5
	return b


## Knarrende Schritte auf dem Dach
static func _roof_steps() -> PackedFloat32Array:
	var b := _buf(3.2)
	var r := RandomNumberGenerator.new()
	r.seed = 52
	for st in 5:
		var start := int((0.1 + st * 0.6) * RATE)
		var lp := 0.0
		for i in int(0.35 * RATE):
			var t := float(i) / RATE
			lp += ((r.randf() * 2.0 - 1.0) - lp) * 0.08
			var creak := sin(TAU * (180.0 + sin(t * 40.0) * 30.0) * t) * 0.3 * exp(-t * 6.0)
			b[start + i] += (lp * 2.0 * exp(-t * 18.0) + creak) * 0.8
	return b


## Türklinke wird gerüttelt
static func _rattle() -> PackedFloat32Array:
	var b := _buf(1.0)
	var r := RandomNumberGenerator.new()
	r.seed = 61
	for k in 9:
		var start := int((0.04 + k * 0.1 + r.randf() * 0.03) * RATE)
		for i in int(0.05 * RATE):
			var t := float(i) / RATE
			b[start + i] += (sin(TAU * 2100.0 * t) * 0.3 + sin(TAU * 900.0 * t) * 0.3 + (r.randf() - 0.5) * 0.4) * exp(-t * 80.0)
	return b


## Fremdartiges elektronisches Signal
static func _signal() -> PackedFloat32Array:
	var b := _buf(2.4)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var step := floorf(t * 5.0)
		var f := 1800.0 - step * 140.0 + sin(t * 70.0) * 20.0
		phase += TAU * f / RATE
		var gate := 1.0 if fmod(t * 5.0, 1.0) < 0.7 else 0.0
		b[i] = sin(phase) * gate * 0.35 * (1.0 - t / 2.6)
	return b


## Spieluhr-Melodie (leicht verstimmt) – lockt in den Wald
static func _music_box() -> PackedFloat32Array:
	var melody := [76, 74, 72, 74, 76, 76, 76, -1, 74, 74, 74, -1, 76, 79, 79, -1]
	var step := 0.42
	var b := _buf(melody.size() * step + 1.5)
	for n in melody.size():
		if melody[n] < 0:
			continue
		var f := 440.0 * pow(2.0, (float(melody[n]) - 69.0) / 12.0) * (1.0 - 0.012 * sin(n * 1.3))
		var start := int(n * step * RATE)
		for i in int(1.4 * RATE):
			if start + i >= b.size():
				break
			var t := float(i) / RATE
			var env := exp(-t * 3.5)
			b[start + i] += (sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.3 + sin(TAU * f * 3.01 * t) * 0.1) * env * 0.22
	return b


## Radiorauschen mit einem einzelnen, wiederkehrenden Ton
static func _radio() -> PackedFloat32Array:
	var b := _buf(2.0)
	var r := RandomNumberGenerator.new()
	r.seed = 71
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += ((r.randf() * 2.0 - 1.0) - lp) * 0.35
		var tone := sin(TAU * 880.0 * t) * 0.12 if fmod(t, 1.0) < 0.12 else 0.0
		b[i] = lp * 0.22 + tone
	return b


## Etwas fällt um (kleiner Gegenstand)
static func _clatter() -> PackedFloat32Array:
	var b := _buf(0.6)
	var r := RandomNumberGenerator.new()
	r.seed = 81
	for k in 4:
		var start := int((0.0 + k * 0.08 * (1.0 + k * 0.4)) * RATE)
		for i in int(0.06 * RATE):
			var t := float(i) / RATE
			b[start + i] += (sin(TAU * 700.0 * t) * 0.5 + (r.randf() - 0.5) * 0.6) * exp(-t * 60.0) * (1.0 - k * 0.2)
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
