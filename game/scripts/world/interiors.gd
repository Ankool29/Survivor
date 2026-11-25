class_name Interiors
extends RefCounted
## Bâtiments détaillés à l'écran (docs/BATIMENTS2.md) : sols, murs fins, portes,
## fenêtres, meubles et toits sur la grille fine (1 m = 16 px), murs abaissés
## quand on est dedans, collisions et portes qui s'ouvrent.

const F := 16                         ## pixels par case fine
const FINE := WorldGen.FINE
const WALL_TEX := "res://assets/interieur/murs.png"
const FLOOR_TEX := "res://assets/interieur/sols.png"
const ROOF_TEX := "res://assets/interieur/toits16.png"
const META := "res://assets/interieur/murs.json"
const FURN_DIR := "res://assets/meubles/"
const LOW_H := 5                      ## hauteur d'un mur abaissé

var world: ChunkManager
var floors: TileMapLayer
var roofs: TileMapLayer
var mods: WorldMods
var wall_h := 24
var _wall_tex: Texture2D
var _mats: Array = []
var _caps := {}
var _darks := {}
var _furn_tex := {}
var _chunks := {}                     ## morceau -> ChunkData
var _nodes := {}                      ## morceau -> [noeuds]
var _walls_by_plan := {}              ## id de bâtiment -> [WallNode]
var _lazy := {}                       ## id -> [descriptions des murs intérieurs et meubles] (sous un toit)
var _lazy_nodes := {}                 ## id -> [noeuds créés en entrant]
var _roof_by_plan := {}               ## id -> [cases fines]
var _furn := {}                       ## morceau -> [{node, plan, idx, rect}]
var _hidden_plan := -1                ## bâtiment dont le toit est masqué
var _low_plan := -1
var _low_y := 0.0


class WallNode extends Node2D:
	## Une rangée de murs horizontaux (bord nord des cases) ou un mur vertical d'un mètre.
	var owner_i: Interiors
	var vertical := false
	var fx := 0                       ## case fine de départ
	var fy := 0
	var codes := PackedByteArray()
	var mat := 0
	var plan_id := -1
	var low := false
	var end_face := false             ## vertical : face visible en bas (fin de mur)

	func _draw() -> void:
		var o := owner_i
		var H := o.wall_h
		var cap: Color = o._caps.get(mat, Color(0.4, 0.4, 0.4))
		var dark: Color = o._darks.get(mat, Color(0.3, 0.3, 0.3))
		var h := Interiors.LOW_H if low else H
		if not vertical:
			for j in codes.size():
				var code := codes[j]
				var x := j * Interiors.F
				var col := 0
				match code:
					BuildingPlan.E_WINDOW: col = 1
					BuildingPlan.E_DOOR, BuildingPlan.E_IDOOR:
						col = 3 if o.door_open(fx + j, fy, "n", code) else 2
					BuildingPlan.E_BREACH: col = 4
				var variant := ((fx + j) * 7 + fy * 3) & 1
				var src := Rect2((variant * 5 + col) * Interiors.F, mat * H + (H - h), Interiors.F, h)
				if code == BuildingPlan.E_BREACH and low:
					continue
				draw_texture_rect_region(o._wall_tex, Rect2(x, -h, Interiors.F, h), src)
				if code != BuildingPlan.E_BREACH and not (col == 3 and not low):
					draw_rect(Rect2(x, -h - 3, Interiors.F, 3), cap)
				elif col == 3:
					draw_rect(Rect2(x, -h - 3, Interiors.F, 3), cap.darkened(0.15))
			return
		# mur vertical : on voit surtout son dessus, et sa face au bout
		var code2 := codes[0]
		if code2 == BuildingPlan.E_BREACH:
			return
		var top := -Interiors.F - h
		match code2:
			BuildingPlan.E_DOOR, BuildingPlan.E_IDOOR:
				if o.door_open(fx, fy, "w", code2):
					draw_rect(Rect2(-2, top, 4, 3), cap)
					draw_rect(Rect2(-2, top + Interiors.F - 3, 4, 3), cap)
				else:
					draw_rect(Rect2(-2, top, 4, Interiors.F), Color(0.41, 0.28, 0.17))
			BuildingPlan.E_WINDOW:
				draw_rect(Rect2(-2, top, 4, Interiors.F), cap)
				draw_rect(Rect2(-1, top + 3, 2, Interiors.F - 6), Color(0.35, 0.45, 0.55))
			_:
				draw_rect(Rect2(-2, top, 4, Interiors.F), cap)
		if end_face:
			draw_rect(Rect2(-2, -h, 4, h), dark)


