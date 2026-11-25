class_name BuildingPlan
extends RefCounted
## Plan intérieur d'un bâtiment réel (docs/BATIMENTS2.md), sur la grille fine (1 m).
##
## Fabriqué à partir d'une fiche de tools/zone/build_tiled.py : emprise, type, état,
## rue la plus proche. Toujours le même pour un même bâtiment (tirages par son id).
## Coordonnées locales : (0, 0) = coin nord-ouest de l'emprise ; x, y = origine
## sur la grille fine du monde (1 case du monde = 2 x 2 cases fines).

# Arêtes : une valeur pour le bord nord (en) et le bord ouest (ew) de chaque case
const E_NONE := 0
const E_WALL := 1
const E_DOOR := 2          ## porte extérieure (fermée au départ)
const E_WINDOW := 3
const E_BREACH := 4        ## brèche (ruine) : on passe
const E_IDOOR := 5         ## porte intérieure (ouverte au départ)

## Sols : index de la planche des sols intérieurs
const FLOORS := ["parquet", "carrelage", "beton", "terre", "lino", "dalles"]

## Pièce -> [sol, matériau des meubles…]
const ROOM_FLOOR := {
	"entree": "carrelage", "sejour": "parquet", "cuisine": "carrelage", "chambre": "parquet",
	"sdb": "carrelage", "wc": "carrelage", "couloir": "lino", "garage": "beton", "remise": "beton",
	"salle_commune": "dalles", "etable": "terre", "grange": "terre", "atelier": "beton",
	"bureau": "lino", "vente": "lino", "reserve": "beton", "salle": "lino", "sanitaires": "carrelage",
	"nef": "dalles", "sacristie": "parquet", "hall": "carrelage",
}

## Meubles par pièce : [nom, largeur, profondeur (m), nombre, contre un mur ?]
const ROOM_FURNITURE := {
	"entree": [["meuble_entree", 1, 1, 1]],
	"sejour": [["canape", 2, 1, 1], ["buffet", 2, 1, 1], ["poele", 1, 1, 1], ["table_basse", 1, 1, 1], ["etagere_livres", 1, 1, 1]],
	"cuisine": [["evier", 1, 1, 1], ["cuisiniere", 1, 1, 1], ["frigo", 1, 1, 1], ["placard", 1, 1, 2], ["table", 2, 1, 1]],
	"chambre": [["lit", 2, 2, 1], ["armoire", 2, 1, 1], ["commode", 1, 1, 1]],
	"sdb": [["baignoire", 2, 1, 1], ["lavabo", 1, 1, 1], ["meuble_sdb", 1, 1, 1]],
	"wc": [["wc", 1, 1, 1]],
	"garage": [["etabli", 2, 1, 1], ["etageres", 2, 1, 2]],
	"remise": [["etageres", 2, 1, 1], ["cartons", 1, 1, 2]],
	"salle_commune": [["cheminee", 2, 1, 1], ["table", 2, 1, 1], ["buffet", 2, 1, 1], ["evier", 1, 1, 1], ["lit", 2, 2, 1]],
	"etable": [["auge", 2, 1, 2], ["foin", 2, 2, 1]],
	"grange": [["foin", 2, 2, 3], ["palette", 2, 2, 1]],
	"atelier": [["etabli", 2, 1, 2], ["etageres", 2, 1, 3], ["palette", 2, 2, 2], ["cartons", 1, 1, 3]],
	"bureau": [["bureau", 2, 1, 1], ["armoire_bureau", 1, 1, 2]],
	"vente": [["comptoir", 2, 1, 1], ["rayonnage", 2, 1, 6]],
	"reserve": [["etageres", 2, 1, 4], ["cartons", 1, 1, 4]],
	"salle": [["bureau", 2, 1, 1], ["pupitre", 1, 1, 8], ["armoire_bureau", 1, 1, 1]],
	"sanitaires": [["wc", 1, 1, 2], ["lavabo", 1, 1, 2]],
	"nef": [["banc", 2, 1, 10], ["autel", 2, 1, 1]],
	"sacristie": [["armoire", 2, 1, 1]],
	"hall": [["boites_lettres", 1, 1, 1]],
	"couloir": [],
}

