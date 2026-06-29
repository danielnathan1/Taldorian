# scenes/world/ui/trade/trade_window.gd
# Janela modal de troca entre dois jogadores. Só EXIBE o estado vindo do WorldTrade
# e envia intenções (adicionar/remover carta, ouro, aceitar, cancelar). A autoridade
# da negociação é o servidor; a efetivação dos itens é responsabilidade do backend.
#
# Layout: [ Você (grade 4×4 fixa) | Oponente (grade 4×4) | Inventário (scroll) ].
# As cartas são CardViews REAIS, renderizados em tamanho natural e reduzidos via
# `scale` (preserva proporções — nada de texto cortado). O CardView é deixado 100%
# passivo (só visual); o clique é tratado aqui, apenas com o botão esquerdo, para a
# roda do mouse continuar rolando o inventário.
extends Control

signal closed

const CARD_VIEW_SCENE := preload("res://scenes/ui/card_view/card_view.tscn")

const MAX_SLOTS    := 16
const GRID_COLS    := 4
const INV_COLS     := 3
const CARD_NATURAL := Vector2(160, 240)
const SLOT_SIZE    := Vector2(92, 138)
const INV_TILE     := Vector2(92, 138)
const PREVIEW_SIZE := Vector2(360, 540)

const GOLD     := Color("c89d4a")
const GREEN    := Color("4ec877")
const GREY_MOD := Color(0.55, 0.55, 0.58, 1.0)

@onready var _close_btn : Button        = $Center/Window/Margin/VBox/TitleBar/CloseButton
@onready var _body      : HBoxContainer = $Center/Window/Margin/VBox/Body
@onready var _footer     : Label        = $Center/Window/Margin/VBox/Footer

var _local_peer : int = -1
var _other_peer : int = -1
var _other_name : String = "Oponente"
var _state      : Dictionary = {}
var _card_index : Dictionary = {}          # card_id (int) → dict da carta

var _local_ui : Dictionary = {}            # refs do lado local
var _other_ui : Dictionary = {}            # refs do lado oponente

var _inv_grid    : GridContainer
var _inv_search  : LineEdit
var _inv_rarity  : OptionButton
var _inv_element : OptionButton
var _inv_entries : Array = []              # [{ cid, name, rarity, symbols, wrap, view, badge }]

const RARITY_OPTIONS := [
	["Raridade: todas", ""],
	["Comum",     "COMMON"],
	["Rara",      "RARE"],
	["Lendária",  "LEGENDARY"],
	["Mística",   "MYSTIC"],
]

var _reset_banner : PanelContainer
var _reset_label  : Label
var _complete_overlay : Control
var _card_menu    : Control       # menuzinho de opções ao clicar numa carta
var _card_preview : Control       # overlay de detalhe (carta grande)

var _lock_remaining : float = 0.0          # contagem regressiva visual do reset

# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	visible = false
	_build_card_index()
	_close_btn.pressed.connect(_on_close_pressed)

	_local_ui = _build_side(true)
	_body.add_child(_local_ui["root"])
	_body.add_child(VSeparator.new())
	_other_ui = _build_side(false)
	_body.add_child(_other_ui["root"])
	_body.add_child(VSeparator.new())
	_body.add_child(_build_inventory())
	# Popula o inventário só depois que a grade está na árvore — senão os @onready
	# dos CardViews ainda são nulos e bind_dict() quebraria.
	_build_inventory_contents()

	_build_reset_banner()
	_build_complete_overlay()

	GameBus.trade_state_synced.connect(_on_state_synced)
	GameBus.trade_reset.connect(_on_reset)
	GameBus.trade_completed.connect(_on_completed)
	GameBus.trade_cancelled.connect(_on_cancelled)

func _process(p_delta: float) -> void:
	if _lock_remaining <= 0.0:
		return
	_lock_remaining = maxf(0.0, _lock_remaining - p_delta)
	_refresh_accept_buttons()
	if _lock_remaining <= 0.0:
		_reset_banner.visible = false

# ── API pública (chamada pelo world_root) ────────────────────────────────────────

