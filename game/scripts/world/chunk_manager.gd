class_name ChunkManager
extends Node2D
## Charge les morceaux autour de la caméra et décharge ceux qui s'éloignent.
## La fabrication d'un morceau se fait sur un autre cœur (WorkerThreadPool),
## une à la fois ; l'image principale ne fait que poser les tuiles prêtes.
## Fournit les drapeaux de déplacement au joueur.

const CHUNK := WorldGen.CHUNK
const TILE := Tiles.SIZE

var zone: ZoneData
var gen: WorldGen
var mods: WorldMods            ## changements du joueur (fournis par main.gd)
var ground: TileMapLayer
var shade_root: Node2D
var entities: Node2D        ## parent trié en Y : décor + joueur
var decor: TileMapLayer
var wang_layers: Array[TileMapLayer] = []   ## une couche par transition, décalée d'une demi-case
var _wang_of_kind := PackedInt32Array()     ## Tiles.G_* -> index de couche, -1 = aucune, -2 = herbe
var _has_base := false
var _walls_wang := false
var _cliff := {}          ## index de couche -> table de correspondance (jeux en relief)

var _chunks := {}           # Vector2i -> WorldGen.ChunkData
var _shades := {}           # Vector2i -> Sprite2D
var _queue: Array[Vector2i] = []
var _shade_material: CanvasItemMaterial
var last_gen_ms := 0.0      ## fabrication (en arrière-plan)
var max_gen_ms := 0.0
var last_apply_ms := 0.0    ## pose des tuiles (image principale)
var max_apply_ms := 0.0

var _task := -1             # tâche de fabrication en cours
var _task_key := Vector2i.ZERO
var _task_result: WorldGen.ChunkData
var _task_ms := 0.0


func setup(z: ZoneData, seed_value: int) -> void:
	zone = z
	gen = WorldGen.new(z, seed_value)
	var ts := Tiles.build_tileset()
	_has_base = ts.has_source(Tiles.SRC_BASE)
	if _has_base:
		# Herbe de base : une seule image répétée sur toute la zone (aucun coût par morceau)
		var grass := Sprite2D.new()
		grass.name = "Herbe"
		grass.texture = load(Tiles.BASE_PATH)
		grass.centered = false
		grass.region_enabled = true
		grass.region_rect = Rect2(0, 0, zone.width * Tiles.SIZE, zone.height * Tiles.SIZE)
		grass.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		add_child(grass)
	_wang_of_kind.resize(Tiles.GROUND_COUNT)
	_wang_of_kind.fill(-1)
	for i in Tiles.WANG_NAMES.size():
		var layer := TileMapLayer.new()
		layer.name = "Transition_" + Tiles.WANG_NAMES[i]
		layer.tile_set = ts
		layer.position = Vector2(-Tiles.SIZE / 2.0, -Tiles.SIZE / 2.0)
		add_child(layer)
		wang_layers.append(layer)
	if _has_base:
		for k in Tiles.WANG_OF_GROUND:
			var name: String = Tiles.WANG_OF_GROUND[k]
			if name == "":
				_wang_of_kind[k] = -2
			else:
				var i := Tiles.WANG_NAMES.find(name)
				if ts.has_source(Tiles.SRC_WANG + i):
					_wang_of_kind[k] = i
	_walls_wang = _has_base and _wang_of_kind[Tiles.G_MUR] >= 0
	for i in Tiles.WANG_NAMES.size():
		var lk := Tiles.cliff_lookup(Tiles.WANG_NAMES[i])
		if not lk.is_empty():
			_cliff[i] = lk
	# Tuiles pleines par-dessus (provisoires, ponts, rails, sols de bâtiments)
	ground = TileMapLayer.new()
	ground.name = "Sol"
	ground.tile_set = ts
	add_child(ground)
	shade_root = Node2D.new()
	shade_root.name = "Relief"
	add_child(shade_root)
	_shade_material = CanvasItemMaterial.new()
	_shade_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	entities = Node2D.new()
	entities.name = "Entites"
	entities.y_sort_enabled = true
	add_child(entities)
	decor = TileMapLayer.new()
	decor.name = "Decor"
	decor.tile_set = ts
	decor.y_sort_enabled = true
	entities.add_child(decor)