## Meubles à fouiller -> table de butin (scripts/survival/loot.gd)
const LOOT := {
	"meuble_entree": "entree", "buffet": "sejour", "etagere_livres": "livres", "placard": "cuisine",
	"frigo": "frigo", "armoire": "chambre", "commode": "chambre", "meuble_sdb": "sdb",
	"etabli": "atelier", "etageres": "atelier", "cartons": "reserve", "bureau": "bureau",
	"armoire_bureau": "bureau", "comptoir": "vente", "rayonnage": "vente", "auge": "ferme",
	"foin": "ferme", "palette": "reserve", "cuisiniere": "cuisine",
}

var id := 0
var type := "maison"
var kind := ""                 ## lieu notable (pharmacie, épicerie…)
var roof := 1                  ## 1 ardoise, 2 tôle
var state := 0                 ## 0 intact, 1 toit effondré, 2 ruine
var x := 0
var y := 0
var w := 0
var h := 0
var inside := PackedByteArray()      ## 1 si la case fine est dans le bâtiment
var room := PackedInt32Array()       ## pièce de chaque case (-1 dehors)
var rooms: Array = []                ## {type, floor, area, cells}
var en := PackedByteArray()          ## bord nord de (cx, cy), cx < w, cy <= h : index cy * (w + 1) + cx
var ew := PackedByteArray()          ## bord ouest de (cx, cy), cx <= w, cy < h : même index
var furniture: Array = []            ## {t, x, y, w, h, loot}
var material := "enduit"             ## murs : enduit, granit, parpaing, bois
var _rng := RandomNumberGenerator.new()
var _anchors := {}

static var _cache := {}
static var _mutex := Mutex.new()


## Plan d'une fiche (mis en cache : le même pour tous les morceaux du bâtiment).
static func of(rec: Dictionary) -> BuildingPlan:
	var k := int(rec["id"])
	_mutex.lock()
	var p: BuildingPlan = _cache.get(k)
	_mutex.unlock()
	if p:
		return p
	p = BuildingPlan.new()
	p.build(rec)
	_mutex.lock()
	if _cache.size() > 3000:
		_cache.clear()
	_cache[k] = p
	_mutex.unlock()
	return p


static func clear_cache() -> void:
	_mutex.lock()
	_cache.clear()
	_mutex.unlock()


func cell_in(cx: int, cy: int) -> bool:
	return cx >= 0 and cy >= 0 and cx < w and cy < h and inside[cy * w + cx] == 1


func room_at(cx: int, cy: int) -> int:
	return room[cy * w + cx] if cx >= 0 and cy >= 0 and cx < w and cy < h else -1


func ei(cx: int, cy: int) -> int:
	return cy * (w + 1) + cx


func build(rec: Dictionary) -> void:
	id = int(rec["id"])
	type = String(rec.get("t", "maison"))
	kind = String(rec.get("k", ""))
	roof = int(rec.get("r", 1))
	state = int(rec.get("s", 0))
	x = int(rec["x"])
	y = int(rec["y"])
	w = int(rec["w"])
	h = int(rec["h"])
	_rng.seed = hash(id) ^ 0x5eed
	# emprise
	var bits := Marshalls.base64_to_raw(String(rec["m"]))
	inside.resize(w * h)
	for i in w * h:
		inside[i] = (bits[i >> 3] >> (7 - (i & 7))) & 1
	room.resize(w * h)
	room.fill(-1)
	var rd: Array = rec.get("rd", [0.0, 1.0])
	var road := Vector2(float(rd[0]), float(rd[1]))
	material = _pick_material()
	_partition(road)
	_name_rooms(road)
	en.resize((w + 1) * (h + 1))
	ew.resize((w + 1) * (h + 1))
	_walls()
	var entry := _doors(road)
	_windows()
	if state == 2:
		_ruin()
	_furnish(entry)


func _pick_material() -> String:
	match type:
		"hangar", "commerce_grand": return "parpaing"
		"grange", "annexe": return "bois" if _rng.randf() < 0.6 else "parpaing"
		"longere", "eglise": return "granit"
		"maison": return "granit" if _rng.randf() < 0.3 else "enduit"
	return "enduit"


# --- Découpage en pièces ------------------------------------------------------------

