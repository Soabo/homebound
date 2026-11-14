class_name Awareness
extends RefCounted
## Verdacht eines Gegners in Stufen (Christian 14.11.2026: Katz und Maus statt sofort entdeckt).
##   0 ruhig → 1 stutzt (hält inne, dreht den Kopf) → 2 sieht nach (geht zum letzten Reiz) → 3 entdeckt.
## Sehen füllt den Verdacht je nach Sichtbarkeit und Abstand, Geräusche und Atem je nach Hörweite.
## Ohne neue Reize klingt er nach decay_delay ab. Werte: StealthConfig (data/stealth/stealth.tres).

enum Stage { CALM, SUSPECT, INVESTIGATE, ALERT }

var value: float = 0.0
## Wo zuletzt etwas war (Geräusch oder Gestalt); INF = nichts
var last_pos: Vector3 = Vector3.INF
var _quiet: float = 99.0
var _stage: int = Stage.CALM
## Stufe vor der letzten Änderung (nur Anstiege lösen eine Reaktion aus)
var prev_stage: int = Stage.CALM
## Merkt sich, ob die letzte Wahrnehmung ein Blick (true) oder ein Geräusch war
var last_was_sight := false


static func cfg() -> StealthConfig:
	return StealthConfig.get_default()


## Sieht den Spieler: part = wie viel von ihm (Stealth.seen_part), vis = Sichtbarkeit, dist / range in Metern.
func see(delta: float, pos: Vector3, part: float, dist: float, range_m: float) -> void:
	if part <= 0.0 or dist > range_m:
		return
	var c := cfg()
	var near := clampf(dist / maxf(range_m, 0.1), 0.0, 1.0)
	var secs := lerpf(c.notice_close, c.notice_far, near)
	value = minf(value + delta * part / maxf(secs, 0.05), 1.0)
	last_pos = pos
	last_was_sight = true
	_quiet = 0.0


## Hört ein Geräusch der Hörweite `radius` (hearing = Faktor des Gegners). Gibt true zurück, wenn es angekommen ist.
func hear(pos: Vector3, radius: float, dist: float, hearing: float = 1.5, gain_factor: float = 1.0) -> bool:
	var reach := radius * hearing
	if reach <= 0.0 or dist > reach:
		return false
	value = minf(value + cfg().noise_gain * gain_factor * (1.0 - dist / reach), 1.0)
	last_pos = pos
	last_was_sight = false
	_quiet = 0.0
	return true


## Gehörter Atem (jedes Bild, solange er zu hören ist).
func hear_breath(delta: float, pos: Vector3) -> void:
	value = minf(value + cfg().breath_gain * delta, 1.0)
	last_pos = pos
	last_was_sight = false
	_quiet = 0.0


## Abklingen; gibt die neue Stufe zurück, wenn sie sich geändert hat (sonst -1).
func tick(delta: float) -> int:
	_quiet += delta
	if _quiet > cfg().decay_delay:
		value = maxf(value - cfg().decay * delta, 0.0)
	var s := stage()
	if s != _stage:
		prev_stage = _stage
		_stage = s
		return s
	return -1


func stage() -> int:
	var c := cfg()
	if value >= 1.0:
		return Stage.ALERT
	if value >= c.investigate_at:
		return Stage.INVESTIGATE
	if value >= c.suspect_at:
		return Stage.SUSPECT
	return Stage.CALM


func alert() -> bool:
	return value >= 1.0


## Nach dem Nachsehen ohne Fund: zurück auf „stutzt“, damit es nicht sofort wieder losgeht.
func calm_down(to: float = 0.25) -> void:
	value = minf(value, to)


func reset() -> void:
	value = 0.0
	last_pos = Vector3.INF
	_stage = Stage.CALM
	prev_stage = Stage.CALM
