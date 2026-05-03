# scenes/world/maps/floresta_inicial.gd
# Primeiro mapa — Floresta Inicial. Placeholder visual via _draw().
extends MapBase

# Grupos de tiles de árvore para bloquear passagem
const TREE_TILES: Array[Vector2i] = [
	Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4),
	Vector2i(15, 8), Vector2i(16, 8), Vector2i(17, 8),
	Vector2i(8, 14), Vector2i(9, 14),
	Vector2i(25, 6), Vector2i(26, 6), Vector2i(27, 6),
	Vector2i(20, 18), Vector2i(21, 18), Vector2i(22, 18),
	Vector2i(30, 12), Vector2i(31, 12),
	Vector2i(12, 22), Vector2i(13, 22), Vector2i(14, 22),
]

func _ready() -> void:
	super._ready()
	for t in TREE_TILES:
		set_tile_walkable(t, false)
	queue_redraw()

func get_map_name() -> String:
	return "floresta_inicial"

func get_spawn_point() -> Vector2i:
	return Vector2i(5, 5)

func _draw() -> void:
	_draw_floor()
	_draw_border()
	_draw_trees()
	_draw_grid()

func _draw_floor() -> void:
	draw_rect(Rect2(0, 0, MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE), Color(0.22, 0.48, 0.18))

func _draw_border() -> void:
	for col in MAP_WIDTH:
		_fill_tile(Vector2i(col, 0),            Color(0.12, 0.28, 0.08))
		_fill_tile(Vector2i(col, MAP_HEIGHT-1), Color(0.12, 0.28, 0.08))
	for row in MAP_HEIGHT:
		_fill_tile(Vector2i(0, row),           Color(0.12, 0.28, 0.08))
		_fill_tile(Vector2i(MAP_WIDTH-1, row), Color(0.12, 0.28, 0.08))

func _draw_trees() -> void:
	for t in TREE_TILES:
		_fill_tile(t, Color(0.08, 0.22, 0.06))
		draw_rect(Rect2(t.x * TILE_SIZE + 3, t.y * TILE_SIZE + 2, 10, 11),
			Color(0.18, 0.40, 0.10))

func _draw_grid() -> void:
	for col in range(1, MAP_WIDTH - 1):
		for row in range(1, MAP_HEIGHT - 1):
			draw_rect(Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE),
				Color(0.0, 0.0, 0.0, 0.04), false)

func _fill_tile(tile: Vector2i, color: Color) -> void:
	draw_rect(Rect2(tile.x * TILE_SIZE, tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), color)
