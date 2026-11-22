class_name ZoneData
extends RefCounted
## Données d'une zone fabriquée par tools/zone/build_zone.py.
## Une valeur d'un octet par case ; ligne 0 au nord, colonne 0 à l'ouest.

# Codes de sol (identiques à TERRAIN dans build_zone.py)
const T_MER := 0
const T_EAU := 1
const T_SABLE := 2
const T_PRAIRIE := 3
const T_CHAMP := 4
const T_FEUILLUS := 5
const T_RESINEUX := 6
const T_MIXTE := 7
const T_LANDE := 8
const T_MARAIS := 9
const T_URBAIN := 10
const T_INDUSTRIEL := 11
const T_ROCHE := 12
const T_CIMETIERE := 13
const T_PARC := 14

# Codes de voies (identiques à ROADS)
const R_AUCUNE := 0
const R_VOIE_RAPIDE := 1
const R_PRINCIPALE := 2
const R_SECONDAIRE := 3
const R_RUE := 4
const R_CHEMIN := 5
const R_RAIL := 6

var name := ""
var title := ""
var width := 0
var height := 0
var cells_per_km := 32
var terrain: PackedByteArray
var roads: PackedByteArray
var density: PackedByteArray
var elev: PackedByteArray
var bld: PackedByteArray        ## bâtiments réels (mode réel) : 1 sol, 2 mur, 3 sol notable
var real := false               ## échelle réelle (vrais bâtiments) ou compressée
var cell_m := 31.25

# --- Zone en tuiles (grandes zones à l'échelle réelle)
var tiled := false
var tile := 0                   ## côté d'une tuile, en cases
var tiles_x := 0
var tiles_y := 0
var elev_step := 1              ## altitude : une valeur toutes les elev_step cases
var elev_w := 0
var elev_h := 0
var _dir := ""
var _tiles := {}                ## Vector2i -> [terrain, roads, bld] (PackedByteArray)
var _tile_age := {}
var _clock := 0
var _mutex := Mutex.new()
const MAX_TILES := 12
const EMPTY_TILE := []
var pois: Array = []
var places: Array = []
var sources: Array = []
var map_texture: Texture2D


static func load_zone(zone_name: String) -> ZoneData:
	var dir := "res://data/zones/%s/" % zone_name
	var meta_text := FileAccess.get_file_as_string(dir + "meta.json")
	if meta_text.is_empty():
		push_error("Zone introuvable : " + dir)
		return null
	var meta: Dictionary = JSON.parse_string(meta_text)
	var z := ZoneData.new()
	z.name = zone_name
	z.title = meta.get("title", zone_name)
	z.width = int(meta["width"])
	z.height = int(meta["height"])
	z.cells_per_km = int(meta.get("cells_per_km", 32))
	z.sources = meta.get("sources", [])
	var n := z.width * z.height
	z.real = meta.get("mode", "") == "reel"
	z.cell_m = float(meta.get("cell_m", 31.25))
	z._dir = dir
	if meta.has("tile"):
		z.tiled = true
		z.tile = int(meta["tile"])
		z.tiles_x = int(meta["tiles_x"])
		z.tiles_y = int(meta["tiles_y"])
		z.elev_step = int(meta["elev_step"])
		z.elev_w = int(meta["elev_w"])
		z.elev_h = int(meta["elev_h"])
		z.elev = _layer(dir, "elev", z.elev_w * z.elev_h)
		if z.elev.size() != z.elev_w * z.elev_h:
			push_error("Relief de zone de taille inattendue")
			return null
		z._load_lists(dir)
		return z
	z.terrain = _layer(dir, "terrain", n)
	z.roads = _layer(dir, "roads", n)
	z.density = _layer(dir, "density", n)
	z.elev = _layer(dir, "elev", n)
	if z.real:
		z.bld = _layer(dir, "bld", n)
		if z.bld.size() != n:
			z.bld.resize(n)
	for arr in [z.terrain, z.roads, z.density, z.elev]:
		if arr.size() != n:
			push_error("Fichier de zone de taille inattendue")
			return null
	z._load_lists(dir)
	return z


func _load_lists(dir: String) -> void:
	var p = JSON.parse_string(FileAccess.get_file_as_string(dir + "pois.json"))
	pois = p if p is Array else []
	var pl = JSON.parse_string(FileAccess.get_file_as_string(dir + "places.json"))
	places = pl if pl is Array else []
	if ResourceLoader.exists(dir + "preview.png"):
		map_texture = load(dir + "preview.png")


