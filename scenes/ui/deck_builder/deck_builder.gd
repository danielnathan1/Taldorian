extends Control

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")
const LOBBY_SCENE := "res://scenes/ui/lobby/lobby.tscn"
const WORLD_SCENE := "res://scenes/world/world_root.tscn"
const DECK_LIST_SCENE := "res://scenes/ui/deck_list/deck_list.tscn"

var _current_deck: DeckData   = null
var _saved_snapshot: DeckData = null
var _is_dirty: bool           = false


func _ready() -> void:
	_style_bg()
	_connect_signals()
	await _load_inventory()
	await _load_or_create_deck()


# Carrega a coleção do jogador do backend (/players/me/inventory) antes de montar
# os pickers. Se a API falhar, segue com a coleção local (seed) — o jogo continua
# testável offline.
func _load_inventory() -> void:
	var overlay := _make_loading_overlay("Carregando coleção…")
	add_child(overlay)
	print("[DeckBuilder] GET /players/me/inventory (autenticado=%s)" % ApiClient.is_authenticated())
	var res := await ApiClient.get_inventory()
	print("[DeckBuilder] inventário → ok=%s status=%d erro=%s" % [res.ok, res.status, res.error])
	if res.ok:
		Collection.load_inventory(res.data)
	else:
		push_warning("DeckBuilder: inventário indisponível (%s) — usando coleção local." % res.error)
		_toast("Coleção indisponível: %s" % res.error)
	if is_instance_valid(overlay):
		overlay.queue_free()


