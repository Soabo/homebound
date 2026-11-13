class_name Wind
extends Node3D
## Der Wind im Wald (Christian: bedrohliches Wehen – ist es der Wind, oder lauert da etwas?).
##  - Stärke kommt vom Wetter (WorldState.weather_wind), dazu langsame Schwankungen.
##  - Böen laufen als Wellen in Windrichtung über den Wald. Pflanzen wiegen sich (shaders/foliage.gdshader),
##    und man hört jede Böe kommen: ein Rauschen, das von weit hinten durch die Bäume auf einen zuläuft und vorbeizieht.
##  - Rascheln: Etwas bewegt sich durchs Gebüsch. Manchmal nur eine Böe in Windrichtung, manchmal mitten in der
##    Windstille, quer zum Wind, und es verstummt, sobald man hinsieht. Dann schweigen die Vögel.
##    Echte Gegner (Zerfleischer, Kreatur) rascheln über `disturb()` genauso.
## Wann das Rascheln kommt: ThreatConfig rustle_*. Wetterwerte: WorldConfig.

static var current: Wind

var strength: float = 0.25
var dir: Vector2 = Vector2(0.8, 0.6)
var time: float = 0.0

var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _player: Player
var _cfg: ThreatConfig
## Rascheln: Ort, Stärke (für den Shader), Herkunft
var _rustle_pos := Vector3(0, -1000, 0)
var _rustle_amp := 0.0
var _disturb_pos := Vector3.ZERO
var _disturb_amp := 0.0
var _disturb_t := 0.0
## laufendes Raschel-Ereignis
var _ev: Dictionary = {}
var _next_rustle: float = 30.0
var _rustle_snd: AudioStreamPlayer3D
## Böen-Rauschen, das durch die Bäume heranläuft
var _gust_snd: Array[AudioStreamPlayer3D] = []
var _gust_cool: float = 4.0
var _last_phase: float = 0.0


func _ready() -> void:
	name = "Wind"
	current = self
	_noise.frequency = 0.02
	_noise.seed = 77
	_rng.randomize()
	_cfg = ThreatDirector.config if ThreatDirector.config else load("res://data/threat/default_threat.tres") as ThreatConfig
	_rustle_snd = AudioStreamPlayer3D.new()
	_rustle_snd.name = "Rustle"
	_rustle_snd.stream = _rustle_stream()
	_rustle_snd.unit_size = 4.0
	_rustle_snd.max_distance = 40.0
	_rustle_snd.volume_db = -60.0
	_rustle_snd.bus = "Master"
	add_child(_rustle_snd)
	for i in 2:
		var g := AudioStreamPlayer3D.new()
		g.name = "GustSound%d" % i
		g.stream = SoundBank.get_sound("gusts") if SoundBank.has_recording("gusts") else _rustle_stream()
		g.unit_size = 14.0
		g.max_distance = 120.0
		g.volume_db = -60.0
		add_child(g)
		_gust_snd.append(g)
	_next_rustle = _rng.randf_range(60.0, 140.0)


func _exit_tree() -> void:
	if current == self:
		current = null


## Böe an einem Ort (0..1) – dieselbe Formel wie im Pflanzen-Shader.
func gust_at(p: Vector3) -> float:
	var a := sin(Vector2(p.x, p.z).dot(dir) * 0.045 - time * 0.6)
	var b := sin(Vector2(p.x, p.z).dot(Vector2(-dir.y, dir.x)) * 0.021 + time * 0.17)
	return clampf(0.5 + 0.38 * a + 0.22 * b, 0.0, 1.0)


## Wind am Ort (Stärke × Böe), für Klang und Teilchen.
func at(p: Vector3) -> float:
	return strength * (0.3 + gust_at(p) * 1.1)


