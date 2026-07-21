# Painel de inventário do Ferreiro: eyebrow/título + filtro por elemento + grade de
# mini-cards (InvCard). Lê cartas possuídas (dicts do catálogo) e emite
# `card_added(card)` ao clicar. `set_available_counts` esmaece/desabilita conforme a
# quantidade ainda disponível (possuída − já encaixada).
class_name ForgeInvPanel
extends PanelContainer

signal card_added(card: Dictionary)

const ELEMENTS := [
	{ "key": "", "glyph": "✶", "name": "Tudo", "icon": "" },
	{ "key": GameSymbols.FOGO, "glyph": "", "name": "Fogo", "icon": "res://assets/icons/elements/fire.png" },
	{ "key": GameSymbols.TERRA, "glyph": "", "name": "Terra", "icon": "res://assets/icons/elements/earth.png" },
	{ "key": GameSymbols.AGUA, "glyph": "", "name": "Água", "icon": "res://assets/icons/elements/water.png" },
	{ "key": GameSymbols.AR, "glyph": "", "name": "Ar", "icon": "res://assets/icons/elements/wind.png" },
	{ "key": GameSymbols.RAIO, "glyph": "", "name": "Raio", "icon": "res://assets/icons/elements/lightning.png" },
	{ "key": GameSymbols.TREVAS, "glyph": "", "name": "Trevas", "icon": "res://assets/icons/elements/dark.png" },
]

const RARITIES := [
	{ "key": "", "name": "Todas" },
	{ "key": "COMMON", "name": "Comum" },
	{ "key": "RARE", "name": "Rara" },
	{ "key": "LEGENDARY", "name": "Lendária" },
	{ "key": "MYSTIC", "name": "Mística" },
]

# Sentinela de restrição "sem alvo ainda" (bloqueia adição sem travar/apagar).
const RESTRICT_NONE := "__none__"

# CardView real, reduzido via `scale` (igual ao inventário da troca — preserva proporções).
const CARD_VIEW := preload("res://scenes/ui/card_view/card_view.tscn")
const CARD_NATURAL := Vector2(160, 240)
const TILE := Vector2(100, 150)
const PREVIEW_SIZE := Vector2(360, 540)

# Onde os overlays (menu/preview) são inseridos — full-screen acima de tudo. As views
# setam para o host (blacksmith); fallback para a cena atual.
var overlay_host: Control

# Restrição de adição (ritual dirigido): só cartas dessa raridade podem ser oferecidas.
# "" = sem restrição. Quando bloqueado, o menu mostra `restrict_hint` em vez de "Adicionar".
var restrict_rarity: String = ""
var restrict_hint: String = ""

var inventory: Array = []          # Array[Dictionary] — cartas possuídas (cru do catálogo)
var _available: Dictionary = {}    # id (int) -> { "normal": int, "foil": int }
var _filter: String = ""           # filtro de elemento
var _rarity_filter: String = ""    # filtro de raridade
var _name_filter: String = ""      # busca por nome
var _sort_by_qty: bool = false     # ordenar por quantidade possuída (desc)
var _rarity_btns: Dictionary = {}  # key -> Button (para set_rarity_filter externo)
var _grid: HFlowContainer
var _rows_by_id: Dictionary = {}   # id -> { card, button, badge }
var _card_menu: Control            # menuzinho de opções ao clicar numa carta
var _card_preview: Control         # overlay de detalhe (carta grande)


func _ready() -> void:
	custom_minimum_size = Vector2(388, 0)
	add_theme_stylebox_override("panel", ForgeTheme.panel_style(
		Color(ForgeTheme.BG_MID.r, ForgeTheme.BG_MID.g, ForgeTheme.BG_MID.b, 0.6),
		ForgeTheme.GOLD_SOFT_A, 1, 0))
	_build()


