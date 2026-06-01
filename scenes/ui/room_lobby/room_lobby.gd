# scenes/ui/room_lobby/room_lobby.gd
# Tela "Salas de Batalha" — navegação de salas (mock), criação, fila rankeada e
# deck ativo. Abre como overlay sobre o mundo aberto (não troca de cena, para
# manter a conexão ENet do mundo viva — Modelo A).
#
# A cena só reage; a origem das salas vive em RoomService (autoload).
extends Control

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")
const SETTINGS_PATH := "user://settings.cfg"

signal closed

# Paleta extra (espelha o protótipo Room Lobby.html, ajustada à paleta do projeto)
const C_INDIGO := Color(0.353, 0.373, 0.690)   # chip "Flash"
const C_GREEN_NET := Color(0.247, 0.749, 0.498)

# ── Estado ──────────────────────────────────────────────────────────────────
var _selected_id: int = -1
var _active_deck_id: String = ""
var _num_filter: String = ""
var _name_filter: String = ""
var _queue_seconds: int = 0
var _queue_tween: Tween

# ── Nós construídos em runtime ────────────────────────────────────────────────
var _room_list: VBoxContainer
var _room_rows: Array[Control] = []
var _count_label: Label
var _empty_label: Label
var _connect_button: Button
var _ranked_button: Button
var _queue_row: HBoxContainer
var _queue_label: Label
var _deck_card_name: Label
var _deck_card_meta: Label
var _deck_options: VBoxContainer
var _deck_chevron: Label
var _net_label: Label
var _toast_label: Label
var _toast_tween: Tween
var _modal_layer: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_active_deck()
	_build_ui()
	_connect_service()
	_refresh_rooms()
	_update_net_status()


func _connect_service() -> void:
	RoomService.rooms_updated.connect(func(_r: Array) -> void: _refresh_rooms())
	RoomService.join_result.connect(_on_join_result)
	RoomService.room_created.connect(_on_room_created)
	# Puxa a lista atual do servidor ao abrir a tela.
	RoomService.refresh()


# ════════════════════════════════════════════════════════════════════════════
#  CONSTRUÇÃO DA UI
# ════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	# Fundo
	var bg := ColorRect.new()
	bg.color = S.C_BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		root.add_theme_constant_override("margin_%s" % ("left" if side == SIDE_LEFT else "right"), 40)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_bottom", 24)
	add_child(root)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 16)
	root.add_child(shell)

	shell.add_child(_build_topbar())

	var sep := HSeparator.new()
	shell.add_child(sep)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	shell.add_child(columns)

	columns.add_child(_build_left_column())
	columns.add_child(_build_right_column())

	# Camada de modais
	_modal_layer = Control.new()
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_modal_layer)

	# Toast
	_toast_label = Label.new()
	_toast_label.add_theme_font_override("font", S.FONT_REG)
	_toast_label.add_theme_font_size_override("font_size", 14)
	_toast_label.add_theme_color_override("font_color", S.C_GOLD_GLOW)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_label.offset_top = -80
	_toast_label.offset_bottom = -50
	_toast_label.offset_left = -300
	_toast_label.offset_right = 300
	_toast_label.modulate.a = 0.0
	add_child(_toast_label)

	# Entrada animada
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


func _build_topbar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 56
	bar.add_theme_constant_override("separation", 14)

	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	var mark := Label.new()
	mark.text = "TALDORIAN"
	mark.add_theme_font_override("font", S.FONT_BLACK)
	mark.add_theme_font_size_override("font_size", 28)
	mark.add_theme_color_override("font_color", S.C_GOLD_GLOW)
	brand.add_child(mark)
	var tag := Label.new()
	tag.text = "SALAS DE BATALHA"
	tag.add_theme_font_override("font", S.FONT_REG)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", S.C_GOLD_DIM)
	brand.add_child(tag)
	bar.add_child(brand)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	# Status de rede
	var net := HBoxContainer.new()
	net.add_theme_constant_override("separation", 8)
	net.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot := _make_dot(8, C_GREEN_NET)
	net.add_child(dot)
	_net_label = Label.new()
	_net_label.add_theme_font_override("font", S.FONT_REG)
	_net_label.add_theme_font_size_override("font_size", 12)
	_net_label.add_theme_color_override("font_color", S.C_PARCHMENT_D)
	net.add_child(_net_label)
	bar.add_child(net)

	# Botão fechar
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(40, 40)
	close.add_theme_font_size_override("font_size", 16)
	var cs := S.button_crimson_normal()
	cs.set_corner_radius_all(20)
	var csh := S.button_crimson_hover()
	csh.set_corner_radius_all(20)
	close.add_theme_stylebox_override("normal", cs)
	close.add_theme_stylebox_override("hover", csh)
	close.add_theme_stylebox_override("pressed", csh)
	close.add_theme_color_override("font_color", Color(0.88, 0.6, 0.6))
	close.add_theme_color_override("font_hover_color", Color(1, 0.8, 0.8))
	close.pressed.connect(_on_close_pressed)
	bar.add_child(close)

	return bar


