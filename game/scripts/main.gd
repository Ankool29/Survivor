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
var fauna: Fauna
var equip: Equipment
var _wear_t := 0.0
var _feet_m := 0.0
var crouch_button: Button
var _aim_line: Line2D
var _hour_t := 0.0
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
var _inside := {}               ## cases du bâtiment où l'on se trouve (toit masqué)


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
	fauna = Fauna.new()
	fauna.name = "Faune"
	add_child(fauna)
	fauna.setup(world, zone)
	fauna.bitten.connect(_on_bitten)
	_aim_line = Line2D.new()
	_aim_line.width = 1.5
	_aim_line.default_color = Color(1, 0.95, 0.7, 0.55)
	_aim_line.z_index = 15
	_aim_line.visible = false
	world.add_child(_aim_line)
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
	inv = Inventory.new(12)
	inv.changed.connect(func(): bag.refresh())
	equip = Equipment.new()
	equip.changed.connect(_apply_equipment)
	surv.equip = equip
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
	bag.equip = equip
	bag.surv = surv
	inv.clock = surv.get_minutes
	fauna.reset(s, mods, surv, player)
	player.aiming = false
	_set_crouch(false)
	death_panel.visible = false
	sleep_overlay.visible = false


## Nouvelle partie : nouvelle graine, départ au hasard sur la terre ferme, mains vides.
func new_game(s: int) -> void:
	_start(s)
	surv.start(s)
	# habits de départ
	for id in ["veste", "pantalon_travail", "chaussures_rando", "sac_courses"]:
		equip.put(id, int(int(Items.info(id).get("usure", 100)) * 0.7))
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
		"survie": surv.to_data(), "sac": inv.to_data(), "monde": mods.to_data(),
		"faune": fauna.to_data(), "equipement": equip.to_data()}
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
	fauna.from_data(data.get("faune", {}))
	if data.has("equipement"):
		equip.from_data(data["equipement"])
	else:
		# sauvegarde d'avant l'étape 4 : vêtement et sac de l'ancien système
		if surv.porte != "" and inv.remove(surv.porte):
			equip.put(surv.porte)
		if surv.sac:
			equip.put("sac")
		surv.porte = ""
		surv.sac = false
	_apply_equipment()
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
	lbl.text = "Tu es mort de %s.\n\nJours survécus : %d\nDistance parcourue : %.1f km\nMeubles fouillés : %d\nBêtes chassées : %d" % [
		cause, surv.days_survived(), surv.distance_m / 1000.0, surv.fouilles, surv.chasse]
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
	fauna.paused = paused
	fauna.update(delta)
	_update_aim()
	atmo.update(_lit_fires())
	_place_timer -= delta
	if _place_timer <= 0.0:
		_place_timer = 0.5
		_update_place()
	_update_roof()
	_action_timer -= delta
	if _action_timer <= 0.0 and not paused:
		_action_timer = 0.2
		_target = actions.find_target(player.position, player.facing)
		hud.set_action("" if surv.sleeping else _action_label())
		hud.shoot_button.visible = not surv.sleeping and inv.has("arc") and inv.has("fleche")
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
	surv.indoor = world.flags_at(cell) & WorldGen.F_ROOF != 0
	surv.near_fire = actions.near_fire(player.position).x >= 0
	surv.sheltered = actions.near_structure(player.position, "abri").x >= 0
	surv.wading = zone.is_water(cell.x, cell.y)
	# charge : au-delà de ce que le sac supporte, on ralentit
	var carried := inv.weight() + equip.worn_weight()
	surv.load_ratio = carried / equip.capacity()
	player.load_factor = clampf(1.0 - (surv.load_ratio - 1.0), 0.5, 1.0)
	var speed := SLEEP_SPEED if surv.sleeping else 1.0
	var before := surv.minutes
	surv.tick(delta, speed)
	for c in actions.burn(surv.minutes - before):
		if c.distance_to(cell) < 12:
			hud.show_message("Le feu s'est éteint.")
	fauna.update_traps(surv.minutes - before)
	_hour_t += surv.minutes - before
	if _hour_t >= 60.0:
		_hour_t = 0.0
		if inv.spoil(surv.minutes) > 0:
			hud.show_message("De la nourriture s'est gâtée.")
	var walked := player.position.distance_to(_last_pos) / Tiles.SIZE * zone.cell_m
	surv.distance_m += walked
	# usure des vêtements : un peu chaque 3 h, les chaussures en marchant
	_feet_m += walked
	_wear_t += surv.minutes - before
	var torn := []
	if _wear_t >= 180.0:
		_wear_t = 0.0
		torn.append_array(equip.wear_all(1))
	if _feet_m >= 500.0:
		_feet_m = 0.0
		var t := equip.wear("pieds", 1)
		if t != "":
			torn.append(t)
	for t in torn:
		hud.show_message("%s est fichu, tu le jettes." % t)
	_last_pos = player.position
	if surv.sleeping:
		var wake := surv.fatigue >= 99.5
		var urgent := surv.soif < 10.0 or surv.faim < 8.0 or surv.chaleur < 10.0
		if wake or urgent:
			_wake("Tu te réveilles." if wake else "Tu te réveilles en sursaut…")
		else:
			(sleep_overlay.get_node("Texte") as Label).text = "Tu dors…  %02d:%02d" % [int(surv.hour()), int(fmod(surv.hour(), 1.0) * 60)]


