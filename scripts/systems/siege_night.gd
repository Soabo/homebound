class_name SiegeNight
extends Node
## Belagerungsnacht à la FNAF (Christian, 13.11.2026): ab Tag 5 etwa jede 4. Nacht, kein Schlaf, von
## siege_start_hour bis siege_end_hour durchhalten. Jeder Raum hat seine Aufgabe, jede Aufgabe einen Druck 0..1:
##   music  – Kinderzimmer: Bens Spieluhr läuft ab → aufziehen, sonst Kinderstimmen, Verzerrung, man geht zur Tür
##   attic  – Dachboden: Schritte übers Dach zur Luke → zuhalten oder zunageln, Leiter oben lassen
##   cellar – Keller: Wurzeln drücken die zugemauerte Stelle auf → mit einem Brett abstützen
##   window – Fenster: die Kreatur bearbeitet ein Fenster → hingehen und mit der Uhr-LED hineinleuchten
## Druck 1 = Fehlschlag (Strike). Erster: Verletzung. Danach: „Es ist im Haus“ → verstecken oder sterben.
## Übersicht: Babyfon + zweiter Monitor auf Stefanies Schreibtisch. Werte: ThreatConfig siege_*.
## Gestartet vom ThreatDirector (Ereignis "siege"), endet selbst im Morgengrauen.

static var current: SiegeNight

## fake = Wechselbalg: eins der Dinge im Haus ist nicht echt (ab Story-Phase 2)
const TASK_ORDER := ["window", "music", "attic", "cellar", "fake"]

var cfg: ThreatConfig
var index: int = 1                 # wievielte Belagerung (bestimmt, wie viele Aufgaben laufen)
var end_total: float = 0.0
var tasks := {}                    # id -> {"p": Druck, "on": aktiv, ...}
var strikes: int = 0
var nailed := false                # Dachbodenluke für diese Nacht zugenagelt
var wind: float = 1.0              # Spieluhr
var _player: Player
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _intrusion := -1.0             # läuft: Sekunden seit „Es ist im Haus“
var _intruder: Node3D
var _music_zero := 0.0
var _whisper_t := 4.0
var _crack_t := 3.0
var _attic_burst := 0.0            # >0: gerade drückt etwas gegen die Luke
var _attic_wait := 20.0
var _window: CabinWindow
var _stalker: Node3D
var _stalker_phase := "away"       # away | approach | work
var _stalker_t := 8.0
var _barricade_hit_t := 0.0
var _outside_t := 0.0
var _finished := false
var _breath_heard := 0.0           # im Versteck: Sekunden hörbarer Atem, während es davorsteht
var _noise_note_t := 0.0
var _breath_warned := false
var _calm_until := 0.0
var fake: Changeling = null        # das falsche Ding im Haus
var _fake_wait := 20.0
var _fake_start_d := 8.0
var _fake_told := false


func _ready() -> void:
	current = self
	_rng.randomize()
	_player = get_tree().get_first_node_in_group("player") as Player
	var order := task_order(get_tree())
	var n := task_count(index, cfg, order)
	for i in order.size():
		tasks[order[i]] = {"p": 0.0, "on": i < n}
	wind = 1.0
	EventBus.notify("Sie kommen. Halte die Hütte bis zum Morgengrauen.", 5.0)
	SoundBank.play_ui(self, "sting_creature", -4.0)
	get_tree().call_group("music_box", "start_siege")
	# noch nie erklärt (z. B. nach dem Laden mitten in der Nacht): jetzt erklären
	if not Tasks.flags.has("siege_briefed") and GameState.in_game():
		ThreatDirector.brief_siege.call_deferred()
	EventBus.noise_made.connect(_on_noise)
	print("[Siege] Nacht %d beginnt, Aufgaben: %s" % [index, str(tasks.keys().filter(func(k: String) -> bool: return tasks[k]["on"]))])


## Welche Aufgaben es geben kann (Keller nur, wenn man ihn kennt; Wechselbalg erst ab seiner Story-Phase).
static func task_order(tree: SceneTree) -> Array:
	var order: Array = TASK_ORDER.duplicate()
	var ch := tree.get_first_node_in_group("cellar_hatch") as CellarHatch
	if ch == null or not ch.rug_moved:
		order.erase("cellar")
	if Story.phase < ThreatDirector.config.changeling_from_phase:
		order.erase("fake")
	return order