func _build_left_column() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", S.panel_mid())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 3.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Cabeçalho: título + contador + filtros
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)

	var title := _section_label("SALAS ABERTAS")
	head.add_child(title)

	_count_label = Label.new()
	_count_label.add_theme_font_override("font", S.FONT_REG)
	_count_label.add_theme_font_size_override("font_size", 12)
	_count_label.add_theme_color_override("font_color", S.C_PARCHMENT_D)
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count_label)

	var head_spacer := Control.new()
	head_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_spacer)

	var num_filter := _make_line_edit("#  número", 120)
	num_filter.text_changed.connect(func(t: String) -> void:
		_num_filter = t
		_refresh_rooms())
	head.add_child(num_filter)

	var name_filter := _make_line_edit("⌕  nome", 200)
	name_filter.text_changed.connect(func(t: String) -> void:
		_name_filter = t
		_refresh_rooms())
	head.add_child(name_filter)

	vbox.add_child(head)

	# Cabeçalho de colunas
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 0)
	cols.add_child(_col_header("ID", 70, HORIZONTAL_ALIGNMENT_LEFT, false))
	cols.add_child(_col_header("SALA", 0, HORIZONTAL_ALIGNMENT_LEFT, true))
	cols.add_child(_col_header("MODO", 130, HORIZONTAL_ALIGNMENT_LEFT, false))
	cols.add_child(_col_header("JOGADORES", 110, HORIZONTAL_ALIGNMENT_RIGHT, false))
	vbox.add_child(cols)

	# Lista
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_room_list = VBoxContainer.new()
	_room_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_room_list)
	vbox.add_child(scroll)

	# Estado vazio
	_empty_label = Label.new()
	_empty_label.text = "Nenhuma sala encontrada com esse filtro"
	_empty_label.add_theme_font_override("font", S.FONT_REG)
	_empty_label.add_theme_font_size_override("font_size", 13)
	_empty_label.add_theme_color_override("font_color", S.C_PARCHMENT_D)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.visible = false
	_room_list.add_child(_empty_label)

	# Barra de ações
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)

	_connect_button = Button.new()
	_connect_button.text = "⚔  Conectar"
	_connect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_connect_button.size_flags_stretch_ratio = 1.6
	_connect_button.custom_minimum_size.y = 44
	S.apply_button_gold(_connect_button)
	_connect_button.disabled = true
	_connect_button.pressed.connect(_on_connect_pressed)
	actions.add_child(_connect_button)

	var random_btn := Button.new()
	random_btn.text = "⚄  Aleatório"
	random_btn.custom_minimum_size.y = 44
	S.apply_button_gold(random_btn)
	random_btn.pressed.connect(func() -> void: RoomService.join_random())
	actions.add_child(random_btn)

	var create_btn := Button.new()
	create_btn.text = "✚  Criar Sala"
	create_btn.custom_minimum_size.y = 44
	S.apply_button_gold(create_btn)
	create_btn.pressed.connect(_open_create_modal)
	actions.add_child(create_btn)

	vbox.add_child(actions)

	return panel


