class_name W17Locator
extends CanvasLayer
## W-17 als Suchgerät: Trägt man es bei sich, summt es in der Nähe fremder Orte (data/world/map.json → w17_sites),
## je näher, desto schneller und höher. Unten in der Mitte eine kleine Anzeige.
## Der Sucher spürt W-17 auch (SeekerConfig.w17_range).

const RANGE := 320.0

var _label: Label
var _t: float = 0.0
var _beep: float = 0.0
var _player: Node3D


func _ready() -> void:
	name = "W17Locator"
	layer = 5
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = -120
	_label.offset_right = 120
	_label.offset_top = -118
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.visible = false
	add_child(_label)


## 0..1: Signalstärke am Punkt und der Ort, der am stärksten anschlägt.
static func signal_at(p: Vector3) -> Array:
	var best := 0.0
	var best_id := ""
	var q := Vector2(p.x, p.z)
	for id: String in WorldMap.data().get("w17_sites", []):
		var d := WorldMap.place_pos(id).distance_to(q)
		var s := clampf(1.0 - d / RANGE, 0.0, 1.0)
		s = s * s
		if s > best:
			best = s
			best_id = id
	return [best, best_id]


func _process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var carried := Inventory.count("w17") > 0 and _player != null
	_label.visible = carried
	if not carried:
		return
	var sig := signal_at(_player.global_position)
	var s: float = sig[0]
	var bars := int(round(s * 6.0))
	_label.text = "W-17  " + "▮".repeat(bars) + "▯".repeat(6 - bars)
	_label.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * lerpf(2.0, 14.0, s)))
	_beep -= delta
	if s > 0.02 and _beep <= 0.0:
		_beep = lerpf(3.2, 0.3, s)
		SoundBank.play_ui(self, "signal", lerpf(-26.0, -12.0, s), lerpf(0.7, 1.6, s))
