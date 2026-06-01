extends Control

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")
const LOBBY_SCENE := "res://scenes/ui/lobby/lobby.tscn"

var _current_deck: DeckData   = null
var _saved_snapshot: DeckData = null
var _is_dirty: bool           = false


func _ready() -> void:
	_style_bg()
	_connect_signals()
	_load_or_create_deck()


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
	rail.clear_cards_requested.connect(_on_clear_cards_requested)

	modal.confirmed.connect(_on_delete_confirmed)


func _load_or_create_deck() -> void:
	if DeckStore.decks.size() > 0:
		load_deck(DeckStore.decks[0])
	else:
		var new_d := DeckStore.new_deck()
		load_deck(new_d)


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
	_refresh_all()


func _on_sleeve_changed(sleeve_id: String) -> void:
	_current_deck.sleeve = sleeve_id
	_mark_dirty()


func _on_playmat_changed(playmat_id: String) -> void:
	_current_deck.playmat = playmat_id
	_mark_dirty()


func _on_card_remove(card_name: String) -> void:
	_current_deck.remove_card(card_name)
	_mark_dirty()
	_refresh_all()


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
	_refresh_all()


func _on_save_requested() -> void:
	var errors := _current_deck.validate()
	if not errors.is_empty():
		for e in errors:
			_toast(e)
		return
	DeckStore.save_deck(_current_deck)
	_saved_snapshot = _current_deck.duplicate_data()
	_is_dirty = false
	_get_header().set_dirty(false)
	_toast("Deck salvo!")


func _on_discard_requested() -> void:
	_current_deck = _saved_snapshot.duplicate_data()
	_is_dirty = false
	_refresh_all()


func _on_delete_confirmed() -> void:
	if DeckStore.decks.size() <= 1:
		_toast("Mantenha ao menos um deck")
		return
	DeckStore.delete_deck(_current_deck.deck_id)
	_load_or_create_deck()


func _on_name_changed(new_name: String) -> void:
	_current_deck.deck_name = new_name
	_mark_dirty()


func _on_back_requested() -> void:
	if _is_dirty:
		var modal := _get_modal()
		modal.confirmed.disconnect(_on_delete_confirmed)
		modal.confirmed.connect(_go_to_lobby, CONNECT_ONE_SHOT)
		modal.cancelled.connect(
			func() -> void:
				modal.confirmed.connect(_on_delete_confirmed),
			CONNECT_ONE_SHOT
		)
		modal.show_modal("Sair sem salvar?", "Há alterações não salvas. Deseja sair mesmo assim?")
	else:
		_go_to_lobby()


func _go_to_lobby() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _mark_dirty() -> void:
	_is_dirty = true
	_get_header().set_dirty(true)


func _refresh_all() -> void:
	_get_header().set_deck_name(_current_deck.deck_name)
	_get_header().set_dirty(_is_dirty)
	_get_rail().bind(_current_deck)
	_get_picker().set_deck_snapshot(_current_deck)


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
