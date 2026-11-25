class_name WorldGen
extends RefCounted
## Fabrique le contenu d'un morceau (32 x 32 cases) à partir des données de zone.
## Toujours le même résultat pour une même graine : rien n'est stocké tant que
## le joueur ne modifie rien.

const CHUNK := 32

# Drapeaux de déplacement par case
const F_BLOCK := 1    # infranchissable (mer, eau profonde, mur, épave)
const F_TRUNK := 2    # petit obstacle au pied de la case (tronc, rocher, tombe)
const F_SLOW := 4     # ralentit (marais, ronces, gué)
const F_INDOOR := 8   # intérieur de bâtiment
const F_ROOF := 16    # sous un toit intact (à l'abri de la pluie)

const POI_SIZE := {
	"hopital": Vector2i(14, 10), "supermarche": Vector2i(13, 10), "eglise": Vector2i(7, 11),
	"gare": Vector2i(12, 6), "mairie": Vector2i(9, 7), "ecole": Vector2i(11, 8),
	"pharmacie": Vector2i(5, 4), "epicerie": Vector2i(5, 4), "quincaillerie": Vector2i(8, 6),
	"garage": Vector2i(7, 6), "station_service": Vector2i(6, 5), "bibliotheque": Vector2i(7, 6),
	"gendarmerie": Vector2i(8, 7), "pompiers": Vector2i(8, 6), "entrepot": Vector2i(12, 9),
	"magasin": Vector2i(9, 7), "grand_batiment": Vector2i(9, 7), "ferme": Vector2i(8, 6),
	"chateau": Vector2i(12, 10), "musee": Vector2i(8, 6), "marche": Vector2i(8, 6),
}

var zone: ZoneData
var seed_value := 1
## Densité du décor : 1 à l'échelle compressée ; plus faible à l'échelle réelle,
## où une case ne fait que 2 m (sinon un arbre toutes les deux cases).
var deco_k := 1.0
var bridge_shift := 3
var shade_k := 0.035
var _pois_by_chunk := {}


class ChunkData:
	var cx := 0
	var cy := 0
	var ground := PackedInt32Array()   # Tiles.G_* * 4 + variante
	var decor := PackedInt32Array()    # Tiles.D_* ou -1
	var flags := PackedByteArray()
	var shade: Image
	## Type de sol (Tiles.G_*) des cases x0-1..x0+31 / y0-1..y0+31, avant les
	## bâtiments : sert aux transitions de la grille double. Index (ly+1)*33+(lx+1).
	var kinds := PackedByteArray()
	var dual: Array = []               ## tuiles de transition précalculées (ChunkManager)
	var roof: Array = []               ## tuiles de toit précalculées, par type de toit
	var buildings: Array = []          # {rect: Rect2i (cases monde), kind: String, name: String}
	## Bâtiments détaillés (grille fine : 1 case = 2 x 2), FINE x FINE à partir de (2*x0, 2*y0)
	var plans: Array = []              ## BuildingPlan qui touchent ce morceau
	var fplan := PackedInt32Array()    ## index dans plans, -1 dehors
	var froom := PackedInt32Array()    ## pièce dans le plan
	var ffloor := PackedByteArray()    ## sol + 1 (0 : aucun)
	var fedge := PackedByteArray()     ## bord nord (bits 0-3) et ouest (bits 4-7) de la case fine
	var feowner := PackedInt32Array()  ## plan du bord nord (bits 0-15) et ouest (16-31), 0xFFFF aucun
	var furn: Array = []               ## [plan index, meuble index] dont l'origine est ici


func _init(z: ZoneData, s: int) -> void:
	zone = z
	seed_value = s
	if zone.real:
		deco_k = 0.22
		bridge_shift = 5
		shade_k = 0.12
	for p in zone.pois:
		var key := Vector2i(int(p["x"]) / CHUNK, int(p["y"]) / CHUNK)
		if not _pois_by_chunk.has(key):
			_pois_by_chunk[key] = []
		_pois_by_chunk[key].append(p)


