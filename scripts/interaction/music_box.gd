class_name MusicBox
extends Interactable
## Bens Spieluhr im Kinderzimmer (auf der Spielzeugkiste). Sonst: aufziehen = spielt einmal ihr Lied.
## In der Belagerungsnacht (SiegeNight, Aufgabe "music"): läuft langsam ab, wird immer langsamer und tiefer –
## immer wieder aufziehen, sonst lockt der Manipulator mit Kinderstimmen.

var _player: AudioStreamPlayer3D
var _crank: Node3D
var _siege := false
var _wind := 1.0


func _ready() -> void:
	add_to_group("music_box")
	var wood := BuildKit.tex_mat("planks_h", 0.4, Color(0.95, 0.75, 0.6))
	var brass := BuildKit.color_mat(Color(0.75, 0.6, 0.3), 0.35, 0.8)
	BuildKit.box(self, Vector3(0.16, 0.08, 0.11), Vector3(0, 0.04, 0), wood, false)
	BuildKit.box(self, Vector3(0.165, 0.015, 0.115), Vector3(0, 0.085, 0), BuildKit.tex_mat("planks_h", 0.4, Color(0.8, 0.55, 0.45)), false)
	# kleine Tänzerin / Stern obendrauf
	BuildKit.cylinder(self, 0.006, 0.04, Vector3(0, 0.11, 0), brass, false, Vector3.ZERO, -1.0, 5)
	BuildKit.sphere(self, 0.018, Vector3(0, 0.14, 0), BuildKit.color_mat(Color(0.95, 0.85, 0.3), 0.3, 0.5), Vector3(1.0, 1.0, 0.4), 6)
	_crank = Node3D.new()
	_crank.position = Vector3(0.085, 0.04, 0)
	add_child(_crank)
	BuildKit.cylinder(_crank, 0.004, 0.03, Vector3(0.015, 0, 0), brass, false, Vector3(0, 0, 90), -1.0, 5)
	BuildKit.box(_crank, Vector3(0.006, 0.035, 0.008), Vector3(0.03, 0.015, 0), brass, false)
	var body := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.3, 0.25, 0.25)
	cs.shape = sh
	cs.position = Vector3(0, 0.08, 0)
	body.add_child(cs)
	add_child(body)
	_player = AudioStreamPlayer3D.new()
	_player.stream = SoundBank.get_sound("music_box")
	_player.volume_db = -4.0
	_player.unit_size = 3.0
	add_child(_player)
	_player.finished.connect(func() -> void:
		if _siege and _wind > 0.0:
			_player.play())


func get_prompt(_p: Node) -> String:
	if _siege:
		return "Bens Spieluhr (%d %%)  [E] aufziehen" % int(_wind * 100.0)
	return "Bens Spieluhr  [E] aufziehen"


func interact(_p: Node) -> void:
	var tw := create_tween()
	tw.tween_property(_crank, "rotation:x", _crank.rotation.x + TAU * 2.0, 0.8)
	SoundBank.play_at(get_parent(), "switch", global_position, -12.0, 1.6)
	if _siege and SiegeNight.current:
		SiegeNight.current.wind_music_box()
	if not _player.playing:
		_player.pitch_scale = 1.0
		_player.play()


func start_siege() -> void:
	_siege = true
	_wind = 1.0
	_player.play()


func end_siege() -> void:
	_siege = false
	_player.stop()


func set_wind(w: float) -> void:
	_wind = w
	# läuft langsam ab: tiefer, leiser, langsamer
	_player.pitch_scale = lerpf(0.55, 1.0, clampf(w, 0.0, 1.0))
	_player.volume_db = lerpf(-14.0, -4.0, clampf(w, 0.0, 1.0))
	if w <= 0.0 and _player.playing:
		_player.stop()
	elif w > 0.0 and not _player.playing and _siege:
		_player.play()
	_crank.rotation.x += 0.02 * w
