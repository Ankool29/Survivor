class_name Loot
extends RefCounted
## Butin par type de meuble ou d'épave : [objet, chance, minimum, maximum].

const TABLES := {
	"maison": [["tissu", 0.5, 1, 2], ["conserve", 0.35, 1, 2], ["bouteille_vide", 0.4, 1, 1],
		["pull", 0.12, 1, 1], ["manteau", 0.06, 1, 1], ["bougie", 0.25, 1, 2], ["allumettes", 0.15, 3, 8],
		["livre", 0.2, 1, 1], ["bandage", 0.1, 1, 1], ["corde", 0.1, 1, 1], ["sac", 0.03, 1, 1],
		["comprimes", 0.05, 1, 2], ["planche", 0.15, 1, 2],
		["tee_shirt", 0.2, 1, 1], ["jean", 0.12, 1, 1], ["bonnet", 0.1, 1, 1], ["casquette", 0.06, 1, 1],
		["baskets", 0.08, 1, 1], ["gants_laine", 0.08, 1, 1], ["veste", 0.05, 1, 1], ["doudoune", 0.03, 1, 1],
		["sac_courses", 0.08, 1, 1], ["necessaire", 0.06, 1, 1]],
	"magasin": [["conserve", 0.35, 1, 3], ["bouteille_vide", 0.25, 1, 2], ["bouteille_bouillie", 0.08, 1, 1],
		["allumettes", 0.12, 3, 10], ["sac", 0.04, 1, 1], ["bougie", 0.1, 1, 3],
		["sac_courses", 0.1, 1, 1], ["tee_shirt", 0.08, 1, 1], ["bonnet", 0.05, 1, 1], ["gants_laine", 0.05, 1, 1],
		["doudoune", 0.02, 1, 1], ["sac_rando", 0.02, 1, 1], ["chaussures_rando", 0.02, 1, 1]],
	"pharmacie": [["bandage", 0.7, 1, 3], ["antiseptique", 0.5, 1, 2], ["comprimes", 0.6, 1, 3]],
	"garage": [["ferraille", 0.7, 1, 3], ["clous", 0.4, 3, 10], ["bidon", 0.3, 1, 1], ["corde", 0.3, 1, 2],
		["bache", 0.2, 1, 1], ["planche", 0.3, 1, 3], ["gants_jardin", 0.25, 1, 1], ["pantalon_travail", 0.1, 1, 1]],
	"ferme": [["corde", 0.4, 1, 2], ["bache", 0.3, 1, 1], ["planche", 0.4, 1, 3], ["tissu", 0.2, 1, 1],
		["bouteille_vide", 0.2, 1, 1], ["cire", 0.12, 1, 1], ["bottes_caoutchouc", 0.2, 1, 1],
		["pantalon_pluie", 0.1, 1, 1], ["pantalon_travail", 0.15, 1, 1], ["gants_jardin", 0.2, 1, 1]],
	"epave": [["ferraille", 0.6, 1, 2], ["tissu", 0.3, 1, 1], ["bidon", 0.2, 1, 1], ["bouteille_vide", 0.2, 1, 1],
		["sac", 0.04, 1, 1], ["casquette", 0.05, 1, 1], ["sac_rando", 0.01, 1, 1]],
}

const TABLE_OF_DECOR := {
	Tiles.D_MEUBLE: "maison", Tiles.D_RAYON: "magasin", Tiles.D_PHARMA: "pharmacie",
	Tiles.D_ETABLI: "garage", Tiles.D_FOIN: "ferme", Tiles.D_EPAVE: "epave",
}


## Tirage déterministe (même graine, même case -> même butin).
static func roll(table: String, cell: Vector2i, seed_value: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, cell.x, cell.y, table])
	var out := {}
	for e in TABLES.get(table, []):
		if r.randf() < float(e[1]):
			out[e[0]] = int(out.get(e[0], 0)) + r.randi_range(int(e[2]), int(e[3]))
	return out