## Entier pseudo-aléatoire stable (31 bits) pour une case.
func hash_cell(x: int, y: int) -> int:
	var n: int = x * 374761393 + y * 668265263 + seed_value * 982451653
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return n & 0x7FFFFFFF


## Nombre pseudo-aléatoire stable dans [0, 1) pour une case et un usage.
func rnd(x: int, y: int, salt: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + (seed_value + salt * 7919) * 982451653
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFFFF) / 16777216.0


## Bruit doux dans [0, 1) : taches de quelques cases au lieu d'un damier.
func patch(x: int, y: int, scale: int, salt: int) -> float:
	var fx := x / float(scale)
	var fy := y / float(scale)
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := lerpf(rnd(ix, iy, salt), rnd(ix + 1, iy, salt), tx)
	var b := lerpf(rnd(ix, iy + 1, salt), rnd(ix + 1, iy + 1, salt), tx)
	return lerpf(a, b, ty)


## Taches de 5 cases, précalculées pour le morceau (bien plus rapide que patch()).
var _p5 := PackedFloat32Array()
var _p5_x := 0
var _p5_y := 0


func _prepare_patch5(x0: int, y0: int) -> void:
	_p5_x = floori((x0 - 1) / 5.0)
	_p5_y = floori((y0 - 1) / 5.0)
	_p5.resize(10 * 10)
	for j in 10:
		for i in 10:
			_p5[j * 10 + i] = rnd(_p5_x + i, _p5_y + j, 2)


func _patch5(x: int, y: int) -> float:
	var fx := x / 5.0 - _p5_x
	var fy := y / 5.0 - _p5_y
	var ix := int(fx)
	var iy := int(fy)
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var k := iy * 10 + ix
	return lerpf(lerpf(_p5[k], _p5[k + 1], tx), lerpf(_p5[k + 10], _p5[k + 11], tx), ty)


func generate(cx: int, cy: int) -> ChunkData:
	var c := ChunkData.new()
	c.cx = cx
	c.cy = cy
	var n := CHUNK * CHUNK
	c.ground.resize(n)
	c.decor.resize(n)
	c.decor.fill(-1)
	c.flags.resize(n)
	var x0 := cx * CHUNK
	var y0 := cy * CHUNK
	_prepare_patch5(x0, y0)
	if zone.detailed:
		_fine(c, x0, y0)
	# 1. sol, voies, eau
	for ly in CHUNK:
		for lx in CHUNK:
			_cell(c, lx, ly, x0 + lx, y0 + ly)
	# 1 bis. types de sol, bordure ouest et nord comprise (même calcul que _cell)
	const K := CHUNK + 1
	c.kinds.resize(K * K)
	var scratch := ChunkData.new()
	scratch.ground.resize(1)
	scratch.decor.resize(1)
	scratch.flags.resize(1)
	for ly in range(-1, CHUNK):
		for lx in range(-1, CHUNK):
			var g: int
			if lx >= 0 and ly >= 0:
				g = c.ground[ly * CHUNK + lx] / Tiles.VARIANTS
			else:
				scratch.flags[0] = 0
				_cell(scratch, 0, 0, x0 + lx, y0 + ly)
				g = scratch.ground[0] / Tiles.VARIANTS
			c.kinds[(ly + 1) * K + lx + 1] = g
	# 2. bâtiments (contenus dans le morceau, à une case des bords)
	_place_buildings(c, x0, y0)
	for b in ([] if zone.real else c.buildings):
		var r: Rect2i = b["rect"]
		for wy in range(r.position.y, r.end.y):
			for wx in range(r.position.x, r.end.x):
				var lx := wx - x0
				var ly := wy - y0
				c.kinds[(ly + 1) * K + lx + 1] = c.ground[ly * CHUNK + lx] / Tiles.VARIANTS
	# 3. ombrage du relief (1 case de marge pour un raccord sans couture)
	c.shade = _shade(x0, y0)
	return c


const FINE := CHUNK * 2


