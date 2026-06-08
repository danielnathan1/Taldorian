extends Node

const CARD_DATA_PATH        := "res://data/cards/taldorian_origins.json"
const PLAYER_CARD_PATH      := "res://data/player_cards.json"
const PLAYER_CARD_SAVE_PATH := "user://player_cards.json"

var all_card_dicts: Array[Dictionary] = []
var all_heroes: Array[Hero] = []
var _owned: Dictionary = {}   # card_id (int) -> quantity (int)

# Posse vinda do backend (/players/me/inventory). Enquanto _inventory_loaded for
# false, a coleção usa o seed local (player_cards.json + todos os heróis).
var _inventory_loaded: bool = false
var _owned_hero_keys: Dictionary = {}        # chave (art_key/nome, lower) -> true
var owned_playmats: Array[Dictionary] = []   # playmats do inventário (cru)

# Mapeamentos nome/chave → UUID do backend (usados ao salvar decks na API).
var _hero_uuid_by_key: Dictionary = {}       # art_key/nome (lower) -> heroId (UUID)
var _card_uuid_by_id: Dictionary = {}        # card_id local (int)  -> cardId (UUID)
var _playmat_uuid_by_key: Dictionary = {}    # nome/artKey (lower)  -> playmatId (UUID)
var _hero_name_by_uuid: Dictionary = {}      # heroId (UUID) -> nome do herói local


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


func is_inventory_loaded() -> bool:
	return _inventory_loaded


# Sincroniza a posse do jogador a partir do payload de /players/me/inventory.
# O backend manda posse + dados de exibição; o COMPORTAMENTO (efeitos das cartas,
# hooks dos heróis) continua vindo do código local (taldorian_origins.json + HeroFactory).
# Por isso aqui só mapeamos "o que o jogador tem" para as definições locais:
#   - cartas: cardId (UUID) → card_id local (fallback cardKey→art_key, depois name), guardado por id local.
#   - heróis: heroKey/name marcados como possuídos (filtra query_heroes).
#   - playmats: guardados crus em owned_playmats (integração com CosmeticsStore depois).
func load_inventory(data: Dictionary) -> void:
	_owned.clear()
	_owned_hero_keys.clear()
	owned_playmats.clear()
	_hero_uuid_by_key.clear()
	_card_uuid_by_id.clear()
	_playmat_uuid_by_key.clear()
	_hero_name_by_uuid.clear()

	var cards: Variant = data.get("cards", [])
	if cards is Array:
		for entry in cards:
			if not entry is Dictionary:
				continue
			var qty: int = int(entry.get("quantity", 0))
			if qty <= 0:
				continue
			var local := _match_card(entry)
			if local.is_empty():
				push_warning("Collection: carta do inventário sem correspondência local (cardKey=%s, name=%s)" % [entry.get("cardKey", ""), entry.get("name", "")])
				continue
			var cid := int(local.get("id", -1))
			_owned[cid] = qty
			var card_uuid := str(entry.get("cardId", ""))
			if card_uuid != "":
				_card_uuid_by_id[cid] = card_uuid

	var heroes: Variant = data.get("heroes", [])
	if heroes is Array:
		for entry in heroes:
			if not entry is Dictionary:
				continue
			var key := str(entry.get("heroKey", "")).strip_edges().to_lower()
			var nm  := str(entry.get("name", "")).strip_edges().to_lower()
			var hero_uuid := str(entry.get("heroId", ""))
			if key != "":
				_owned_hero_keys[key] = true
				if hero_uuid != "":
					_hero_uuid_by_key[key] = hero_uuid
			if nm != "":
				_owned_hero_keys[nm] = true
				if hero_uuid != "":
					_hero_uuid_by_key[nm] = hero_uuid
			# Reverso: heroId (UUID) → nome do herói local (casando heroKey↔art_key).
			if hero_uuid != "":
				var local_hero := _local_hero_for(key, nm)
				if local_hero != null:
					_hero_name_by_uuid[hero_uuid] = local_hero.hero_name

	var playmats: Variant = data.get("playmats", [])
	if playmats is Array:
		for entry in playmats:
			if not entry is Dictionary:
				continue
			owned_playmats.append(entry)
			var pm_uuid := str(entry.get("playmatId", ""))
			if pm_uuid == "":
				continue
			var pm_name := str(entry.get("name", "")).strip_edges().to_lower()
			var pm_art  := str(entry.get("artKey", "")).strip_edges().to_lower()
			if pm_name != "":
				_playmat_uuid_by_key[pm_name] = pm_uuid
			if pm_art != "":
				_playmat_uuid_by_key[pm_art] = pm_uuid

	_inventory_loaded = true


# ── Mapeamento nome → UUID (para salvar decks na API) ──────────────────────────

func get_hero_uuid(hero_name: String) -> String:
	return str(_hero_uuid_by_key.get(hero_name.strip_edges().to_lower(), ""))

func get_card_uuid_by_name(card_name: String) -> String:
	var d := get_card_dict(card_name)
	if d.is_empty():
		return ""
	# UUID vem direto do JSON local (card_id); fallback ao mapa do inventário.
	var uuid := str(d.get("card_id", ""))
	if uuid != "":
		return uuid
	return str(_card_uuid_by_id.get(int(d.get("id", -1)), ""))