func open(p_other_peer: int, p_other_name: String, p_state: Dictionary) -> void:
	_local_peer = multiplayer.get_unique_id()
	_other_peer = p_other_peer
	_other_name = p_other_name
	visible = true
	_complete_overlay.visible = false
	_reset_banner.visible = false
	_lock_remaining = 0.0
	_render(p_state)
	_animate_in()

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTRUÇÃO DOS LADOS
# ═══════════════════════════════════════════════════════════════════════════════

func _build_side(p_is_local: bool) -> Dictionary:
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(396, 0)
	root.add_theme_constant_override("separation", 12)

	var header := Label.new()
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", GOLD if p_is_local else Color("c8c4ba"))
	root.add_child(header)

	# Conteúdo (grade + ouro) — é o que fica "cinza" quando aquele lado aceita.
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	root.add_child(content)

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)

	var slots: Array = []
	for i in MAX_SLOTS:
		var slot := _build_slot(p_is_local, i)
		grid.add_child(slot["wrap"])
		slots.append(slot)

	# Linha de ouro
	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 8)
	var coin := Label.new()
	coin.text = "Ouro:"
	coin.add_theme_color_override("font_color", GOLD)
	coin.add_theme_font_size_override("font_size", 14)
	gold_row.add_child(coin)

	var gold_spin: SpinBox = null
	var gold_label: Label = null
	if p_is_local:
		gold_spin = SpinBox.new()
		gold_spin.min_value = 0
		gold_spin.max_value = 999999
		gold_spin.step = 1
		gold_spin.custom_minimum_size = Vector2(120, 0)
		gold_spin.value_changed.connect(_on_local_gold_changed)
		gold_row.add_child(gold_spin)
	else:
		gold_label = Label.new()
		gold_label.text = "0"
		gold_label.add_theme_font_size_override("font_size", 15)
		gold_label.add_theme_color_override("font_color", Color("e7e3da"))
		gold_row.add_child(gold_label)
	content.add_child(gold_row)

	# Empurra o botão/indicador para a base.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	# Botão aceitar (local) ou indicador de aceite (oponente)
	var accept_btn: Button = null
	var status_label: Label = null
	if p_is_local:
		accept_btn = Button.new()
		accept_btn.custom_minimum_size = Vector2(0, 42)
		accept_btn.add_theme_font_size_override("font_size", 16)
		accept_btn.pressed.connect(_on_local_accept_pressed)
		root.add_child(accept_btn)
	else:
		status_label = Label.new()
		status_label.custom_minimum_size = Vector2(0, 42)
		status_label.add_theme_font_size_override("font_size", 16)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		root.add_child(status_label)

	var stamp := Label.new()
	stamp.text = "ACEITO"
	stamp.add_theme_font_size_override("font_size", 18)
	stamp.add_theme_color_override("font_color", GREEN)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.rotation_degrees = -9.0
	stamp.visible = false
	root.add_child(stamp)

	return {
		"root":       root,
		"header":     header,
		"content":    content,
		"slots":      slots,
		"gold_spin":  gold_spin,
		"gold_label": gold_label,
		"accept":     accept_btn,
		"status":     status_label,
		"stamp":      stamp,
	}

# Slot fixo (vazio com moldura bonita; recebe um CardView quando preenchido).
func _build_slot(p_is_local: bool, p_index: int) -> Dictionary:
	var wrap := Control.new()
	wrap.custom_minimum_size = SLOT_SIZE
	wrap.clip_contents = true

	var placeholder := Panel.new()
	placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	placeholder.add_theme_stylebox_override("panel", _slot_empty_style())
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(placeholder)

	# Ambos os lados respondem ao clique (abre o menu da carta). O lado local pode
	# remover; o oponente só vê detalhes.
	wrap.gui_input.connect(_on_slot_input.bind(p_is_local, p_index))

	return { "wrap": wrap, "placeholder": placeholder, "card": null }

