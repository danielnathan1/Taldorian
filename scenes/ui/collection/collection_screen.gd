# scenes/ui/collection/collection_screen.gd
# Tela de Coleção — cartas possuídas (quantidade/foil), heróis e cosméticos do jogador.
# Estrutura visual em collection_screen.tscn; o código só estiliza e popula as grades.
# Fluxo: World HUD "Inventário" → Coleção → volta ao mundo (ou lobby se desconectado).
extends Control

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")
const FONT_DECO := preload("res://assets/fonts/CinzelDecorative-Bold.ttf")

const WORLD_SCENE := "res://scenes/world/world_root.tscn"
const LOGIN_SCENE := "res://scenes/ui/login/login.tscn"

const CARD_CELL_SCENE     := preload("res://scenes/ui/collection/components/collection_card_cell.tscn")
const HERO_CELL_SCENE     := preload("res://scenes/ui/collection/components/collection_hero_cell.tscn")
const COSMETIC_CELL_SCENE := preload("res://scenes/ui/collection/components/cosmetic_cell.tscn")

# Chaves dos chips, na MESMA ordem dos botões declarados no .tscn ("" = todos).
const SYM_KEYS: Array[String] = ["", GameSymbols.FOGO, GameSymbols.TERRA, GameSymbols.AGUA, GameSymbols.AR, GameSymbols.RAIO]
const RARITY_KEYS: Array[String] = ["", "COMMON", "RARE", "LEGENDARY", "MYSTIC"]
const CLASS_KEYS: Array[String] = ["", "BARBARIAN", "WARRIOR", "MONK", "ROGUE", "CLERIC", "RANGER", "GUARDIAN", "WIZARD", "SORCERER"]

# Estado dos filtros (aba Cartas)
var _search_text: String = ""
var _active_symbols: Array[String] = []
var _active_timing: String = ""
var _active_rarity: String = ""
# Estado dos filtros (aba Heróis)
var _hero_search_text: String = ""
var _active_classes: Array[String] = []

# ── Header ─────────────────────────────────────────────────────────────────────
@onready var _header: PanelContainer = $VBox/Header
@onready var _back_btn: Button = $VBox/Header/HeaderHBox/BackBtn
@onready var _eyebrow_line: Label = $VBox/Header/HeaderHBox/TitleBox/EyebrowLine
@onready var _eyebrow_title: Label = $VBox/Header/HeaderHBox/TitleBox/EyebrowTitle

# ── Abas (placas com contagem) ─────────────────────────────────────────────────
@onready var _tabs_bar: PanelContainer = $VBox/TabsBar
@onready var _tab_plaques: Array[PanelContainer] = [
	$VBox/TabsBar/TabsCenter/TabsHBox/TabCards,
	$VBox/TabsBar/TabsCenter/TabsHBox/TabHeroes,
	$VBox/TabsBar/TabsCenter/TabsHBox/TabCosmetics,
]
@onready var _tab_panels: Array[Control] = [
	$VBox/CardsTab,
	$VBox/HeroesTab,
	$VBox/CosmeticsTab,
]

# ── Aba Cartas ─────────────────────────────────────────────────────────────────
@onready var _filter_bar: PanelContainer = $VBox/CardsTab/FilterBar
@onready var _search_input: LineEdit = $VBox/CardsTab/FilterBar/FilterVBox/SearchRow/SearchInput
@onready var _timing_select: OptionButton = $VBox/CardsTab/FilterBar/FilterVBox/SearchRow/TimingSelect
@onready var _rarity_label: Label = $VBox/CardsTab/FilterBar/FilterVBox/RarityHBox/RarityLabel
@onready var _rarity_row: HBoxContainer = $VBox/CardsTab/FilterBar/FilterVBox/RarityHBox/RarityRow
@onready var _element_label: Label = $VBox/CardsTab/FilterBar/FilterVBox/ElementHBox/ElementLabel
@onready var _sym_row: HBoxContainer = $VBox/CardsTab/FilterBar/FilterVBox/ElementHBox/SymRow
@onready var _card_list: HFlowContainer = $VBox/CardsTab/GridMargin/GridVBox/CardScroll/CardList
@onready var _cards_empty: Label = $VBox/CardsTab/GridMargin/GridVBox/CardsEmptyLabel

