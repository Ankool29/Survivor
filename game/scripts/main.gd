extends Node2D
## Scène principale : monde à l'échelle réelle, joueur, survie (étape 2), interface.

const ZONE := "quimperle"
const ZONE_FILE := "user://zone.txt"
const SAVE_FILE := "user://partie.json"
const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.0
const SLEEP_SPEED := 60.0        ## en dormant : 1 s réelle = 1 h de jeu
const AUTOSAVE_S := 120.0

var zone: ZoneData
var world: ChunkManager
var player: Player
var camera: Camera2D
var joystick: TouchStick
var map_view: MapView
var place_label: Label
var debug_label: Label
var run_button: Button
var hud: SurvivalHud
var bag: BagPanel
var atmo: Atmosphere
var sleep_overlay: ColorRect
var death_panel: Control

var surv: Survival
var inv: Inventory
var mods: WorldMods
var actions: Actions
var seed_value := 0
var _target := {}
var _cont_inv: Inventory          ## contenu ouvert (coffre, meuble, épave)
var _cont_save := Callable()     ## écrit le contenu dans les changements du monde
var _place_timer := 0.0
var _action_timer := 0.0
var _save_timer := AUTOSAVE_S
var _last_pos := Vector2.ZERO
var _touches := {}
var _pinch_dist := 0.0


func _ready() -> void:
	var zone_name := ZONE
	var saved := FileAccess.get_file_as_string(ZONE_FILE).strip_edges()
	if saved != "" and saved in ZoneData.available():
		zone_name = saved
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--zone="):
			zone_name = arg.trim_prefix("--zone=")
	zone = ZoneData.load_zone(zone_name)
	_build_ui()
	if zone == null:
		place_label.text = "Données de zone absentes : lancer le workflow « Données de zone » sur GitHub."
		return
	world = ChunkManager.new()
	world.name = "Monde"
	add_child(world)
	world.setup(zone, 1)
	player = Player.new()
	player.name = "Joueur"
	player.world = world
	player.walk_speed = clampf(5.0 / zone.cell_m, 2.5, 4.0) * Tiles.SIZE
	world.entities.add_child(player)
	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = zone.width * Tiles.SIZE
	camera.limit_bottom = zone.height * Tiles.SIZE
	player.add_child(camera)
	camera.make_current()
	map_view.zone = zone
	atmo = Atmosphere.new()
	add_child(atmo)
	atmo.setup(world, $Ciel, player)
	if not load_game():
		new_game(randi())


# --- Partie -------------------------------------------------------------------

func _start(s: int) -> void:
	seed_value = s
	mods = WorldMods.new()
	world.mods = mods
	world.reset(s)
	surv = Survival.new()
	surv.message.connect(hud.show_message)
	surv.died.connect(_on_died)
	inv = Inventory.new(16)
	inv.changed.connect(func(): bag.refresh())
	actions = Actions.new()
	actions.world = world
	actions.zone = zone
	actions.surv = surv
	actions.inv = inv
	actions.mods = mods
	actions.seed_value = s
	hud.surv = surv
	atmo.surv = surv
	bag.inv = inv
	death_panel.visible = false
	sleep_overlay.visible = false


## Nouvelle partie : nouvelle graine, départ au hasard sur la terre ferme, mains vides.
func new_game(s: int) -> void:
	_start(s)
	surv.start(s)
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	for attempt in 600:
		var cell := Vector2i(rng.randi_range(40, zone.width - 41), rng.randi_range(40, zone.height - 41))
		if zone.tiled and zone.e_at(cell.x, cell.y) <= 0.5:
			continue
		var t := zone.t_at(cell.x, cell.y)
		if t == ZoneData.T_MER or t == ZoneData.T_EAU or zone.b_at(cell.x, cell.y) != 0:
			continue
		world.ensure_cell(cell)
		if world.flags_at(cell) & (WorldGen.F_BLOCK | WorldGen.F_TRUNK):
			continue
		player.position = Vector2(cell.x + 0.5, cell.y + 0.7) * Tiles.SIZE
		break
	camera.reset_smoothing()
	_last_pos = player.position
	_update_place()
	hud.show_message("Jour 1. Trouve de l'eau, de quoi manger et un abri avant la nuit.")
	save_game()


