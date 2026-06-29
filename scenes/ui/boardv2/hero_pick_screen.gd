# scenes/ui/boardv2/hero_pick_screen.gd
extends Control

# Emitido ao alternar "espiar tabuleiro" — o board usa para esconder o DimOverlay.
signal peek_changed(peeking: bool)

const HeroSlotScene  := preload("res://scenes/ui/hero_slot/hero_slot.tscn")
const CardViewScene  := preload("res://scenes/ui/card_view/card_view.tscn")

const C_GOLD        := Color(0.902, 0.722, 0.392)
const C_GOLD_DIM    := Color(0.627, 0.490, 0.227)
const C_GOLD_GLOW   := Color(1.000, 0.839, 0.463)
const C_CRIMSON_BR  := Color(0.827, 0.353, 0.247)
const C_PARCHMENT   := Color(0.941, 0.918, 0.839)
const C_PARCHMENT_D := Color(0.710, 0.663, 0.541)
const C_INK         := Color(0.165, 0.122, 0.082)
const C_LINE_SOFT   := Color(0.902, 0.722, 0.392, 0.10)
const C_PANEL_BG    := Color(0.07, 0.05, 0.03, 0.82)

const _FONT_DECO := preload("res://assets/fonts/CinzelDecorative-Bold.ttf")
const _FONT_BOLD := preload("res://assets/fonts/palatino/fonnts.com-Palatino-LT-Bold.ttf")
const _FONT_REG  := preload("res://assets/fonts/palatino/palr45w.ttf")

var _selected_hero: Hero  = null
var _confirmed            := false
var _time_left            := 75
var _heroes: Array        = []
var _slots: Array         = []        # HeroSlot instances
var _card_views: Array    = []        # CardView instances (hand)

var _main:        VBoxContainer    # conteúdo do overlay (escondido ao "espiar" o tabuleiro)
var _peek_btn:    Button           # alterna entre ver o tabuleiro e voltar à seleção
var _collapsed             := false
var _heroes_row:  HBoxContainer
var _status_lbl:  RichTextLabel
var _timer_lbl:   Label
var _confirm_btn: Button
var _waiting_lbl: Label
var _hand_row:    HBoxContainer
var _hand_count_lbl: Label  # instanciado mas não adicionado à árvore

var _dot_tween:  Tween
var _tick_timer: Timer

var sleeve: Texture2D = null

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	for child in get_children():
		child.visible = false
	_build_ui()
	GameBus.state_synced.connect(_on_state_synced)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and is_node_ready():
		_collapsed = false   # sempre reabre expandido ao entrar na seleção
		_refresh_screen()

# ── UI Construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-rect VBox — background is transparent so the board shows through
	_main = VBoxContainer.new()
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.add_theme_constant_override("separation", 0)
	add_child(_main)

	_main.add_child(_build_header())

	# Heroes area — takes all remaining space
	var heroes_area := CenterContainer.new()
	heroes_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main.add_child(heroes_area)

	_heroes_row = HBoxContainer.new()
	_heroes_row.add_theme_constant_override("separation", 32)
	_heroes_row.alignment = BoxContainer.ALIGNMENT_CENTER
	heroes_area.add_child(_heroes_row)

	_main.add_child(_build_hand_section())
	_main.add_child(_build_footer())

	# Botão flutuante para espiar o tabuleiro (fica fora de _main para sobreviver ao
	# colapso). Ancorado no canto superior direito; mantém-se ao esconder _main.
	_build_peek_button()


func _build_peek_button() -> void:
	_peek_btn = Button.new()
	_peek_btn.text = "👁  Ver tabuleiro"
	_peek_btn.add_theme_font_override("font", _FONT_BOLD)
	_peek_btn.add_theme_font_size_override("font_size", 13)
	_peek_btn.add_theme_color_override("font_color", Color(0.941, 0.910, 0.784))
	_peek_btn.anchor_left   = 1.0
	_peek_btn.anchor_right  = 1.0
	_peek_btn.anchor_top    = 0.0
	_peek_btn.anchor_bottom = 0.0
	_peek_btn.offset_left   = -200
	_peek_btn.offset_right  = -20
	_peek_btn.offset_top    = 16
	_peek_btn.offset_bottom = 48
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.09, 0.07, 0.92)
	s.border_color = Color(C_GOLD_DIM, 0.7)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 14; s.content_margin_right  = 14
	s.content_margin_top  = 6;  s.content_margin_bottom = 6
	_peek_btn.add_theme_stylebox_override("normal",  s)
	_peek_btn.add_theme_stylebox_override("hover",   s)
	_peek_btn.add_theme_stylebox_override("pressed", s)
	_peek_btn.pressed.connect(_toggle_peek)
	add_child(_peek_btn)


