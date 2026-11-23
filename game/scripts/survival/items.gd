class_name Items
extends RefCounted
## Catalogue des objets. Icônes : res://assets/items/<id>.png (PixelLab),
## sinon une icône provisoire dessinée par le jeu.
##
## Champs : nom, pile (taille d'une pile), et selon l'objet :
##   faim / soif : gain en mangeant ou buvant ; malade : risque (0-1) de tomber malade
##   soin : santé rendue ; usure : nombre d'utilisations d'un outil
##   chaleur : bonus de température s'il est porté ; utiliser : nom de l'action
##   Vêtements (étape 4) : emplacement, imper (0-1 de la pluie arrêtée), protection (0-1 des dégâts),
##   bruit (+ distance de repérage), tenue (apparence du personnage), cases et charge (sacs, kg),
##   reparer (matière pour réparer)

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
	"pull": {"nom": "Pull en laine", "pile": 1, "emplacement": "torse", "chaleur": 4.0, "usure": 80, "reparer": "tissu"},
	"manteau": {"nom": "Manteau", "pile": 1, "emplacement": "torse", "chaleur": 7.0, "imper": 0.3, "protection": 0.1, "usure": 120, "reparer": "tissu"},
	"livre": {"nom": "Vieux livre", "pile": 5},
	"bidon": {"nom": "Jerrican", "pile": 2},
	"sac": {"nom": "Sac à dos", "pile": 1, "emplacement": "dos", "cases": 20, "charge": 15.0, "usure": 300, "reparer": "tissu"},
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
	"peau_lapin": {"nom": "Peau de lapin", "pile": 10, "garde": 4320},
	"peau_renard": {"nom": "Peau de renard", "pile": 5, "garde": 4320},
	"peau_chevreuil": {"nom": "Peau de chevreuil", "pile": 3, "garde": 4320},
	"peau_sanglier": {"nom": "Peau de sanglier", "pile": 3, "garde": 4320},
	"peau_loup": {"nom": "Peau de loup", "pile": 3, "garde": 4320},
	"peau_chien": {"nom": "Peau de chien", "pile": 5, "garde": 4320},
	"os": {"nom": "Os", "pile": 20},
	"tendon": {"nom": "Tendons", "pile": 20},
	"graisse": {"nom": "Graisse", "pile": 10},
	"defense": {"nom": "Défense de sanglier", "pile": 10},
	"arc": {"nom": "Arc", "pile": 1, "usure": 80},
	"fleche": {"nom": "Flèche", "pile": 20},
	"ligne": {"nom": "Ligne de pêche", "pile": 1, "usure": 30},
	# Étape 4 : vêtements trouvés
	"bonnet": {"nom": "Bonnet", "pile": 1, "emplacement": "tete", "chaleur": 2.0, "usure": 80, "reparer": "tissu"},
	"casquette": {"nom": "Casquette", "pile": 1, "emplacement": "tete", "chaleur": 0.5, "imper": 0.2, "usure": 80, "reparer": "tissu"},
	"tee_shirt": {"nom": "Tee-shirt", "pile": 1, "emplacement": "torse", "chaleur": 1.0, "usure": 60, "reparer": "tissu"},
	"veste": {"nom": "Veste de travail", "pile": 1, "emplacement": "torse", "chaleur": 4.0, "imper": 0.3, "protection": 0.1, "usure": 120, "reparer": "tissu"},
	"cire": {"nom": "Ciré", "pile": 1, "emplacement": "torse", "chaleur": 2.0, "imper": 0.9, "capuche": true, "bruit": 0.15, "tenue": "cire", "usure": 100, "reparer": "tissu"},
	"doudoune": {"nom": "Doudoune", "pile": 1, "emplacement": "torse", "chaleur": 9.0, "imper": 0.2, "bruit": 0.15, "usure": 80, "reparer": "tissu"},
	"jean": {"nom": "Jean", "pile": 1, "emplacement": "jambes", "chaleur": 2.0, "protection": 0.05, "usure": 120, "reparer": "tissu"},
	"pantalon_travail": {"nom": "Pantalon de travail", "pile": 1, "emplacement": "jambes", "chaleur": 2.5, "imper": 0.2, "protection": 0.1, "usure": 140, "reparer": "tissu"},
	"pantalon_pluie": {"nom": "Pantalon de pluie", "pile": 1, "emplacement": "jambes", "chaleur": 1.0, "imper": 0.9, "bruit": 0.1, "usure": 80, "reparer": "tissu"},
	"baskets": {"nom": "Baskets", "pile": 1, "emplacement": "pieds", "chaleur": 1.0, "usure": 80, "reparer": "tissu"},
	"bottes_caoutchouc": {"nom": "Bottes en caoutchouc", "pile": 1, "emplacement": "pieds", "chaleur": 1.0, "imper": 0.8, "usure": 120, "reparer": "tissu"},
	"chaussures_rando": {"nom": "Chaussures de rando", "pile": 1, "emplacement": "pieds", "chaleur": 2.0, "imper": 0.4, "protection": 0.05, "usure": 160, "reparer": "cuir"},
	"gants_jardin": {"nom": "Gants de jardin", "pile": 1, "emplacement": "mains", "chaleur": 0.5, "protection": 0.05, "usure": 80, "reparer": "tissu"},
	"gants_laine": {"nom": "Gants de laine", "pile": 1, "emplacement": "mains", "chaleur": 1.5, "usure": 60, "reparer": "tissu"},
	"sac_courses": {"nom": "Sac de courses", "pile": 1, "emplacement": "dos", "cases": 16, "charge": 6.0, "usure": 150, "reparer": "tissu"},
	"sac_rando": {"nom": "Sac de rando", "pile": 1, "emplacement": "dos", "cases": 28, "charge": 30.0, "usure": 400, "reparer": "tissu"},
	# Étape 4 : vêtements fabriqués
	"bonnet_fourrure": {"nom": "Bonnet de fourrure", "pile": 1, "emplacement": "tete", "chaleur": 4.0, "imper": 0.3, "protection": 0.05, "usure": 150, "reparer": "fourrure"},
	"gilet_peau": {"nom": "Gilet de peau", "pile": 1, "emplacement": "torse", "chaleur": 4.0, "imper": 0.4, "protection": 0.2, "tenue": "cuir", "usure": 200, "reparer": "cuir"},
	"manteau_fourrure": {"nom": "Manteau de fourrure", "pile": 1, "emplacement": "torse", "chaleur": 10.0, "imper": 0.5, "protection": 0.25, "tenue": "fourrure", "usure": 250, "reparer": "fourrure"},
	"pantalon_peau": {"nom": "Pantalon de peau", "pile": 1, "emplacement": "jambes", "chaleur": 3.0, "imper": 0.4, "protection": 0.15, "usure": 200, "reparer": "cuir"},
	"mocassins": {"nom": "Mocassins", "pile": 1, "emplacement": "pieds", "chaleur": 1.5, "imper": 0.2, "bruit": -0.15, "usure": 120, "reparer": "cuir"},
	"bottes_fourrees": {"nom": "Bottes fourrées", "pile": 1, "emplacement": "pieds", "chaleur": 4.0, "imper": 0.4, "protection": 0.05, "usure": 200, "reparer": "cuir"},
	"moufles": {"nom": "Moufles de fourrure", "pile": 1, "emplacement": "mains", "chaleur": 3.0, "usure": 120, "reparer": "fourrure"},
	"sac_cuir": {"nom": "Sac en cuir", "pile": 1, "emplacement": "dos", "cases": 24, "charge": 22.0, "usure": 400, "reparer": "cuir"},
	"carquois": {"nom": "Carquois", "pile": 1, "emplacement": "ceinture", "usure": 300, "reparer": "cuir"},
	# Étape 4 : matières et outils de couture
	"cuir": {"nom": "Cuir", "pile": 10},
	"fourrure_lapin": {"nom": "Fourrure de lapin", "pile": 10},
	"fourrure_renard": {"nom": "Fourrure de renard", "pile": 5},
	"fourrure_loup": {"nom": "Fourrure de loup", "pile": 3},
	"cendres": {"nom": "Cendres", "pile": 20},
	"aiguille": {"nom": "Aiguille en os", "pile": 1, "usure": 40},
	"fil": {"nom": "Fil", "pile": 30},
	"necessaire": {"nom": "Nécessaire de couture", "pile": 1, "usure": 60},
	"grattoir": {"nom": "Grattoir en os", "pile": 1, "usure": 30},
}