func setup(w: ChunkManager) -> void:
	world = w
	var meta: Dictionary = {}
	if FileAccess.file_exists(META):
		meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	wall_h = int(meta.get("wall_h", 24))
	_mats = meta.get("materials", ["enduit", "granit", "parpaing", "bois"])
	for i in _mats.size():
		var c: Array = meta.get("caps", {}).get(_mats[i], [110, 110, 110])
		var d: Array = meta.get("dark", {}).get(_mats[i], [80, 80, 80])
		_caps[i] = Color8(c[0], c[1], c[2])
		_darks[i] = Color8(d[0], d[1], d[2])
	_wall_tex = load(WALL_TEX)
	# sols
	floors = TileMapLayer.new()
	floors.name = "SolsInterieurs"
	floors.tile_set = _tileset(FLOOR_TEX, BuildingPlan.FLOORS.size())
	w.add_child(floors)
	w.move_child(floors, w.ground.get_index() + 1)
	# toits au mètre
	roofs = TileMapLayer.new()
	roofs.name = "ToitsFins"
	roofs.tile_set = _tileset(ROOF_TEX, 2)
	w.roof_root.add_child(roofs)


func _tileset(path: String, rows: int) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(F, F)
	var src := TileSetAtlasSource.new()
	src.texture = load(path)
	src.texture_region_size = Vector2i(F, F)
	for r in rows:
		for v in 4:
			src.create_tile(Vector2i(v, r))
	ts.add_source(src, 0)
	return ts


# --- Morceaux ---------------------------------------------------------------------------

func add_chunk(key: Vector2i, c: WorldGen.ChunkData) -> void:
	if c.fplan.is_empty():
		return
	_chunks[key] = c
	var nodes: Array = []
	var fx0 := key.x * FINE
	var fy0 := key.y * FINE
	# sols et toits
	for ly in FINE:
		for lx in FINE:
			var i := ly * FINE + lx
			var fl := c.ffloor[i]
			var cell := Vector2i(fx0 + lx, fy0 + ly)
			if fl > 0:
				floors.set_cell(cell, 0, Vector2i((cell.x * 3 + cell.y * 5) & 3, fl - 1))
			var pi := c.fplan[i]
			if pi >= 0:
				var p: BuildingPlan = c.plans[pi]
				if p.roof_over(cell.x - p.x, cell.y - p.y):
					if not _roof_by_plan.has(p.id):
						_roof_by_plan[p.id] = []
					_roof_by_plan[p.id].append(cell)
					if p.id != _hidden_plan:
						roofs.set_cell(cell, 0, Vector2i(((cell.x & 1) + (cell.y & 1) * 2), p.roof - 1))
	# murs horizontaux : rangées continues d'un même bâtiment
	for ly in FINE:
		var lx := 0
		while lx < FINE:
			var i := ly * FINE + lx
			var code := c.fedge[i] & 0x0F
			if code == 0:
				lx += 1
				continue
			var pi := c.feowner[i] & 0xFFFF
			var run := PackedByteArray()
			var start := lx
			var inner := _inner_edge(c, pi, fx0 + lx, fy0 + ly, "n")
			while lx < FINE and (c.fedge[ly * FINE + lx] & 0x0F) != 0 and (c.feowner[ly * FINE + lx] & 0xFFFF) == pi \
					and _inner_edge(c, pi, fx0 + lx, fy0 + ly, "n") == inner:
				run.append(c.fedge[ly * FINE + lx] & 0x0F)
				lx += 1
			var ph: BuildingPlan = c.plans[pi] if pi >= 0 and pi < c.plans.size() else null
			if inner and ph and ph.state == 0:
				_defer(ph.id, {"key": key, "k": "h", "p": ph, "fx": fx0 + start, "fy": fy0 + ly, "codes": run})
			else:
				nodes.append(_wall_node(ph, false, fx0 + start, fy0 + ly, run, false))
	# murs verticaux : un noeud par mètre (pour bien passer devant ou derrière le joueur)
	for ly in FINE:
		for lx in FINE:
			var i := ly * FINE + lx
			var code := (c.fedge[i] >> 4) & 0x0F
			if code == 0:
				continue
			var pi := (c.feowner[i] >> 16) & 0xFFFF
			var below := edge_code(fx0 + lx, fy0 + ly + 1, "w")
			var end := below == 0 or below == BuildingPlan.E_BREACH
			var pv: BuildingPlan = c.plans[pi] if pi >= 0 and pi < c.plans.size() else null
			if pv and pv.state == 0 and _inner_edge(c, pi, fx0 + lx, fy0 + ly, "w"):
				_defer(pv.id, {"key": key, "k": "v", "p": pv, "fx": fx0 + lx, "fy": fy0 + ly, "codes": PackedByteArray([code]), "end": end})
			else:
				nodes.append(_wall_node(pv, true, fx0 + lx, fy0 + ly, PackedByteArray([code]), end))
	# meubles : sous un toit intact, créés seulement quand on entre
	_furn[key] = []
	for e in c.furn:
		var p: BuildingPlan = c.plans[e[0]]
		if p.state == 0:
			_defer(p.id, {"key": key, "k": "f", "p": p, "idx": e[1]})
		else:
			nodes.append(_furniture_node(key, p, e[1]))
	_nodes[key] = nodes
	if _lazy_nodes.has(_hidden_plan):
		_materialize(_hidden_plan)
	_apply_low()


