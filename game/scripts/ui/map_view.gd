class_name MapView
extends Control
## Carte de la zone (aperçu fabriqué avec les données) et position du joueur.
## Étape 1 : toute la zone est visible, pour tester. Toucher pour fermer.

var zone: ZoneData
var player_cell := Vector2.ZERO
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	visible = false


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		visible = false
		accept_event()


func _map_rect() -> Rect2:
	var s := size
	var side := minf(s.x, s.y) - 24.0
	return Rect2(Vector2((s.x - side) * 0.5, 12), Vector2(side, side))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.07, 0.92))
	if zone == null:
		return
	var r := _map_rect()
	if zone.map_texture:
		draw_texture_rect(zone.map_texture, r, false)
	else:
		draw_rect(r, Color8(90, 110, 70))
	var k := r.size.x / zone.width
	# Noms des villes et bourgs
	for p in zone.places:
		var kind: String = p["kind"]
		if kind not in ["city", "town", "village"]:
			continue
		var pos := r.position + Vector2(float(p["x"]), float(p["y"])) * k
		var fs := 15 if kind != "village" else 11
		draw_circle(pos, 2.5 if kind != "village" else 1.5, Color.WHITE)
		draw_string_outline(_font, pos + Vector2(4, -3), p["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.8))
		draw_string(_font, pos + Vector2(4, -3), p["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# Joueur
	var me := r.position + player_cell * k
	draw_circle(me, 7, Color(0, 0, 0, 0.6))
	draw_circle(me, 5, Color8(255, 80, 60))
	var lines: Array[String] = ["© contributeurs OpenStreetMap (ODbL)"]
	if zone.sources.size() > 1:
		lines.append("Relief : " + String(zone.sources[1]))
	for i in lines.size():
		draw_string(_font, Vector2(12, size.y - 10 - 14 * (lines.size() - 1 - i)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, r.position.x - 20, 10, Color(1, 1, 1, 0.6))
	draw_string(_font, Vector2(12, 24), zone.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(_font, Vector2(12, 46), "Toucher pour fermer", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))
