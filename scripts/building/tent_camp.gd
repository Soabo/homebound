class_name TentCamp
extends Node3D
## Das Zelt als Unterschlupf für die Nacht draußen (Mutprobe).
##  E (außen) = hineinkriechen · drinnen: E schlafen, R hinauskriechen, F Uhrlicht
##  Im Zelt sieht man nach draußen nur durch den Eingang. Licht drinnen macht das Zelt zur Laterne.
##  Zeltnacht-Ereignisse (vom ThreatDirector geplant): Schritte ums Zelt, Schatten auf der Plane,
##  etwas drückt die Plane ein, eine Stimme, Licht von oben, das Feuer geht aus, der Sucher.
##  Zerrissen (Sucher/Kreatur) = man ist verletzt, kann nicht mehr darin schlafen, E flickt es (1 Brett, 3 Nägel).

const REPAIR := {"planks": 1, "nails": 3}

var structure: Structure
var torn: bool = false
var _player: Player
var _rng := RandomNumberGenerator.new()
var _busy: bool = false
var _shadow: Node3D
var _bulge: MeshInstance3D
var _night_events: int = 0


func _ready() -> void:
	add_to_group("tent_camp")
	_rng.randomize()
	torn = bool(_rec().get("torn", false))
	_apply_torn()
	TimeManager.day_changed.connect(_on_day)


func _rec() -> Dictionary:
	return Builder.record(structure.uid) if structure else {}


func occupied() -> bool:
	return _player != null


func get_prompt() -> String:
	if torn:
		return "Zelt – zerrissen  [E] flicken (1 Brett, 3 Nägel)"
	return "Zelt  [E] Hineinkriechen"


func interact(p: Player) -> void:
	if torn:
		if not Inventory.has_all(REPAIR):
			EventBus.notify("Zum Flicken brauche ich 1 Brett und 3 Nägel.", 2.5)
			return
		for id: String in REPAIR:
			Inventory.remove(id, int(REPAIR[id]))
		torn = false
		_rec()["torn"] = false
		Tasks.flag("tent_repaired")
		_apply_torn()
		SoundBank.hammer_series(get_parent(), global_position + Vector3(0, 0.6, 0), 3)
		EventBus.notify("Notdürftig geflickt. Hält vielleicht noch eine Nacht.", 3.0)
		return
	if p == null or _player:
		return
	_enter(p)


func _enter(p: Player) -> void:
	_player = p
	p.in_tent = self
	var feet := global_position + global_transform.basis * Vector3(-0.25, 0.05, -0.2)
	var fwd := (global_transform.basis * Vector3(0, 0, 1)).normalized()
	var tw := Seat.sit_down(self, p, feet, fwd, 0.42, true)
	tw.chain().tween_callback(func() -> void: p.input_locked = false)
	SoundBank.play_at(get_parent(), "backpack", global_position + Vector3(0, 0.4, 0), -6.0, 0.8)
	EventBus.interaction_prompt_changed.emit("Im Zelt   [E] Schlafen   [R] Hinauskriechen   [F] Licht")
	if TimeManager.is_night():
		ThreatDirector.plan_camp_night(self)


func leave() -> void:
	if _player == null:
		return
	var p := _player
	_player = null
	p.in_tent = null
	var back := global_position + global_transform.basis * Vector3(0, 0, size_z() * 0.5 + 1.0)
	back.y = Terrain.height_at(back.x, back.z) + 0.1
	Seat.stand_up(self, p, back)
	EventBus.interaction_prompt_changed.emit("")


func size_z() -> float:
	return structure.size.z if structure else 2.4


func _input(event: InputEvent) -> void:
	if _player == null or get_tree().paused or _player.input_locked:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_try_sleep()
	elif event.is_action_pressed("interact_secondary") and not event.is_echo():
		get_viewport().set_input_as_handled()
		leave()


func _try_sleep() -> void:
	if not TimeManager.can_sleep():
		EventBus.notify("Ich bin noch nicht müde.", 2.0)
		return
	var why := ThreatDirector.sleep_blocker()
	if why != "":
		EventBus.notify(why, 2.5)
		return
	ThreatDirector.plan_camp_night(self)
	Tasks.flag("slept_outside")
	EventBus.sleep_requested.emit(TimeManager.config.wake_up_hour)


## Licht im Zelt: leuchtet nach außen (für den Sucher).
func glowing() -> bool:
	return _player != null and _player.light_shining()


# --- Zeltnacht-Ereignisse ------------------------------------------------------