func _build_right_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 360
	col.size_flags_stretch_ratio = 1.0
	col.add_theme_constant_override("separation", 16)

	# ── Deck ativo ──
	var deck_panel := PanelContainer.new()
	deck_panel.add_theme_stylebox_override("panel", S.panel_mid())
	var deck_margin := _padded_vbox(16)
	deck_panel.add_child(deck_margin.get_parent())
	deck_margin.add_child(_section_label("DECK ATIVO"))
	deck_margin.add_child(_build_deck_selector())
	col.add_child(deck_panel)

	# ── Partida rankeada ──
	var ranked_panel := PanelContainer.new()
	ranked_panel.add_theme_stylebox_override("panel", S.panel_mid())
	ranked_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ranked_margin := _padded_vbox(16)
	ranked_panel.add_child(ranked_margin.get_parent())
	ranked_margin.add_theme_constant_override("separation", 12)
	ranked_margin.add_child(_section_label("PARTIDA RANKEADA"))

	var emblem := _make_ranked_emblem()
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ranked_margin.add_child(emblem)

	var tier := Label.new()
	tier.text = "Prata IV"
	tier.add_theme_font_override("font", S.FONT_BOLD)
	tier.add_theme_font_size_override("font_size", 18)
	tier.add_theme_color_override("font_color", S.C_PARCHMENT)
	tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranked_margin.add_child(tier)

	var elo := Label.new()
	elo.text = "1.248 pontos · 7 vitórias seguidas"
	elo.add_theme_font_override("font", S.FONT_REG)
	elo.add_theme_font_size_override("font_size", 12)
	elo.add_theme_color_override("font_color", S.C_PARCHMENT_D)
	elo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranked_margin.add_child(elo)

	# Linha "na fila" (oculta por padrão)
	_queue_row = HBoxContainer.new()
	_queue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_queue_row.add_theme_constant_override("separation", 8)
	_queue_row.visible = false
	var pulse := _make_dot(8, C_GREEN_NET)
	_queue_row.add_child(pulse)
	_pulse_dot(pulse)
	_queue_label = Label.new()
	_queue_label.add_theme_font_override("font", S.FONT_REG)
	_queue_label.add_theme_font_size_override("font_size", 12)
	_queue_label.add_theme_color_override("font_color", S.C_GOLD_GLOW)
	_queue_row.add_child(_queue_label)
	ranked_margin.add_child(_queue_row)

	var ranked_spacer := Control.new()
	ranked_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ranked_margin.add_child(ranked_spacer)

	_ranked_button = Button.new()
	_ranked_button.text = "⚔  Entrar na Fila Rankeada"
	_ranked_button.custom_minimum_size.y = 44
	S.apply_button_crimson(_ranked_button)
	_ranked_button.pressed.connect(_on_ranked_pressed)
	ranked_margin.add_child(_ranked_button)

	var builder_btn := Button.new()
	builder_btn.text = "⚒  Deck Builder"
	builder_btn.custom_minimum_size.y = 40
	S.apply_button_gold(builder_btn)
	builder_btn.pressed.connect(_on_builder_pressed)
	ranked_margin.add_child(builder_btn)

	col.add_child(ranked_panel)

	return col


func _build_deck_selector() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)

	var card := Button.new()
	card.custom_minimum_size.y = 56
	card.toggle_mode = false
	S.apply_button_gold(card)

	var card_box := HBoxContainer.new()
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_box.add_theme_constant_override("separation", 8)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_deck_card_name = Label.new()
	_deck_card_name.add_theme_font_override("font", S.FONT_BOLD)
	_deck_card_name.add_theme_font_size_override("font_size", 16)
	_deck_card_name.add_theme_color_override("font_color", S.C_GOLD_GLOW)
	info.add_child(_deck_card_name)
	_deck_card_meta = Label.new()
	_deck_card_meta.add_theme_font_override("font", S.FONT_REG)
	_deck_card_meta.add_theme_font_size_override("font_size", 11)
	_deck_card_meta.add_theme_color_override("font_color", S.C_PARCHMENT_D)
	info.add_child(_deck_card_meta)
	card_box.add_child(info)
	_deck_chevron = Label.new()
	_deck_chevron.text = "▼"
	_deck_chevron.add_theme_color_override("font_color", S.C_GOLD)
	_deck_chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_box.add_child(_deck_chevron)
	card.add_child(card_box)
	wrap.add_child(card)

	_deck_options = VBoxContainer.new()
	_deck_options.add_theme_constant_override("separation", 2)
	_deck_options.visible = false
	wrap.add_child(_deck_options)

	card.pressed.connect(func() -> void:
		_deck_options.visible = not _deck_options.visible
		_deck_chevron.text = "▲" if _deck_options.visible else "▼")

	_rebuild_deck_options()
	_update_active_deck_display()
	return wrap