func _make_loading_overlay(p_msg: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 20
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(S.C_BG_DEEP, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var label := Label.new()
	label.text = p_msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	center.add_child(label)
	return layer


func _style_bg() -> void:
	$BG.color = S.C_BG_DEEP


func _connect_signals() -> void:
	var header   := _get_header()
	var picker   := _get_picker()
	var rail     := _get_rail()
	var modal    := _get_modal()

	header.back_requested.connect(_on_back_requested)
	header.save_requested.connect(_on_save_requested)
	header.discard_requested.connect(_on_discard_requested)
	header.delete_requested.connect(func() -> void: modal.show_modal("Excluir deck", "Deseja excluir \"%s\"? Esta ação não pode ser desfeita." % _current_deck.deck_name))
	header.name_changed.connect(_on_name_changed)

	picker.hero_add_requested.connect(_on_hero_add)
	picker.hero_preview_requested.connect(_on_hero_preview)
	picker.card_add_requested.connect(_on_card_add)
	picker.card_remove_requested.connect(_on_card_remove)
	picker.card_preview_requested.connect(_on_card_preview)
	picker.cosmetic_sleeve_changed.connect(_on_sleeve_changed)
	picker.cosmetic_playmat_changed.connect(_on_playmat_changed)

	rail.hero_remove_requested.connect(_on_hero_remove)
	rail.card_remove_requested.connect(_on_card_remove)
	rail.foil_change_requested.connect(_on_foil_change)
	rail.clear_cards_requested.connect(_on_clear_cards_requested)

	modal.confirmed.connect(_on_delete_confirmed)


func _load_or_create_deck() -> void:
	# A DeckList escolhe qual deck abrir via DeckStore.active_deck_id ("" = novo).
	var id := DeckStore.active_deck_id
	DeckStore.active_deck_id = ""   # consome
	if id != "":
		var overlay := _make_loading_overlay("Abrindo deck…")
		add_child(overlay)
		var res := await ApiClient.get_deck(id)   # GET /decks/{id} — deck completo
		if is_instance_valid(overlay):
			overlay.queue_free()
		if res.ok and res.data is Dictionary:
			load_deck(DeckStore.deck_from_detail(res.data))
			return
		_toast("Falha ao abrir deck: %s" % (res.error if not res.ok else "resposta inválida"))
	load_deck(DeckStore.new_deck())


func load_deck(deck: DeckData) -> void:
	_current_deck  = deck.duplicate_data()
	_saved_snapshot = deck.duplicate_data()
	_is_dirty = false
	_refresh_all()


func _on_hero_add(hero: Hero) -> void:
	if not _current_deck.add_hero(hero.hero_name):
		_toast("O deck já tem 3 heróis")
		return
	_mark_dirty()
	_refresh_all()


func _on_hero_remove(hero_name: String) -> void:
	_current_deck.remove_hero(hero_name)
	_mark_dirty()
	_refresh_all()


func _on_card_add(card_name: String) -> void:
	var max_cop := Collection.get_max_copies(card_name)
	if not _current_deck.add_card(card_name, max_cop):
		if _current_deck.total_cards() >= DeckData.MAX_CARDS:
			_toast("O deck está cheio (%d cartas)" % DeckData.MAX_CARDS)
		else:
			_toast("Limite de %d cópias atingido" % max_cop)
		return
	_mark_dirty()
	_refresh_deck_only()


func _on_sleeve_changed(sleeve_id: String) -> void:
	_current_deck.sleeve = sleeve_id
	_mark_dirty()


func _on_playmat_changed(playmat_id: String) -> void:
	_current_deck.playmat = playmat_id
	_mark_dirty()


func _on_card_remove(card_name: String) -> void:
	_current_deck.remove_card(card_name)
	_mark_dirty()
	_refresh_deck_only()


# Clique na pílula foil do rail: cicla 0 → 1 → … → máx → 0, onde
# máx = min(cópias no deck, cópias foil possuídas).
func _on_foil_change(card_name: String) -> void:
	var count := _current_deck.count_of(card_name)
	var card_id := int(Collection.get_card_dict(card_name).get("id", -1))
	var owned := Collection.get_foil_quantity(card_id) if card_id >= 0 else 0
	var max_foil := mini(count, owned)
	if max_foil <= 0:
		return
	var cur := clampi(_current_deck.foil_of(card_name), 0, max_foil)
	_current_deck.set_foil(card_name, (cur + 1) % (max_foil + 1))
	_mark_dirty()
	_refresh_deck_only()


func _on_clear_cards_requested() -> void:
	var modal := _get_modal()
	modal.confirmed.disconnect(_on_delete_confirmed)
	modal.confirmed.connect(_on_clear_cards_confirmed, CONNECT_ONE_SHOT)
	modal.cancelled.connect(
		func() -> void: modal.confirmed.connect(_on_delete_confirmed),
		CONNECT_ONE_SHOT
	)
	modal.show_modal("Limpar cartas", "Remover todas as %d cartas do deck?" % _current_deck.total_cards())


func _on_clear_cards_confirmed() -> void:
	_get_modal().confirmed.connect(_on_delete_confirmed)
	_current_deck.card_entries.clear()
	_mark_dirty()
	_refresh_deck_only()


func _on_save_requested() -> void:
	var errors := _current_deck.validate()
	if not errors.is_empty():
		for e in errors:
			_toast(e)
		return

	# Mapeia heróis para UUIDs do inventário — sem isso o backend não aceita.
	var missing := _missing_hero_mappings(_current_deck)
	if not missing.is_empty():
		_toast("Heróis sem correspondência no inventário: %s" % ", ".join(missing))
		return

	var payload := _build_deck_payload(_current_deck)
	var overlay := _make_loading_overlay("Salvando deck…")
	add_child(overlay)

	var res: Dictionary
	if _current_deck.remote_id == "":
		res = await ApiClient.create_deck(payload)            # POST /decks
	else:
		res = await ApiClient.update_deck(_current_deck.remote_id, payload)  # PUT /decks/{id}

	if is_instance_valid(overlay):
		overlay.queue_free()

	if not res.ok:
		_toast("Falha ao salvar: %s" % res.error)
		return

	# Em criação, guarda o id devolvido pelo servidor → próximos saves viram PUT.
	if _current_deck.remote_id == "":
		_current_deck.remote_id = _extract_deck_id(res.data)
		_current_deck.deck_id   = _current_deck.remote_id

	# Fonte da verdade é o backend; a DeckList re-busca da API ao abrir. Sem espelho local.
	_saved_snapshot = _current_deck.duplicate_data()
	_is_dirty = false
	_get_header().set_dirty(false)
	_toast("Deck salvo!")


# Monta o corpo de POST/PUT /decks a partir do deck local, resolvendo nomes → UUID.
func _build_deck_payload(deck: DeckData) -> Dictionary:
	var hero_uuids: Array[String] = []
	for hname in deck.hero_names:
		hero_uuids.append(Collection.get_hero_uuid(hname))

	var cards: Array = []
	for entry in deck.card_entries:
		var card_uuid := Collection.get_card_uuid_by_name(entry["name"])
		if card_uuid == "":
			push_warning("DeckBuilder: carta sem UUID no inventário, ignorada no payload: %s" % entry["name"])
			continue
		# foilQuantity = escolha do jogador (set via rail), clampada à posse por segurança
		# (não dá pra marcar mais foil do que se possui, caso a posse tenha mudado).
		var count := int(entry["count"])
		var card_id := int(Collection.get_card_dict(entry["name"]).get("id", -1))
		var owned := Collection.get_foil_quantity(card_id) if card_id >= 0 else 0
		var foil_qty := clampi(int(entry.get("foil", 0)), 0, mini(count, owned))
		cards.append({ "cardId": card_uuid, "quantity": count, "foilQuantity": foil_qty })

	# Cosméticos: id local → UUID do backend (master data no cosmetics.json). "default"
	# não tem backend_id → "" → null no payload (= sem cosmético).
	var playmat_uuid := CosmeticsStore.get_playmat_backend_id(deck.playmat)
	var sleeve_uuid  := CosmeticsStore.get_sleeve_backend_id(deck.sleeve)
	return {
		"name":  deck.deck_name,
		"hero1": hero_uuids[0] if hero_uuids.size() > 0 and hero_uuids[0] != "" else null,
		"hero2": hero_uuids[1] if hero_uuids.size() > 1 and hero_uuids[1] != "" else null,
		"hero3": hero_uuids[2] if hero_uuids.size() > 2 and hero_uuids[2] != "" else null,
		"cards": cards,
		"playmatId": playmat_uuid if playmat_uuid != "" else null,
		"sleeveId":  sleeve_uuid if sleeve_uuid != "" else null,
	}


func _missing_hero_mappings(deck: DeckData) -> Array[String]:
	var missing: Array[String] = []
	for hname in deck.hero_names:
		if Collection.get_hero_uuid(hname) == "":
			missing.append(hname)
	return missing


func _extract_deck_id(data: Dictionary) -> String:
	for key in ["id", "deckId", "deck_id"]:
		if data.has(key) and str(data[key]) != "":
			return str(data[key])
	return ""


func _on_discard_requested() -> void:
	_current_deck = _saved_snapshot.duplicate_data()
	_is_dirty = false
	_refresh_all()


func _on_delete_confirmed() -> void:
	# Deck novo, nunca salvo no backend → não há o que apagar; só volta à lista.
	if _current_deck.remote_id == "":
		_go_back()
		return
	var overlay := _make_loading_overlay("Apagando deck…")
	add_child(overlay)
	var res := await DeckStore.delete_deck(_current_deck.remote_id)   # DELETE /decks/{id}
	if is_instance_valid(overlay):
		overlay.queue_free()
	if not res.ok:
		_toast("Falha ao apagar: %s" % res.error)
		return
	_go_back()


func _on_name_changed(new_name: String) -> void:
	_current_deck.deck_name = new_name
	_mark_dirty()


func _on_back_requested() -> void:
	if _is_dirty:
		var modal := _get_modal()
		modal.confirmed.disconnect(_on_delete_confirmed)
		modal.confirmed.connect(_go_back, CONNECT_ONE_SHOT)
		modal.cancelled.connect(
			func() -> void:
				modal.confirmed.connect(_on_delete_confirmed),
			CONNECT_ONE_SHOT
		)
		modal.show_modal("Sair sem salvar?", "Há alterações não salvas. Deseja sair mesmo assim?")
	else:
		_go_back()


# "Voltar": retorna à listagem de decks (DeckList).
func _go_back() -> void:
	get_tree().change_scene_to_file(DECK_LIST_SCENE)


func _mark_dirty() -> void:
	_is_dirty = true
	_get_header().set_dirty(true)


func _refresh_all() -> void:
	_get_header().set_deck_name(_current_deck.deck_name)
	_get_header().set_dirty(_is_dirty)
	_get_rail().bind(_current_deck)
	_get_picker().set_deck_snapshot(_current_deck)


# Refresh leve para mudanças só de cartas (add/remove/foil/limpar): atualiza o rail e
# re-sincroniza as contagens da grade do picker SEM reconstruí-la (sem piscada).
func _refresh_deck_only() -> void:
	_get_header().set_dirty(_is_dirty)
	_get_rail().bind(_current_deck)
	_get_picker().sync_deck_counts(_current_deck)


func _toast(msg: String) -> void:
	_get_toast().show_toast(msg)


func _on_hero_preview(hero: Hero) -> void:
	_get_hero_preview().show_hero(hero)


func _on_card_preview(card_dict: Dictionary) -> void:
	_get_card_preview().show_card(card_dict)


func _get_header()       -> PanelContainer: return $VBox/DBHeader
func _get_picker()       -> PanelContainer: return $VBox/Body/PickerPanel
func _get_rail()         -> PanelContainer: return $VBox/Body/DeckRail
func _get_modal()        -> CanvasLayer:    return $ConfirmModal
func _get_toast()        -> CanvasLayer:    return $ToastLayer
func _get_hero_preview() -> CanvasLayer:    return $HeroPreviewPopup
func _get_card_preview() -> CanvasLayer:    return $CardPreviewPopup
