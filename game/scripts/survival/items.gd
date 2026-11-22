class_name Items
extends RefCounted
## Catalogue des objets. Icônes : res://assets/items/<id>.png (PixelLab),
## sinon une icône provisoire dessinée par le jeu.
##
## Champs : nom, pile (taille d'une pile), et selon l'objet :
##   faim / soif : gain en mangeant ou buvant ; malade : risque (0-1) de tomber malade
##   soin : santé rendue ; usure : nombre d'utilisations d'un outil
##   chaleur : bonus de température s'il est porté ; utiliser : nom de l'action

const DB := {
	"branche": {"nom": "Branche", "pile": 20},
	"buche": {"nom": "Bûche", "pile": 10},
	"fibre": {"nom": "Fibres", "pile": 20},
	"corde": {"nom": "Corde", "pile": 10},
	"pierre": {"nom": "Pierre", "pile": 20},
	"silex": {"nom": "Silex", "pile": 10},
	"planche": {"nom": "Planche", "pile": 10},
	"tissu": {"nom": "Tissu", "pile": 10},
	"ferraille": {"nom": "Ferraille", "pile": 20},
	"clous": {"nom": "Clous", "pile": 30},
	"bache": {"nom": "Bâche", "pile": 3},
	"mures": {"nom": "Mûres", "pile": 20, "faim": 6, "soif": 2, "utiliser": "Manger"},
	"pomme": {"nom": "Pomme", "pile": 10, "faim": 10, "soif": 4, "utiliser": "Manger"},
	"champignon": {"nom": "Cèpe", "pile": 10, "faim": 8, "malade": 0.1, "utiliser": "Manger cru"},
	"champignon_douteux": {"nom": "Champignon douteux", "pile": 10, "faim": 8, "malade": 0.6, "utiliser": "Manger cru"},
	"conserve": {"nom": "Conserve", "pile": 6, "faim": 30, "soif": 5, "malade": 0.2, "utiliser": "Manger"},
	"repas": {"nom": "Repas chaud", "pile": 5, "faim": 40, "soif": 5, "chaud": 15, "utiliser": "Manger"},
	"bouteille_vide": {"nom": "Bouteille vide", "pile": 3},
	"bouteille_eau": {"nom": "Eau non traitée", "pile": 3, "soif": 35, "malade": 0.3, "utiliser": "Boire", "rend": "bouteille_vide"},
	"bouteille_bouillie": {"nom": "Eau bouillie", "pile": 3, "soif": 35, "utiliser": "Boire", "rend": "bouteille_vide"},
	"couteau": {"nom": "Couteau en silex", "pile": 1, "usure": 60},
	"hache": {"nom": "Hache de pierre", "pile": 1, "usure": 40},
	"lance": {"nom": "Lance", "pile": 1, "usure": 50},
	"torche": {"nom": "Torche", "pile": 5, "utiliser": "Allumer"},
	"bandage": {"nom": "Bandage", "pile": 10, "soin": 15, "utiliser": "Se soigner"},
	"antiseptique": {"nom": "Antiseptique", "pile": 5, "soin": 5, "guerit": true, "utiliser": "Se soigner"},
	"comprimes": {"nom": "Comprimés", "pile": 10, "soin": 5, "guerit": true, "utiliser": "Prendre"},
	"pull": {"nom": "Pull en laine", "pile": 1, "chaleur": 4, "utiliser": "Porter"},
	"manteau": {"nom": "Manteau", "pile": 1, "chaleur": 8, "utiliser": "Porter"},
	"livre": {"nom": "Vieux livre", "pile": 5},
	"bidon": {"nom": "Jerrican", "pile": 2},
	"sac": {"nom": "Sac à dos", "pile": 1, "utiliser": "Équiper"},
	"allumettes": {"nom": "Allumettes", "pile": 20},
	"bougie": {"nom": "Bougie", "pile": 10},
	# Étape 3 : chasse et pêche. « garde » : minutes avant de se gâter.
	"petite_viande": {"nom": "Petite viande crue", "pile": 10, "faim": 8, "malade": 0.4, "utiliser": "Manger cru", "garde": 2880},
	"viande": {"nom": "Viande crue", "pile": 10, "faim": 15, "malade": 0.5, "utiliser": "Manger cru", "garde": 2880},
	"poisson": {"nom": "Poisson cru", "pile": 10, "faim": 10, "malade": 0.3, "utiliser": "Manger cru", "garde": 1440},
	"brochette": {"nom": "Brochette grillée", "pile": 10, "faim": 18, "chaud": 6, "utiliser": "Manger", "garde": 5760},
	"viande_cuite": {"nom": "Viande cuite", "pile": 10, "faim": 35, "chaud": 10, "utiliser": "Manger", "garde": 5760},
	"poisson_grille": {"nom": "Poisson grillé", "pile": 10, "faim": 22, "chaud": 6, "utiliser": "Manger", "garde": 4320},
	"viande_sechee": {"nom": "Viande séchée", "pile": 20, "faim": 25, "soif": -5, "utiliser": "Manger"},
	"viande_avariee": {"nom": "Nourriture avariée", "pile": 10, "faim": 5, "malade": 0.9, "utiliser": "Manger cru"},
	"peau_lapin": {"nom": "Peau de lapin", "pile": 10},
	"peau_renard": {"nom": "Peau de renard", "pile": 5},
	"peau_chevreuil": {"nom": "Peau de chevreuil", "pile": 3},
	"peau_sanglier": {"nom": "Peau de sanglier", "pile": 3},
	"peau_loup": {"nom": "Peau de loup", "pile": 3},
	"peau_chien": {"nom": "Peau de chien", "pile": 5},
	"os": {"nom": "Os", "pile": 20},
	"tendon": {"nom": "Tendons", "pile": 20},
	"graisse": {"nom": "Graisse", "pile": 10},
	"defense": {"nom": "Défense de sanglier", "pile": 10},
	"arc": {"nom": "Arc", "pile": 1, "usure": 80},
	"fleche": {"nom": "Flèche", "pile": 20},
	"ligne": {"nom": "Ligne de pêche", "pile": 1, "usure": 30},
}