static func task_count(idx: int, c: ThreatConfig, order: Array) -> int:
	return clampi(c.siege_tasks_first + idx - 1, 1, mini(TASK_ORDER.size(), order.size()))


## Die Aufgaben der kommenden Belagerung (für die Erklärung am Nachmittag).
static func planned_tasks(tree: SceneTree) -> Array:
	var order := task_order(tree)
	return order.slice(0, task_count(maxi(ThreatDirector.siege_count, 1), ThreatDirector.config, order))


func _exit_tree() -> void:
	if current == self:
		current = null
	if _player:
		_player.mind_extra = 0.0


func active(id: String) -> bool:
	return tasks.has(id) and bool(tasks[id]["on"])


func pressure(id: String) -> float:
	return float(tasks[id]["p"]) if tasks.has(id) else 0.0


func _set_p(id: String, v: float) -> void:
	if tasks.has(id):
		tasks[id]["p"] = clampf(v, 0.0, 1.0)


func _process(delta: float) -> void:
	if _finished or _player == null:
		return
	_t += delta
	if TimeManager.get_total_hours() >= end_total:
		finish(true)
		return
	if GameState.dead:
		return
	if _intrusion >= 0.0:
		_update_intrusion(delta)
		return
	# Nach einem überstandenen Eindringen: kurze Atempause, bevor die Aufgaben wieder drängen
	if _t < _calm_until:
		return
	if active("music"):
		_update_music(delta)
	if active("attic"):
		_update_attic(delta)
	if active("cellar"):
		_update_cellar(delta)
	if active("window"):
		_update_window(delta)
	if active("fake"):
		_update_fake(delta)
	# Draußen ist man Freiwild
	if not Cabin.is_inside(_player.global_position):
		_outside_t += delta
		if _outside_t > cfg.siege_outside_seconds:
			_outside_t = 0.0
			_strike("outside", _player.global_position + Vector3(0, 1, 2))
	else:
		_outside_t = 0.0


# --- Kinderzimmer: Spieluhr ----------------------------------------------------

func _update_music(delta: float) -> void:
	wind = maxf(wind - delta / cfg.siege_music_seconds, 0.0)
	_set_p("music", 1.0 - wind)
	get_tree().call_group("music_box", "set_wind", wind)
	var low := clampf((0.3 - wind) / 0.3, 0.0, 1.0)
	_player.mind_extra = low * 0.55 + clampf(_music_zero / cfg.siege_music_grace, 0.0, 1.0) * 0.4
	if wind <= 0.3:
		_whisper_t -= delta
		if _whisper_t <= 0.0:
			_whisper_t = _rng.randf_range(5.0, 9.0) * (1.0 - low * 0.5)
			var kids := Vector3(-7.5, 1.3, -2.0)
			CreatureSounds.play(get_parent(), "child", kids, -4.0)
			CreatureSounds.play(get_parent(), "breath", kids, -12.0, 1.3)
			var lines := ["„Papa …?“", "„Papa, komm mal …“", "„Papa, mir ist kalt …“", "„Machst du die Tür auf?“"]
			EventBus.notify(lines[_rng.randi() % lines.size()], 2.5)
	if wind <= 0.0:
		_music_zero += delta
		if _music_zero >= cfg.siege_music_grace:
			_music_zero = 0.0
			_lure_to_door()
	else:
		_music_zero = 0.0


func wind_music_box() -> void:
	wind = minf(wind + cfg.siege_music_wind, 1.0)
	_music_zero = 0.0
	_player.mind_extra = 0.0