## Gegner, die sich durchs Gebüsch bewegen, rascheln (jedes Bild aufrufen, solange es raschelt).
static func disturb(pos: Vector3, amount: float) -> void:
	if current == null:
		return
	if amount >= current._disturb_amp or pos.distance_to(current._disturb_pos) < 3.0:
		current._disturb_pos = pos
		current._disturb_amp = maxf(current._disturb_amp, amount)
		current._disturb_t = 0.25


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	time += delta
	# Stärke: Wetter + langsames Auf und Ab
	var target := WorldState.weather_wind() * (0.75 + 0.5 * (_noise.get_noise_1d(time * 0.6) * 0.5 + 0.5))
	strength = lerpf(strength, target, clampf(delta * 0.15, 0.0, 1.0))
	var ang := atan2(0.6, 0.8) + _noise.get_noise_1d(time * 0.05 + 300.0) * 0.6
	dir = Vector2(cos(ang), sin(ang))
	RenderingServer.global_shader_parameter_set("wind_strength", strength)
	RenderingServer.global_shader_parameter_set("wind_dir", dir)
	RenderingServer.global_shader_parameter_set("wind_time", time)
	RenderingServer.global_shader_parameter_set("wetness", WorldState.wetness)
	if _player == null:
		return
	_update_gust_sound(delta)
	_update_rustle(delta)
	# Shader bekommt das stärkere von beidem: Ereignis-Rascheln oder echter Gegner
	_disturb_t -= delta
	if _disturb_t <= 0.0:
		_disturb_amp = move_toward(_disturb_amp, 0.0, delta * 3.0)
	var pos := _rustle_pos
	var amp := _rustle_amp
	if _disturb_amp > amp:
		pos = _disturb_pos
		amp = _disturb_amp
	RenderingServer.global_shader_parameter_set("rustle", Vector4(pos.x, pos.y, pos.z, amp))


func _outside() -> bool:
	var p := _player.global_position
	return not Cabin.is_inside(p) and not Shed.is_inside(p)


# --- Böen, die man kommen hört ------------------------------------------------

## Läuft der Wellenkamm der nächsten Böe gleich über den Spieler, startet hinter ihm (gegen den Wind) ein Rauschen,
## das mit der Welle durch die Bäume auf ihn zuläuft und vorbeizieht.
func _update_gust_sound(delta: float) -> void:
	_gust_cool -= delta
	var pp := _player.global_position
	var speed := 0.6 / 0.045   # Geschwindigkeit des Wellenkamms in m/s (aus der Formel oben)
	for g: AudioStreamPlayer3D in _gust_snd:
		if not g.playing:
			continue
		var life := float(g.get_meta("life", 0.0)) + delta
		g.set_meta("life", life)
		g.global_position += Vector3(dir.x, 0, dir.y) * speed * delta
		var total := float(g.get_meta("total", 8.0))
		var env := sin(clampf(life / total, 0.0, 1.0) * PI)
		var loud := float(g.get_meta("loud", -10.0))
		g.volume_db = lerpf(-50.0, loud, env) + (-12.0 if not _outside() else 0.0)
		if life >= total:
			g.stop()
	if _gust_cool > 0.0 or strength < 0.12:
		return
	# Phase der Welle am Spieler: ein Kamm in ca. 3 s?
	var phase := Vector2(pp.x, pp.z).dot(dir) * 0.045 - time * 0.6
	var ahead := fposmod(PI * 0.5 - phase, TAU)   # bis zum nächsten Maximum (sin = 1)
	var secs := ahead / 0.6
	if secs > 2.5 and secs < 3.5:
		for g: AudioStreamPlayer3D in _gust_snd:
			if g.playing:
				continue
			var lateral := Vector3(-dir.y, 0, dir.x) * _rng.randf_range(-15.0, 15.0)
			g.global_position = pp - Vector3(dir.x, 0, dir.y) * speed * secs + lateral + Vector3(0, 6.0, 0)
			g.set_meta("life", 0.0)
			g.set_meta("total", secs * 2.0 + 1.5)
			g.set_meta("loud", lerpf(-16.0, -2.0, clampf(strength, 0.0, 1.0)))
			g.pitch_scale = _rng.randf_range(0.8, 1.05)
			g.play(_rng.randf() * 4.0)
			_gust_cool = 6.0
			break


# --- Rascheln: Wind oder etwas anderes? ----------------------------------------

