class_name ForestVoices
extends Node
## Klänge des Bayerischen Waldes (Etappe 6, Christian 24.11.): Kirchenglocken der Waldkapelle zu festen Stunden,
## Käuze in der Nacht (Waldkauz, ‚kuwitt‘ = Totenvogel, Rauhfußkauz), schreckende Hirsche/Rehe, im Winter Raben und
## Schwarzspecht statt Vogelgesang. Dazu zwei Vorkommnisse (NightOmens): die versunkene Glocke von Altenreuth und
## die Wilde Jagd in den Rauhnächten. Alle Werte: data/audio/ambience.json.

const DATA := "res://data/audio/ambience.json"

static var _cfg: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _owl_t := 25.0
var _deer_t := 90.0
var _bird_t := 30.0
var _bells_done: Dictionary = {}   ## "Tag:Stunde" → schon geläutet
var _notice_day := -1
## Zuletzt gespielte Klänge (für Tests): id → Anzahl
var played: Dictionary = {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = DataDB.load_json(DATA)
	return _cfg


## Gehört die Nacht nach dem Abend von Tag d zu den Rauhnächten?
static func is_rauhnacht(d: int) -> bool:
	var r: Dictionary = cfg().get("rauhnacht", {})
	if r.is_empty():
		return false
	var dt := TimeManager.date_of(d)
	var md := int(dt["month"]) * 100 + int(dt["day"])
	var from: Array = r["from"]
	var to: Array = r["to"]
	var a := int(from[0]) * 100 + int(from[1])
	var b := int(to[0]) * 100 + int(to[1])
	if a <= b:
		return md >= a and md <= b
	return md >= a or md <= b   # über den Jahreswechsel


## Vorkommnis aus NightOmens ausführen
static func omen(scene: Node, kind: String) -> void:
	var fv := scene.get_tree().get_first_node_in_group("forest_voices") as ForestVoices
	if fv == null:
		return
	match kind:
		"sunken_bell": fv.sunken_bell()
		"wild_hunt": fv.wild_hunt()


func _ready() -> void:
	name = "ForestVoices"
	add_to_group("forest_voices")
	_rng.randomize()


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _nature() -> NatureAmbience:
	# Achtung: auch Wildlife steht in der Gruppe nature_ambience – darum über den Namen
	return get_tree().current_scene.get_node_or_null("NatureAmbience") as NatureAmbience


func _indoor(p: Node3D) -> bool:
	return Cabin.is_inside(p.global_position) or Shed.is_inside(p.global_position)


func _pick(kinds: Dictionary) -> String:
	var total := 0.0
	for k in kinds:
		total += float(kinds[k])
	var r := _rng.randf() * total
	for k in kinds:
		r -= float(kinds[k])
		if r <= 0.0:
			return k
	return kinds.keys()[0]


## Ein Klang irgendwo um den Spieler (Abstand von..bis), etwas über dem Boden.
func _around(id: String, dist: Array, db: float, up: float = 4.0, pitch: float = 1.0) -> void:
	var p := _player()
	if p == null:
		return
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(float(dist[0]), float(dist[1]))
	var at := p.global_position + Vector3(cos(a), 0, sin(a)) * d
	at.y = Terrain.height_at(at.x, at.z) + up
	_far_at(id, at, db, maxf(d * 2.5, 80.0), pitch)


## Ferner Klang: Spieler hört ihn aus Richtung `src`, aber mit eigener Reichweite (große Entfernungen).
func _far_at(id: String, at: Vector3, db: float, max_d: float, pitch: float = 1.0, cutoff: float = 5000.0) -> void:
	var s := AudioStreamPlayer3D.new()
	s.stream = SoundBank.get_sound(id)
	s.volume_db = db + (float(SoundBank.GAIN.get(id, 0.0)) if SoundBank.has_recording(id) else 0.0)
	s.pitch_scale = pitch
	s.unit_size = 10.0
	s.max_distance = max_d
	s.attenuation_filter_cutoff_hz = cutoff
	get_tree().current_scene.add_child(s)
	s.global_position = at
	s.play()
	s.finished.connect(s.queue_free)
	played[id] = int(played.get(id, 0)) + 1


## Klang aus Richtung eines Ortes (map.json), hörbar in 50 m Abstand vom Spieler, leiser je Entfernung.
func _from_place(id: String, place: String, base_db: float, far_drop: float, min_db: float, pitch: float = 1.0) -> void:
	var p := _player()
	if p == null or not WorldMap.places().has(place):
		return
	var src: Vector2 = WorldMap.place_pos(place)
	var here := Vector2(p.global_position.x, p.global_position.z)
	var dist := here.distance_to(src)
	var dir := (src - here).normalized() if dist > 1.0 else Vector2(0, -1)
	var near := minf(dist, 50.0)
	var at := Vector3(here.x + dir.x * near, 0, here.y + dir.y * near)
	at.y = Terrain.height_at(at.x, at.z) + 12.0
	var db := maxf(base_db - far_drop * maxf(dist - 50.0, 0.0) / 100.0, min_db)
	if _indoor(p):
		db -= 8.0
	# je weiter weg, desto dumpfer
	var cutoff := lerpf(6000.0, 1400.0, clampf(dist / 900.0, 0.0, 1.0))
	_far_at(id, at, db, 140.0, pitch, cutoff)


func _process(delta: float) -> void:
	var p := _player()
	if p == null:
		return
	var c := cfg()
	var nature := _nature()
	var quiet := nature != null and nature.silence_level() > 0.3
	var night := TimeManager.is_night()
	var h := TimeManager.hour
	var dusk := h > 15.5 and h < 18.0 or h > 6.5 and h < 8.5
	var fauna := WorldState.stage() < 3
	_check_bells(c)
	_check_rauhnacht(c)
	if quiet or not fauna:
		return
	# Käuze
	if night:
		_owl_t -= delta
		if _owl_t <= 0.0:
			var o: Dictionary = c.get("owls", {})
			var iv: Array = o.get("interval", [35, 90])
			_owl_t = _rng.randf_range(float(iv[0]), float(iv[1]))
			var kind := _pick(o.get("kinds", {"owl": 1}))
			_around(kind, o.get("dist", [25, 60]), -4.0 if kind == "owl" else -6.0, 9.0, _rng.randf_range(0.95, 1.05))
	# Hirsch/Reh schreckt
	if night or dusk:
		_deer_t -= delta
		if _deer_t <= 0.0:
			var dcfg: Dictionary = c.get("deer", {})
			var iv2: Array = dcfg.get("interval", [140, 320])
			_deer_t = _rng.randf_range(float(iv2[0]), float(iv2[1]))
			var n := _rng.randi_range(1, 3)
			for i in n:
				get_tree().create_timer(i * _rng.randf_range(1.2, 2.2)).timeout.connect(_around.bind("deer_bark", dcfg.get("dist", [45, 85]), -5.0, 1.0, _rng.randf_range(0.92, 1.08)))
	# Wintervögel am Tag
	if not night and not dusk:
		_bird_t -= delta
		if _bird_t <= 0.0:
			var wb: Dictionary = c.get("winter_birds", {})
			var iv3: Array = wb.get("interval", [45, 120])
			_bird_t = _rng.randf_range(float(iv3[0]), float(iv3[1]))
			var bk := _pick(wb.get("kinds", {"crow": 1}))
			_around(bk, wb.get("dist", [25, 70]), -6.0, 12.0 if bk == "crow" else 6.0, _rng.randf_range(0.95, 1.05))


## Kirchenglocken zu festen Stunden (einmal je Stunde und Tag)
func _check_bells(c: Dictionary) -> void:
	var b: Dictionary = c.get("bells", {})
	for hh in b.get("hours", []):
		var hour := float(hh)
		var key := "%d:%s" % [TimeManager.day, str(hour)]
		if TimeManager.hour >= hour and TimeManager.hour < hour + 0.25 and not _bells_done.has(key):
			_bells_done[key] = true
			ring_bells()


func ring_bells() -> void:
	var b: Dictionary = cfg().get("bells", {})
	var st: Array = b.get("strokes", [9, 15])
	var n := _rng.randi_range(int(st[0]), int(st[1]))
	var gap := float(b.get("gap", 1.6))
	var rec := SoundBank.has_recording("church_bell")   # echte Aufnahmen: verschiedene Glocken statt Tonhöhe
	for i in n:
		get_tree().create_timer(i * gap + _rng.randf_range(-0.05, 0.05)).timeout.connect(
				_from_place.bind("church_bell", String(b.get("source", "kapelle")), float(b.get("db", 0.0)),
				float(b.get("far_drop", 4.0)), float(b.get("min_db", -16.0)), 1.0 if i % 2 == 0 or rec else 0.84))


## Vorkommnis: die versunkene Glocke von Altenreuth läutet unter Wasser – dumpf, langsam, die Tiere verstummen.
func sunken_bell() -> void:
	var s: Dictionary = cfg().get("sunken_bell", {})
	var st: Array = s.get("strokes", [3, 13])
	var n := _rng.randi_range(int(st[0]), int(st[1]))
	var gap := float(s.get("gap", 3.2))
	var nature := _nature()
	if nature:
		nature.silence_for(n * gap + 6.0, false)
	for i in n:
		get_tree().create_timer(i * gap).timeout.connect(
				_from_place.bind("sunken_bell", String(s.get("source", "dorf")), float(s.get("db", -4.0)), 2.0, -14.0, 1.0))


## Vorkommnis: die Wilde Jagd zieht über den Wald – Sturm, Heulen, Hunde, Horn; Böe, Stille, kurzer Schreck.
func wild_hunt() -> void:
	var p := _player()
	if p == null:
		return
	var w: Dictionary = cfg().get("wild_hunt", {})
	var secs := float(w.get("seconds", 9.0))
	var up := float(w.get("height", 18.0))
	var a := _rng.randf() * TAU
	var from := p.global_position + Vector3(cos(a), 0, sin(a)) * 70.0 + Vector3(0, up, 0)
	var to := p.global_position - Vector3(cos(a), 0, sin(a)) * 70.0 + Vector3(0, up, 0)
	var s := AudioStreamPlayer3D.new()
	s.stream = SoundBank.get_sound("wild_hunt")
	s.volume_db = float(w.get("db", 2.0))
	s.unit_size = 14.0
	s.max_distance = 160.0
	get_tree().current_scene.add_child(s)
	s.global_position = from
	s.play()
	s.finished.connect(s.queue_free)
	var tw := s.create_tween()
	tw.tween_property(s, "global_position", to, secs)
	played["wild_hunt"] = int(played.get("wild_hunt", 0)) + 1
	var nature := _nature()
	if nature:
		nature.silence_for(secs + 20.0, false)
	get_tree().create_timer(secs * 0.45).timeout.connect(func() -> void:
		EventBus.fear_spike.emit(float(w.get("fear", 0.35))))


## Gedanke am ersten Abend der Rauhnächte
func _check_rauhnacht(c: Dictionary) -> void:
	var r: Dictionary = c.get("rauhnacht", {})
	if r.is_empty() or _notice_day == TimeManager.day:
		return
	if TimeManager.hour < float(r.get("notice_hour", 16.5)) or TimeManager.hour > 20.0:
		return
	_notice_day = TimeManager.day
	if is_rauhnacht(TimeManager.day) and not is_rauhnacht(TimeManager.day - 1):
		EventBus.notify(String(r.get("notice", "")), 7.0)
