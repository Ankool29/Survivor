class_name ChunkManager
extends Node2D
## Charge les morceaux autour de la caméra, au plus un par image, et décharge
## ceux qui s'éloignent. Fournit les drapeaux de déplacement au joueur.

const CHUNK := WorldGen.CHUNK
const TILE := Tiles.SIZE

var zone: ZoneData
var gen: WorldGen
var ground: TileMapLayer
var shade_root: Node2D
var entities: Node2D        ## parent trié en Y : décor + joueur
var decor: TileMapLayer

var _chunks := {}           # Vector2i -> WorldGen.ChunkData
var _shades := {}           # Vector2i -> Sprite2D
var _queue: Array[Vector2i] = []
var _shade_material: CanvasItemMaterial
var last_gen_ms := 0.0
var max_gen_ms := 0.0


func setup(z: ZoneData, seed_value: int) -> void:
	zone = z
	gen = WorldGen.new(z, seed_value)
	var ts := Tiles.build_tileset()
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
		_load(key)
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
	if not _queue.is_empty():
		var key: Vector2i = _queue.pop_front()
		if wanted.has(key) and not _chunks.has(key):
			_load(key)
	# Décharger ce qui est loin (avec une marge pour éviter les allers-retours)
	for key in _chunks.keys():
		if key.x < a.x - 1 or key.x > b.x + 1 or key.y < a.y - 1 or key.y > b.y + 1:
			_unload(key)
	_queue = _queue.filter(func(k): return wanted.has(k))


func loaded_count() -> int:
	return _chunks.size()


func _load(key: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	var c := gen.generate(key.x, key.y)
	var x0 := key.x * CHUNK
	var y0 := key.y * CHUNK
	for ly in CHUNK:
		for lx in CHUNK:
			var i := ly * CHUNK + lx
			var g := c.ground[i]
			var cell := Vector2i(x0 + lx, y0 + ly)
			ground.set_cell(cell, Tiles.SRC_GROUND, Vector2i(g % Tiles.VARIANTS, g / Tiles.VARIANTS))
			var d := c.decor[i]
			if d >= 0:
				decor.set_cell(cell, Tiles.SRC_DECOR, Tiles.decor_coords(d))
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
	last_gen_ms = (Time.get_ticks_usec() - t0) / 1000.0
	max_gen_ms = maxf(max_gen_ms, last_gen_ms)


func _unload(key: Vector2i) -> void:
	var x0 := key.x * CHUNK
	var y0 := key.y * CHUNK
	for ly in CHUNK:
		for lx in CHUNK:
			var cell := Vector2i(x0 + lx, y0 + ly)
			ground.erase_cell(cell)
			decor.erase_cell(cell)
	if _shades.has(key):
		_shades[key].queue_free()
		_shades.erase(key)
	_chunks.erase(key)