# Alterna entre esconder o overlay (para ver o tabuleiro) e reabri-lo.
func _toggle_peek() -> void:
	_collapsed = not _collapsed
	_apply_peek_state()
	peek_changed.emit(_collapsed)


func is_peeking() -> bool:
	return _collapsed


func _apply_peek_state() -> void:
	if _main == null or _peek_btn == null:
		return
	_main.visible = not _collapsed
	# Colapsado: deixa o clique/hover passar para o tabuleiro (o botão flutuante,
	# como filho com filtro próprio, continua clicável).
	mouse_filter = Control.MOUSE_FILTER_IGNORE if _collapsed else Control.MOUSE_FILTER_STOP
	_peek_btn.text = "↩  Voltar à seleção" if _collapsed else "👁  Ver tabuleiro"


func _build_header() -> Control:
	var panel := _panel(C_PANEL_BG, C_LINE_SOFT, 0, 0, 0, 1)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top",    22)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.add_theme_constant_override("margin_left",   40)
	margin.add_theme_constant_override("margin_right",  40)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var eyebrow := Label.new()
	eyebrow.text = "— FASE DE PREPARAÇÃO —"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", _FONT_BOLD)
	eyebrow.add_theme_font_size_override("font_size", 9)
	eyebrow.add_theme_color_override("font_color", Color(C_GOLD_DIM, 0.75))
	vbox.add_child(eyebrow)

	var title := Label.new()
	title.text = "Seleção de Herói"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _FONT_DECO)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", C_GOLD)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Escolha um herói para ser o herói ativo nesta partida."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", _FONT_REG)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(C_PARCHMENT_D, 0.75))
	vbox.add_child(sub)

	return panel


func _build_hand_section() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   40)
	margin.add_theme_constant_override("margin_right",  40)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 6)

	_hand_count_lbl = Label.new()   # kept for data binding; not added to tree

	_hand_row = HBoxContainer.new()
	_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_row.add_theme_constant_override("separation", 8)
	margin.add_child(_hand_row)

	return margin


func _build_footer() -> Control:
	var panel := _panel(C_PANEL_BG, C_LINE_SOFT, 1, 0, 0, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   40)
	margin.add_theme_constant_override("margin_right",  40)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	# Status label (left, expands)
	_status_lbl = RichTextLabel.new()
	_status_lbl.bbcode_enabled = true
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_lbl.fit_content   = true
	_status_lbl.scroll_active = false
	_status_lbl.add_theme_font_override("normal_font", _FONT_REG)
	_status_lbl.add_theme_font_size_override("normal_font_size", 15)
	_status_lbl.add_theme_color_override("default_color", Color(C_PARCHMENT_D, 0.55))
	hbox.add_child(_status_lbl)

	# Timer (center)
	_timer_lbl = Label.new()
	_timer_lbl.add_theme_font_override("font", _FONT_BOLD)
	_timer_lbl.add_theme_font_size_override("font_size", 13)
	_timer_lbl.add_theme_color_override("font_color", C_CRIMSON_BR)
	_timer_lbl.text = "●  Tempo  01:15"
	hbox.add_child(_timer_lbl)

	# Waiting label (replaces timer area after confirm)
	_waiting_lbl = Label.new()
	_waiting_lbl.text = "Aguardando oponente…"
	_waiting_lbl.visible = false
	_waiting_lbl.add_theme_font_override("font", _FONT_BOLD)
	_waiting_lbl.add_theme_font_size_override("font_size", 13)
	_waiting_lbl.add_theme_color_override("font_color", Color(C_GOLD_DIM, 0.8))
	hbox.add_child(_waiting_lbl)

	# Confirm button (right)
	_confirm_btn = Button.new()
	_confirm_btn.text     = "Confirmar Herói"
	_confirm_btn.disabled = true
	_confirm_btn.add_theme_font_override("font", _FONT_BOLD)
	_confirm_btn.add_theme_font_size_override("font_size", 14)
	_confirm_btn.add_theme_color_override("font_color",          Color(0.941, 0.910, 0.784))
	_confirm_btn.add_theme_color_override("font_disabled_color", C_PARCHMENT_D)
	_confirm_btn.custom_minimum_size = Vector2(200, 0)
	_apply_confirm_style(false)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	hbox.add_child(_confirm_btn)

	return panel