# ════════════════════════════════════════════════════════════════════════════
#  LISTA DE SALAS
# ════════════════════════════════════════════════════════════════════════════
func _refresh_rooms() -> void:
	if _room_list == null:
		return
	for row in _room_rows:
		row.queue_free()
	_room_rows.clear()

	var filtered := _apply_filters()
	for room: RoomInfo in filtered:
		var row := _make_room_row(room)
		_room_list.add_child(row)
		_room_list.move_child(row, _room_list.get_child_count() - 2)  # antes do _empty_label
		_room_rows.append(row)

	_empty_label.visible = filtered.is_empty()
	_count_label.text = "%d de %d" % [filtered.size(), RoomService.rooms.size()]

	# Se a sala selecionada sumiu do filtro, limpa seleção
	if _selected_id != -1 and RoomService.get_room(_selected_id) == null:
		_select(-1)
	else:
		_update_selection_visuals()


func _apply_filters() -> Array:
	var out: Array = []
	for room: RoomInfo in RoomService.rooms:
		if not _num_filter.is_empty() and not str(room.id).contains(_num_filter):
			continue
		if not _name_filter.is_empty() and not room.room_name.to_lower().contains(_name_filter.to_lower()):
			continue
		out.append(room)
	return out


func _make_room_row(p_room: RoomInfo) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size.y = 52
	row.set_meta("room_id", p_room.id)
	row.add_theme_stylebox_override("panel", _row_style(false))

	var full := p_room.is_full()
	if full:
		row.modulate.a = 0.5

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	row.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	margin.add_child(hbox)

	# ID
	var id_lbl := Label.new()
	id_lbl.text = "#%d" % p_room.id
	id_lbl.custom_minimum_size.x = 70
	id_lbl.add_theme_font_override("font", S.FONT_REG)
	id_lbl.add_theme_font_size_override("font_size", 13)
	id_lbl.add_theme_color_override("font_color", S.C_GOLD_DIM)
	id_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(id_lbl)

	# Nome (com cadeado se privada)
	var name_cell := HBoxContainer.new()
	name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_cell.add_theme_constant_override("separation", 6)
	if p_room.locked:
		name_cell.add_child(_make_lock_icon())
	var name_lbl := Label.new()
	name_lbl.text = p_room.room_name
	name_lbl.add_theme_font_override("font", S.FONT_REG)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", S.C_PARCHMENT)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_cell.add_child(name_lbl)
	hbox.add_child(name_cell)

	# Chip de modo
	var chip_wrap := Control.new()
	chip_wrap.custom_minimum_size.x = 130
	var chip := _make_mode_chip(p_room)
	chip.position = Vector2(0, 0)
	chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	chip_wrap.add_child(chip)
	hbox.add_child(chip_wrap)

	# Jogadores
	var players_cell := HBoxContainer.new()
	players_cell.custom_minimum_size.x = 110
	players_cell.alignment = BoxContainer.ALIGNMENT_END
	players_cell.add_theme_constant_override("separation", 6)
	players_cell.add_child(_make_dot(7, S.C_GOLD if not full else S.C_CRIMSON_BR))
	var pl := Label.new()
	pl.text = "%d/%d" % [p_room.players, p_room.capacity]
	pl.add_theme_font_override("font", S.FONT_REG)
	pl.add_theme_font_size_override("font_size", 13)
	pl.add_theme_color_override("font_color", S.C_CRIMSON_BR if full else S.C_PARCHMENT)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	players_cell.add_child(pl)
	hbox.add_child(players_cell)

	if not full:
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select(p_room.id))
		row.mouse_entered.connect(func() -> void:
			if _selected_id != p_room.id:
				row.add_theme_stylebox_override("panel", _row_style(false, true)))
		row.mouse_exited.connect(func() -> void:
			if _selected_id != p_room.id:
				row.add_theme_stylebox_override("panel", _row_style(false)))

	return row


func _select(p_id: int) -> void:
	_selected_id = p_id
	_update_selection_visuals()
	if p_id == -1:
		_connect_button.disabled = true
		_connect_button.text = "⚔  Conectar"
	else:
		_connect_button.disabled = false
		_connect_button.text = "⚔  Conectar · #%d" % p_id


