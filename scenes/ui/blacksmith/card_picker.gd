# Modal de seleção da carta-ALVO do ritual dirigido. Mostra TODAS as cartas do
# catálogo (independe de posse) com filtros de elemento, raridade e nome.
# Emite `picked(card)` e fecha.
class_name CardPicker
extends Control

signal picked(card: Dictionary)

const CARD_VIEW := preload("res://scenes/ui/card_view/card_view.tscn")
const CARD_SIZE := Vector2(160, 240)
const PICK_SCALE := 0.7

var _grid: HFlowContainer
var _filter: String = ""
var _rarity_filter: String = ""
var _name_filter: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	# Tamanho explícito do viewport — não confiar na propagação de âncora do pai (que
	# pode chegar 0 no frame de criação e jogar o modal pro canto superior esquerdo).
	var vp := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp

	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.7)
	veil.position = Vector2.ZERO
	veil.size = vp
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	# Clicar fora fecha.
	var close_hit := Button.new()
	close_hit.flat = true
	close_hit.position = Vector2.ZERO
	close_hit.size = vp
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		close_hit.add_theme_stylebox_override(st, empty)
	close_hit.pressed.connect(queue_free)
	add_child(close_hit)

	# CenterContainer com tamanho explícito → centraliza o painel de verdade.
	var center := CenterContainer.new()
	center.position = Vector2.ZERO
	center.size = vp
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ForgeTheme.panel_style(
		Color(ForgeTheme.BG_MID.r, ForgeTheme.BG_MID.g, ForgeTheme.BG_MID.b, 0.98),
		ForgeTheme.GOLD, 1, 0))
	panel.custom_minimum_size = Vector2(900, 600)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var header := HBoxContainer.new()
	vb.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(ForgeTheme.make_eyebrow("Alvo da Forja", ForgeTheme.GOLD_DIM, 10))
	titles.add_child(ForgeTheme.make_label("Escolha a carta almejada", ForgeTheme.font_display(), 20, ForgeTheme.GOLD_GLOW))

	# Campo de busca por nome.
	var search := LineEdit.new()
	search.placeholder_text = "Buscar por nome..."
	search.custom_minimum_size = Vector2(240, 34)
	search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	search.add_theme_font_override("font", ForgeTheme.font_body())
	search.add_theme_font_size_override("font_size", 13)
	search.text_changed.connect(func(t: String) -> void:
		_name_filter = t
		_rebuild_grid())
	header.add_child(search)

	var close := Button.new()
	close.text = "✕"
	ForgeTheme.style_ghost_button(close, 16)
	close.pressed.connect(queue_free)
	header.add_child(close)

	# Filtro por elemento.
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 4)
	vb.add_child(filters)
	for el in ForgeInvPanel.ELEMENTS:
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
	for rar in ForgeInvPanel.RARITIES:
		var rb := Button.new()
		rb.text = str(rar.name)
		rb.toggle_mode = true
		rb.button_pressed = rar.key == _rarity_filter
		rb.custom_minimum_size = Vector2(0, 30)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ForgeTheme.style_ghost_button(rb, 11)
		if str(rar.key) != "":
			rb.add_theme_color_override("font_color", ForgeTheme.rarity_color(str(rar.key)))
		rb.toggled.connect(_on_rarity_toggled.bind(rarity_filters, rb, str(rar.key)))
		rarity_filters.add_child(rb)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	_rebuild_grid()


func _on_rarity_toggled(on: bool, container: HBoxContainer, btn: Button, key: String) -> void:
	if not on:
		return
	_rarity_filter = key
	for other in container.get_children():
		if other != btn and other is Button:
			(other as Button).set_pressed_no_signal(false)
	_rebuild_grid()


func _rebuild_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var needle := _name_filter.strip_edges().to_lower()
	for card in Collection.all_card_dicts:
		if _filter != "" and not (_filter in card.get("symbols", [])):
			continue
		if _rarity_filter != "" and str(card.get("rarity", "COMMON")) != _rarity_filter:
			continue
		if needle != "" and not str(card.get("name", "")).to_lower().contains(needle):
			continue
		_grid.add_child(_make_pick_card(card))


func _make_pick_card(card: Dictionary) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE * PICK_SCALE
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, empty)

	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(holder)
	var cv := CARD_VIEW.instantiate() as CardView
	holder.add_child(cv)
	ForgeTheme.bind_card_tile(cv, card, PICK_SCALE, PICK_SCALE)
	ForgeTheme.make_passive(cv)

	btn.pressed.connect(func() -> void:
		picked.emit(card)
		queue_free())
	return btn