func _build_inventory() -> Control:
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(340, 0)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Seu Inventário"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", GOLD)
	root.add_child(title)

	_inv_search = LineEdit.new()
	_inv_search.placeholder_text = "Buscar carta…"
	_inv_search.clear_button_enabled = true
	_inv_search.text_changed.connect(func(_t: String) -> void: _apply_inv_filter())
	root.add_child(_inv_search)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	root.add_child(filters)

	_inv_rarity = OptionButton.new()
	_inv_rarity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for opt in RARITY_OPTIONS:
		_inv_rarity.add_item(str(opt[0]))
		_inv_rarity.set_item_metadata(_inv_rarity.item_count - 1, str(opt[1]))
	_inv_rarity.select(0)
	_inv_rarity.item_selected.connect(func(_i: int) -> void: _apply_inv_filter())
	filters.add_child(_inv_rarity)

	_inv_element = OptionButton.new()
	_inv_element.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_element.add_item("Elemento: todos")
	_inv_element.set_item_metadata(0, "")
	for sym in GameSymbols.ALL:
		_inv_element.add_item(str(GameSymbols.DISPLAY.get(sym, sym)))
		_inv_element.set_item_metadata(_inv_element.item_count - 1, str(sym))
	_inv_element.select(0)
	_inv_element.item_selected.connect(func(_i: int) -> void: _apply_inv_filter())
	filters.add_child(_inv_element)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("0c0d14"), Color("2c3140")))
	root.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = INV_COLS
	_inv_grid.add_theme_constant_override("h_separation", 8)
	_inv_grid.add_theme_constant_override("v_separation", 8)
	_inv_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# PASS para a roda do mouse subir até o ScrollContainer (clique é tratado nos tiles).
	_inv_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_inv_grid)
	return root

func _build_inventory_contents() -> void:
	var no_syms: Array[String] = []
	var no_deck: Array[String] = []
	var owned: Array = Collection.query_cards("", no_syms, "", no_deck, "")
	for d in owned:
		var cid := int(d.get("id", -1))
		if cid < 0:
			continue
		# Normal e foil viram tiles separados (foil acende o holo e oferta a cópia foil).
		var foilq := Collection.get_foil_quantity(cid)
		var normalq := Collection.get_owned_quantity(cid) - foilq
		if normalq > 0:
			_add_inv_tile(d, cid, false)
		if foilq > 0:
			_add_inv_tile(d, cid, true)

func _add_inv_tile(p_dict: Dictionary, p_card_id: int, p_foil: bool) -> void:
	var wrap := Control.new()
	wrap.custom_minimum_size = INV_TILE
	wrap.clip_contents = true
	# PASS: trata clique esquerdo aqui, mas deixa a roda do mouse rolar o scroll.
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	_inv_grid.add_child(wrap)

	var cv := _make_card(p_dict, INV_TILE, wrap, 1.2, p_foil)
	var badge := _make_badge()
	wrap.add_child(badge)
	wrap.gui_input.connect(_on_inv_input.bind(p_card_id, p_foil))

	_inv_entries.append({
		"cid":     p_card_id,
		"foil":    p_foil,
		"name":    str(p_dict.get("name", "")),
		"rarity":  str(p_dict.get("rarity", "COMMON")),
		"symbols": (p_dict.get("symbols", []) as Array).duplicate(),
		"wrap":    wrap,
		"view":    cv,
		"badge":   badge,
	})

# Cria um CardView em tamanho natural e reduz por `scale` (mantém proporções).
# `p_parent` precisa já estar na árvore (os @onready do CardView rodam no add_child).
# `p_font_scale`: os labels do CardView vêm com font_size=1 no .tscn e SÓ ganham
# tamanho real via apply_scale() — sem isso o texto some. O tamanho visual final é
# (apply_scale) × (scale do nó), então preview usa um fator maior.
func _make_card(p_dict: Dictionary, p_tile: Vector2, p_parent: Control, p_font_scale: float = 1.2, p_foil: bool = false) -> CardView:
	var cv := CARD_VIEW_SCENE.instantiate() as CardView
	p_parent.add_child(cv)
	cv.set_preview_enabled(false)
	cv.bind_dict(p_dict)
	cv.set_foil(p_foil)
	cv.apply_scale(p_font_scale)
	cv.position = Vector2.ZERO
	cv.size = CARD_NATURAL
	cv.pivot_offset = Vector2.ZERO
	cv.scale = p_tile / CARD_NATURAL
	_make_passive(cv)
	return cv

