class_name Radio
extends Interactable
## Altes Batterieradio auf dem Schreibtisch. Läuft auch ohne Strom –
## und schaltet sich manchmal nachts von selbst ein (GDD 13.2, Phase 5).
## Phase 7: An der Werkbank wird es zum improvisierten Analysegerät umgebaut; später
## kommt daneben das fremde Analysegerät von der Absturzstelle (GDD 12.5).
## Der Knoten steht dort, wo das Radio steht (Vorderseite = lokale -x-Achse); anchor = Versatz (meist 0).

@export var anchor: Vector3 = Vector3.ZERO

var is_on: bool = false
var _player3d: AudioStreamPlayer3D
var _dial: StandardMaterial3D
var _tier_shown: int = 0
var _tier1: Node3D
var _tier2: Node3D
var _alien_glow: StandardMaterial3D
var _meter_needle: Node3D
var _t: float = 0.0
var _hint_given: bool = false
## Radio-Nachrichten (data/radio/radio.json): jeden Tag eine neue. Grüne Leuchte = noch nicht gehört.
const DATA_PATH := "res://data/radio/radio.json"
var _data: Dictionary = {}
var heard_day: int = 0
var _led: StandardMaterial3D
var _led_light: OmniLight3D
var _was_new: bool = false
var _play_id: int = 0


func _ready() -> void:
	add_to_group("radio")
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.25, 0.3)
	cs.shape = shape
	cs.position = anchor + Vector3(0, 0.1, 0)
	body.add_child(cs)
	add_child(body)
	_data = DataDB.load_json(DATA_PATH)
	add_to_group("persistent")
	# kleine grüne Leuchte: neue Nachricht
	_led = BuildKit.emissive_mat(Color(0.3, 1.0, 0.35), 0.0)
	BuildKit.sphere(self, 0.012, anchor + Vector3(-0.18, 0.17, 0.02), _led, Vector3.ONE, 8)
	_led_light = OmniLight3D.new()
	_led_light.light_color = Color(0.35, 1.0, 0.4)
	_led_light.omni_range = 0.9
	_led_light.light_energy = 0.0
	_led_light.position = anchor + Vector3(-0.22, 0.17, 0.02)
	add_child(_led_light)
	_dial = BuildKit.emissive_mat(Color(1.0, 0.7, 0.3), 0.0)
	BuildKit.box(self, Vector3(0.012, 0.05, 0.1), anchor + Vector3(-0.18, 0.11, -0.03), _dial, false)
	_player3d = AudioStreamPlayer3D.new()
	_player3d.stream = SoundBank.get_sound("radio")
	_player3d.position = anchor + Vector3(0, 0.1, 0)
	_player3d.unit_size = 2.5
	_player3d.max_distance = 18.0
	_player3d.volume_db = -6.0
	add_child(_player3d)
	Research.changed.connect(_update_tier)
	_update_tier()
	# Fassung für W-17 seitlich am umgebauten Gerät
	var slot := W17Slot.new()
	slot.name = "W17Slot"
	slot.position = anchor + Vector3(-0.33, 0.0, -0.14)
	add_child(slot)
	GameState.restore(self)


func get_prompt(_player: Node) -> String:
	if Inventory.count("alien_analyzer") > 0 and Research.tier < 2:
		return "[E] Fremdes Analysegerät hier aufstellen"
	if Research.tier >= 1:
		var status := ""
		if Research.slot != "":
			status = "  (%s: %d%%)" % [Research.analysis(Research.slot).get("name", ""), int(Research.progress_of(Research.slot) * 100.0)]
		return "[E] %s%s" % [Research.device_name(), status]
	var new_msg := "  – neue Nachricht" if has_new_message() else ""
	return "[E] Radio %s%s" % ["ausschalten" if is_on else "einschalten", new_msg]


func get_secondary_prompt(_player: Node) -> String:
	if Research.tier >= 1:
		return "[R] Radio %s%s" % ["ausschalten" if is_on else "einschalten", "  – neue Nachricht" if has_new_message() else ""]
	return ""


