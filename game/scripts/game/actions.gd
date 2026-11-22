class_name Actions
extends RefCounted
## Actions du joueur sur ce qui l'entoure : trouver la cible, proposer l'action,
## l'exécuter. Renvoie des messages pour l'interface.

var world: ChunkManager
var zone: ZoneData
var surv: Survival
var inv: Inventory
var mods: WorldMods
var seed_value := 0

const TITLES := {"armoire": "Armoire", "commode": "Commode", "etagere": "Étagère", "carton": "Cartons",
	"frigo": "Frigo", "lit": "Lit", "caisse": "Caisse", "table": "Table", "rayon": "Rayon",
	"armoire_pharma": "Armoire à pharmacie", "etabli": "Établi", "foin": "Botte de foin",
	"voiture": "Voiture", "camionnette": "Camionnette"}

const TREES := [Tiles.D_FEUILLU_A, Tiles.D_FEUILLU_B, Tiles.D_RESINEUX_A, Tiles.D_RESINEUX_B,
	Tiles.D_JEUNE_ARBRE, Tiles.D_ARBRE_MORT, Tiles.D_SAULE]


## Cible : {cell, decor, kind} la plus proche devant le joueur, ou {} s'il n'y a rien.
func find_target(pos: Vector2, facing: Vector2) -> Dictionary:
	var front := pos + facing.normalized() * 14.0
	var c0 := Vector2i(floori(pos.x / Tiles.SIZE), floori(pos.y / Tiles.SIZE))
	var best := {}
	var best_d := INF
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cell := c0 + Vector2i(dx, dy)
			var d := world.decor_at(cell)
			if d < 0 or d in [Tiles.D_MUR, Tiles.D_MUR_BRISE, Tiles.D_TOMBE, Tiles.D_POTEAU]:
				continue
			var center := (Vector2(cell) + Vector2(0.5, 0.8)) * Tiles.SIZE
			var dist := center.distance_to(front)
			if dist < 40.0 and dist < best_d:
				best_d = dist
				best = {"cell": cell, "decor": d}
	return best


func near_water(pos: Vector2) -> bool:
	var c0 := Vector2i(floori(pos.x / Tiles.SIZE), floori(pos.y / Tiles.SIZE))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := c0 + Vector2i(dx, dy)
			if zone.t_at(c.x, c.y) == ZoneData.T_EAU:
				return true
	return false


func near_fire(pos: Vector2, radius := 4) -> Vector2i:
	var c0 := Vector2i(floori(pos.x / Tiles.SIZE), floori(pos.y / Tiles.SIZE))
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c := c0 + Vector2i(dx, dy)
			var st := mods.structure_at(c)
			if st.get("type", "") == "feu" and float(st.get("feu", 0)) > 0.0:
				return c
	return Vector2i(-1, -1)


func near_structure(pos: Vector2, type: String, radius := 1) -> Vector2i:
	var c0 := Vector2i(floori(pos.x / Tiles.SIZE), floori(pos.y / Tiles.SIZE))
	for dy in range(-radius, radius + 2):
		for dx in range(-radius, radius + 1):
			var c := c0 + Vector2i(dx, dy)
			if mods.structure_at(c).get("type", "") == type:
				return c
	return Vector2i(-1, -1)