func _defer(pid: int, spec: Dictionary) -> void:
	if not _lazy.has(pid):
		_lazy[pid] = []
	_lazy[pid].append(spec)


func _furniture_node(key: Vector2i, p: BuildingPlan, idx: int) -> Sprite2D:
	var f: Dictionary = p.furniture[idx]
	var s := Sprite2D.new()
	var tex := _furniture_tex(String(f["t"]), int(f["w"]), int(f["h"]))
	s.texture = tex
	s.centered = false
	var r := Rect2((p.x + int(f["x"])) * F, (p.y + int(f["y"])) * F, int(f["w"]) * F, int(f["h"]) * F)
	s.position = Vector2(r.position.x, r.end.y)
	s.offset = Vector2((r.size.x - tex.get_width()) / 2.0, -tex.get_height())
	world.entities.add_child(s)
	if not _furn.has(key):
		_furn[key] = []
	_furn[key].append({"node": s, "plan": p, "idx": idx, "rect": r})
	return s


## Crée les murs intérieurs et les meubles d'un bâtiment (on vient d'y entrer).
func _materialize(pid: int) -> void:
	var made: Array = _lazy_nodes.get(pid, [])
	var done := {}
	for n in made:
		done[n.get_meta("spec")] = true
	for i in _lazy.get(pid, []).size():
		var spec: Dictionary = _lazy[pid][i]
		if done.has(spec):
			continue
		var n: Node2D
		match spec["k"]:
			"h":
				n = _wall_node(spec["p"], false, spec["fx"], spec["fy"], spec["codes"], false)
			"v":
				n = _wall_node(spec["p"], true, spec["fx"], spec["fy"], spec["codes"], spec["end"])
			"f":
				n = _furniture_node(spec["key"], spec["p"], spec["idx"])
		n.set_meta("spec", spec)
		made.append(n)
	_lazy_nodes[pid] = made


func _dematerialize(pid: int) -> void:
	for n in _lazy_nodes.get(pid, []):
		_forget(n)
		n.queue_free()
	_lazy_nodes.erase(pid)


func _forget(n: Node2D) -> void:
	if n is WallNode and _walls_by_plan.has(n.plan_id):
		_walls_by_plan[n.plan_id].erase(n)
	elif n is Sprite2D:
		for key in _furn:
			var lst: Array = _furn[key]
			for j in range(lst.size() - 1, -1, -1):
				if lst[j]["node"] == n:
					lst.remove_at(j)


func _wall_node(p: BuildingPlan, vertical: bool, fx: int, fy: int, codes: PackedByteArray, end: bool) -> WallNode:
	var n := WallNode.new()
	n.owner_i = self
	n.vertical = vertical
	n.fx = fx
	n.fy = fy
	n.codes = codes
	n.end_face = end
	n.mat = maxi(0, _mats.find(p.material)) if p else 0
	n.plan_id = p.id if p else -1
	n.position = Vector2(fx * F, (fy + 1) * F) if vertical else Vector2(fx * F, fy * F)
	world.entities.add_child(n)
	if not _walls_by_plan.has(n.plan_id):
		_walls_by_plan[n.plan_id] = []
	_walls_by_plan[n.plan_id].append(n)
	return n


