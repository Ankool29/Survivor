class_name Animal
extends Node2D
## Un animal vivant (ou sa carcasse) près du joueur. Position = pieds.
## États : repos, marche, fuite, traque, attaque, charge, mort.

const TILE := Tiles.SIZE

var fauna: Fauna
var sp_id := ""
var sp: Dictionary
var pv := 10.0
var state := "repos"
var facing := Vector2.DOWN
var group := 0                  ## animaux d'un même groupe (meute, harde)
var region := Vector2i.ZERO
var bleeding := 0.0             ## points de vie perdus par seconde
var arrows := 0                 ## flèches plantées (récupérées en dépeçant)
var dead_at := 0.0              ## minute de jeu de la mort (carcasse)
var alerted := false            ## a repéré le joueur
var vel := Vector2.ZERO         ## vitesse actuelle (pour viser en avance)

var _timer := 0.0
var _goal := Vector2.ZERO
var _speed := 0.0
var _cooldown := 0.0
var _stun := 0.0
var _think := 0.0
var _blood_t := 0.0
var _sprite: AnimatedSprite2D
var _anim := "repos"


func setup(f: Fauna, id: String, pos: Vector2) -> void:
	fauna = f
	sp_id = id
	sp = Species.info(id)
	pv = float(sp["pv"])
	position = pos
	facing = Vector2.from_angle(randf() * TAU)
	_timer = randf() * 3.0
	var frames: SpriteFrames = fauna.frames_for(id)
	if frames:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_sprite.centered = false
		var meta: Dictionary = fauna.meta_for(id)
		_sprite.position = Vector2(-float(meta["frame_w"]) / 2.0, -float(meta["feet_y"]) - 1.0)
		add_child(_sprite)
		_play("repos")
		_sprite.frame = randi() % 4


func is_dead() -> bool:
	return state == "mort"


func body_center() -> Vector2:
	return position + Vector2(0, -8)


## Blessé par le joueur (flèche ou coup).
func hurt(dmg: float, from: Vector2, arrow := false) -> void:
	if is_dead():
		return
	pv -= dmg
	alerted = true
	if arrow:
		arrows += 1
		bleeding = maxf(bleeding, 1.5)
	_stun = 0.3
	if pv <= 0.0:
		die()
		return
	var b := String(sp["comportement"])
	if b == "sanglier":
		_set_state("charge")
	elif (b == "meute" or b == "loup") and pv > float(sp["pv"]) * 0.4:
		_set_state("attaque")
		fauna.alert_group(self, "attaque")
	else:
		_flee_from(from)


func die(restored := false) -> void:
	state = "mort"
	bleeding = 0.0
	dead_at = fauna.now()
	if _sprite:
		_sprite.play("repos_east")
		_sprite.pause()
		# couché sur le dos, pattes en l'air
		_sprite.centered = true
		_sprite.flip_v = true
		_sprite.rotation = 0.12
		_sprite.position = Vector2(0, -8)
		_sprite.modulate = Color(0.8, 0.7, 0.68)
	if not restored:
		fauna.on_death(self)
	queue_redraw()


func _set_state(s: String) -> void:
	state = s
	_timer = 0.0


func _flee_from(p: Vector2) -> void:
	var away := (position - p).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	_goal = position + away.rotated(randf_range(-0.5, 0.5)) * float(sp["fuite"]) * TILE
	_set_state("fuite")


func _process(delta: float) -> void:
	if is_dead() or fauna == null or fauna.paused:
		return
	var player_pos: Vector2 = fauna.player_pos()
	var to_p := player_pos - position
	var dist := to_p.length() / TILE
	_cooldown -= delta
	_stun -= delta
	if bleeding > 0.0:
		pv -= bleeding * delta
		_blood_t -= delta
		if _blood_t <= 0.0:
			_blood_t = 0.35
			fauna.add_blood(position)
		if pv <= 0.0:
			die()
			return
	_think -= delta
	if _think <= 0.0:
		_think = 0.25
		_decide(dist, player_pos)
	if _stun > 0.0:
		_animate(false)
		return
	_act(delta, dist, player_pos)