func get_playmat_uuid(playmat_key: String) -> String:
	return str(_playmat_uuid_by_key.get(playmat_key.strip_edges().to_lower(), ""))


# ── Resolução reversa (deck vindo da API → formato local) ──────────────────────

## heroId (UUID) → nome do herói local. Requer inventário carregado.
func get_hero_name_by_uuid(uuid: String) -> String:
	return str(_hero_name_by_uuid.get(uuid, ""))

## Resolve a definição local (taldorian_origins.json) a partir do dict cru de uma carta
## da API (booster usa `id`, inventário usa `cardId`). UUID-first → cardKey → name. {} se não achar.
func resolve_card(p_entry: Dictionary) -> Dictionary:
	return _local_card_for(
		str(p_entry.get("id", p_entry.get("cardId", ""))),
		str(p_entry.get("cardKey", "")),
		str(p_entry.get("name", "")))

## cardKey (== art_key) → nome da carta local (fallback por nome direto). "" se não achar.
func get_card_name_by_key(card_key: String, fallback_name: String = "") -> String:
	var k := card_key.strip_edges().to_lower()
	for d in all_card_dicts:
		if k != "" and str(d.get("art_key", "")).to_lower() == k:
			return str(d.get("name", ""))
	var fn := fallback_name.strip_edges().to_lower()
	for d in all_card_dicts:
		if fn != "" and str(d.get("name", "")).to_lower() == fn:
			return str(d.get("name", ""))
	return ""

## Converte a resposta de GET /decks/{id} no deck_dict local que o GameState entende:
## { "heroes": [nome,...], "cards": [{name,count}], "sleeve", "playmat" }.
## Heróis (hero1/2/3) vêm como UUID → precisa do inventário carregado.
func resolve_api_deck(p_deck: Dictionary) -> Dictionary:
	var heroes: Array[String] = []
	for key in ["hero1", "hero2", "hero3"]:
		var uuid := str(p_deck.get(key, ""))
		if uuid == "":
			continue
		var hname := get_hero_name_by_uuid(uuid)
		if hname != "":
			heroes.append(hname)
		else:
			push_warning("Collection: herói do deck sem correspondência local (uuid=%s)" % uuid)

	var cards: Array = []
	var raw_cards: Variant = p_deck.get("cards", [])
	if raw_cards is Array:
		for c in raw_cards:
			if not c is Dictionary:
				continue
			var qty := int(c.get("quantity", 0))
			if qty <= 0:
				continue
			var local := _local_card_for(str(c.get("cardId", "")), str(c.get("cardKey", "")), str(c.get("name", "")))
			if local.is_empty():
				push_warning("Collection: carta do deck sem correspondência local (cardId=%s, cardKey=%s, name=%s)" % [c.get("cardId", ""), c.get("cardKey", ""), c.get("name", "")])
				continue
			cards.append({ "name": str(local.get("name", "")), "count": qty })

	return {
		"heroes":  heroes,
		"cards":   cards,
		"sleeve":  "default",   # cosmético; mapeamento UUID→id local ainda não disponível
		"playmat": "default",
	}


# Herói local (HeroFactory) cujo art_key == heroKey, ou nome == name. null se nenhum.
func _local_hero_for(p_key: String, p_name: String) -> Hero:
	for h in all_heroes:
		if p_key != "" and h.art_key.to_lower() == p_key:
			return h
	for h in all_heroes:
		if p_name != "" and h.hero_name.to_lower() == p_name:
			return h
	return null


# Resolve a definição local a partir de uma entrada do backend, por ordem de
# confiança: UUID (card_id) → cardKey/art_key (legado) → name. Tudo case-insensitive.
# O UUID é a identidade real da carta (estável e independente da arte).
func _local_card_for(p_uuid: String, p_card_key: String, p_name: String) -> Dictionary:
	var u := p_uuid.strip_edges().to_lower()
	if u != "":
		for d in all_card_dicts:
			if str(d.get("card_id", "")).to_lower() == u:
				return d
	var k := p_card_key.strip_edges().to_lower()
	if k != "":
		for d in all_card_dicts:
			if str(d.get("art_key", "")).to_lower() == k:
				return d
	var n := p_name.strip_edges().to_lower()
	if n != "":
		for d in all_card_dicts:
			if str(d.get("name", "")).to_lower() == n:
				return d
	return {}


# Casa uma carta do inventário com a definição local (UUID-first via _local_card_for).
func _match_card(p_entry: Dictionary) -> Dictionary:
	return _local_card_for(
		str(p_entry.get("cardId", p_entry.get("id", ""))),
		str(p_entry.get("cardKey", "")),
		str(p_entry.get("name", "")))


func _is_hero_owned(p_hero: Hero) -> bool:
	if _owned_hero_keys.has(p_hero.art_key.to_lower()):
		return true
	return _owned_hero_keys.has(p_hero.hero_name.to_lower())


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
		if _inventory_loaded and not _is_hero_owned(h):
			continue
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