## Mur entre deux cases du même bâtiment ?
func _inner_edge(c: WorldGen.ChunkData, pi: int, fx: int, fy: int, side: String) -> bool:
	if pi < 0 or pi >= c.plans.size():
		return false
	var p: BuildingPlan = c.plans[pi]
	var a := Vector2i(fx - p.x, fy - p.y)
	var b := a + (Vector2i(0, -1) if side == "n" else Vector2i(-1, 0))
	return p.cell_in(a.x, a.y) and p.cell_in(b.x, b.y)


func remove_chunk(key: Vector2i) -> void:
	var c: WorldGen.ChunkData = _chunks.get(key)
	if c == null:
		return
	var fx0 := key.x * FINE
	var fy0 := key.y * FINE
	for ly in FINE:
		for lx in FINE:
			var cell := Vector2i(fx0 + lx, fy0 + ly)
			floors.erase_cell(cell)
			roofs.erase_cell(cell)
	for p in c.plans:
		if _roof_by_plan.has(p.id):
			_roof_by_plan[p.id] = _roof_by_plan[p.id].filter(func(cell): return cell.x < fx0 or cell.y < fy0 or cell.x >= fx0 + FINE or cell.y >= fy0 + FINE)
	for n in _nodes.get(key, []):
		_forget(n)
		n.queue_free()
	# descriptions et noeuds différés de ce morceau
	for pid in _lazy.keys():
		_lazy[pid] = _lazy[pid].filter(func(sp): return sp["key"] != key)
		if _lazy_nodes.has(pid):
			var keep: Array = []
			for n in _lazy_nodes[pid]:
				if n.get_meta("spec")["key"] == key:
					_forget(n)
					n.queue_free()
				else:
					keep.append(n)
			_lazy_nodes[pid] = keep
		if _lazy[pid].is_empty():
			_lazy.erase(pid)
	_nodes.erase(key)
	_furn.erase(key)
	_chunks.erase(key)


func clear() -> void:
	for key in _chunks.keys():
		remove_chunk(key)
	_hidden_plan = -1
	_low_plan = -1
	_lazy.clear()
	_lazy_nodes.clear()


# --- Lecture de la grille fine -----------------------------------------------------------

func _chunk_of(fx: int, fy: int) -> WorldGen.ChunkData:
	return _chunks.get(Vector2i(floori(float(fx) / FINE), floori(float(fy) / FINE)))


## Code du bord nord ("n") ou ouest ("w") de la case fine (fx, fy).
func edge_code(fx: int, fy: int, side: String) -> int:
	var c := _chunk_of(fx, fy)
	if c == null:
		return 0
	var i := posmod(fy, FINE) * FINE + posmod(fx, FINE)
	return (c.fedge[i] & 0x0F) if side == "n" else ((c.fedge[i] >> 4) & 0x0F)


static func door_key(fx: int, fy: int, side: String) -> String:
	return "%d,%d,%s" % [fx, fy, side]


func door_open(fx: int, fy: int, side: String, code: int) -> bool:
	if mods == null:
		return code == BuildingPlan.E_IDOOR
	return bool(mods.doors.get(door_key(fx, fy, side), code == BuildingPlan.E_IDOOR))


func _blocks(fx: int, fy: int, side: String) -> bool:
	var code := edge_code(fx, fy, side)
	match code:
		BuildingPlan.E_WALL, BuildingPlan.E_WINDOW:
			return true
		BuildingPlan.E_DOOR, BuildingPlan.E_IDOOR:
			return not door_open(fx, fy, side, code)
	return false


## Vrai si aller de a à b (en pixels, petit pas) traverse un mur, une fenêtre ou une porte fermée.
func move_blocked(a: Vector2, b: Vector2, furniture := true) -> bool:
	var fa := Vector2i(floori(a.x / F), floori(a.y / F))
	var fb := Vector2i(floori(b.x / F), floori(b.y / F))
	if fa == fb:
		return false
	# meubles : on ne marche pas dessus
	var cb := _chunk_of(fb.x, fb.y)
	if furniture and cb and cb.fblock.size() > 0 and cb.fblock[posmod(fb.y, FINE) * FINE + posmod(fb.x, FINE)] == 1:
		var ca := _chunk_of(fa.x, fa.y)
		if not (ca and ca.fblock[posmod(fa.y, FINE) * FINE + posmod(fa.x, FINE)] == 1):
			return true
	if fa.x != fb.x and _blocks(maxi(fa.x, fb.x), fa.y, "w"):
		return true
	if fa.y != fb.y and _blocks(fb.x, maxi(fa.y, fb.y), "n"):
		return true
	if fa.x != fb.x and fa.y != fb.y and _blocks(maxi(fa.x, fb.x), fb.y, "w"):
		return true
	return false


