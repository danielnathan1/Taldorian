class_name DeckData
extends RefCounted

const MAX_HEROES := 3
const MAX_CARDS  := 50

var deck_id: String = ""
var remote_id: String = ""   # UUID do deck no backend ("" = ainda não criado → POST)
var deck_name: String = "Novo Deck"
var hero_names: Array[String] = []
var card_entries: Array[Dictionary] = []  # [{ "name": String, "count": int }]
var sleeve: String  = "default"
var playmat: String = "default"


func add_card(card_name: String, max_copies: int) -> bool:
	if total_cards() >= MAX_CARDS:
		return false
	for entry in card_entries:
		if entry["name"] == card_name:
			if entry["count"] >= max_copies:
				return false
			entry["count"] += 1
			return true
	card_entries.append({ "name": card_name, "count": 1 })
	return true


func remove_card(card_name: String) -> bool:
	for i in card_entries.size():
		if card_entries[i]["name"] == card_name:
			card_entries[i]["count"] -= 1
			if card_entries[i]["count"] <= 0:
				card_entries.remove_at(i)
			return true
	return false


func count_of(card_name: String) -> int:
	for entry in card_entries:
		if entry["name"] == card_name:
			return entry["count"]
	return 0


func total_cards() -> int:
	var n := 0
	for entry in card_entries:
		n += entry["count"]
	return n


func add_hero(hero_name: String) -> bool:
	if hero_names.has(hero_name) or hero_names.size() >= MAX_HEROES:
		return false
	hero_names.append(hero_name)
	return true


func remove_hero(hero_name: String) -> void:
	hero_names.erase(hero_name)


func has_hero(hero_name: String) -> bool:
	return hero_name in hero_names


func validate() -> Array[String]:
	var errors: Array[String] = []
	if hero_names.size() != MAX_HEROES:
		errors.append("O deck precisa de %d heróis (%d selecionado(s))" % [MAX_HEROES, hero_names.size()])
	if total_cards() == 0:
		errors.append("O deck não tem cartas")
	if total_cards() > MAX_CARDS:
		errors.append("O deck tem %d cartas (máximo %d)" % [total_cards(), MAX_CARDS])
	return errors


func duplicate_data() -> DeckData:
	var d := DeckData.new()
	d.deck_id   = deck_id
	d.remote_id = remote_id
	d.deck_name = deck_name
	d.hero_names  = hero_names.duplicate()
	d.card_entries = []
	for entry in card_entries:
		d.card_entries.append(entry.duplicate())
	d.sleeve  = sleeve
	d.playmat = playmat
	return d


func to_dict() -> Dictionary:
	return {
		"deck_id":   deck_id,
		"remote_id": remote_id,
		"deck_name": deck_name,
		"heroes":    hero_names.duplicate(),
		"cards":     card_entries.duplicate(true),
		"sleeve":    sleeve,
		"playmat":   playmat,
	}


static func from_dict(d: Dictionary) -> DeckData:
	if not d.has("deck_id"):
		return null
	var dd := DeckData.new()
	dd.deck_id   = str(d.get("deck_id", ""))
	dd.remote_id = str(d.get("remote_id", ""))
	dd.deck_name = str(d.get("deck_name", "Novo Deck"))
	var heroes_raw: Variant = d.get("heroes", [])
	if heroes_raw is Array:
		for h in heroes_raw:
			dd.hero_names.append(str(h))
	var cards_raw: Variant = d.get("cards", [])
	if cards_raw is Array:
		for c in cards_raw:
			if c is Dictionary and c.has("name") and c.has("count"):
				dd.card_entries.append({ "name": str(c["name"]), "count": int(c["count"]) })
	dd.sleeve  = str(d.get("sleeve",  "default"))
	dd.playmat = str(d.get("playmat", "default"))
	return dd