## Toit du bâtiment où l'on entre : masqué tant qu'on est dedans.
func _update_roof() -> void:
	var cell := player.cell()
	var indoor := world.flags_at(cell) & WorldGen.F_INDOOR != 0
	if indoor:
		if not _inside.has(cell):
			var cells := world.building_cells(cell)
			_inside = {}
			for c in cells:
				_inside[c] = true
			world.hide_roof(cells)
	elif not _inside.is_empty():
		_inside = {}
		world.show_roof()


func _lit_fires() -> Array:
	var out := []
	for k in mods.structures:
		var st: Dictionary = mods.structures[k]
		if st.get("type", "") == "feu" and float(st.get("feu", 0)) > 0.0:
			out.append(WorldMods.cell_of(k))
	return out


# --- Actions ------------------------------------------------------------------

## Arme de corps à corps : [objet, dégâts, portée en cases].
func _weapon() -> Array:
	for w in [["lance", 25.0, 2.2], ["hache", 18.0, 1.5], ["couteau", 12.0, 1.3]]:
		if inv.has(w[0]):
			return w
	return ["", 4.0, 1.0]


## Action proposée : la faune d'abord (frapper, dépecer, ramasser une flèche).
func _action_label() -> String:
	var a := fauna.animal_in_reach(player.position, player.facing, _weapon()[2])
	if a:
		return "Frapper le " + String(a.sp["nom"]).split(" ")[0]
	var c := fauna.carcass_near(player.position)
	if c:
		return "Dépecer le " + String(c.sp["nom"]).split(" ")[0]
	var pk := fauna.pickup_near(player.position)
	if not pk.is_empty():
		return "Ramasser : " + Items.name_of(pk["id"]).to_lower()
	return actions.label_for(_target, player.position)


## Fait passer du temps de jeu (dépecer, cuire, pêcher…).
func _spend(minutes: float) -> void:
	var before := surv.minutes
	surv.tick(minutes)
	actions.burn(surv.minutes - before)
	fauna.update_traps(surv.minutes - before)


func _fauna_action(label: String) -> bool:
	if label.begins_with("Frapper"):
		var w := _weapon()
		var a := fauna.animal_in_reach(player.position, player.facing, w[2])
		if a == null:
			return true
		player.facing = (a.position - player.position).normalized()
		player.play_action("frapper")
		a.hurt(float(w[1]) * randf_range(0.8, 1.2), player.position)
		if w[0] != "" and not inv.wear(w[0]):
			hud.show_message("Ton arme s'est cassée.")
		if a.is_dead():
			hud.show_message("Le %s est mort." % String(a.sp["nom"]))
		return true
	if label.begins_with("Dépecer"):
		var c := fauna.carcass_near(player.position)
		if c == null:
			return true
		if not inv.has("couteau"):
			hud.show_message("Il faut un couteau pour dépecer.")
			return true
		player.play_action("ramasser")
		_spend(float(c.sp.get("depecer", 20)))
		inv.wear("couteau")
		var got: Dictionary = c.sp["butin"].duplicate()
		var old := surv.minutes - c.dead_at > 1440.0
		if old:
			for id in ["viande", "petite_viande"]:
				if got.has(id):
					got["viande_avariee"] = int(got.get("viande_avariee", 0)) + int(got[id])
					got.erase(id)
		if c.arrows > 0:
			got["fleche"] = c.arrows
		fauna.remove_carcass(c)
		hud.show_message(actions._give(got, "La carcasse était trop vieille." if old else "")["msg"])
		return true
	if label.begins_with("Ramasser : "):
		var pk := fauna.pickup_near(player.position)
		if pk.is_empty():
			return true
		var st: Dictionary = pk.duplicate()
		st.erase("node")
		st.erase("x")
		st.erase("y")
		var left := inv.add_stack(st)
		fauna.take_pickup(pk)
		if not left.is_empty():
			fauna.drop_item(Vector2(float(pk["x"]), float(pk["y"])), left)
			hud.show_message("Sac plein.")
		player.play_action("ramasser")
		return true
	return false