func interact(_player: Node) -> void:
	if Inventory.count("alien_analyzer") > 0 and Research.tier < 2:
		Inventory.remove("alien_analyzer", 1)
		Research.set_tier(2)
		SoundBank.play_at(self, "signal", to_global(anchor), -2.0, 1.2)
		EventBus.notify("Das fremde Gerät summt auf – es arbeitet doppelt so schnell und braucht keinen Strom.", 4.5)
		return
	if Research.tier >= 1:
		get_tree().call_group("research_menu", "open_station")
		return
	set_on(not is_on)


func secondary_interact(_player: Node) -> void:
	if Research.tier >= 1:
		set_on(not is_on)


## Gerätestufe sichtbar machen: Kabel und Messgerät (umgebaut), fremdes Gerät daneben.
func _update_tier() -> void:
	if Research.tier == _tier_shown:
		return
	_tier_shown = Research.tier
	if Research.tier >= 1 and _tier1 == null:
		_tier1 = Node3D.new()
		add_child(_tier1)
		var case_mat := BuildKit.tex_mat("metal", 0.2, Color(1.1, 1.1, 1.05), 0.4)
		var wire := BuildKit.color_mat(Color(0.7, 0.15, 0.1), 0.6)
		var wire2 := BuildKit.color_mat(Color(0.1, 0.1, 0.1), 0.6)
		var a := anchor
		# Messgerät mit Zeiger, Klemmschale für Funde, Kabel zum Radio
		BuildKit.box(_tier1, Vector3(0.16, 0.12, 0.1), a + Vector3(-0.33, 0.06, -0.02), case_mat, false)
		BuildKit.box(_tier1, Vector3(0.12, 0.07, 0.005), a + Vector3(-0.33, 0.075, 0.032), BuildKit.color_mat(Color(0.9, 0.88, 0.75)), false)
		_meter_needle = Node3D.new()
		_meter_needle.position = a + Vector3(-0.33, 0.045, 0.036)
		_tier1.add_child(_meter_needle)
		BuildKit.box(_meter_needle, Vector3(0.003, 0.05, 0.002), Vector3(0, 0.025, 0), wire2, false)
		BuildKit.cylinder(_tier1, 0.07, 0.015, a + Vector3(-0.33, 0.008, 0.12), case_mat, false, Vector3.ZERO, 0.06, 12)
		for k in 3:
			BuildKit.box(_tier1, Vector3(0.006, 0.006, 0.25), a + Vector3(-0.2 + k * 0.012, 0.01, 0.05 + k * 0.02), wire if k == 0 else wire2, false, Vector3(0, 30 + k * 10, 0))
		BuildKit.box(_tier1, Vector3(0.05, 0.03, 0.03), a + Vector3(-0.42, 0.015, 0.12), BuildKit.color_mat(Color(0.2, 0.3, 0.6)), false)
	if Research.tier >= 2 and _tier2 == null:
		_tier2 = Node3D.new()
		add_child(_tier2)
		CrashSite.build_analyzer_model(_tier2, anchor + Vector3(0.12, 0.0, 0.99), 0.7)
		_alien_glow = CrashSite.glow_material()


