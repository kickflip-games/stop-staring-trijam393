extends Node2D
## Decorative dungeon art uses the same atlas regions and eye layers as gameplay.
const TILES := preload("res://assets/2d/dungeon_crawler/full_tilemap.png")
const SOCKET := preload("res://assets/2d/eyes/empty_socket.tres")
const WHITE := preload("res://experiments/pixel_pivot/art/eyeball.svg")
const PUPIL := preload("res://experiments/pixel_pivot/art/pupil.svg")
const FLOOR_TINT := Color(0.38, 0.66, 1.0)
const EYES := [Vector2(112, 184), Vector2(224, 184), Vector2(336, 184)]
var _pointer := Vector2.ZERO

func _process(_delta: float) -> void:
	var pointer := get_global_mouse_position().round()
	if pointer != _pointer:
		_pointer = pointer
		queue_redraw()

func tile(point: Vector2, cell: Vector2i, tint := Color.WHITE) -> void:
	draw_texture_rect_region(TILES, Rect2(point, Vector2(16, 16)), Rect2(Vector2(cell) * 16.0, Vector2(16, 16)), tint)

func _draw() -> void:
	# Quiet stone trim leaves open space around the title and buttons.
	for x in range(0, 448, 16):
		tile(Vector2(x, 0), Vector2i(7, 4), Color(0.35, 0.42, 0.55))
		tile(Vector2(x, 368), Vector2i(2, 6), Color(0.45, 0.52, 0.66))
	for y in range(16, 368, 16):
		tile(Vector2(0, y), Vector2i(4, 5), Color(0.45, 0.52, 0.66))
		tile(Vector2(432, y), Vector2i(3, 5), Color(0.45, 0.52, 0.66))
	# A compact slice of the actual dungeon, rather than a second busy arena.
	draw_rect(Rect2(48, 168, 352, 88), Color("080c15"))
	for x in range(64, 384, 16):
		tile(Vector2(x, 168), Vector2i(2, 7))
		tile(Vector2(x, 184), Vector2i(7, 4))
		tile(Vector2(x, 200), Vector2i(2, 1), FLOOR_TINT)
		tile(Vector2(x, 216), Vector2i(2, 1), FLOOR_TINT)
		tile(Vector2(x, 232), Vector2i(2, 6))
	for y in range(184, 232, 16):
		tile(Vector2(48, y), Vector2i(4, 5))
		tile(Vector2(384, y), Vector2i(3, 5))
	tile(Vector2(48, 168), Vector2i(1, 7))
	tile(Vector2(384, 168), Vector2i(5, 7))
	tile(Vector2(48, 232), Vector2i(1, 6))
	tile(Vector2(384, 232), Vector2i(5, 6))
	tile(Vector2(96, 216), Vector2i(2, 2), FLOOR_TINT)
	tile(Vector2(336, 200), Vector2i(3, 2), FLOOR_TINT)
	tile(Vector2(64, 200), Vector2i(4, 0))
	tile(Vector2(368, 200), Vector2i(4, 0))
	for center in EYES:
		draw_texture_rect(SOCKET, Rect2(center - Vector2(12, 12), Vector2(24, 24)), false, Color(0.8, 0.9, 1.0))
		draw_texture_rect(WHITE, Rect2(center - Vector2(8, 8), Vector2(16, 16)), false)
		var look: Vector2 = (_pointer - center).normalized() * 2.0
		draw_texture_rect(PUPIL, Rect2(center - Vector2(3, 3) + look.round(), Vector2(6, 6)), false)
	# Use the game's mint trajectory dots to point toward the slime.
	for x in range(168, 208, 8):
		draw_rect(Rect2(x, 221, 2, 2), Color("9eedb0"))