func _build() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)

	vb.add_child(ForgeTheme.make_eyebrow("Sua Coleção", ForgeTheme.GOLD_DIM, 10))
	vb.add_child(ForgeTheme.make_label("Inventário", ForgeTheme.font_display(), 18, ForgeTheme.GOLD_GLOW))

	# Filtro por elemento.
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 4)
	vb.add_child(filters)
	for el in ELEMENTS:
		var b := Button.new()
		b.tooltip_text = el.name
		b.toggle_mode = true
		b.button_pressed = el.key == _filter
		b.custom_minimum_size = Vector2(48, 38)
		ForgeTheme.style_ghost_button(b, 14)
		if str(el.icon) != "":
			b.icon = load(el.icon)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 24)
		else:
			b.text = el.glyph
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_filter = el.key
				for other in filters.get_children():
					if other != b and other is Button:
						(other as Button).button_pressed = false
				_rebuild_grid())
		filters.add_child(b)

	# Filtro por raridade.
	var rarity_filters := HBoxContainer.new()
	rarity_filters.add_theme_constant_override("separation", 4)
	vb.add_child(rarity_filters)
	for rar in RARITIES:
		var rb := Button.new()
		rb.text = str(rar.name)
		rb.toggle_mode = true
		rb.button_pressed = rar.key == _rarity_filter
		rb.custom_minimum_size = Vector2(0, 30)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ForgeTheme.style_ghost_button(rb, 11)
		if str(rar.key) != "":
			rb.add_theme_color_override("font_color", ForgeTheme.rarity_color(str(rar.key)))
		_rarity_btns[str(rar.key)] = rb
		rb.toggled.connect(_on_rarity_toggled.bind(str(rar.key)))
		rarity_filters.add_child(rb)

	# Busca por nome + ordenar por quantidade.
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	vb.add_child(tools)
	var search := LineEdit.new()
	search.placeholder_text = "Buscar por nome..."
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.add_theme_font_override("font", ForgeTheme.font_body())
	search.add_theme_font_size_override("font_size", 12)
	search.text_changed.connect(func(t: String) -> void:
		_name_filter = t
		_rebuild_grid())
	tools.add_child(search)
	var sort_btn := Button.new()
	sort_btn.toggle_mode = true
	sort_btn.text = "↓ Qtd"
	sort_btn.tooltip_text = "Ordenar por quantidade"
	sort_btn.custom_minimum_size = Vector2(0, 32)
	ForgeTheme.style_ghost_button(sort_btn, 12)
	sort_btn.toggled.connect(func(on: bool) -> void:
		_sort_by_qty = on
		_rebuild_grid())
	tools.add_child(sort_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)


# ── API pública ──────────────────────────────────────────────────────────────
func set_inventory(cards: Array) -> void:
	inventory = cards
	_rebuild_grid()


func set_available_counts(avail: Dictionary) -> void:
	_available = avail
	for cid in _rows_by_id:
		_update_row_state(cid)


# Define o filtro de raridade de fora (ex.: ritual fixa na raridade do alvo).
func set_rarity_filter(key: String) -> void:
	_rarity_filter = key
	for k in _rarity_btns:
		(_rarity_btns[k] as Button).set_pressed_no_signal(k == key)
	_rebuild_grid()


# True quando há uma raridade-alvo travada (ritual com alvo escolhido).
func _locked() -> bool:
	return restrict_rarity != "" and restrict_rarity != RESTRICT_NONE


# Aplica a restrição do ritual: apaga as cartas de outras raridades (não-adicionáveis),
# mas mantém os filtros livres para o usuário navegar.
# rarity == "" → sem restrição; == RESTRICT_NONE → sem alvo (bloqueia adição, sem apagar).
func set_restriction(rarity: String, hint: String) -> void:
	restrict_rarity = rarity
	restrict_hint = hint
	_rebuild_grid()


func _on_rarity_toggled(on: bool, key: String) -> void:
	if not on:
		return
	_rarity_filter = key
	for k in _rarity_btns:
		(_rarity_btns[k] as Button).set_pressed_no_signal(k == key)
	_rebuild_grid()


