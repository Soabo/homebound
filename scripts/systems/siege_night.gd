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

const TASK_ORDER := ["window", "music", "attic", "cellar"]

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


func _ready() -> void:
	current = self
	_rng.randomize()
	_player = get_tree().get_first_node_in_group("player") as Player
	var n := clampi(cfg.siege_tasks_first + index - 1, 1, TASK_ORDER.size())
	var order: Array = TASK_ORDER.duplicate()
	# Keller nur, wenn man ihn schon kennt (Teppich weg); sonst rückt die nächste Aufgabe nach
	var ch := get_tree().get_first_node_in_group("cellar_hatch") as CellarHatch
	if ch == null or not ch.rug_moved:
		order.erase("cellar")
	for i in order.size():
		tasks[order[i]] = {"p": 0.0, "on": i < n}
	wind = 1.0
	EventBus.notify("Sie kommen. Halte die Hütte bis zum Morgengrauen.", 5.0)
	SoundBank.play_ui(self, "sting_creature", -4.0)
	get_tree().call_group("music_box", "start_siege")
	print("[Siege] Nacht %d beginnt, Aufgaben: %s" % [index, str(tasks.keys().filter(func(k: String) -> bool: return tasks[k]["on"]))])


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
	if active("music"):
		_update_music(delta)
	if active("attic"):
		_update_attic(delta)
	if active("cellar"):
		_update_cellar(delta)
	if active("window"):
		_update_window(delta)
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
		_player.take_damage(cfg.siege_hit_damage, from)
		EventBus.screen_shake.emit(0.7)
		CreatureSounds.play(get_parent(), "shriek", from, 2.0)
		var msg := {"window": "Das Fenster ist durch – etwas hat dich gepackt!", "attic": "Die Luke bricht auf – es kommt herunter!",
			"cellar": "Die Kellermauer gibt nach, Wurzeln brechen durch!", "door": "Die Tür ist offen. Etwas hat nur darauf gewartet.",
			"outside": "Draußen bist du Beute!"}
		EventBus.notify(String(msg.get(why, "Es hat dich erwischt!")) + "  Beim nächsten Mal kommt es herein.", 4.0)
		return
	_start_intrusion(from)


## „Es ist im Haus“: verstecken (Schrank/Spind, Keller mit geschlossener Luke, Dachboden mit hochgezogener Leiter) oder sterben.
func _start_intrusion(from: Vector3) -> void:
	_intrusion = 0.0
	EventBus.notify("Es ist im Haus! Versteck dich – Schrank, Spind, Keller oder Dachboden!", 5.0)
	SoundBank.play_ui(self, "heartbeat", 0.0)
	CreatureSounds.play(get_parent(), "shriek", from, 4.0, 0.85)
	_intruder = Node3D.new()
	get_tree().current_scene.add_child(_intruder)
	CreatureModel.build(_intruder)
	var start := from
	start.y = Cabin.FLOOR_Y
	if not Cabin.is_inside(start):
		start = Vector3(-3.0, Cabin.FLOOR_Y, 3.6)
	_intruder.global_position = start


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
	if is_instance_valid(_intruder):
		# geht langsam dorthin, wo du zuletzt warst
		var target := _player.global_position
		target.y = Cabin.FLOOR_Y
		var d := target - _intruder.global_position
		d.y = 0.0
		if d.length() > 1.0 and not safe:
			_intruder.global_position += d.normalized() * minf(1.1 * delta, d.length())
			_intruder.look_at(_intruder.global_position + d.normalized(), Vector3.UP)
		if fmod(_intrusion, 0.9) < delta:
			CreatureSounds.play(get_parent(), "step", _intruder.global_position, -2.0, 0.85)
	if _intrusion < cfg.siege_hide_seconds:
		return
	if safe:
		# Es sucht … und zieht ab
		if _intrusion >= cfg.siege_hide_seconds + 8.0:
			if is_instance_valid(_intruder):
				Apparition.flash(get_tree().current_scene, _intruder.global_position + Vector3(0, 1.3, 0))
				_intruder.queue_free()
			_intrusion = -1.0
			strikes = 1
			for id: String in tasks:
				_set_p(id, minf(pressure(id), 0.3))
			wind = maxf(wind, 0.7)
			EventBus.notify("Es ist weg. Noch nicht vorbei – halte durch.", 3.5)
		return
	# nicht versteckt: aus
	if is_instance_valid(_intruder):
		CreatureSounds.play(get_parent(), "shriek", _intruder.global_position + Vector3(0, 1.6, 0), 6.0)
	_intrusion = -1.0
	_player.take_damage(9999.0, _intruder.global_position + Vector3(0, 1.4, 0) if is_instance_valid(_intruder) else _player.global_position)
	if is_instance_valid(_intruder):
		_intruder.queue_free()


# --- Ende ----------------------------------------------------------------------

func finish(survived: bool) -> void:
	if _finished:
		return
	_finished = true
	_hide_stalker(false)
	if is_instance_valid(_intruder):
		_intruder.queue_free()
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
