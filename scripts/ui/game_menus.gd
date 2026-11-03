class_name GameMenus
extends CanvasLayer
## Inventar (Tab) und Werkbank-Menü. Beide lassen die Welt weiterlaufen –
## nachts ist man also auch beim Herumkramen nicht sicher.

var _root: Control
var _title: Label
var _list: VBoxContainer
var _info: Label
var _mode: String = ""  ## "", "inventory", "crafting"


func _ready() -> void:
	name = "GameMenus"
	layer = 8
	add_to_group("game_menus")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.2
	panel.anchor_right = 0.8
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.9
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 0.95)
	style.border_color = Color(0.45, 0.35, 0.25)
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
	v.add_child(_title)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 18)
	_info.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_info)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var hint := Label.new()
	hint.text = "Tab / Esc  schließen"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))
	v.add_child(hint)
	Inventory.changed.connect(_refresh)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if _mode == "":
			if _player_free():
				open_inventory()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif _mode != "" and event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()


func _player_free() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Player
	return p != null and not p.input_locked and not get_tree().paused


func open_inventory() -> void:
	_open("inventory")


func open_crafting() -> void:
	_open("crafting")


func _open(m: String) -> void:
	_mode = m
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p := get_tree().get_first_node_in_group("player") as Player
	if p:
		p.input_locked = true
	SoundBank.play_ui(self, "switch", -8.0, 0.8)
	_refresh()


func close() -> void:
	if _mode == "":
		return
	_mode = ""
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var p := get_tree().get_first_node_in_group("player") as Player
	if p:
		p.input_locked = false


func is_open() -> bool:
	return _mode != ""


func _refresh() -> void:
	if _mode == "":
		return
	for c in _list.get_children():
		c.queue_free()
	if _mode == "inventory":
		_fill_inventory()
	else:
		_fill_crafting()


func _fill_inventory() -> void:
	_title.text = "Inventar"
	_info.text = "Traglast %.1f / %.0f kg      Hunger %d%%   Durst %d%%   Ausdauer %d%%" % [
		Inventory.total_weight(), Inventory.MAX_WEIGHT, int(Survival.hunger), int(Survival.thirst), int(Survival.stamina)]
	if Inventory.items.is_empty():
		_list.add_child(_text("Du trägst nichts bei dir."))
		return
	for id in Inventory.items:
		var def := DataDB.item(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var l := _text("%s  ×%d" % [def.get("name", id), Inventory.count(id)])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(_text("%s · %.1f kg" % [def.get("category", ""), Inventory.weight_of(id) * Inventory.count(id)], 16, Color(0.6, 0.58, 0.5)))
		if def.has("use"):
			var b := _button("Essen" if def["use"].has("hunger") else "Trinken")
			b.pressed.connect(_on_use.bind(id))
			row.add_child(b)
		if def.has("build"):
			var b := _button("Bauen")
			b.pressed.connect(_on_build.bind(id))
			row.add_child(b)
		var drop := _button("Ablegen")
		drop.pressed.connect(_on_drop.bind(id))
		row.add_child(drop)
		_list.add_child(row)


func _fill_crafting() -> void:
	_title.text = "Werkbank"
	_info.text = "Traglast %.1f / %.0f kg   –   Hergestellte Bauteile setzt du über das Inventar (Tab → Bauen) oder mit B." % [Inventory.total_weight(), Inventory.MAX_WEIGHT]
	for r: Dictionary in DataDB.recipes():
		var gives: Dictionary = r.get("gives", {})
		var label: String = r.get("name", "")
		if label == "":
			var parts: PackedStringArray = []
			for id in gives:
				parts.append("%d× %s" % [int(gives[id]), Inventory.display_name(id)])
			label = ", ".join(parts)
		var needs: Dictionary = r.get("needs", {})
		var need_parts: PackedStringArray = []
		for id in needs:
			need_parts.append("%s %d/%d" % [Inventory.display_name(id), Inventory.count(id), int(needs[id])])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_text(label, 22))
		var ok := Inventory.has_all(needs)
		col.add_child(_text("braucht: " + ", ".join(need_parts), 16, Color(0.55, 0.85, 0.5) if ok else Color(0.85, 0.5, 0.4)))
		row.add_child(col)
		var b := _button("Herstellen")
		b.disabled = not ok
		b.pressed.connect(_on_craft.bind(r))
		row.add_child(b)
		_list.add_child(row)


func _on_use(id: String) -> void:
	Inventory.use(id)


func _on_drop(id: String) -> void:
	Inventory.remove(id, Inventory.count(id))
	EventBus.notify("Abgelegt.", 1.5)


func _on_build(id: String) -> void:
	close()
	get_tree().call_group("build_controller", "start", id)


func _on_craft(r: Dictionary) -> void:
	var msg := Workbench.craft(r, get_tree())
	if msg == "":
		SoundBank.play_ui(self, "hammer", -6.0)
		EventBus.notify("Hergestellt.", 1.5)
	else:
		EventBus.notify(msg, 2.5)
	_refresh()


func _text(t: String, size: int = 20, color: Color = Color(0.9, 0.88, 0.82)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(130, 40)
	b.add_theme_font_size_override("font_size", 18)
	return b
