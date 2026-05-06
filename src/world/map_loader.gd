# src/world/map_loader.gd
class_name MapLoader extends RefCounted

const MAP_SCENES: Dictionary = {
	"floresta_inicial": "res://scenes/world/maps/floresta_inicial.tscn",
	"taldorian_city":   "res://scenes/world/maps/taldorian_city.tscn",
}

static func load_map(map_name: String) -> PackedScene:
	if not MAP_SCENES.has(map_name):
		push_error("MapLoader: mapa desconhecido '%s'" % map_name)
		return null
	return load(MAP_SCENES[map_name]) as PackedScene
