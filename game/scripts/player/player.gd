class_name Player
extends Node2D
## Joueur : déplacement au joystick ou au clavier, collisions sur la grille.
## La position est celle des pieds (sert aussi au tri en profondeur).

const TILE := Tiles.SIZE
var walk_speed := 4.0 * TILE       ## 4 cases par seconde (réglé selon l'échelle par main.gd)
const RUN_FACTOR := 1.7
const SLOW_FACTOR := 0.55
const HALF_W := 5.0
const HEIGHT := 4.0

var world: ChunkManager
var input_vector := Vector2.ZERO    ## fourni par le joystick
var run := false
var facing := Vector2.DOWN
var moving := false
var _anim := 0.0
var _sprite: AnimatedSprite2D     ## sprite PixelLab, si présent
var _running_now := false
var _action := ""                 ## animation ponctuelle en cours (ramasser, frapper, boire)
var sleeping := false
var crouch := false               ## accroupi : lent et discret
var aiming := false               ## arc bandé : très lent
var _rest_offset := Vector2.ZERO

var load_factor := 1.0             ## ralenti par la charge (1 = normal)
var outfit := "civil"
var _frames_cache := {}


func _ready() -> void:
	var frames := _frames_for("civil")
	if frames == null:
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.centered = false
	_sprite.position = _rest_offset
	add_child(_sprite)
	_sprite.play("repos_south")
	_sprite.animation_finished.connect(func():
		if _action != "dormir":
			_action = "")


## Planche d'animations d'une tenue : joueur.png (civil) ou joueur_<tenue>.png.
func _frames_for(t: String) -> SpriteFrames:
	if _frames_cache.has(t):
		return _frames_cache[t]
	var base := "res://assets/characters/joueur" + ("" if t == "civil" else "_" + t)
	if not ResourceLoader.exists(base + ".png") or not FileAccess.file_exists(base + ".json"):
		return null if t == "civil" else _frames_for("civil")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	var tex: Texture2D = load(base + ".png")
	var fw := int(meta["frame_w"])
	var fh := int(meta["frame_h"])
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var fps := {"repos": 5.0, "marche": 9.0, "course": 12.0, "ramasser": 10.0, "frapper": 11.0, "boire": 7.0, "dormir": 3.0}
	var once := ["ramasser", "frapper", "boire", "dormir"]
	for a in meta["anims"]:
		var name := "%s_%s" % [a["name"], a["dir"]]
		frames.add_animation(name)
		frames.set_animation_speed(name, fps.get(a["name"], 8.0))
		frames.set_animation_loop(name, not (a["name"] in once))
		for i in int(a["frames"]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, int(a["row"]) * fh, fw, fh)
			frames.add_frame(name, at)
	if t == "civil":
		_rest_offset = Vector2(-fw / 2.0, -float(meta["feet_y"]) - 1.0)
	_frames_cache[t] = frames
	return frames


## Change l'apparence selon le vêtement de torse (civil, cire, cuir, fourrure).
func set_outfit(t: String) -> void:
	if t == outfit or _sprite == null:
		return
	var f := _frames_for(t)
	if f == null:
		return
	outfit = t
	var anim := _sprite.animation
	var fr := _sprite.frame
	_sprite.sprite_frames = f
	if f.has_animation(anim):
		_sprite.play(anim)
		_sprite.frame = mini(fr, f.get_frame_count(anim) - 1)
		if sleeping:
			_sprite.pause()


## Joue une animation ponctuelle (si elle existe) : ramasser, frapper, boire, dormir.
func play_action(anim: String) -> void:
	if _sprite == null:
		return
	var name := anim + "_" + _direction_name()
	if not _sprite.sprite_frames.has_animation(name):
		name = anim + "_south"
	if not _sprite.sprite_frames.has_animation(name):
		return
	_action = anim
	_sprite.play(name)


func set_sleeping(on: bool) -> void:
	sleeping = on
	if _sprite == null:
		return
	if on:
		# allongé : sprite au repos couché sur le côté
		_action = "dormir"
		_sprite.play("repos_east")
		_sprite.pause()
		_sprite.centered = true
		_sprite.rotation = -PI / 2.0
		_sprite.position = Vector2(0, -6)
		_sprite.modulate = Color(0.85, 0.85, 0.9)
	else:
		_action = ""
		_sprite.centered = false
		_sprite.rotation = 0.0
		_sprite.position = _rest_offset
		_sprite.modulate = Color.WHITE
		_update_sprite()


