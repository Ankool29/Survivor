class_name Tiles
extends RefCounted
## Catalogue des tuiles et graphismes provisoires.
##
## Sol : planche de 4 colonnes (variantes) x une ligne par type, cases de 32 x 32.
## Décor : planche de 8 colonnes x 2 lignes, éléments de 32 x 64 posés sur la case.
## Si res://assets/tiles/ground.png ou decor.png existent (sprites définitifs),
## ils remplacent les graphismes provisoires, avec la même disposition.

const SIZE := 32
const VARIANTS := 4

# --- Sol (ligne dans la planche)
const G_MER := 0
const G_EAU := 1
const G_SABLE := 2
const G_HERBE_HAUTE := 3
const G_FRICHE := 4
const G_SOL_FEUILLUS := 5
const G_SOL_RESINEUX := 6
const G_LANDE := 7
const G_MARAIS := 8
const G_BETON := 9
const G_BETON_INDUS := 10
const G_ROCHE := 11
const G_ASPHALTE := 12
const G_ASPHALTE_ENVAHI := 13
const G_ROUTE := 14
const G_CHEMIN := 15
const G_RAIL := 16
const G_PONT := 17
const G_SOL_BATIMENT := 18
const G_CARRELAGE := 19
const GROUND_COUNT := 20

# --- Décor (index dans la planche, 8 par ligne)
const D_FEUILLU_A := 0
const D_FEUILLU_B := 1
const D_RESINEUX_A := 2
const D_RESINEUX_B := 3
const D_JEUNE_ARBRE := 4
const D_BUISSON := 5
const D_RONCES := 6
const D_ROCHER := 7
const D_EPAVE := 8
const D_MUR := 9
const D_MUR_BRISE := 10
const D_GRAVATS := 11
const D_ROSEAUX := 12
const D_TOMBE := 13
const D_AJONC := 14
const DECOR_COUNT := 15
# Décors sans équivalent provisoire (affichés seulement avec les sprites)
const D_ARBRE_MORT := 15
const D_SOUCHE := 16
const D_SAULE := 17
const D_POTEAU := 18
const DECOR_COLS := 8

## Objets de décor PixelLab (tailles variées) : res://assets/decor/<nom>.png,
## décrits dans res://assets/decor/decor.json ({nom: {w, h, foot}}).
## Chaque type de décor D_* a une ou plusieurs variantes, tirées au hasard par case.
const DECOR_VARIANTS := {
	D_FEUILLU_A: ["chene_a", "chene_b", "chataignier"],
	D_FEUILLU_B: ["hetre_a", "hetre_b", "chene_a"],
	D_RESINEUX_A: ["pin_a", "pin_b"],
	D_RESINEUX_B: ["sapin_a", "sapin_b"],
	D_JEUNE_ARBRE: ["bouleau_a", "bouleau_b", "aubepine", "pommier"],
	D_BUISSON: ["buisson_a", "buisson_b", "herbes"],
	D_RONCES: ["ronces"],
	D_AJONC: ["ajonc"],
	D_ROSEAUX: ["roseaux", "herbes"],
	D_ROCHER: ["rocher", "cailloux"],
	D_EPAVE: ["voiture", "camionnette"],
	D_GRAVATS: ["gravats", "palette", "rondins"],
	D_TOMBE: ["tombe"],
	D_ARBRE_MORT: ["arbre_mort", "souche_lierre"],
	D_SOUCHE: ["souche", "rondins"],
	D_SAULE: ["saule"],
	D_POTEAU: ["poteau"],
}
const DECOR_META := "res://assets/decor/decor.json"
const SRC_OBJ := 100
## D_* -> liste des sources d'objets disponibles (rempli par build_tileset)
static var decor_sources := {}

const SRC_GROUND := 0
const SRC_DECOR := 1
const SRC_BASE := 2
const SRC_WANG := 10        ## + index dans WANG_NAMES

## Transitions herbe <-> sol (PixelLab), dans l'ordre d'empilement (bas -> haut).
## Fichiers : res://assets/tiles/wang/<nom>.png, 16 tuiles rangées par coins
## (NO=8, NE=4, SO=2, SE=1), herbe transparente. Sol de base : base_herbe.png.
const WANG_NAMES := ["friche", "lande", "feuillus", "resineux", "marais", "chemin",
	"sable", "beton", "asphalte", "eau", "mer"]
