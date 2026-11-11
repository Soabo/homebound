extends Node
## Stromversorgung (GDD 7.4): Generator, Treibstoff, Verbraucher, Stromausfall.
## Lampen, Kameras und Monitor fragen has_power() bzw. hören auf power_changed.

signal power_changed(has_power: bool)
signal fuel_changed(fuel: float)

## Treibstoff in Prozent des Tanks.
var fuel: float = 55.0
var generator_running: bool = false  ## zu Spielbeginn aus (Christian) – erst anwerfen
## Ausfall durch ein Ereignis – der Generator muss neu gestartet werden.
var outage: bool = false

## Verbrauch in Prozent pro Spielstunde: Grundlast + je eingeschaltetem Verbraucher.
const BASE_USE := 2.0
const USE_PER_CONSUMER := 0.6

var _consumers: Dictionary = {}
var _last_power: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_last_power = has_power()


func has_power() -> bool:
	return generator_running and fuel > 0.0 and not outage


func _process(delta: float) -> void:
	if generator_running and not outage:
		var hours := delta * TimeManager.get_hours_per_second() * (TimeManager.config.debug_fast_forward_multiplier if TimeManager.fast_forward else 1.0)
		if not TimeManager.running:
			hours = 0.0
		var use := (BASE_USE + _consumers.size() * USE_PER_CONSUMER) * hours
		if use > 0.0:
			fuel = maxf(fuel - use, 0.0)
			fuel_changed.emit(fuel)
			if fuel <= 0.0:
				generator_running = false
				EventBus.notify("Der Generator ist aus – kein Benzin mehr.", 4.0)
	_check()


## Verbraucher melden sich an/ab (z. B. eingeschaltete Lampen, laufender Monitor).
func set_consumer(id: String, active: bool) -> void:
	if active:
		_consumers[id] = true
	else:
		_consumers.erase(id)


## Wie viele Spielstunden das Benzin beim jetzigen Verbrauch noch reicht.
func hours_left() -> float:
	return fuel / (BASE_USE + _consumers.size() * USE_PER_CONSUMER)


func start_generator() -> bool:
	if fuel <= 0.0:
		EventBus.notify("Kein Benzin im Tank.", 2.5)
		return false
	generator_running = true
	outage = false
	_check()
	return true


func stop_generator() -> void:
	generator_running = false
	_check()


func add_fuel(amount: float) -> void:
	fuel = minf(fuel + amount, 100.0)
	fuel_changed.emit(fuel)


## Stromausfall durch ein Ereignis (Threat Director).
func trigger_outage() -> void:
	if not has_power():
		return
	outage = true
	generator_running = false
	_check()


func _check() -> void:
	var p := has_power()
	if p != _last_power:
		_last_power = p
		power_changed.emit(p)


func get_state() -> Dictionary:
	return {"fuel": fuel, "running": generator_running, "outage": outage}


func set_state(s: Dictionary) -> void:
	fuel = float(s.get("fuel", 55.0))
	generator_running = bool(s.get("running", false))
	outage = bool(s.get("outage", false))
	_consumers.clear()
	_last_power = not has_power()
	_check()