## Pièces = rectangles d'un découpage binaire de l'emprise, selon le type.
func _partition(road: Vector2) -> void:
	var area := 0
	for v in inside:
		area += v
	var leaves: Array = []
	var full := Rect2i(0, 0, w, h)
	match type:
		"annexe", "grange", "eglise", "commerce_grand":
			leaves = [full]
			if type == "eglise" and area > 60:
				leaves = _cut(full, 0.85, w >= h)
			elif type == "commerce_grand" and area > 80:
				leaves = _cut(full, 0.8, w < h)
		"hangar":
			leaves = [full]
			if area > 120:
				var o := Rect2i(0, 0, mini(4, w / 3), mini(4, h / 3))
				leaves = [o, full]            # bureau dans un coin, le reste en atelier
		"longere":
			# enfilade le long du grand côté : une pièce tous les 4 à 7 m
			var long_x := w >= h
			var L := w if long_x else h
			var n := clampi(int(round(L / 5.5)), 2, 6)
			var pos := 0
			for k in n:
				var size := (L - pos) if k == n - 1 else int(round(float(L) / n)) + _rng.randi_range(-1, 1)
				leaves.append(Rect2i(pos, 0, size, h) if long_x else Rect2i(0, pos, w, size))
				pos += size
		"public":
			# couloir central le long du grand côté, salles de part et d'autre
			var along_x := w >= h
			var mid := (h if along_x else w) / 2
			var corr := Rect2i(0, mid - 1, w, 2) if along_x else Rect2i(mid - 1, 0, 2, h)
			var a := Rect2i(0, 0, w, mid - 1) if along_x else Rect2i(0, 0, mid - 1, h)
			var b := Rect2i(0, mid + 1, w, h - mid - 1) if along_x else Rect2i(mid + 1, 0, w - mid - 1, h)
			leaves = [corr]
			for half in [a, b]:
				leaves.append_array(_bsp(half, 35, 3))
		"commerce":
			# salle de vente côté rue (65 %), réserve et bureau au fond
			var by_x := absf(road.x) > absf(road.y)
			var toward_end := (road.x > 0) if by_x else (road.y > 0)
			leaves = _cut(full, 0.35 if toward_end else 0.65, by_x)
			if leaves.size() == 2:
				var back_i := 0 if toward_end else 1
				var back: Rect2i = leaves[back_i]
				leaves.remove_at(back_i)
				if back.get_area() > 16:
					leaves.append_array(_cut(back, 0.5, not by_x))
				else:
					leaves.append(back)
		"immeuble":
			leaves = _bsp(full, 18, 2)
		_:
			var target := 16 if area < 90 else 20
			leaves = _bsp(full, target, 2)
	# rectangles -> pièces (cases de l'emprise seulement ; le premier rectangle gagne)
	for r in leaves:
		var cells := PackedInt32Array()
		for cy in range(r.position.y, r.end.y):
			for cx in range(r.position.x, r.end.x):
				var i := cy * w + cx
				if cx < w and cy < h and inside[i] == 1 and room[i] == -1:
					cells.append(i)
		if cells.size() > 0:
			var k := rooms.size()
			for i in cells:
				room[i] = k
			rooms.append({"type": "", "area": cells.size(), "cells": cells})
	# petites pièces (moins de 3 m²) et morceaux détachés : rattachés à une voisine
	for k in rooms.size():
		if rooms[k]["area"] < 3 or not _connected(k):
			_merge_into_neighbour(k)
	# cases de l'emprise oubliées
	for i in w * h:
		if inside[i] == 1 and room[i] == -1:
			var cx := i % w
			var cy := i / w
			var best := -1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var r := room_at(cx + d.x, cy + d.y)
				if r >= 0:
					best = r
					break
			if best < 0:
				best = rooms.size()
				rooms.append({"type": "", "area": 0, "cells": PackedInt32Array()})
			room[i] = best
			rooms[best]["area"] += 1
			rooms[best]["cells"].append(i)


func _cut(r: Rect2i, frac: float, vertical_cut: bool) -> Array:
	if vertical_cut:
		var cut := clampi(int(round(r.size.x * frac)), 2, r.size.x - 2)
		if r.size.x < 5:
			return [r]
		return [Rect2i(r.position.x, r.position.y, cut, r.size.y), Rect2i(r.position.x + cut, r.position.y, r.size.x - cut, r.size.y)]
	var cut2 := clampi(int(round(r.size.y * frac)), 2, r.size.y - 2)
	if r.size.y < 5:
		return [r]
	return [Rect2i(r.position.x, r.position.y, r.size.x, cut2), Rect2i(r.position.x, r.position.y + cut2, r.size.x, r.size.y - cut2)]


