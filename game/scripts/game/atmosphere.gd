class_name Atmosphere
extends Node
## Nuit (assombrissement + lumières), pluie et brouillard.

var surv: Survival
var modulate_node: CanvasModulate
var player_light: PointLight2D
var rain: CPUParticles2D
var fog: ColorRect
var _fire_lights := {}          ## Vector2i -> PointLight2D
var _light_tex: Texture2D
var world_root: Node2D

const NIGHT := Color(0.16, 0.18, 0.30)
const DUSK := Color(0.85, 0.65, 0.55)


func setup(world: Node2D, overlay: CanvasLayer, player: Node2D) -> void:
	world_root = world
	modulate_node = CanvasModulate.new()
	world.add_child(modulate_node)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_light_tex = gt
	player_light = PointLight2D.new()
	player_light.texture = _light_tex
	player_light.color = Color(0.75, 0.8, 1.0)
	player.add_child(player_light)
	fog = ColorRect.new()
	fog.color = Color(0.75, 0.78, 0.8, 0.0)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(fog)
	rain = CPUParticles2D.new()
	rain.amount = 260
	rain.lifetime = 0.7
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(800, 10)
	rain.position = Vector2(640, -20)
	rain.direction = Vector2(-0.25, 1)
	rain.spread = 3.0
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 900.0
	rain.initial_velocity_max = 1100.0
	rain.scale_amount_min = 1.0
	rain.scale_amount_max = 1.0
	var line := Image.create(2, 14, false, Image.FORMAT_RGBA8)
	line.fill(Color(0.75, 0.82, 0.95, 0.45))
	rain.texture = ImageTexture.create_from_image(line)
	rain.emitting = false
	overlay.add_child(rain)


func update(fires: Array) -> void:
	var d := surv.daylight()
	var c := NIGHT.lerp(Color.WHITE, d)
	var h := surv.hour()
	if d > 0.0 and d < 1.0:
		c = c.lerp(DUSK, 0.35 * (1.0 - absf(d - 0.5) * 2.0))
	if surv.weather in ["pluie", "brouillard", "nuageux"]:
		c = c.darkened(0.12 if surv.weather == "nuageux" else 0.2)
	modulate_node.color = c
	# Lumière autour du joueur : faible la nuit (lune), forte avec une torche
	var night := 1.0 - d
	player_light.enabled = night > 0.05
	player_light.texture_scale = 2.2 if surv.torche > 0.0 else 1.4
	player_light.energy = night * (1.3 if surv.torche > 0.0 else 0.55)
	player_light.color = Color(1.0, 0.75, 0.45) if surv.torche > 0.0 else Color(0.7, 0.75, 1.0)
	rain.emitting = surv.weather == "pluie"
	fog.color.a = 0.35 if surv.weather == "brouillard" else 0.0
	# Feux allumés
	var seen := {}
	for cell in fires:
		seen[cell] = true
		if not _fire_lights.has(cell):
			var l := PointLight2D.new()
			l.texture = _light_tex
			l.color = Color(1.0, 0.65, 0.35)
			l.texture_scale = 2.6
			l.position = (Vector2(cell) + Vector2(0.5, 0.5)) * Tiles.SIZE
			world_root.add_child(l)
			_fire_lights[cell] = l
		var fl: PointLight2D = _fire_lights[cell]
		fl.energy = 0.4 + night * 1.1 + sin(Time.get_ticks_msec() / 90.0) * 0.08
	for cell in _fire_lights.keys():
		if not seen.has(cell):
			_fire_lights[cell].queue_free()
			_fire_lights.erase(cell)
