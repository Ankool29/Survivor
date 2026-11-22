class_name SurvivalHud
extends Control
## Jauges, horloge et météo, messages, bouton d'action contextuel.

signal action_pressed
signal bag_pressed
signal sleep_pressed
signal shoot_down
signal shoot_up

var surv: Survival
var action_button: Button
var bag_button: Button
var sleep_button: Button
var shoot_button: Button
var crouching := false
var clock: Label
var _msg: Label
var _msg_time := 0.0
var _font: Font

const GAUGES := [["soif", "Soif", Color8(90, 150, 210)], ["faim", "Faim", Color8(210, 150, 70)],
	["fatigue", "Énergie", Color8(170, 170, 90)], ["chaleur", "Chaleur", Color8(220, 100, 70)],
	["sante", "Santé", Color8(200, 60, 60)]]
const RIGHT_MARGIN := 90.0       ## loin du bord droit (panneau latéral Samsung)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	clock = Label.new()
	clock.add_theme_font_size_override("font_size", 16)
	clock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	clock.add_theme_constant_override("outline_size", 5)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(clock)
	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 18)
	_msg.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_msg.add_theme_constant_override("outline_size", 6)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_msg)
	action_button = _make_button("", 22)
	action_button.pressed.connect(func(): action_pressed.emit())
	bag_button = _make_button("Sac", 18)
	bag_button.pressed.connect(func(): bag_pressed.emit())
	sleep_button = _make_button("Dormir", 16)
	sleep_button.pressed.connect(func(): sleep_pressed.emit())
	shoot_button = _make_button("Tirer", 20)
	shoot_button.button_down.connect(func(): shoot_down.emit())
	shoot_button.button_up.connect(func(): shoot_up.emit())
	shoot_button.visible = false
	resized.connect(_layout)
	_layout()


func _make_button(text: String, size_px: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size_px)
	add_child(b)
	return b


func _layout() -> void:
	var s := size
	clock.position = Vector2(s.x - RIGHT_MARGIN - 460, 8)
	clock.size = Vector2(460, 24)
	_msg.position = Vector2(s.x * 0.2, s.y * 0.30)
	_msg.size = Vector2(s.x * 0.6, 60)
	action_button.position = Vector2(s.x - RIGHT_MARGIN - 220, s.y - 96)
	action_button.size = Vector2(220, 72)
	bag_button.position = Vector2(s.x - RIGHT_MARGIN - 220, s.y - 160)
	bag_button.size = Vector2(104, 52)
	sleep_button.position = Vector2(s.x - RIGHT_MARGIN - 104, s.y - 160)
	sleep_button.size = Vector2(104, 52)
	shoot_button.position = Vector2(s.x - RIGHT_MARGIN - 330, s.y - 96)
	shoot_button.size = Vector2(100, 72)


func show_message(text: String) -> void:
	if text == "":
		return
	_msg.text = text
	_msg_time = 4.0


func set_action(text: String) -> void:
	action_button.visible = text != ""
	action_button.text = text


func _process(delta: float) -> void:
	if _msg_time > 0.0:
		_msg_time -= delta
		_msg.modulate.a = clampf(_msg_time, 0.0, 1.0)
	if surv:
		var h := surv.hour()
		clock.text = "Jour %d · %02d:%02d · %s · %s · %d °C · %s" % [surv.days_survived() + 1, int(h), int(fmod(h, 1.0) * 60.0),
			Survival.SEASONS[surv.season()], surv.weather, roundi(surv.outside_temp()), surv.wind_name()]
		sleep_button.visible = surv.fatigue < 60.0 and not surv.sleeping
	queue_redraw()


func _draw() -> void:
	if surv == null:
		return
	var x := 10.0
	var y := 66.0
	for g in GAUGES:
		var v: float = surv.get(g[0])
		var col: Color = g[2]
		var w := 120.0
		var low := v < 25.0
		if low and fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0:
			col = col.lightened(0.4)
		draw_rect(Rect2(x + 64, y, w, 12), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(x + 64, y, w * v / 100.0, 12), col)
		draw_string_outline(_font, Vector2(x, y + 11), g[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
		draw_string(_font, Vector2(x, y + 11), g[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		y += 18.0
	var extra: PackedStringArray = []
	if surv.malade > 0.0:
		extra.append("malade")
	if surv.mouille > 0.3:
		extra.append("mouillé")
	if surv.porte != "":
		extra.append(Items.name_of(surv.porte).to_lower())
	if surv.torche > 0.0:
		extra.append("torche")
	if surv.saigne > 0.0:
		extra.append("saigne")
	if crouching:
		extra.append("accroupi")
	if not extra.is_empty():
		var t := " · ".join(extra)
		draw_string_outline(_font, Vector2(x, y + 12), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
		draw_string(_font, Vector2(x, y + 12), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.9, 0.7))
