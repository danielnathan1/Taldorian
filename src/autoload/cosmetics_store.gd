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


## Totais do catálogo (independem de posse) — usados na contagem "N/M" da Coleção.
func get_catalog_sleeve_count() -> int:
	return (_catalog.get("sleeves", []) as Array).size()


func get_catalog_playmat_count() -> int:
	return (_catalog.get("playmats", []) as Array).size()


# UUID do backend (master data) gravado no catálogo local — análogo ao card_id das
# cartas. id local → UUID (para salvar o deck). "" se o cosmético não tem backend_id
# (ex: "default", que significa "sem cosmético").
func get_playmat_backend_id(p_id: String) -> String:
	return str(get_playmat(p_id).get("backend_id", ""))

func get_sleeve_backend_id(p_id: String) -> String:
	return str(get_sleeve(p_id).get("backend_id", ""))

# Reverso: UUID do backend → id local (para carregar o deck vindo da API). "" se não achar.
func find_playmat_id_by_backend_id(p_uuid: String) -> String:
	return _find_id_by_backend(_catalog.get("playmats", []), p_uuid)

func find_sleeve_id_by_backend_id(p_uuid: String) -> String:
	return _find_id_by_backend(_catalog.get("sleeves", []), p_uuid)

func _find_id_by_backend(entries: Array, p_uuid: String) -> String:
	if p_uuid == "":
		return ""
	for e: Dictionary in entries:
		if str(e.get("backend_id", "")) == p_uuid:
			return str(e.get("id", ""))
	return ""


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