func _update_selection_visuals() -> void:
	for row in _room_rows:
		if not is_instance_valid(row):
			continue
		var rid: int = row.get_meta("room_id", -1)
		row.add_theme_stylebox_override("panel", _row_style(rid == _selected_id))


# ════════════════════════════════════════════════════════════════════════════
#  AÇÕES
# ════════════════════════════════════════════════════════════════════════════
func _on_connect_pressed() -> void:
	if _selected_id == -1:
		return
	var room := RoomService.get_room(_selected_id)
	if room == null:
		return
	if room.locked:
		_open_password_modal(room)
	else:
		RoomService.join_room(room.id)


func _on_join_result(success: bool, msg: String) -> void:
	_show_toast(("✦  " if success else "⚠  ") + msg)
	# Em sucesso, o servidor coloca o jogador na sala. Quando a sala enche, o
	# servidor inicia a partida (MatchService) e troca ambos para o board.


func _on_room_created(p_room: RoomInfo) -> void:
	# O servidor confirmou a criação e já colocou o criador na sala.
	_select(p_room.id)
	_show_toast("✦  Sala #%d criada — aguardando oponente" % p_room.id)


func _on_ranked_pressed() -> void:
	if RoomService.in_ranked_queue:
		RoomService.leave_ranked_queue()
		_stop_queue_timer()
	else:
		RoomService.enter_ranked_queue()
		_start_queue_timer()


func _on_builder_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/deck_builder/deck_builder.tscn")


func _on_close_pressed() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())


# ── Fila rankeada (timer visual) ──────────────────────────────────────────────
func _start_queue_timer() -> void:
	_queue_seconds = 0
	_queue_row.visible = true
	_ranked_button.text = "Cancelar Fila"
	if _queue_tween:
		_queue_tween.kill()
	_queue_tween = create_tween().set_loops()
	_queue_tween.tween_interval(1.0)
	_queue_tween.tween_callback(func() -> void:
		_queue_seconds += 1
		_queue_label.text = "Na fila · %02d:%02d" % [_queue_seconds / 60, _queue_seconds % 60])
	_queue_label.text = "Na fila · 00:00"


func _stop_queue_timer() -> void:
	if _queue_tween:
		_queue_tween.kill()
		_queue_tween = null
	_queue_row.visible = false
	_ranked_button.text = "⚔  Entrar na Fila Rankeada"


# ════════════════════════════════════════════════════════════════════════════
#  DECKS
# ════════════════════════════════════════════════════════════════════════════
func _rebuild_deck_options() -> void:
	for child in _deck_options.get_children():
		child.queue_free()
	if DeckStore.decks.is_empty():
		var none := Label.new()
		none.text = "Nenhum deck criado"
		none.add_theme_font_override("font", S.FONT_REG)
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", S.C_PARCHMENT_D)
		_deck_options.add_child(none)
		return
	for deck in DeckStore.decks:
		var opt := Button.new()
		opt.custom_minimum_size.y = 38
		opt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var active := deck.deck_id == _active_deck_id
		opt.text = "%s    %s" % [deck.deck_name, ("✓ ativo" if active else "%d cartas" % deck.total_cards())]
		S.apply_button_gold(opt)
		var did: String = deck.deck_id
		opt.pressed.connect(func() -> void: _set_active_deck(did))
		_deck_options.add_child(opt)


func _set_active_deck(p_deck_id: String) -> void:
	_active_deck_id = p_deck_id
	_save_active_deck()
	_deck_options.visible = false
	_deck_chevron.text = "▼"
	_rebuild_deck_options()
	_update_active_deck_display()
	var deck := DeckStore.get_deck(p_deck_id)
	if deck:
		_show_toast("✦  Deck ativo: %s" % deck.deck_name)


func _update_active_deck_display() -> void:
	var deck := DeckStore.get_deck(_active_deck_id)
	if deck == null and not DeckStore.decks.is_empty():
		deck = DeckStore.decks[0]
		_active_deck_id = deck.deck_id
	if deck == null:
		_deck_card_name.text = "Sem deck"
		_deck_card_meta.text = "Crie um deck no Deck Builder"
		return
	_deck_card_name.text = deck.deck_name
	_deck_card_meta.text = "%d heróis · %d cartas" % [deck.hero_names.size(), deck.total_cards()]


func _load_active_deck() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_active_deck_id = str(cfg.get_value("game", "active_deck_id", ""))