# ── Construção da grade ──────────────────────────────────────────────────────
func _rebuild_grid() -> void:
	_rows_by_id.clear()
	for c in _grid.get_children():
		c.queue_free()
	var needle := _name_filter.strip_edges().to_lower()
	var shown: Array = []
	for card in inventory:
		if _filter != "" and not (_filter in card.get("symbols", [])):
			continue
		if _rarity_filter != "" and str(card.get("rarity", "COMMON")) != _rarity_filter:
			continue
		if needle != "" and not str(card.get("name", "")).to_lower().contains(needle):
			continue
		shown.append(card)
	if _sort_by_qty:
		shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("owned_quantity", 0)) > int(b.get("owned_quantity", 0)))
	for card in shown:
		_grid.add_child(_make_inv_card(card))


func _make_inv_card(card: Dictionary) -> Control:
	var cid := int(card.get("id", -1))
	# Botão-tile que segura o CardView passivo + badge de quantidade.
	var btn := Button.new()
	btn.custom_minimum_size = TILE
	btn.flat = true
	btn.clip_contents = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, empty)

	# CardView em tamanho natural, reduzido por `scale` (mantém proporções/legibilidade).
	var cv := CARD_VIEW.instantiate() as CardView
	btn.add_child(cv)
	cv.position = Vector2.ZERO
	ForgeTheme.bind_card_tile(cv, card, 1.2, TILE.x / CARD_NATURAL.x, bool(card.get("is_foil", false)))
	ForgeTheme.make_passive(cv)

	# Badge ×N (canto inferior direito), com contorno para ler sobre a arte.
	var badge := Label.new()
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -36.0
	badge.offset_top = -22.0
	badge.offset_right = -4.0
	badge.offset_bottom = -3.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	badge.add_theme_font_override("font", ForgeTheme.font_display())
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color("f0ece2"))
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	badge.add_theme_constant_override("outline_size", 4)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)

	# Esquerdo: manda direto pra forja. Direito: abre o menu de opções.
	btn.gui_input.connect(_on_tile_input.bind(card))

	_rows_by_id[cid] = { "card": card, "button": btn, "badge": badge }
	_update_row_state(cid)
	return btn


func _update_row_state(cid: int) -> void:
	if not _rows_by_id.has(cid):
		return
	var row: Dictionary = _rows_by_id[cid]
	var card: Dictionary = row.card
	var total := _avail_normal(cid) + _avail_foil(cid)
	(row.badge as Label).text = "×%d" % total
	# Raridade fora do alvo (ritual travado) → bem apagada; esgotada → meio apagada.
	var alpha := 1.0
	if _locked() and str(card.get("rarity", "COMMON")) != restrict_rarity:
		alpha = 0.25
	elif total <= 0:
		alpha = 0.4
	(row.button as Button).modulate = Color(1, 1, 1, alpha)


func _avail_normal(cid: int) -> int:
	var e: Dictionary = _available.get(cid, {})
	return int(e.get("normal", 0))


func _avail_foil(cid: int) -> int:
	var e: Dictionary = _available.get(cid, {})
	return int(e.get("foil", 0))


# ── Input do tile: esquerdo = adicionar direto; direito = menu ──────────────────
func _on_tile_input(event: InputEvent, card: Dictionary) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_direct_add(card)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		_open_card_menu(card)


# Adiciona uma cópia (normal de preferência; foil se só houver foil), respeitando a
# restrição de raridade do ritual. Sem cópia disponível/permitida → não faz nada.
func _direct_add(card: Dictionary) -> void:
	if restrict_rarity != "" and str(card.get("rarity", "COMMON")) != restrict_rarity:
		return
	var cid := int(card.get("id", -1))
	if _avail_normal(cid) > 0:
		_emit_add(card, false)
	elif _avail_foil(cid) > 0:
		_emit_add(card, true)