## Libellé de l'action principale proposée (bouton d'action), "" si aucune.
func label_for(t: Dictionary, pos: Vector2) -> String:
	if not t.is_empty():
		var d: int = t["decor"]
		var cell: Vector2i = t["cell"]
		var name := Tiles.decor_name(d, cell)
		if d in Loot.TABLE_OF_DECOR:
			return "Ouvrir" if mods.is_searched(cell) else "Fouiller"
		match d:
			Tiles.D_FEU_ETEINT: return "Allumer le feu"
			Tiles.D_FEU_ALLUME: return "Entretenir le feu"
			Tiles.D_ABRI: return "Dormir"
			Tiles.D_COFFRE: return "Ouvrir le coffre"
		if not mods.can_harvest(cell, surv.minutes):
			return ""
		if d in TREES:
			if name == "pommier" and surv.season() == 2:
				return "Cueillir des pommes"
			return "Couper du bois" if inv.has("hache") else "Ramasser des branches"
		match d:
			Tiles.D_BUISSON, Tiles.D_AJONC: return "Ramasser"
			Tiles.D_RONCES: return "Cueillir des mûres" if surv.season() in [1, 2] else "Ramasser des fibres"
			Tiles.D_ROSEAUX: return "Ramasser des fibres"
			Tiles.D_ROCHER: return "Ramasser des pierres"
			Tiles.D_GRAVATS: return "Fouiller les débris"
			Tiles.D_SOUCHE: return "Ramasser du bois"
	if near_water(pos):
		return "Remplir la bouteille" if inv.has("bouteille_vide") else "Boire"
	var g := world.ground_at(Vector2i(floori(pos.x / Tiles.SIZE), floori(pos.y / Tiles.SIZE)))
	if g == Tiles.G_SOL_FEUILLUS and surv.season() == 2:
		var fc := Vector2i(floori(pos.x / Tiles.SIZE) >> 2, floori(pos.y / Tiles.SIZE) >> 2) + Vector2i(100000, 0)
		if mods.can_harvest(fc, surv.minutes):
			return "Chercher des champignons"
	return ""


## Exécute l'action principale ; renvoie le message à afficher (et peut ouvrir le coffre).
func run(t: Dictionary, pos: Vector2) -> Dictionary:
	var label := label_for(t, pos)
	if label == "":
		return {}
	var got := {}
	var msg := ""
	match label:
		"Boire":
			var risky := randf() < 0.3
			surv.soif = minf(100.0, surv.soif + 30.0)
			msg = "Tu bois l'eau de la rivière."
			if risky:
				surv.malade = maxf(surv.malade, 12.0 * 60.0)
				msg += " Elle n'était pas saine…"
			return {"msg": msg}
		"Remplir la bouteille":
			inv.remove("bouteille_vide")
			inv.add("bouteille_eau")
			return {"msg": "Bouteille remplie (eau à faire bouillir)."}
		"Chercher des champignons":
			var fc := Vector2i(floori(pos.x / Tiles.SIZE) >> 2, floori(pos.y / Tiles.SIZE) >> 2) + Vector2i(100000, 0)
			mods.harvest(fc, surv.minutes, 2.0)
			var r := randf()
			if r < 0.35:
				got = {"champignon": 1 + randi() % 2}
			elif r < 0.6:
				got = {"champignon_douteux": 1}
			else:
				return {"msg": "Rien ici."}
	if t.is_empty():
		return _give(got, msg)
	var cell: Vector2i = t["cell"]
	var d: int = t["decor"]
	match label:
		"Fouiller", "Ouvrir":
			if label == "Fouiller":
				surv.fouilles += 1
				var content := Inventory.new(12)
				var loot := Loot.roll(Loot.TABLE_OF_DECOR[d], cell, seed_value)
				for id in loot:
					content.add(id, int(loot[id]))
				mods.mark_searched(cell, content.to_data())
			return {"container": cell, "title": TITLES.get(Tiles.decor_name(d, cell), "Meuble")}
		"Ramasser des branches":
			got = {"branche": 2 + randi() % 2}
			mods.harvest(cell, surv.minutes)
		"Couper du bois":
			got = {"buche": 2, "branche": 1}
			mods.harvest(cell, surv.minutes)
			if not inv.wear("hache"):
				msg = "La hache s'est cassée."
		"Cueillir des pommes":
			got = {"pomme": 2 + randi() % 3}
			mods.harvest(cell, surv.minutes, 4.0)
		"Ramasser":
			got = {"branche": 1, "fibre": 1 + randi() % 2}
			mods.harvest(cell, surv.minutes)
		"Cueillir des mûres":
			got = {"mures": 3 + randi() % 4}
			mods.harvest(cell, surv.minutes, 2.0)
			if inv.has("couteau"):
				inv.wear("couteau")
			else:
				surv.hurt(4.0, "les ronces")
				msg = "Les ronces t'égratignent."
		"Ramasser des fibres":
			got = {"fibre": 2 + randi() % 2}
			mods.harvest(cell, surv.minutes)
			if d == Tiles.D_RONCES and not inv.has("couteau"):
				surv.hurt(3.0, "les ronces")
		"Ramasser des pierres":
			got = {"pierre": 2}
			if randf() < 0.3:
				got["silex"] = 1
			mods.harvest(cell, surv.minutes, 5.0)
		"Fouiller les débris":
			var name := Tiles.decor_name(d, cell)
			got = {"planche": 2} if name == "palette" else ({"buche": 1} if name == "rondins" else {"pierre": 1})
			mods.harvest(cell, surv.minutes, 30.0)
		"Ramasser du bois":
			got = {"buche": 1} if inv.has("hache") else {"branche": 2}
			mods.harvest(cell, surv.minutes)
		"Allumer le feu", "Entretenir le feu":
			return fire(cell)
		"Dormir":
			return {"sleep": "abri"}
		"Ouvrir le coffre":
			return {"chest": cell}
	return _give(got, msg)