func _save_active_deck() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("game", "active_deck_id", _active_deck_id)
	cfg.save(SETTINGS_PATH)


# ════════════════════════════════════════════════════════════════════════════
#  MODAIS
# ════════════════════════════════════════════════════════════════════════════
func _open_create_modal() -> void:
	var overlay := _make_modal_overlay()
	var box := _make_modal_box(440)
	overlay.add_child(_center_modal(box))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	box.add_child(vbox)

	var title := Label.new()
	title.text = "⚒  CRIAR SALA"
	title.add_theme_font_override("font", S.FONT_BOLD)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", S.C_GOLD_GLOW)
	vbox.add_child(title)

	# Nome
	vbox.add_child(_field_label("NOME DA SALA"))
	var name_edit := _make_line_edit("Minha sala", 0)
	name_edit.max_length = 32
	vbox.add_child(name_edit)

	# Tipo
	vbox.add_child(_field_label("TIPO DE JOGO"))
	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 8)
	var selected_type := { "value": RoomInfo.TYPE_CLASSICO }
	var classico_btn := Button.new()
	var flash_btn := Button.new()
	classico_btn.text = "Clássico"
	flash_btn.text = "Flash"
	classico_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flash_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	classico_btn.custom_minimum_size.y = 38
	flash_btn.custom_minimum_size.y = 38
	var refresh_type := func() -> void:
		S.apply_chip(classico_btn, selected_type["value"] == RoomInfo.TYPE_CLASSICO)
		S.apply_chip(flash_btn, selected_type["value"] == RoomInfo.TYPE_FLASH)
	classico_btn.pressed.connect(func() -> void:
		selected_type["value"] = RoomInfo.TYPE_CLASSICO
		refresh_type.call())
	flash_btn.pressed.connect(func() -> void:
		selected_type["value"] = RoomInfo.TYPE_FLASH
		refresh_type.call())
	refresh_type.call()
	type_row.add_child(classico_btn)
	type_row.add_child(flash_btn)
	vbox.add_child(type_row)

	# Privada
	var private_row := HBoxContainer.new()
	private_row.add_theme_constant_override("separation", 8)
	var private_check := CheckBox.new()
	private_check.text = "Sala privada"
	private_check.add_theme_color_override("font_color", S.C_PARCHMENT)
	private_check.add_theme_font_override("font", S.FONT_REG)
	private_row.add_child(private_check)
	vbox.add_child(private_row)

	# Reveal senha
	var pass_reveal := VBoxContainer.new()
	pass_reveal.add_theme_constant_override("separation", 4)
	pass_reveal.visible = false
	pass_reveal.add_child(_field_label("SENHA"))
	var pass_edit := _make_line_edit("••••", 0)
	pass_edit.secret = true
	pass_reveal.add_child(pass_edit)
	vbox.add_child(pass_reveal)

	# Ações
	var create_btn := Button.new()
	var validate := func() -> void:
		var ok := not name_edit.text.strip_edges().is_empty()
		if private_check.button_pressed:
			ok = ok and not pass_edit.text.is_empty()
		create_btn.disabled = not ok
	private_check.toggled.connect(func(on: bool) -> void:
		pass_reveal.visible = on
		if on:
			pass_reveal.modulate.a = 0.0
			create_tween().tween_property(pass_reveal, "modulate:a", 1.0, 0.25)
		validate.call())
	name_edit.text_changed.connect(func(_t: String) -> void: validate.call())
	pass_edit.text_changed.connect(func(_t: String) -> void: validate.call())

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_END
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	S.apply_button_gold(cancel_btn)
	cancel_btn.pressed.connect(func() -> void: overlay.queue_free())
	create_btn.text = "Criar Sala"
	create_btn.custom_minimum_size = Vector2(140, 40)
	S.apply_button_crimson(create_btn)
	create_btn.disabled = true
	create_btn.pressed.connect(func() -> void:
		RoomService.create_room(
			name_edit.text.strip_edges(),
			selected_type["value"],
			private_check.button_pressed,
			pass_edit.text)
		overlay.queue_free()
		_show_toast("✦  Criando sala…"))
	actions.add_child(cancel_btn)
	actions.add_child(create_btn)
	vbox.add_child(actions)

	name_edit.grab_focus()