func _on_bitten(dmg: float, who: String) -> void:
	if surv.dead:
		return
	if surv.sleeping:
		_wake("Tu te réveilles : un %s t'attaque !" % who)
	var prot := equip.protection()
	surv.hurt(dmg * randf_range(0.8, 1.2) * (1.0 - prot), "un " + who)
	var hit_slot: String = ["torse", "jambes", "mains", "torse"][randi() % 4]
	var torn := equip.wear(hit_slot, 3)
	if torn != "":
		hud.show_message("%s est déchiré." % torn)
	if randf() < 0.35 * (1.0 - prot * 1.5):
		surv.saigne = maxf(surv.saigne, 90.0)
		hud.show_message("Le %s te mord : tu saignes !" % who)
	else:
		hud.show_message("Le %s te mord !" % who)
	var tw := create_tween()
	player.modulate = Color(1.0, 0.45, 0.45)
	tw.tween_property(player, "modulate", Color.WHITE, 0.35)


func _set_crouch(on: bool) -> void:
	if player == null or fauna == null:
		return
	player.set_crouch(on)
	fauna.crouching = on
	hud.crouching = on
	if crouch_button:
		crouch_button.set_pressed_no_signal(on)
	if on and run_button:
		run_button.set_pressed_no_signal(false)
		player.run = false


# --- Arc : maintenir « Tirer » pour viser, relâcher pour tirer ----------------------

func _aim_dir() -> Vector2:
	var t := fauna.aim_target(player.position, player.facing)
	if t:
		# on vise un peu devant une bête qui court
		var start := player.position + Vector2(0, -12)
		var lead := start.distance_to(t.body_center()) / (Fauna.ARROW_SPEED * Tiles.SIZE)
		return (t.body_center() + t.vel * lead - start).normalized()
	return player.facing.normalized()


func _update_aim() -> void:
	if not player.aiming:
		_aim_line.visible = false
		return
	var start := player.position + Vector2(0, -12)
	var t := fauna.aim_target(player.position, player.facing)
	var end := start + _aim_dir() * Fauna.ARROW_RANGE * Tiles.SIZE
	if t:
		end = t.body_center()
	_aim_line.points = PackedVector2Array([start, end])
	_aim_line.default_color = Color(1.0, 0.5, 0.4, 0.8) if t else Color(1, 0.95, 0.7, 0.45)
	_aim_line.visible = true


func _on_shoot_down() -> void:
	if surv.dead or surv.sleeping or not (inv.has("arc") and inv.has("fleche")):
		return
	player.aiming = true


func _on_shoot_up() -> void:
	if not player.aiming:
		return
	player.aiming = false
	if not (inv.has("arc") and inv.has("fleche")):
		return
	var dir := _aim_dir()
	player.facing = dir
	inv.remove("fleche")
	fauna.shoot(player.position, dir, 30.0)
	if not inv.wear("arc"):
		hud.show_message("L'arc s'est cassé.")


func _on_action() -> void:
	if surv.dead or surv.sleeping:
		return
	var label := _action_label()
	if _fauna_action(label):
		_action_timer = 0.0
		return

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
	if r.has("carcass"):
		fauna.add_carcass(r["carcass"], (Vector2(r["at"]) + Vector2(0.5, 0.7)) * Tiles.SIZE)
	if r.has("spend"):
		_spend(float(r["spend"]))
	hud.show_message(r.get("msg", ""))
	_action_timer = 0.0