## Découpage binaire : on coupe le côté long tant que la pièce dépasse target m².
func _bsp(r: Rect2i, target: int, min_side: int) -> Array:
	var area := 0
	for cy in range(r.position.y, r.end.y):
		for cx in range(r.position.x, r.end.x):
			if cx < w and cy < h:
				area += inside[cy * w + cx]
	if area <= target * 1.3:
		return [r]
	var vertical := r.size.x >= r.size.y
	var side := r.size.x if vertical else r.size.y
	if side < min_side * 2 + 1:
		vertical = not vertical
		side = r.size.x if vertical else r.size.y
		if side < min_side * 2 + 1:
			return [r]
	var cut := clampi(int(round(side * _rng.randf_range(0.38, 0.62))), min_side, side - min_side)
	var a: Rect2i
	var b: Rect2i
	if vertical:
		a = Rect2i(r.position.x, r.position.y, cut, r.size.y)
		b = Rect2i(r.position.x + cut, r.position.y, r.size.x - cut, r.size.y)
	else:
		a = Rect2i(r.position.x, r.position.y, r.size.x, cut)
		b = Rect2i(r.position.x, r.position.y + cut, r.size.x, r.size.y - cut)
	return _bsp(a, target, min_side) + _bsp(b, target, min_side)


func _connected(k: int) -> bool:
	var cells: PackedInt32Array = rooms[k]["cells"]
	if cells.size() == 0:
		return true
	var seen := {cells[0]: true}
	var stack := [cells[0]]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var cx := i % w
		var cy := i / w
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if room_at(nx, ny) == k and not seen.has(ny * w + nx):
				seen[ny * w + nx] = true
				stack.append(ny * w + nx)
	return seen.size() == cells.size()


func _merge_into_neighbour(k: int) -> void:
	var count := {}
	for i in rooms[k]["cells"]:
		var cx: int = i % w
		var cy: int = i / w
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var r := room_at(cx + d.x, cy + d.y)
			if r >= 0 and r != k and rooms[r]["area"] > 0:
				count[r] = int(count.get(r, 0)) + 1
	if count.is_empty():
		return
	var best: int = count.keys()[0]
	for r in count:
		if count[r] > count[best]:
			best = r
	for i in rooms[k]["cells"]:
		room[i] = best
	rooms[best]["cells"].append_array(rooms[k]["cells"])
	rooms[best]["area"] += rooms[k]["area"]
	rooms[k]["cells"] = PackedInt32Array()
	rooms[k]["area"] = 0


## Pièces voisines : k -> {voisine: longueur de mur commun}
func _adjacency() -> Dictionary:
	var adj := {}
	for cy in h:
		for cx in w:
			var a := room_at(cx, cy)
			if a < 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var b := room_at(cx + d.x, cy + d.y)
				if b >= 0 and b != a:
					for pair in [[a, b], [b, a]]:
						if not adj.has(pair[0]):
							adj[pair[0]] = {}
						adj[pair[0]][pair[1]] = int(adj[pair[0]].get(pair[1], 0)) + 1
	return adj


# --- Nommer les pièces ----------------------------------------------------------------

