class_name CampEvents
extends Node3D
## Zeltnacht-Vorfälle (Kind von TentCamp). Inhalte und Gewichte: data/threat/camp_events.json, Mengen und Werte:
## ThreatConfig camp_*. Die älteren Vorfälle (Schritte, Schatten, Plane, Stimme, Licht, Feuer aus, Sucher) liegen in TentCamp.
## Neu (14.11.): Tiere, Geräusche, Bewegungen – und Vorfälle, bei denen man handeln muss oder kann:
##  sniffer (Licht verscheucht), zipper/shake (E halten), breath_still (stillhalten), drone_scan (Licht aus),
##  mauler_prowl (mit der LED hinausleuchten), lure (drinnen bleiben).
## Christians Regel bleibt: Zeltnacht verletzt, tötet aber nicht (camp_min_health).

const DATA := "res://data/threat/camp_events.json"
const OWN := ["steps", "shadow", "press", "voice", "light", "fire_out", "seeker"]

var camp: TentCamp
var cfg: ThreatConfig
var _rng := RandomNumberGenerator.new()
## Laufende Handlung: {kind, pressure, t, ...}
var challenge: Dictionary = {}
var _hand: Node3D
var _face: Node3D
var _marks: Node3D


static func data() -> Array:
	return DataDB.load_json(DATA).get("events", [])


static func def(kind: String) -> Dictionary:
	for e: Dictionary in data():
		if e["id"] == kind:
			return e
	return {}


static func wakes(kind: String) -> bool:
	return bool(def(kind).get("wakes", true))