const BASE_PATH := "res://assets/tiles/base_herbe.png"

## Transition utilisée par chaque type de sol ("" = l'herbe de base).
## Les sols absents de cette table sont dessinés en tuiles pleines par-dessus.
const WANG_OF_GROUND := {
	G_HERBE_HAUTE: "", G_FRICHE: "friche", G_LANDE: "lande", G_ROCHE: "lande",
	G_SOL_FEUILLUS: "feuillus", G_SOL_RESINEUX: "resineux", G_MARAIS: "marais",
	G_CHEMIN: "chemin", G_RAIL: "chemin", G_SABLE: "sable",
	G_BETON: "beton", G_BETON_INDUS: "beton",
	G_ASPHALTE: "asphalte", G_ASPHALTE_ENVAHI: "asphalte", G_ROUTE: "asphalte",
	G_EAU: "eau", G_PONT: "eau", G_MER: "mer",
}
## Sols toujours dessinés en tuile pleine au-dessus des transitions.
const OVERLAY_GROUNDS := [G_RAIL, G_PONT, G_ROCHE, G_SOL_BATIMENT, G_CARRELAGE]


static func wang_path(name: String) -> String:
	return "res://assets/tiles/wang/%s.png" % name

const GROUND_COLORS := [
	Color8(34, 66, 104), Color8(52, 98, 140), Color8(206, 190, 140), Color8(104, 140, 64),
	Color8(132, 128, 70), Color8(64, 84, 44), Color8(70, 70, 46), Color8(112, 100, 70),
	Color8(72, 92, 70), Color8(118, 116, 108), Color8(100, 98, 96), Color8(120, 118, 110),
	Color8(64, 64, 66), Color8(72, 80, 60), Color8(96, 92, 86), Color8(124, 100, 70),
	Color8(92, 84, 76), Color8(110, 86, 60), Color8(88, 80, 74), Color8(150, 146, 136),
]


static func ground_coords(kind: int, variant: int) -> Vector2i:
	return Vector2i(variant % VARIANTS, kind)


static func decor_coords(index: int) -> Vector2i:
	return Vector2i(index % DECOR_COLS, index / DECOR_COLS)


static func build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(SIZE, SIZE)
	# Sol
	var ground := TileSetAtlasSource.new()
	ground.texture = _texture("res://assets/tiles/ground.png", _make_ground_sheet)
	ground.texture_region_size = Vector2i(SIZE, SIZE)
	ts.add_source(ground, SRC_GROUND)
	for k in GROUND_COUNT:
		for v in VARIANTS:
			ground.create_tile(Vector2i(v, k))
	# Décor (32 x 64, posé sur le bas de la case)
	var decor := TileSetAtlasSource.new()
	decor.texture = _texture("res://assets/tiles/decor.png", _make_decor_sheet)
	decor.texture_region_size = Vector2i(SIZE, SIZE * 2)
	ts.add_source(decor, SRC_DECOR)
	for i in DECOR_COUNT:
		var c := decor_coords(i)
		decor.create_tile(c)
		var td := decor.get_tile_data(c, 0)
		td.texture_origin = Vector2i(0, SIZE / 2)
		td.y_sort_origin = 0
	# Objets PixelLab
	decor_sources = {}
	if FileAccess.file_exists(DECOR_META):
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DECOR_META))
		var src_of := {}
		var next := SRC_OBJ
		for name in meta:
			var path := "res://assets/decor/%s.png" % name
			if not ResourceLoader.exists(path):
				continue
			var m: Dictionary = meta[name]
			var src := TileSetAtlasSource.new()
			src.texture = load(path)
			src.texture_region_size = Vector2i(int(m["w"]), int(m["h"]))
			ts.add_source(src, next)
			src.create_tile(Vector2i.ZERO)
			var td := src.get_tile_data(Vector2i.ZERO, 0)
			# le pied de l'objet tombe à 4 px du bas de la case
			td.texture_origin = Vector2i(0, int(m["foot"]) - int(m["h"]) / 2 - 12)
			src_of[name] = next
			next += 1
		for d in DECOR_VARIANTS:
			var list: Array[int] = []
			for name in DECOR_VARIANTS[d]:
				if src_of.has(name):
					list.append(src_of[name])
			if not list.is_empty():
				decor_sources[d] = list
	# Herbe de base, avec une variante retournée pour casser la répétition
	if ResourceLoader.exists(BASE_PATH):
		var base := TileSetAtlasSource.new()
		base.texture = load(BASE_PATH)
		base.texture_region_size = Vector2i(SIZE, SIZE)
		ts.add_source(base, SRC_BASE)
		base.create_tile(Vector2i.ZERO)
		var alt := base.create_alternative_tile(Vector2i.ZERO)
		base.get_tile_data(Vector2i.ZERO, alt).flip_h = true
	# Transitions
	for i in WANG_NAMES.size():
		var path := wang_path(WANG_NAMES[i])
		if not ResourceLoader.exists(path):
			continue
		var w := TileSetAtlasSource.new()
		w.texture = load(path)
		w.texture_region_size = Vector2i(SIZE, SIZE)
		ts.add_source(w, SRC_WANG + i)
		for m in 16:
			w.create_tile(Vector2i(m, 0))
	return ts