func _name_rooms(road: Vector2) -> void:
	var live: Array = []
	for k in rooms.size():
		if rooms[k]["area"] > 0:
			live.append(k)
	live.sort_custom(func(a, b): return rooms[a]["area"] > rooms[b]["area"])
	var front := _front_order(live, road)       # du plus proche de la rue au plus loin
	match type:
		"annexe":
			for k in live:
				rooms[k]["type"] = "garage" if rooms[k]["area"] >= 15 and _rng.randf() < 0.6 else "remise"
		"grange":
			for k in live:
				rooms[k]["type"] = "grange" if rooms[k]["area"] > 40 or _rng.randf() < 0.5 else "etable"
		"hangar":
			for k in live:
				rooms[k]["type"] = "atelier"
			if live.size() > 1:
				rooms[live[-1]]["type"] = "bureau"
		"eglise":
			for k in live:
				rooms[k]["type"] = "nef"
			if live.size() > 1:
				rooms[live[-1]]["type"] = "sacristie"
		"commerce", "commerce_grand":
			for k in live:
				rooms[k]["type"] = "reserve"
			rooms[front[0]]["type"] = "vente"
			if live.size() > 2:
				rooms[live[-1]]["type"] = "bureau"
		"public":
			for k in live:
				rooms[k]["type"] = "salle"
			rooms[live[0]]["type"] = "salle"
			for k in live:
				if _is_strip(k):
					rooms[k]["type"] = "couloir"
			var small := live.duplicate()
			small.sort_custom(func(a, b): return rooms[a]["area"] < rooms[b]["area"])
			for k in small:
				if rooms[k]["type"] == "salle":
					rooms[k]["type"] = "sanitaires"
					break
			if kind == "mairie" or kind == "gendarmerie":
				for k in live:
					if rooms[k]["type"] == "salle":
						rooms[k]["type"] = "bureau"
		"longere":
			var order := _line_order(live)
			for n in order.size():
				var k: int = order[n]
				rooms[k]["type"] = "chambre"
			rooms[order[order.size() / 2]]["type"] = "salle_commune"
			rooms[order[0]]["type"] = "etable" if order.size() > 2 else rooms[order[0]]["type"]
			if order.size() > 3:
				rooms[order[-1]]["type"] = "grange"
		_:   # maison, immeuble
			for k in live:
				rooms[k]["type"] = "chambre"
			if live.size() == 1:
				rooms[live[0]]["type"] = "sejour"
				return
			var entry: int = front[0]
			var big: int = live[0]
			rooms[big]["type"] = "sejour"
			var adj := _adjacency()
			if entry != big:
				rooms[entry]["type"] = "entree"
			# cuisine : la plus grande voisine du séjour (ni l'entrée)
			var kitchen := -1
			for k in live:
				if k != big and k != entry and adj.get(big, {}).has(k) and rooms[k]["area"] >= 5:
					kitchen = k
					break
			if kitchen < 0:
				for k in live:
					if rooms[k]["type"] == "chambre":
						kitchen = k
						break
			if kitchen >= 0:
				rooms[kitchen]["type"] = "cuisine"
			# petites pièces : salle de bain, WC ; la dernière chambre devient parfois un garage
			var small := live.duplicate()
			small.sort_custom(func(a, b): return rooms[a]["area"] < rooms[b]["area"])
			var bath := false
			for k in small:
				if rooms[k]["type"] != "chambre":
					continue
				if rooms[k]["area"] <= 4:
					rooms[k]["type"] = "wc"
				elif not bath and rooms[k]["area"] <= 10:
					rooms[k]["type"] = "sdb"
					bath = true
			if not bath:
				for k in small:
					if rooms[k]["type"] == "chambre":
						rooms[k]["type"] = "sdb"
						break
			if type == "immeuble" and entry != big:
				rooms[entry]["type"] = "hall"
	for k in rooms.size():
		rooms[k]["floor"] = FLOORS.find(ROOM_FLOOR.get(rooms[k]["type"], "parquet"))


func _is_strip(k: int) -> bool:
	var c: PackedInt32Array = rooms[k]["cells"]
	var x0 := w
	var x1 := 0
	var y0 := h
	var y1 := 0
	for i in c:
		x0 = mini(x0, i % w)
		x1 = maxi(x1, i % w)
		y0 = mini(y0, i / w)
		y1 = maxi(y1, i / w)
	return mini(x1 - x0 + 1, y1 - y0 + 1) <= 2 and maxi(x1 - x0 + 1, y1 - y0 + 1) >= 6


func _center(k: int) -> Vector2:
	var s := Vector2.ZERO
	var c: PackedInt32Array = rooms[k]["cells"]
	for i in c:
		s += Vector2(i % w, i / w)
	return s / maxf(1.0, c.size())


func _front_order(live: Array, road: Vector2) -> Array:
	var o := live.duplicate()
	o.sort_custom(func(a, b): return _center(a).dot(road) > _center(b).dot(road))
	return o


func _line_order(live: Array) -> Array:
	var o := live.duplicate()
	var along_x := w >= h
	o.sort_custom(func(a, b): return (_center(a).x < _center(b).x) if along_x else (_center(a).y < _center(b).y))
	return o


# --- Murs, portes, fenêtres -------------------------------------------------------------

