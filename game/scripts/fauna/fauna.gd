class_name Fauna
extends Node2D
## Faune autour du joueur (étape 3).
##
## Le monde est découpé en régions de 64 × 64 cases. Chaque région a une densité
## de groupes par espèce, tirée de son terrain ; quand le joueur s'en approche, ses
## groupes apparaissent hors de vue et vivent vraiment ; quand il s'éloigne, ils
## disparaissent. Les bêtes tuées baissent les effectifs de la région, qui se
## reconstituent en quelques jours. Gère aussi les carcasses, les flèches au sol,
## le sang, les collets et les nasses.

signal bitten(damage: float, who: String)

const REGION := 64
const ACTIVE_R := 75.0          ## cases : régions activées dans ce rayon
const DESPAWN_R := 100.0        ## cases : au-delà, les bêtes vivantes disparaissent
const SPAWN_MIN := 26.0         ## cases : jamais d'apparition plus près (hors de l'écran)
const RESPAWN_MIN := 180.0      ## minutes de jeu avant qu'une région se repeuple
const REGEN_PER_DAY := 0.25
const CARCASS_ROT := 2880.0     ## une carcasse pourrit en 2 jours de jeu
const ARROW_SPEED := 26.0       ## cases par seconde
const ARROW_RANGE := 15.0

var world: ChunkManager
var zone: ZoneData
var surv: Survival
var player: Player
var mods: WorldMods
var seed_value := 0
var crouching := false
var paused := false

var animals: Array[Animal] = []
var stock := {}                 ## "rx,ry,espèce" -> 0..1 (effectifs restants)
var carcasses: Array = []       ## carcasses hors de portée : {x, y, sp, t, fleches}
var pickups: Array = []         ## objets au sol : {x, y, id, n, usure?, node}

var _habitat := {}              ## région -> {terrain: part}
var _spawned := {}              ## région -> minute de la dernière apparition
var _region_t := 0.0
var _group_id := 0
var _frames := {}
var _meta := {}
var _blood: Array = []          ## [pos, âge]
var _blood_layer: Node2D
var _arrows: Array = []         ## flèches en vol : {pos, dir, left, node}
var _trap_t := 0.0


func setup(w: ChunkManager, z: ZoneData) -> void:
	world = w
	zone = z
	_blood_layer = Node2D.new()
	_blood_layer.name = "Sang"
	_blood_layer.draw.connect(_draw_blood)
	world.add_child(_blood_layer)
	world.move_child(_blood_layer, world.entities.get_index())


func reset(s: int, m: WorldMods, sv: Survival, p: Player) -> void:
	for a in animals:
		a.queue_free()
	animals.clear()
	for pk in pickups:
		if is_instance_valid(pk.get("node")):
			pk["node"].queue_free()
	for ar in _arrows:
		ar["node"].queue_free()
	_arrows.clear()
	pickups.clear()
	carcasses.clear()
	stock.clear()
	_spawned.clear()
	_blood.clear()
	seed_value = s
	mods = m
	surv = sv
	player = p


# --- Accès pour les animaux ----------------------------------------------------

func now() -> float:
	return surv.minutes


func player_pos() -> Vector2:
	return player.position


func daylight() -> float:
	return surv.daylight()


func season() -> int:
	return surv.season()


func torch_on() -> bool:
	return surv.torche > 0.0


func frames_for(id: String) -> SpriteFrames:
	if _frames.has(id):
		return _frames[id]
	var png := "res://assets/characters/%s.png" % id
	var js := "res://assets/characters/%s.json" % id
	if not ResourceLoader.exists(png) or not FileAccess.file_exists(js):
		_frames[id] = null
		return null
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(js))
	var tex: Texture2D = load(png)
	var fw := int(meta["frame_w"])
	var fh := int(meta["frame_h"])
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var fps := {"repos": 3.0, "marche": 8.0, "course": 13.0, "attaque": 12.0}
	for a in meta["anims"]:
		var name := "%s_%s" % [a["name"], a["dir"]]
		frames.add_animation(name)
		frames.set_animation_speed(name, fps.get(a["name"], 8.0))
		frames.set_animation_loop(name, a["name"] != "attaque")
		for i in int(a["frames"]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, int(a["row"]) * fh, fw, fh)
			frames.add_frame(name, at)
	_frames[id] = frames
	_meta[id] = meta
	return frames


