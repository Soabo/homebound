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
var thirst: float = 75.0   ## 100 = kein Durst
var stamina: float = STAMINA_MAX

var _warned_hunger: bool = false
var _warned_thirst: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


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
	if hunger > 30.0:
		_warned_hunger = false
	if thirst > 30.0:
		_warned_thirst = false
	changed.emit()


## Schaden pro Sekunde, wenn man verhungert/verdurstet (sehr langsam).
func starvation_damage() -> float:
	var d := 0.0
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
	return {"hunger": hunger, "thirst": thirst}


func set_state(s: Dictionary) -> void:
	hunger = float(s.get("hunger", 80.0))
	thirst = float(s.get("thirst", 75.0))
	stamina = STAMINA_MAX
	changed.emit()