func _give(got: Dictionary, msg: String) -> Dictionary:
	var parts: PackedStringArray = []
	var lost := false
	for id in got:
		var left := inv.add(id, int(got[id]))
		if left < int(got[id]):
			parts.append("+%d %s" % [int(got[id]) - left, Items.name_of(id).to_lower()])
		if left > 0:
			lost = true
	var text := ", ".join(parts)
	if lost:
		text += " (sac plein)"
	if msg != "":
		text = msg + ("  " + text if text != "" else "")
	return {"msg": text}


## Allumer ou entretenir un feu.
func fire(cell: Vector2i) -> Dictionary:
	var st: Dictionary = mods.structures.get(WorldMods.key(cell), {})
	var lit := float(st.get("feu", 0)) > 0.0
	var fuel := 0.0
	if inv.remove("buche"):
		fuel = 240.0
	elif inv.remove("branche"):
		fuel = 60.0
	else:
		return {"msg": "Il faut du bois (branches ou bûches)."}
	if not lit:
		if inv.remove("allumettes"):
			pass
		elif inv.remove("fibre"):
			surv.minutes += 20.0     # friction : ça prend du temps
		else:
			inv.add("buche" if fuel > 60.0 else "branche")
			return {"msg": "Il faut des allumettes ou des fibres pour l'allumer."}
	st["feu"] = float(st.get("feu", 0)) + fuel
	mods.structures[WorldMods.key(cell)] = st
	world.set_decor(cell, Tiles.D_FEU_ALLUME)
	return {"msg": "Le feu prend." if not lit else "Tu remets du bois.", "fire": cell}


## Fait brûler les feux allumés ; renvoie les feux qui viennent de s'éteindre.
func burn(minutes_passed: float) -> Array:
	var out := []
	for k in mods.structures:
		var st: Dictionary = mods.structures[k]
		if st.get("type", "") == "feu" and float(st.get("feu", 0)) > 0.0:
			st["feu"] = maxf(0.0, float(st["feu"]) - minutes_passed)
			if float(st["feu"]) == 0.0:
				var cell := WorldMods.cell_of(k)
				world.set_decor(cell, Tiles.D_FEU_ETEINT)
				out.append(cell)
	return out


## Pose une construction sur la case libre devant le joueur.
func place(type: String, pos: Vector2, facing: Vector2) -> bool:
	var front := pos + facing.normalized() * 30.0
	var cell := Vector2i(floori(front.x / Tiles.SIZE), floori(front.y / Tiles.SIZE))
	if world.decor_at(cell) >= 0 or world.flags_at(cell) & (WorldGen.F_BLOCK | WorldGen.F_INDOOR):
		return false
	if zone.is_water(cell.x, cell.y) or zone.r_at(cell.x, cell.y) != 0:
		return false
	var st := {"type": type}
	if type == "coffre":
		st["objets"] = []
	mods.structures[WorldMods.key(cell)] = st
	world.set_decor(cell, world.structure_decor(st))
	return true