func meta_for(id: String) -> Dictionary:
	return _meta.get(id, {"frame_w": 32, "feet_y": 28})


## Case praticable pour cet animal (les morceaux non chargés : d'après la carte).
func walkable(p: Vector2, a: Animal) -> bool:
	var c := Vector2i(floori(p.x / Tiles.SIZE), floori(p.y / Tiles.SIZE))
	if not zone.inside(c.x, c.y) or zone.is_water(c.x, c.y):
		return false
	if not world.is_loaded(c):
		return zone.b_at(c.x, c.y) == 0
	if world.interiors and world.move_blocked(a.position, p):
		return false
	var f := world.flags_at(c)
	if f & WorldGen.F_BLOCK:
		return false
	if f & WorldGen.F_INDOOR and not (a.sp_id in ["chien", "renard"]):
		return false
	return true


## Distance (en cases) à laquelle l'animal repère le joueur.
func detect_range(a: Animal) -> float:
	var r := float(a.sp["sens"])
	if surv.sleeping:
		r *= 0.6
	elif crouching:
		r *= 0.5
	elif player.moving and player._running_now:
		r *= 1.6
	elif not player.moving:
		r *= 0.8
	if daylight() < 0.3:
		r *= 0.75
	if surv.equip:
		r *= maxf(0.6, 1.0 + surv.equip.total("bruit"))   # ciré, doudoune bruyants ; mocassins discrets
	var cell := player.cell()
	var g := world.ground_at(cell)
	if world.flags_at(cell) & WorldGen.F_SLOW or g in [Tiles.G_HERBE_HAUTE, Tiles.G_LANDE, Tiles.G_SOL_FEUILLUS, Tiles.G_SOL_RESINEUX, Tiles.G_MARAIS]:
		r *= 0.8
	var to_p := (player.position - a.position).normalized()
	if a.facing.dot(to_p) < -0.2:
		r *= 0.65                      # le joueur est dans son dos
	var downwind := surv.wind().dot(-to_p)    # le vent porte l'odeur du joueur vers l'animal
	if downwind > 0.5:
		r *= 1.5
	elif downwind < -0.5:
		r *= 0.85
	return r


## Un feu allumé à moins de r cases : sa position, sinon Vector2.INF.
func fire_near(p: Vector2, r: float) -> Vector2:
	var c0 := Vector2i(floori(p.x / Tiles.SIZE), floori(p.y / Tiles.SIZE))
	for k in mods.structures:
		var st: Dictionary = mods.structures[k]
		if st.get("type", "") == "feu" and float(st.get("feu", 0)) > 0.0:
			var c := WorldMods.cell_of(k)
			if Vector2(c - c0).length() < r:
				return (Vector2(c) + Vector2(0.5, 0.5)) * Tiles.SIZE
	return Vector2.INF


## Une meute passe à l'attaque ?
func should_attack(a: Animal, dist: float) -> bool:
	if dist > 18.0:
		return false
	if fire_near(player.position, 5.0) != Vector2.INF:
		return false
	var pack := 0
	for o in animals:
		if o.group == a.group and not o.is_dead():
			pack += 1
	var night := daylight() < 0.3
	if torch_on() and night and pack < 4:
		return false
	var fleeing := player.moving and player._running_now and player.facing.dot((player.position - a.position).normalized()) > 0.5
	var weak := surv.sante < 50.0 or surv.sleeping
	# chances par décision (quatre par seconde)
	var chance := 0.0
	# bêtes farouches : elles suivent de loin et n'attaquent qu'un joueur affaibli,
	# qui fuit, ou la nuit en plein hiver (meute affamée)
	var winter := season() == 3
	if a.sp_id == "loup":
		chance = 0.0005 + (0.006 if night else 0.0) + (0.012 if winter and night else 0.0)
		if pack >= 4:
			chance += 0.003
	else:
		chance = 0.0003 + (0.004 if night else 0.0) + (0.006 if winter else 0.0) + (0.002 if pack >= 5 else 0.0)
	if fleeing:
		chance += 0.05
	if weak:
		chance += 0.03
	return randf() < chance


