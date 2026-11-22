class_name BagPanel
extends Control
## Sac : inventaire à gauche ; à droite, la fabrication ou le contenu d'un coffre.
## Toucher un objet du sac : l'utiliser (ou le ranger dans le coffre ouvert).

signal use_item(index: int)
signal craft(recipe: Dictionary)
signal take_from_chest(index: int)
signal closed

var inv: Inventory
var chest: Inventory            ## coffre ouvert (null sinon)
var _grid: GridContainer
var _right: VBoxContainer
var _title: Label
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.05, 0.93)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_top = 14
	root.offset_right = -100
	root.offset_bottom = -14
	root.add_theme_constant_override("separation", 24)
	add_child(root)
	var left := VBoxContainer.new()
	root.add_child(left)
	var l := Label.new()
	l.text = "Sac — toucher un objet pour l'utiliser"
	l.add_theme_font_size_override("font_size", 16)
	left.add_child(l)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(_grid)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.modulate = Color(1, 1, 1, 0.7)
	left.add_child(_hint)
	var close := Button.new()
	close.text = "Fermer"
	close.custom_minimum_size = Vector2(140, 48)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): hide_panel())
	left.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", 6)
	scroll.add_child(_right)
	_title = Label.new()


func open(with_chest: Inventory = null) -> void:
	chest = with_chest
	visible = true
	refresh()


func hide_panel() -> void:
	visible = false
	chest = null
	closed.emit()


func refresh() -> void:
	if not visible:
		return
	for ch in _grid.get_children():
		ch.queue_free()
	for i in inv.slots.size():
		_grid.add_child(_slot_button(inv.slots[i], func(): use_item.emit(i)))
	_hint.text = "%d cases libres" % inv.free_slots()
	for ch in _right.get_children():
		ch.queue_free()
	var t := Label.new()
	t.add_theme_font_size_override("font_size", 16)
	_right.add_child(t)
	if chest != null:
		t.text = "Coffre — toucher pour reprendre ; un objet du sac touché y est rangé"
		var g := GridContainer.new()
		g.columns = 6
		_right.add_child(g)
		for i in chest.slots.size():
			g.add_child(_slot_button(chest.slots[i], func(): take_from_chest.emit(i)))
		return
	t.text = "Fabrication"
	var list := Recipes.LIST.duplicate()
	list.sort_custom(func(a, b): return int(Recipes.can_make(a, inv)) > int(Recipes.can_make(b, inv)))
	for r in list:
		var ok := Recipes.can_make(r, inv)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s  —  %s" % [r["nom"], Recipes.describe(r)]
		b.disabled = not ok
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 15)
		if r.has("pose"):
			b.text += "  (posé devant toi)"
		else:
			b.icon = Items.icon(r["id"])
			b.expand_icon = false
		b.pressed.connect(func(): craft.emit(r))
		_right.add_child(b)


func _slot_button(s: Dictionary, action: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(64, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	if not s.is_empty():
		b.icon = Items.icon(s["id"])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var txt := str(int(s["n"])) if int(s["n"]) > 1 else ""
		if s.has("usure"):
			txt = "%d%%" % int(100.0 * float(s["usure"]) / float(Items.info(s["id"]).get("usure", 1)))
		b.text = txt
		b.tooltip_text = Items.name_of(s["id"])
		b.pressed.connect(action)
	else:
		b.disabled = true
	return b
