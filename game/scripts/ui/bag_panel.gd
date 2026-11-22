class_name BagPanel
extends Control
## Sac : inventaire à gauche ; à droite, la fabrication ou le contenu d'un meuble,
## d'une épave ou d'un coffre. Toucher un objet le sélectionne ; la barre d'actions
## propose alors : utiliser, jeter, ranger, prendre (un seul ou toute la pile).

signal use_item(index: int)
signal drop_item(index: int, all: bool)
signal store_item(index: int, all: bool)
signal take_item(index: int, all: bool)
signal take_all
signal craft(recipe: Dictionary)
signal closed

var inv: Inventory
var container: Inventory        ## contenu ouvert (null sinon)
var container_title := ""
var _sel_side := ""             ## "sac" ou "cont"
var _sel := -1
var _grid: GridContainer
var _right: VBoxContainer
var _actions: HBoxContainer
var _sel_label: Label
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.05, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_top = 12
	root.offset_right = -100
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 24)
	add_child(root)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	var l := Label.new()
	l.text = "Sac — toucher un objet pour le choisir"
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
	_sel_label = Label.new()
	_sel_label.add_theme_font_size_override("font_size", 15)
	left.add_child(_sel_label)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 6)
	left.add_child(_actions)
	var close := _btn("Fermer", func(): hide_panel())
	close.custom_minimum_size = Vector2(140, 46)
	left.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", 6)
	scroll.add_child(_right)


func open(with_container: Inventory = null, title := "") -> void:
	container = with_container
	container_title = title
	_sel = -1
	_sel_side = ""
	visible = true
	refresh()


func hide_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
	container = null


func _btn(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(action)
	return b


func refresh() -> void:
	if not visible:
		return
	# Sélection encore valable ?
	var src: Inventory = inv if _sel_side == "sac" else container
	if _sel >= 0 and (src == null or _sel >= src.slots.size() or src.slots[_sel].is_empty()):
		_sel = -1
		_sel_side = ""
	for ch in _grid.get_children():
		ch.queue_free()
	for i in inv.slots.size():
		_grid.add_child(_slot_button(inv.slots[i], "sac", i))
	_hint.text = "%d cases libres" % inv.free_slots()
	_build_actions()
	for ch in _right.get_children():
		ch.queue_free()
	var t := Label.new()
	t.add_theme_font_size_override("font_size", 16)
	_right.add_child(t)
	if container != null:
		t.text = container_title + " — toucher un objet pour le choisir"
		var g := GridContainer.new()
		g.columns = 6
		g.add_theme_constant_override("h_separation", 6)
		g.add_theme_constant_override("v_separation", 6)
		_right.add_child(g)
		for i in container.slots.size():
			g.add_child(_slot_button(container.slots[i], "cont", i))
		var all := _btn("Tout prendre", func(): take_all.emit())
		all.disabled = container.free_slots() == container.slots.size()
		_right.add_child(all)
		return
	t.text = "Fabrication"
	var list := Recipes.LIST.duplicate()
	list.sort_custom(func(a, b): return int(Recipes.can_make(a, inv)) > int(Recipes.can_make(b, inv)))
	for r in list:
		var b := _btn("%s  —  %s" % [r["nom"], Recipes.describe(r)], func(): craft.emit(r))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not Recipes.can_make(r, inv)
		if r.has("pose"):
			b.text += "  (posé devant toi)"
		else:
			b.icon = Items.icon(r["id"])
		_right.add_child(b)


func _build_actions() -> void:
	for ch in _actions.get_children():
		ch.queue_free()
	if _sel < 0:
		_sel_label.text = ""
		return
	var src: Inventory = inv if _sel_side == "sac" else container
	var s: Dictionary = src.slots[_sel]
	var id: String = s["id"]
	var n := int(s["n"])
	_sel_label.text = Items.name_of(id) + ("  ×%d" % n if n > 1 else "")
	var i := _sel
	if _sel_side == "cont":
		_actions.add_child(_btn("Prendre", func(): take_item.emit(i, false)))
		if n > 1:
			_actions.add_child(_btn("Prendre tout", func(): take_item.emit(i, true)))
		return
	var use := String(Items.info(id).get("utiliser", ""))
	if use != "" and container == null:
		_actions.add_child(_btn(use, func(): use_item.emit(i)))
	if container != null:
		_actions.add_child(_btn("Ranger", func(): store_item.emit(i, false)))
		if n > 1:
			_actions.add_child(_btn("Ranger tout", func(): store_item.emit(i, true)))
	_actions.add_child(_btn("Jeter", func(): drop_item.emit(i, false)))
	if n > 1:
		_actions.add_child(_btn("Jeter tout", func(): drop_item.emit(i, true)))


func _slot_button(s: Dictionary, side: String, i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(62, 62)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	if s.is_empty():
		b.disabled = true
		return b
	b.icon = Items.icon(s["id"])
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var txt := str(int(s["n"])) if int(s["n"]) > 1 else ""
	if s.has("usure"):
		txt = "%d%%" % int(100.0 * float(s["usure"]) / float(Items.info(s["id"]).get("usure", 1)))
	b.text = txt
	if side == _sel_side and i == _sel:
		b.modulate = Color(1.3, 1.25, 0.8)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.35, 0.3, 0.12)
		sb.border_color = Color(0.95, 0.8, 0.3)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
	b.pressed.connect(func():
		if _sel_side == side and _sel == i:
			_sel = -1
			_sel_side = ""
		else:
			_sel = i
			_sel_side = side
		refresh())
	return b
