# Modo "Sorte do Metal": encaixa cartas na pedra-runa, calcula chances/custo e dispara
# o cataclismo que revela uma carta sorteada. Sem regra de jogo crítica — só economia
# do Ferreiro (ouro de sessão + cache local), centralizada no host (blacksmith.gd).
class_name RandomForgeView
extends Control

signal back_requested

const CARD_VIEW := preload("res://scenes/ui/card_view/card_view.tscn")
const CARD_SIZE := Vector2(160, 240)
const SOCKET_SCALE := 0.4

@export var stone_slots: int = 20

var host: Control                     # blacksmith.gd (economia/ouro)
var _placed: Array = []               # tamanho stone_slots; null = vazio, senão dict
var _phase: String = "idle"

var _sockets: HFlowContainer
var _odds: ForgeOddsBar
var _cost_lbl: Label
var _forge_btn: Button
var _inv: ForgeInvPanel
var _caption_lbl: Label


func _ready() -> void:
	_placed.resize(stone_slots)
	_build()


# Chamado pelo host ao abrir esta view.
func enter() -> void:
	for i in _placed.size():
		_placed[i] = null
	_refresh_inventory()
	_rebuild_sockets()
	_recompute()


func on_gold_changed() -> void:
	_recompute()


# ── Construção ────────────────────────────────────────────────────────────────
func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	margin.add_child(split)

	# Palco da forja (esquerda, expande).
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 16)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(main)

	var stage_wrap := CenterContainer.new()
	stage_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(stage_wrap)
	stage_wrap.add_child(_build_runestone())

	# Caption + limpar.
	var caption_row := HBoxContainer.new()
	caption_row.add_theme_constant_override("separation", 10)
	caption_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_child(caption_row)
	_caption_lbl = ForgeTheme.make_label("", ForgeTheme.font_body(), 12, ForgeTheme.PARCHMENT_D)
	caption_row.add_child(_caption_lbl)
	var clear_link := Button.new()
	clear_link.text = "limpar"
	ForgeTheme.style_ghost_button(clear_link, 11)
	clear_link.pressed.connect(_on_clear)
	caption_row.add_child(clear_link)

	# Barra de chances.
	_odds = ForgeOddsBar.new()
	main.add_child(_odds)

	# Rodapé: custo + FORJAR.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	main.add_child(footer)
	footer.add_child(_build_cost_box())
	_forge_btn = _build_forge_button()
	footer.add_child(_forge_btn)

	# Inventário (direita, fixo).
	_inv = ForgeInvPanel.new()
	_inv.overlay_host = host
	_inv.card_added.connect(_on_inv_card_added)
	split.add_child(_inv)


func _build_runestone() -> Control:
	var stone := PanelContainer.new()
	stone.custom_minimum_size = Vector2(760, 360)
	var style := ForgeTheme.panel_style(Color(0.06, 0.06, 0.09, 0.95), ForgeTheme.GOLD_SOFT_A, 2, 8)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	stone.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	stone.add_child(vb)

	var rune_decor := ForgeTheme.make_label("◇  ⟡  ◈  ⟡  ◇", ForgeTheme.font_body(), 14,
		Color(ForgeTheme.GOLD.r, ForgeTheme.GOLD.g, ForgeTheme.GOLD.b, 0.35),
		HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(rune_decor)

	_sockets = HFlowContainer.new()
	_sockets.add_theme_constant_override("h_separation", 12)
	_sockets.add_theme_constant_override("v_separation", 12)
	_sockets.alignment = FlowContainer.ALIGNMENT_CENTER
	_sockets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_sockets)

	var base := ForgeTheme.make_label("⛓  PEDRA-RUNA  ⛓", ForgeTheme.font_body(), 10,
		Color(ForgeTheme.GOLD.r, ForgeTheme.GOLD.g, ForgeTheme.GOLD.b, 0.4),
		HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(base)
	return stone


func _build_cost_box() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ForgeTheme.panel_style(
		Color(ForgeTheme.BG_SURFACE.r, ForgeTheme.BG_SURFACE.g, ForgeTheme.BG_SURFACE.b, 0.9),
		ForgeTheme.GOLD_SOFT_A, 1, 0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)
	vb.add_child(ForgeTheme.make_eyebrow("Custo da Forja", ForgeTheme.GOLD_DIM, 9))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	row.add_child(ForgeTheme.make_label("◉", ForgeTheme.font_display(), 18, ForgeTheme.GOLD_GLOW))
	_cost_lbl = ForgeTheme.make_label("0", ForgeTheme.font_display(), 22, ForgeTheme.GOLD_GLOW)
	row.add_child(_cost_lbl)
	return panel


func _build_forge_button() -> Button:
	var btn := Button.new()
	btn.text = "FORJAR"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 64)
	btn.add_theme_font_override("font", ForgeTheme.font_heading())
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", ForgeTheme.PARCHMENT)
	btn.add_theme_color_override("font_disabled_color", ForgeTheme.PARCHMENT_D)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", ForgeTheme.crimson_button_style())
	btn.add_theme_stylebox_override("hover", ForgeTheme.crimson_button_style(true))
	btn.add_theme_stylebox_override("pressed", ForgeTheme.crimson_button_style(true))
	btn.add_theme_stylebox_override("focus", ForgeTheme.crimson_button_style())
	btn.add_theme_stylebox_override("disabled", ForgeTheme.disabled_button_style())
	btn.pressed.connect(_on_forge_pressed)
	return btn


