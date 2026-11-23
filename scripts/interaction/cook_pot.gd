class_name CookPot
extends RefCounted
## Ein Topf auf Ofen oder Kamin (Christian 23.11.): Zutaten kommen hinein, das Gericht gart nur, solange
## Feuer brennt (Fortschritt in Prozent wie beim Analysegerät). Geht das Feuer aus, bleibt alles drin und
## wartet. Herausnehmen: fertig = Ergebnis, unfertig = die Zutaten zurück. Nichts verschwindet.

var recipe: Dictionary = {}
var done_h: float = 0.0          ## schon gegart (Spielstunden)
var announced: bool = false      ## „fertig“ schon gemeldet


static func start(r: Dictionary) -> CookPot:
	var p := CookPot.new()
	p.recipe = r
	return p


func need_h() -> float:
	return maxf(float(recipe.get("minutes", 20)) / 60.0, 0.01)


func progress() -> float:
	return clampf(done_h / need_h(), 0.0, 1.0)


func finished() -> bool:
	return done_h >= need_h()


func title() -> String:
	if recipe.has("name"):
		return String(recipe["name"])
	var parts: PackedStringArray = []
	var gives: Dictionary = recipe.get("gives", {})
	for id in gives:
		parts.append(Inventory.display_name(id))
	return ", ".join(parts)


## Kurze Zeile für Hinweise und Menü, z. B. „Wasser abkochen – 45 %“ / „Wasser abkochen – fertig“.
func status_text() -> String:
	return "%s – %s" % [title(), "fertig" if finished() else "%d %%" % int(progress() * 100.0)]


## Gart um `hours` weiter. true = gerade eben fertig geworden.
func advance(hours: float) -> bool:
	if hours <= 0.0 or finished():
		return false
	done_h += hours
	return finished()


## Inhalt herausnehmen. Gibt die Meldung zurück; "" = Topf bleibt (nichts passte in den Rucksack).
func take_out() -> String:
	var items: Dictionary = recipe.get("gives", {}) if finished() else recipe.get("needs", {})
	for id in items:
		if Inventory.count(id) + int(items[id]) > int(DataDB.item(id).get("stack", 99)):
			return ""
	for id in items:
		Inventory.add(id, int(items[id]))
	if finished():
		Tasks.flag("cooked_" + String(recipe.get("id", "")))
		if not String(recipe.get("id", "")).begins_with("boil"):
			Tasks.flag("cooked_meal")
		return "Herausgenommen: %s." % title()
	return "Unfertig herausgenommen – die Zutaten sind zurück im Rucksack."


func to_dict() -> Dictionary:
	return {"id": String(recipe.get("id", "")), "done_h": done_h, "announced": announced}


static func from_dict(d: Dictionary) -> CookPot:
	if d.is_empty():
		return null
	for r: Dictionary in DataDB.recipes():
		if String(r.get("id", "")) == String(d.get("id", "")):
			var p := CookPot.start(r)
			p.done_h = float(d.get("done_h", 0.0))
			p.announced = bool(d.get("announced", false))
			return p
	return null


## Gemeinsamer Ablauf für Ofen und Kamin: gart nur bis `cook_until` (Spielstunden), meldet „fertig“ einmal.
static func tick(pot: CookPot, last_h: float, now_h: float, cook_until: float, where: String) -> void:
	if pot == null:
		return
	var span := minf(now_h, cook_until) - last_h
	if pot.advance(span) and not pot.announced:
		pot.announced = true
		EventBus.notify("%s: %s ist fertig." % [where, pot.title()], 3.0)
