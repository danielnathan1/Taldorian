# src/entities/deck_loader.gd
class_name DeckLoader
extends RefCounted

const MAX_COPIES := 3
const MAX_DECK_SIZE := 60

## Lê um JSON de deck e retorna Array[Card] pronta para uso.
## Retorna array vazia e loga erro se o arquivo for inválido.
static func load_from_json(path: String) -> Array[Card]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DeckLoader: arquivo não encontrado — %s" % path)
		return []

	var parse_result: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not parse_result is Dictionary:
		push_error("DeckLoader: JSON inválido em %s" % path)
		return []

	var raw_list: Variant = parse_result.get("deck", [])
	if not raw_list is Array:
		push_error("DeckLoader: chave 'deck' ausente ou inválida em %s" % path)
		return []

	return _build(raw_list, path)


static func _build(entries: Array, source_path: String) -> Array[Card]:
	var out: Array[Card] = []
	# chave única por carta: nome + timing + symbols para contar cópias
	var copy_count: Dictionary = {}

	for entry in entries:
		if not entry is Dictionary:
			push_warning("DeckLoader: entrada ignorada (não é dicionário) em %s" % source_path)
			continue

		var copies: int = entry.get("copies", 1)
		copies = clampi(copies, 1, MAX_COPIES)

		var key := _entry_key(entry)
		var already: int = copy_count.get(key, 0)
		var allowed: int = mini(copies, MAX_COPIES - already)

		if allowed <= 0:
			push_warning("DeckLoader: carta '%s' já atingiu o limite de %d cópias — entrada ignorada." % [entry.get("name", "?"), MAX_COPIES])
			continue

		for _i in range(allowed):
			if out.size() >= MAX_DECK_SIZE:
				push_warning("DeckLoader: deck atingiu o limite de %d cartas — cartas extras ignoradas." % MAX_DECK_SIZE)
				return out
			out.append(Card.from_dict(entry))

		copy_count[key] = already + allowed

	return out


static func _entry_key(entry: Dictionary) -> String:
	var syms: Array = entry.get("symbols", [])
	syms = syms.duplicate()
	syms.sort()
	return "%s|%s|%s" % [
		entry.get("name", ""),
		entry.get("timing", "ACTION"),
		"|".join(syms)
	]