func _on_sleep_button() -> void:
	var q := 0.6
	if actions.near_structure(player.position, "abri").x >= 0:
		q = 1.0
	elif world.flags_at(player.cell()) & WorldGen.F_ROOF:
		q = 0.9
	elif world.flags_at(player.cell()) & WorldGen.F_INDOOR:
		q = 0.7
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
	_cont_inv.clock = surv.get_minutes
	_cont_inv.from_data(data)
	_cont_inv.resize(12)
	_cont_save = save
	bag.open(_cont_inv, title)


func _store_container() -> void:
	if _cont_inv != null and _cont_save.is_valid():
		_cont_save.call(_cont_inv.to_data())


## Près d'un feu allumé : faire bouillir l'eau, cuire ou réchauffer.
func _on_cook_item(index: int) -> void:
	var s: Dictionary = inv.slots[index]
	if s.is_empty() or actions.near_fire(player.position, 3).x < 0:
		hud.show_message("Il faut un feu allumé tout près.")
		return
	var id: String = s["id"]
	var c: Array = Items.COOK[id]
	inv.remove(id)
	inv.add(c[0])
	_spend(float(c[2]))
	hud.show_message("L'eau a bouilli : elle est potable." if id == "bouteille_eau" else "%s : prêt." % Items.name_of(c[0]))


func _on_smoke_item(index: int) -> void:
	var s: Dictionary = inv.slots[index]
	if s.is_empty() or actions.near_fire(player.position, 3).x < 0:
		return
	var id: String = s["id"]
	inv.remove(id)
	inv.add(Items.SMOKE[id])
	_spend(60.0)
	hud.show_message("Viande fumée : elle se gardera longtemps.")


func _on_use_item(index: int) -> void:
	var s: Dictionary = inv.slots[index]
	if s.is_empty():
		return
	var id: String = s["id"]
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
	var dropped: Dictionary = s.duplicate()
	dropped["n"] = n
	if n >= int(s["n"]):
		inv.take_slot(index)
	else:
		inv.remove(s["id"], n)
		dropped.erase("usure")
	fauna.drop_item(player.position + player.facing * 10.0, dropped)
	hud.show_message("Tu poses par terre : %s%s." % [Items.name_of(s["id"]).to_lower(), " ×%d" % n if n > 1 else ""])
	bag.refresh()


func _on_store_item(index: int, all: bool) -> void:
	var s: Dictionary = inv.slots[index]
	if s.is_empty() or _cont_inv == null:
		return
	var n := int(s["n"]) if all else 1
	var left := 0
	if s.has("usure") or s.has("exp"):
		if _cont_inv.add_stack(s).is_empty():
			inv.take_slot(index)
		else:
			left = n
	else:
		left = _cont_inv.add(s["id"], n)
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
	var left := 0
	if s.has("usure") or s.has("exp"):
		if inv.add_stack(s).is_empty():
			_cont_inv.take_slot(index)
		else:
			left = n
	else:
		left = inv.add(s["id"], n)
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
		var left := 0
		if s.has("usure") or s.has("exp"):
			if inv.add_stack(s).is_empty():
				_cont_inv.take_slot(i)
			else:
				left = n
		else:
			left = inv.add(s["id"], n)
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
	if "aiguille" in r.get("outils", []):
		var needle := "aiguille" if inv.has("aiguille") else "necessaire"
		if not inv.wear(needle):
			hud.show_message("%s est usé jusqu'au bout." % Items.name_of(needle))
	if r.has("pose"):
		hud.show_message("%s posé devant toi." % r["nom"])
		bag.hide_panel()
	else:
		var left := inv.add(r["id"], int(r.get("n", 1)))
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
			KEY_C: _set_crouch(not player.crouch)
			KEY_F: _on_shoot_down()
	elif event is InputEventKey and not event.pressed and event.physical_keycode == KEY_F:
		_on_shoot_up()


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
	hud.shoot_down.connect(_on_shoot_down)
	hud.shoot_up.connect(_on_shoot_up)
	var bar := VBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.position = Vector2(-SurvivalHud.RIGHT_MARGIN - 130, 40)
	bar.size = Vector2(130, 0)
	bar.add_theme_constant_override("separation", 6)
	ui.add_child(bar)
	bar.add_child(_button("Carte", _open_map))
	run_button = _button("Courir", func():
		player.run = run_button.button_pressed
		if player.run:
			_set_crouch(false))
	run_button.toggle_mode = true
	bar.add_child(run_button)
	crouch_button = _button("S'accroupir", func(): _set_crouch(crouch_button.button_pressed))
	crouch_button.toggle_mode = true
	bar.add_child(crouch_button)
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 6)
	zoom_row.add_child(_button(" − ", func(): set_zoom(camera.zoom.x / 1.4)))
	zoom_row.add_child(_button(" + ", func(): set_zoom(camera.zoom.x * 1.4)))
	bar.add_child(zoom_row)
	bag = BagPanel.new()
	ui.add_child(bag)
	bag.use_item.connect(_on_use_item)
	bag.cook_item.connect(_on_cook_item)
	bag.equip_item.connect(_on_equip_item)
	bag.unequip.connect(_on_unequip)
	bag.repair.connect(_on_repair)
	bag.repair_check = func(id): return _repair_material(id) != ""
	bag.smoke_item.connect(_on_smoke_item)
	bag.fire_check = func(): return actions.near_fire(player.position, 3).x >= 0
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
	map_view.mods = mods
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


