# scenes/ui/catalog/catalog_screen.gd
# Tela do Catálogo — lista de coleções e o "fichário" (binder) de cada uma.
# O fichário mostra TODAS as cartas da coleção (ordenadas por id): coloridas se o
# jogador possui, cinza se não. Duas páginas 4×4 (16 cartas) por spread, com folhear.
# Fluxo: World HUD "Inventário → Catálogo" → lista → fichário → volta.
extends Control

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")
const FONT_DECO := preload("res://assets/fonts/CinzelDecorative-Bold.ttf")

const WORLD_SCENE := "res://scenes/world/world_root.tscn"
const LOGIN_SCENE := "res://scenes/ui/login/login.tscn"

const COLLECTION_TILE := preload("res://scenes/ui/catalog/components/collection_card_tile.tscn")
const BINDER_SLOT     := preload("res://scenes/ui/catalog/components/binder_card_slot.tscn")
const GRID_LINES      := preload("res://scenes/ui/catalog/components/grid_lines.gd")

const CARDS_PER_PAGE := 16
const CARDS_PER_SPREAD := CARDS_PER_PAGE * 2

var _all_cards: Array[Dictionary] = []   # cartas da coleção aberta, ordenadas por id
var _spread: int = 0
var _spread_count: int = 0
var _in_binder: bool = false
var _drag_start_x: float = -1.0

@onready var _header: PanelContainer = $VBox/Header
@onready var _back_btn: Button = $VBox/Header/HeaderHBox/BackBtn
@onready var _eyebrow_line: Label = $VBox/Header/HeaderHBox/TitleBox/EyebrowLine
@onready var _eyebrow_title: Label = $VBox/Header/HeaderHBox/TitleBox/EyebrowTitle

@onready var _list_state: MarginContainer = $VBox/ListState
@onready var _collection_list: HFlowContainer = $VBox/ListState/ListScroll/CollectionList

@onready var _binder_state: MarginContainer = $VBox/BinderState
@onready var _binder_title: Label = $VBox/BinderState/BinderVBox/BinderTitle
@onready var _book: HBoxContainer = $VBox/BinderState/BinderVBox/Book
@onready var _page_left: GridContainer = $VBox/BinderState/BinderVBox/Book/PageLeftPanel/PageLeftMargin/PageLeft
@onready var _page_right: GridContainer = $VBox/BinderState/BinderVBox/Book/PageRightPanel/PageRightMargin/PageRight
@onready var _page_left_panel: PanelContainer = $VBox/BinderState/BinderVBox/Book/PageLeftPanel
@onready var _page_right_panel: PanelContainer = $VBox/BinderState/BinderVBox/Book/PageRightPanel
@onready var _spine: Panel = $VBox/BinderState/BinderVBox/Book/Spine
@onready var _prev_btn: Button = $VBox/BinderState/BinderVBox/NavRow/PrevBtn
@onready var _next_btn: Button = $VBox/BinderState/BinderVBox/NavRow/NextBtn
@onready var _page_counter: Label = $VBox/BinderState/BinderVBox/NavRow/PageCounter

@onready var _card_preview: CanvasLayer = $CardPreviewPopup


func _ready() -> void:
	_apply_styles()
	_build_spine()
	_build_grid_lines()
	_back_btn.pressed.connect(_go_back)


# Linhas douradas de divisão sobre cada página (grade do fichário). Ficam no mesmo
# MarginContainer do grid, então cobrem exatamente o mesmo rect e alinham as células.
func _build_grid_lines() -> void:
	for grid: GridContainer in [_page_left, _page_right]:
		var lines := GRID_LINES.new()
		grid.get_parent().add_child(lines)
	_prev_btn.pressed.connect(func() -> void: _go_spread(_spread - 1, -1))
	_next_btn.pressed.connect(func() -> void: _go_spread(_spread + 1, 1))
	_book.gui_input.connect(_on_book_input)
	_switch_to_list()
	await _load_collections()