func save_game() -> void:
	if surv == null or surv.dead:
		return
	var data := {"version": 1, "zone": zone.name, "seed": seed_value,
		"x": player.position.x, "y": player.position.y,
		"survie": surv.to_data(), "sac": inv.to_data(), "monde": mods.to_data()}
	var f := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	if not data is Dictionary or data.get("zone", "") != zone.name:
		return false
	_start(int(data["seed"]))
	surv.from_data(data.get("survie", {}))
	mods.from_data(data.get("monde", {}), surv.minutes)
	inv.from_data(data.get("sac", []))
	inv.resize(24 if surv.sac else 16)
	player.position = Vector2(float(data["x"]), float(data["y"]))
	world.ensure_cell(player.cell())
	camera.reset_smoothing()
	_last_pos = player.position
	hud.show_message("Partie reprise : jour %d." % (surv.days_survived() + 1))
	return true


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST]:
		if world != null:
			save_game()


func _on_died(cause: String) -> void:
	sleep_overlay.visible = false
	bag.hide_panel()
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(SAVE_FILE)
	var lbl: Label = death_panel.get_node("Texte")
	lbl.text = "Tu es mort de %s.\n\nJours survécus : %d\nDistance parcourue : %.1f km\nMeubles fouillés : %d" % [
		cause, surv.days_survived(), surv.distance_m / 1000.0, surv.fouilles]
	death_panel.visible = true


# --- Boucle -------------------------------------------------------------------

func _process(delta: float) -> void:
	if world == null:
		return
	var paused := bag.visible or map_view.visible or surv.dead
	joystick.set_process_input(not paused and not surv.sleeping)
	player.input_vector = Vector2.ZERO if (paused or surv.sleeping) else joystick.vector
	player.set_process(not surv.sleeping and not paused)
	if not camera.is_current():
		camera.make_current()
	var screen := get_viewport_rect().size
	if screen.x < 64 or screen.y < 64:
		screen = Vector2(1280, 576)
	var vp := screen / camera.zoom
	world.update_view(Rect2(player.position - vp * 0.5, vp))
	if not paused:
		_tick_survival(delta)
	atmo.update(_lit_fires())
	_place_timer -= delta
	if _place_timer <= 0.0:
		_place_timer = 0.5
		_update_place()
	_action_timer -= delta
	if _action_timer <= 0.0 and not paused:
		_action_timer = 0.2
		_target = actions.find_target(player.position, player.facing)
		hud.set_action("" if surv.sleeping else actions.label_for(_target, player.position))
	_save_timer -= delta
	if _save_timer <= 0.0:
		_save_timer = AUTOSAVE_S
		save_game()
	map_view.player_cell = player.position / Tiles.SIZE
	debug_label.text = "%d img/s · morceaux %d · fabrication %.1f ms · pose %.1f ms · case %d, %d · alt. %d m" % [
		Engine.get_frames_per_second(), world.loaded_count(), world.last_gen_ms, world.last_apply_ms,
		player.cell().x, player.cell().y, int(zone.e_at(player.cell().x, player.cell().y))]


func _tick_survival(delta: float) -> void:
	var cell := player.cell()
	surv.running = player.moving and player._running_now
	surv.indoor = world.flags_at(cell) & WorldGen.F_INDOOR != 0
	surv.near_fire = actions.near_fire(player.position).x >= 0
	surv.sheltered = actions.near_structure(player.position, "abri").x >= 0
	var speed := SLEEP_SPEED if surv.sleeping else 1.0
	var before := surv.minutes
	surv.tick(delta, speed)
	for c in actions.burn(surv.minutes - before):
		if c.distance_to(cell) < 12:
			hud.show_message("Le feu s'est éteint.")
	surv.distance_m += player.position.distance_to(_last_pos) / Tiles.SIZE * zone.cell_m
	_last_pos = player.position
	if surv.sleeping:
		var wake := surv.fatigue >= 99.5
		var urgent := surv.soif < 10.0 or surv.faim < 8.0 or surv.chaleur < 10.0
		if wake or urgent:
			_wake("Tu te réveilles." if wake else "Tu te réveilles en sursaut…")
		else:
			(sleep_overlay.get_node("Texte") as Label).text = "Tu dors…  %02d:%02d" % [int(surv.hour()), int(fmod(surv.hour(), 1.0) * 60)]


