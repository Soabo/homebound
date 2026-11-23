class_name Fear
extends RefCounted
## Angst des Spielers (Christian 23.11.2026). Ein Wert 0..1, der jedes Bild im Player läuft (`Player.fear`).
##  - steigt: Wesen gesehen (je näher, desto mehr), Wesen in der Nähe gehört, ein Wesen hat dich bemerkt,
##    nachts draußen im Dunkeln, weit weg von der Hütte, Belagerung, Atem lange angehalten, Treffer, Schreckmomente
##    (`EventBus.fear_spike`).
##  - sinkt: langsam von selbst, schneller am Licht/Feuer, im Versteck (durchatmen) und wenn nichts in der Nähe ist.
##  - Folgen: Herzschlag, dunkle Ränder (Hud), zitternde Hände + LED (PlayerHands), lautere Schritte und Geräusche
##    (`noise_factor`), hörbarer Atem (`breath_factor`, `betrays_breath`), Rennen und Atemanhalten kosten mehr Puste.
## Werte: data/player/fear.tres (`FearConfig`).

var level: float = 0.0       ## Angst jetzt (0..1)
var spike: float = 0.0       ## Schreck, klingt ab
var base: float = 0.0        ## Ziel ohne Schreck (für Tests)
var calm: bool = false       ## gerade am Licht / im Versteck
var _scan_t: float = 0.0
var _threat_target: float = 0.0
var _threat_close: bool = false


static func cfg() -> FearConfig:
	return FearConfig.get_default()


## Ein Schreckmoment (0..1): springt sofort hoch und klingt dann ab.
func add_spike(amount: float) -> void:
	spike = clampf(maxf(spike, amount), 0.0, 1.0)
	level = maxf(level, spike)


func update(pl: Player, delta: float) -> void:
	var c := cfg()
	if GameState.dead:
		level = move_toward(level, 0.0, delta * 0.5)
		spike = 0.0
		return
	# Wesen nur ein paar Mal pro Sekunde prüfen (Sichtlinien kosten)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.2
		_scan_threats(pl)
	var t := _threat_target
	var p := pl.global_position
	var inside := Cabin.is_inside(p) or Shed.is_inside(p)
	var night := TimeManager.is_night()
	if night and not inside:
		if not pl.light_shining() and not Stealth.near_light(pl.get_tree(), p, c.calm_light_range):
			t = maxf(t, c.dark_outside)
		if ThreatDirector.far_from_home():
			t = maxf(t, c.far_night)
	if SiegeNight.current != null:
		t = maxf(t, c.siege_base)
	if pl.holding_breath and pl.breath_held > c.breath_hold_from:
		t = maxf(t, clampf((pl.breath_held - c.breath_hold_from) / 10.0, 0.0, c.breath_hold_max))
	# Ruhe: Licht/Feuer in der Nähe, im Versteck – aber nicht, wenn etwas ganz nah ist
	calm = false
	if not _threat_close:
		if pl.is_hidden():
			t *= c.calm_hidden_factor
			calm = true
		elif Stealth.near_light(pl.get_tree(), p, c.calm_light_range):
			t *= c.calm_light_factor
			calm = true
	base = t
	spike = maxf(spike - c.spike_decay * delta, 0.0)
	var target := maxf(t, spike)
	var fall := c.fall_speed_calm if calm else c.fall_speed
	level = move_toward(level, target, delta * (c.rise_speed if target > level else fall))


func _scan_threats(pl: Player) -> void:
	var c := cfg()
	var best := 0.0
	var close := false
	var cam := pl.camera.global_transform
	var fwd := -cam.basis.z
	for g: String in c.threat_groups:
		for n in pl.get_tree().get_nodes_in_group(g):
			if not (n is Node3D) or not (n as Node3D).is_visible_in_tree():
				continue
			var at := (n as Node3D).global_position + Vector3(0, 1.2, 0)
			var d := at.distance_to(cam.origin)
			if d > c.seen_range:
				continue
			var to := (at - cam.origin) / maxf(d, 0.01)
			var seen := fwd.dot(to) > cos(deg_to_rad(42.0)) and _line_clear(pl, cam.origin, at, n)
			if seen:
				best = maxf(best, lerpf(c.seen_near, c.seen_far, clampf(d / c.seen_range, 0.0, 1.0)))
			elif d < c.heard_range:
				best = maxf(best, c.heard_target * (1.0 - 0.5 * d / c.heard_range))
			if d < c.heard_range * 0.6:
				close = true
	if StealthHud.max_awareness(pl.get_tree()) >= 1.0:
		best = maxf(best, c.alert_target)
		close = true
	_threat_target = best
	_threat_close = close


static func _line_clear(pl: Player, from: Vector3, to: Vector3, target: Node) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [pl.get_rid()]
	var hit := pl.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	var col: Object = hit.get("collider")
	# Treffer am Wesen selbst (oder an einem seiner Teile) zählt als frei; Glas lässt Blicke durch
	if col is Node and (col == target or target.is_ancestor_of(col as Node)):
		return true
	return col is Node and (col as Node).is_in_group("see_through")


# --- Folgen ---------------------------------------------------------------

## Hörweite von Schritten und Geräuschen × dieser Faktor
func noise_factor() -> float:
	return 1.0 + cfg().noise_extra * level


## Atem: Hörweite × dieser Faktor
func breath_factor() -> float:
	return 1.0 + cfg().breath_extra * level


## Verrät einen der Atem schon im Stehen?
func betrays_breath() -> bool:
	return level >= cfg().breath_betray_from


func sprint_drain() -> float:
	return 1.0 + cfg().sprint_drain_extra * level


func breath_drain() -> float:
	return 1.0 + cfg().breath_drain_extra * level
