# scenes/world/maps/map_base.gd
# Classe base de todos os mapas do mundo. Gerencia walkable grid e pontos de saída.
class_name MapBase extends Node2D

const TILE_SIZE  := 16
const MAP_WIDTH  := 40
const MAP_HEIGHT := 30

# [col][row] = bool
var _walkable: Array = []

func _ready() -> void:
	_init_walkable()
	_mark_obstacles()

func _init_walkable() -> void:
	_walkable.resize(MAP_WIDTH)
	for col in MAP_WIDTH:
		_walkable[col] = []
		_walkable[col].resize(MAP_HEIGHT)
		for row in MAP_HEIGHT:
			_walkable[col][row] = true

func _mark_obstacles() -> void:
	for col in MAP_WIDTH:
		_walkable[col][0]            = false
		_walkable[col][MAP_HEIGHT-1] = false
	for row in MAP_HEIGHT:
		_walkable[0][row]           = false
		_walkable[MAP_WIDTH-1][row] = false

func is_tile_walkable(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.x >= MAP_WIDTH or tile.y < 0 or tile.y >= MAP_HEIGHT:
		return false
	return _walkable[tile.x][tile.y]

func set_tile_walkable(tile: Vector2i, value: bool) -> void:
	if tile.x < 0 or tile.x >= MAP_WIDTH or tile.y < 0 or tile.y >= MAP_HEIGHT:
		return
	_walkable[tile.x][tile.y] = value

func get_spawn_point() -> Vector2i:
	return Vector2i(5, 5)

func get_map_name() -> String:
	return "unknown"

# Retorna lista de { "target_map": String, "area": Rect2i }
func get_exits() -> Array:
	return []
