class_name KeyCard
extends PanelContainer
## Tastenbild auf dunklem Papier (Christian 26.11.): F1 im Spiel, „Steuerung“ in Pause und Hauptmenü.
## Inhalt aus data/ui/controls.json.


static func data() -> Dictionary:
	return DataDB.load_json("res://data/ui/controls.json")


## Nur das Raster mit den Tastengruppen (für eigene Fenster, z. B. Hauptmenü).
static func build_grid(size: int = 18) -> HBoxContainer:
	var cols := HBoxContainer.new()
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_theme_constant_override("separation", 40)
	for g: Dictionary in Array(data().get("groups", [])):
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 7)
		var head := UiStyle.label(col, "type", size + 4, UiStyle.EMBER, String(g.get("title", "")))
		head.add_theme_constant_override("outline_size", 0)
		for k: Array in Array(g.get("keys", [])):
			UiStyle.key_row(col, String(k[0]), String(k[1]), size)
		cols.add_child(col)
	return cols


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiStyle.paper(0.9, 8, 28))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	var t := UiStyle.label(box, "type", 30, UiStyle.INK, "Steuerung")
	t.add_theme_constant_override("outline_size", 0)
	box.add_child(build_grid())
	var hint := UiStyle.label(box, "ui", 16, UiStyle.INK_DIM, "F1 schließt dieses Bild.")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
