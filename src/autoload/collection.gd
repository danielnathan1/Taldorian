extends Node

const CARD_DATA_PATH        := "res://data/cards/base_set.json"
const PLAYER_CARD_PATH      := "res://data/player_cards.json"
const PLAYER_CARD_SAVE_PATH := "user://player_cards.json"

var all_card_dicts: Array[Dictionary] = []
var all_heroes: Array[Hero] = []
var _owned: Dictionary = {}   # card_id (int) -> quantity (int)


func _ready() -> void:
	_load_cards()
	_load_player_cards()
	all_heroes = HeroFactory.make_team()


func _load_player_cards() -> void:
	# user:// overrides the bundled res:// seed
	var path := PLAYER_CARD_SAVE_PATH if FileAccess.file_exists(PLAYER_CARD_SAVE_PATH) else PLAYER_CARD_PATH
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var cards: Variant = parsed.get("cards", [])
	if not cards is Array:
		return
	for entry in cards:
		if entry is Dictionary:
			var cid: int = entry.get("card_id", -1)
			var qty: int = entry.get("quantity", 0)
			if cid >= 0:
				_owned[cid] = qty


func get_owned_quantity(card_id: int) -> int:
	return _owned.get(card_id, 0)


func _load_cards() -> void:
	var file := FileAccess.open(CARD_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Collection: não conseguiu abrir %s" % CARD_DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("Collection: JSON inválido em %s" % CARD_DATA_PATH)
		return
	var raw: Variant = parsed.get("deck", [])
	if not raw is Array:
		push_error("Collection: chave 'deck' não encontrada")
		return
	for entry in raw:
		if entry is Dictionary:
			all_card_dicts.append(entry)


func query_cards(search: String, symbols: Array[String], timing: String, only_in_deck: Array[String], rarity: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var search_lower := search.to_lower().strip_edges()
	for d in all_card_dicts:
		var card_id: int = d.get("id", -1)
		if not _owned.has(card_id) or _owned[card_id] <= 0:
			continue
		var name_str: String = d.get("name", "")
		if search_lower != "" and not name_str.to_lower().contains(search_lower):
			continue
		if not symbols.is_empty():
			var card_syms: Variant = d.get("symbols", [])
			var match_found := false
			if card_syms is Array:
				for sym in symbols:
					if sym in card_syms:
						match_found = true
						break
			if not match_found:
				continue
		if timing != "" and d.get("timing", "") != timing:
			continue
		if rarity != "" and d.get("rarity", "COMMON") != rarity:
			continue
		if not only_in_deck.is_empty() and not (name_str in only_in_deck):
			continue
		out.append(d)
	return out


func query_heroes(search: String, hero_classes: Array[String]) -> Array[Hero]:
	var out: Array[Hero] = []
	var search_lower := search.to_lower().strip_edges()
	for h in all_heroes:
		if search_lower != "" and not h.hero_name.to_lower().contains(search_lower):
			continue
		if not hero_classes.is_empty():
			var class_key: String = Hero.HeroClass.keys()[h.hero_class]
			if not class_key in hero_classes:
				continue
		out.append(h)
	return out


func get_card_dict(card_name: String) -> Dictionary:
	for d in all_card_dicts:
		if d.get("name", "") == card_name:
			return d
	return {}


func get_max_copies(card_name: String) -> int:
	for d in all_card_dicts:
		if d.get("name", "") == card_name:
			var deck_limit: int = int(d.get("copies", 3))
			var card_id: int    = int(d.get("id", -1))
			var owned_qty: int  = _owned.get(card_id, 0)
			return mini(deck_limit, owned_qty)
	return 0


func get_hero_by_name(hero_name: String) -> Hero:
	for h in all_heroes:
		if h.hero_name == hero_name:
			return h
	return null


func add_cards(card_dicts: Array) -> void:
	for d in card_dicts:
		if not d is Dictionary:
			continue
		var cid: int = d.get("id", -1)
		if cid >= 0:
			_owned[cid] = _owned.get(cid, 0) + 1
	_save_player_cards()


func _save_player_cards() -> void:
	var out: Array = []
	for cid in _owned:
		out.append({ "card_id": cid, "quantity": _owned[cid] })
	var file := FileAccess.open(PLAYER_CARD_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Collection: não conseguiu salvar em %s" % PLAYER_CARD_SAVE_PATH)
		return
	file.store_string(JSON.stringify({ "cards": out }, "\t"))
	file.close()