func _lit_fires() -> Array:
	var out := []
	for k in mods.structures:
		var st: Dictionary = mods.structures[k]
		if st.get("type", "") == "feu" and float(st.get("feu", 0)) > 0.0:
			out.append(WorldMods.cell_of(k))
	return out


# --- Actions ------------------------------------------------------------------

func _on_action() -> void:
	if surv.dead or surv.sleeping:
		return
	var label := actions.label_for(_target, player.position)
	var r := actions.run(_target, player.position)
	if label.begins_with("Couper") or label == "Fouiller les débris":
		player.play_action("frapper")
	elif label == "Boire" or label.begins_with("Remplir"):
		player.play_action("boire")
	elif not r.has("chest") and not r.has("sleep") and label != "Ouvrir" and label != "":
		player.play_action("ramasser")
	if r.has("sleep"):
		_sleep(1.0)
		return
	if r.has("chest"):
		_open_chest(r["chest"])
		return
	if r.has("container"):
		_open_furniture(r["container"], r["title"])
		return
	hud.show_message(r.get("msg", ""))
	_action_timer = 0.0


func _on_sleep_button() -> void:
	var q := 0.6
	if actions.near_structure(player.position, "abri").x >= 0:
		q = 1.0
	elif world.flags_at(player.cell()) & WorldGen.F_INDOOR:
		q = 0.9
	_sleep(q)


func _sleep(quality: float) -> void:
	if surv.fatigue > 85.0:
		hud.show_message("Tu n'as pas sommeil.")
		return
	surv.sleeping = true
	surv.sleep_quality = quality
	sleep_overlay.visible = true
	player.set_sleeping(true)
	hud.set_action("")


func _wake(text: String) -> void:
	surv.sleeping = false
	sleep_overlay.visible = false
	player.set_sleeping(false)
	hud.show_message(text)
	save_game()


func _open_chest(cell: Vector2i) -> void:
	var k := WorldMods.key(cell)
	_open_container(mods.structures[k].get("objets", []), "Coffre",
		func(data): mods.structures[k]["objets"] = data)


func _open_furniture(cell: Vector2i, title: String) -> void:
	_open_container(mods.content_of(cell), title, func(data): mods.mark_searched(cell, data))


func _open_container(data: Array, title: String, save: Callable) -> void:
	_cont_inv = Inventory.new(12)
	_cont_inv.from_data(data)
	_cont_inv.resize(12)
	_cont_save = save
	bag.open(_cont_inv, title)


func _store_container() -> void:
	if _cont_inv != null and _cont_save.is_valid():
		_cont_save.call(_cont_inv.to_data())


func _on_use_item(index: int) -> void:
	var s: Dictionary = inv.slots[index]
	if s.is_empty():
		return
	var id: String = s["id"]
	# Près d'un feu : cuisson
	if actions.near_fire(player.position, 2).x >= 0 and id in ["bouteille_eau", "champignon", "conserve"]:
		inv.remove(id)
		inv.add("bouteille_bouillie" if id == "bouteille_eau" else "repas")
		hud.show_message("Eau bouillie." if id == "bouteille_eau" else "Repas cuit.")
		return
	var it := Items.info(id)
	match String(it.get("utiliser", "")):
		"Manger", "Manger cru", "Boire", "Se soigner", "Prendre":
			if it.get("utiliser") == "Boire":
				player.play_action("boire")
			inv.remove(id)
			if it.has("rend"):
				inv.add(it["rend"])
			var m := surv.consume(id)
			hud.show_message(m if m != "" else "%s : fait." % Items.name_of(id))
		"Porter":
			surv.porte = "" if surv.porte == id else id
			hud.show_message(("Tu portes : " + Items.name_of(id)) if surv.porte == id else "Tu enlèves ton vêtement.")
		"Équiper":
			if not surv.sac:
				inv.remove(id)
				surv.sac = true
				inv.resize(24)
				hud.show_message("Sac à dos équipé : 8 cases de plus.")
		"Allumer":
			inv.remove(id)
			surv.torche += 60.0
			hud.show_message("Torche allumée (1 h).")
		_:
			hud.show_message("%s : rien à en faire pour l'instant." % Items.name_of(id))
	bag.refresh()


