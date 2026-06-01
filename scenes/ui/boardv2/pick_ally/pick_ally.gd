# scenes/ui/boardv2/pick_ally/pick_ally.gd
# Overlay que permite ao jogador escolher um herói aliado para aplicar um efeito.
# Atualmente usado por: Broto Vital (curar 1 aliado à escolha).
extends Control

const _FONT_BLACK   := preload("res://assets/fonts/CinzelDecorative-Black.ttf")
const _FONT_REGULAR := preload("res://assets/fonts/CinzelDecorative-Regular.ttf")

var _hero_cards: Array[Control] = []
var _selected_idx: int = -1
var _confirm_btn: Button = null

func _ready() -> void:
	visible = false
	_build_ui()
	GameBus.state_synced.connect(_on_state_synced)

func _build_ui() -> void:
	# Fundo escurecido
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 520)
	_style_panel(panel)
	center.add_child(panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left",   36)
	margins.add_theme_constant_override("margin_right",  36)
	margins.add_theme_constant_override("margin_top",    28)
	margins.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margins)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margins.add_child(vbox)

	# Título
	var title := Label.new()
	title.text = "Escolha um herói aliado para curar"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _FONT_REGULAR)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Grade de heróis (3 lado a lado)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 28)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	for i in 3:
		var card := _make_hero_card(i)
		_hero_cards.append(card)
		hbox.add_child(card)

	vbox.add_child(HSeparator.new())

	# Botão confirmar
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirmar"
	_confirm_btn.custom_minimum_size = Vector2(220, 52)
	_confirm_btn.disabled = true
	_confirm_btn.add_theme_font_override("font", _FONT_BLACK)
	_confirm_btn.add_theme_font_size_override("font_size", 18)
	_style_btn(_confirm_btn, Color(0.08, 0.35, 0.15), Color(0.12, 0.55, 0.24))
	_confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(_confirm_btn)

func _make_hero_card(slot_idx: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 310)
	_style_hero_card(card, false)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left",  10)
	margins.add_theme_constant_override("margin_right", 10)
	margins.add_theme_constant_override("margin_top",   10)
	margins.add_theme_constant_override("margin_bottom",10)
	card.add_child(margins)
	margins.add_child(vb)

	# Arte do herói
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(200, 200)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(art)

	# Nome
	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", _FONT_BLACK)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.80))
	vb.add_child(name_lbl)

	# HP
	var hp_lbl := Label.new()
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 13)
	hp_lbl.add_theme_color_override("font_color", Color(0.55, 0.92, 0.70))
	vb.add_child(hp_lbl)

	# Guarda referências como metadata
	card.set_meta("slot_idx",  slot_idx)
	card.set_meta("art_rect",  art)
	card.set_meta("name_lbl",  name_lbl)
	card.set_meta("hp_lbl",    hp_lbl)

	# Clique
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	var empty_style := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_style)
	btn.add_theme_stylebox_override("hover",  empty_style)
	btn.add_theme_stylebox_override("pressed",empty_style)
	btn.pressed.connect(_on_hero_clicked.bind(slot_idx))
	card.add_child(btn)

	return card

func _refresh() -> void:
	var local_idx := NetworkState.local_player_index
	if GameState.players.size() <= local_idx:
		return
	var p := GameState.players[local_idx]
	_selected_idx = -1
	_confirm_btn.disabled = true

	for i in _hero_cards.size():
		var card  := _hero_cards[i]
		var hero  := p.heroes[i] if i < p.heroes.size() else null
		var art   := card.get_meta("art_rect") as TextureRect
		var name_lbl := card.get_meta("name_lbl") as Label
		var hp_lbl   := card.get_meta("hp_lbl")   as Label

		if hero == null:
			card.modulate = Color(0.3, 0.3, 0.3, 0.4)
			continue

		art.texture  = hero.get_texture()
		name_lbl.text = hero.hero_name
		hp_lbl.text   = "♥ %d / %d" % [hero.current_hp, hero.max_hp]

		if hero.state == Hero.State.DEFEATED:
			card.modulate = Color(0.4, 0.4, 0.4, 0.35)
		else:
			card.modulate = Color.WHITE

		_style_hero_card(card, false)

func _on_hero_clicked(slot_idx: int) -> void:
	var local_idx := NetworkState.local_player_index
	if GameState.players.size() <= local_idx:
		return
	var p := GameState.players[local_idx]
	if slot_idx >= p.heroes.size():
		return
	var hero := p.heroes[slot_idx]
	if hero.state == Hero.State.DEFEATED:
		return  # não pode selecionar herói derrotado

	_selected_idx = slot_idx
	for i in _hero_cards.size():
		_style_hero_card(_hero_cards[i], i == slot_idx)
	_confirm_btn.disabled = false

func _on_confirm() -> void:
	if _selected_idx < 0:
		return
	GameState.rpc_id(1, "rpc_submit_ally_pick", _selected_idx)
	visible = false

# ── estado ────────────────────────────────────────────────

func _on_state_synced() -> void:
	var local_idx  := NetworkState.local_player_index
	var pick_player := GameState.get_pending_ally_pick_player()
	if pick_player == local_idx:
		visible = true
		_refresh()
	else:
		visible = false

# ── estilos ────────────────────────────────────────────────

func _style_panel(panel: PanelContainer) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.05, 0.12, 0.97)
	s.set_corner_radius_all(16)
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.border_color = Color(0.28, 0.72, 0.42, 0.90)
	panel.add_theme_stylebox_override("panel", s)

func _style_hero_card(card: PanelContainer, selected: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.08, 0.18, 0.95) if not selected else Color(0.10, 0.32, 0.16, 0.97)
	s.set_corner_radius_all(12)
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.border_color = Color(0.28, 0.72, 0.42, 0.85) if selected else Color(0.30, 0.28, 0.45, 0.60)
	card.add_theme_stylebox_override("panel", s)

func _style_btn(btn: Button, normal_col: Color, hover_col: Color) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = normal_col
	sn.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sn)
	var sh := StyleBoxFlat.new()
	sh.bg_color = hover_col
	sh.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("hover", sh)
	var sd := StyleBoxFlat.new()
	sd.bg_color = Color(normal_col.r * 0.6, normal_col.g * 0.6, normal_col.b * 0.6)
	sd.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("disabled", sd)
