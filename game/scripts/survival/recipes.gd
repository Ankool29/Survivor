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
	{"id": "corde", "nom": "Corde de tendons", "ing": {"tendon": 2}},
	{"id": "arc", "nom": "Arc", "ing": {"branche": 2, "corde": 2}, "outils": ["couteau"]},
	{"id": "fleche", "n": 4, "nom": "4 flèches (pointes en silex)", "ing": {"branche": 2, "silex": 1}, "outils": ["couteau"]},
	{"id": "fleche", "n": 4, "nom": "4 flèches (pointes en clous)", "ing": {"branche": 2, "clous": 2}, "outils": ["couteau"]},
	{"id": "fleche", "n": 4, "nom": "4 flèches (pointes en os)", "ing": {"branche": 2, "os": 1}, "outils": ["couteau"]},
	{"id": "ligne", "nom": "Ligne de pêche", "ing": {"corde": 1, "clous": 1}},
	{"id": "ligne", "nom": "Ligne de pêche (hameçon en os)", "ing": {"corde": 1, "os": 1}, "outils": ["couteau"]},
	{"id": "collet", "nom": "Collet", "ing": {"corde": 1, "branche": 1}, "pose": "collet"},
	{"id": "nasse", "nom": "Nasse", "ing": {"branche": 4, "corde": 2}, "pose": "nasse"},
	# Étape 4 : peaux et couture
	{"id": "sechoir", "nom": "Cadre de séchage", "ing": {"branche": 4, "corde": 1}, "pose": "sechoir"},
	{"id": "grattoir", "nom": "Grattoir en os", "ing": {"os": 1}, "outils": ["couteau"]},
	{"id": "aiguille", "nom": "Aiguille en os", "ing": {"os": 1}, "outils": ["couteau"]},
	{"id": "fil", "n": 4, "nom": "4 fils de tendon", "ing": {"tendon": 1}},
	{"id": "fil", "n": 2, "nom": "2 fils de fibres", "ing": {"fibre": 3}},
	{"id": "bonnet_fourrure", "nom": "Bonnet de fourrure", "ing": {"fourrure_lapin": 2, "fil": 1}, "outils": ["aiguille"]},
	{"id": "moufles", "nom": "Moufles de fourrure", "ing": {"fourrure_lapin": 2, "fil": 1}, "outils": ["aiguille"]},
	{"id": "gilet_peau", "nom": "Gilet de peau", "ing": {"cuir": 2, "fil": 2}, "outils": ["aiguille"]},
	{"id": "pantalon_peau", "nom": "Pantalon de peau", "ing": {"cuir": 2, "fil": 2}, "outils": ["aiguille"]},
	{"id": "manteau_fourrure", "nom": "Manteau de fourrure (renard)", "ing": {"fourrure_renard": 2, "cuir": 1, "fil": 3}, "outils": ["aiguille"]},
	{"id": "manteau_fourrure", "nom": "Manteau de fourrure (loup)", "ing": {"fourrure_loup": 1, "cuir": 1, "fil": 3}, "outils": ["aiguille"]},
	{"id": "mocassins", "nom": "Mocassins", "ing": {"cuir": 1, "fil": 1}, "outils": ["aiguille"]},
	{"id": "bottes_fourrees", "nom": "Bottes fourrées", "ing": {"cuir": 1, "fourrure_lapin": 1, "fil": 2}, "outils": ["aiguille"]},
	{"id": "sac_cuir", "nom": "Sac en cuir", "ing": {"cuir": 3, "corde": 2, "fil": 2}, "outils": ["aiguille"]},
	{"id": "carquois", "nom": "Carquois", "ing": {"cuir": 1, "fil": 1}, "outils": ["aiguille"]},
]

## Outils qui peuvent en remplacer un autre.
const TOOL_ALIASES := {"aiguille": ["necessaire"], "couteau": []}


static func has_tool(inv: Inventory, t: String) -> bool:
	if inv.has(t):
		return true
	for a in TOOL_ALIASES.get(t, []):
		if inv.has(a):
			return true
	return false


static func can_make(r: Dictionary, inv: Inventory) -> bool:
	for id in r["ing"]:
		if not inv.has(id, int(r["ing"][id])):
			return false
	for t in r.get("outils", []):
		if not has_tool(inv, t):
			return false
	return true


static func describe(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in r["ing"]:
		parts.append("%d %s" % [int(r["ing"][id]), Items.name_of(id).to_lower()])
	for t in r.get("outils", []):
		parts.append("(" + Items.name_of(t).to_lower() + ")")
	return ", ".join(parts)