func alert_group(a: Animal, state: String) -> void:
	for o in animals:
		if o.group == a.group and o != a and not o.is_dead():
			o.alerted = true
			if state != "" and o.state != "fuite":
				o.state = state


## Deux bêtes au plus mordent en même temps ; les autres tournent autour.
var _biters := {}

func can_bite(a: Animal) -> bool:
	var t := Time.get_ticks_msec()
	for k in _biters.keys():
		if t - int(_biters[k]) > 1500:
			_biters.erase(k)
	if _biters.has(a.get_instance_id()) or _biters.size() < 2:
		_biters[a.get_instance_id()] = t
		return true
	return false


func bite_player(a: Animal) -> void:
	bitten.emit(float(a.sp.get("degats", 5.0)), String(a.sp["nom"]))


## Où aller en flânant : un peu plus loin, vers une carcasse pour les charognards.
func wander_goal(a: Animal) -> Vector2:
	if a.sp_id in ["chien", "renard", "loup"]:
		for o in animals:
			if o.is_dead() and o.position.distance_to(a.position) < 25.0 * Tiles.SIZE:
				return o.position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	return a.position + Vector2.from_angle(randf() * TAU) * randf_range(2.0, 7.0) * Tiles.SIZE


func on_death(a: Animal) -> void:
	var k := "%d,%d,%s" % [a.region.x, a.region.y, a.sp_id]
	stock[k] = [maxf(0.0, _stock_of(k) - 0.5), now()]
	surv.chasse += 1


func add_blood(p: Vector2) -> void:
	_blood.append([p + Vector2(randf_range(-4, 4), randf_range(-3, 3)), now()])
	if _blood.size() > 400:
		_blood.pop_front()
	_blood_layer.queue_redraw()


# --- Mise à jour ----------------------------------------------------------------

func update(delta: float) -> void:
	if paused or surv.dead:
		return
	_update_arrows(delta)
	_region_t -= delta
	if _region_t <= 0.0:
		_region_t = 1.0
		_update_regions()
		# le sang sèche en une demi-journée
		var t := now()
		var n := _blood.size()
		_blood = _blood.filter(func(b): return t - b[1] < 720.0)
		if _blood.size() != n:
			_blood_layer.queue_redraw()


func _update_regions() -> void:
	var pc := player.position / Tiles.SIZE
	# disparitions
	for a: Animal in animals.duplicate():
		var d := a.position.distance_to(player.position) / Tiles.SIZE
		if a.is_dead():
			if d > DESPAWN_R or now() - a.dead_at > CARCASS_ROT:
				if now() - a.dead_at <= CARCASS_ROT:
					carcasses.append({"x": a.position.x, "y": a.position.y, "sp": a.sp_id, "t": a.dead_at, "fleches": a.arrows})
				animals.erase(a)
				a.queue_free()
		elif d > DESPAWN_R and a.bleeding <= 0.0:
			animals.erase(a)
			a.queue_free()
	# carcasses qui reviennent à portée
	for c in carcasses.duplicate():
		if now() - float(c["t"]) > CARCASS_ROT:
			carcasses.erase(c)
		elif Vector2(float(c["x"]), float(c["y"])).distance_to(player.position) / Tiles.SIZE < DESPAWN_R * 0.8:
			carcasses.erase(c)
			var a := _new_animal(c["sp"], Vector2(float(c["x"]), float(c["y"])), Vector2i.ZERO, 0)
			a.arrows = int(c.get("fleches", 0))
			a.die(true)
			a.dead_at = float(c["t"])
	# apparitions dans les régions proches
	var r0 := Vector2i(floori((pc.x - ACTIVE_R) / REGION), floori((pc.y - ACTIVE_R) / REGION))
	var r1 := Vector2i(floori((pc.x + ACTIVE_R) / REGION), floori((pc.y + ACTIVE_R) / REGION))
	for ry in range(r0.y, r1.y + 1):
		for rx in range(r0.x, r1.x + 1):
			var rg := Vector2i(rx, ry)
			var center := (Vector2(rg) + Vector2(0.5, 0.5)) * REGION
			if center.distance_to(pc) > ACTIVE_R + REGION * 0.5:
				continue
			if now() - float(_spawned.get(rg, -1e9)) < RESPAWN_MIN:
				continue
			_spawned[rg] = now()
			_populate(rg)


