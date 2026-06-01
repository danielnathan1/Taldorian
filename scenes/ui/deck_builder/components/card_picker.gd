extends Control

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

signal card_add_requested(card_name: String)
signal card_remove_requested(card_name: String)
signal card_preview_requested(card_dict: Dictionary)

var _active_symbols: Array[String] = []
var _active_timing: String = ""
var _active_rarity: String = ""
var _search_text: String = ""
var _only_in_deck: bool = false
var _deck_snapshot: DeckData = null

const CARD_ROW_SCENE := preload("res://scenes/ui/deck_builder/components/picker_card_row.tscn")


func _ready() -> void:
	_get_search_input().text_changed.connect(_on_search_changed)
	_get_only_deck_btn().toggled.connect(_on_only_deck_toggled)
	_setup_timing_select()
	_build_chips()
	_rebuild_list()


func refresh(deck: DeckData) -> void:
	_deck_snapshot = deck
	_rebuild_list()


func _setup_timing_select() -> void:
	var sel := _get_timing_select()
	sel.clear()
	var labels  := ["Todos os tipos", "⚡ Ação", "✦ Bônus", "🛡 Reação"]
	var timings := ["",               "ACTION",  "BONUS_ACTION", "REACTION"]
	for i in labels.size():
		sel.add_item(labels[i])
		sel.set_item_metadata(i, timings[i])
	sel.selected = 0
	sel.item_selected.connect(_on_timing_selected)


func _on_timing_selected(index: int) -> void:
	_active_timing = _get_timing_select().get_item_metadata(index)
	_rebuild_list()


func _build_chips() -> void:
	_build_symbol_chips()
	_build_rarity_chips()
	_refresh_chips()


func _build_symbol_chips() -> void:
	var row := _get_sym_row()
	for c in row.get_children(): c.queue_free()
	row.add_child(_make_chip("Todos", ""))
	var syms   := ["fogo", "terra", "agua", "ar"]
	var labels := ["🔥 Fogo", "🌿 Terra", "💧 Água", "💨 Ar"]
	for i in syms.size():
		row.add_child(_make_chip(labels[i], syms[i]))


func _build_rarity_chips() -> void:
	var row := _get_rarity_row()
	for c in row.get_children(): c.queue_free()
	var rarities := ["", "COMMON",   "RARE",  "LEGENDARY",   "MYSTIC"]
	var labels   := ["Todas", "⬜ Comum", "🔵 Rara", "🟡 Lendária", "🟣 Mística"]
	for i in rarities.size():
		var btn := Button.new()
		btn.text        = labels[i]
		btn.toggle_mode = true
		btn.focus_mode  = Control.FOCUS_NONE
		var key: String = rarities[i]
		btn.pressed.connect(func() -> void: _on_rarity_chip_pressed(key))
		row.add_child(btn)
	_refresh_rarity_row()


func _on_rarity_chip_pressed(key: String) -> void:
	_active_rarity = "" if _active_rarity == key else key
	_refresh_rarity_row()
	_rebuild_list()


func _refresh_rarity_row() -> void:
	var row := _get_rarity_row()
	var rarities := ["", "COMMON", "RARE", "LEGENDARY", "MYSTIC"]
	for i in row.get_child_count():
		var btn := row.get_child(i) as Button
		if btn:
			S.apply_chip(btn, _active_rarity == rarities[i])


func _make_chip(label: String, key: String) -> Button:
	var btn := Button.new()
	btn.text        = label
	btn.toggle_mode = true
	btn.focus_mode  = Control.FOCUS_NONE
	btn.pressed.connect(func() -> void: _on_chip_pressed(key, btn))
	return btn


func _on_chip_pressed(key: String, _btn: Button) -> void:
	if key == "":
		_active_symbols.clear()
	else:
		if key in _active_symbols: _active_symbols.erase(key)
		else: _active_symbols.append(key)
	_refresh_chips()
	_rebuild_list()


func _refresh_chips() -> void:
	_refresh_chip_row(_get_sym_row())
	_refresh_rarity_row()


func _refresh_chip_row(row: HBoxContainer) -> void:
	var all_btn := row.get_child(0) as Button
	if all_btn:
		S.apply_chip(all_btn, _active_symbols.is_empty())
	var keys_sym := ["fogo", "terra", "agua", "ar"]
	for i in range(1, row.get_child_count()):
		var btn := row.get_child(i) as Button
		if not btn: continue
		var key: String = keys_sym[i - 1] if i - 1 < keys_sym.size() else ""
		S.apply_chip(btn, key in _active_symbols)


func _on_search_changed(text: String) -> void:
	_search_text = text
	_rebuild_list()


func _on_only_deck_toggled(pressed: bool) -> void:
	_only_in_deck = pressed
	_rebuild_list()


func _rebuild_list() -> void:
	var list := _get_list()
	for child in list.get_children():
		child.queue_free()

	var in_deck_names: Array[String] = []
	if _only_in_deck and _deck_snapshot:
		for entry in _deck_snapshot.card_entries:
			in_deck_names.append(entry["name"])

	var cards := Collection.query_cards(_search_text, _active_symbols, _active_timing, in_deck_names, _active_rarity)

	for card_dict in cards:
		var card_name: String = card_dict.get("name", "")
		var count_in_deck := _deck_snapshot.count_of(card_name) if _deck_snapshot else 0
		var max_copies    := Collection.get_max_copies(card_name)

		var row: Node = CARD_ROW_SCENE.instantiate()
		list.add_child(row)
		row.call("bind", card_dict, count_in_deck, max_copies)
		row.connect("add_pressed", _on_row_add)
		row.connect("remove_pressed", _on_row_remove)
		row.connect("preview_requested", _on_row_preview)


func _on_row_add(card_name: String) -> void:
	card_add_requested.emit(card_name)


func _on_row_remove(card_name: String) -> void:
	card_remove_requested.emit(card_name)


func _on_row_preview(card_dict: Dictionary) -> void:
	card_preview_requested.emit(card_dict)


func _get_search_input()   -> LineEdit:      return $VBox/SearchRow/SearchInput
func _get_sym_row()        -> HBoxContainer: return $VBox/SymRow
func _get_timing_select()  -> OptionButton:  return $VBox/TimingSelect
func _get_rarity_row()     -> HBoxContainer: return $VBox/RarityRow
func _get_only_deck_btn()  -> Button:        return $VBox/SearchRow/OnlyDeckBtn
func _get_list()           -> HFlowContainer: return $VBox/Scroll/List