## [bâtiment, pièce] sous ce point, ou [] dehors.
func plan_at(p: Vector2) -> Array:
	var fx := floori(p.x / F)
	var fy := floori(p.y / F)
	var c := _chunk_of(fx, fy)
	if c == null:
		return []
	var i := posmod(fy, FINE) * FINE + posmod(fx, FINE)
	var pi := c.fplan[i]
	if pi < 0:
		return []
	return [c.plans[pi], c.froom[i]]


## Porte juste devant (à moins d'un pas) : {fx, fy, side, code, open} ou {}.
func door_ahead(pos: Vector2, facing: Vector2) -> Dictionary:
	for dist in [10.0, 18.0]:
		var a := pos + Vector2(0, -4)
		var b: Vector2 = a + facing.normalized() * dist
		var fa := Vector2i(floori(a.x / F), floori(a.y / F))
		var fb := Vector2i(floori(b.x / F), floori(b.y / F))
		var cand: Array = []
		if fa.x != fb.x:
			cand.append([maxi(fa.x, fb.x), fa.y, "w"])
		if fa.y != fb.y:
			cand.append([fa.x, maxi(fa.y, fb.y), "n"])
		for e in cand:
			var code := edge_code(e[0], e[1], e[2])
			if code == BuildingPlan.E_DOOR or code == BuildingPlan.E_IDOOR:
				return {"fx": e[0], "fy": e[1], "side": e[2], "code": code, "open": door_open(e[0], e[1], e[2], code)}
	return {}


func toggle_door(d: Dictionary) -> void:
	mods.doors[door_key(d["fx"], d["fy"], d["side"])] = not bool(d["open"])
	for key in _nodes:
		for n in _nodes[key]:
			if n is WallNode:
				var hit: bool = (n.vertical and d["side"] == "w" and n.fx == d["fx"] and n.fy == d["fy"]) or \
					(not n.vertical and d["side"] == "n" and n.fy == d["fy"] and d["fx"] >= n.fx and d["fx"] < n.fx + n.codes.size())
				if hit:
					n.queue_redraw()


## Meuble le plus proche devant le joueur : {plan, idx, f, rect} ou {}.
func furniture_ahead(pos: Vector2, facing: Vector2, only_loot := true) -> Dictionary:
	var probe := pos + Vector2(0, -4) + facing.normalized() * 12.0
	var best := {}
	var bd := 14.0
	for key in _furn:
		for e in _furn[key]:
			if only_loot and not (e["plan"] as BuildingPlan).furniture[e["idx"]]["loot"]:
				continue
			var r: Rect2 = e["rect"]
			var q := Vector2(clampf(probe.x, r.position.x, r.end.x), clampf(probe.y, r.position.y, r.end.y))
			var d := q.distance_to(probe)
			if d < bd and not move_blocked(pos + Vector2(0, -2), q.move_toward(pos, 1.0), false):
				bd = d
				var p: BuildingPlan = e["plan"]
				best = {"plan": p, "idx": e["idx"], "f": p.furniture[e["idx"]], "rect": r}
	return best


# --- Toit masqué et murs abaissés quand on est dedans ----------------------------------------

func set_inside(plan_id: int, player_y: float) -> void:
	if plan_id != _hidden_plan:
		if _hidden_plan >= 0:
			_restore_roof(_hidden_plan)
			_dematerialize(_hidden_plan)
		_hidden_plan = plan_id
		if plan_id >= 0:
			for cell in _roof_by_plan.get(plan_id, []):
				roofs.erase_cell(cell)
			_materialize(plan_id)
	if plan_id != _low_plan or absf(player_y - _low_y) > 4.0:
		var old := _low_plan
		_low_plan = plan_id
		_low_y = player_y
		if old >= 0 and old != plan_id:
			for n in _walls_by_plan.get(old, []):
				if n.low:
					n.low = false
					n.queue_redraw()
		_apply_low()