## Vorfälle für eine Nacht auswählen: n Stück, höchstens wake_max davon wecken.
static func plan(n: int, night: int, wake_max: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for e: Dictionary in data():
		if night < int(e.get("from_night", 1)):
			continue
		var need := String(e.get("needs", ""))
		if need == "phase2" and Story.phase < 2:
			continue
		if need == "dictaphone" and Inventory.count("dictaphone") <= 0:
			continue
		pool.append(e)
	var out: Array = []
	var woke := 0
	var tries := 0
	while out.size() < n and tries < 200:
		tries += 1
		var total := 0.0
		for e: Dictionary in pool:
			total += float(e.get("weight", 1))
		var r := rng.randf() * total
		var pick: Dictionary = pool[0]
		for e: Dictionary in pool:
			r -= float(e.get("weight", 1))
			if r <= 0.0:
				pick = e
				break
		var w := bool(pick.get("wakes", true))
		if w and woke >= wake_max:
			continue
		# dieselbe Handlung nicht zweimal in einer Nacht
		if out.has(pick["id"]) and String(pick.get("act", "–")) != "–":
			continue
		if w:
			woke += 1
		out.append(pick["id"])
	return out


func _ready() -> void:
	_rng.randomize()
	cfg = ThreatDirector.config


func busy() -> bool:
	return not challenge.is_empty()


func _scene() -> Node:
	return camp.get_parent()


func _player() -> Player:
	return camp._player


func _door(out: float = 0.6, h: float = 0.8) -> Vector3:
	return camp.global_position + camp.global_transform.basis * Vector3(0, h, camp.size_z() * 0.5 + out)


func _around(r: float, h: float = 0.1) -> Vector3:
	var a := _rng.randf() * TAU
	return camp.global_position + Vector3(cos(a) * r, h, sin(a) * r)


func _hurt(dmg: float) -> void:
	var p := _player()
	if p == null:
		return
	var h := p.health
	p.health = maxf(h - dmg, minf(h, cfg.camp_min_health))
	EventBus.player_hurt.emit(dmg)
	EventBus.screen_shake.emit(0.5)


func _fire_burning() -> bool:
	for f in get_tree().get_nodes_in_group("campfire"):
		if f.call("burning") and (f as Node3D).global_position.distance_to(camp.global_position) < 10.0:
			return true
	return false


func _prompt(text: String) -> void:
	EventBus.interaction_prompt_changed.emit(text)


func _restore_prompt() -> void:
	if _player():
		_prompt("Im Zelt   [E] Schlafen   [R] Hinauskriechen   [F] Licht")


## Einen Vorfall starten.
func run(kind: String) -> void:
	if busy():
		return
	match kind:
		"owl_silence": _owl_silence()
		"twigs": _twigs()
		"deer": NightOmens.fire("animals", _scene(), _player(), cfg, _rng)
		"wisps": NightOmens.fire("lights", _scene(), _player(), cfg, _rng)
		"glimpse": NightOmens.fire("mauler_glimpse" if Story.phase >= 2 and _rng.randf() < 0.5 else "seeker_glimpse", _scene(), _player(), cfg, _rng)
		"fox_scream": _fox_scream()
		"pebbles": _pebbles()
		"radio_voice": _radio_voice()
		"gear_moved": camp._rec()["gear_moved"] = true
		"face_door": _face_door()
		"sniffer": _sniffer()
		"zipper": _hold_start("zipper")
		"shake": _hold_start("shake")
		"breath_still": _breath_still()
		"drone_scan": _drone_scan()
		"mauler_prowl": _mauler_prowl()
		"lure": _lure()
		"cl_backpack": _changeling("backpack", 1.1, false)
		"cl_stump": _changeling("stump", 9.0, true)
		"cl_tent": camp._rec()["second_tent"] = true
		_: camp.camp_event("steps")


## Wechselbalg am Zelt: ein zweiter Rucksack am Eingang, oder ein Baumstumpf, der bei jedem Wegsehen näher rückt.
## Zeltnacht-Regel: er packt hier nicht zu.
func _changeling(kind: String, dist: float, moves: bool) -> void:
	var at := _door(dist, 0.0) if not moves else _around(dist, 0.0)
	if not moves:
		at += camp.global_transform.basis.x * 0.7
	var ch := Changeling.spawn(_scene(), kind, at, {"mode": "camp", "approach": moves, "fast": moves, "stop_distance": 2.2,
		"subtle": ThreatDirector.changeling_stage() >= 3, "echo": false})
	ch.face_dir(camp.global_position - at)
	if moves:
		SoundBank.play_at(_scene(), "changeling_drag_forest" if SoundBank.has_recording("changeling_drag_forest") else "changeling_drag", at, -6.0, 0.9)
		EventBus.notify("Draußen schleift etwas über das Laub. Dann ist es still.", 3.5)
	else:
		EventBus.notify("Am Eingang raschelt es kurz. Wie wenn jemand etwas abstellt.", 3.0)


# --- Stimmung: Geräusche, Tiere, Bewegungen ---------------------------------------

func _owl_silence() -> void:
	var p := _around(22.0, 6.0)
	SoundBank.play_at(_scene(), "owl", p, -4.0)
	await get_tree().create_timer(2.5).timeout
	SoundBank.play_at(_scene(), "owl", p, -6.0, 0.95)
	await get_tree().create_timer(3.0).timeout
	get_tree().call_group("nature_ambience", "silence_for", 25.0, true)
	EventBus.notify("Die Eule bricht mitten im Ruf ab. Dann ist alles still. Auch die Grillen.", 4.0)


func _twigs() -> void:
	var start := _rng.randf() * TAU
	for i in 6:
		var a := start + i * 0.9
		var r := 12.0 - i * 1.3
		SoundBank.play_at(_scene(), "twig", camp.global_position + Vector3(cos(a) * r, 0.3, sin(a) * r), -4.0 + i, _rng.randf_range(0.8, 1.15))
		await get_tree().create_timer(_rng.randf_range(1.6, 3.0)).timeout
		if not is_inside_tree():
			return


func _fox_scream() -> void:
	CreatureSounds.play(_scene(), "shriek", _around(35.0, 1.0), -6.0, 1.55, 70.0)
	await get_tree().create_timer(1.2).timeout
	EventBus.notify("Ein Schrei wie von einer Frau, irgendwo im Wald. Ein Fuchs … hoffentlich.", 4.5)


func _pebbles() -> void:
	for i in _rng.randi_range(4, 7):
		var at := camp.global_position + Vector3(_rng.randf_range(-0.8, 0.8), 1.2, _rng.randf_range(-1.0, 1.0))
		SoundBank.play_at(_scene(), "knock", at, -12.0, _rng.randf_range(1.6, 2.2))
		await get_tree().create_timer(_rng.randf_range(0.6, 2.4)).timeout
		if not is_inside_tree():
			return
	EventBus.notify("Steinchen prasseln auf die Plane. Einer kullert durch den Eingang herein. Jemand wirft.", 4.0)


func _radio_voice() -> void:
	var p := _player()
	if p == null:
		return
	SoundBank.play_at(_scene(), "static", p.global_position + Vector3(0, 0.5, 0), -6.0)
	await get_tree().create_timer(1.6).timeout
	EventBus.notify("Aus dem Rucksack rauscht es. Das Diktiergerät spielt von selbst: »… Christian … mach auf …«", 5.0)


## Ein bleiches Gesicht im Eingang – nur, solange man hinsieht.
func _face_door() -> void:
	if _face == null:
		_face = Node3D.new()
		add_child(_face)
		var skin := BuildKit.color_mat(Color(0.62, 0.64, 0.6), 0.6)
		BuildKit.sphere(_face, 0.17, Vector3.ZERO, skin, Vector3(0.85, 1.25, 0.8), 12)
		var eye := BuildKit.color_mat(Color(0.0, 0.0, 0.0), 0.2)
		for sx: float in [-1.0, 1.0]:
			BuildKit.sphere(_face, 0.045, Vector3(sx * 0.06, 0.04, 0.12), eye, Vector3(1.0, 1.5, 0.5), 8)
	_face.global_position = _door(0.35, 0.55)
	_face.look_at(camp.global_position + Vector3(0, 0.55, 0), Vector3.UP, true)
	_face.visible = false
	CreatureSounds.play_phrase(_scene(), "breath", _door(0.5, 0.6), -8.0, 3.0, 12.0)
	var seen := 0.0
	var t := 0.0
	while t < 12.0 and is_inside_tree():
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var p := _player()
		if p == null:
			break
		var to := (_face.global_position - p.camera.global_position).normalized()
		var looking := (-p.camera.global_transform.basis.z).dot(to) > 0.9
		_face.visible = looking and seen < 1.4
		if looking:
			seen += dt
			if seen >= 1.4:
				CreatureSounds.play(_scene(), "head_snap", _face.global_position, -2.0)
				EventBus.fear_spike.emit(1.0)
				break
	if _face:
		_face.visible = false


# --- Handeln: Licht, festhalten, stillhalten, drinnen bleiben ------------------------

## Ein Marder/Fuchs schnüffelt am Zeltrand. Licht an verscheucht ihn, sonst klaut er Essen.
func _sniffer() -> void:
	challenge = {"kind": "sniffer"}
	var side := Vector3(camp.structure.size.x * 0.5 if camp.structure else 0.9, 0.1, 0.2)
	var at := camp.global_position + camp.global_transform.basis * side
	_prompt("Etwas schnüffelt und kratzt unten an der Plane   [F] Licht an")
	SoundBank.play_at(_scene(), "scratch", at, -8.0, 1.6)
	var t := 0.0
	var scared := false
	while t < 8.0 and is_inside_tree():
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		if _player() and _player().light_shining():
			scared = true
			break
		if int(t * 4) % 6 == 0:
			SoundBank.play_at(_scene(), "scratch", at, -9.0, _rng.randf_range(1.5, 1.9))
	challenge = {}
	_restore_prompt()
	if scared:
		SoundBank.play_at(_scene(), "rustle", at + Vector3(2, 0, 0), -6.0, 1.4)
		EventBus.notify("Zwei kleine Augen im Licht – dann ist es weg. Nur ein Marder.", 3.5)
		return
	for id: String in ["food", "ration", "meat_cooked", "meat_raw", "honey", "radish", "carrot", "potato"]:
		if Inventory.count(id) > 0:
			Inventory.remove(id, 1)
			EventBus.notify("Etwas Kleines huscht durch den Eingang und wieder hinaus – mit meinem Essen (%s)!" % Inventory.display_name(id), 4.5)
			return
	EventBus.notify("Etwas Kleines huscht durch den Eingang, schnuppert und verschwindet wieder.", 3.5)


## Reißverschluss / Zelt schütteln: E halten senkt den Druck. Druck voll = Hand greift herein bzw. Zelt bricht zusammen.
func _hold_start(kind: String) -> void:
	challenge = {"kind": kind, "pressure": 0.25, "t": 0.0}
	if kind == "zipper":
		_prompt("Der Reißverschluss bewegt sich – jemand zieht von außen!   [E] gedrückt halten")
		SoundBank.play_at(_scene(), "scratch", _door(0.2, 0.7), -6.0, 2.2)
		CreatureSounds.play_phrase(_scene(), "breath_click", _door(0.6, 0.9), -6.0, 3.0, 12.0)
	else:
		_prompt("Das ganze Zelt wird geschüttelt!   [E] die Stange festhalten")
		SoundBank.play_at(_scene(), "wood_crack", camp.global_position + Vector3(0, 1.0, 0), -6.0, 1.3)
	EventBus.fear_spike.emit(0.8)


func _process(delta: float) -> void:
	if challenge.is_empty() or not (challenge["kind"] in ["zipper", "shake"]):
		return
	var p := _player()
	if p == null:
		_end_hold(false, true)
		return
	challenge["t"] = float(challenge["t"]) + delta
	var holding := Input.is_action_pressed("interact") and not get_tree().paused
	var pr := float(challenge["pressure"])
	pr += (-cfg.camp_hold_fall if holding else cfg.camp_hold_rise) * delta
	challenge["pressure"] = clampf(pr, 0.0, 1.0)
	if challenge["kind"] == "shake":
		EventBus.screen_shake.emit(0.15 + pr * 0.25)
	elif _rng.randf() < delta * 1.5:
		SoundBank.play_at(_scene(), "scratch", _door(0.2, 0.6), -10.0, _rng.randf_range(2.0, 2.4))
	var bar := "■".repeat(int(pr * 10.0)) + "□".repeat(10 - int(pr * 10.0))
	var what := "Reißverschluss" if challenge["kind"] == "zipper" else "Zelt"
	_prompt("%s %s   [E] gedrückt halten" % [what, bar])
	if pr >= 1.0:
		_end_hold(false)
	elif float(challenge["t"]) >= cfg.camp_hold_seconds:
		_end_hold(true)


func _end_hold(held: bool, silent: bool = false) -> void:
	var kind := String(challenge.get("kind", ""))
	challenge = {}
	_restore_prompt()
	if silent:
		return
	if held:
		if _rng.randf() < 0.3:
			camp.camp_event("steps")
		EventBus.notify("Es lässt los. Schritte entfernen sich – langsam, als hätte es Zeit." if kind == "zipper" else "Das Rütteln hört auf. Stille.", 4.0)
		return
	if kind == "zipper":
		_reach_in()
	else:
		EventBus.notify("Die Stangen knicken weg, die Plane fällt über mir zusammen!", 4.0)
		camp.tear(0.0)


## Eine lange graue Hand greift durch den Eingang herein.
func _reach_in() -> void:
	if _hand == null:
		_hand = Node3D.new()
		add_child(_hand)
		var skin := BuildKit.color_mat(Color(0.32, 0.33, 0.3), 0.5)
		BuildKit.box(_hand, Vector3(0.07, 0.07, 0.9), Vector3(0, 0, -0.45), skin, false)
		for k in 4:
			BuildKit.box(_hand, Vector3(0.015, 0.015, 0.22), Vector3(-0.03 + k * 0.02, 0, -1.0), skin, false, Vector3(0, -8 + k * 5, 0))
	var start := _door(0.5, 0.45)
	var reach := camp.global_position + Vector3(0, 0.45, 0)
	_hand.global_position = start
	_hand.look_at(reach, Vector3.UP)
	_hand.visible = true
	CreatureSounds.play(_scene(), "shriek", start, -4.0, 0.9)
	var tw := create_tween()
	tw.tween_property(_hand, "global_position", start.lerp(reach, 0.75), 0.35)
	tw.tween_callback(func() -> void:
		_hurt(cfg.camp_hand_damage)
		EventBus.notify("Kalte Finger packen meinen Knöchel – ich trete zu, dann ist die Hand weg.", 4.5))
	tw.tween_property(_hand, "global_position", start, 0.5)
	tw.tween_callback(func() -> void: _hand.visible = false)


## Atem direkt neben dem Kopf, nur die Plane dazwischen. Stillhalten: nicht umsehen, kein Licht, nicht hinaus.
func _breath_still() -> void:
	var p := _player()
	if p == null:
		return
	challenge = {"kind": "breath_still"}
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var at := camp.global_position + camp.global_transform.basis * Vector3(side * 0.7, 0.6, -0.3)
	_prompt("Atem, direkt neben meinem Kopf. Nicht bewegen.   [Alt] Atem anhalten!")
	CreatureSounds.play_phrase(_scene(), "breath", at, -2.0, 9.0, 8.0)
	EventBus.fear_spike.emit(0.9)
	var yaw0 := p.rotation.y
	var pitch0 := p.head.rotation.x
	var t := 0.0
	var moved := false
	var breathed := 0.0
	while t < 9.0 and is_inside_tree():
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		if _player() == null or p.light_shining() or absf(angle_difference(p.rotation.y, yaw0)) > 0.35 or absf(p.head.rotation.x - pitch0) > 0.3:
			moved = true
			break
		# Atem hörbar (nach einer Schrecksekunde): es hört dich
		if t > 1.2 and not p.holding_breath:
			breathed += 0.1
			if breathed > cfg.camp_breath_grace:
				moved = true
				break
	challenge = {}
	_restore_prompt()
	if moved:
		camp.camp_event("press")
		_hurt(cfg.camp_still_damage)
		EventBus.notify("Es hat mich bemerkt. Etwas schlägt durch die Plane gegen meine Schulter.", 4.0)
	else:
		EventBus.notify("Der Atem wird leiser. Es geht weiter. Ich atme erst wieder, als nichts mehr zu hören ist.", 4.5)


## Die Drohne sucht mit dem Scheinwerfer. Brennt Licht im Zelt, merkt sie es sich – später kommt der Sucher.
func _drone_scan() -> void:
	challenge = {"kind": "drone_scan"}
	_prompt("Ein Summen über den Bäumen, ein Lichtkegel tastet sich heran.   [F] Licht aus!")
	var spot := SpotLight3D.new()
	spot.light_color = Color(0.85, 0.95, 1.0)
	spot.light_energy = 8.0
	spot.spot_range = 40.0
	spot.spot_angle = 14.0
	spot.top_level = true
	add_child(spot)
	var c := camp.global_position + Vector3(0, 18.0, 0)
	SoundBank.play_at(_scene(), "signal", c, -8.0, 1.4)
	var seen := false
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		var off := Vector3(cos(k * TAU) * 12.0 * (1.0 - k * 0.6), 0, sin(k * TAU) * 12.0 * (1.0 - k * 0.6))
		spot.global_position = c + off * 0.3
		spot.look_at(camp.global_position + off, Vector3.FORWARD), 0.0, 1.0, 10.0)
	while tw.is_running():
		await get_tree().create_timer(0.25).timeout
		if _player() and _player().light_shining():
			seen = true
	spot.queue_free()
	challenge = {}
	_restore_prompt()
	if seen:
		Research.flare_until = maxf(Research.flare_until, TimeManager.get_total_hours() + 1.5)
		ThreatDirector.force_event("seeker", 0.4)
		EventBus.notify("Der Lichtkegel bleibt auf dem Zelt stehen. Lange. Dann zieht er ab – aber er hat mich gesehen.", 5.0)
	else:
		EventBus.notify("Der Lichtkegel streift das Zelt und wandert weiter.", 3.0)


