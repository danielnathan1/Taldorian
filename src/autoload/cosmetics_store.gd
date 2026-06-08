extends Node

const COSMETICS_PATH        := "res://data/cosmetics.json"
const PLAYER_COSMETICS_PATH := "res://data/player_cosmetics.json"

var _catalog: Dictionary       = {}
var _owned_sleeves: Array[String]  = []
var _owned_playmats: Array[String] = []


func _ready() -> void:
	_load_catalog()
	_load_player_cosmetics()


## Entrada do catálogo (id/name/art_key) por id, independente de posse. {} se não achar.
func get_sleeve(p_id: String) -> Dictionary:
	for s: Dictionary in _catalog.get("sleeves", []):
		if str(s.get("id", "")) == p_id:
			return s
	return {}


func get_playmat(p_id: String) -> Dictionary:
	for p: Dictionary in _catalog.get("playmats", []):
		if str(p.get("id", "")) == p_id:
			return p
	return {}


func get_available_sleeves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for s: Dictionary in _catalog.get("sleeves", []):
		if str(s.get("id", "")) in _owned_sleeves:
			result.append(s)
	return result


func get_available_playmats() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p: Dictionary in _catalog.get("playmats", []):
		if str(p.get("id", "")) in _owned_playmats:
			result.append(p)
	return result


func _load_catalog() -> void:
	var file := FileAccess.open(COSMETICS_PATH, FileAccess.READ)
	if file == null:
		push_error("CosmeticsStore: não foi possível abrir " + COSMETICS_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("CosmeticsStore: erro ao parsear cosmetics.json")
		return
	_catalog = json.data


func _load_player_cosmetics() -> void:
	var file := FileAccess.open(PLAYER_COSMETICS_PATH, FileAccess.READ)
	if file == null:
		push_error("CosmeticsStore: não foi possível abrir " + PLAYER_COSMETICS_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("CosmeticsStore: erro ao parsear player_cosmetics.json")
		return
	var data: Dictionary = json.data
	for s: Variant in data.get("sleeves", []):
		_owned_sleeves.append(str(s))
	for p: Variant in data.get("playmats", []):
		_owned_playmats.append(str(p))
