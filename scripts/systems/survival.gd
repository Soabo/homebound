extends Node
## Survival-Grundwerte (GDD 6.1): Hunger, Durst, Ausdauer.
## Bewusst sanft: Hunger und Durst werden erst bei längerem Vernachlässigen
## zum Problem (eine Konserve reicht gut einen Spieltag).

signal changed

## Abnahme pro Spielstunde
const HUNGER_PER_HOUR := 1.3
const THIRST_PER_HOUR := 2.0
const STAMINA_MAX := 100.0

var hunger: float = 80.0   ## 100 = satt
var warmth: float = 90.0   ## 100 = warm, 0 = erfroren (Kälte, siehe data/survival/survival.tres)
var wet_until: float = -1.0  ## nass bis (Gesamtstunden)
var cfg: SurvivalConfig
var _warned_cold: bool = false
var _shiver: float = 0.0
var _sleep_from: float = -1.0
var _sleep_rate: float = 0.0
var thirst: float = 75.0   ## 100 = kein Durst
var stamina: float = STAMINA_MAX

var _warned_hunger: bool = false
var _warned_thirst: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	cfg = SurvivalConfig.get_default()
	EventBus.sleep_requested.connect(_on_sleep)
	EventBus.sleep_finished.connect(_on_woke)


func _process(delta: float) -> void:
	if not TimeManager.running:
		return
	var hours := delta * TimeManager.get_hours_per_second() * (TimeManager.config.debug_fast_forward_multiplier if TimeManager.fast_forward else 1.0)
	hunger = maxf(hunger - HUNGER_PER_HOUR * hours, 0.0)
	thirst = maxf(thirst - THIRST_PER_HOUR * hours, 0.0)
	if hunger < 20.0 and not _warned_hunger:
		_warned_hunger = true
		EventBus.notify("Du hast Hunger. Im Vorratsraum gibt es Konserven.", 4.0)
	if thirst < 20.0 and not _warned_thirst:
		_warned_thirst = true
		EventBus.notify("Du hast Durst. Trink an der Regentonne, an der Spüle oder am Bach.", 4.0)
	_update_warmth(hours, delta)
	if hunger > 30.0:
		_warned_hunger = false
	if thirst > 30.0:
		_warned_thirst = false
	changed.emit()


## Wärme pro Stunde an der aktuellen Stelle (positiv = wird wärmer).
func warmth_rate(p: Node3D) -> float:
	var pos := p.global_position
	var night := TimeManager.is_night()
	var heat := 0.0
	var cabin_heated := false
	for n in get_tree().get_nodes_in_group("heat_source"):
		if n.has_method("heats_cabin") and n.call("heats_cabin"):
			cabin_heated = true
		if n.has_method("heat_at"):
			heat = maxf(heat, float(n.call("heat_at", pos)))
	if Cabin.is_inside(pos):
		if cabin_heated:
			return cfg.cabin_heated_gain
		return cfg.cabin_unheated_gain_night if night else cfg.cabin_unheated_gain_day
	var loss := cfg.outdoor_loss_night if night else cfg.outdoor_loss_day
	loss += maxf(pos.y, 0.0) / 100.0 * cfg.altitude_loss_per_100m * (1.0 if night else 0.4)
	if TimeManager.get_total_hours() < wet_until:
		loss *= cfg.wet_factor
	if Inventory.count("heat_stone") > 0:
		loss *= float(Research.gadget("heat_stone", "loss_factor", 0.55))
	var tent := p.get("in_tent") as Node
	if tent and is_instance_valid(tent):
		loss *= cfg.tent_factor
		if Inventory.count("sleeping_bag") > 0:
			loss *= cfg.sleeping_bag_factor
	return heat * cfg.fire_gain - loss


