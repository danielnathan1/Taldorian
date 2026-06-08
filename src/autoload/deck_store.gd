extends Node

const SAVE_PATH := "user://decks.json"

signal decks_changed

var decks: Array[DeckData] = []

## Deck que o DeckBuilder deve abrir (setado pela DeckList antes de trocar de cena).
## "" = criar um deck novo.
var active_deck_id: String = ""

## Deck (UUID no backend) escolhido na Match Room para a próxima partida.
## O board busca as cartas desse deck na API antes de iniciar. "" = usa deck local.
var match_deck_id: String = ""


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	decks.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("DeckStore: não conseguiu abrir %s" % SAVE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Array:
		return
	for entry in parsed:
		if entry is Dictionary:
			var d := DeckData.from_dict(entry)
			if d != null:
				decks.append(d)


func _save_all() -> void:
	var out: Array = []
	for d in decks:
		out.append(d.to_dict())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("DeckStore: não conseguiu escrever em %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	decks_changed.emit()


func save_deck(deck: DeckData) -> void:
	for i in decks.size():
		if decks[i].deck_id == deck.deck_id:
			decks[i] = deck
			_save_all()
			return
	decks.append(deck)
	_save_all()


func delete_deck(deck_id: String) -> void:
	decks = decks.filter(func(d: DeckData) -> bool: return d.deck_id != deck_id)
	_save_all()


func new_deck() -> DeckData:
	var d := DeckData.new()
	d.deck_id   = "%d_%d" % [int(Time.get_unix_time_from_system()), randi()]
	d.deck_name = "Novo Deck"
	return d


func get_deck(deck_id: String) -> DeckData:
	for d in decks:
		if d.deck_id == deck_id:
			return d
	return null
