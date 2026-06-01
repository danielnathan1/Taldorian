# src/autoload/character_store.gd
# Persiste o personagem do mundo aberto em user://character.json
extends Node

const SAVE_PATH := "user://character.json"

var _character: Dictionary = {}

func _ready() -> void:
	_load()

# ── API pública ────────────────────────────────────────────────────────────────

func has_character() -> bool:
	return _character.size() > 0 and _character.get("name", "").strip_edges() != ""

func get_character() -> Dictionary:
	return _character.duplicate(true)

func save_character(data: Dictionary) -> void:
	_character = data.duplicate(true)
	_persist()

func clear() -> void:
	_character = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.open("user://").remove("character.json")

# ── Persistência ───────────────────────────────────────────────────────────────

func _persist() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[CharacterStore] Falha ao abrir %s para escrita" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(_character, "\t"))
	file.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text  := file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if result is Dictionary:
		_character = result
