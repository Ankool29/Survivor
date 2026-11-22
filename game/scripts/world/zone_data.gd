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
	z.terrain = FileAccess.get_file_as_bytes(dir + "terrain.bin")
	z.roads = FileAccess.get_file_as_bytes(dir + "roads.bin")
	z.density = FileAccess.get_file_as_bytes(dir + "density.bin")
	z.elev = FileAccess.get_file_as_bytes(dir + "elev.bin")
	var n := z.width * z.height
	for arr in [z.terrain, z.roads, z.density, z.elev]:
		if arr.size() != n:
			push_error("Fichier de zone de taille inattendue")
			return null
	var p = JSON.parse_string(FileAccess.get_file_as_string(dir + "pois.json"))
	z.pois = p if p is Array else []
	var pl = JSON.parse_string(FileAccess.get_file_as_string(dir + "places.json"))
	z.places = pl if pl is Array else []
	if ResourceLoader.exists(dir + "preview.png"):
		z.map_texture = load(dir + "preview.png")
	return z


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func t_at(x: int, y: int) -> int:
	if not inside(x, y):
		return T_MER
	return terrain[y * width + x]


func r_at(x: int, y: int) -> int:
	if not inside(x, y):
		return R_AUCUNE
	return roads[y * width + x]


func d_at(x: int, y: int) -> int:
	if not inside(x, y):
		return 0
	return density[y * width + x]


func e_at(x: int, y: int) -> int:
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
