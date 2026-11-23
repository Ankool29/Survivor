class_name BagPanel
extends Control
## Sac : inventaire à gauche ; à droite, la fabrication ou le contenu d'un meuble,
## d'une épave ou d'un coffre. Toucher un objet le sélectionne ; la barre d'actions
## propose alors : utiliser, jeter, ranger, prendre (un seul ou toute la pile).

signal use_item(index: int)
signal cook_item(index: int)
signal smoke_item(index: int)
signal drop_item(index: int, all: bool)
signal store_item(index: int, all: bool)
signal take_item(index: int, all: bool)
signal take_all
signal craft(recipe: Dictionary)
signal equip_item(index: int)
signal unequip(slot: String)
signal repair(slot: String, index: int)
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
var fire_check: Callable    ## renvoie vrai si un feu allumé est à portée
var equip: Equipment
var surv: Survival
var repair_check: Callable  ## (id) -> vrai si on a de quoi réparer
var _tab := "craft"         ## "craft" ou "equip"
var _title: Label



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
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	left.add_child(_title)
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


func open_equipment() -> void:
	_tab = "equip"
	open()


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
	if action.is_valid():
		b.pressed.connect(action)
	return b


func refresh() -> void:
	if not visible:
		return
	# Sélection encore valable ?
	var src: Inventory = inv if _sel_side == "sac" else container
	if _sel_side == "equip":
		if equip == null or equip.slots.get(_sel_slot, {}).is_empty():
			_sel = -1
			_sel_side = ""
	elif _sel >= 0 and (src == null or _sel >= src.slots.size() or src.slots[_sel].is_empty()):
		_sel = -1
		_sel_side = ""
	for ch in _grid.get_children():
		ch.queue_free()
	for i in inv.slots.size():
		_grid.add_child(_slot_button(inv.slots[i], "sac", i))
	var carried := inv.weight() + (equip.worn_weight() if equip else 0.0)
	var cap := equip.capacity() if equip else 20.0
	_title.text = "Sac — %d / %d cases · %.1f / %.0f kg" % [inv.slots.size() - inv.free_slots(), inv.slots.size(), carried, cap]
	_hint.text = "Trop chargé : tu ralentis et te fatigues vite." if carried > cap else "Toucher un objet pour le choisir."
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
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	_right.add_child(tabs)
	_right.move_child(tabs, 0)
	for tb in [["craft", "Fabrication"], ["equip", "Équipement"]]:
		var key: String = tb[0]
		var b := _btn(tb[1], func():
			_tab = key
			if _sel_side == "equip":
				_sel = -1
				_sel_side = ""
			refresh())
		b.custom_minimum_size = Vector2(150, 42)
		b.disabled = _tab == key
		tabs.add_child(b)
	if _tab == "equip" and equip != null:
		t.queue_free()
		_build_equipment()
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


func _build_equipment() -> void:
	var imper := equip.impermeability()
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 14)
	info.text = "Chaleur +%d °C · pluie arrêtée %d %% · protection %d %% · bruit %+d %%" % [
		roundi(equip.total("chaleur")), roundi(imper * 100.0), roundi(equip.protection() * 100.0), roundi(equip.total("bruit") * 100.0)]
	if surv and surv.mouille > 0.05:
		info.text += "\nMouillé à %d %% : tes vêtements tiennent moins chaud. Sèche-toi près d'un feu." % roundi(surv.mouille * 100.0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right.add_child(info)
	for slot in Items.SLOTS:
		var st: Dictionary = equip.slots[slot]
		var b := _btn("", Callable())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.expand_icon = false
		if st.is_empty():
			b.text = "%s : rien" % Items.SLOT_NAMES[slot]
			b.modulate = Color(1, 1, 1, 0.55)
		else:
			var id := String(st["id"])
			b.icon = Items.icon(id)
			b.text = "%s : %s  (%d %%)" % [Items.SLOT_NAMES[slot], Items.name_of(id),
				roundi(100.0 * float(st["usure"]) / float(Items.info(id).get("usure", 1)))]
			var key: String = slot
			b.pressed.connect(func():
				if _sel_side == "equip" and _sel_slot == key:
					_sel = -1
					_sel_side = ""
				else:
					_sel = 0
					_sel_side = "equip"
					_sel_slot = key
				refresh())
			if _sel_side == "equip" and _sel_slot == slot:
				b.modulate = Color(1.3, 1.25, 0.8)
		_right.add_child(b)


var _sel_slot := ""


func _build_actions() -> void:
	for ch in _actions.get_children():
		ch.queue_free()
	if _sel < 0:
		_sel_label.text = ""
		return
	if _sel_side == "equip":
		var st: Dictionary = equip.slots.get(_sel_slot, {})
		if st.is_empty():
			_sel_label.text = ""
			return
		var id := String(st["id"])
		var slot := _sel_slot
		_sel_label.text = Items.name_of(id) + " (porté)"
		_actions.add_child(_btn("Enlever", func(): unequip.emit(slot)))
		if int(st["usure"]) < int(Items.info(id).get("usure", 1)):
			var rb := _btn("Réparer", func(): repair.emit(slot, -1))
			rb.disabled = not (repair_check.is_valid() and repair_check.call(id))
			_actions.add_child(rb)
		return
	var src: Inventory = inv if _sel_side == "sac" else container
	var s: Dictionary = src.slots[_sel]
	var id: String = s["id"]
	var place := String(Items.info(id).get("emplacement", ""))
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
	if place != "" and container == null and equip != null:
		_actions.add_child(_btn("Mettre", func(): equip_item.emit(i)))
		if s.has("usure") and int(s["usure"]) < int(Items.info(id).get("usure", 1)) and repair_check.is_valid() and repair_check.call(id):
			_actions.add_child(_btn("Réparer", func(): repair.emit("", i)))
	if container == null and Items.COOK.has(id):
		if fire_check.is_valid() and fire_check.call():
			_actions.add_child(_btn(Items.COOK[id][1], func(): cook_item.emit(i)))
			if Items.SMOKE.has(id):
				_actions.add_child(_btn("Fumer", func(): smoke_item.emit(i)))
		elif id == "bouteille_eau":
			_sel_label.text += "  (à faire bouillir près d'un feu allumé)"
		else:
			_sel_label.text += "  (à cuire au feu)"
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