# Torna o CardView 100% passivo (só visual) para não roubar cliques/roda do mouse.
func _make_passive(p_node: Node) -> void:
	if p_node is Control:
		(p_node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in p_node.get_children():
		_make_passive(c)

func _make_badge() -> Label:
	var badge := Label.new()
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -34.0
	badge.offset_top = -22.0
	badge.offset_right = -3.0
	badge.offset_bottom = -3.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color("f0ece2"))
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	badge.add_theme_constant_override("outline_size", 4)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return badge

func _slot_empty_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("12131c")
	s.set_border_width_all(1)
	s.border_color = Color("2c3140")
	s.set_corner_radius_all(4)
	return s

func _panel_style(p_bg: Color, p_border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = p_bg
	s.set_border_width_all(2)
	s.border_color = p_border
	s.set_corner_radius_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

# ═══════════════════════════════════════════════════════════════════════════════
# RENDERIZAÇÃO
# ═══════════════════════════════════════════════════════════════════════════════

func _render(p_state: Dictionary) -> void:
	_state = p_state
	if not p_state.has("sides"):
		return
	var sides: Dictionary = p_state["sides"]
	var local_side: Dictionary = sides.get(_local_peer, {"items": [], "gold": 0, "accepted": false})
	var other_side: Dictionary = sides.get(_other_peer, {"items": [], "gold": 0, "accepted": false})

	_local_ui["header"].text = "Você"
	_other_ui["header"].text = _other_name

	_render_slots(_local_ui, local_side.get("items", []), true)
	_render_slots(_other_ui, other_side.get("items", []), false)

	# Ouro
	var local_spin: SpinBox = _local_ui["gold_spin"]
	if local_spin != null:
		local_spin.set_block_signals(true)
		local_spin.value = float(local_side.get("gold", 0))
		local_spin.set_block_signals(false)
	_other_ui["gold_label"].text = str(other_side.get("gold", 0))

	# Cinza nos lados aceitos
	_local_ui["content"].modulate = GREY_MOD if bool(local_side.get("accepted", false)) else Color.WHITE
	_other_ui["content"].modulate = GREY_MOD if bool(other_side.get("accepted", false)) else Color.WHITE
	_local_ui["stamp"].visible = bool(local_side.get("accepted", false))
	_other_ui["stamp"].visible = bool(other_side.get("accepted", false))

	# Indicador do oponente
	var other_accepted := bool(other_side.get("accepted", false))
	_other_ui["status"].text = "✓ Aceito" if other_accepted else "Negociando…"
	_other_ui["status"].add_theme_color_override("font_color", GREEN if other_accepted else Color("8a8f99"))

	_update_inventory_availability()
	_refresh_accept_buttons()
	_update_footer(local_side, other_side)

func _render_slots(p_ui: Dictionary, p_items: Array, _p_is_local: bool) -> void:
	var slots: Array = p_ui["slots"]
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if slot["card"] != null and is_instance_valid(slot["card"]):
			slot["card"].queue_free()
		slot["card"] = null
		var filled := i < p_items.size()
		(slot["placeholder"] as Panel).visible = not filled
		if not filled:
			continue
		# Item agora é { card_id, foil } — o foil vem da própria oferta (vale p/ os 2 lados).
		var item: Dictionary = p_items[i]
		var cid := int(item["card_id"])
		var d: Dictionary = _card_index.get(cid, {})
		if d.is_empty():
			continue
		slot["card"] = _make_card(d, SLOT_SIZE, slot["wrap"], 1.2, bool(item.get("foil", false)))

func _update_inventory_availability() -> void:
	for e in _inv_entries:
		var cid: int = e["cid"]
		var is_foil: bool = e["foil"]
		var avail := _inv_available(cid, is_foil)
		var txt := "x%d" % maxi(0, avail)
		if is_foil:
			txt = "✦ " + txt
		(e["badge"] as Label).text = txt
		(e["view"] as CardView).modulate.a = 1.0 if avail > 0 else 0.4

# Disponível para ofertar dessa variante (normal ou foil), descontando o já ofertado.
func _inv_available(p_card_id: int, p_foil: bool) -> int:
	if p_foil:
		return Collection.get_foil_quantity(p_card_id) - _offered_count(p_card_id, true)
	var normal := Collection.get_owned_quantity(p_card_id) - Collection.get_foil_quantity(p_card_id)
	return normal - _offered_count(p_card_id, false)

# Quantas cópias dessa carta/variante já estão na MINHA oferta.
func _offered_count(p_card_id: int, p_foil: bool) -> int:
	var n := 0
	for it in _local_items():
		if int((it as Dictionary)["card_id"]) == p_card_id and bool((it as Dictionary).get("foil", false)) == p_foil:
			n += 1
	return n

# Filtro do inventário (nome + raridade + elemento). Esconde os tiles que não batem;
# o GridContainer reflui sozinho ao ignorar filhos invisíveis.
func _apply_inv_filter() -> void:
	var q := _inv_search.text.strip_edges().to_lower()
	var rarity := str(_inv_rarity.get_selected_metadata()) if _inv_rarity != null else ""
	var element := str(_inv_element.get_selected_metadata()) if _inv_element != null else ""
	for e in _inv_entries:
		var ok := q == "" or str(e["name"]).to_lower().contains(q)
		if ok and rarity != "":
			ok = str(e["rarity"]) == rarity
		if ok and element != "":
			ok = element in (e["symbols"] as Array)
		(e["wrap"] as Control).visible = ok

func _refresh_accept_buttons() -> void:
	var btn: Button = _local_ui["accept"]
	if btn == null:
		return
	var locked := _lock_remaining > 0.0
	var local_accepted := _local_accepted()
	if locked:
		btn.disabled = true
		btn.text = "Reconfira  %d" % int(ceil(_lock_remaining))
		btn.add_theme_color_override("font_color", Color("8a8f99"))
	elif local_accepted:
		btn.disabled = false
		btn.text = "✓ Aceito — Cancelar"
		btn.add_theme_color_override("font_color", GREEN)
	else:
		btn.disabled = false
		btn.text = "Aceitar Troca"
		btn.add_theme_color_override("font_color", GOLD)

func _update_footer(p_local: Dictionary, p_other: Dictionary) -> void:
	var local_acc := bool(p_local.get("accepted", false))
	var other_acc := bool(p_other.get("accepted", false))
	if _lock_remaining > 0.0:
		_footer.text = "Confirmação reiniciada — aguarde %ds" % int(ceil(_lock_remaining))
	elif local_acc and not other_acc:
		_footer.text = "Você aceitou — aguardando %s" % _other_name
	elif other_acc and not local_acc:
		_footer.text = "%s aceitou — aguardando você" % _other_name
	else:
		_footer.text = "Negociação em andamento"

# ═══════════════════════════════════════════════════════════════════════════════
# INTERAÇÕES LOCAIS → WorldTrade (apenas botão esquerdo)
# ═══════════════════════════════════════════════════════════════════════════════

func _on_inv_input(p_event: InputEvent, p_card_id: int, p_is_foil: bool) -> void:
	if not _is_left_click(p_event):
		return
	get_viewport().set_input_as_handled()
	var d: Dictionary = _card_index.get(p_card_id, {})
	if d.is_empty():
		return
	var actions: Array = []
	if _inv_available(p_card_id, p_is_foil) > 0:
		var label := "Ofertar foil" if p_is_foil else "Ofertar carta"
		actions.append({ "label": label, "fn": func() -> void: WorldTrade.add_item(p_card_id, p_is_foil) })
	actions.append({ "label": "Ver detalhes", "fn": func() -> void: _open_card_preview(d, p_is_foil) })
	_open_card_menu(actions)

func _on_slot_input(p_event: InputEvent, p_is_local: bool, p_slot: int) -> void:
	if not _is_left_click(p_event):
		return
	var items := _local_items() if p_is_local else _other_items()
	if p_slot >= items.size():
		return   # slot vazio — nada a fazer
	get_viewport().set_input_as_handled()
	var item: Dictionary = items[p_slot]
	var cid := int(item["card_id"])
	var foil := bool(item.get("foil", false))
	var d: Dictionary = _card_index.get(cid, {})
	if d.is_empty():
		return
	var actions: Array = []
	if p_is_local:
		actions.append({ "label": "Remover carta", "fn": func() -> void: WorldTrade.remove_item(p_slot) })
	actions.append({ "label": "Ver detalhes", "fn": func() -> void: _open_card_preview(d, foil) })
	_open_card_menu(actions)

func _is_left_click(p_event: InputEvent) -> bool:
	return p_event is InputEventMouseButton \
		and (p_event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
		and (p_event as InputEventMouseButton).pressed

# ── Menu de opções da carta (Ofertar/Remover + Ver detalhes) ────────────────────

func _open_card_menu(p_actions: Array) -> void:
	_close_card_menu()
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fundo invisível que fecha o menu ao clicar fora.
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_card_menu()
	)
	overlay.add_child(catcher)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("12131c"), GOLD))
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	for action in p_actions:
		var btn := Button.new()
		btn.text = str(action["label"])
		btn.custom_minimum_size = Vector2(150, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 14)
		var fn: Callable = action["fn"]
		btn.pressed.connect(func() -> void:
			fn.call()
			_close_card_menu()
		)
		vbox.add_child(btn)

	add_child(overlay)
	_card_menu = overlay
	_place_menu(panel)