# Lombada do fichário: gutter escuro com bordas douradas + 3 argolas.
func _build_spine() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.07, 1.0)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_color = S.border_gold(0.35)
	_spine.add_theme_stylebox_override("panel", sb)
	for r in 3:
		var ring := Panel.new()
		ring.custom_minimum_size = Vector2(10, 10)
		ring.set_anchors_preset(Control.PRESET_CENTER)
		ring.anchor_top = 0.28 + r * 0.22
		ring.anchor_bottom = ring.anchor_top
		ring.offset_left = -5
		ring.offset_right = 5
		ring.offset_top = -5
		ring.offset_bottom = 5
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0.20, 0.19, 0.16, 1.0)
		rs.set_corner_radius_all(5)
		rs.set_border_width_all(1)
		rs.border_color = S.border_gold(0.55)
		ring.add_theme_stylebox_override("panel", rs)
		_spine.add_child(ring)


# ── Lista de coleções ──────────────────────────────────────────────────────────

func _load_collections() -> void:
	var overlay := _make_loading_overlay("Carregando catálogo…")
	add_child(overlay)
	# Garante o inventário carregado (posse define colorida vs cinza no fichário).
	if not Collection.is_inventory_loaded():
		var inv := await ApiClient.get_inventory()
		if inv.ok:
			Collection.load_inventory(inv.data)
	var res := await ApiClient.get_collections()
	var collections: Array = res.data if res.ok and res.data is Array else []
	if collections.is_empty():
		# Fallback local (sem backend): set base + expansão "Ecos do Abismo".
		collections = [
			{ "name": "Origens de Taldorian", "artKey": "taldorian_origins" },
			{ "name": "Ecos do Abismo", "artKey": "ecos_do_abismo" },
		]
	_build_collection_list(collections)
	if is_instance_valid(overlay):
		overlay.queue_free()


func _build_collection_list(collections: Array) -> void:
	for c in _collection_list.get_children():
		c.queue_free()
	for entry: Dictionary in collections:
		var tile := COLLECTION_TILE.instantiate()
		_collection_list.add_child(tile)
		var art_key := str(entry.get("artKey", ""))
		tile.bind(str(entry.get("name", "Coleção")), "res://assets/collections/%s.png" % art_key)
		tile.pressed.connect(func() -> void: _open_binder(str(entry.get("name", "Coleção"))))


# ── Fichário ───────────────────────────────────────────────────────────────────

## Coleção-padrão das cartas sem o campo "collection" (o set base histórico).
const DEFAULT_COLLECTION := "Origens de Taldorian"

func _open_binder(p_name: String) -> void:
	# Cartas da coleção aberta, ordenadas por id (ordem fixa). Cartas sem "collection"
	# pertencem ao set base ("Origens de Taldorian").
	_all_cards = []
	for d in Collection.all_card_dicts:
		var col := str(d.get("collection", DEFAULT_COLLECTION))
		if col == p_name:
			_all_cards.append(d)
	_all_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("id", 0)) < int(b.get("id", 0)))
	# Contagem possuídas/total no título (diagnóstico direto: se X == total, o jogador
	# tem o set inteiro e nada fica P&B; se menos, as cinza estão nas páginas onde caem).
	var owned_count := 0
	for d in _all_cards:
		if Collection.get_owned_quantity(int(d.get("id", -1))) > 0:
			owned_count += 1
	_binder_title.text = "%s   ·   %d/%d" % [p_name, owned_count, _all_cards.size()]
	_spread_count = maxi(1, int(ceil(float(_all_cards.size()) / float(CARDS_PER_SPREAD))))
	_spread = 0
	_fill_spread()
	_switch_to_binder()


func _fill_spread() -> void:
	_populate_page(_page_left, _spread * CARDS_PER_SPREAD)
	_populate_page(_page_right, _spread * CARDS_PER_SPREAD + CARDS_PER_PAGE)
	_page_counter.text = "%d / %d" % [_spread + 1, _spread_count]
	_prev_btn.disabled = _spread <= 0
	_next_btn.disabled = _spread >= _spread_count - 1