# ── Style helper ──────────────────────────────────────────────────────────────

func _panel(bg: Color, border: Color, top: int, right: int, bottom: int, bot_override: int = -1) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_top    = top
	style.border_width_right  = right
	style.border_width_bottom = bot_override if bot_override >= 0 else bottom
	style.border_width_left   = 0
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style)
	return p


func _apply_confirm_style(enabled: bool) -> void:
	if enabled:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.35, 0.12, 0.08)
		s.border_color = Color(C_CRIMSON_BR, 0.7)
		s.set_border_width_all(1)
		s.content_margin_left = 28; s.content_margin_right  = 28
		s.content_margin_top  = 12; s.content_margin_bottom = 12
		_confirm_btn.add_theme_stylebox_override("normal",   s)
		_confirm_btn.add_theme_stylebox_override("hover",    s)
		_confirm_btn.add_theme_stylebox_override("pressed",  s)
		_confirm_btn.add_theme_stylebox_override("disabled", _disabled_style())
	else:
		var s := _disabled_style()
		_confirm_btn.add_theme_stylebox_override("normal",   s)
		_confirm_btn.add_theme_stylebox_override("hover",    s)
		_confirm_btn.add_theme_stylebox_override("pressed",  s)
		_confirm_btn.add_theme_stylebox_override("disabled", s)


func _disabled_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.09, 0.07, 0.8)
	s.border_color = C_LINE_SOFT
	s.set_border_width_all(1)
	s.content_margin_left = 28; s.content_margin_right  = 28
	s.content_margin_top  = 12; s.content_margin_bottom = 12
	return s

# ── Game data ─────────────────────────────────────────────────────────────────

func _refresh_screen() -> void:
	if GameState.players.is_empty():
		return
	var local_idx := NetworkState.local_player_index
	if GameState.has_submitted_hero_pick(local_idx):
		_show_waiting()
		return
	_rebuild_heroes(local_idx)
	_rebuild_hand(local_idx)
	_restart_timer()
	_apply_peek_state()   # preserva o estado "espiando" caso um sync rebuilde a tela


func _rebuild_heroes(local_idx: int) -> void:
	_slots.clear()
	for child in _heroes_row.get_children():
		child.queue_free()

	_selected_hero = null
	_confirmed     = false
	_confirm_btn.disabled = true
	_confirm_btn.text     = "Confirmar Herói"
	_apply_confirm_style(false)
	_waiting_lbl.visible = false
	_timer_lbl.visible   = true

	_heroes = GameState.players[local_idx].heroes

	for i in _heroes.size():
		var hero: Hero = _heroes[i]

		var slot: HeroSlot = HeroSlotScene.instantiate()
		# Fixed 240×360 so CenterContainer has a concrete size to center
		slot.custom_minimum_size   = Vector2(288, 432)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
		_heroes_row.add_child(slot)
		slot.bind(hero)
		slot.set_hp_visible(true)
		if sleeve != null:
			slot.set_sleeve_texture(sleeve)
		slot.slot_clicked.connect(_on_slot_clicked)
		_slots.append(slot)

	_schedule_scale()
	_update_status()


func _rebuild_hand(local_idx: int) -> void:
	_card_views.clear()
	for child in _hand_row.get_children():
		child.queue_free()

	var hand: Array = GameState.players[local_idx].hand

	# 95×143 ≈ 2:3 ratio, visível sem roubar espaço dos heróis
	const HAND_W := 95
	const HAND_H := 143

	for card in hand:
		var view: CardView = CardViewScene.instantiate()
		# Override tscn minimum (160×240) so the card stays compact
		view.custom_minimum_size   = Vector2(HAND_W, HAND_H)
		view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		view.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
		_hand_row.add_child(view)
		view.bind(card)
		# Non-interactable (no click) but hover fires card_preview
		view.set_interactable(false, false)
		if sleeve != null:
			view.set_sleeve(sleeve)
		_card_views.append(view)