## Bâtiments détaillés de ce morceau : sols, murs, pièces sur la grille fine.
func _fine(c: ChunkData, x0: int, y0: int) -> void:
	var fx0 := x0 * 2
	var fy0 := y0 * 2
	var n := FINE * FINE
	c.fplan.resize(n)
	c.fplan.fill(-1)
	c.froom.resize(n)
	c.ffloor.resize(n)
	c.fedge.resize(n)
	c.feowner.resize(n)
	c.feowner.fill(-1)
	var rect := Rect2i(fx0, fy0, FINE, FINE)
	for rec in zone.buildings_in(rect):
		var p := BuildingPlan.of(rec)
		var pi := c.plans.size()
		c.plans.append(p)
		var a := Vector2i(maxi(p.x, fx0), maxi(p.y, fy0))
		var b := Vector2i(mini(p.x + p.w + 1, fx0 + FINE), mini(p.y + p.h + 1, fy0 + FINE))
		for fy in range(a.y, b.y):
			for fx in range(a.x, b.x):
				var lx := fx - fx0
				var ly := fy - fy0
				var i := ly * FINE + lx
				var px := fx - p.x
				var py := fy - p.y
				if px < p.w and py < p.h and p.inside[py * p.w + px] == 1:
					var r := p.room[py * p.w + px]
					c.fplan[i] = pi
					c.froom[i] = r
					if r >= 0:
						c.ffloor[i] = int(p.rooms[r]["floor"]) + 1
				var e := c.fedge[i]
				var own := c.feowner[i]
				if px < p.w:
					var vn := p.en[p.ei(px, py)]
					if vn != 0:
						e = (e & 0xF0) | vn
						own = (own & ~0xFFFF) | pi
				if py < p.h:
					var vw := p.ew[p.ei(px, py)]
					if vw != 0:
						e = (e & 0x0F) | (vw << 4)
						own = (own & 0xFFFF) | (pi << 16)
				c.fedge[i] = e
				c.feowner[i] = own
		for k in p.furniture.size():
			var f: Dictionary = p.furniture[k]
			var fx: int = p.x + int(f["x"])
			var fy: int = p.y + int(f["y"])
			if rect.has_point(Vector2i(fx, fy)):
				c.furn.append([pi, k])


func _put(c: ChunkData, lx: int, ly: int, g: int, variant: int) -> void:
	c.ground[ly * CHUNK + lx] = g * Tiles.VARIANTS + (variant % Tiles.VARIANTS)


func _deco(c: ChunkData, lx: int, ly: int, d: int, flag := 0) -> void:
	var i := ly * CHUNK + lx
	c.decor[i] = d
	c.flags[i] |= flag