# --- Équipement (étape 4) ------------------------------------------------------------

## Le sac porté fixe le nombre de cases ; le torse, l'apparence ; le carquois, les flèches.
func _apply_equipment() -> void:
	if equip == null or inv == null:
		return
	var n := equip.bag_slots()
	if inv.slots.size() < n:
		inv.resize(n)
	elif inv.slots.size() > n:
		for st in inv.shrink(n):
			fauna.drop_item(player.position + Vector2(randf_range(-12, 12), randf_range(-4, 8)), st)
			hud.show_message("Plus de place : des objets tombent par terre.")
	inv.pile_bonus = {"fleche": 60} if equip.item("ceinture") == "carquois" else {}
	player.set_outfit(equip.outfit())
	bag.refresh()


func _on_equip_item(index: int) -> void:
	var s: Dictionary = inv.slots[index]
	if s.is_empty():
		return
	var id := String(s["id"])
	inv.take_slot(index)
	var old := equip.put(id, int(s.get("usure", -1)))
	if not old.is_empty():
		var back := {"id": old["id"], "n": 1, "usure": old["usure"]}
		if not inv.add_stack(back).is_empty():
			fauna.drop_item(player.position, back)
			hud.show_message("Pas de place dans le sac : %s posé par terre." % Items.name_of(old["id"]).to_lower())
	hud.show_message("Tu mets : %s." % Items.name_of(id).to_lower())


func _on_unequip(slot: String) -> void:
	var old := equip.take(slot)
	if old.is_empty():
		return
	var back := {"id": old["id"], "n": 1, "usure": old["usure"]}
	if not inv.add_stack(back).is_empty():
		fauna.drop_item(player.position, back)
		hud.show_message("Pas de place dans le sac : %s posé par terre." % Items.name_of(old["id"]).to_lower())


## Matière disponible pour réparer cet objet ("" si rien ou pas d'aiguille).
func _repair_material(id: String) -> String:
	if not Recipes.has_tool(inv, "aiguille") or not inv.has("fil"):
		return ""
	match String(Items.info(id).get("reparer", "tissu")):
		"tissu":
			for m in ["tissu", "cuir"]:
				if inv.has(m):
					return m
		"cuir":
			for m in ["cuir", "tissu"]:
				if inv.has(m):
					return m
		"fourrure":
			for m in ["fourrure_lapin", "fourrure_renard", "cuir"]:
				if inv.has(m):
					return m
	return ""


func _on_repair(slot: String, index: int) -> void:
	var id := equip.item(slot) if slot != "" else String(inv.slots[index].get("id", ""))
	var m := _repair_material(id)
	if id == "" or m == "":
		return
	inv.remove(m)
	inv.remove("fil")
	var needle := "aiguille" if inv.has("aiguille") else "necessaire"
	inv.wear(needle)
	if slot != "":
		equip.repair(slot)
	else:
		inv.slots[index]["usure"] = int(Items.info(id).get("usure", 100))
	_spend(30.0)
	hud.show_message("%s : réparé." % Items.name_of(id))
	bag.refresh()