## Cuisson au feu : objet cru -> [objet cuit, bouton, minutes de jeu].
const COOK := {
	"bouteille_eau": ["bouteille_bouillie", "Faire bouillir", 10],
	"champignon": ["repas", "Cuire", 10],
	"conserve": ["repas", "Réchauffer", 5],
	"petite_viande": ["brochette", "Griller", 15],
	"viande": ["viande_cuite", "Cuire", 30],
	"poisson": ["poisson_grille", "Griller", 15],
}
## Fumer la viande au feu : se garde sans limite.
const SMOKE := {"viande": "viande_sechee", "petite_viande": "viande_sechee"}

const _COLORS := {
	"branche": Color8(120, 86, 52), "buche": Color8(140, 96, 56), "fibre": Color8(150, 160, 90),
	"pierre": Color8(130, 130, 126), "silex": Color8(90, 96, 110), "mures": Color8(70, 40, 80),
	"pomme": Color8(180, 50, 40), "conserve": Color8(160, 160, 170), "repas": Color8(170, 110, 60),
}

static var _icons := {}


static func name_of(id: String) -> String:
	return DB.get(id, {}).get("nom", id)


static func info(id: String) -> Dictionary:
	return DB.get(id, {})


static func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var path := "res://assets/items/%s.png" % id
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var c: Color = _COLORS.get(id, Color.from_hsv(float(hash(id) % 360) / 360.0, 0.4, 0.7))
		img.fill_rect(Rect2i(6, 6, 20, 20), c)
		img.fill_rect(Rect2i(6, 6, 20, 3), c.lightened(0.3))
		tex = ImageTexture.create_from_image(img)
	_icons[id] = tex
	return tex