## Der Manipulator hat gewonnen: man geht wie ferngesteuert zur Haustür und öffnet sie.
func _lure_to_door() -> void:
	# Wer versteckt ist (Schrank, Keller, Dachboden), wird nicht herausgezogen – es zählt nur als Fehlschlag
	if is_safe(_player) or _player.is_hidden():
		wind = 0.6
		_strike("door", _player.global_position + Vector3(0, 1.2, 0))
		return
	var door: Door = null
	for d in get_tree().get_nodes_in_group("entry_point"):
		if d is Door:
			door = d
	var target := Vector3(-3.0, Cabin.FLOOR_Y, 3.7)
	_player.input_locked = true
	_player.set_physics_process(false)
	EventBus.notify("Du gehst zur Tür. Du willst es nicht – du gehst trotzdem.", 3.0)
	var tw := create_tween()
	tw.tween_property(_player, "global_position", target, 4.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		if door:
			door.set_open(true)
		_player.set_physics_process(true)
		_player.input_locked = false
		wind = 0.6
		_strike("door", target + Vector3(0, 1.2, 1.2)))


# --- Dachboden: Luke ---------------------------------------------------------

func _update_attic(delta: float) -> void:
	if nailed:
		_set_p("attic", 0.0)
		return
	var hatch := get_tree().get_first_node_in_group("attic_hatch") as AtticHatch
	if _attic_burst <= 0.0:
		_attic_wait -= delta
		_set_p("attic", pressure("attic") - delta * 0.02)
		if _attic_wait <= 0.0:
			_attic_burst = _rng.randf_range(cfg.siege_attic_burst.x, cfg.siege_attic_burst.y)
			_attic_wait = _rng.randf_range(cfg.siege_attic_pause.x, cfg.siege_attic_pause.y)
			# Schritte über das Dach Richtung Luke
			for k in 4:
				get_tree().create_timer(k * 0.8).timeout.connect(func() -> void:
					if is_instance_valid(self):
						SoundBank.play_at(get_parent(), "roof_steps", Vector3(-3.0 + k * 2.2, Cabin.WALL_TOP + 1.2, 0.3), -1.0, 0.8))
		return
	_attic_burst -= delta
	var rate := 1.0 / cfg.siege_attic_seconds * (3.0 if AtticHatch.down_now else 1.0)
	_set_p("attic", pressure("attic") + rate * delta)
	if hatch and fmod(_t, 1.3) < delta:
		hatch.bump()
	if pressure("attic") >= 1.0:
		_set_p("attic", 0.0)
		_attic_burst = 0.0
		if hatch:
			hatch.set_down(true)
		Apparition.spawn(get_tree().current_scene, "ladder")
		_strike("attic", AtticHatch.FOOT + Vector3(0, 1.4, 0))


func attic_hold() -> void:
	_set_p("attic", pressure("attic") - 0.4)
	SoundBank.play_at(get_parent(), "thud", AtticHatch.FOOT + Vector3(0, 2.6, -1.4), -2.0, 0.8)


func attic_nail() -> bool:
	if nailed or Inventory.count("planks") < 2:
		return false
	Inventory.remove("planks", 2)
	nailed = true
	_set_p("attic", 0.0)
	SoundBank.hammer_series(get_parent(), AtticHatch.FOOT + Vector3(0, 2.6, -1.4), 5)
	return true


# --- Keller: Mauer -------------------------------------------------------------

func _update_cellar(delta: float) -> void:
	_set_p("cellar", pressure("cellar") + delta / cfg.siege_cellar_seconds)
	get_tree().call_group("cellar_brace", "set_pressure", pressure("cellar"))
	_crack_t -= delta
	if _crack_t <= 0.0:
		_crack_t = lerpf(9.0, 2.5, pressure("cellar"))
		SoundBank.play_at(get_parent(), "wood_crack", Vector3(1.4, Cabin.CELLAR_FLOOR + 1.0, -3.35), lerpf(-6.0, 4.0, pressure("cellar")), 0.7)
	if pressure("cellar") >= 1.0:
		_set_p("cellar", 0.35)
		get_tree().call_group("cellar_brace", "burst")
		_strike("cellar", Vector3(0.9, Cabin.FLOOR_Y + 0.5, -5.7))


func cellar_brace() -> bool:
	if Inventory.count("planks") < 1:
		return false
	Inventory.remove("planks", 1)
	_set_p("cellar", 0.0)
	SoundBank.hammer_series(get_parent(), Vector3(1.4, Cabin.CELLAR_FLOOR + 1.0, -3.35), 3)
	return true