## Der Zerfleischer kreist ums Zelt und zieht die Klauen über die Plane. Die Uhr-LED zum Eingang hinaus vertreibt ihn.
func _mauler_prowl() -> void:
	var p := _player()
	if p == null:
		return
	challenge = {"kind": "mauler_prowl"}
	_prompt("Schwere Schritte, ein Knurren. Es umkreist das Zelt.   [F] mit der Uhr-LED hinausleuchten")
	var start := _rng.randf() * TAU
	var driven := false
	for i in 12:
		var a := start + i * 0.55
		var pos := camp.global_position + Vector3(cos(a) * 2.4, 0.1, sin(a) * 2.4)
		CreatureSounds.play(_scene(), "step", pos, -2.0, 0.7, 30.0)
		if i % 4 == 2:
			CreatureSounds.play(_scene(), "breath_click", pos + Vector3(0, 1.0, 0), -2.0, 0.6, 20.0)
			if not _fire_burning():
				SoundBank.play_at(_scene(), "scratch", pos + Vector3(0, 0.8, 0), -2.0, 0.7)
				_claw_marks()
		await get_tree().create_timer(0.9).timeout
		if not is_inside_tree() or _player() == null:
			break
		# LED-Kegel zum Eingang hinaus
		var to_door := (_door(1.5, 0.8) - p.camera.global_position).normalized()
		if p.light_shining() and not p.hands.screen_mode and (-p.camera.global_transform.basis.z).dot(to_door) > 0.8:
			driven = true
			break
	challenge = {}
	_restore_prompt()
	if driven:
		CreatureSounds.play(_scene(), "shriek", _door(4.0, 1.2), -2.0, 0.8)
		EventBus.notify("Ein Kreischen im Lichtkegel – dann bricht es durchs Unterholz davon.", 4.0)
	elif _fire_burning():
		EventBus.notify("Es hält Abstand zum Feuer. Irgendwann sind die Schritte weg.", 3.5)
	else:
		EventBus.notify("Lange Risse in der Plane, von außen. Es wollte mir zeigen, dass es könnte.", 4.5)