func _update_rustle(delta: float) -> void:
	if _ev.is_empty():
		_rustle_amp = move_toward(_rustle_amp, 0.0, delta * 2.0)
		_rustle_snd.volume_db = move_toward(_rustle_snd.volume_db, -60.0, delta * 30.0)
		if _rustle_snd.volume_db <= -59.0 and _rustle_snd.playing:
			_rustle_snd.stop()
		_next_rustle -= delta
		if _next_rustle <= 0.0:
			_schedule()
			if _outside() and not GameState.dead and not SiegeNight.current:
				_start_rustle()
		return
	var ev := _ev
	ev["t"] = float(ev["t"]) + delta
	var t: float = ev["t"]
	var dur: float = ev["dur"]
	var p: Vector3 = (ev["from"] as Vector3).lerp(ev["to"], clampf(t / dur, 0.0, 1.0))
	p.y = Terrain.height_at(p.x, p.z) + 0.6
	_rustle_pos = p
	_rustle_snd.global_position = p
	var env := clampf(t / 0.6, 0.0, 1.0) * clampf((dur - t) / 0.8, 0.0, 1.0)
	_rustle_amp = env * float(ev["amp"])
	_rustle_snd.volume_db = lerpf(-40.0, float(ev["loud"]), env)
	# Nicht der Wind: schaut man hin, verstummt es sofort – und die Vögel schweigen
	if not ev["wind"] and _looking_at(p):
		_rustle_amp = 0.0
		_rustle_snd.stop()
		get_tree().call_group("nature_ambience", "silence_for", _cfg.rustle_silence_seconds)
		if _rng.randf() < _cfg.rustle_twig_chance:
			var behind := _player.global_position - (-_player.camera.global_transform.basis.z) * _rng.randf_range(7.0, 12.0)
			get_tree().create_timer(_rng.randf_range(3.0, 7.0)).timeout.connect(func() -> void:
				if is_instance_valid(self):
					SoundBank.play_at(get_parent(), "twig", behind, -4.0, _rng.randf_range(0.8, 1.0)))
		_ev = {}
		return
	if t >= dur:
		_ev = {}


func _schedule() -> void:
	var r := _cfg.rustle_minutes_night if TimeManager.is_night() else _cfg.rustle_minutes_day
	# Spielminuten → Sekunden Echtzeit
	var hps := TimeManager.get_hours_per_second()
	_next_rustle = _rng.randf_range(r.x, r.y) / 60.0 / maxf(hps, 0.00001)


func _start_rustle() -> void:
	var pp := _player.global_position
	var wind := strength > 0.25 and _rng.randf() < _cfg.rustle_wind_share
	var d := _rng.randf_range(_cfg.rustle_distance.x, _cfg.rustle_distance.y)
	var look := -_player.camera.global_transform.basis.z
	var look2 := Vector2(look.x, look.z).normalized()
	var start: Vector3
	var to: Vector3
	if wind:
		# Böe: läuft in Windrichtung an einem vorbei
		var side := Vector2(-dir.y, dir.x) * (_rng.randf_range(4.0, 9.0) * (1.0 if _rng.randf() < 0.5 else -1.0))
		var s2 := Vector2(pp.x, pp.z) - dir * d + side
		var e2 := s2 + dir * d * 2.0
		start = Vector3(s2.x, pp.y, s2.y)
		to = Vector3(e2.x, pp.y, e2.y)
	else:
		# Etwas: seitlich oder hinter dir, bewegt sich quer, oft gegen den Wind
		var ang := atan2(look2.y, look2.x) + PI * _rng.randf_range(0.55, 1.45) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var c := Vector2(pp.x, pp.z) + Vector2(cos(ang), sin(ang)) * d
		var tang := Vector2(-sin(ang), cos(ang)) * _rng.randf_range(5.0, 11.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		start = Vector3(c.x, pp.y, c.y)
		to = Vector3(c.x + tang.x, pp.y, c.y + tang.y)
	_ev = {"t": 0.0, "dur": _rng.randf_range(_cfg.rustle_seconds.x, _cfg.rustle_seconds.y), "from": start, "to": to,
		"wind": wind, "amp": 1.0 if not wind else 0.7, "loud": -6.0 if not wind else -10.0}
	_rustle_snd.pitch_scale = _rng.randf_range(0.85, 1.15)
	_rustle_snd.play(_rng.randf() * 1.5)


func _looking_at(p: Vector3) -> bool:
	var cam := _player.camera.global_transform
	var to := p - cam.origin
	return rad_to_deg((-cam.basis.z).angle_to(to.normalized())) < _cfg.rustle_look_angle and to.length() < 30.0


## Laubrascheln als Schleife (eigene Aufnahme „rustle“, sonst aus Rauschen gebaut).
static func _rustle_stream() -> AudioStream:
	if SoundBank.has_recording("rustle"):
		return SoundBank.get_sound("rustle")
	return SoundBank.get_generated("rustle")