# ── Sockets ───────────────────────────────────────────────────────────────────
func _rebuild_sockets() -> void:
	for c in _sockets.get_children():
		c.queue_free()
	for i in stone_slots:
		_sockets.add_child(_make_socket(i))


func _make_socket(i: int) -> Control:
	var tile := CARD_SIZE * SOCKET_SCALE
	var card: Variant = _placed[i]
	var wrap := Control.new()
	wrap.custom_minimum_size = tile
	wrap.clip_contents = true

	# Moldura (border) como irmão atrás — não corta a carta com content margins.
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := ForgeTheme.GOLD if card != null else Color(ForgeTheme.GOLD.r, ForgeTheme.GOLD.g, ForgeTheme.GOLD.b, 0.25)
	var fstyle := StyleBoxFlat.new()
	fstyle.bg_color = Color(0.04, 0.04, 0.07, 0.9)
	fstyle.set_border_width_all(1)
	fstyle.border_color = border
	fstyle.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", fstyle)
	wrap.add_child(frame)

	if card == null:
		var emblem := ForgeTheme.make_label("◆", ForgeTheme.font_display(), 28,
			Color(ForgeTheme.GOLD.r, ForgeTheme.GOLD.g, ForgeTheme.GOLD.b, 0.3),
			HORIZONTAL_ALIGNMENT_CENTER)
		emblem.set_anchors_preset(Control.PRESET_FULL_RECT)
		emblem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(emblem)
		var tw := create_tween().set_loops()
		tw.tween_property(emblem, "modulate:a", 0.4, 1.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(emblem, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
		return wrap

	# Encaixe cheio: CardView preenchendo o tile + botão remover.
	var cv := CARD_VIEW.instantiate() as CardView
	wrap.add_child(cv)
	ForgeTheme.bind_card_tile(cv, card, SOCKET_SCALE, SOCKET_SCALE, bool(card.get("is_foil", false)))
	ForgeTheme.make_passive(cv)

	var remove := Button.new()
	remove.text = "✕"
	remove.add_theme_font_size_override("font_size", 12)
	remove.add_theme_color_override("font_color", ForgeTheme.PARCHMENT)
	remove.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	remove.offset_left = -22.0
	remove.offset_top = 2.0
	remove.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rstyle := StyleBoxFlat.new()
	rstyle.bg_color = Color(0.5, 0.12, 0.1, 0.85)
	rstyle.set_corner_radius_all(3)
	remove.add_theme_stylebox_override("normal", rstyle)
	remove.add_theme_stylebox_override("hover", rstyle)
	remove.add_theme_stylebox_override("pressed", rstyle)
	remove.pressed.connect(_on_socket_removed.bind(i))
	wrap.add_child(remove)
	return wrap


# ── Lógica ────────────────────────────────────────────────────────────────────
func _refresh_inventory() -> void:
	var typed_syms: Array[String] = []
	var typed_deck: Array[String] = []
	var inv := Collection.query_cards("", typed_syms, "", typed_deck)
	_inv.set_inventory(inv)
	_update_available()


func _update_available() -> void:
	var placed_normal := {}
	var placed_foil := {}
	for c in _placed:
		if c != null:
			var cid := int(c.get("id", -1))
			if bool(c.get("is_foil", false)):
				placed_foil[cid] = int(placed_foil.get(cid, 0)) + 1
			else:
				placed_normal[cid] = int(placed_normal.get(cid, 0)) + 1
	var avail := {}
	for c in _inv.inventory:
		var cid := int(c.get("id", -1))
		var owned_foil := Collection.get_foil_quantity(cid)
		var owned_normal := Collection.get_owned_quantity(cid) - owned_foil
		avail[cid] = {
			"normal": owned_normal - int(placed_normal.get(cid, 0)),
			"foil": owned_foil - int(placed_foil.get(cid, 0)),
		}
	_inv.set_available_counts(avail)


func _on_inv_card_added(card: Dictionary) -> void:
	if _phase != "idle":
		return
	var slot := _placed.find(null)
	if slot == -1:
		return
	_placed[slot] = card
	_rebuild_sockets()
	_update_available()
	_recompute()


func _on_socket_removed(i: int) -> void:
	if _phase != "idle" or _placed[i] == null:
		return
	_placed[i] = null
	_rebuild_sockets()
	_update_available()
	_recompute()


func _on_clear() -> void:
	if _phase != "idle":
		return
	for i in _placed.size():
		_placed[i] = null
	_rebuild_sockets()
	_update_available()
	_recompute()


func _placed_cards() -> Array:
	return _placed.filter(func(c): return c != null)


func _recompute() -> void:
	var placed := _placed_cards()
	_odds.set_odds(ForgeService.compute_odds(placed, stone_slots))
	var cost := ForgeService.compute_cost(placed)
	_cost_lbl.text = ForgeTheme.fmt_gold(cost)
	var afford: bool = host == null or host.can_afford(cost)
	_cost_lbl.add_theme_color_override("font_color",
		ForgeTheme.GOLD_GLOW if afford else ForgeTheme.RED_INSUFF)

	var n := placed.size()
	_caption_lbl.text = ("Encaixe cartas da coleção nas runas da pedra" if n == 0
		else "%d / %d runas seladas · valor de forja %d" % [n, stone_slots, int(ForgeService.total_value(placed))])

	var can := n > 0 and afford and _phase == "idle"
	_forge_btn.disabled = not can
	if n == 0:
		_forge_btn.text = "Encaixe ao menos 1 carta"
	elif not afford:
		_forge_btn.text = "Ouro insuficiente"
	else:
		_forge_btn.text = "FORJAR"


func _on_forge_pressed() -> void:
	if _phase != "idle" or host == null:
		return
	var placed := _placed_cards()
	var cost := ForgeService.compute_cost(placed)
	if placed.is_empty() or not host.can_afford(cost):
		return
	_phase = "forging"
	_recompute()

	# Servidor é autoridade: monta as oferendas (UUID + foil), forja e devolve a carta.
	var res: Dictionary = await host.forge_random(_build_offerings(placed))
	if not res.ok:
		_phase = "idle"
		_recompute()
		return

	var stage := CataclysmStage.new()
	host.add_child(stage)
	stage.play(res.result, placed, true, "forte")
	await stage.kept

	# Inventário e ouro já foram aplicados por host.forge_random.
	for i in _placed.size():
		_placed[i] = null
	_phase = "idle"
	_refresh_inventory()
	_rebuild_sockets()
	_recompute()


# Agrupa as cartas encaixadas por UUID do backend (card_id), contando as foil.
func _build_offerings(placed: Array) -> Array:
	var by_uuid := {}
	for c in placed:
		var uuid := str(c.get("card_id", ""))
		if uuid == "":
			continue
		var e: Dictionary = by_uuid.get(uuid, { "cardId": uuid, "quantity": 0, "foilQuantity": 0 })
		e.quantity += 1
		if bool(c.get("is_foil", false)):
			e.foilQuantity += 1
		by_uuid[uuid] = e
	return by_uuid.values()