func _place_menu(p_panel: PanelContainer) -> void:
	await get_tree().process_frame
	if not is_instance_valid(p_panel):
		return
	var mouse := get_viewport().get_mouse_position()
	var vp := get_viewport_rect().size
	var pos := mouse + Vector2(8, 8)
	pos.x = clampf(pos.x, 8.0, vp.x - p_panel.size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, vp.y - p_panel.size.y - 8.0)
	p_panel.position = pos

func _close_card_menu() -> void:
	if _card_menu != null and is_instance_valid(_card_menu):
		_card_menu.queue_free()
	_card_menu = null

# ── Preview da carta em tamanho grande ──────────────────────────────────────────

func _open_card_preview(p_dict: Dictionary, p_foil: bool = false) -> void:
	_close_card_preview()
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0, 0, 0, 0.75)
	veil.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_card_preview()
	)
	overlay.add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	add_child(overlay)
	_card_preview = overlay

	# Renderiza em TAMANHO REAL (sem scale de nó) para o texto sair nítido. As fontes
	# vêm em font_size=1 no .tscn, então apply_scale define o tamanho proporcional ao
	# card grande (PREVIEW_SIZE.x / largura natural 160).
	var cv := CARD_VIEW_SCENE.instantiate() as CardView
	center.add_child(cv)
	cv.set_preview_enabled(false)
	cv.custom_minimum_size = PREVIEW_SIZE
	cv.bind_dict(p_dict)
	cv.set_foil(p_foil)
	cv.apply_scale(PREVIEW_SIZE.x / CARD_NATURAL.x)
	_make_passive(cv)

	# Fade-in (sem escalar — evita borrar o texto).
	overlay.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.18)