func set_crouch(on: bool) -> void:
	crouch = on
	if _sprite == null or sleeping:
		return
	_sprite.scale = Vector2(1.0, 0.86) if on else Vector2.ONE
	_sprite.position = _rest_offset * Vector2(1.0, 0.86 if on else 1.0)


func _direction_name() -> String:
	if absf(facing.x) > absf(facing.y):
		return "east" if facing.x > 0 else "west"
	return "south" if facing.y > 0 else "north"


func _update_sprite() -> void:
	if _action != "":
		if moving and _action != "dormir":
			_action = ""
		else:
			return
	var anim := "repos"
	if moving:
		anim = "course" if _running_now else "marche"
	var name := anim + "_" + _direction_name()
	if _sprite.animation != name:
		_sprite.play(name)


func cell() -> Vector2i:
	return Vector2i(floori(position.x / TILE), floori(position.y / TILE))


func _process(delta: float) -> void:
	var dir := input_vector
	var keys := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keys.length() > 0.1:
		dir = keys
	var running := run or Input.is_action_pressed("run")
	_running_now = running and not crouch and load_factor > 0.81
	moving = dir.length() > 0.1
	if moving:
		if dir.length() > 1.0:
			dir = dir.normalized()
		facing = dir.normalized()
		var speed := walk_speed * (RUN_FACTOR if _running_now else 1.0)
		if crouch:
			speed *= 0.45
		if aiming:
			speed *= 0.3
		speed *= load_factor
		if world.flags_at(cell()) & WorldGen.F_SLOW:
			speed *= SLOW_FACTOR
		var step := dir * speed * delta
		_try_move(Vector2(step.x, 0))
		_try_move(Vector2(0, step.y))
		_anim += delta * (10.0 if running else 7.0)
	if _sprite:
		_update_sprite()
	else:
		queue_redraw()


func _try_move(step: Vector2) -> void:
	var target := position + step
	if blocked(target):
		return
	# murs fins des bâtiments détaillés : les coins du pied ne traversent pas un mur
	if world.interiors:
		for o in [Vector2(-4, -2), Vector2(4, -2), Vector2(-4, 1), Vector2(4, 1)]:
			if world.move_blocked(position + o, target + o):
				return
	position = target


## Vrai si les pieds posés en p touchent un obstacle.
func blocked(p: Vector2) -> bool:
	var box := Rect2(p.x - HALF_W, p.y - HEIGHT, HALF_W * 2, HEIGHT)
	var c0 := Vector2i(floori(box.position.x / TILE), floori(box.position.y / TILE))
	var c1 := Vector2i(floori(box.end.x / TILE), floori(box.end.y / TILE))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var f := world.flags_at(Vector2i(cx, cy))
			if f & WorldGen.F_BLOCK:
				return true
			if f & WorldGen.F_TRUNK:
				var trunk := Rect2(cx * TILE + 11, cy * TILE + 20, 10, 10)
				if trunk.intersects(box):
					return true
	return false


## Silhouette provisoire, remplacée par le sprite PixelLab.
func _draw() -> void:
	if _sprite:
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 7, Color(0, 0, 0, 0.28))
		return
	var bob := sin(_anim) * 1.5 if moving else 0.0
	draw_set_transform(Vector2.ZERO)
	# ombre
	draw_circle(Vector2(0, -1), 7, Color(0, 0, 0, 0.3))
	# jambes
	var leg := sin(_anim) * 3.0 if moving else 0.0
	draw_rect(Rect2(-4, -10, 3, 9 + leg * 0.3), Color8(60, 56, 48))
	draw_rect(Rect2(1, -10, 3, 9 - leg * 0.3), Color8(60, 56, 48))
	# corps (veste)
	draw_rect(Rect2(-6, -22 + bob, 12, 13), Color8(110, 96, 62))
	# sac
	if facing.y < 0.3:
		draw_rect(Rect2(-5, -21 + bob, 10, 9), Color8(84, 70, 48))
	# tête
	draw_circle(Vector2(0, -27 + bob), 5, Color8(214, 176, 140))
	draw_rect(Rect2(-5, -32 + bob, 10, 3), Color8(70, 50, 36))
	if facing.y >= -0.3:
		var ex := facing.x * 2.0
		draw_rect(Rect2(-2.5 + ex, -28 + bob, 1.5, 1.5), Color8(30, 30, 30))
		draw_rect(Rect2(1 + ex, -28 + bob, 1.5, 1.5), Color8(30, 30, 30))