## Tuile (tx, ty) : [terrain, voies, bâtiments], chargée au besoin ; [] = mer.
## Appelé depuis l'image principale et depuis le fil de fabrication.
func _get_tile(tx: int, ty: int) -> Array:
	var key := Vector2i(tx, ty)
	_mutex.lock()
	_clock += 1
	var t: Array = _tiles.get(key, EMPTY_TILE)
	if _tiles.has(key):
		_tile_age[key] = _clock
		_mutex.unlock()
		return t
	var path := "%stiles/%d_%d.bin.gz" % [_dir, tx, ty]
	t = []
	if FileAccess.file_exists(path):
		var n := tile * tile
		var raw := FileAccess.get_file_as_bytes(path).decompress(n * 3, FileAccess.COMPRESSION_GZIP)
		if raw.size() == n * 3:
			t = [raw.slice(0, n), raw.slice(n, 2 * n), raw.slice(2 * n, 3 * n)]
	_tiles[key] = t
	_tile_age[key] = _clock
	if _tiles.size() > MAX_TILES:
		var oldest: Vector2i = key
		var age := _clock
		for k in _tile_age:
			if _tile_age[k] < age:
				age = _tile_age[k]
				oldest = k
		_tiles.erase(oldest)
		_tile_age.erase(oldest)
	_mutex.unlock()
	return t


func _tiled_at(x: int, y: int, layer: int, outside: int) -> int:
	var t := _get_tile(x / tile, y / tile)
	if t.is_empty():
		return outside
	return t[layer][(y % tile) * tile + (x % tile)]


## Couche d'un octet par case : <nom>.bin.gz (compressé) ou <nom>.bin.
static func _layer(dir: String, layer: String, n: int) -> PackedByteArray:
	if FileAccess.file_exists(dir + layer + ".bin.gz"):
		var raw := FileAccess.get_file_as_bytes(dir + layer + ".bin.gz")
		return raw.decompress(n, FileAccess.COMPRESSION_GZIP)
	return FileAccess.get_file_as_bytes(dir + layer + ".bin")


## Liste des zones disponibles (dossiers de res://data/zones contenant meta.json).
static func available() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open("res://data/zones")
	if d:
		for name in d.get_directories():
			if FileAccess.file_exists("res://data/zones/%s/meta.json" % name) and name != "test":
				out.append(name)
	out.sort()
	return out


func b_at(x: int, y: int) -> int:
	if not real or not inside(x, y):
		return 0
	if tiled:
		return _tiled_at(x, y, 2, 0)
	return bld[y * width + x]


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func t_at(x: int, y: int) -> int:
	if not inside(x, y):
		return T_MER
	if tiled:
		return _tiled_at(x, y, 0, T_MER)
	return terrain[y * width + x]


func r_at(x: int, y: int) -> int:
	if not inside(x, y):
		return R_AUCUNE
	if tiled:
		return _tiled_at(x, y, 1, R_AUCUNE)
	return roads[y * width + x]


func d_at(x: int, y: int) -> int:
	if tiled or not inside(x, y):
		return 0
	return density[y * width + x]


## Altitude en mètres (interpolée pour les zones en tuiles).
func e_at(x: int, y: int) -> float:
	if tiled:
		var fx := clampf(x / float(elev_step), 0.0, elev_w - 1.001)
		var fy := clampf(y / float(elev_step), 0.0, elev_h - 1.001)
		var ix := int(fx)
		var iy := int(fy)
		var tx := fx - ix
		var ty := fy - iy
		var k := iy * elev_w + ix
		var a := lerpf(elev[k], elev[k + 1], tx)
		var b := lerpf(elev[k + elev_w], elev[k + elev_w + 1], tx)
		return lerpf(a, b, ty)
	return elev[clampi(y, 0, height - 1) * width + clampi(x, 0, width - 1)]


func is_water(x: int, y: int) -> bool:
	var t := t_at(x, y)
	return t == T_MER or t == T_EAU


## Nom du lieu le plus proche, avec la distance en cases.
func nearest_place(x: float, y: float) -> Dictionary:
	var best := {}
	var best_score := INF
	for p in places:
		var kind: String = p["kind"]
		var weight := 1.0
		match kind:
			"city": weight = 0.35
			"town": weight = 0.5
			"suburb", "village": weight = 0.8
			"hamlet": weight = 1.0
			_: weight = 1.3
		var d := Vector2(float(p["x"]) - x, float(p["y"]) - y).length()
		var score := d * weight
		if score < best_score:
			best_score = score
			best = {"name": p["name"], "kind": kind, "dist": d}
	return best