func _close_card_preview() -> void:
	if _card_preview != null and is_instance_valid(_card_preview):
		_card_preview.queue_free()
	_card_preview = null

func _on_local_gold_changed(p_value: float) -> void:
	WorldTrade.set_gold(int(p_value))

func _on_local_accept_pressed() -> void:
	WorldTrade.accept()

func _on_close_pressed() -> void:
	WorldTrade.cancel()
	_close()

# ═══════════════════════════════════════════════════════════════════════════════
# SINAIS DO WorldTrade (via GameBus)
# ═══════════════════════════════════════════════════════════════════════════════

func _on_state_synced(p_state: Dictionary) -> void:
	if not _is_my_session(p_state):
		return
	_render(p_state)

func _on_reset(p_seconds: float) -> void:
	_lock_remaining = p_seconds
	_reset_banner.visible = true
	_reset_label.text = "A oferta mudou — reconfirmem a troca"
	_refresh_accept_buttons()

func _on_completed(p_state: Dictionary) -> void:
	if not _is_my_session(p_state):
		return
	_render(p_state)
	_show_complete_overlay()
	_reload_inventory()

func _on_cancelled(_p_by_peer: int) -> void:
	_close()

# ═══════════════════════════════════════════════════════════════════════════════
# OVERLAYS (reset + conclusão)
# ═══════════════════════════════════════════════════════════════════════════════