func _on_drop_item(index: int, all: bool) -> void:
	var s: Dictionary = inv.slots[index]
	if s.is_empty():
		return
	var n := int(s["n"]) if all else 1
	if surv.porte == s["id"] and inv.count(s["id"]) <= n:
		surv.porte = ""
	inv.remove(s["id"], n)
	hud.show_message("Tu jettes : %s%s." % [Items.name_of(s["id"]).to_lower(), " ×%d" % n if n > 1 else ""])
	bag.refresh()


func _on_store_item(index: int, all: bool) -> void:
	var s: Dictionary = inv.slots[index]
	if s.is_empty() or _cont_inv == null:
		return
	var n := int(s["n"]) if all else 1
	var left := _cont_inv.add(s["id"], n)
	inv.remove(s["id"], n - left)
	if left > 0:
		hud.show_message("Plus de place.")
	_store_container()
	bag.refresh()


func _on_take_item(index: int, all: bool) -> void:
	if _cont_inv == null:
		return
	var s: Dictionary = _cont_inv.slots[index]
	if s.is_empty():
		return
	var n := int(s["n"]) if all else 1
	var left := inv.add(s["id"], n)
	_cont_inv.remove(s["id"], n - left)
	if left > 0:
		hud.show_message("Sac plein.")
	_store_container()
	bag.refresh()


func _on_take_all() -> void:
	if _cont_inv == null:
		return
	var full := false
	for i in _cont_inv.slots.size():
		var s: Dictionary = _cont_inv.slots[i]
		if s.is_empty():
			continue
		var n := int(s["n"])
		var left := inv.add(s["id"], n)
		_cont_inv.remove(s["id"], n - left)
		full = full or left > 0
	if full:
		hud.show_message("Sac plein.")
	_store_container()
	bag.refresh()


func _on_craft(r: Dictionary) -> void:
	if not Recipes.can_make(r, inv):
		return
	if r.has("pose"):
		if not actions.place(r["pose"], player.position, player.facing):
			hud.show_message("Pas de place devant toi.")
			return
	for id in r["ing"]:
		inv.remove(id, int(r["ing"][id]))
	if r.has("pose"):
		hud.show_message("%s posé devant toi." % r["nom"])
		bag.hide_panel()
	else:
		var left := inv.add(r["id"])
		hud.show_message(("Fabriqué : " + r["nom"]) if left == 0 else "Sac plein.")
	bag.refresh()


func _update_place() -> void:
	var c := player.cell()
	var b := world.building_at(c)
	if not b.is_empty() and b["kind"] != "maison" and b["kind"] != "entrepot":
		var label: String = String(b["kind"]).replace("_", " ").capitalize()
		if b["name"] != "":
			label += " — " + b["name"]
		place_label.text = label
		return
	var p := zone.nearest_place(c.x, c.y)
	if p.is_empty():
		place_label.text = zone.title
	elif p["dist"] < 20.0 * 31.25 / zone.cell_m:
		place_label.text = p["name"]
	else:
		place_label.text = "Près de " + p["name"]


# --- Zoom par pincement (deux doigts hors du joystick) --------------------------