## Vom ThreatDirector: ein Ereignis der Zeltnacht. kind = "" → zufällig.
func camp_event(kind: String = "") -> void:
	if _busy:
		return
	_night_events += 1
	_rec()["visited"] = true
	if kind == "":
		var pool := ["steps", "steps", "shadow", "press", "voice", "light", "fire_out"]
		if ThreatDirector.current_night() >= ThreatDirector.config.seeker_from_day:
			pool.append_array(["seeker", "seeker"])
		kind = pool[_rng.randi() % pool.size()]
	print("[TentCamp] Ereignis: ", kind)
	match kind:
		"steps": _steps_around()
		"shadow": _shadow_pass()
		"press": _press()
		"voice": _voice()
		"light": _light_from_above()
		"fire_out": _fire_out()
		"seeker": Seeker.spawn_for(get_tree().current_scene, global_position)


func _steps_around() -> void:
	_busy = true
	var start := _rng.randf() * TAU
	var steps := 14
	for i in steps:
		var a := start + TAU * 0.85 * i / steps
		var r := 3.2 - i * 0.12
		var pos := global_position + Vector3(cos(a) * r, 0.1, sin(a) * r)
		CreatureSounds.play(get_parent(), "step", pos, -8.0 + i * 0.4, _rng.randf_range(0.85, 1.0), 25.0)
		await get_tree().create_timer(_rng.randf_range(0.7, 1.1)).timeout
		if not is_inside_tree():
			return
	# Am Eingang stehen bleiben – atmen
	var door := global_position + global_transform.basis * Vector3(0, 0.9, size_z() * 0.5 + 0.6)
	CreatureSounds.play_phrase(get_parent(), "breath", door, -6.0, 4.0, 18.0)
	EventBus.fear_changed.emit(0.6)
	await get_tree().create_timer(4.5).timeout
	_busy = false