# ── Aba Heróis ─────────────────────────────────────────────────────────────────
@onready var _hero_filter_bar: PanelContainer = $VBox/HeroesTab/HeroFilterBar
@onready var _hero_search_input: LineEdit = $VBox/HeroesTab/HeroFilterBar/HeroFilterVBox/HeroSearchRow/HeroSearchInput
@onready var _class_label: Label = $VBox/HeroesTab/HeroFilterBar/HeroFilterVBox/ClassHBox/ClassLabel
@onready var _class_row: HBoxContainer = $VBox/HeroesTab/HeroFilterBar/HeroFilterVBox/ClassHBox/ClassRow
@onready var _hero_list: HFlowContainer = $VBox/HeroesTab/HeroGridMargin/HeroGridVBox/HeroScroll/HeroList
@onready var _heroes_empty: Label = $VBox/HeroesTab/HeroGridMargin/HeroGridVBox/HeroesEmptyLabel

# ── Aba Cosméticos ─────────────────────────────────────────────────────────────
@onready var _sleeves_title: Label = $VBox/CosmeticsTab/CosScroll/CosVBox/SleevesTitle
@onready var _sleeve_flow: HFlowContainer = $VBox/CosmeticsTab/CosScroll/CosVBox/SleeveFlow
@onready var _playmats_title: Label = $VBox/CosmeticsTab/CosScroll/CosVBox/PlaymatsTitle
@onready var _playmat_flow: HFlowContainer = $VBox/CosmeticsTab/CosScroll/CosVBox/PlaymatFlow

# ── Previews ───────────────────────────────────────────────────────────────────
@onready var _card_preview: CanvasLayer = $CardPreviewPopup
@onready var _hero_preview: CanvasLayer = $HeroPreviewPopup


func _ready() -> void:
	_apply_styles()
	_wire()
	_switch_tab(0)
	await _load_inventory()
	_rebuild_cards()
	_rebuild_heroes()
	_build_cosmetics()
	_update_tab_counts()


# Carrega a coleção do jogador do backend (/players/me/inventory) antes de montar
# as grades. Se a API falhar, segue com a coleção local (seed) — testável offline.
func _load_inventory() -> void:
	var overlay := _make_loading_overlay("Carregando coleção…")
	add_child(overlay)
	var res := await ApiClient.get_inventory()
	if res.ok:
		Collection.load_inventory(res.data)
	else:
		push_warning("Coleção: inventário indisponível (%s) — usando coleção local." % res.error)
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
	label.add_theme_font_override("font", S.FONT_REG)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", S.C_GOLD_GLOW)
	center.add_child(label)
	return layer


# ── Wiring ─────────────────────────────────────────────────────────────────────

func _wire() -> void:
	_back_btn.pressed.connect(_go_back)

	for i in _tab_plaques.size():
		var idx := i
		_tab_plaques[i].connect("pressed", func() -> void: _switch_tab(idx))

	_search_input.text_changed.connect(func(text: String) -> void:
		_search_text = text
		_rebuild_cards())
	_hero_search_input.text_changed.connect(func(text: String) -> void:
		_hero_search_text = text
		_rebuild_heroes())

	_setup_timing_select()
	_wire_chip_row(_sym_row, SYM_KEYS, _on_sym_chip)
	_wire_chip_row(_rarity_row, RARITY_KEYS, _on_rarity_chip)
	_wire_chip_row(_class_row, CLASS_KEYS, _on_class_chip)
	_refresh_sym_chips()
	_refresh_rarity_chips()
	_refresh_class_chips()


func _setup_timing_select() -> void:
	_timing_select.clear()
	var labels  := ["Todos os tipos", "⚡ Ação", "✦ Bônus", "🛡 Reação"]
	var timings := ["",               "ACTION",  "BONUS_ACTION", "REACTION"]
	for i in labels.size():
		_timing_select.add_item(labels[i])
		_timing_select.set_item_metadata(i, timings[i])
	_timing_select.selected = 0
	_timing_select.item_selected.connect(func(index: int) -> void:
		_active_timing = _timing_select.get_item_metadata(index)
		_rebuild_cards())


func _wire_chip_row(row: Container, keys: Array[String], handler: Callable) -> void:
	for i in row.get_child_count():
		var btn := row.get_child(i) as Button
		if btn == null or i >= keys.size():
			continue
		var key: String = keys[i]
		btn.pressed.connect(func() -> void: handler.call(key))