## Remet le monde à zéro avec une nouvelle graine (nouvelle partie).
func reset(seed_value: int) -> void:
	_finish_task(false)
	for key in _chunks.keys():
		_unload(key)
	_queue.clear()
	gen = WorldGen.new(zone, seed_value)


func chunk_of_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(cell.x / float(CHUNK)), floori(cell.y / float(CHUNK)))


## Charge tout de suite le morceau qui contient cette case.
func ensure_cell(cell: Vector2i) -> WorldGen.ChunkData:
	var key := chunk_of_cell(cell)
	if not _chunks.has(key):
		_finish_task(true)
		if not _chunks.has(key):
			var t0 := Time.get_ticks_usec()
			var c := gen.generate(key.x, key.y)
			_apply(key, c, (Time.get_ticks_usec() - t0) / 1000.0)
	return _chunks[key]


func flags_at(cell: Vector2i) -> int:
	if not zone.inside(cell.x, cell.y):
		return WorldGen.F_BLOCK
	var key := chunk_of_cell(cell)
	var c: WorldGen.ChunkData = _chunks.get(key)
	if c == null:
		return WorldGen.F_BLOCK  # pas encore chargé : on attend
	return c.flags[(cell.y - key.y * CHUNK) * CHUNK + (cell.x - key.x * CHUNK)]


func building_at(cell: Vector2i) -> Dictionary:
	var c: WorldGen.ChunkData = _chunks.get(chunk_of_cell(cell))
	if c:
		for b in c.buildings:
			if (b["rect"] as Rect2i).has_point(cell):
				return b
	return {}


## Appelé à chaque image avec la zone visible (en pixels monde).
func update_view(view: Rect2) -> void:
	var margin := float(CHUNK * TILE) * 0.5
	var r := view.grow(margin)
	var a := Vector2i(floori(r.position.x / (CHUNK * TILE)), floori(r.position.y / (CHUNK * TILE)))
	var b := Vector2i(floori(r.end.x / (CHUNK * TILE)), floori(r.end.y / (CHUNK * TILE)))
	var max_c := Vector2i((zone.width - 1) / CHUNK, (zone.height - 1) / CHUNK)
	a = a.clamp(Vector2i.ZERO, max_c)
	b = b.clamp(Vector2i.ZERO, max_c)
	var wanted := {}
	var center := view.get_center() / float(CHUNK * TILE)
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var key := Vector2i(cx, cy)
			wanted[key] = true
			if not _chunks.has(key) and not _queue.has(key):
				_queue.append(key)
	# Les plus proches d'abord
	_queue.sort_custom(func(p, q): return (Vector2(p) - center).length_squared() < (Vector2(q) - center).length_squared())
	# Poser un morceau prêt, puis lancer la fabrication du suivant
	if _task != -1 and WorkerThreadPool.is_task_completed(_task):
		_finish_task(true)
	if _task == -1:
		while not _queue.is_empty():
			var key: Vector2i = _queue.pop_front()
			if wanted.has(key) and not _chunks.has(key):
				_start_task(key)
				break
	# Décharger ce qui est loin (avec une marge pour éviter les allers-retours)
	for key in _chunks.keys():
		if key.x < a.x - 1 or key.x > b.x + 1 or key.y < a.y - 1 or key.y > b.y + 1:
			_unload(key)
	_queue = _queue.filter(func(k): return wanted.has(k))


func loaded_count() -> int:
	return _chunks.size()


func _start_task(key: Vector2i) -> void:
	_task_key = key
	_task_result = null
	_task = WorkerThreadPool.add_task(_generate_in_thread.bind(key, gen))


func _generate_in_thread(key: Vector2i, g: WorldGen) -> void:
	var t0 := Time.get_ticks_usec()
	var c := g.generate(key.x, key.y)
	if _has_base:
		c.dual = _compute_dual(c, key.x * CHUNK, key.y * CHUNK)
	_task_ms = (Time.get_ticks_usec() - t0) / 1000.0
	_task_result = c


## Attend la tâche en cours ; pose le morceau si apply est vrai.
func _finish_task(apply: bool) -> void:
	if _task == -1:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var c := _task_result
	_task_result = null
	if apply and c != null and not _chunks.has(_task_key):
		_apply(_task_key, c, _task_ms)