func _update_warmth(hours: float, delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or hours <= 0.0:
		return
	warmth = clampf(warmth + warmth_rate(p) * hours, 0.0, 100.0)
	if warmth < cfg.cold_warn:
		if not _warned_cold:
			_warned_cold = true
			EventBus.notify("Mir ist kalt. Ich brauche ein Feuer – oder ein Dach über dem Kopf.", 4.0)
		# Zittern
		_shiver -= delta
		if _shiver <= 0.0:
			_shiver = lerpf(1.4, 4.0, warmth / cfg.cold_warn)
			EventBus.screen_shake.emit(lerpf(0.25, 0.08, warmth / cfg.cold_warn))
	elif warmth > cfg.cold_warn + 10.0:
		_warned_cold = false


func set_wet() -> void:
	wet_until = TimeManager.get_total_hours() + cfg.wet_hours


## Schlaf: Wärme über die geschlafenen Stunden (Hütte ohne Verlust, Zelt je nach Schlafsack und Feuer).
func _on_sleep(_wake: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	_sleep_from = TimeManager.get_total_hours()
	_sleep_rate = 0.0
	if p and not Cabin.is_inside(p.global_position):
		_sleep_rate = minf(warmth_rate(p), 0.0)
		# ein Lagerfeuer brennt nur ein paar Stunden – danach zählt nur noch die Kälte
		var fire := 0.0
		for n in get_tree().get_nodes_in_group("heat_source"):
			if n.has_method("heat_at") and n.has_method("hours_left"):
				if float(n.call("heat_at", p.global_position)) > 0.1:
					fire = maxf(fire, float(n.call("hours_left")))
		_sleep_fire_hours = fire


var _sleep_fire_hours: float = 0.0


func _on_woke() -> void:
	if _sleep_from < 0.0:
		return
	var hours := maxf(TimeManager.get_total_hours() - _sleep_from, 0.0)
	_sleep_from = -1.0
	if _sleep_rate >= 0.0:
		warmth = maxf(warmth, 70.0)
		return
	var cold_hours := maxf(hours - _sleep_fire_hours, 0.0)
	warmth = clampf(warmth + _sleep_rate * cold_hours, 0.0, 100.0)
	if warmth < cfg.freeze_below:
		var p := get_tree().get_first_node_in_group("player")
		if p:
			var h := float(p.get("health"))
			p.set("health", maxf(h - cfg.sleep_freeze_damage, minf(h, cfg.sleep_min_health)))
		EventBus.notify("Durchgefroren aufgewacht. Ich spüre meine Finger kaum. (Schlafsack? Feuer?)", 5.0)
	elif warmth < cfg.cold_warn:
		EventBus.notify("Kalt geschlafen. Ein Schlafsack wäre gut.", 3.5)


## Schaden pro Sekunde, wenn man verhungert/verdurstet (sehr langsam) oder erfriert.
func starvation_damage() -> float:
	var d := 0.0
	if warmth < cfg.freeze_below:
		d += cfg.freeze_damage * (2.0 if warmth <= 0.0 else 1.0)
	if hunger <= 0.0:
		d += 0.4
	if thirst <= 0.0:
		d += 0.6
	return d


## Maximale Ausdauer sinkt bei Hunger/Durst.
func stamina_cap() -> float:
	var cap := STAMINA_MAX
	if hunger < 20.0:
		cap -= 30.0
	if thirst < 20.0:
		cap -= 30.0
	if warmth < cfg.cold_warn:
		cap -= cfg.cold_stamina_cut
	return cap


## Rennen kostet Ausdauer; gibt zurück, ob noch gerannt werden kann.
func use_stamina(amount: float) -> bool:
	if stamina <= 0.0:
		return false
	stamina = maxf(stamina - amount, 0.0)
	return true


func regen_stamina(amount: float) -> void:
	stamina = minf(stamina + amount, stamina_cap())


func apply(effect: Dictionary) -> void:
	if effect.has("hunger"):
		hunger = minf(hunger + float(effect["hunger"]), 100.0)
		EventBus.notify("Gegessen.", 1.5)
		PlayerSounds.play_phrase(self, "eat", -6.0, 2.6)
	if effect.has("thirst"):
		thirst = minf(thirst + float(effect["thirst"]), 100.0)
		EventBus.notify("Getrunken.", 1.5)
		PlayerSounds.play_phrase(self, "drink", -4.0, 2.4, true)
	changed.emit()


## Still abziehen (z. B. Übelkeit), ohne Ess-/Trinkgeräusch.
func drain(h: float, t: float) -> void:
	hunger = maxf(hunger - h, 0.0)
	thirst = maxf(thirst - t, 0.0)
	changed.emit()


func get_state() -> Dictionary:
	return {"hunger": hunger, "thirst": thirst, "warmth": warmth}


func set_state(s: Dictionary) -> void:
	hunger = float(s.get("hunger", 80.0))
	thirst = float(s.get("thirst", 75.0))
	warmth = float(s.get("warmth", 90.0))
	stamina = STAMINA_MAX
	# Reste des abgebrochenen Tages: nasse Kleidung, laufender Schlaf, Warnungen
	wet_until = -1.0
	_sleep_from = -1.0
	_warned_hunger = false
	_warned_thirst = false
	_warned_cold = false
	changed.emit()