func _region_habitat(rg: Vector2i) -> Dictionary:
	if _habitat.has(rg):
		return _habitat[rg]
	var h := {}
	for sy in 8:
		for sx in 8:
			var x := rg.x * REGION + sx * 8 + 4
			var y := rg.y * REGION + sy * 8 + 4
			if not zone.inside(x, y):
				continue
			var t := zone.t_at(x, y)
			if zone.b_at(x, y) != 0:
				t = ZoneData.T_URBAIN
			h[t] = float(h.get(t, 0.0)) + 1.0 / 64.0
	_habitat[rg] = h
	return h


## Nombre moyen de groupes d'une espèce dans une région, à cette heure.
func expected_groups(rg: Vector2i, id: String) -> float:
	var h := _region_habitat(rg)
	var dens := 0.0
	var hab: Dictionary = Species.info(id)["habitat"]
	for t in h:
		dens += float(h[t]) * float(hab.get(t, 0.0))
	var km := REGION * zone.cell_m / 1000.0
	var k := "%d,%d,%s" % [rg.x, rg.y, id]
	return dens * km * km * Species.activity(id, surv.hour()) * _stock_of(k)


func _stock_of(k: String) -> float:
	if not stock.has(k):
		return 1.0
	var v: Array = stock[k] if stock[k] is Array else [float(stock[k]), now()]
	var s := minf(1.0, float(v[0]) + (now() - float(v[1])) / 1440.0 * REGEN_PER_DAY)
	return s


func _populate(rg: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, rg.x, rg.y, int(now() / RESPAWN_MIN)])
	var pc := player.position / Tiles.SIZE
	for id in Species.DB:
		var lam := expected_groups(rg, id)
		if lam <= 0.0:
			continue
		# tirage de Poisson
		var n := 0
		var l := exp(-lam)
		var p := rng.randf()
		while p > l and n < 4:
			n += 1
			p *= rng.randf()
		for g in n:
			var hab: Dictionary = Species.info(id)["habitat"]
			for attempt in 14:
				var c := Vector2i(rg.x * REGION + rng.randi_range(0, REGION - 1), rg.y * REGION + rng.randi_range(0, REGION - 1))
				if not zone.inside(c.x, c.y) or zone.is_water(c.x, c.y) or zone.b_at(c.x, c.y) != 0:
					continue
				var t := zone.t_at(c.x, c.y)
				if float(hab.get(t, 0.0)) <= 0.0 and not (id == "chien" and t in [ZoneData.T_URBAIN, ZoneData.T_INDUSTRIEL]):
					continue
				if Vector2(c).distance_to(pc) < SPAWN_MIN:
					continue
				_spawn_group(id, c, rg, rng)
				break


func _spawn_group(id: String, c: Vector2i, rg: Vector2i, rng: RandomNumberGenerator) -> void:
	var gs: Array = Species.info(id)["groupe"]
	var count := rng.randi_range(int(gs[0]), int(gs[1]))
	_group_id += 1
	for i in count:
		var p := (Vector2(c) + Vector2(0.5, 0.5) + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))) * Tiles.SIZE
		_new_animal(id, p, rg, _group_id)