func _open_password_modal(p_room: RoomInfo) -> void:
	var overlay := _make_modal_overlay()
	var box := _make_modal_box(380)
	overlay.add_child(_center_modal(box))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	box.add_child(vbox)

	var title := Label.new()
	title.text = "🔒  SALA PROTEGIDA"
	title.add_theme_font_override("font", S.FONT_BOLD)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", S.C_GOLD_GLOW)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "%s · #%d" % [p_room.room_name, p_room.id]
	sub.add_theme_font_override("font", S.FONT_REG)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", S.C_PARCHMENT_D)
	vbox.add_child(sub)

	var pass_edit := _make_line_edit("Senha", 0)
	pass_edit.secret = true
	vbox.add_child(pass_edit)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_END
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	S.apply_button_gold(cancel_btn)
	cancel_btn.pressed.connect(func() -> void: overlay.queue_free())
	var enter_btn := Button.new()
	enter_btn.text = "Entrar"
	enter_btn.custom_minimum_size = Vector2(120, 40)
	S.apply_button_crimson(enter_btn)
	var submit := func() -> void:
		overlay.queue_free()
		RoomService.join_room(p_room.id, pass_edit.text)
	enter_btn.pressed.connect(submit)
	pass_edit.text_submitted.connect(func(_t: String) -> void: submit.call())
	actions.add_child(cancel_btn)
	actions.add_child(enter_btn)
	vbox.add_child(actions)

	pass_edit.grab_focus()


func _make_modal_overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		# Clicar no fundo escuro fecha (o Box consome seus próprios cliques)
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free())
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(overlay)
	overlay.tree_exited.connect(func() -> void:
		if _modal_layer.get_child_count() == 0:
			_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE)
	overlay.modulate.a = 0.0
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.2)
	return overlay


func _center_modal(p_box: Control) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(p_box)
	return center


func _make_modal_box(p_width: float) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(p_width, 0)
	var style := S.panel_mid()
	style.bg_color = S.C_BG_SURFACE
	style.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	# Impede que cliques no box fechem o overlay
	box.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			box.accept_event())
	box.scale = Vector2(0.94, 0.94)
	box.pivot_offset = Vector2(p_width / 2.0, 100)
	create_tween().tween_property(box, "scale", Vector2.ONE, 0.2)
	return box


# ════════════════════════════════════════════════════════════════════════════
#  HELPERS VISUAIS
# ════════════════════════════════════════════════════════════════════════════
func _section_label(p_text: String) -> Label:
	var lbl := Label.new()
	lbl.text = p_text
	lbl.add_theme_font_override("font", S.FONT_REG)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", S.C_GOLD_DIM)
	return lbl


func _field_label(p_text: String) -> Label:
	var lbl := Label.new()
	lbl.text = p_text
	lbl.add_theme_font_override("font", S.FONT_REG)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", S.C_GOLD_DIM)
	return lbl


func _col_header(p_text: String, p_width: float, p_align: int, p_expand: bool) -> Label:
	var lbl := Label.new()
	lbl.text = p_text
	lbl.add_theme_font_override("font", S.FONT_REG)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", S.C_GOLD_DIM)
	lbl.horizontal_alignment = p_align
	if p_expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		lbl.custom_minimum_size.x = p_width
	return lbl


func _make_line_edit(p_placeholder: String, p_width: float) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = p_placeholder
	if p_width > 0:
		le.custom_minimum_size.x = p_width
	else:
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.add_theme_font_override("font", S.FONT_REG)
	le.add_theme_font_size_override("font_size", 13)
	le.add_theme_color_override("font_color", S.C_PARCHMENT)
	le.add_theme_color_override("font_placeholder_color", Color(S.C_PARCHMENT_D, 0.5))
	le.add_theme_color_override("caret_color", S.C_GOLD)
	var normal := S.panel_deep()
	normal.set_content_margin_all(8)
	var focus := S.panel_deep()
	focus.border_color = S.border_gold(0.6)
	focus.set_content_margin_all(8)
	le.add_theme_stylebox_override("normal", normal)
	le.add_theme_stylebox_override("focus", focus)
	return le