func _apply(key: Vector2i, c: WorldGen.ChunkData, gen_ms: float) -> void:
	var t0 := Time.get_ticks_usec()
	var x0 := key.x * CHUNK
	var y0 := key.y * CHUNK
	_apply_structures(c)
	if _has_base:
		if c.dual.is_empty():
			c.dual = _compute_dual(c, x0, y0)
		_apply_dual(c)
	for ly in CHUNK:
		for lx in CHUNK:
			var i := ly * CHUNK + lx
			var g := c.ground[i]
			var cell := Vector2i(x0 + lx, y0 + ly)
			var kind := g / Tiles.VARIANTS
			if not _has_base or _wang_of_kind[kind] == -1:
				ground.set_cell(cell, Tiles.SRC_GROUND, Vector2i(g % Tiles.VARIANTS, kind))
			var d := c.decor[i]
			if d in Tiles.WALL_DECOR and _walls_wang:
				d = -1
			if d >= 0:
				_draw_decor(cell, d)
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(c.shade)
	s.region_enabled = true
	s.region_rect = Rect2(1, 1, CHUNK, CHUNK)
	s.centered = false
	s.scale = Vector2(TILE, TILE)
	s.position = Vector2(x0 * TILE, y0 * TILE)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.material = _shade_material
	shade_root.add_child(s)
	_shades[key] = s
	_chunks[key] = c
	last_gen_ms = gen_ms
	max_gen_ms = maxf(max_gen_ms, gen_ms)
	last_apply_ms = (Time.get_ticks_usec() - t0) / 1000.0
	max_apply_ms = maxf(max_apply_ms, last_apply_ms)


## (Calculé en arrière-plan.) Chaque transition sur la grille décalée : la case double
## (X, Y) a pour coins les cases (X-1, Y-1), (X, Y-1), (X-1, Y), (X, Y).
func _compute_dual(c: WorldGen.ChunkData, x0: int, y0: int) -> Array:
	var out: Array = []
	for i in wang_layers.size():
		out.append(PackedInt32Array())
	const K := CHUNK + 1
	var corners := PackedInt32Array([0, 0, 0, 0])
	for dy in CHUNK:
		for dx in CHUNK:
			var r := dy * K + dx
			corners[0] = _wang_of_kind[c.kinds[r]]
			corners[1] = _wang_of_kind[c.kinds[r + 1]]
			corners[2] = _wang_of_kind[c.kinds[r + K]]
			corners[3] = _wang_of_kind[c.kinds[r + K + 1]]
			for j in 4:
				var layer := corners[j]
				if layer < 0:
					continue
				var seen := false
				for q in j:
					if corners[q] == layer:
						seen = true
				if seen:
					continue
				if _cliff.has(layer):
					continue
				var mask := (8 if corners[0] == layer else 0) | (4 if corners[1] == layer else 0) \
					| (2 if corners[2] == layer else 0) | (1 if corners[3] == layer else 0)
				out[layer].append_array([x0 + dx, y0 + dy, mask])
	# Jeux en relief (murs) : un coin sous un dessus de mur porte la face du mur
	var zone_r := Rect2i(x0, y0, CHUNK, CHUNK)
	if not zone.real:
		if c.buildings.is_empty():
			return out
		zone_r = Rect2i()
		for b in c.buildings:
			var br: Rect2i = b["rect"]
			zone_r = br if zone_r.size == Vector2i.ZERO else zone_r.merge(br)
		zone_r = zone_r.grow(2).intersection(Rect2i(x0, y0, CHUNK, CHUNK))
	for layer in _cliff:
		var lookup: Dictionary = _cliff[layer]
		for dy in range(zone_r.position.y - y0, zone_r.end.y - y0):
			for dx in range(zone_r.position.x - x0, zone_r.end.x - x0):
				var r := dy * K + dx
				var code := 0
				var any_wall := false
				for j in 4:
					var ri: int = r + (1 if j % 2 == 1 else 0) + (K if j >= 2 else 0)
					var st := 0
					if _wang_of_kind[c.kinds[ri]] == layer:
						st = 1
					elif ri >= K and _wang_of_kind[c.kinds[ri - K]] == layer:
						st = 2
					if st != 0:
						any_wall = true
					code = code * 3 + st
				if not any_wall:
					continue
				var idx: int = lookup.get(code, -1)
				if idx < 0:
					# combinaison absente : on ignore la face
					var c2 := 0
					var p := 1
					var tmp := code
					for j in 4:
						var st2 := tmp % 3
						tmp /= 3
						c2 += (st2 if st2 == 1 else 0) * p
						p *= 3
					idx = lookup.get(c2, -1)
				if idx >= 0:
					out[layer].append_array([x0 + dx, y0 + dy, idx])
	return out