## Emplacements d'équipement, dans l'ordre d'affichage.
const SLOTS := ["tete", "torse", "mains", "jambes", "pieds", "dos", "ceinture"]
const SLOT_NAMES := {"tete": "Tête", "torse": "Torse", "mains": "Mains", "jambes": "Jambes", "pieds": "Pieds", "dos": "Sac", "ceinture": "Ceinture"}

## Poids en kg (0,2 kg si absent).
const WEIGHT := {
	"buche": 1.5, "pierre": 0.5, "planche": 1.0, "ferraille": 1.0, "bidon": 1.0, "bache": 1.0, "branche": 0.3,
	"bouteille_eau": 0.8, "bouteille_bouillie": 0.8, "bouteille_vide": 0.1, "conserve": 0.4, "livre": 0.5,
	"hache": 1.2, "lance": 1.0, "arc": 1.0, "fleche": 0.05, "couteau": 0.2, "clous": 0.02, "silex": 0.2,
	"viande": 1.0, "petite_viande": 0.4, "viande_cuite": 0.8, "viande_sechee": 0.2, "poisson": 0.6,
	"peau_lapin": 0.2, "peau_renard": 0.5, "peau_chevreuil": 1.5, "peau_sanglier": 2.5, "peau_loup": 1.5, "peau_chien": 1.0,
	"os": 0.3, "graisse": 0.5, "defense": 0.2, "cuir": 0.8, "fourrure_lapin": 0.2, "fourrure_renard": 0.6,
	"fourrure_loup": 1.5, "cendres": 0.1, "fil": 0.01, "fibre": 0.05, "tissu": 0.2, "corde": 0.2, "mures": 0.05,
	"pomme": 0.2, "champignon": 0.1, "nasse": 2.0, "collet": 0.1,
	"manteau_fourrure": 3.0, "doudoune": 1.0, "manteau": 2.0, "cire": 1.0, "sac_rando": 2.0, "sac_cuir": 1.5,
}


static func weight(id: String) -> float:
	return float(WEIGHT.get(id, 0.2))

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