func _walls() -> void:
	for cy in range(h + 1):
		for cx in range(w + 1):
			var here := room_at(cx, cy)
			if cx < w:
				var up := room_at(cx, cy - 1)
				if here != up:
					en[ei(cx, cy)] = E_WALL
			if cy < h:
				var left := room_at(cx - 1, cy)
				if here != left:
					ew[ei(cx, cy)] = E_WALL


## Arêtes extérieures de la pièce k : [cx, cy, "n"|"w", normale vers l'extérieur]
func _outer_edges(k: int) -> Array:
	var out := []
	for i in rooms[k]["cells"]:
		var cx: int = i % w
		var cy: int = i / w
		if room_at(cx, cy - 1) == -1:
			out.append([cx, cy, "n", Vector2(0, -1)])
		if room_at(cx, cy + 1) == -1:
			out.append([cx, cy + 1, "n", Vector2(0, 1)])
		if room_at(cx - 1, cy) == -1:
			out.append([cx, cy, "w", Vector2(-1, 0)])
		if room_at(cx + 1, cy) == -1:
			out.append([cx + 1, cy, "w", Vector2(1, 0)])
	return out


func _set_edge(e: Array, code: int) -> void:
	if e[2] == "n":
		en[ei(e[0], e[1])] = code
	else:
		ew[ei(e[0], e[1])] = code


func _edge(e: Array) -> int:
	return en[ei(e[0], e[1])] if e[2] == "n" else ew[ei(e[0], e[1])]


## Une arête extérieure n'est bonne pour une porte que si ses deux voisines le long du mur
## sont aussi des murs (pas dans un angle).
func _straight(e: Array) -> bool:
	var a: Array
	var b: Array
	if e[2] == "n":
		a = [e[0] - 1, e[1], "n"]
		b = [e[0] + 1, e[1], "n"]
		if a[0] < 0 or b[0] >= w:
			return false
	else:
		a = [e[0], e[1] - 1, "w"]
		b = [e[0], e[1] + 1, "w"]
		if a[1] < 0 or b[1] >= h:
			return false
	return _edge(a) != E_NONE and _edge(b) != E_NONE


## Portes : entrée principale côté rue, porte de service, portes entre pièces.
## Renvoie la pièce d'entrée.
func _doors(road: Vector2) -> int:
	var live: Array = []
	for k in rooms.size():
		if rooms[k]["area"] > 0:
			live.append(k)
	if live.is_empty():
		return -1
	var entry: int = _front_order(live, road)[0]
	# longère : chaque pièce a sa porte sur la cour (côté rue)
	var with_door: Array = [entry]
	if type == "longere":
		with_door = live
	if type == "public" or type == "immeuble":
		for k in live:
			if rooms[k]["type"] in ["couloir", "hall"]:
				entry = k
				with_door = [k]
	for k in with_door:
		var best: Array = []
		var bs := -INF
		for e in _outer_edges(k):
			if not _straight(e):
				continue
			var s: float = (e[3] as Vector2).dot(road) * 10.0 - absf(_rng.randf())
			if s > bs:
				bs = s
				best = e
		if not best.is_empty():
			_set_edge(best, E_DOOR)
			if type in ["hangar", "grange", "commerce_grand"]:
				# grande porte : deux mètres
				var nb := [best[0] + 1, best[1], best[2]] if best[2] == "n" else [best[0], best[1] + 1, best[2]]
				if _edge(nb) == E_WALL:
					_set_edge(nb, E_DOOR)
	# porte de service à l'arrière (maisons assez grandes, cuisine de préférence)
	if type in ["maison", "commerce", "public"] and _area() > 70:
		var back := -1
		for k in live:
			if rooms[k]["type"] in ["cuisine", "reserve", "garage"]:
				back = k
		if back >= 0:
			var best2: Array = []
			var bs2 := -INF
			for e in _outer_edges(back):
				if _straight(e) and _edge(e) == E_WALL:
					var s2: float = -(e[3] as Vector2).dot(road)
					if s2 > bs2:
						bs2 = s2
						best2 = e
			if not best2.is_empty() and bs2 > 0.3:
				_set_edge(best2, E_DOOR)
	# portes intérieures : arbre couvrant depuis l'entrée
	var adj := _adjacency()
	var seen := {entry: true}
	var queue := [entry]
	while not queue.is_empty():
		var a: int = queue.pop_front()
		var nbs: Array = adj.get(a, {}).keys()
		nbs.sort_custom(func(p, q): return adj[a][p] > adj[a][q])
		for b in nbs:
			if seen.has(b):
				continue
			seen[b] = true
			queue.append(b)
			_inner_door(a, b)
	# pièces sans lien avec l'entrée (rares) : une porte vers l'extérieur
	for k in live:
		if not seen.has(k):
			for e in _outer_edges(k):
				if _straight(e):
					_set_edge(e, E_DOOR)
					break
	return entry


