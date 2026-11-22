class_name Inventory
extends RefCounted
## Cases d'objets : chaque case est {id, n, usure} ou un dictionnaire vide.

signal changed

var slots: Array = []
var clock := Callable()          ## minutes de jeu (pour les denrées qui se gâtent)


func _init(size := 16) -> void:
	resize(size)


func resize(size: int) -> void:
	while slots.size() < size:
		slots.append({})


func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s.get("id", "") == id:
			n += int(s["n"])
	return n


func has(id: String, n := 1) -> bool:
	return count(id) >= n


## Ajoute n objets ; renvoie le nombre qui n'a pas trouvé de place.
func add(id: String, n := 1) -> int:
	var pile := int(Items.info(id).get("pile", 10))
	for s in slots:
		if n <= 0:
			break
		if s.get("id", "") == id and int(s["n"]) < pile:
			var k := mini(pile - int(s["n"]), n)
			s["n"] = int(s["n"]) + k
			n -= k
	for i in slots.size():
		if n <= 0:
			break
		if slots[i].is_empty():
			var k := mini(pile, n)
			slots[i] = {"id": id, "n": k}
			var garde := float(Items.info(id).get("garde", 0))
			if garde > 0.0 and clock.is_valid():
				slots[i]["exp"] = float(clock.call()) + garde
			var usure := int(Items.info(id).get("usure", 0))
			if usure > 0:
				slots[i]["usure"] = usure
			n -= k
	changed.emit()
	return n


func remove(id: String, n := 1) -> bool:
	if not has(id, n):
		return false
	for i in range(slots.size() - 1, -1, -1):
		if n <= 0:
			break
		var s: Dictionary = slots[i]
		if s.get("id", "") == id:
			var k := mini(int(s["n"]), n)
			s["n"] = int(s["n"]) - k
			n -= k
			if int(s["n"]) <= 0:
				slots[i] = {}
	changed.emit()
	return true


## Use un outil d'un cran ; renvoie faux s'il casse.
func wear(id: String) -> bool:
	for i in slots.size():
		var s: Dictionary = slots[i]
		if s.get("id", "") == id:
			s["usure"] = int(s.get("usure", 1)) - 1
			if int(s["usure"]) <= 0:
				slots[i] = {}
				changed.emit()
				return false
			changed.emit()
			return true
	return false


## Les denrées périmées deviennent de la nourriture avariée ; renvoie le nombre gâté.
func spoil(now: float) -> int:
	var n := 0
	for i in slots.size():
		var s: Dictionary = slots[i]
		if s.has("exp") and float(s["exp"]) < now:
			var k := int(s["n"])
			slots[i] = {}
			n += k
			add("viande_avariee", k)
	if n > 0:
		changed.emit()
	return n


func free_slots() -> int:
	var n := 0
	for s in slots:
		if s.is_empty():
			n += 1
	return n


func to_data() -> Array:
	return slots.duplicate(true)


func from_data(data: Array) -> void:
	slots = []
	for s in data:
		slots.append(s if s is Dictionary else {})
	changed.emit()