func _process(delta: float) -> void:
	_t += delta
	# Neue Nachricht: grüne Leuchte blitzt zweimal kurz, dann Pause; dazwischen glimmt sie nach.
	# Ein schwacher grüner Schein fällt auf Tisch und Wand, die Skala pulsiert leise mit.
	if has_new_message():
		var ph := fmod(_t, 1.8)
		var flash := 1.0 if (ph < 0.12 or (ph > 0.3 and ph < 0.42)) else 0.0
		var after := maxf(0.0, 1.0 - (ph - 0.42) / 0.8) * 0.35 if ph > 0.42 else 0.0
		var glow := maxf(flash, after)
		_led.emission_energy_multiplier = 0.3 + glow * 7.0
		_led_light.light_energy = glow * 0.35
		if not _player3d.playing:
			_dial.emission_energy_multiplier = 0.25 + (sin(_t * 2.2) * 0.5 + 0.5) * 0.6
		_was_new = true
	else:
		_led.emission_energy_multiplier = 0.0
		_led_light.light_energy = 0.0
		if _was_new and not _player3d.playing:
			_dial.emission_energy_multiplier = 0.0
		_was_new = false
	if _meter_needle:
		var active := Research.slot != "" and not Research.done.has(Research.slot) and Research.has_power_for_analysis()
		_meter_needle.rotation.z = (sin(_t * 7.0) * 0.25 + 0.3) if active else -0.6


## Gibt es heute eine Nachricht, die noch niemand gehört hat?
func has_new_message() -> bool:
	return heard_day < TimeManager.day


## Die Nachricht des heutigen Tages (Absturz-Hinweis, solange die Absturzstelle unbekannt ist).
func message_for_today() -> String:
	var d := TimeManager.day
	var days: Dictionary = _data.get("days", {})
	var hint := d <= 3 and not Research.seen.has("metal_fragment") and _data.has("crash_hint")
	if hint and (d == 1 or not days.has(str(d))):
		return String(_data["crash_hint"])
	if days.has(str(d)):
		return String(days[str(d)]) + (("  Dann wieder: " + String(_data["crash_hint"])) if hint else "")
	var later: Array = _data.get("later", [])
	if later.is_empty():
		return ""
	return String(later[(d - days.size() - 1) % later.size()])


## Einschalten: Nachricht des Tages (oder bei Nacht ein unheimlicher Fetzen), nach ~20 s blendet es aus.
## night_event = das Radio schaltet sich nachts von selbst ein.
func set_on(v: bool, night_event: bool = false) -> void:
	is_on = v
	_play_id += 1
	_dial.emission_energy_multiplier = 2.5 if v else 0.0
	if v:
		_player3d.volume_db = -6.0
		# jedes Mal eine andere Aufnahme (nie zweimal dieselbe hintereinander)
		_player3d.stream = SoundBank.get_sound("radio")
		_player3d.play()
		if night_event:
			var night: Array = _data.get("night", [])
			if not night.is_empty():
				EventBus.notify(String(night[randi() % night.size()]), 6.0)
		else:
			var msg := message_for_today()
			if msg != "":
				var again := "" if has_new_message() else "(Wiederholung) "
				EventBus.notify("Im Radio: " + again + msg, 8.0)
				message_until_msec = Time.get_ticks_msec() + int(float(_data.get("play_seconds", 20.0)) * 1000.0)
				heard_day = TimeManager.day
				Tasks.flag("radio_day_%d" % TimeManager.day)   # z. B. Bauplan Wasserfilter nach der Wasser-Warnung (Tag 7)
				if msg == String(_data.get("crash_hint", "")):
					_hint_given = true
		_fade_out_later(_play_id)
	else:
		_player3d.stop()
	SoundBank.play_at(self, "switch", to_global(anchor), -6.0, 0.7)


## Bis wann gerade eine Nachricht läuft (für das Diktiergerät: Funkspruch mitschneiden).
static var message_until_msec: int = -1


func _fade_out_later(id: int) -> void:
	await get_tree().create_timer(float(_data.get("play_seconds", 20.0))).timeout
	if id != _play_id or not is_on:
		return
	var tw := create_tween()
	tw.tween_property(_player3d, "volume_db", -40.0, float(_data.get("fade_seconds", 4.0)))
	await tw.finished
	if id == _play_id and is_on:
		is_on = false
		_player3d.stop()
		_dial.emission_energy_multiplier = 0.0


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"heard_day": heard_day, "hint": _hint_given}


func set_state(st: Dictionary) -> void:
	heard_day = int(st.get("heard_day", 0))
	_hint_given = bool(st.get("hint", false))
