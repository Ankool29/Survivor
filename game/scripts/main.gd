extends Node2D
## Scène principale de l'étape 1 : monde test, joueur, interface.

const ZONE := "quimperle"
const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.0

var zone: ZoneData
var world: ChunkManager
var player: Player
var camera: Camera2D
var joystick: TouchStick
var map_view: MapView
var place_label: Label
var debug_label: Label
var run_button: Button
var seed_value := 0
var _place_timer := 0.0
var _touches := {}
var _pinch_dist := 0.0


func _ready() -> void:
	var zone_name := ZONE
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--zone="):
			zone_name = arg.trim_prefix("--zone=")
	zone = ZoneData.load_zone(zone_name)
	_build_ui()
	if zone == null:
		place_label.text = "Données de zone absentes : lancer le workflow « Données de zone » sur GitHub."
		return
	world = ChunkManager.new()
	world.name = "Monde"
	add_child(world)
	seed_value = randi()
	world.setup(zone, seed_value)
	player = Player.new()
	player.name = "Joueur"
	player.world = world
	world.entities.add_child(player)
	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = zone.width * Tiles.SIZE
	camera.limit_bottom = zone.height * Tiles.SIZE
	player.add_child(camera)
	camera.make_current()
	map_view.zone = zone
	new_game(seed_value)


## Nouvelle partie : nouvelle graine, départ tiré au hasard sur la terre ferme.
func new_game(s: int) -> void:
	seed_value = s
	world.reset(s)
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	for attempt in 400:
		var cell := Vector2i(rng.randi_range(40, zone.width - 41), rng.randi_range(40, zone.height - 41))
		var t := zone.t_at(cell.x, cell.y)
		if t == ZoneData.T_MER or t == ZoneData.T_EAU:
			continue
		world.ensure_cell(cell)
		if world.flags_at(cell) & (WorldGen.F_BLOCK | WorldGen.F_TRUNK):
			continue
		player.position = Vector2(cell.x + 0.5, cell.y + 0.7) * Tiles.SIZE
		camera.reset_smoothing()
		break
	_update_place()


func _process(delta: float) -> void:
	if world == null:
		return
	player.input_vector = joystick.vector
	if not camera.is_current():
		camera.make_current()
	var screen := get_viewport_rect().size
	if screen.x < 64 or screen.y < 64:
		screen = Vector2(1280, 576)
	var vp := screen / camera.zoom
	world.update_view(Rect2(player.position - vp * 0.5, vp))
	_place_timer -= delta
	if _place_timer <= 0.0:
		_place_timer = 0.5
		_update_place()
	map_view.player_cell = player.position / Tiles.SIZE
	debug_label.text = "%d img/s · morceaux %d · fabrication %.1f ms (max %.1f) · pose %.1f ms (max %.1f) · écran %dx%d · caméra %s · case %d, %d · alt. %d m" % [
		Engine.get_frames_per_second(), world.loaded_count(), world.last_gen_ms, world.max_gen_ms,
		world.last_apply_ms, world.max_apply_ms, int(get_viewport_rect().size.x), int(get_viewport_rect().size.y),
		"ok" if camera.is_current() else "inactive",
		player.cell().x, player.cell().y, zone.e_at(player.cell().x, player.cell().y)]


func _update_place() -> void:
	var c := player.cell()
	var b := world.building_at(c)
	if not b.is_empty() and b["kind"] != "maison" and b["kind"] != "entrepot":
		var label: String = String(b["kind"]).replace("_", " ").capitalize()
		if b["name"] != "":
			label += " — " + b["name"]
		place_label.text = label
		return
	var p := zone.nearest_place(c.x, c.y)
	if p.is_empty():
		place_label.text = zone.title
	elif p["dist"] < 20.0:
		place_label.text = p["name"]
	else:
		place_label.text = "Près de " + p["name"]


# --- Zoom par pincement (deux doigts hors du joystick)
func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not joystick.is_touch(event.index):
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_dist = 0.0
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _touches.size() == 2:
			var pts: Array = _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_dist > 0.0:
				set_zoom(camera.zoom.x * d / _pinch_dist)
			_pinch_dist = d
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(camera.zoom.x * 1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(camera.zoom.x / 1.15)


func set_zoom(z: float) -> void:
	z = clampf(z, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(z, z)


# --- Interface
func _build_ui() -> void:
	var hud := CanvasLayer.new()
	hud.name = "Interface"
	add_child(hud)
	joystick = TouchStick.new()
	hud.add_child(joystick)
	place_label = Label.new()
	place_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place_label.position = Vector2(-300, 10)
	place_label.size = Vector2(600, 30)
	place_label.add_theme_font_size_override("font_size", 22)
	place_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	place_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(place_label)
	debug_label = Label.new()
	debug_label.position = Vector2(10, 44)
	debug_label.add_theme_font_size_override("font_size", 12)
	debug_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	debug_label.add_theme_constant_override("outline_size", 4)
	hud.add_child(debug_label)
	var bar := VBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.position = Vector2(-150, 10)
	bar.size = Vector2(140, 0)
	bar.add_theme_constant_override("separation", 8)
	hud.add_child(bar)
	bar.add_child(_button("Carte", _open_map))
	run_button = _button("Courir", func(): player.run = run_button.button_pressed)
	run_button.toggle_mode = true
	bar.add_child(run_button)
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 8)
	zoom_row.add_child(_button(" − ", func(): set_zoom(camera.zoom.x / 1.4)))
	zoom_row.add_child(_button(" + ", func(): set_zoom(camera.zoom.x * 1.4)))
	bar.add_child(zoom_row)
	bar.add_child(_button("Nouveau départ", func(): new_game(randi())))
	map_view = MapView.new()
	hud.add_child(map_view)


func _open_map() -> void:
	map_view.visible = true
	map_view.queue_redraw()


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(64, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b