# ── Menu de opções da carta (Ver / Adicionar / Adicionar foil) ──────────────────
func _open_card_menu(card: Dictionary) -> void:
	_close_card_menu()
	var cid := int(card.get("id", -1))
	# Ritual dirigido: só a raridade do alvo pode ser oferecida.
	var blocked := restrict_rarity != "" and str(card.get("rarity", "COMMON")) != restrict_rarity
	var actions: Array = []
	actions.append({ "label": "Ver detalhes", "fn": func() -> void: _open_card_preview(card) })
	if not blocked and _avail_normal(cid) > 0:
		actions.append({ "label": "Adicionar à forja", "fn": func() -> void: _emit_add(card, false) })
	if not blocked and _avail_foil(cid) > 0:
		actions.append({ "label": "Adicionar foil", "fn": func() -> void: _emit_add(card, true) })

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close_card_menu())
	overlay.add_child(catcher)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ForgeTheme.panel_style(
		Color(ForgeTheme.BG_SURFACE.r, ForgeTheme.BG_SURFACE.g, ForgeTheme.BG_SURFACE.b, 0.98),
		ForgeTheme.GOLD, 1, 0))
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	for action in actions:
		var b := Button.new()
		b.text = str(action["label"])
		b.custom_minimum_size = Vector2(168, 34)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ForgeTheme.style_ghost_button(b, 13)
		var fn: Callable = action["fn"]
		b.pressed.connect(func() -> void:
			fn.call()
			_close_card_menu())
		vbox.add_child(b)

	# Dica quando a adição está bloqueada pela regra de raridade do ritual.
	if blocked and restrict_hint != "":
		var hint := Button.new()
		hint.text = restrict_hint
		hint.disabled = true
		hint.custom_minimum_size = Vector2(168, 30)
		hint.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ForgeTheme.style_ghost_button(hint, 11)
		hint.add_theme_color_override("font_disabled_color", ForgeTheme.PARCHMENT_D)
		vbox.add_child(hint)

	_overlay_root().add_child(overlay)
	_card_menu = overlay
	_place_menu(panel)


func _emit_add(card: Dictionary, foil: bool) -> void:
	var c := card.duplicate()
	c["is_foil"] = foil
	card_added.emit(c)


func _place_menu(panel: PanelContainer) -> void:
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	var mouse := get_viewport().get_mouse_position()
	var vp := get_viewport_rect().size
	var pos := mouse + Vector2(8, 8)
	pos.x = clampf(pos.x, 8.0, vp.x - panel.size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, vp.y - panel.size.y - 8.0)
	panel.position = pos


func _close_card_menu() -> void:
	if _card_menu != null and is_instance_valid(_card_menu):
		_card_menu.queue_free()
	_card_menu = null


# ── Preview da carta em tamanho grande ──────────────────────────────────────────
func _open_card_preview(card: Dictionary) -> void:
	_close_card_preview()
	var vp := get_viewport_rect().size
	var overlay := Control.new()
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var veil := ColorRect.new()
	veil.position = Vector2.ZERO
	veil.size = vp
	veil.color = Color(0, 0, 0, 0.78)
	veil.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close_card_preview())
	overlay.add_child(veil)

	var center := CenterContainer.new()
	center.position = Vector2.ZERO
	center.size = vp
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	_overlay_root().add_child(overlay)
	_card_preview = overlay

	var cv := CARD_VIEW.instantiate() as CardView
	center.add_child(cv)
	cv.set_preview_enabled(false)
	cv.custom_minimum_size = PREVIEW_SIZE
	cv.bind_dict(card)
	cv.set_foil(bool(card.get("is_foil", false)))
	cv.apply_scale(PREVIEW_SIZE.x / CARD_NATURAL.x)
	ForgeTheme.make_passive(cv)

	overlay.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.18)


func _close_card_preview() -> void:
	if _card_preview != null and is_instance_valid(_card_preview):
		_card_preview.queue_free()
	_card_preview = null


func _overlay_root() -> Node:
	if overlay_host != null and is_instance_valid(overlay_host):
		return overlay_host
	return get_tree().current_scene
