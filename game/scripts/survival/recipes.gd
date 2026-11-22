class_name Recipes
extends RefCounted
## Recettes du palier 1. « outils » : objets nécessaires mais non consommés.
## « pose » : le résultat est une construction posée devant le joueur.

const LIST := [
	{"id": "corde", "nom": "Corde", "ing": {"fibre": 3}},
	{"id": "couteau", "nom": "Couteau en silex", "ing": {"silex": 1, "branche": 1, "corde": 1}},
	{"id": "hache", "nom": "Hache de pierre", "ing": {"pierre": 2, "branche": 1, "corde": 1}},
	{"id": "lance", "nom": "Lance", "ing": {"branche": 2, "corde": 1}, "outils": ["couteau"]},
	{"id": "torche", "nom": "Torche", "ing": {"branche": 1, "fibre": 2}},
	{"id": "bandage", "nom": "Bandage", "ing": {"tissu": 1}},
	{"id": "feu", "nom": "Feu de camp", "ing": {"branche": 6, "pierre": 4}, "pose": "feu"},
	{"id": "abri", "nom": "Abri de branches", "ing": {"branche": 12, "fibre": 6, "corde": 2}, "pose": "abri"},
	{"id": "coffre", "nom": "Coffre de camp", "ing": {"planche": 4, "corde": 1}, "pose": "coffre"},
]


static func can_make(r: Dictionary, inv: Inventory) -> bool:
	for id in r["ing"]:
		if not inv.has(id, int(r["ing"][id])):
			return false
	for t in r.get("outils", []):
		if not inv.has(t):
			return false
	return true


static func describe(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in r["ing"]:
		parts.append("%d %s" % [int(r["ing"][id]), Items.name_of(id).to_lower()])
	for t in r.get("outils", []):
		parts.append("(" + Items.name_of(t).to_lower() + ")")
	return ", ".join(parts)