static func _texture(path: String, maker: Callable) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return ImageTexture.create_from_image(maker.call())


# ---------------------------------------------------------------------------
# Graphismes provisoires
# ---------------------------------------------------------------------------

static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


static func _make_ground_sheet() -> Image:
	var img := Image.create(SIZE * VARIANTS, SIZE * GROUND_COUNT, false, Image.FORMAT_RGBA8)
	for k in GROUND_COUNT:
		for v in VARIANTS:
			_paint_ground(img, k, v, Vector2i(v * SIZE, k * SIZE))
	return img


static func _paint_ground(img: Image, k: int, v: int, o: Vector2i) -> void:
	var base: Color = GROUND_COLORS[k]
	var r := _rng(k * 97 + v * 13 + 1)
	img.fill_rect(Rect2i(o, Vector2i(SIZE, SIZE)), base)
	# grain
	var grain := 0.06
	if k in [G_MER, G_EAU, G_BETON, G_ASPHALTE, G_CARRELAGE]:
		grain = 0.03
	for i in 120:
		var p := o + Vector2i(r.randi_range(0, SIZE - 1), r.randi_range(0, SIZE - 1))
		var f := r.randf_range(-grain, grain)
		img.set_pixelv(p, base.lightened(f) if f > 0 else base.darkened(-f))
	match k:
		G_MER, G_EAU:
			for i in 3:
				var y := r.randi_range(3, SIZE - 4)
				var x := r.randi_range(0, SIZE - 10)
				for dx in r.randi_range(5, 9):
					img.set_pixel(o.x + x + dx, o.y + y, base.lightened(0.18))
		G_HERBE_HAUTE, G_FRICHE, G_LANDE, G_MARAIS:
			for i in 26:
				var x := r.randi_range(0, SIZE - 1)
				var y := r.randi_range(2, SIZE - 1)
				var c := base.lightened(r.randf_range(0.05, 0.25))
				img.set_pixel(o.x + x, o.y + y, c)
				img.set_pixel(o.x + x, o.y + y - 1, c.darkened(0.1))
				if k == G_MARAIS and r.randf() < 0.3:
					img.set_pixel(o.x + x, o.y + y, Color8(60, 90, 110))
		G_SOL_FEUILLUS, G_SOL_RESINEUX:
			for i in 14:
				var p := o + Vector2i(r.randi_range(0, SIZE - 2), r.randi_range(0, SIZE - 2))
				var c := Color8(110, 74, 40) if k == G_SOL_FEUILLUS else Color8(90, 62, 36)
				img.set_pixelv(p, c)
				img.set_pixelv(p + Vector2i(1, 0), c.darkened(0.2))
		G_BETON, G_BETON_INDUS, G_ASPHALTE, G_ASPHALTE_ENVAHI, G_ROUTE:
			# fissures
			var x := r.randi_range(4, SIZE - 5)
			var y := 0
			while y < SIZE:
				img.set_pixel(o.x + clampi(x, 0, SIZE - 1), o.y + y, base.darkened(0.35))
				x += r.randi_range(-1, 1)
				y += 1
			if k == G_ASPHALTE_ENVAHI or k == G_BETON:
				for i in 30 if k == G_ASPHALTE_ENVAHI else 10:
					var p := o + Vector2i(r.randi_range(0, SIZE - 1), r.randi_range(0, SIZE - 1))
					img.set_pixelv(p, Color8(84, 120, 52).lightened(r.randf_range(0, 0.2)))
			if k == G_ASPHALTE and v < 2:
				img.fill_rect(Rect2i(o + Vector2i(15, 4 + v * 10), Vector2i(2, 8)), Color8(190, 180, 150).darkened(0.3))
		G_RAIL:
			for y in range(2, SIZE, 6):
				img.fill_rect(Rect2i(o + Vector2i(4, y), Vector2i(24, 3)), Color8(70, 52, 38))
			img.fill_rect(Rect2i(o + Vector2i(9, 0), Vector2i(2, SIZE)), Color8(120, 100, 90))
			img.fill_rect(Rect2i(o + Vector2i(21, 0), Vector2i(2, SIZE)), Color8(120, 100, 90))
		G_PONT:
			for y in range(0, SIZE, 4):
				img.fill_rect(Rect2i(o + Vector2i(0, y), Vector2i(SIZE, 1)), base.darkened(0.3))
		G_CARRELAGE:
			for y in range(0, SIZE, 8):
				img.fill_rect(Rect2i(o + Vector2i(0, y), Vector2i(SIZE, 1)), base.darkened(0.15))
			for x in range(0, SIZE, 8):
				img.fill_rect(Rect2i(o + Vector2i(x, 0), Vector2i(1, SIZE)), base.darkened(0.15))
		G_SOL_BATIMENT:
			for i in 8:
				var p := o + Vector2i(r.randi_range(1, SIZE - 4), r.randi_range(1, SIZE - 4))
				img.fill_rect(Rect2i(p, Vector2i(3, 2)), Color8(130, 120, 110))