# --- Fenster: die Kreatur ------------------------------------------------------

func _update_window(delta: float) -> void:
	_stalker_t -= delta
	match _stalker_phase:
		"away":
			_set_p("window", 0.0)
			if _stalker_t <= 0.0:
				_window = _pick_window()
				if _window:
					_stalker_phase = "approach"
					_stalker_t = _rng.randf_range(cfg.siege_window_approach.x, cfg.siege_window_approach.y)
					CreatureSounds.play(get_parent(), "step", _window.outside_point() + Vector3(4, 0, 0), -6.0, 0.9)
		"approach":
			if _stalker_t <= 0.0:
				_stalker_phase = "work"
				_show_stalker()
		"work":
			if not is_instance_valid(_window):
				_stalker_phase = "away"
				return
			var pos := _window.global_position + Vector3(0, _window.height * 0.5, 0)
			if _window.barricade > 0.0:
				# vernageltes Fenster: sie reißt an den Brettern (langsamer)
				_barricade_hit_t -= delta
				if _barricade_hit_t <= 0.0:
					_barricade_hit_t = 4.0
					_window.receive_hit(cfg.siege_barricade_hit)
				_set_p("window", pressure("window") + delta / (cfg.siege_window_seconds * 2.5))
			else:
				_set_p("window", pressure("window") + delta / cfg.siege_window_seconds)
				if fmod(_t, 2.2) < delta:
					SoundBank.play_at(get_parent(), "scratch" if _rng.randf() < 0.6 else "knock", pos, -1.0, 0.9)
			# hineinleuchten vertreibt sie
			if _lit_at(pos):
				_repel()
				return
			if pressure("window") >= 1.0:
				_window.receive_hit(9999.0)
				var at := pos
				_hide_stalker(false)
				_stalker_phase = "away"
				_stalker_t = _rng.randf_range(10.0, 18.0)
				_strike("window", at)


func _pick_window() -> CabinWindow:
	var list := []
	for w in get_tree().get_nodes_in_group("entry_point"):
		if w is CabinWindow and w != _window:
			list.append(w)
	if list.is_empty():
		return null
	return list[_rng.randi() % list.size()]


func _lit_at(pos: Vector3) -> bool:
	if not _player.light_shining():
		return false
	var cam := _player.camera.global_transform
	var to := pos - cam.origin
	return to.length() < cfg.siege_light_range and (-cam.basis.z).dot(to.normalized()) > 0.88


func _show_stalker() -> void:
	_hide_stalker(false)
	_stalker = Node3D.new()
	get_tree().current_scene.add_child(_stalker)
	CreatureModel.build(_stalker)
	var out := _window.outside_point()
	out.y = Terrain.height_at(out.x, out.z)
	_stalker.global_position = out + (out - _window.global_position).normalized() * Vector3(1, 0, 1) * 0.3
	var look := _window.global_position
	_stalker.look_at(Vector3(look.x, _stalker.global_position.y, look.z), Vector3.UP)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.55, 0.6, 0.7)
	rim.light_energy = 0.5
	rim.omni_range = 3.0
	rim.position = Vector3(0, 2.0, 1.2)
	_stalker.add_child(rim)


func _hide_stalker(flash: bool) -> void:
	if is_instance_valid(_stalker):
		if flash:
			Apparition.flash(get_tree().current_scene, _stalker.global_position + Vector3(0, 1.3, 0))
		_stalker.queue_free()
	_stalker = null


func _repel() -> void:
	print("[Siege] Fenster %s: angeleuchtet, sie weicht zurück" % (String(_window.name) if is_instance_valid(_window) else "?"))
	CreatureSounds.play(get_parent(), "recoil", _window.outside_point() + Vector3(0, 1.6, 0), 0.0)
	_hide_stalker(true)
	_stalker_phase = "away"
	_stalker_t = _rng.randf_range(cfg.siege_window_pause.x, cfg.siege_window_pause.y)
	_set_p("window", 0.0)


# --- Fehlschläge ---------------------------------------------------------------

