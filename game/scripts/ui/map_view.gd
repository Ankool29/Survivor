class_name MapView
extends Control
## Carte de la zone : zoom (pincement, molette, boutons), déplacement au doigt.
## Plus on zoome, plus les noms de lieux et les lieux notables apparaissent.

const ZOOM_MAX := 24.0

var zone: ZoneData
var mods: WorldMods            ## constructions du joueur (abris, feux, coffres)
var player_cell := Vector2.ZERO
var zoom := 1.0
var center := Vector2.ZERO          ## centre de la vue, en cases
var _font: Font
var _touches := {}
var _pinch := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	visible = false
	var bar := VBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.position = Vector2(-SurvivalHud.RIGHT_MARGIN - 110, 12)
	bar.size = Vector2(110, 0)
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	bar.add_child(_btn("Fermer", func(): visible = false))
	bar.add_child(_btn("+", func(): set_zoom(zoom * 1.6)))
	bar.add_child(_btn("−", func(): set_zoom(zoom / 1.6)))
	bar.add_child(_btn("Moi", _recenter))


func _btn(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(110, 46)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(action)
	return b


func _recenter() -> void:
	center = player_cell
	queue_redraw()


## Ouvre la carte centrée sur le joueur, avec un zoom qui montre les environs.
func open() -> void:
	center = player_cell
	if zoom < 1.0:
		zoom = 1.0
	visible = true
	queue_redraw()


func set_zoom(z: float) -> void:
	zoom = clampf(z, 1.0, ZOOM_MAX)
	queue_redraw()


## Pixels écran par case.
func _k() -> float:
	return size.y / float(zone.height) * zoom


func _to_screen(cell: Vector2) -> Vector2:
	return size * 0.5 + (cell - center) * _k()


func _gui_input(event: InputEvent) -> void:
	if zone == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch = 0.0
		accept_event()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch > 0.0:
				set_zoom(zoom * d / _pinch)
			_pinch = d
		else:
			center -= event.relative / _k()
			center = center.clamp(Vector2.ZERO, Vector2(zone.width, zone.height))
			queue_redraw()
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(zoom * 1.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(zoom / 1.25)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.07, 1.0))
	if zone == null:
		return
	var k := _k()
	var top_left := _to_screen(Vector2.ZERO)
	var full := Rect2(top_left, Vector2(zone.width, zone.height) * k)
	if zone.map_texture:
		draw_texture_rect(zone.map_texture, full, false)
	else:
		draw_rect(full, Color8(90, 110, 70))
	# Lieux notables (à partir d'un certain zoom)
	if zoom >= 6.0:
		for p in zone.pois:
			var pos := _to_screen(Vector2(float(p["x"]), float(p["y"])))
			if not Rect2(Vector2.ZERO, size).has_point(pos):
				continue
			draw_circle(pos, 3, Color8(250, 210, 90))
			if zoom >= 10.0:
				var t: String = p["name"] if p["name"] != "" else String(p["kind"]).replace("_", " ")
				_label(pos + Vector2(5, 4), t, 11, Color8(250, 230, 170))
	# Noms : villes toujours, villages puis hameaux en zoomant
	for p in zone.places:
		var kind: String = p["kind"]
		var show := kind in ["city", "town"] or (kind in ["village", "suburb"] and zoom >= 2.5) \
			or (kind in ["hamlet", "locality", "isolated_dwelling"] and zoom >= 12.0)
		if not show:
			continue
		var pos := _to_screen(Vector2(float(p["x"]), float(p["y"])))
		if not Rect2(Vector2(-50, -20), size + Vector2(100, 40)).has_point(pos):
			continue
		var fs := 16 if kind in ["city", "town"] else (13 if kind in ["village", "suburb"] else 11)
		draw_circle(pos, 2.5, Color.WHITE)
		_label(pos + Vector2(4, -3), p["name"], fs, Color.WHITE)
	# Joueur
	_draw_structures()
	var me := _to_screen(player_cell)
	draw_circle(me, 8, Color(0, 0, 0, 0.6))
	draw_circle(me, 6, Color8(255, 80, 60))
	# Échelle
	var km := 1.0
	for cand in [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0]:
		if cand * 1000.0 / zone.cell_m * k > 60.0:
			km = cand
			break
	var px := km * 1000.0 / zone.cell_m * k
	var y := size.y - 36
	draw_line(Vector2(16, y), Vector2(16 + px, y), Color.WHITE, 2)
	_label(Vector2(16, y - 6), ("%d m" % int(km * 1000)) if km < 1.0 else ("%d km" % int(km)), 12, Color.WHITE)
	var credit := "© contributeurs OpenStreetMap (ODbL)"
	if zone.sources.size() > 1:
		credit += " · Relief : " + String(zone.sources[1])
	_label(Vector2(16, size.y - 10), credit, 10, Color(1, 1, 1, 0.6))
	_label(Vector2(16, 26), zone.title, 18, Color.WHITE)


func _label(pos: Vector2, text: String, fs: int, col: Color) -> void:
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Abris, feux et coffres construits : toujours visibles, nommés en zoomant.
func _draw_structures() -> void:
	if mods == null:
		return
	for k in mods.structures:
		var st: Dictionary = mods.structures[k]
		var t := String(st.get("type", ""))
		var pos := _to_screen(Vector2(WorldMods.cell_of(k)) + Vector2(0.5, 0.5))
		if not Rect2(Vector2(-20, -20), size + Vector2(40, 40)).has_point(pos):
			continue
		match t:
			"abri":
				var tri := PackedVector2Array([pos + Vector2(0, -11), pos + Vector2(10, 7), pos + Vector2(-10, 7)])
				draw_colored_polygon(tri, Color8(150, 105, 55))
				draw_polyline(tri + PackedVector2Array([tri[0]]), Color.BLACK, 2.0)
				draw_line(pos + Vector2(0, -2), pos + Vector2(0, 7), Color.BLACK, 2.0)
				if zoom >= 3.0:
					_label(pos + Vector2(13, 5), "Abri", 13, Color8(255, 225, 170))
			"feu":
				if zoom >= 3.0:
					draw_circle(pos, 5, Color.BLACK)
					draw_circle(pos, 3.5, Color8(255, 140, 40) if float(st.get("feu", 0)) > 0.0 else Color8(120, 110, 100))
			"coffre":
				if zoom >= 3.0:
					draw_rect(Rect2(pos - Vector2(5, 4), Vector2(10, 8)), Color8(120, 80, 40))
					draw_rect(Rect2(pos - Vector2(5, 4), Vector2(10, 8)), Color.BLACK, false, 1.5)