static func _make_decor_sheet() -> Image:
	var rows := int(ceil(DECOR_COUNT / float(DECOR_COLS)))
	var img := Image.create(SIZE * DECOR_COLS, SIZE * 2 * rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in DECOR_COUNT:
		var c := decor_coords(i)
		_paint_decor(img, i, Vector2i(c.x * SIZE, c.y * SIZE * 2))
	return img


static func _disc(img: Image, o: Vector2i, center: Vector2, radius: float, col: Color, rng: RandomNumberGenerator, shade := true) -> void:
	for y in range(int(center.y - radius), int(center.y + radius) + 1):
		for x in range(int(center.x - radius), int(center.x + radius) + 1):
			if x < 0 or y < 0 or x >= SIZE or y >= SIZE * 2:
				continue
			var d := Vector2(x, y).distance_to(center)
			if d <= radius:
				var c := col
				if shade:
					var lit := (center.x - x + center.y - y) / (radius * 2.0)
					c = col.lightened(clampf(lit * 0.35, 0, 0.3)) if lit > 0 else col.darkened(clampf(-lit * 0.4, 0, 0.35))
					if rng.randf() < 0.18:
						c = c.darkened(0.15)
				img.set_pixel(o.x + x, o.y + y, c)


static func _paint_decor(img: Image, i: int, o: Vector2i) -> void:
	var r := _rng(1000 + i * 31)
	var shadow := Color(0, 0, 0, 0.28)
	match i:
		D_FEUILLU_A, D_FEUILLU_B, D_JEUNE_ARBRE:
			var big := i != D_JEUNE_ARBRE
			for x in range(8, 24):
				img.set_pixel(o.x + x, o.y + 60, shadow)
				img.set_pixel(o.x + x, o.y + 61, shadow)
			img.fill_rect(Rect2i(o + Vector2i(14, 40), Vector2i(4, 21)), Color8(84, 60, 40))
			var leaf := Color8(58, 110, 46) if i == D_FEUILLU_A else Color8(76, 116, 40)
			if not big:
				leaf = Color8(96, 140, 60)
			var rad := 13.0 if big else 8.0
			var cy := 28.0 if big else 36.0
			_disc(img, o, Vector2(16, cy), rad, leaf, r)
			_disc(img, o, Vector2(10, cy + 4), rad * 0.6, leaf, r)
			_disc(img, o, Vector2(22, cy + 3), rad * 0.6, leaf, r)
		D_RESINEUX_A, D_RESINEUX_B:
			img.fill_rect(Rect2i(o + Vector2i(14, 50), Vector2i(4, 11)), Color8(80, 56, 36))
			var col := Color8(34, 78, 50) if i == D_RESINEUX_A else Color8(42, 86, 56)
			for y in range(6, 54):
				var half := int((y - 4) * 0.26) + 1
				for x in range(16 - half, 16 + half):
					var c := col.lightened(0.15) if x < 16 else col.darkened(0.1)
					if (y + x) % 7 == 0:
						c = c.darkened(0.2)
					img.set_pixel(o.x + x, o.y + y, c)
		D_BUISSON, D_AJONC:
			var col := Color8(70, 108, 48) if i == D_BUISSON else Color8(84, 104, 40)
			_disc(img, o, Vector2(16, 52), 9, col, r)
			_disc(img, o, Vector2(10, 55), 6, col, r)
			_disc(img, o, Vector2(22, 55), 6, col, r)
			if i == D_AJONC:
				for k in 12:
					img.set_pixel(o.x + r.randi_range(8, 24), o.y + r.randi_range(46, 58), Color8(230, 200, 60))
		D_RONCES:
			for k in 40:
				var x := r.randi_range(3, 28)
				var y := r.randi_range(44, 61)
				img.set_pixel(o.x + x, o.y + y, Color8(80, 70, 50).lightened(r.randf() * 0.2))
				img.set_pixel(o.x + x + 1, o.y + y, Color8(60, 90, 40))
		D_ROCHER:
			_disc(img, o, Vector2(16, 53), 9, Color8(128, 126, 118), r)
		D_EPAVE:
			img.fill_rect(Rect2i(o + Vector2i(2, 46), Vector2i(28, 14)), Color8(120, 64, 40))
			img.fill_rect(Rect2i(o + Vector2i(7, 42), Vector2i(16, 8)), Color8(96, 54, 36))
			img.fill_rect(Rect2i(o + Vector2i(9, 43), Vector2i(12, 5)), Color8(40, 50, 56))
			for k in 30:
				img.set_pixel(o.x + r.randi_range(2, 29), o.y + r.randi_range(42, 59), Color8(150, 80, 40))
		D_MUR, D_MUR_BRISE:
			var top := 36 if i == D_MUR else 48
			img.fill_rect(Rect2i(o + Vector2i(0, top), Vector2i(SIZE, 64 - top)), Color8(150, 136, 120))
			img.fill_rect(Rect2i(o + Vector2i(0, top), Vector2i(SIZE, 6)), Color8(176, 164, 150))
			for y in range(top + 8, 64, 6):
				img.fill_rect(Rect2i(o + Vector2i(0, y), Vector2i(SIZE, 1)), Color8(120, 106, 92))
			if i == D_MUR_BRISE:
				for k in 10:
					img.set_pixel(o.x + r.randi_range(0, 31), o.y + top + r.randi_range(0, 2), Color(0, 0, 0, 0))
		D_GRAVATS:
			for k in 9:
				var p := Vector2i(r.randi_range(4, 24), r.randi_range(48, 58))
				img.fill_rect(Rect2i(o + p, Vector2i(r.randi_range(2, 5), r.randi_range(2, 4))), Color8(140, 130, 120).darkened(r.randf() * 0.3))
		D_ROSEAUX:
			for k in 10:
				var x := r.randi_range(4, 28)
				var h := r.randi_range(10, 20)
				img.fill_rect(Rect2i(o + Vector2i(x, 62 - h), Vector2i(1, h)), Color8(120, 130, 70))
				img.fill_rect(Rect2i(o + Vector2i(x, 62 - h), Vector2i(1, 3)), Color8(110, 80, 50))
		D_TOMBE:
			img.fill_rect(Rect2i(o + Vector2i(10, 44), Vector2i(12, 16)), Color8(150, 150, 146))
			img.fill_rect(Rect2i(o + Vector2i(15, 46), Vector2i(2, 8)), Color8(110, 110, 106))
			img.fill_rect(Rect2i(o + Vector2i(12, 48), Vector2i(8, 2)), Color8(110, 110, 106))
