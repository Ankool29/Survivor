class_name Equipment
extends RefCounted
## Ce que le joueur porte (étape 4) : un objet par emplacement, {id, usure} ou vide.

signal changed

var slots := {}


func _init() -> void:
	for s in Items.SLOTS:
		slots[s] = {}


func item(slot: String) -> String:
	return String(slots.get(slot, {}).get("id", ""))


func is_worn(id: String) -> bool:
	for s in slots:
		if item(s) == id:
			return true
	return false


## Somme d'un champ sur tout ce qui est porté (chaleur, protection, bruit…).
func total(field: String) -> float:
	var t := 0.0
	for s in slots:
		var id := item(s)
		if id != "":
			t += float(Items.info(id).get(field, 0.0))
	return t


## Part de pluie arrêtée : le torse compte le plus.
func impermeability() -> float:
	var k := {"torse": 0.65, "tete": 0.15, "jambes": 0.15, "pieds": 0.05}
	var t := 0.0
	for s in k:
		var id := item(s)
		if s == "tete" and id == "" and Items.info(item("torse")).get("capuche", false):
			id = item("torse")             # la capuche du ciré couvre la tête
		if id != "":
			t += float(k[s]) * float(Items.info(id).get("imper", 0.0))
	return t


func protection() -> float:
	return minf(0.6, total("protection"))


## Nombre de cases du sac porté (12 sans sac).
func bag_slots() -> int:
	var id := item("dos")
	return int(Items.info(id).get("cases", 12)) if id != "" else 12


## Charge supportée en kg (25 kg sans sac).
func capacity() -> float:
	var id := item("dos")
	return 25.0 + (float(Items.info(id).get("charge", 0.0)) if id != "" else 0.0)


func worn_weight() -> float:
	var w := 0.0
	for s in slots:
		if item(s) != "":
			w += Items.weight(item(s)) * 0.25     # porté, ça pèse peu
	return w


## Apparence du personnage : celle du vêtement de torse.
func outfit() -> String:
	return String(Items.info(item("torse")).get("tenue", "civil"))


## Met un objet ; renvoie ce qu'il remplace ({} si rien).
func put(id: String, usure := -1) -> Dictionary:
	var slot := String(Items.info(id).get("emplacement", ""))
	var old: Dictionary = slots[slot]
	var u := usure if usure >= 0 else int(Items.info(id).get("usure", 100))
	slots[slot] = {"id": id, "usure": u}
	changed.emit()
	return old


func take(slot: String) -> Dictionary:
	var old: Dictionary = slots[slot]
	slots[slot] = {}
	changed.emit()
	return old


## Use une pièce ; renvoie son nom si elle se déchire.
func wear(slot: String, amount := 1) -> String:
	var s: Dictionary = slots.get(slot, {})
	if s.is_empty():
		return ""
	s["usure"] = int(s["usure"]) - amount
	if int(s["usure"]) <= 0:
		var id := String(s["id"])
		slots[slot] = {}
		changed.emit()
		return Items.name_of(id)
	changed.emit()
	return ""


func wear_all(amount := 1) -> Array:
	var torn := []
	for s in slots.keys():
		if s == "dos" or s == "ceinture":
			continue
		var t := wear(s, amount)
		if t != "":
			torn.append(t)
	return torn


func repair(slot: String) -> void:
	var s: Dictionary = slots.get(slot, {})
	if not s.is_empty():
		s["usure"] = int(Items.info(s["id"]).get("usure", 100))
		changed.emit()


func to_data() -> Dictionary:
	return slots.duplicate(true)


func from_data(d: Dictionary) -> void:
	for s in Items.SLOTS:
		slots[s] = d.get(s, {}) if d.get(s, {}) is Dictionary else {}
	changed.emit()