func _claw_marks() -> void:
	if _marks == null:
		_marks = Node3D.new()
		add_child(_marks)
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var w := (camp.structure.size.x * 0.5 if camp.structure else 0.9) * 0.55
	var mat := BuildKit.color_mat(Color(0.08, 0.07, 0.06), 0.9)
	for k in 3:
		BuildKit.box(_marks, Vector3(0.012, 0.5, 0.012), Vector3(side * w, 0.65, -0.2 + k * 0.06), mat, false, Vector3(0, 0, side * 50.0))


## Eine Kinderstimme lockt hinaus. Wer ihr folgt (weit weg vom Zelt), verliert das Zelt.
func _lure() -> void:
	challenge = {"kind": "lure"}
	var dir := Vector3(cos(_rng.randf() * TAU), 0, 0)
	dir.z = sqrt(maxf(1.0 - dir.x * dir.x, 0.0)) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var src := camp.global_position + dir * 20.0
	var who := "Ben" if _rng.randf() < 0.5 else "Lena"
	EventBus.notify("»Papa?« – ganz leise, draußen zwischen den Bäumen. Es klingt wie %s." % who, 5.0)
	SoundBank.play_at(_scene(), "music_box", src + Vector3(0, 1.0, 0), -14.0, 0.8)
	var t := 0.0
	var followed := false
	while t < 30.0 and is_inside_tree():
		await get_tree().create_timer(0.5).timeout
		t += 0.5
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		if pl and pl.global_position.distance_to(camp.global_position) > 10.0:
			followed = true
			break
		if is_equal_approx(fmod(t, 10.0), 0.0):
			EventBus.notify("»Papa … komm raus …«", 3.0)
	challenge = {}
	_restore_prompt()
	if followed:
		EventBus.notify("Die Stimme bricht ab. Hinter mir, am Zelt, reißt Stoff.", 4.5)
		await get_tree().create_timer(0.8).timeout
		camp.tear(0.0)
		camp._rec()["small_steps"] = true
	else:
		camp._rec()["small_steps"] = true
		EventBus.notify("Die Stimme kommt nicht näher. Irgendwann hört sie auf.", 3.5)