func _build_reset_banner() -> void:
	_reset_banner = PanelContainer.new()
	_reset_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_reset_banner.position = Vector2(0, 12)
	_reset_banner.add_theme_stylebox_override("panel", _panel_style(Color("2a1810"), Color("e0853a")))
	_reset_banner.visible = false
	var m := MarginContainer.new()
	for k in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(k, 16)
	for k in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(k, 8)
	_reset_banner.add_child(m)
	_reset_label = Label.new()
	_reset_label.add_theme_color_override("font_color", Color("e0853a"))
	_reset_label.add_theme_font_size_override("font_size", 14)
	m.add_child(_reset_label)
	add_child(_reset_banner)

func _build_complete_overlay() -> void:
	_complete_overlay = Control.new()
	_complete_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_complete_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_complete_overlay.visible = false

	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0, 0, 0, 0.65)
	_complete_overlay.add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_complete_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("0c1410"), GREEN))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for k in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(k, 40)
	for k in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(k, 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var t := Label.new()
	t.text = "Troca Concluída"
	t.add_theme_color_override("font_color", GREEN)
	t.add_theme_font_size_override("font_size", 24)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(t)

	var sub := Label.new()
	sub.text = "Os itens foram transferidos"
	sub.add_theme_color_override("font_color", Color("c8c4ba"))
	sub.add_theme_font_size_override("font_size", 14)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var btn := Button.new()
	btn.text = "Fechar"
	btn.custom_minimum_size = Vector2(160, 40)
	btn.pressed.connect(_close)
	vbox.add_child(btn)

	add_child(_complete_overlay)

func _show_complete_overlay() -> void:
	_complete_overlay.visible = true
	_complete_overlay.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_complete_overlay, "modulate:a", 1.0, 0.3)

# ═══════════════════════════════════════════════════════════════════════════════
# EFETIVAÇÃO NO BACKEND (ponto de integração)
# ═══════════════════════════════════════════════════════════════════════════════

# A efetivação (transferência) é feita pelo SERVIDOR de mundo via POST /trades.
# Aqui, no cliente, só recarregamos o inventário do próprio jogador após a conclusão.
func _reload_inventory() -> void:
	if not ApiClient.is_authenticated():
		return
	var inv: Dictionary = await ApiClient.get_inventory()
	if inv.get("ok", false):
		Collection.load_inventory(inv.get("data", {}))

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITÁRIOS
# ═══════════════════════════════════════════════════════════════════════════════

func _build_card_index() -> void:
	for d in Collection.all_card_dicts:
		_card_index[int(d.get("id", -1))] = d

func _local_items() -> Array:
	if not _state.has("sides"):
		return []
	var sides: Dictionary = _state["sides"]
	return (sides.get(_local_peer, {}) as Dictionary).get("items", [])

func _other_items() -> Array:
	if not _state.has("sides"):
		return []
	var sides: Dictionary = _state["sides"]
	return (sides.get(_other_peer, {}) as Dictionary).get("items", [])

func _local_accepted() -> bool:
	if not _state.has("sides"):
		return false
	var sides: Dictionary = _state["sides"]
	return bool((sides.get(_local_peer, {}) as Dictionary).get("accepted", false))

func _is_my_session(p_state: Dictionary) -> bool:
	var peers: Array = p_state.get("peers", [])
	return _local_peer in peers and _other_peer in peers

func _animate_in() -> void:
	var win := $Center/Window
	win.scale = Vector2(0.92, 0.92)
	win.modulate = Color(1, 1, 1, 0)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(win, "scale", Vector2.ONE, 0.35)
	tw.parallel().tween_property(win, "modulate:a", 1.0, 0.3)

func _close() -> void:
	closed.emit()
	queue_free()
