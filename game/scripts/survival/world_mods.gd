class_name WorldMods
extends RefCounted
## Changements faits par le joueur dans le monde (sauvegardés) :
## - récoltes : case -> minute de jeu où la plante a repoussé ;
## - fouilles : meubles et épaves déjà fouillés -> ce qu'il y reste (cases d'inventaire) ;
## - constructions : case -> {type, feu (minutes restantes), objets (coffre)}.

const REGROW_MIN := 3 * 1440.0   ## une plante repousse en 3 jours

var harvested := {}
var searched := {}
var structures := {}


static func key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


static func cell_of(k: String) -> Vector2i:
	var p := k.split(",")
	return Vector2i(int(p[0]), int(p[1]))


func can_harvest(c: Vector2i, now: float) -> bool:
	return float(harvested.get(key(c), -1.0)) <= now


func harvest(c: Vector2i, now: float, days := 1.0) -> void:
	harvested[key(c)] = now + REGROW_MIN * days


func is_searched(c: Vector2i) -> bool:
	return searched.has(key(c))


func mark_searched(c: Vector2i, content: Array) -> void:
	searched[key(c)] = content


func content_of(c: Vector2i) -> Array:
	var v = searched.get(key(c), [])
	return v if v is Array else []


func structure_at(c: Vector2i) -> Dictionary:
	return structures.get(key(c), {})


func structures_in(rect: Rect2i) -> Array:
	var out := []
	for k in structures:
		var c := cell_of(k)
		if rect.has_point(c):
			out.append(c)
	return out


func to_data() -> Dictionary:
	# On oublie les récoltes déjà repoussées pour garder la sauvegarde légère
	return {"harvested": harvested, "searched": searched, "structures": structures}


func from_data(d: Dictionary, now: float) -> void:
	harvested = {}
	for k in d.get("harvested", {}):
		if float(d["harvested"][k]) > now:
			harvested[k] = float(d["harvested"][k])
	searched = d.get("searched", {})
	structures = d.get("structures", {})