# ── Filtros ────────────────────────────────────────────────────────────────────

func _on_sym_chip(key: String) -> void:
	_toggle_multi(_active_symbols, key)
	_refresh_sym_chips()
	_rebuild_cards()


func _on_class_chip(key: String) -> void:
	_toggle_multi(_active_classes, key)
	_refresh_class_chips()
	_rebuild_heroes()


func _on_rarity_chip(key: String) -> void:
	_active_rarity = "" if _active_rarity == key else key
	_refresh_rarity_chips()
	_rebuild_cards()


func _toggle_multi(list: Array[String], key: String) -> void:
	if key == "":
		list.clear()
	elif key in list:
		list.erase(key)
	else:
		list.append(key)


func _refresh_sym_chips() -> void:
	_refresh_multi_chip_row(_sym_row, SYM_KEYS, _active_symbols)


func _refresh_class_chips() -> void:
	_refresh_multi_chip_row(_class_row, CLASS_KEYS, _active_classes)


func _refresh_rarity_chips() -> void:
	for i in _rarity_row.get_child_count():
		var btn := _rarity_row.get_child(i) as Button
		if btn != null and i < RARITY_KEYS.size():
			_chip(btn, _active_rarity == RARITY_KEYS[i])


func _refresh_multi_chip_row(row: Container, keys: Array[String], active: Array[String]) -> void:
	for i in row.get_child_count():
		var btn := row.get_child(i) as Button
		if btn == null or i >= keys.size():
			continue
		var is_active := active.is_empty() if keys[i] == "" else keys[i] in active
		_chip(btn, is_active)


# Chip do padrão do deck builder, com fonte maior (fontes da tela ampliadas).
func _chip(btn: Button, active: bool) -> void:
	S.apply_chip(btn, active)
	btn.add_theme_font_size_override("font_size", 14)


# ── Grades ─────────────────────────────────────────────────────────────────────

func _rebuild_cards() -> void:
	for child in _card_list.get_children():
		child.queue_free()
	var no_deck_filter: Array[String] = []
	var cards := Collection.query_cards(_search_text, _active_symbols, _active_timing, no_deck_filter, _active_rarity)
	for card_dict in cards:
		var cell := CARD_CELL_SCENE.instantiate()
		_card_list.add_child(cell)
		cell.bind(card_dict)
		cell.preview_requested.connect(_card_preview.show_card)
	_cards_empty.visible = cards.is_empty()


func _rebuild_heroes() -> void:
	for child in _hero_list.get_children():
		child.queue_free()
	var heroes := Collection.query_heroes(_hero_search_text, _active_classes)
	for hero in heroes:
		var cell := HERO_CELL_SCENE.instantiate()
		_hero_list.add_child(cell)
		cell.bind(hero)
		cell.preview_requested.connect(_hero_preview.show_hero)
	_heroes_empty.visible = heroes.is_empty()


# Cosméticos são estáticos na sessão — montado uma única vez no _ready.
func _build_cosmetics() -> void:
	for s in CosmeticsStore.get_available_sleeves():
		var cell := COSMETIC_CELL_SCENE.instantiate()
		_sleeve_flow.add_child(cell)
		cell.bind(str(s.get("name", "")), "res://assets/sleve/%s.png" % str(s.get("art_key", "")), Vector2(72, 100))
	for p in CosmeticsStore.get_available_playmats():
		var cell := COSMETIC_CELL_SCENE.instantiate()
		_playmat_flow.add_child(cell)
		cell.bind(str(p.get("name", "")), "res://assets/playmats/%s.png" % str(p.get("art_key", "")), Vector2(192, 108))


# Contagem "possuídas/total" exibida em cada placa de aba.
func _update_tab_counts() -> void:
	var no_symbols: Array[String] = []
	var no_deck_filter: Array[String] = []
	var owned_cards := Collection.query_cards("", no_symbols, "", no_deck_filter, "").size()
	var total_cards: int = Collection.all_card_dicts.size()
	var owned_heroes := Collection.query_heroes("", no_symbols).size()
	var total_heroes: int = Collection.all_heroes.size()
	var owned_cosmetics := CosmeticsStore.get_available_sleeves().size() + CosmeticsStore.get_available_playmats().size()
	var total_cosmetics: int = CosmeticsStore.get_catalog_sleeve_count() + CosmeticsStore.get_catalog_playmat_count()
	_tab_plaques[0].call("set_count", "%d/%d" % [owned_cards, total_cards])
	_tab_plaques[1].call("set_count", "%d/%d" % [owned_heroes, total_heroes])
	_tab_plaques[2].call("set_count", "%d/%d" % [owned_cosmetics, total_cosmetics])