func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not joystick.is_touch(event.index):
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_dist = 0.0
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _touches.size() == 2:
			var pts: Array = _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_dist > 0.0:
				set_zoom(camera.zoom.x * d / _pinch_dist)
			_pinch_dist = d
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(camera.zoom.x * 1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(camera.zoom.x / 1.15)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E, KEY_SPACE: _on_action()
			KEY_I, KEY_TAB: _toggle_bag()


func set_zoom(z: float) -> void:
	z = clampf(z, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(z, z)


# --- Interface ----------------------------------------------------------------

func _build_ui() -> void:
	var sky := CanvasLayer.new()
	sky.name = "Ciel"
	sky.layer = 1
	add_child(sky)
	var ui := CanvasLayer.new()
	ui.name = "Interface"
	ui.layer = 2
	add_child(ui)
	joystick = TouchStick.new()
	ui.add_child(joystick)
	place_label = Label.new()
	place_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place_label.position = Vector2(-300, 8)
	place_label.size = Vector2(600, 30)
	place_label.add_theme_font_size_override("font_size", 22)
	place_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	place_label.add_theme_constant_override("outline_size", 6)
	ui.add_child(place_label)
	debug_label = Label.new()
	debug_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	debug_label.position = Vector2(10, -20)
	debug_label.add_theme_font_size_override("font_size", 11)
	debug_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	debug_label.add_theme_constant_override("outline_size", 4)
	debug_label.modulate = Color(1, 1, 1, 0.6)
	ui.add_child(debug_label)
	hud = SurvivalHud.new()
	ui.add_child(hud)
	hud.action_pressed.connect(_on_action)
	hud.bag_pressed.connect(_toggle_bag)
	hud.sleep_pressed.connect(_on_sleep_button)
	var bar := VBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.position = Vector2(-SurvivalHud.RIGHT_MARGIN - 130, 40)
	bar.size = Vector2(130, 0)
	bar.add_theme_constant_override("separation", 6)
	ui.add_child(bar)
	bar.add_child(_button("Carte", _open_map))
	run_button = _button("Courir", func(): player.run = run_button.button_pressed)
	run_button.toggle_mode = true
	bar.add_child(run_button)
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 6)
	zoom_row.add_child(_button(" − ", func(): set_zoom(camera.zoom.x / 1.4)))
	zoom_row.add_child(_button(" + ", func(): set_zoom(camera.zoom.x * 1.4)))
	bar.add_child(zoom_row)
	bag = BagPanel.new()
	ui.add_child(bag)
	bag.use_item.connect(_on_use_item)
	bag.drop_item.connect(_on_drop_item)
	bag.store_item.connect(_on_store_item)
	bag.take_item.connect(_on_take_item)
	bag.take_all.connect(_on_take_all)
	bag.craft.connect(_on_craft)
	bag.closed.connect(func():
		_store_container()
		_cont_inv = null
		_cont_save = Callable())
	map_view = MapView.new()
	ui.add_child(map_view)
	sleep_overlay = _overlay("Tu dors…", "Se réveiller", func(): _wake("Tu te lèves."))
	sleep_overlay.color = Color(0, 0, 0.05, 0.5)
	ui.add_child(sleep_overlay)
	death_panel = _overlay("", "Nouvelle partie", func(): new_game(randi()))
	ui.add_child(death_panel)


func _overlay(text: String, button_text: String, action: Callable) -> ColorRect:
	var o := ColorRect.new()
	o.color = Color(0, 0, 0, 0.82)
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.visible = false
	var l := Label.new()
	l.name = "Texte"
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 20)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.offset_left = -280
	l.offset_right = 280
	l.offset_top = -230
	l.offset_bottom = -70
	o.add_child(l)
	var b := _button(button_text, action)
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	b.offset_left = -120
	b.offset_right = 120
	b.offset_top = 40
	b.offset_bottom = 96
	o.add_child(b)
	return o


func _toggle_bag() -> void:
	if bag.visible:
		bag.hide_panel()
	elif not surv.dead and not surv.sleeping:
		bag.open()


func _open_map() -> void:
	map_view.player_cell = player.position / Tiles.SIZE
	map_view.open()


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(60, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 17)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b