func _strike(why: String, from: Vector3) -> void:
	strikes += 1
	print("[Siege] Fehlschlag %d (%s)" % [strikes, why])
	if strikes == 1:
		_player.take_damage(cfg.siege_hit_damage, from, "siege_fail")
		EventBus.screen_shake.emit(0.7)
		CreatureSounds.play(get_parent(), "shriek", from, 2.0)
		var msg := {"window": "Das Fenster ist durch – etwas hat dich gepackt!", "attic": "Die Luke bricht auf – es kommt herunter!",
			"cellar": "Die Kellermauer gibt nach, Wurzeln brechen durch!", "door": "Die Tür ist offen. Etwas hat nur darauf gewartet.",
			"outside": "Draußen bist du Beute!", "fake": "Das falsche Ding steht direkt hinter dir – es reißt dich zu Boden!"}
		EventBus.notify(String(msg.get(why, "Es hat dich erwischt!")) + "  Beim nächsten Mal kommt es herein.", 4.0)
		return
	_start_intrusion(from)


## „Es ist im Haus“: verstecken (Schrank/Spind, Keller mit geschlossener Luke, Dachboden mit hochgezogener Leiter) oder sterben.
## Christian 25.11.: Es läuft nicht mehr sichtbar durchs Haus (ohne Wegfindung glitt es nur dahin) – man hört es kommen.
## Nach der Frist steht es mit einem Blitz direkt vor dem Versteck, man muss den Atem anhalten, es geht langsam in die Hocke
## und späht hinein … und verschwindet wieder mit einem Blitz.
func _start_intrusion(from: Vector3) -> void:
	_intrusion = 0.0
	_breath_heard = 0.0
	_breath_warned = false
	_search_started = false
	EventBus.notify("Es ist im Haus! Versteck dich – Schrank, Spind, Keller oder Dachboden!", 5.0)
	EventBus.fear_spike.emit(1.0)
	SoundBank.play_ui(self, "heartbeat", 0.0)
	CreatureSounds.play(get_parent(), "shriek", from, 4.0, 0.85)
	_intrude_from = from
	_intrude_from.y = Cabin.FLOOR_Y
	if not Cabin.is_inside(_intrude_from):
		_intrude_from = Vector3(-3.0, Cabin.FLOOR_Y, 3.6)


## Wie lange es vor dem Versteck steht und hineinspäht (Sekunden)
const SEARCH_SECONDS := 9.0
var _intrude_from := Vector3.ZERO
var _search_started := false
var _pose_rest: Dictionary = {}
var _pose_crouch: Dictionary = {}


## Die Kreatur mit einem Blitz an einer Stelle erscheinen lassen, Blick auf look_to.
func _appear(at: Vector3, look_to: Vector3) -> void:
	if is_instance_valid(_intruder):
		_intruder.queue_free()
	_intruder = Node3D.new()
	_intruder.name = "SiegeIntruder"
	get_tree().current_scene.add_child(_intruder)
	var parts := CreatureModel.build(_intruder)
	_pose_rest = CreatureModel.capture_pose(parts)
	CreatureModel.pose_crouch(parts)
	_pose_crouch = CreatureModel.capture_pose(parts)
	CreatureModel.apply_pose(_pose_rest, _pose_crouch, 0.0)
	_intruder.global_position = at
	var to := look_to - at
	to.y = 0.0
	if to.length() > 0.05:
		_intruder.look_at(at + to.normalized(), Vector3.UP)
	Apparition.flash(get_tree().current_scene, at + Vector3(0, 1.3, 0))


func _vanish() -> void:
	if is_instance_valid(_intruder):
		Apparition.flash(get_tree().current_scene, _intruder.global_position + Vector3(0, 1.3, 0))
		_intruder.queue_free()
	_intruder = null