# ── Abas ───────────────────────────────────────────────────────────────────────

func _switch_tab(idx: int) -> void:
	for i in _tab_panels.size():
		_tab_panels[i].visible = (i == idx)
		_tab_plaques[i].call("set_active", i == idx)


# ── Navegação ──────────────────────────────────────────────────────────────────

func _go_back() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		get_tree().change_scene_to_file(WORLD_SCENE)
	else:
		get_tree().change_scene_to_file(LOGIN_SCENE)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _card_preview.visible:
			_card_preview.hide_popup()
		elif _hero_preview.visible:
			_hero_preview.hide_popup()
		else:
			_go_back()
		get_viewport().set_input_as_handled()


# ── Estilos ────────────────────────────────────────────────────────────────────

func _apply_styles() -> void:
	$BG.color = S.C_BG_DEEP

	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.05, 0.05, 0.10, 0.85)
	hs.border_color = S.border_gold(0.18)
	hs.border_width_bottom = 1
	hs.set_content_margin(SIDE_LEFT, 26)
	hs.set_content_margin(SIDE_RIGHT, 26)
	hs.set_content_margin(SIDE_TOP, 8)
	hs.set_content_margin(SIDE_BOTTOM, 8)
	_header.add_theme_stylebox_override("panel", hs)

	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.05, 0.05, 0.10, 0.4)
	ts.border_color = S.border_gold(0.18)
	ts.border_width_bottom = 1
	ts.set_content_margin(SIDE_LEFT, 26)
	ts.set_content_margin(SIDE_RIGHT, 26)
	ts.set_content_margin(SIDE_TOP, 18)
	ts.set_content_margin(SIDE_BOTTOM, 18)
	_tabs_bar.add_theme_stylebox_override("panel", ts)

	for bar: PanelContainer in [_filter_bar, _hero_filter_bar]:
		var fs := StyleBoxFlat.new()
		fs.bg_color = Color(0.05, 0.05, 0.10, 0.35)
		fs.border_color = S.border_gold(0.18)
		fs.border_width_bottom = 1
		fs.set_content_margin(SIDE_LEFT, 30)
		fs.set_content_margin(SIDE_RIGHT, 30)
		fs.set_content_margin(SIDE_TOP, 12)
		fs.set_content_margin(SIDE_BOTTOM, 12)
		bar.add_theme_stylebox_override("panel", fs)

	_back_btn.add_theme_font_override("font", S.FONT_REG)
	_back_btn.add_theme_font_size_override("font_size", 14)
	_back_btn.add_theme_color_override("font_color", S.C_GOLD_DIM)
	_back_btn.add_theme_color_override("font_hover_color", S.C_GOLD)

	_style_lbl(_eyebrow_line, S.FONT_REG, 12, Color(S.C_GOLD_DIM, 0.7))
	_style_lbl(_eyebrow_title, FONT_DECO, 26, S.C_GOLD_GLOW)

	for lbl: Label in [_rarity_label, _element_label, _class_label]:
		_style_lbl(lbl, S.FONT_REG, 13, Color(S.C_GOLD_DIM, 0.85))

	for input: LineEdit in [_search_input, _hero_search_input]:
		input.add_theme_font_override("font", S.FONT_REG)
		input.add_theme_font_size_override("font_size", 15)
	_timing_select.add_theme_font_override("font", S.FONT_REG)
	_timing_select.add_theme_font_size_override("font_size", 14)

	_style_lbl(_cards_empty, S.FONT_REG, 16, Color(S.C_PARCHMENT_D, 0.55))
	_style_lbl(_heroes_empty, S.FONT_REG, 16, Color(S.C_PARCHMENT_D, 0.55))
	_style_lbl(_sleeves_title, S.FONT_REG, 16, S.C_GOLD_DIM)
	_style_lbl(_playmats_title, S.FONT_REG, 16, S.C_GOLD_DIM)


func _style_lbl(label: Label, font: Font, size: int, color: Color) -> void:
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