func _cell(c: ChunkData, lx: int, ly: int, x: int, y: int) -> void:
	_cell_base(c, lx, ly, x, y)
	if not zone.real:
		return
	# Échelle réelle : vrais bâtiments d'OpenStreetMap
	var b := zone.bb_at(x, y)
	var i := ly * CHUNK + lx
	if zone.detailed:
		# bâtiments détaillés : murs et meubles sur la grille fine ; ici, pas de grand décor
		# sur une case touchée par un bâtiment
		var touched := b != 0
		if c.fplan.size() > 0:
			var k0 := (ly * 2) * FINE + lx * 2
			for k in [k0, k0 + 1, k0 + FINE, k0 + FINE + 1]:
				if c.fplan[k] >= 0 or c.fedge[k] != 0:
					touched = true
		if touched:
			c.decor[i] = -1
			c.flags[i] = 0
			return
		# lierre et herbes au pied des façades
		if zone.bb_at(x, y - 1) != 0 and zone.r_at(x, y) == 0 and not zone.is_water(x, y) and (hash_cell(x, y) >> 5) % 100 < 22:
			c.decor[i] = -1
			_deco(c, lx, ly, Tiles.D_LIERRE)
		return
	if b == 0:
		# devant une porte : un seuil de pierre puis un bout de chemin, pour la repérer
		if zone.r_at(x, y) == 0 and not zone.is_water(x, y):
			var step := _door_step(x, y)
			if step > 0:
				_put(c, lx, ly, Tiles.G_BETON if step == 1 else Tiles.G_CHEMIN, hash_cell(x, y) & 3)
				c.decor[i] = -1
				c.flags[i] = 0
				return
		# lierre et herbes au pied des façades (sous un mur, dehors)
		if c.decor[i] < 0 and zone.bb_at(x, y - 1) == 2 and zone.r_at(x, y) == 0 and not zone.is_water(x, y):
			if (hash_cell(x, y) >> 5) % 100 < 22:
				_deco(c, lx, ly, Tiles.D_LIERRE)
		return
	var h := hash_cell(x, y)
	var state := zone.state_at(x, y)
	c.decor[i] = -1
	c.flags[i] = 0
	if b == 2:
		_put(c, lx, ly, Tiles.G_MUR, h & 3)
		_deco(c, lx, ly, Tiles.D_MUR, F_BLOCK)
		return
	# sol (4 = porte : une ouverture dans le mur)
	_put(c, lx, ly, Tiles.G_CARRELAGE if b == 3 else Tiles.G_SOL_BATIMENT, h & 3)
	var roofed := F_ROOF if state == 0 else 0
	if b == 4:
		c.flags[i] = F_INDOOR | roofed
		return
	c.flags[i] = F_INDOOR | roofed
	var a := float((h >> 10) & 0xFFFF) / 65536.0
	if state != 0:
		# toit effondré ou ruine : gravats, herbes, jeunes arbres
		if a < 0.08:
			_deco(c, lx, ly, Tiles.D_GRAVATS)
		elif a < 0.13:
			_deco(c, lx, ly, Tiles.D_BUISSON)
		elif a < 0.15:
			_deco(c, lx, ly, Tiles.D_JEUNE_ARBRE, F_TRUNK)
		return
	# meubles contre les murs, à fouiller
	# meubles contre un mur latéral ou le mur du bas, jamais sous la face d'un mur du haut
	# ni devant une porte
	var by_wall := zone.bb_at(x + 1, y) == 2 or zone.bb_at(x - 1, y) == 2 or zone.bb_at(x, y + 1) == 2
	var blocked := zone.bb_at(x, y - 1) == 2 or _near_door(x, y)
	if by_wall and not blocked and a < 0.06:
		_deco(c, lx, ly, _furniture(x, y, b), F_TRUNK)
	elif a < 0.02:
		_deco(c, lx, ly, Tiles.D_GRAVATS)
	elif a < 0.028:
		_deco(c, lx, ly, Tiles.D_BUISSON)


## 1 si la case touche une porte, 2 si elle est à deux cases dans l'axe, 0 sinon.
func _door_step(x: int, y: int) -> int:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if zone.bb_at(x + d.x, y + d.y) == 4:
			return 1
		if zone.bb_at(x + 2 * d.x, y + 2 * d.y) == 4 and zone.bb_at(x + d.x, y + d.y) == 0:
			return 2
	return 0