func _inner_door(a: int, b: int) -> void:
	var cands: Array = []
	for i in rooms[a]["cells"]:
		var cx: int = i % w
		var cy: int = i / w
		if room_at(cx, cy - 1) == b:
			cands.append([cx, cy, "n"])
		if room_at(cx, cy + 1) == b:
			cands.append([cx, cy + 1, "n"])
		if room_at(cx - 1, cy) == b:
			cands.append([cx, cy, "w"])
		if room_at(cx + 1, cy) == b:
			cands.append([cx + 1, cy, "w"])
	if cands.is_empty():
		return
	# au milieu du mur commun, sinon le premier endroit possible
	var pick: Array = cands[cands.size() / 2]
	_set_edge(pick, E_IDOOR)


func _area() -> int:
	var a := 0
	for v in inside:
		a += v
	return a


## Fenêtres tous les 3 à 4 m sur les murs extérieurs, sauf réserves et WC.
func _windows() -> void:
	var none := ["wc", "reserve", "remise", "couloir", "hall"]
	var few := ["garage", "atelier", "grange", "etable"]
	for k in rooms.size():
		if rooms[k]["area"] == 0 or rooms[k]["type"] in none:
			continue
		var step := 6 if rooms[k]["type"] in few else 3
		var n := 0
		for e in _outer_edges(k):
			n += 1
			if n % step != 2 or not _straight(e) or _edge(e) != E_WALL:
				continue
			if _near_door(e):
				continue
			_set_edge(e, E_WINDOW)


func _near_door(e: Array) -> bool:
	var around: Array
	if e[2] == "n":
		around = [[e[0] - 1, e[1], "n"], [e[0] + 1, e[1], "n"]]
	else:
		around = [[e[0], e[1] - 1, "w"], [e[0], e[1] + 1, "w"]]
	for a in around:
		if a[0] >= 0 and a[1] >= 0 and a[0] <= w and a[1] <= h:
			var v := _edge(a)
			if v == E_DOOR or v == E_IDOOR:
				return true
	return false


## Ruine : brèches dans les murs, portes arrachées.
func _ruin() -> void:
	for i in en.size():
		if en[i] in [E_DOOR, E_IDOOR]:
			en[i] = E_BREACH
		elif en[i] != E_NONE and _rng.randf() < 0.18:
			en[i] = E_BREACH
	for i in ew.size():
		if ew[i] in [E_DOOR, E_IDOOR]:
			ew[i] = E_BREACH
		elif ew[i] != E_NONE and _rng.randf() < 0.18:
			ew[i] = E_BREACH


# --- Meubles ------------------------------------------------------------------------------

func _furnish(_entry: int) -> void:
	var used := PackedByteArray()
	used.resize(w * h)
	# cases devant les portes : toujours libres
	for cy in range(h + 1):
		for cx in range(w + 1):
			for side in ["n", "w"]:
				if (side == "n" and cx >= w) or (side == "w" and cy >= h):
					continue
				var v: int = en[ei(cx, cy)] if side == "n" else ew[ei(cx, cy)]
				if v in [E_DOOR, E_IDOOR, E_BREACH]:
					for c in ([Vector2i(cx, cy), Vector2i(cx, cy - 1)] if side == "n" else [Vector2i(cx, cy), Vector2i(cx - 1, cy)]):
						if cell_in(c.x, c.y):
							used[c.y * w + c.x] = 1
	for k in rooms.size():
		if rooms[k]["area"] == 0:
			continue
		if state != 0:
			_overgrow(k, used)
			if state == 2:
				continue
		var list: Array = ROOM_FURNITURE.get(rooms[k]["type"], [])
		for f in list:
			for n in int(f[3]):
				if _rng.randf() < (0.35 if state == 1 else 0.0):
					continue
				_place(k, String(f[0]), int(f[1]), int(f[2]), used)