## Morgens nach der Zeltnacht: Folgen einzelner Vorfälle.
func morning(scene: Node) -> void:
	var rec := camp._rec()
	if bool(rec.get("second_tent", false)):
		rec["second_tent"] = false
		var a := _rng.randf() * TAU
		var at := camp.global_position + Vector3(cos(a) * 7.5, 0, sin(a) * 7.5)
		var t := Changeling.spawn(scene, "tent", at, {"mode": "morning", "vanish_when_unseen": true, "subtle": _rng.randf() < 0.4})
		t.global_rotation.y = camp.global_rotation.y
		EventBus.notify("Draußen ist etwas anders. Ich sehe lieber zweimal hin.", 4.0)
	if bool(rec.get("gear_moved", false)):
		rec["gear_moved"] = false
		var stones := BuildKit.tex_mat("stone", 0.4)
		var root := Node3D.new()
		root.name = "StoneCircle_%d" % TimeManager.day
		scene.add_child(root)
		root.global_position = camp.global_position
		for i in 9:
			var a := TAU * i / 9.0
			var p := Vector3(cos(a) * 3.2, 0.0, sin(a) * 3.2)
			p.y = Terrain.height_at(camp.global_position.x + p.x, camp.global_position.z + p.z) - camp.global_position.y + 0.06
			BuildKit.sphere(root, 0.12, p, stones, Vector3(1.2, 0.7, 1.0), 6)
		EventBus.notify("Um das Zelt liegen Steine. Ein sauberer Kreis. Gestern Abend war der noch nicht da.", 5.0)
	if bool(rec.get("small_steps", false)):
		rec["small_steps"] = false
		var door := camp.global_position + camp.global_transform.basis * Vector3(0, 0, camp.size_z() * 0.5 + 0.5)
		Traces.footprints(scene, door + Vector3(4.0, 0, 6.0), door)
		EventBus.notify("Vor dem Eingang: kleine Abdrücke. Wie von Kinderfüßen. Barfuß.", 5.0)