func _near_door(x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if zone.bb_at(x + dx, y + dy) == 4:
				return true
	return false


## Meuble selon le type du bâtiment (lieu notable le plus proche, ou zone industrielle).
func _furniture(x: int, y: int, b: int) -> int:
	if b == 3:
		var best := ""
		var bd := 40.0 * 40.0
		for p in _pois_by_chunk.get(Vector2i(x / CHUNK, y / CHUNK), []):
			var d2 := Vector2(float(p["x"]) - x, float(p["y"]) - y).length_squared()
			if d2 < bd:
				bd = d2
				best = p["kind"]
		match best:
			"supermarche", "epicerie", "magasin", "marche": return Tiles.D_RAYON
			"pharmacie", "hopital": return Tiles.D_PHARMA
			"garage", "station_service", "quincaillerie", "entrepot", "pompiers": return Tiles.D_ETABLI
			"ferme": return Tiles.D_FOIN
	if zone.t_at(x, y) == ZoneData.T_INDUSTRIEL:
		return Tiles.D_ETABLI
	return Tiles.D_MEUBLE


func _cell_base(c: ChunkData, lx: int, ly: int, x: int, y: int) -> void:
	var i := ly * CHUNK + lx
	var h := hash_cell(x, y)
	var v := h & 3
	if not zone.inside(x, y):
		_put(c, lx, ly, Tiles.G_MER, v)
		c.flags[i] = F_BLOCK
		return
	var t: int = zone.t_at(x, y)
	var road: int = zone.r_at(x, y)
	var r2 := _patch5(x, y) * 0.8 + float((h >> 2) & 0xFF) / 1280.0
	var water := t == ZoneData.T_MER or t == ZoneData.T_EAU
	if road != ZoneData.R_AUCUNE:
		if water:
			# Pont : un sur quatre s'est effondré en 30 ans
			if rnd(x >> bridge_shift, y >> bridge_shift, 3) < 0.25:
				_water(c, lx, ly, x, y, t, v)
			else:
				_put(c, lx, ly, Tiles.G_RAIL if road == ZoneData.R_RAIL else Tiles.G_PONT, v)
			return
		match road:
			ZoneData.R_VOIE_RAPIDE, ZoneData.R_PRINCIPALE:
				_put(c, lx, ly, Tiles.G_ASPHALTE_ENVAHI if r2 < 0.3 else Tiles.G_ASPHALTE, v)
				if rnd(x, y, 4) / deco_k < 0.025:
					_deco(c, lx, ly, Tiles.D_EPAVE, F_BLOCK)
				elif rnd(x, y, 5) / deco_k < 0.02:
					_deco(c, lx, ly, Tiles.D_BUISSON)
			ZoneData.R_SECONDAIRE, ZoneData.R_RUE:
				_put(c, lx, ly, Tiles.G_ASPHALTE_ENVAHI if r2 < 0.45 else Tiles.G_ROUTE, v)
				var e := rnd(x, y, 4) / deco_k
				if e < 0.008:
					_deco(c, lx, ly, Tiles.D_EPAVE, F_BLOCK)
				elif e < 0.05:
					_deco(c, lx, ly, Tiles.D_BUISSON)
				elif e < 0.06:
					_deco(c, lx, ly, Tiles.D_JEUNE_ARBRE, F_TRUNK)
			ZoneData.R_CHEMIN:
				_put(c, lx, ly, Tiles.G_CHEMIN if r2 < 0.6 else Tiles.G_FRICHE, v)
				if rnd(x, y, 4) / deco_k < 0.03:
					_deco(c, lx, ly, Tiles.D_ROCHER)   # cailloux du chemin
			ZoneData.R_RAIL:
				_put(c, lx, ly, Tiles.G_RAIL, v)
				if rnd(x, y, 4) / deco_k < 0.04:
					_deco(c, lx, ly, Tiles.D_BUISSON)
		return
	if water:
		_water(c, lx, ly, x, y, t, v)
		return
	var a := float((h >> 10) & 0xFFFF) / 65536.0 / deco_k
	match t:
		ZoneData.T_SABLE:
			_put(c, lx, ly, Tiles.G_SABLE, v)
			if a < 0.02:
				_deco(c, lx, ly, Tiles.D_ROCHER, F_TRUNK)
		ZoneData.T_PRAIRIE:
			_put(c, lx, ly, Tiles.G_HERBE_HAUTE, v)
			_wild(c, lx, ly, a, 0.06, 0.03, 0.03)
		ZoneData.T_CHAMP:
			# 30 ans sans culture : friche, ronces, jeunes arbres
			_put(c, lx, ly, Tiles.G_FRICHE if r2 < 0.32 else Tiles.G_HERBE_HAUTE, v)
			_wild(c, lx, ly, a, 0.10, 0.07, 0.06)
			if a >= 0.23 and a < 0.26:
				_deco(c, lx, ly, Tiles.D_ROCHER, F_TRUNK)   # pierres remontées par les labours
		ZoneData.T_FEUILLUS, ZoneData.T_MIXTE, ZoneData.T_RESINEUX:
			var conifer := t == ZoneData.T_RESINEUX or (t == ZoneData.T_MIXTE and patch(x, y, 9, 7) < 0.45)
			_put(c, lx, ly, Tiles.G_SOL_RESINEUX if conifer else Tiles.G_SOL_FEUILLUS, v)
			if a < 0.40:
				var d := Tiles.D_RESINEUX_A if conifer else Tiles.D_FEUILLU_A
				if rnd(x, y, 8) < 0.5:
					d += 1
				_deco(c, lx, ly, d, F_TRUNK)
			elif a < 0.42:
				_deco(c, lx, ly, Tiles.D_ARBRE_MORT, F_TRUNK)
			elif a < 0.44:
				_deco(c, lx, ly, Tiles.D_SOUCHE, F_TRUNK)
			elif a < 0.53:
				_deco(c, lx, ly, Tiles.D_BUISSON)
			elif a < 0.57:
				_deco(c, lx, ly, Tiles.D_RONCES, F_SLOW)
			elif a < 0.6:
				_deco(c, lx, ly, Tiles.D_ROCHER, F_TRUNK)
		ZoneData.T_LANDE:
			_put(c, lx, ly, Tiles.G_LANDE, v)
			if a < 0.18:
				_deco(c, lx, ly, Tiles.D_AJONC, F_SLOW)
			elif a < 0.21:
				_deco(c, lx, ly, Tiles.D_ROCHER, F_TRUNK)
			elif a < 0.24:
				_deco(c, lx, ly, Tiles.D_JEUNE_ARBRE, F_TRUNK)
		ZoneData.T_MARAIS:
			_put(c, lx, ly, Tiles.G_MARAIS, v)
			c.flags[i] |= F_SLOW
			if a < 0.25:
				_deco(c, lx, ly, Tiles.D_ROSEAUX)
			elif a < 0.28:
				_deco(c, lx, ly, Tiles.D_SAULE, F_TRUNK)
		ZoneData.T_URBAIN:
			# Jardins et trottoirs envahis
			_put(c, lx, ly, Tiles.G_BETON if r2 < 0.35 else Tiles.G_HERBE_HAUTE, v)
			_wild(c, lx, ly, a, 0.07, 0.02, 0.05)
		ZoneData.T_INDUSTRIEL:
			_put(c, lx, ly, Tiles.G_BETON_INDUS if r2 < 0.75 else Tiles.G_FRICHE, v)
			if a < 0.04:
				_deco(c, lx, ly, Tiles.D_GRAVATS)
			elif a < 0.09:
				_deco(c, lx, ly, Tiles.D_BUISSON)
			elif a < 0.1:
				_deco(c, lx, ly, Tiles.D_EPAVE, F_BLOCK)
		ZoneData.T_ROCHE:
			_put(c, lx, ly, Tiles.G_ROCHE, v)
			if a < 0.15:
				_deco(c, lx, ly, Tiles.D_ROCHER, F_TRUNK)
		ZoneData.T_CIMETIERE:
			_put(c, lx, ly, Tiles.G_HERBE_HAUTE, v)
			if (x + y) % 2 == 0 and a < 0.7:
				_deco(c, lx, ly, Tiles.D_TOMBE, F_TRUNK)
		ZoneData.T_PARC:
			_put(c, lx, ly, Tiles.G_HERBE_HAUTE, v)
			if a < 0.22:
				_deco(c, lx, ly, Tiles.D_FEUILLU_A + int(rnd(x, y, 8) * 2), F_TRUNK)
			else:
				_wild(c, lx, ly, a - 0.22, 0.06, 0.02, 0.02)
		_:
			_put(c, lx, ly, Tiles.G_FRICHE, v)


func _wild(c: ChunkData, lx: int, ly: int, a: float, bush: float, brambles: float, young: float) -> void:
	if a < bush:
		_deco(c, lx, ly, Tiles.D_BUISSON)
	elif a < bush + brambles:
		_deco(c, lx, ly, Tiles.D_RONCES, F_SLOW)
	elif a < bush + brambles + young:
		_deco(c, lx, ly, Tiles.D_JEUNE_ARBRE, F_TRUNK)


func _water(c: ChunkData, lx: int, ly: int, x: int, y: int, t: int, v: int) -> void:
	var i := ly * CHUNK + lx
	if t == ZoneData.T_MER:
		_put(c, lx, ly, Tiles.G_MER, v)
		c.flags[i] |= F_BLOCK
		return
	_put(c, lx, ly, Tiles.G_EAU, v)
	# Eau profonde si large, gué si c'est un ruisseau d'une case
	var wet := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if zone.is_water(x + dx, y + dy):
				wet += 1
	c.flags[i] |= F_BLOCK if wet >= 6 else F_SLOW


func _free(c: ChunkData, r: Rect2i, margin: int, occupied: PackedByteArray) -> bool:
	if r.position.x < 1 or r.position.y < 1 or r.end.x > CHUNK - 1 or r.end.y > CHUNK - 1:
		return false
	for ly in range(r.position.y - margin, r.end.y + margin):
		for lx in range(r.position.x - margin, r.end.x + margin):
			if lx < 0 or ly < 0 or lx >= CHUNK or ly >= CHUNK:
				continue
			var i := ly * CHUNK + lx
			if occupied[i]:
				return false
			var inner := r.has_point(Vector2i(lx, ly))
			if inner and (c.flags[i] & F_BLOCK or zone.r_at(c.cx * CHUNK + lx, c.cy * CHUNK + ly) != 0):
				return false
	return true


func _place_buildings(c: ChunkData, x0: int, y0: int) -> void:
	if zone.real:
		# Bâtiments réels : on ne garde que les étiquettes des lieux notables
		for p in _pois_by_chunk.get(Vector2i(c.cx, c.cy), []):
			var pc := Vector2i(int(p["x"]), int(p["y"]))
			c.buildings.append({"rect": Rect2i(pc - Vector2i(6, 6), Vector2i(13, 13)),
				"kind": p["kind"], "name": p.get("name", "")})
		return
	var occupied := PackedByteArray()
	occupied.resize(CHUNK * CHUNK)
	var key := Vector2i(c.cx, c.cy)
	# Grands bâtiments réels, à leur emplacement
	for p in _pois_by_chunk.get(key, []):
		var kind: String = p["kind"]
		if kind in ["monument", "chateau_eau", "phare", "militaire"]:
			continue
		var size: Vector2i = POI_SIZE.get(kind, Vector2i(7, 6))
		var area := float(p.get("area_m2", 0))
		if area > 0:
			var side := clampf(sqrt(area) / 4.0, 5.0, 16.0)
			size = Vector2i(int(side * 1.2), int(side))
		var px := int(p["x"]) - x0 - size.x / 2
		var py := int(p["y"]) - y0 - size.y / 2
		px = clampi(px, 1, CHUNK - 1 - size.x)
		py = clampi(py, 1, CHUNK - 1 - size.y)
		var placed := false
		for attempt in 9:
			var r := Rect2i(px + (attempt % 3 - 1) * 3, py + (attempt / 3 - 1) * 3, size.x, size.y)
			if _free(c, r, 1, occupied):
				_build(c, r, occupied, true, kind, p.get("name", ""))
				placed = true
				break
		if not placed and size.x > 6:
			var r := Rect2i(px, py, size.x - 2, size.y - 2)
			if _free(c, r, 0, occupied):
				_build(c, r, occupied, true, kind, p.get("name", ""))
	# Maisons et ateliers : d'autant plus que le bâti réel est dense
	var urban := 0
	var dens := 0
	for ly in CHUNK:
		for lx in CHUNK:
			var t := zone.t_at(x0 + lx, y0 + ly)
			var d := zone.d_at(x0 + lx, y0 + ly)
			dens += d
			if t == ZoneData.T_URBAIN or t == ZoneData.T_INDUSTRIEL or d > 10:
				urban += 1
	if urban < 4:
		return
	# Parcours de l'îlot par pas de 2 cases : on tente un bâtiment à chaque
	# point, avec une probabilité qui suit la densité réelle du bâti.
	for ly in range(1, CHUNK - 2, 2):
		for lx in range(1, CHUNK - 2, 2):
			var wx := x0 + lx
			var wy := y0 + ly
			if occupied[ly * CHUNK + lx]:
				continue
			var t := zone.t_at(wx, wy)
			var d := zone.d_at(wx, wy)
			if not (t == ZoneData.T_URBAIN or t == ZoneData.T_INDUSTRIEL or d > 8):
				continue
			var chance := clampf(d / 90.0, 0.12, 0.95)
			if t == ZoneData.T_URBAIN:
				chance = maxf(chance, 0.35)
			if rnd(wx, wy, 22) > chance:
				continue
			var indus := t == ZoneData.T_INDUSTRIEL
			var w := 6 + int(rnd(wx, wy, 23) * 5) if indus else 3 + int(rnd(wx, wy, 23) * 3)
			var h := 5 + int(rnd(wx, wy, 24) * 4) if indus else 3 + int(rnd(wx, wy, 24) * 2)
			# essayer la taille prévue, puis plus petit
			for shrink in 2:
				var r := Rect2i(lx, ly, maxi(3, w - shrink * 2), maxi(3, h - shrink))
				if _free(c, r, 1, occupied):
					_build(c, r, occupied, false, "entrepot" if indus else "maison", "")
					break


func _build(c: ChunkData, r: Rect2i, occupied: PackedByteArray, special: bool, kind: String, label: String) -> void:
	var x0 := c.cx * CHUNK
	var y0 := c.cy * CHUNK
	var ruin := rnd(x0 + r.position.x, y0 + r.position.y, 30)
	var breaches := 1 + int(ruin * 3.0)
	for ly in range(r.position.y, r.end.y):
		for lx in range(r.position.x, r.end.x):
			var i := ly * CHUNK + lx
			occupied[i] = 1
			c.decor[i] = -1
			c.flags[i] = 0
			var wx := x0 + lx
			var wy := y0 + ly
			var edge := lx == r.position.x or ly == r.position.y or lx == r.end.x - 1 or ly == r.end.y - 1
			var v := int(rnd(wx, wy, 31) * 4.0)
			_put(c, lx, ly, Tiles.G_CARRELAGE if special else Tiles.G_SOL_BATIMENT, v)
			if edge:
				var corner := (lx == r.position.x or lx == r.end.x - 1) and (ly == r.position.y or ly == r.end.y - 1)
				var door := not corner and rnd(wx, wy, 32) < float(breaches) / float(2 * (r.size.x + r.size.y))
				if door:
					c.flags[i] = F_INDOOR
				else:
					_put(c, lx, ly, Tiles.G_MUR, v)
					_deco(c, lx, ly, Tiles.D_MUR_BRISE if rnd(wx, wy, 33) < ruin * 0.5 else Tiles.D_MUR, F_BLOCK)
			else:
				c.flags[i] = F_INDOOR
				var a := rnd(wx, wy, 34)
				if a < 0.10:
					_deco(c, lx, ly, Tiles.D_GRAVATS)
				elif a < 0.10 + ruin * 0.08:
					_deco(c, lx, ly, Tiles.D_BUISSON)
				elif a < 0.12 + ruin * 0.1:
					_deco(c, lx, ly, Tiles.D_JEUNE_ARBRE, F_TRUNK)
	# Garantir au moins une ouverture au sud
	var door_x := r.position.x + 1 + int(rnd(x0 + r.position.x, y0, 35) * maxf(1, r.size.x - 2))
	var di := (r.end.y - 1) * CHUNK + door_x
	c.decor[di] = -1
	c.flags[di] = F_INDOOR
	c.ground[di] = (Tiles.G_CARRELAGE if special else Tiles.G_SOL_BATIMENT) * Tiles.VARIANTS
	c.buildings.append({
		"rect": Rect2i(r.position + Vector2i(x0, y0), r.size),
		"kind": kind, "name": label,
	})


func _shade(x0: int, y0: int) -> Image:
	var img := Image.create(CHUNK + 2, CHUNK + 2, false, Image.FORMAT_L8)
	for ly in CHUNK + 2:
		for lx in CHUNK + 2:
			var x := x0 + lx - 1
			var y := y0 + ly - 1
			var gx := zone.e_at(x + 1, y) - zone.e_at(x - 1, y)
			var gy := zone.e_at(x, y + 1) - zone.e_at(x, y - 1)
			var v := clampf(0.9 + (gx + gy) * shade_k, 0.6, 1.0)
			img.set_pixel(lx, ly, Color(v, v, v))
	return img