## Ein Schatten wandert über die Plane (deutlicher, wenn draußen ein Feuer brennt).
func _shadow_pass() -> void:
	_busy = true
	var lit := false
	for f in get_tree().get_nodes_in_group("campfire"):
		if f.call("burning") and (f as Node3D).global_position.distance_to(global_position) < 9.0:
			lit = true
	if _shadow == null:
		_shadow = Node3D.new()
		add_child(_shadow)
		var dark := BuildKit.color_mat(Color(0, 0, 0, 0.75), 1.0)
		dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dark.cull_mode = BaseMaterial3D.CULL_DISABLED
		BuildKit.box(_shadow, Vector3(0.02, 0.9, 0.32), Vector3(0, 0.45, 0), dark, false)
		BuildKit.sphere(_shadow, 0.14, Vector3(0, 1.02, 0.02), dark, Vector3(0.15, 1.3, 1.0), 8)
		BuildKit.box(_shadow, Vector3(0.02, 0.7, 0.06), Vector3(0, 0.45, 0.24), dark, false, Vector3(18, 0, 0))
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var w := structure.size.x * 0.5
	_shadow.position = Vector3(side * w * 0.55, 0.0, -size_z() * 0.5)
	_shadow.rotation_degrees = Vector3(0, 0, side * 50.0)
	_shadow.scale = Vector3.ONE * (1.0 if lit else 0.8)
	_shadow.visible = true
	var mats := _shadow.find_children("*", "MeshInstance3D", true, false)
	for m: MeshInstance3D in mats:
		(m.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color.a = 0.75 if lit else 0.35
	var tw := create_tween()
	tw.tween_property(_shadow, "position:z", size_z() * 0.5, 5.5)
	tw.tween_callback(func() -> void: _shadow.visible = false)
	CreatureSounds.play(get_parent(), "step", global_position + Vector3(side * 1.8, 0.1, 0), -10.0, 0.9, 20.0)
	await tw.finished
	_busy = false


## Etwas drückt von außen gegen die Plane.
func _press() -> void:
	_busy = true
	if _bulge == null:
		_bulge = BuildKit.sphere(self, 0.25, Vector3.ZERO, BuildKit.tex_mat("fabric", 0.6, Color(0.55, 0.75, 0.5)), Vector3(1.0, 1.4, 0.4), 10)
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var w := structure.size.x * 0.5
	var out := Vector3(side * w * 0.62, 0.55, _rng.randf_range(-0.6, 0.4))
	var into := Vector3(side * w * 0.38, 0.6, out.z)
	_bulge.position = out
	_bulge.rotation_degrees = Vector3(0, 90, side * 40.0)
	_bulge.visible = true
	CreatureSounds.play_phrase(get_parent(), "breath_click", global_position + out * 1.4, -4.0, 3.0, 15.0)
	EventBus.fear_changed.emit(0.8)
	var tw := create_tween()
	tw.tween_property(_bulge, "position", into, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(1.5)
	tw.tween_property(_bulge, "position", out, 0.25)
	tw.tween_callback(func() -> void: _bulge.visible = false)
	await tw.finished
	_busy = false


func _voice() -> void:
	var a := _rng.randf() * TAU
	var pos := global_position + Vector3(cos(a) * 24.0, 1.4, sin(a) * 24.0)
	CreatureSounds.play_phrase(get_parent(), "breath", pos, -10.0, 3.0, 40.0)
	var who := "Stefanie" if _rng.randf() < 0.6 else "Ilse"
	EventBus.notify("Von draußen ruft jemand leise meinen Namen. Es klingt wie %s." % who, 4.5)


## Licht von oben: etwas schwebt über dem Zelt und leuchtet hinein.
func _light_from_above() -> void:
	_busy = true
	var spot := SpotLight3D.new()
	spot.light_color = Color(0.75, 0.85, 1.0)
	spot.light_energy = 6.0
	spot.spot_range = 30.0
	spot.spot_angle = 18.0
	spot.shadow_enabled = true
	get_tree().current_scene.add_child(spot)
	var c := global_position + Vector3(0, 14.0, 0)
	spot.global_position = c + Vector3(-10, 0, 0)
	spot.look_at(global_position + Vector3(-6, 0, 0))
	SoundBank.play_at(get_parent(), "signal", c, -10.0, 0.6)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		spot.global_position = c + Vector3(lerpf(-10.0, 10.0, t), 0, sin(t * PI) * 3.0)
		spot.look_at(global_position + Vector3(lerpf(-5.0, 5.0, t), 0, 0)), 0.0, 1.0, 9.0)
	await tw.finished
	spot.queue_free()
	_busy = false


func _fire_out() -> void:
	for f in get_tree().get_nodes_in_group("campfire"):
		if f.call("burning") and (f as Node3D).global_position.distance_to(global_position) < 12.0:
			f.call("put_out")
			EventBus.notify("Das Feuer ist aus. Einfach so. Kein Wind.", 3.5)
			return
	_steps_around()


## Sucher oder Kreatur reißt das Zelt auf: verletzt, Zelt kaputt, man liegt draußen.
func tear(damage: float) -> void:
	if torn:
		return
	torn = true
	_rec()["torn"] = true
	_apply_torn()
	SoundBank.play_at(get_parent(), "wood_crack", global_position + Vector3(0, 0.7, 0), 0.0, 0.7)
	CreatureSounds.play(get_parent(), "shriek", global_position + Vector3(0, 1.4, 1.5), -2.0)
	EventBus.screen_shake.emit(0.8)
	if _player:
		var p := _player
		var h := p.health
		p.health = maxf(h - damage, minf(h, 15.0))
		EventBus.player_hurt.emit(damage)
		leave()
		EventBus.notify("Die Plane reißt auf! Etwas hat mich durch den Stoff erwischt.", 4.0)
	Tasks.flag("tent_torn")


func _apply_torn() -> void:
	var r := structure.get_node_or_null("CanvasR") as Node3D if structure else null
	if r:
		r.visible = not torn
	var l := structure.get_node_or_null("CanvasL") as Node3D if structure else null
	if l:
		l.rotation_degrees.z = -60.0 if torn else rad_to_deg(atan2(structure.size.y, structure.size.x * 0.5)) * -1.0


## Am Morgen nach einer unruhigen Nacht: Spuren ums Zelt.
func _on_day(_d: int) -> void:
	if not bool(_rec().get("visited", false)):
		return
	_rec()["visited"] = false
	var scene := get_tree().current_scene
	var start := _rng.randf() * TAU
	for i in 6:
		var a0 := start + TAU * i / 6.0
		var a1 := start + TAU * (i + 1) / 6.0
		var p0 := global_position + Vector3(cos(a0) * 2.6, 0, sin(a0) * 2.6)
		var p1 := global_position + Vector3(cos(a1) * 2.6, 0, sin(a1) * 2.6)
		Traces.footprints(scene, p0, p1)
	var door := global_position + global_transform.basis * Vector3(0, 0, size_z() * 0.5 + 0.5)
	Traces.footprints(scene, door + Vector3(0, 0, 2.5), door)