## Schleichen: Was man im Haus laut macht (Schritte, knarrende Dielen), hören sie – oben auf dem Dach und am Fenster.
func _on_noise(pos: Vector3, radius: float) -> void:
	if _finished or _intrusion >= 0.0 or radius < 2.5 or not Cabin.is_inside(pos):
		return
	var add := cfg.siege_noise_pressure * radius / 9.0
	if active("attic"):
		_set_p("attic", pressure("attic") + add)
	if active("window"):
		_set_p("window", pressure("window") + add * 0.5)
	if radius >= 6.0 and _t - _noise_note_t > 40.0 and (active("attic") or active("window")):
		_noise_note_t = _t
		SoundBank.play_at(get_parent(), "scratch", Vector3(pos.x, Cabin.WALL_TOP + 0.6, pos.z), -6.0, 0.8)
		EventBus.notify("Oben hört das Kratzen kurz auf. Dann ist es genau über dir. Leise sein!", 3.5)


func is_safe(p: Player) -> bool:
	if p.is_hidden():
		return true
	var ch := get_tree().get_first_node_in_group("cellar_hatch") as CellarHatch
	if Cabin.in_cellar(p.global_position) and ch and not ch.open:
		return true
	if p.global_position.y > Cabin.WALL_TOP and not AtticHatch.down_now:
		return true
	return false


func _update_intrusion(delta: float) -> void:
	_intrusion += delta
	var safe := is_safe(_player)
	var hide := cfg.siege_hide_seconds
	if _intrusion < hide:
		# man hört es durchs Haus kommen: Schritte wandern vom Einstieg zu dir
		if fmod(_intrusion, 0.9) < delta:
			var f := clampf(_intrusion / hide, 0.0, 1.0)
			var at := _intrude_from.lerp(Vector3(_player.global_position.x, Cabin.FLOOR_Y, _player.global_position.z), f * 0.85)
			CreatureSounds.play(get_parent(), "step", at, -2.0 + f * 3.0, 0.85)
		return
	if not safe:
		# nicht versteckt: es steht mit einem Blitz vor dir – aus
		var fwd := -_player.global_transform.basis.z
		fwd.y = 0.0
		_appear(_player.global_position + fwd.normalized() * 1.1, _player.global_position)
		CreatureSounds.play(get_parent(), "shriek", _intruder.global_position + Vector3(0, 1.6, 0), 6.0)
		_intrusion = -1.0
		_player.take_damage(9999.0, _intruder.global_position + Vector3(0, 1.4, 0), "siege_found")
		_vanish()
		return
	if _intrusion >= hide + SEARCH_SECONDS:
		_end_intrusion()
		return
	var spot_node := _player.hidden_in as HideSpot if _player.is_hidden() else null
	if spot_node == null:
		# Keller/Dachboden: man hört es suchen, dann ist es weg
		if fmod(_intrusion, 1.3) < delta:
			CreatureSounds.play(get_parent(), "step", _intrude_from, -4.0, 0.8)
		return
	var t := _intrusion - hide
	if not _search_started:
		_search_started = true
		var front := spot_node.front_point(maxf(float(spot_node.exit_dist), 0.55))
		front.y = spot_node.global_position.y
		_appear(front, spot_node.global_position)
		CreatureSounds.play(get_parent(), "breath", front + Vector3(0, 1.5, 0), 0.0, 0.8)
		EventBus.notify("Es steht direkt vor deinem Versteck. [Alt] Atem anhalten!", 4.0)
		EventBus.fear_spike.emit(0.8)
		# Verstecke lernen: ein oft benutztes Versteck kennt es schon (ThreatDirector.hide_uses)
		var uses := int(ThreatDirector.hide_uses.get(String(spot_node.name), 0))
		if _rng.randf() < minf(float(uses) * cfg.hide_tear_per_use, cfg.hide_tear_max):
			spot_node.force_open()
			_found_hidden()
			return
	# langsam in die Hocke, späht hinein
	if is_instance_valid(_intruder):
		CreatureModel.apply_pose(_pose_rest, _pose_crouch, smoothstep(1.5, 6.0, t))
	if t > 1.0 and not _player.holding_breath:
		_breath_heard += delta
		if _breath_heard > cfg.siege_breath_grace:
			_found_hidden()


## Es hat aufgegeben: Blitz, weg, kurze Ruhe.
func _end_intrusion() -> void:
	_vanish()
	_intrusion = -1.0
	strikes = 1
	for id: String in tasks:
		_set_p(id, minf(pressure(id), 0.3))
	wind = maxf(wind, 0.7)
	_calm_until = _t + cfg.siege_calm_after
	EventBus.notify("Es ist weg. Noch nicht vorbei – halte durch.", 3.5)


