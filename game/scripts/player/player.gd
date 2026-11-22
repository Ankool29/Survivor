class_name Player
extends Node2D
## Joueur : déplacement au joystick ou au clavier, collisions sur la grille.
## La position est celle des pieds (sert aussi au tri en profondeur).

const TILE := Tiles.SIZE
const WALK_SPEED := 4.0 * TILE      # 4 cases par seconde
const RUN_FACTOR := 1.7
const SLOW_FACTOR := 0.55
const HALF_W := 7.0
const HEIGHT := 6.0

var world: ChunkManager
var input_vector := Vector2.ZERO    ## fourni par le joystick
var run := false
var facing := Vector2.DOWN
var moving := false
var _anim := 0.0


func cell() -> Vector2i:
	return Vector2i(floori(position.x / TILE), floori(position.y / TILE))


func _process(delta: float) -> void:
	var dir := input_vector
	var keys := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keys.length() > 0.1:
		dir = keys
	var running := run or Input.is_action_pressed("run")
	moving = dir.length() > 0.1
	if moving:
		if dir.length() > 1.0:
			dir = dir.normalized()
		facing = dir.normalized()
		var speed := WALK_SPEED * (RUN_FACTOR if running else 1.0)
		if world.flags_at(cell()) & WorldGen.F_SLOW:
			speed *= SLOW_FACTOR
		var step := dir * speed * delta
		_try_move(Vector2(step.x, 0))
		_try_move(Vector2(0, step.y))
		_anim += delta * (10.0 if running else 7.0)
	queue_redraw()


func _try_move(step: Vector2) -> void:
	var target := position + step
	if not blocked(target):
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