## Pose un meuble contre un mur de la pièce k ; false s'il ne tient pas.
func _place(k: int, t: String, fw: int, fd: int, used: PackedByteArray) -> bool:
	var cells: PackedInt32Array = rooms[k]["cells"]
	if not _anchors.has(k):
		var an := [[], [], [], []]       # mur au nord, à l'ouest, à l'est, au sud
		for i in cells:
			var cx: int = i % w
			var cy: int = i / w
			if en[ei(cx, cy)] in [E_WALL, E_WINDOW]:
				an[0].append(Vector2i(cx, cy))
			if ew[ei(cx, cy)] == E_WALL:
				an[1].append(Vector2i(cx, cy))
			if ew[ei(cx + 1, cy)] == E_WALL:
				an[2].append(Vector2i(cx, cy))
			if en[ei(cx, cy + 1)] == E_WALL:
				an[3].append(Vector2i(cx, cy))
		_anchors[k] = an
	var an2: Array = _anchors[k]
	var tries := []
	for c in an2[0]:
		tries.append(Rect2i(c.x, c.y, fw, fd))
	for c in an2[1]:
		tries.append(Rect2i(c.x, c.y, fd, fw))
	for c in an2[2]:
		tries.append(Rect2i(c.x - fd + 1, c.y, fd, fw))
	if fd == 1 and fw <= 2:
		for c in an2[3]:
			tries.append(Rect2i(c.x, c.y, fw, fd))
	if tries.is_empty():
		return false
	var start := _rng.randi_range(0, tries.size() - 1)
	var check := cells.size() < 80          # grande pièce : on circule toujours
	for n in mini(tries.size(), 24):
		var r: Rect2i = tries[(start + n * 7) % tries.size()]
		if _fits(k, r, used):
			for cy in range(r.position.y, r.end.y):
				for cx in range(r.position.x, r.end.x):
					used[cy * w + cx] = 1
			if check and not _still_open(k, used):
				for cy in range(r.position.y, r.end.y):
					for cx in range(r.position.x, r.end.x):
						used[cy * w + cx] = 0
				continue
			furniture.append({"t": t, "x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y,
				"loot": LOOT.has(t), "room": rooms[k]["type"]})
			return true
	return false


func _fits(k: int, r: Rect2i, used: PackedByteArray) -> bool:
	for cy in range(r.position.y, r.end.y):
		for cx in range(r.position.x, r.end.x):
			if room_at(cx, cy) != k or used[cy * w + cx] == 1:
				return false
	return true


## Les cases libres de la pièce restent d'un seul tenant (on peut toujours circuler).
func _still_open(k: int, used: PackedByteArray) -> bool:
	var free := []
	for i in rooms[k]["cells"]:
		if used[i] == 0 or _is_door_cell(i):
			free.append(i)
	if free.is_empty():
		return false
	var seen := {free[0]: true}
	var stack := [free[0]]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var cx := i % w
		var cy := i / w
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var j: int = (cy + d.y) * w + cx + d.x
			if room_at(cx + d.x, cy + d.y) == k and not seen.has(j) and (used[j] == 0 or _is_door_cell(j)):
				seen[j] = true
				stack.append(j)
	return seen.size() == free.size()


func _is_door_cell(_i: int) -> bool:
	return false


## Toit effondré ou ruine : gravats, broussailles, jeunes arbres.
func _overgrow(k: int, used: PackedByteArray) -> void:
	for i in rooms[k]["cells"]:
		if used[i] == 1:
			continue
		var r := _rng.randf()
		var t := ""
		if r < 0.06:
			t = "gravats"
		elif r < 0.1:
			t = "broussailles"
		elif r < 0.115 and state == 2:
			t = "jeune_arbre"
		if t != "":
			used[i] = 1
			furniture.append({"t": t, "x": i % w, "y": i / w, "w": 1, "h": 1, "loot": false, "room": rooms[k]["type"]})


## Toit au-dessus de cette case ? (pas au-dessus des portes extérieures : une encoche les signale)
func roof_over(cx: int, cy: int) -> bool:
	if state != 0 or not cell_in(cx, cy):
		return false
	for e in [[cx, cy, "n"], [cx, cy + 1, "n"], [cx, cy, "w"], [cx + 1, cy, "w"]]:
		if _edge(e) == E_DOOR:
			return false
	return true