## Wechselbalg: ein Ding im Haus ist nicht echt und rückt bei jedem Wegsehen näher. Uhr-LED drauf = er flieht.
## Druck = wie nah er schon ist. Erreicht er dich: Fehlschlag.
func _update_fake(delta: float) -> void:
	var ccfg := ChangelingConfig.get_default()
	if not is_instance_valid(fake):
		fake = null
		_set_p("fake", maxf(pressure("fake") - delta * 0.2, 0.0))
		_fake_wait -= delta
		if _fake_wait > 0.0:
			return
		var pool := Changeling.spots("siege")
		pool.shuffle()
		for sp: Dictionary in pool:
			var at := Vector3(float(sp["pos"][0]), _player.global_position.y, float(sp["pos"][1]))
			if at.distance_to(_player.global_position) > 4.5:
				fake = Changeling.spawn_spot(get_parent(), sp, {"mode": "siege", "approach": true, "fast": true, "stop_distance": 1.0,
					"subtle": ThreatDirector.changeling_stage() >= 3})
				_fake_start_d = maxf(fake.dist(), 3.0)
				break
		if fake and not _fake_told:
			_fake_told = true
			EventBus.notify(Changeling.text("siege_start"), 5.0)
		return
	var d := fake.dist()
	_set_p("fake", clampf(1.0 - (d - 1.3) / maxf(_fake_start_d - 1.3, 0.5), 0.0, 1.0))
	if fake.lit_time >= ccfg.siege_led_time:
		fake.flee()
		fake = null
		_set_p("fake", 0.0)
		_fake_wait = _rng.randf_range(ccfg.siege_respawn.x, ccfg.siege_respawn.y)
		return
	if d < 1.4:
		var at := fake.global_position + Vector3(0, 1.0, 0)
		fake.flee()
		fake = null
		_set_p("fake", 0.0)
		_fake_wait = _rng.randf_range(ccfg.siege_respawn.x, ccfg.siege_respawn.y)
		_strike("fake", at)


## Im Versteck gefunden, weil man geatmet hat: tut weh, dann ist es weg (der Schrank hält es nicht auf, der Atem schon).
func _found_hidden() -> void:
	_breath_heard = 0.0
	_intrusion = -1.0
	strikes = 1
	var from := _intruder.global_position + Vector3(0, 1.4, 0) if is_instance_valid(_intruder) else _player.global_position
	CreatureSounds.play(get_parent(), "shriek", from, 6.0)
	_player.take_damage(cfg.siege_hit_damage, from, "siege_fail")
	EventBus.screen_shake.emit(0.7)
	EventBus.notify("Es hat dich atmen gehört! Die Schranktür fliegt auf – dann ist es mit einem Blitz weg.", 4.5)
	_vanish()
	for id: String in tasks:
		_set_p(id, minf(pressure(id), 0.3))


# --- Ende ----------------------------------------------------------------------

func finish(survived: bool) -> void:
	if _finished:
		return
	_finished = true
	_hide_stalker(false)
	if is_instance_valid(_intruder):
		_intruder.queue_free()
	if is_instance_valid(fake):
		fake.queue_free()
	if _player:
		_player.mind_extra = 0.0
	get_tree().call_group("music_box", "end_siege")
	get_tree().call_group("cellar_brace", "set_pressure", 0.0)
	if survived:
		Tasks.flag("siege_survived")
		EventBus.notify("Morgengrauen. Sie ziehen ab – du hast die Hütte gehalten.", 5.0)
		SoundBank.play_ui(self, "sting_dawn", -4.0)
	EventBus.siege_finished.emit(survived)
	queue_free()


## Für das Babyfon: Druck je Raum (Kinderzimmer, Dachboden, Keller), -1 = nicht aktiv heute Nacht.
func monitor_levels() -> Array:
	var out := []
	for id: String in ["music", "attic", "cellar"]:
		out.append(pressure(id) if active(id) else -1.0)
	return out