func _new_animal(id: String, p: Vector2, rg: Vector2i, grp: int) -> Animal:
	var a := Animal.new()
	a.region = rg
	a.group = grp
	world.entities.add_child(a)
	a.setup(self, id, p)
	animals.append(a)
	return a


## Pour les tests : fait apparaître un groupe près d'une case.
func spawn_at(id: String, cell: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	_spawn_group(id, cell, Vector2i(cell.x / REGION, cell.y / REGION), rng)


# --- Interactions du joueur -------------------------------------------------------

## Animal vivant à portée de coup devant le joueur.
func animal_in_reach(pos: Vector2, facing: Vector2, reach_cells: float) -> Animal:
	var best: Animal = null
	var bd := INF
	for a in animals:
		if a.is_dead():
			continue
		var v := a.position - pos
		var d := v.length() / Tiles.SIZE
		if d <= reach_cells and (d < 0.8 or facing.dot(v.normalized()) > 0.2) and d < bd:
			bd = d
			best = a
	return best


func carcass_near(pos: Vector2, r_cells := 1.6) -> Animal:
	for a in animals:
		if a.is_dead() and a.position.distance_to(pos) / Tiles.SIZE <= r_cells:
			return a
	return null


func pickup_near(pos: Vector2) -> Dictionary:
	for pk in pickups:
		if Vector2(float(pk["x"]), float(pk["y"])).distance_to(pos) / Tiles.SIZE <= 1.3:
			return pk
	return {}


func take_pickup(pk: Dictionary) -> void:
	pickups.erase(pk)
	if is_instance_valid(pk.get("node")):
		pk["node"].queue_free()


func remove_carcass(a: Animal) -> void:
	animals.erase(a)
	a.queue_free()


## Carcasse posée directement (collet relevé).
func add_carcass(id: String, p: Vector2) -> Animal:
	var a := _new_animal(id, p, Vector2i(floori(p.x / Tiles.SIZE / REGION), floori(p.y / Tiles.SIZE / REGION)), 0)
	a.die()
	return a


## Cible de tir : l'animal vivant le plus proche dans un cône devant le joueur.
func aim_target(pos: Vector2, facing: Vector2) -> Animal:
	var best: Animal = null
	var bs := -INF
	for a in animals:
		if a.is_dead():
			continue
		var v := a.body_center() - (pos + Vector2(0, -9))
		var d := v.length() / Tiles.SIZE
		if d > ARROW_RANGE:
			continue
		var dot := facing.dot(v.normalized())
		if dot < 0.9:
			continue
		var score := dot * 2.0 - d / ARROW_RANGE
		if score > bs:
			bs = score
			best = a
	return best


func shoot(pos: Vector2, dir: Vector2, damage: float) -> void:
	var node := Sprite2D.new()
	node.texture = Items.icon("fleche")
	node.scale = Vector2(0.55, 0.55)
	node.rotation = dir.angle() + PI / 4.0
	node.z_index = 5
	world.add_child(node)
	var start := pos + Vector2(0, -9)
	node.position = start
	_arrows.append({"pos": start, "dir": dir.normalized(), "left": ARROW_RANGE * Tiles.SIZE, "node": node, "dmg": damage})


func _update_arrows(delta: float) -> void:
	for ar in _arrows.duplicate():
		var step := ARROW_SPEED * Tiles.SIZE * delta
		var p: Vector2 = ar["pos"]
		var hit: Animal = null
		for a in animals:
			if a.is_dead():
				continue
			var closest := Geometry2D.get_closest_point_to_segment(a.body_center(), p, p + ar["dir"] * step)
			if closest.distance_to(a.body_center()) < 0.7 * Tiles.SIZE:
				hit = a
				break
		p += ar["dir"] * step
		ar["pos"] = p
		ar["left"] = float(ar["left"]) - step
		ar["node"].position = p
		var c := Vector2i(floori(p.x / Tiles.SIZE), floori((p.y + 12) / Tiles.SIZE))
		var wall := world.flags_at(c) & WorldGen.F_BLOCK != 0
		if hit:
			var dmg := float(ar["dmg"]) * (1.5 if not hit.alerted else 1.0)
			hit.hurt(dmg, player.position, true)
			ar["node"].queue_free()
			_arrows.erase(ar)
		elif float(ar["left"]) <= 0.0 or wall:
			ar["node"].queue_free()
			_arrows.erase(ar)
			if randf() < 0.6 and not zone.is_water(c.x, c.y):
				drop_item(p + Vector2(0, 12), {"id": "fleche", "n": 1})


## Pose un objet au sol (flèche perdue, objet jeté, sac trop plein…).
func drop_item(p: Vector2, s: Dictionary) -> void:
	var node := Sprite2D.new()
	node.texture = Items.icon(s["id"])
	node.scale = Vector2(0.5, 0.5) if s["id"] == "fleche" else Vector2(0.6, 0.6)
	node.rotation = randf() * TAU if s["id"] == "fleche" else 0.0
	node.position = p + (Vector2.ZERO if s["id"] == "fleche" else Vector2(0, -6))
	world.entities.add_child(node)
	var pk := s.duplicate()
	pk["x"] = p.x
	pk["y"] = p.y
	pk["node"] = node
	pickups.append(pk)


# --- Pièges ----------------------------------------------------------------------

## Collets et nasses : appelé avec le temps de jeu écoulé (minutes).
## Renvoie les cases de collets qui viennent de prendre quelque chose.
func update_traps(minutes_passed: float) -> Array:
	_trap_t += minutes_passed
	var out := []
	if _trap_t < 60.0:
		return out
	var hours := _trap_t / 60.0
	_trap_t = 0.0
	for k in mods.structures:
		var st: Dictionary = mods.structures[k]
		var c := WorldMods.cell_of(k)
		var rg := Vector2i(floori(float(c.x) / REGION), floori(float(c.y) / REGION))
		match st.get("type", ""):
			"collet":
				if st.get("pris", "") != "":
					continue
				var lam := 0.0
				for id in ["lapin", "renard"]:
					var hab: Dictionary = Species.info(id)["habitat"]
					var h := _region_habitat(rg)
					for t in h:
						lam += float(h[t]) * float(hab.get(t, 0.0)) * (1.0 if id == "lapin" else 2.0)
				var p := clampf(lam / 90.0 * 0.1, 0.0, 0.15) * hours
				if randf() < p:
					st["pris"] = "renard" if randf() < 0.15 else "lapin"
					world.set_decor(c, Tiles.D_COLLET_PRIS)
					out.append(c)
			"nasse":
				var n := int(st.get("poissons", 0))
				if n < 4 and randf() < 0.12 * hours:
					st["poissons"] = n + 1
	return out


# --- Sauvegarde ------------------------------------------------------------------

func to_data() -> Dictionary:
	var cs := carcasses.duplicate(true)
	for a in animals:
		if a.is_dead():
			cs.append({"x": a.position.x, "y": a.position.y, "sp": a.sp_id, "t": a.dead_at, "fleches": a.arrows})
	var pk := []
	for p in pickups:
		var c: Dictionary = p.duplicate()
		c.erase("node")
		pk.append(c)
	var st := {}
	for k in stock:
		st[k] = [_stock_of(k), now()]
	return {"stock": st, "carcasses": cs, "fleches": pk}


func from_data(d: Dictionary) -> void:
	stock = d.get("stock", {})
	carcasses = d.get("carcasses", [])
	for p in d.get("fleches", []):
		var s: Dictionary = p.duplicate()
		s["n"] = int(s.get("n", 1))
		drop_item(Vector2(float(p["x"]), float(p["y"])), s)


func _draw_blood() -> void:
	for b in _blood:
		var age := (now() - float(b[1])) / 720.0
		_blood_layer.draw_circle(b[0], 1.8, Color(0.45, 0.04, 0.04, 0.85 * (1.0 - age)))