## Pose les tuiles de transition déjà choisies (image principale).
func _apply_dual(c: WorldGen.ChunkData) -> void:
	for layer in c.dual.size():
		var arr: PackedInt32Array = c.dual[layer]
		var tl := wang_layers[layer]
		var src := Tiles.SRC_WANG + layer
		for k in range(0, arr.size(), 3):
			tl.set_cell(Vector2i(arr[k], arr[k + 1]), src, Vector2i(arr[k + 2], 0))


func _draw_decor(cell: Vector2i, d: int) -> void:
	if d < 0:
		decor.erase_cell(cell)
		return
	var objs: Array = Tiles.decor_sources.get(d, [])
	if not objs.is_empty():
		var names: Array = Tiles.DECOR_VARIANTS[d]
		var name: String = Tiles.decor_name(d, cell)
		# la source correspond à la variante si elle existe, sinon la première disponible
		var idx := mini(names.find(name), objs.size() - 1)
		decor.set_cell(cell, objs[maxi(idx, 0)] if objs.size() == names.size() else objs[Tiles.decor_pick(d, cell) % objs.size()], Vector2i.ZERO)
	elif d < Tiles.DECOR_COUNT:
		decor.set_cell(cell, Tiles.SRC_DECOR, Tiles.decor_coords(d))
	else:
		decor.erase_cell(cell)


func _chunk_at(cell: Vector2i) -> WorldGen.ChunkData:
	return _chunks.get(chunk_of_cell(cell))


## Décor présent sur une case (-1 si rien ou morceau non chargé).
func decor_at(cell: Vector2i) -> int:
	var c := _chunk_at(cell)
	if c == null:
		return -1
	return c.decor[(cell.y - c.cy * CHUNK) * CHUNK + (cell.x - c.cx * CHUNK)]


## Type de sol (Tiles.G_*) d'une case chargée, -1 sinon.
func ground_at(cell: Vector2i) -> int:
	var c := _chunk_at(cell)
	if c == null:
		return -1
	return c.ground[(cell.y - c.cy * CHUNK) * CHUNK + (cell.x - c.cx * CHUNK)] / Tiles.VARIANTS


## Pose ou retire un décor (constructions) et met à jour l'affichage et les obstacles.
func set_decor(cell: Vector2i, d: int, flag := WorldGen.F_TRUNK) -> void:
	var c := _chunk_at(cell)
	if c == null:
		return
	var i := (cell.y - c.cy * CHUNK) * CHUNK + (cell.x - c.cx * CHUNK)
	c.decor[i] = d
	if d < 0:
		c.flags[i] &= ~(WorldGen.F_TRUNK | WorldGen.F_BLOCK)
	else:
		c.flags[i] |= flag
	_draw_decor(cell, d)


const STRUCT_DECOR := {"feu": Tiles.D_FEU_ETEINT, "abri": Tiles.D_ABRI, "coffre": Tiles.D_COFFRE}


func structure_decor(st: Dictionary) -> int:
	if st.get("type", "") == "feu":
		return Tiles.D_FEU_ALLUME if float(st.get("feu", 0)) > 0.0 else Tiles.D_FEU_ETEINT
	return STRUCT_DECOR.get(st.get("type", ""), -1)


func _apply_structures(c: WorldGen.ChunkData) -> void:
	if mods == null:
		return
	for cell in mods.structures_in(Rect2i(c.cx * CHUNK, c.cy * CHUNK, CHUNK, CHUNK)):
		var i: int = (cell.y - c.cy * CHUNK) * CHUNK + (cell.x - c.cx * CHUNK)
		c.decor[i] = structure_decor(mods.structure_at(cell))
		c.flags[i] |= WorldGen.F_TRUNK


func _unload(key: Vector2i) -> void:
	var x0 := key.x * CHUNK
	var y0 := key.y * CHUNK
	for ly in CHUNK:
		for lx in CHUNK:
			var cell := Vector2i(x0 + lx, y0 + ly)
			ground.erase_cell(cell)
			decor.erase_cell(cell)
			for layer in wang_layers:
				layer.erase_cell(cell)
	if _shades.has(key):
		_shades[key].queue_free()
		_shades.erase(key)
	_chunks.erase(key)