func _row_style(p_selected: bool, p_hover: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(3)
	if p_selected:
		s.bg_color = Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.14)
		s.border_color = S.border_gold(0.75)
		s.set_border_width_all(1)
	elif p_hover:
		s.bg_color = Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.07)
		s.border_color = S.border_gold(0.25)
		s.set_border_width_all(1)
	else:
		s.bg_color = Color(S.C_BG_SURFACE.r, S.C_BG_SURFACE.g, S.C_BG_SURFACE.b, 0.5)
		s.border_color = S.border_gold(0.12)
		s.set_border_width_all(1)
	return s


func _make_mode_chip(p_room: RoomInfo) -> PanelContainer:
	var is_flash := p_room.game_type == RoomInfo.TYPE_FLASH
	var col := C_INDIGO if is_flash else S.C_GOLD
	var chip := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col.r, col.g, col.b, 0.10)
	s.border_color = Color(col.r, col.g, col.b, 0.45)
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.set_content_margin(SIDE_LEFT, 10)
	s.set_content_margin(SIDE_RIGHT, 10)
	s.set_content_margin(SIDE_TOP, 3)
	s.set_content_margin(SIDE_BOTTOM, 3)
	chip.add_theme_stylebox_override("panel", s)
	var lbl := Label.new()
	lbl.text = p_room.type_label()
	lbl.add_theme_font_override("font", S.FONT_REG)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", col)
	chip.add_child(lbl)
	return chip


func _make_dot(p_size: int, p_color: Color) -> Control:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(p_size, p_size)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var s := StyleBoxFlat.new()
	s.bg_color = p_color
	s.set_corner_radius_all(p_size)
	dot.add_theme_stylebox_override("panel", s)
	return dot


func _make_lock_icon() -> Control:
	# Cadeado desenhado: corpo (Panel) + arco (Panel com borda superior).
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(13, 14)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var shackle := Panel.new()
	shackle.position = Vector2(3, 0)
	shackle.size = Vector2(7, 6)
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0, 0, 0, 0)
	ss.border_color = S.C_GOLD
	ss.border_width_top = 2
	ss.border_width_left = 2
	ss.border_width_right = 2
	ss.set_corner_radius_all(3)
	shackle.add_theme_stylebox_override("panel", ss)
	holder.add_child(shackle)
	var body := Panel.new()
	body.position = Vector2(1, 5)
	body.size = Vector2(11, 9)
	var bs := StyleBoxFlat.new()
	bs.bg_color = S.C_GOLD
	bs.set_corner_radius_all(2)
	body.add_theme_stylebox_override("panel", bs)
	holder.add_child(body)
	return holder


func _make_ranked_emblem() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(64, 64)
	var diamond := Panel.new()
	diamond.size = Vector2(44, 44)
	diamond.position = Vector2(10, 10)
	diamond.pivot_offset = Vector2(22, 22)
	diamond.rotation = deg_to_rad(45)
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.12)
	ds.border_color = S.border_gold(0.6)
	ds.set_border_width_all(2)
	diamond.add_theme_stylebox_override("panel", ds)
	holder.add_child(diamond)
	var iv := Label.new()
	iv.text = "IV"
	iv.add_theme_font_override("font", S.FONT_BOLD)
	iv.add_theme_font_size_override("font_size", 20)
	iv.add_theme_color_override("font_color", S.C_GOLD_GLOW)
	iv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	iv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(iv)
	return holder


func _pulse_dot(p_dot: Control) -> void:
	var tw := p_dot.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw.tween_property(p_dot, "modulate:a", 0.3, 0.55)
	tw.tween_property(p_dot, "modulate:a", 1.0, 0.55)


func _padded_vbox(p_pad: int) -> VBoxContainer:
	# Retorna o VBox interno; o pai (MarginContainer) é acessível via get_parent().
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", p_pad)
	margin.add_theme_constant_override("margin_right", p_pad)
	margin.add_theme_constant_override("margin_top", p_pad)
	margin.add_theme_constant_override("margin_bottom", p_pad)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	return vbox


func _update_net_status() -> void:
	var n := 1
	if WorldState.has_method("get_players"):
		n = max(1, WorldState.get_players().size())
	_net_label.text = "Rede Local · %d jogador%s online" % [n, "es" if n != 1 else ""]


func _show_toast(p_msg: String) -> void:
	_toast_label.text = p_msg
	if _toast_tween:
		_toast_tween.kill()
	_toast_label.modulate.a = 0.0
	_toast_tween = create_tween().set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.4)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