func _apply_low() -> void:
	if _low_plan < 0:
		return
	for n in _walls_by_plan.get(_low_plan, []):
		var want: bool = n.position.y > _low_y - 2.0
		if n.low != want:
			n.low = want
			n.queue_redraw()


func _restore_roof(plan_id: int) -> void:
	for key in _chunks:
		var c: WorldGen.ChunkData = _chunks[key]
		for p in c.plans:
			if p.id == plan_id:
				for cell in _roof_by_plan.get(plan_id, []):
					roofs.set_cell(cell, 0, Vector2i(((cell.x & 1) + (cell.y & 1) * 2), p.roof - 1))
				return


# --- Textures des meubles ---------------------------------------------------------------------

const FURN_COLORS := {
	"lit": Color8(150, 110, 90), "armoire": Color8(110, 78, 52), "commode": Color8(120, 86, 58),
	"canape": Color8(96, 104, 120), "buffet": Color8(112, 80, 54), "table": Color8(130, 96, 64),
	"table_basse": Color8(124, 90, 60), "poele": Color8(60, 60, 64), "cheminee": Color8(120, 116, 110),
	"evier": Color8(180, 182, 184), "cuisiniere": Color8(200, 198, 190), "frigo": Color8(214, 214, 208),
	"placard": Color8(150, 120, 86), "baignoire": Color8(220, 222, 220), "lavabo": Color8(210, 212, 210),
	"wc": Color8(226, 226, 222), "meuble_sdb": Color8(190, 190, 186), "etabli": Color8(118, 92, 60),
	"etageres": Color8(100, 90, 80), "cartons": Color8(164, 132, 90), "palette": Color8(150, 124, 86),
	"bureau": Color8(116, 86, 60), "armoire_bureau": Color8(130, 130, 126), "comptoir": Color8(120, 100, 80),
	"rayonnage": Color8(150, 150, 146), "foin": Color8(196, 170, 96), "auge": Color8(110, 106, 100),
	"banc": Color8(104, 76, 50), "autel": Color8(200, 196, 186), "pupitre": Color8(130, 100, 70),
	"etagere_livres": Color8(110, 80, 56), "meuble_entree": Color8(120, 90, 62), "boites_lettres": Color8(150, 150, 140),
	"gravats": Color8(120, 114, 106), "broussailles": Color8(70, 96, 52), "jeune_arbre": Color8(60, 100, 50),
}
const FURN_HEIGHT := {"armoire": 22, "frigo": 20, "etageres": 18, "rayonnage": 16, "armoire_bureau": 18,
	"etagere_livres": 20, "placard": 10, "cheminee": 18, "buffet": 10, "foin": 12, "jeune_arbre": 30}


func _furniture_tex(t: String, fw: int, fh: int) -> Texture2D:
	var k := "%s_%d_%d" % [t, fw, fh]
	if _furn_tex.has(k):
		return _furn_tex[k]
	var tex: Texture2D = null
	var path := FURN_DIR + t + ".png"
	if ResourceLoader.exists(path):
		tex = load(path)
		if fw < fh:
			# posé contre un mur latéral : on tourne l'image d'un quart de tour
			var img := tex.get_image()
			img.rotate_90(CLOCKWISE if (hash(t) & 1) == 0 else COUNTERCLOCKWISE)
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		tex = _placeholder(t, fw, fh)
	_furn_tex[k] = tex
	return tex


## Meuble provisoire (en attendant les sprites) : un bloc avec dessus et face.
func _placeholder(t: String, fw: int, fh: int) -> Texture2D:
	var c: Color = FURN_COLORS.get(t, Color8(120, 100, 80))
	var w := fw * F - 2
	var depth := fh * F - 4
	var hgt: int = FURN_HEIGHT.get(t, 8)
	var img := Image.create(w, depth + hgt, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(0, 0, w, depth), c.lightened(0.15))
	img.fill_rect(Rect2i(0, depth, w, hgt), c.darkened(0.2))
	for x in w:
		img.set_pixel(x, 0, c.darkened(0.45))
		img.set_pixel(x, depth + hgt - 1, c.darkened(0.5))
	for y in depth + hgt:
		img.set_pixel(0, y, c.darkened(0.45))
		img.set_pixel(w - 1, y, c.darkened(0.45))
	return ImageTexture.create_from_image(img)
