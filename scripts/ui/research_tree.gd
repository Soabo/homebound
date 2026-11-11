class_name ResearchTree
extends Control
## Forschungsbaum auf dem Tablet (Forschung 2.0): alle Projekte und Verknüpfungen als Kästchen, von links
## (keine Voraussetzung) nach rechts (braucht vieles). Linien = Voraussetzungen, goldene Linien = Verknüpfungen.
## Unbekanntes bleibt „???“, bis man den Fund gesehen hat. Anklicken zeigt Einzelheiten.

signal picked(id: String)

const BOX := Vector2(236, 60)
const GAP := Vector2(64, 12)
const MARGIN := Vector2(16, 34)
const AREA_COLORS := {
	"Technologie": Color(0.55, 0.75, 0.95),
	"Biologie": Color(0.55, 0.9, 0.6),
	"Energie und Physik": Color(0.95, 0.85, 0.45),
	"Spezies und Verhalten": Color(0.95, 0.55, 0.5),
	"Raumfahrt und Infrastruktur": Color(0.7, 0.65, 0.95),
	"Menschen und WURZELWERK": Color(0.9, 0.6, 0.85),
	"Zusammenhänge": Color(1.0, 0.8, 0.5),
}
const STATION_SHORT := {"device": "Analysegerät", "bench": "Arbeitsplatte", "microscope": "Mikroskop",
	"terrarium": "Terrarium", "shield": "Abschirmkasten", "screen": "Auswertung"}

var pos: Dictionary = {}      ## id -> Vector2 (linke obere Ecke)
var depth: Dictionary = {}
var bands: Array = []          ## [[Gebiet, y], …]
var selected: String = ""
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	layout_nodes()
	Research.changed.connect(queue_redraw)


static func is_link(id: String) -> bool:
	return (Research.data().get("links", {}) as Dictionary).has(id)


static func needs_of(id: String) -> Array:
	if is_link(id):
		return Research.link_def(id).get("needs", [])
	return Research.analysis(id).get("requires", [])


func _depth(id: String, guard: int = 0) -> int:
	if depth.has(id):
		return depth[id]
	var d := 0
	if guard < 12:
		for n: String in needs_of(id):
			d = maxi(d, _depth(n, guard + 1) + 1)
	depth[id] = d
	return d


## Zeilen nach Forschungsgebiet (Bänder), Spalten nach Stufe.
func layout_nodes() -> void:
	pos.clear()
	depth.clear()
	bands.clear()
	var ids: Array = []
	ids.append_array((Research.data().get("analyses", {}) as Dictionary).keys())
	ids.append_array((Research.data().get("links", {}) as Dictionary).keys())
	var areas: Array = Research.data().get("areas", [])
	var max_col := 0
	var y := MARGIN.y
	for area: String in areas:
		var cols: Dictionary = {}
		for id: String in ids:
			if _area(id) != area:
				continue
			var d := _depth(id)
			max_col = maxi(max_col, d)
			if not cols.has(d):
				cols[d] = []
			cols[d].append(id)
		if cols.is_empty():
			continue
		bands.append([area, y])
		y += 24.0
		var rows := 0
		for d: int in cols:
			var col: Array = cols[d]
			col.sort()
			for i in col.size():
				pos[col[i]] = Vector2(MARGIN.x + d * (BOX.x + GAP.x), y + i * (BOX.y + GAP.y))
			rows = maxi(rows, col.size())
		y += rows * (BOX.y + GAP.y) + 10.0
	custom_minimum_size = Vector2(MARGIN.x * 2.0 + (max_col + 1) * (BOX.x + GAP.x), y + MARGIN.y)
	queue_redraw()


static func _area(id: String) -> String:
	if is_link(id):
		return String(Research.link_def(id).get("area", "Zusammenhänge"))
	return String(Research.analysis(id).get("area", ""))


## done = fertig (und gesendet), open = kann begonnen/verknüpft werden, known = Fund gesehen, hidden = ???
static func state_of(id: String) -> String:
	if is_link(id):
		if Research.links_done.has(id):
			return "done"
		if Research.can_link(id):
			return "open"
		var any := false
		for n: String in Research.link_def(id).get("needs", []):
			if Research.done.has(n):
				any = true
		return "known" if any else "hidden"
	if Research.done.has(id):
		return "done" if Research.is_sent(id) else "open"
	var find := String(Research.analysis(id).get("find", ""))
	if Research.running_at(id) != "":
		return "running"
	if Research.requirements_met(id) and Research.seen.has(find):
		return "open"
	if Research.seen.has(find) or Research.requirements_met(id) and needs_of(id).size() > 0:
		return "known"
	return "hidden"


static func title_of(id: String) -> String:
	var st := state_of(id)
	if st == "hidden":
		return "???"
	if is_link(id):
		return "◆ " + String(Research.link_def(id).get("name", id))
	return String(Research.analysis(id).get("name", id))