func _populate_page(grid: GridContainer, start: int) -> void:
	for c in grid.get_children():
		c.queue_free()
	# Sempre 16 bolsos por página — os sem carta ficam vazios (visual de fichário).
	for i in CARDS_PER_PAGE:
		var idx := start + i
		var slot := BINDER_SLOT.instantiate()
		grid.add_child(slot)
		if idx < _all_cards.size():
			var card_dict: Dictionary = _all_cards[idx]
			var owned := Collection.get_owned_quantity(int(card_dict.get("id", -1))) > 0
			slot.bind(card_dict, owned)
			slot.preview_requested.connect(_card_preview.show_card)
		else:
			slot.set_empty()


# Troca de spread (sem animação por enquanto — troca direta).
func _go_spread(new_idx: int, _direction: int) -> void:
	if new_idx < 0 or new_idx >= _spread_count or new_idx == _spread:
		return
	_spread = new_idx
	_fill_spread()


func _on_book_input(event: InputEvent) -> void:
	# Clicar-arrastar horizontal também vira a página.
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var dx: float = event.position.x - _drag_start_x
		if _drag_start_x >= 0.0 and absf(dx) > 60.0:
			if dx < 0.0:
				_go_spread(_spread + 1, 1)
			else:
				_go_spread(_spread - 1, -1)
		_drag_start_x = -1.0
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_start_x = event.position.x


# ── Estados / navegação ────────────────────────────────────────────────────────

func _switch_to_list() -> void:
	_in_binder = false
	_list_state.visible = true
	_binder_state.visible = false


func _switch_to_binder() -> void:
	_in_binder = true
	_list_state.visible = false
	_binder_state.visible = true


func _go_back() -> void:
	if _in_binder:
		_switch_to_list()
		return
	var peer := multiplayer.multiplayer_peer
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		get_tree().change_scene_to_file(WORLD_SCENE)
	else:
		get_tree().change_scene_to_file(LOGIN_SCENE)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _card_preview.visible:
			_card_preview.hide_popup()
		else:
			_go_back()
		get_viewport().set_input_as_handled()


# ── Infra ──────────────────────────────────────────────────────────────────────

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

	_back_btn.add_theme_font_override("font", S.FONT_REG)
	_back_btn.add_theme_font_size_override("font_size", 14)
	_back_btn.add_theme_color_override("font_color", S.C_GOLD_DIM)
	_back_btn.add_theme_color_override("font_hover_color", S.C_GOLD)

	_style_lbl(_eyebrow_line, S.FONT_REG, 12, Color(S.C_GOLD_DIM, 0.7))
	_style_lbl(_eyebrow_title, FONT_DECO, 26, S.C_GOLD_GLOW)
	_style_lbl(_binder_title, FONT_DECO, 20, S.C_GOLD_GLOW)
	_style_lbl(_page_counter, S.FONT_REG, 15, S.C_PARCHMENT_D)

	# Páginas do fichário: couro escuro com borda dourada; a esquerda "sangra" a
	# sombra à direita (junto à lombada) e a direita à esquerda, dando volume de livro.
	_page_left_panel.add_theme_stylebox_override("panel", _page_style(true))
	_page_right_panel.add_theme_stylebox_override("panel", _page_style(false))

	for btn: Button in [_prev_btn, _next_btn]:
		S.apply_button_gold(btn)
		btn.add_theme_font_size_override("font_size", 22)
		btn.custom_minimum_size = Vector2(64, 44)


# Estilo de uma página do fichário (couro escuro + borda). p_left define de que lado
# fica a borda mais forte (a da lombada).
func _page_style(p_left: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.07, 0.11, 1.0)
	sb.set_corner_radius_all(6)
	if p_left:
		sb.corner_radius_top_right = 0
		sb.corner_radius_bottom_right = 0
	else:
		sb.corner_radius_top_left = 0
		sb.corner_radius_bottom_left = 0
	sb.set_border_width_all(1)
	sb.border_color = S.border_gold(0.28)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	sb.shadow_size = 6
	return sb


func _style_lbl(label: Label, font: Font, size: int, color: Color) -> void:
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
