class_name Radio
extends Interactable
## Altes Batterieradio auf dem Schreibtisch. Läuft auch ohne Strom –
## und schaltet sich manchmal nachts von selbst ein (GDD 13.2, Phase 5).
## Phase 7: An der Werkbank wird es zum improvisierten Analysegerät umgebaut; später
## kommt daneben das fremde Analysegerät von der Absturzstelle (GDD 12.5).
## Der Knoten liegt im Ursprung der Hütte; anchor = Position des Radios.

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


func get_prompt(_player: Node) -> String:
	if Inventory.count("alien_analyzer") > 0 and Research.tier < 2:
		return "[E] Fremdes Analysegerät hier aufstellen"
	if Research.tier >= 1:
		var status := ""
		if Research.slot != "":
			status = "  (%s: %d%%)" % [Research.analysis(Research.slot).get("name", ""), int(Research.progress_of(Research.slot) * 100.0)]
		return "[E] %s%s" % [Research.device_name(), status]
	return "[E] Radio %s" % ("ausschalten" if is_on else "einschalten")


func get_secondary_prompt(_player: Node) -> String:
	if Research.tier >= 1:
		return "[R] Radio %s" % ("ausschalten" if is_on else "einschalten")
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
	if _meter_needle:
		var active := Research.slot != "" and Research.has_power_for_analysis()
		_meter_needle.rotation.z = (sin(_t * 7.0) * 0.25 + 0.3) if active else -0.6


func set_on(v: bool) -> void:
	is_on = v
	# Hinweis auf die Absturzstelle, solange sie noch niemand gefunden hat
	if v and not _hint_given and not Research.seen.has("metal_fragment") and TimeManager.hour > 6.0 and TimeManager.hour < 20.0:
		_hint_given = true
		EventBus.notify("Im Radio: Rauschen, dann Bruchstücke – „…helle Lichter über dem Wald … nordwestlich der alten Forststraße … Rauch …“", 7.0)
	_dial.emission_energy_multiplier = 2.5 if v else 0.0
	if v:
		_player3d.play()
	else:
		_player3d.stop()
	SoundBank.play_at(self, "switch", to_global(anchor), -6.0, 0.7)