## Choix de l'état (quatre fois par seconde).
func _decide(dist: float, player_pos: Vector2) -> void:
	var b := String(sp["comportement"])
	var sees: bool = dist < fauna.detect_range(self)
	if sees and not alerted:
		alerted = true
		fauna.alert_group(self, "")
	if dist > float(sp["fuite"]) * 1.6:
		alerted = false if state != "attaque" else alerted
	var fire: Vector2 = fauna.fire_near(position, 6.0)
	match b:
		"proie":
			if alerted and state != "fuite":
				_flee_from(player_pos)
		"sanglier":
			if alerted and state in ["repos", "marche"]:
				if dist < 3.0 or pv < float(sp["pv"]):
					_set_state("charge")
				else:
					_flee_from(player_pos)
		"meute", "loup":
			if fire != Vector2.INF:
				if state != "fuite":
					_flee_from(fire)
				return
			if b == "loup" and fauna.daylight() > 0.5 and fauna.season() != 3 and state != "attaque":
				if alerted and state != "fuite":
					_flee_from(player_pos)
				return
			if pv < float(sp["pv"]) * 0.4:
				if state != "fuite":
					_flee_from(player_pos)
				return
			if state == "attaque":
				if dist > 35.0:
					_set_state("repos")
					alerted = false
				elif fauna.torch_on() and randf() < 0.05:
					_set_state("traque")
			elif alerted:
				if state != "traque":
					_set_state("traque")
				if fauna.should_attack(self, dist):
					_set_state("attaque")
					fauna.alert_group(self, "attaque")


func _act(delta: float, dist: float, player_pos: Vector2) -> void:
	var walk := float(sp["marche"]) * TILE
	var run := float(sp["course"]) * TILE
	match state:
		"repos":
			_timer -= delta
			if _timer <= 0.0:
				_goal = fauna.wander_goal(self)
				_set_state("marche")
				_timer = randf_range(3.0, 8.0)
			_animate(false)
		"marche":
			_timer -= delta
			if _move_to(_goal, walk, delta) or _timer <= 0.0:
				_set_state("repos")
				_timer = randf_range(2.0, 7.0)
		"fuite":
			var done := _move_to(_goal, run, delta)
			if done:
				if dist < float(sp["fuite"]):
					_flee_from(player_pos)
				else:
					_set_state("repos")
					_timer = randf_range(4.0, 9.0)
					alerted = false
		"traque":
			# tourne autour du joueur à distance
			var ring := 12.0
			var side := Vector2.from_angle((position - player_pos).angle() + 0.4)
			_move_to(player_pos + side * ring * TILE, walk * 1.6, delta)
		"attaque":
			if dist > float(sp.get("portee", 1.0)):
				_move_to(player_pos, run, delta)
			else:
				facing = (player_pos - position).normalized()
				_bite()
		"charge":
			if _move_to(player_pos, run * 1.1, delta) or dist < float(sp.get("portee", 1.0)):
				_bite()
				_goal = position + (player_pos - position).normalized() * 10.0 * TILE
				_set_state("fuite")


func _bite() -> void:
	if _cooldown > 0.0 or not fauna.can_bite(self):
		_animate(false)
		return
	_cooldown = randf_range(1.8, 2.6)
	_play("attaque")
	fauna.bite_player(self)


## Avance vers p ; renvoie vrai une fois arrivé (ou bloqué).
func _move_to(p: Vector2, speed: float, delta: float) -> bool:
	var d := p - position
	if d.length() < 4.0:
		_animate(false)
		return true
	var dir := d.normalized()
	var step := speed * delta
	for a in [0.0, 0.6, -0.6, 1.2, -1.2, 1.9, -1.9]:
		var v := dir.rotated(a)
		var np := position + v * step
		if fauna.walkable(np, self):
			position = np
			facing = v
			vel = v * speed
			_animate(true, speed > float(sp["marche"]) * TILE * 1.3)
			return false
	_animate(false)
	return true


func _animate(moving: bool, running := false) -> void:
	if not moving:
		vel = Vector2.ZERO
	if _sprite == null:
		return
	if _sprite.animation.begins_with("attaque") and _sprite.is_playing():
		return
	_play(("course" if running else "marche") if moving else "repos")


func _play(anim: String) -> void:
	if _sprite == null:
		return
	var dir := "south"
	if absf(facing.x) > absf(facing.y):
		dir = "east" if facing.x > 0 else "west"
	elif facing.y < 0:
		dir = "north"
	var name := anim + "_" + dir
	if not _sprite.sprite_frames.has_animation(name):
		name = "repos_" + dir
	if _sprite.animation != name or not _sprite.is_playing():
		_sprite.play(name)


func _draw() -> void:
	# ombre au sol, flaque de sang sous une carcasse
	var w := 6.0 + float(sp.get("pv", 10)) * 0.12
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
	if is_dead():
		draw_circle(Vector2(0, -6), w * 1.3, Color(0.4, 0.03, 0.03, 0.6))
	else:
		draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.25))
