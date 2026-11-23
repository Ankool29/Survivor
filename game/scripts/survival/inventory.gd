class_name Inventory
extends RefCounted
## Cases d'objets : chaque case est {id, n, usure} ou un dictionnaire vide.

signal changed

var slots: Array = []
var clock := Callable()          ## minutes de jeu (pour les denrées qui se gâtent)
var pile_bonus := {}             ## piles agrandies (flèches dans un carquois)


func _init(size := 16) -> void:
	resize(size)


func resize(size: int) -> void:
	while slots.size() < size:
		slots.append({})


## Réduit le nombre de cases : renvoie ce qui ne rentre plus ([{id, n, …}]).
func shrink(size: int) -> Array:
	var over := []
	# tasse d'abord les objets vers le début
	var kept := []
	for s in slots:
		if not s.is_empty():
			kept.append(s)
	slots = []
	for s in kept:
		if slots.size() < size:
			slots.append(s)
		else:
			over.append(s)
	resize(size)
	changed.emit()
	return over


func weight() -> float:
	var w := 0.0
	for s in slots:
		if not s.is_empty():
			w += Items.weight(s["id"]) * int(s["n"])
	return w


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
	var pile := int(pile_bonus.get(id, Items.info(id).get("pile", 10)))
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


## Ajoute une case telle quelle (garde l'usure) ; renvoie ce qui reste ({} si tout est rangé).
func add_stack(st: Dictionary) -> Dictionary:
	if st.has("usure") or st.has("exp"):
		for i in slots.size():
			if slots[i].is_empty():
				slots[i] = {"id": st["id"], "n": int(st.get("n", 1))}
				for k in ["usure", "exp"]:
					if st.has(k):
						slots[i][k] = st[k]
				changed.emit()
				return {}
		return st
	var left := add(st["id"], int(st.get("n", 1)))
	if left == 0:
		return {}
	var r := st.duplicate()
	r["n"] = left
	return r


## Retire une case entière et la renvoie.
func take_slot(i: int) -> Dictionary:
	var s: Dictionary = slots[i]
	slots[i] = {}
	changed.emit()
	return s


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
			if not String(s["id"]).begins_with("peau_"):   # une peau pourrie se jette
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
