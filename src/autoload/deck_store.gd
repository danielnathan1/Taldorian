extends Node

# Coordena os decks do jogador. NÃO persiste nada em disco — a fonte da verdade é
# sempre o backend (taldorian-service). `decks` é apenas um cache em memória,
# hidratado via API (GET /decks → GET /decks/{id}) e reconstruído a cada refresh().

signal decks_changed

## Máximo de decks por jogador. Trava de UI — o backend continua sendo a autoridade.
const MAX_DECKS := 6

## Cache em memória dos decks do jogador autenticado. Hidratado por refresh().
var decks: Array[DeckData] = []

## Deck que o DeckBuilder deve abrir (setado pela DeckList antes de trocar de cena).
## Guarda o UUID remoto do deck. "" = criar um deck novo.
var active_deck_id: String = ""

## Deck (UUID no backend) escolhido na Match Room para a próxima partida.
## O board busca as cartas desse deck na API antes de iniciar. "" = fila rápida.
var match_deck_id: String = ""

## true depois de um refresh() bem-sucedido nesta sessão.
var _loaded: bool = false


# Busca a lista de decks do jogador na API e hidrata cada um (GET /decks devolve só
# resumo, sem cartas → GET /decks/{id} por deck). Reconstrói o cache em memória.
# Retorna { "ok": bool, "error": String }.
func refresh() -> Dictionary:
	# Heróis vêm como UUID nos decks → inventário precisa estar carregado p/ resolver nomes.
	if not Collection.is_inventory_loaded():
		var inv := await ApiClient.get_inventory()
		if inv.ok:
			Collection.load_inventory(inv.data)

	var res := await ApiClient.get_decks()
	if not res.ok:
		return { "ok": false, "error": res.error }

	var hydrated: Array[DeckData] = []
	if res.data is Array:
		for summary in res.data:
			if not summary is Dictionary:
				continue
			var id := str(summary.get("id", ""))
			if id == "":
				continue
			var detail := await ApiClient.get_deck(id)
			if not detail.ok or not detail.data is Dictionary:
				push_warning("DeckStore: falha ao hidratar deck %s (%s)" % [id, detail.error])
				continue
			hydrated.append(deck_from_detail(detail.data))

	decks = hydrated
	_loaded = true
	decks_changed.emit()
	return { "ok": true, "error": "" }


## Garante que o cache foi carregado ao menos uma vez nesta sessão. Idempotente.
func ensure_loaded() -> Dictionary:
	if _loaded:
		return { "ok": true, "error": "" }
	return await refresh()


## Constrói um DeckData a partir do corpo de GET /decks/{id} (DeckDetailResponse).
## Reaproveita o mapeamento reverso do Collection (UUID → nomes locais).
func deck_from_detail(detail: Dictionary) -> DeckData:
	var local := Collection.resolve_api_deck(detail)   # { heroes, cards, sleeve, playmat }
	var dd := DeckData.new()
	var id := str(detail.get("id", ""))
	dd.remote_id = id
	dd.deck_id   = id
	dd.deck_name = str(detail.get("name", "Deck"))
	dd.hero_names = []
	for h in local.get("heroes", []):
		dd.hero_names.append(str(h))
	dd.card_entries = []
	for c in local.get("cards", []):
		dd.card_entries.append({ "name": str(c["name"]), "count": int(c["count"]), "foil": int(c.get("foil", 0)) })
	dd.sleeve  = str(local.get("sleeve", "default"))
	dd.playmat = str(local.get("playmat", "default"))
	return dd


## Apaga um deck no backend (DELETE /decks/{id}) e remove do cache.
## Retorna { "ok": bool, "error": String }.
func delete_deck(remote_id: String) -> Dictionary:
	if remote_id == "":
		return { "ok": true, "error": "" }
	var res := await ApiClient.delete_deck(remote_id)
	if not res.ok:
		return { "ok": false, "error": res.error }
	decks = decks.filter(func(d: DeckData) -> bool: return d.remote_id != remote_id)
	decks_changed.emit()
	return { "ok": true, "error": "" }


## Deck novo, ainda não salvo (remote_id == "" → o DeckBuilder faz POST ao salvar).
func new_deck() -> DeckData:
	var d := DeckData.new()
	d.deck_id   = ""
	d.remote_id = ""
	d.deck_name = "Novo Deck"
	return d


## Busca no cache pelo UUID remoto. null se não estiver carregado.
func get_deck(deck_id: String) -> DeckData:
	if deck_id == "":
		return null
	for d in decks:
		if d.deck_id == deck_id:
			return d
	return null
