class_name Species
extends RefCounted
## Fiches des animaux (étape 3). Vitesses et distances en cases (1 case = 2 m).
##
## habitat : densité de groupes par type de terrain (ZoneData.T_*), en groupes par km²
##           (densités « 30 ans sans chasse », relevées pour le jeu).
## groupe : [min, max] ; actif : activité selon l'heure [nuit, aube/crépuscule, jour].
## sens : distance à laquelle il repère le joueur ; fuite : distance où il se calme.
## comportement : proie, sanglier, meute (chiens), loup.


const DB := {
	"lapin": {"nom": "lapin", "pv": 10, "marche": 1.2, "course": 7.0, "sens": 9.1, "fuite": 18.2,
		"groupe": [1, 3], "actif": [0.15, 1.3, 1.0], "comportement": "proie",
		"habitat": {ZoneData.T_PRAIRIE: 90.0, ZoneData.T_CHAMP: 60.0, ZoneData.T_LANDE: 80.0, ZoneData.T_PARC: 60.0, ZoneData.T_CIMETIERE: 40.0, ZoneData.T_MIXTE: 15.0},
		"butin": {"petite_viande": 1, "peau_lapin": 1}, "depecer": 10},
	"chevreuil": {"nom": "chevreuil", "pv": 40, "marche": 1.4, "course": 8.5, "sens": 16.9, "fuite": 36.4,
		"groupe": [1, 3], "actif": [0.6, 1.5, 0.7], "comportement": "proie",
		"habitat": {ZoneData.T_FEUILLUS: 18.0, ZoneData.T_MIXTE: 18.0, ZoneData.T_RESINEUX: 10.0, ZoneData.T_CHAMP: 8.0, ZoneData.T_PRAIRIE: 6.0, ZoneData.T_LANDE: 6.0},
		"butin": {"viande": 4, "peau_chevreuil": 1, "os": 2, "tendon": 2}, "depecer": 30},
	"sanglier": {"nom": "sanglier", "pv": 80, "marche": 1.2, "course": 6.5, "sens": 11.7, "fuite": 26.0,
		"groupe": [1, 4], "actif": [1.3, 1.0, 0.5], "comportement": "sanglier", "degats": 15.0, "portee": 1.2,
		"habitat": {ZoneData.T_FEUILLUS: 10.0, ZoneData.T_MIXTE: 10.0, ZoneData.T_CHAMP: 6.0, ZoneData.T_MARAIS: 8.0, ZoneData.T_LANDE: 3.0},
		"butin": {"viande": 6, "peau_sanglier": 1, "defense": 2, "graisse": 2, "os": 2}, "depecer": 40},
	"renard": {"nom": "renard", "pv": 20, "marche": 1.3, "course": 7.0, "sens": 13.0, "fuite": 23.4,
		"groupe": [1, 1], "actif": [1.4, 1.2, 0.4], "comportement": "proie",
		"habitat": {ZoneData.T_PRAIRIE: 6.0, ZoneData.T_CHAMP: 6.0, ZoneData.T_FEUILLUS: 5.0, ZoneData.T_MIXTE: 5.0, ZoneData.T_LANDE: 5.0, ZoneData.T_URBAIN: 4.0, ZoneData.T_PARC: 6.0},
		"butin": {"petite_viande": 1, "peau_renard": 1}, "depecer": 15},
	"chien": {"nom": "chien sauvage", "pv": 30, "marche": 1.5, "course": 7.5, "sens": 18.2, "fuite": 31.2,
		"groupe": [3, 6], "actif": [1.0, 1.2, 0.8], "comportement": "meute", "degats": 5.0, "portee": 0.9,
		"habitat": {ZoneData.T_URBAIN: 4.0, ZoneData.T_INDUSTRIEL: 6.0, ZoneData.T_PARC: 2.0, ZoneData.T_CHAMP: 0.5},
		"butin": {"viande": 2, "peau_chien": 1, "os": 1}, "depecer": 20},
	"loup": {"nom": "loup", "pv": 45, "marche": 1.5, "course": 8.0, "sens": 20.8, "fuite": 39.0,
		"groupe": [2, 5], "actif": [1.6, 1.0, 0.25], "comportement": "loup", "degats": 8.0, "portee": 1.0,
		"habitat": {ZoneData.T_FEUILLUS: 0.8, ZoneData.T_MIXTE: 0.8, ZoneData.T_RESINEUX: 1.0, ZoneData.T_LANDE: 0.6},
		"butin": {"viande": 3, "peau_loup": 1, "os": 1, "tendon": 1}, "depecer": 25},
}


static func info(id: String) -> Dictionary:
	return DB.get(id, {})


## Activité selon l'heure (0 = terré, >1 = très actif).
static func activity(id: String, hour: float) -> float:
	var a: Array = DB[id]["actif"]
	if hour < 5.0 or hour >= 22.0:
		return a[0]
	if hour < 8.5 or hour >= 18.5:
		return a[1]
	return a[2]