func _schedule_scale() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for slot in _slots:
		if is_instance_valid(slot):
			# slot.size.y = 360 → factor = 2.25 → clamped a 1.6 para fonte menor
			var factor: float = clamp(slot.size.y / 160.0, 1.0, 1.76)
			slot.apply_scale(factor)
	# Hand cards stay at tscn default font sizes (1px = invisible labels,
	# only art shows). Player can hover to see full card_preview.

# ── Timer ─────────────────────────────────────────────────────────────────────

func _restart_timer() -> void:
	if _tick_timer != null and is_instance_valid(_tick_timer):
		_tick_timer.stop()
		_tick_timer.queue_free()
	_time_left = 75
	_update_timer_label()
	_start_dot_pulse(false)
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.autostart = true
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)


func _on_tick() -> void:
	_time_left = max(0, _time_left - 1)
	_update_timer_label()
	if _time_left == 0:
		_tick_timer.stop()
		if not _confirmed:
			if _selected_hero == null and not _slots.is_empty():
				_on_slot_clicked(_heroes[0])
			_on_confirm_pressed()


func _update_timer_label() -> void:
	var m := _time_left / 60
	var s := _time_left % 60
	_timer_lbl.text = "●  Tempo  %02d:%02d" % [m, s]
	if _time_left <= 10:
		_timer_lbl.add_theme_color_override("font_color", Color(0.90, 0.30, 0.15))
		_start_dot_pulse(true)
	else:
		_timer_lbl.add_theme_color_override("font_color", C_CRIMSON_BR)


func _start_dot_pulse(urgent: bool) -> void:
	if _dot_tween != null and _dot_tween.is_valid():
		_dot_tween.kill()
	_dot_tween = create_tween().set_loops()
	var dur := 0.6 if urgent else 1.4
	_dot_tween.tween_property(_timer_lbl, "modulate:a", 0.3, dur * 0.5)
	_dot_tween.tween_property(_timer_lbl, "modulate:a", 1.0, dur * 0.5)

# ── Interaction ───────────────────────────────────────────────────────────────

func _on_slot_clicked(hero: Hero) -> void:
	if _confirmed or hero.state == Hero.State.DEFEATED:
		return
	_selected_hero = hero
	for i in _slots.size():
		var slot: HeroSlot = _slots[i]
		if _heroes[i] == hero:
			slot.modulate = Color(1.3, 1.3, 0.8)
		else:
			slot.modulate = Color.WHITE
	_confirm_btn.disabled = false
	_apply_confirm_style(true)
	_update_status()


func _on_confirm_pressed() -> void:
	if _confirmed or _selected_hero == null:
		return
	_confirmed = true

	# Dim non-selected slots
	for i in _slots.size():
		if _heroes[i] != _selected_hero:
			_slots[i].modulate = Color(1, 1, 1, 0.35)

	var local_idx := NetworkState.local_player_index
	var slot_idx: int = GameState.players[local_idx].heroes.find(_selected_hero)
	if slot_idx >= 0:
		GameState.rpc_id(1, "rpc_submit_hero", slot_idx)

	_show_waiting()


func _show_waiting() -> void:
	_confirm_btn.disabled = true
	_confirm_btn.text     = "Confirmar Herói"
	_apply_confirm_style(false)
	_timer_lbl.visible   = false
	_waiting_lbl.visible = true
	if _dot_tween != null and _dot_tween.is_valid():
		_dot_tween.kill()
	_timer_lbl.modulate.a = 1.0
	_update_status()
	_apply_peek_state()


func _update_status() -> void:
	if (_confirmed or not _timer_lbl.visible) and _selected_hero != null:
		_status_lbl.text = "[color=#e8c66e]%s[/color] confirmado — aguardando oponente…" % _selected_hero.hero_name
	elif _selected_hero != null:
		_status_lbl.text = "[color=#e8c66e]%s[/color] selecionado — pronto para confirmar." % _selected_hero.hero_name
	else:
		_status_lbl.text = "[color=#b5a98a][i]Nenhum herói selecionado.[/i][/color]"

# ── GameBus ───────────────────────────────────────────────────────────────────

func _on_state_synced() -> void:
	if visible:
		_refresh_screen()