func _draw() -> void:
	# Spaltenköpfe
	var cols := 0
	for id: String in pos:
		cols = maxi(cols, int(depth.get(id, 0)) + 1)
	for c in cols:
		var t := "Erste Funde" if c == 0 else "Stufe %d" % (c + 1)
		draw_string(_font, Vector2(MARGIN.x + c * (BOX.x + GAP.x), 20), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.62, 0.7))
	for b: Array in bands:
		var col: Color = AREA_COLORS.get(b[0], Color(0.7, 0.7, 0.7))
		draw_line(Vector2(MARGIN.x, float(b[1]) + 4.0), Vector2(size.x - MARGIN.x, float(b[1]) + 4.0), Color(col, 0.25), 1.0)
		draw_string(_font, Vector2(MARGIN.x, float(b[1]) + 19.0), String(b[0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col.darkened(0.1))
	# Linien zuerst
	for id: String in pos:
		var to: Vector2 = pos[id] + Vector2(0, BOX.y * 0.5)
		var link := is_link(id)
		for n: String in needs_of(id):
			if not pos.has(n):
				continue
			var from: Vector2 = pos[n] + Vector2(BOX.x, BOX.y * 0.5)
			var vis := state_of(n) != "hidden" or state_of(id) != "hidden"
			var col := Color(1.0, 0.8, 0.45, 0.55) if link else Color(0.6, 0.7, 0.8, 0.45)
			if not vis:
				col.a = 0.12
			if id == selected or n == selected:
				col.a = 1.0
			var mid := (from.x + to.x) * 0.5
			var pts := PackedVector2Array([from, Vector2(mid, from.y), Vector2(mid, to.y), to])
			draw_polyline(pts, col, 2.0 if id == selected or n == selected else 1.2, true)
	# Kästchen
	for id: String in pos:
		var p: Vector2 = pos[id]
		var st := state_of(id)
		var area_col: Color = AREA_COLORS.get(_area(id), Color(0.7, 0.7, 0.7))
		var bg := Color(0.08, 0.1, 0.12)
		var fg := Color(0.85, 0.88, 0.9)
		match st:
			"done":
				bg = area_col.darkened(0.55)
				fg = Color(0.95, 0.97, 0.95)
			"running":
				bg = Color(0.12, 0.2, 0.22)
			"open":
				bg = Color(0.14, 0.15, 0.12)
				fg = Color(1.0, 0.92, 0.7)
			"known":
				fg = Color(0.65, 0.68, 0.7)
			"hidden":
				fg = Color(0.35, 0.38, 0.4)
				area_col = area_col.darkened(0.6)
		var r := Rect2(p, BOX)
		draw_rect(r, bg)
		draw_rect(Rect2(p, Vector2(5, BOX.y)), area_col)
		draw_rect(r, Color(1.0, 0.9, 0.5) if id == selected else area_col.darkened(0.3), false, 2.0 if id == selected else 1.0)
		# Titel darf zweizeilig sein (lange Namen werden umbrochen statt abgeschnitten)
		draw_multiline_string(_font, p + Vector2(11, 17), title_of(id), HORIZONTAL_ALIGNMENT_LEFT, BOX.x - 18, 13, 2, fg)
		var sub := ""
		if st != "hidden":
			if is_link(id):
				sub = "Verknüpfung" + ("  ✓" if st == "done" else ("  – jetzt möglich" if st == "open" else ""))
			else:
				var h := Research.hours_needed(id)
				sub = "%s · %s" % [STATION_SHORT.get(Research.station_of(id), ""), ResearchMenu.fmt_hours(h).trim_prefix("ca. ")]
				if st == "running":
					sub = "läuft %d %%" % int(Research.progress_of(id) * 100.0)
				elif st == "done":
					sub += "  ✓"
				if bool(Research.analysis(id).get("living", false)):
					sub += "  · lebend"
		draw_string(_font, p + Vector2(11, 53), sub, HORIZONTAL_ALIGNMENT_LEFT, BOX.x - 16, 11, fg.darkened(0.25))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for id: String in pos:
			if Rect2(pos[id], BOX).has_point(event.position):
				selected = id
				picked.emit(id)
				queue_redraw()
				accept_event()
				return


## Text zu einem Kästchen (für die Zeile unter dem Baum).
static func describe(id: String) -> String:
	var st := state_of(id)
	if st == "hidden":
		return "Noch unbekannt. Vielleicht findest du draußen etwas, das hierher gehört."
	var needs: PackedStringArray = []
	for n: String in needs_of(id):
		var ok := Research.requirement_done(n)
		needs.append(("✓ " if ok else "○ ") + (title_of(n) if state_of(n) != "hidden" else "???"))
	var need_text := ("   Voraussetzungen: " + ", ".join(needs)) if not needs.is_empty() else ""
	if is_link(id):
		var l := Research.link_def(id)
		var t := String(l.get("text", "")) if st == "done" else "Verbindet zwei Ergebnisse."
		var unlocks: PackedStringArray = []
		for u: String in l.get("unlocks", []):
			unlocks.append(Inventory.display_name(u))
		return "%s – %s%s%s" % [l.get("name", id), t, ("   Bauplan: " + ", ".join(unlocks)) if not unlocks.is_empty() and st == "done" else "", need_text]
	var a := Research.analysis(id)
	var find := String(a.get("find", ""))
	var where := "%s, %s" % [STATION_SHORT.get(Research.station_of(id), ""), ResearchMenu.fmt_hours(Research.hours_needed(id))]
	var body := String(a.get("summary", "")) if st == "done" else ("Fund: %s (%s)" % [Inventory.display_name(find), "dabei" if Inventory.count(find) > 0 else ("schon gesehen" if Research.seen.has(find) else "noch nicht gefunden")])
	return "%s  [%s]  –  %s%s" % [a.get("name", id), where, body, need_text]
