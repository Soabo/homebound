extends Node
## Time Manager (GDD 17.2): Spielzeit, Tag/Nacht, Schlaf-Zeitsprünge.
## Jahreszeiten kommen später dazu; die Uhr ist dafür schon über Tage gezählt.

signal minute_changed(day: int, hour: int, minute: int)
signal hour_changed(day: int, hour: int)
signal phase_changed(is_night: bool)
signal day_changed(day: int)
signal time_skipped(from_total_hours: float, to_total_hours: float)

const CONFIG_PATH := "res://data/time/default_time_config.tres"

var config: TimeConfig
var day: int = 1
## Aktuelle Uhrzeit in Stunden, 0.0 bis unter 24.0.
var hour: float = 0.0
var running: bool = true
var fast_forward: bool = false

var _last_minute: int = -1
var _last_hour: int = -1
var _was_night: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	config = load(CONFIG_PATH) as TimeConfig
	if config == null:
		push_warning("TimeConfig fehlt, nutze Standardwerte.")
		config = TimeConfig.new()
	day = config.start_day
	hour = config.start_hour
	_sync_markers(false)


func _process(delta: float) -> void:
	if not running:
		return
	var multiplier := config.debug_fast_forward_multiplier if fast_forward else 1.0
	advance_hours(delta * get_hours_per_second() * multiplier)


# --- Abfragen -----------------------------------------------------------

func get_day_length_hours() -> float:
	return fposmod(config.night_start_hour - config.day_start_hour, 24.0)


func get_night_length_hours() -> float:
	return 24.0 - get_day_length_hours()


func get_hours_per_second() -> float:
	if is_night():
		return get_night_length_hours() / maxf(config.night_duration_minutes * 60.0, 1.0)
	return get_day_length_hours() / maxf(config.day_duration_minutes * 60.0, 1.0)


func is_night() -> bool:
	return is_night_at(hour)


func is_night_at(h: float) -> bool:
	return not _in_range(h, config.day_start_hour, config.night_start_hour)


func can_sleep() -> bool:
	return _in_range(hour, config.sleep_allowed_from_hour, config.sleep_allowed_until_hour)


func get_hour_int() -> int:
	return int(hour)


func get_minute() -> int:
	return int((hour - floorf(hour)) * 60.0)


func get_clock_text() -> String:
	return "%02d:%02d" % [get_hour_int(), get_minute()]


func get_total_hours() -> float:
	return float(day - 1) * 24.0 + hour


# --- Zeit verändern -----------------------------------------------------

func advance_hours(amount: float) -> void:
	if amount <= 0.0:
		return
	hour += amount
	while hour >= 24.0:
		hour -= 24.0
		day += 1
		day_changed.emit(day)
	_sync_markers(true)


## Springt vorwärts bis zur nächsten angegebenen Uhrzeit (z. B. beim Schlafen).
func skip_to_hour(target_hour: float) -> void:
	var from_total := get_total_hours()
	var diff := fposmod(target_hour - hour, 24.0)
	if diff < 0.01:
		diff = 24.0
	advance_hours(diff)
	time_skipped.emit(from_total, get_total_hours())


func set_time(new_day: int, new_hour: float) -> void:
	day = new_day
	hour = fposmod(new_hour, 24.0)
	_sync_markers(true)


# --- Speichern (für den späteren Save Manager) --------------------------

func get_state() -> Dictionary:
	return {"day": day, "hour": hour}


func set_state(state: Dictionary) -> void:
	set_time(int(state.get("day", 1)), float(state.get("hour", config.start_hour)))


# --- intern -------------------------------------------------------------

static func _in_range(h: float, from_h: float, to_h: float) -> bool:
	if from_h <= to_h:
		return h >= from_h and h < to_h
	return h >= from_h or h < to_h


func _sync_markers(emit: bool) -> void:
	var h := get_hour_int()
	var m := get_minute()
	var night := is_night()
	if emit:
		if m != _last_minute or h != _last_hour:
			minute_changed.emit(day, h, m)
		if h != _last_hour:
			hour_changed.emit(day, h)
		if night != _was_night:
			phase_changed.emit(night)
	_last_minute = m
	_last_hour = h
	_was_night = night
