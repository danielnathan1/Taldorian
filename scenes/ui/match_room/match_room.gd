# scenes/ui/match_room/match_room.gd
# Sala de espera (Match Room) — lobby pré-partida 1v1 (Modelo A).
#
# O servidor (RoomService) é autoridade: difunde o detalhe da sala (assentos +
# ready + counting_down) por GameBus.match_room_synced. O "pronto"/"sair" vão ao
# servidor via RoomService.submit_ready / request_leave_match_room. Quando os dois
# ficam prontos, o servidor conta 3s e inicia a partida. Esta cena só REAGE.
#
# Parte 2: visual fiel ao protótipo (docs/Match Room) — anéis de runa girando,
# avatar em círculo interno, sigilo VS em losango, glow do "pronto", chão, deck.
extends Control

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")
const FONT_DISPLAY   := preload("res://assets/fonts/CinzelDecorative-Black.ttf")
const FONT_DISPLAY_B := preload("res://assets/fonts/CinzelDecorative-Bold.ttf")

# Paleta (espelha os tokens OKLCH do Match Room.html, em sRGB)
const BG_DEEP     := Color("0a0a16")
const GOLD        := Color("c89d4a")
const GOLD_DIM    := Color("8f6f37")
const GOLD_GLOW   := Color("e6b455")
const CRIMSON     := Color("8a2a2a")
const CRIMSON_BR  := Color("b34141")
const READY       := Color("33b87a")
const READY_GLOW  := Color("4fd693")
const PARCHMENT   := Color("e8dccb")
const PARCHMENT_D := Color("b6a78f")
const RUNE        := Color("7d7fc0")
const STAGE       := 210.0
const AVATAR      := 78.0

# ── Estado ────────────────────────────────────────────────────────────────────
var _detail: Dictionary = {}
var _local_ready: bool = false
var _countdown_active: bool = false
var _countdown_tween: Tween

# ── Nós ───────────────────────────────────────────────────────────────────────
var _room_title: Label
var _room_chip: Label
var _room_id_lbl: Label
var _seats_box: HBoxContainer
var _footer_status: Label
var _ready_btn: Button
var _countdown_overlay: ColorRect
var _countdown_num: Label
var _deck_picker: OptionButton
var _decks: Array = []   # decks do jogador (GET /decks); fallback: locais


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameBus.match_room_synced.connect(_on_synced)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	RoomService.request_room_detail()
	_render()
	_load_decks()   # corrotina: popula o picker e reporta o deck escolhido


# ════════════════════════════════════════════════════════════════════════════
#  CONSTRUÇÃO DA UI
# ════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Vinheta radial sutil (profundidade)
	var vign := TextureRect.new()
	vign.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vign.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vign.stretch_mode = TextureRect.STRETCH_SCALE
	var vt := GradientTexture2D.new()
	vt.width = 256
	vt.height = 256
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.62)
	vt.fill_to = Vector2(1.0, 1.1)
	var vg := Gradient.new()
	vg.offsets = PackedFloat32Array([0.0, 1.0])
	vg.colors = PackedColorArray([Color(0.12, 0.10, 0.22, 0.55), Color(0.0, 0.0, 0.0, 0.0)])
	vt.gradient = vg
	vign.texture = vt
	add_child(vign)

	_build_embers()

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 44)
	root.add_theme_constant_override("margin_right", 44)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_bottom", 24)
	add_child(root)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	root.add_child(shell)

	shell.add_child(_build_topbar())
	shell.add_child(_thin_divider())

	var arena := CenterContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(arena)
	_seats_box = HBoxContainer.new()
	_seats_box.add_theme_constant_override("separation", 90)
	_seats_box.alignment = BoxContainer.ALIGNMENT_CENTER
	arena.add_child(_seats_box)

	shell.add_child(_build_deck_picker_row())
	shell.add_child(_thin_divider())
	shell.add_child(_build_footer())
	_build_countdown_overlay()


func _build_deck_picker_row() -> Control:
	var cc := CenterContainer.new()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	cc.add_child(hb)

	var lbl := Label.new()
	lbl.text = "SEU DECK"
	lbl.add_theme_font_override("font", S.FONT_REG)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", GOLD_DIM)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(lbl)

	_deck_picker = OptionButton.new()
	_deck_picker.custom_minimum_size = Vector2(280, 38)
	_deck_picker.add_theme_font_override("font", S.FONT_REG)
	_deck_picker.add_theme_font_size_override("font_size", 14)
	_deck_picker.add_theme_color_override("font_color", PARCHMENT)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.09, 0.08, 0.14, 0.9)
	ps.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.4)
	ps.set_border_width_all(1)
	ps.set_content_margin(SIDE_LEFT, 12)
	ps.set_content_margin(SIDE_RIGHT, 12)
	ps.set_content_margin(SIDE_TOP, 7)
	ps.set_content_margin(SIDE_BOTTOM, 7)
	_deck_picker.add_theme_stylebox_override("normal", ps)
	_deck_picker.add_theme_stylebox_override("hover", ps)
	_deck_picker.add_theme_stylebox_override("pressed", ps)
	_deck_picker.add_theme_stylebox_override("focus", ps)
	_deck_picker.item_selected.connect(_on_deck_chosen)
	hb.add_child(_deck_picker)
	return cc


func _load_decks() -> void:
	var res := await ApiClient.get_decks()
	_decks = []
	_deck_picker.clear()
	if res.ok and res.data is Array:
		for d in res.data:
			if d is Dictionary:
				_decks.append(d)
				_deck_picker.add_item(str(d.get("name", "Deck")))
	# Fallback: decks locais (sem id de backend) se a API falhar/estiver vazia.
	if _decks.is_empty():
		for d in DeckStore.decks:
			_decks.append({ "id": "", "name": d.deck_name })
			_deck_picker.add_item(d.deck_name)
	if _decks.is_empty():
		_deck_picker.add_item("(sem decks)")
		_deck_picker.disabled = true
		return
	# Seleção padrão: o deck ativo (isActive), senão o primeiro.
	var sel := 0
	for i in _decks.size():
		if bool(_decks[i].get("isActive", false)):
			sel = i
			break
	_deck_picker.select(sel)
	_deck_picker.disabled = _local_ready
	_apply_deck_choice(sel)


func _on_deck_chosen(idx: int) -> void:
	_apply_deck_choice(idx)


func _apply_deck_choice(idx: int) -> void:
	if idx < 0 or idx >= _decks.size():
		return
	var d: Dictionary = _decks[idx]
	DeckStore.match_deck_id = str(d.get("id", ""))
	RoomService.report_deck_name(str(d.get("name", "")))


func _build_topbar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 50
	bar.add_theme_constant_override("separation", 14)

	_room_title = Label.new()
	_room_title.add_theme_font_override("font", FONT_DISPLAY_B)
	_room_title.add_theme_font_size_override("font_size", 30)
	_room_title.add_theme_color_override("font_color", GOLD_GLOW)
	_room_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_room_title)

	# Chip do modo (com borda dourada)
	var chip_panel := PanelContainer.new()
	chip_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.06)
	cs.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.4)
	cs.set_border_width_all(1)
	cs.set_content_margin(SIDE_LEFT, 9)
	cs.set_content_margin(SIDE_RIGHT, 9)
	cs.set_content_margin(SIDE_TOP, 4)
	cs.set_content_margin(SIDE_BOTTOM, 4)
	chip_panel.add_theme_stylebox_override("panel", cs)
	_room_chip = Label.new()
	_room_chip.add_theme_font_override("font", S.FONT_REG)
	_room_chip.add_theme_font_size_override("font_size", 11)
	_room_chip.add_theme_color_override("font_color", GOLD)
	chip_panel.add_child(_room_chip)
	bar.add_child(chip_panel)

	_room_id_lbl = Label.new()
	_room_id_lbl.add_theme_font_override("font", S.FONT_REG)
	_room_id_lbl.add_theme_font_size_override("font_size", 12)
	_room_id_lbl.add_theme_color_override("font_color", GOLD_DIM)
	_room_id_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_room_id_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var net := HBoxContainer.new()
	net.add_theme_constant_override("separation", 8)
	net.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	net.add_child(_make_dot(7, Color(0.45, 0.85, 0.55)))
	var net_lbl := Label.new()
	net_lbl.text = "Rede Local · sincronizado"
	net_lbl.add_theme_font_override("font", S.FONT_REG)
	net_lbl.add_theme_font_size_override("font_size", 13)
	net_lbl.add_theme_color_override("font_color", PARCHMENT_D)
	net.add_child(net_lbl)
	bar.add_child(net)
	return bar


func _build_footer() -> Control:
	var footer := Control.new()
	footer.custom_minimum_size.y = 64

	_footer_status = Label.new()
	_footer_status.add_theme_font_override("font", S.FONT_REG)
	_footer_status.add_theme_font_size_override("font_size", 14)
	_footer_status.add_theme_color_override("font_color", PARCHMENT_D)
	_footer_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_footer_status.offset_left = 4
	footer.add_child(_footer_status)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(cc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	cc.add_child(hb)

	var leave_btn := Button.new()
	leave_btn.text = "⬅  Sair da Sala"
	leave_btn.custom_minimum_size = Vector2(210, 50)
	_style_button(leave_btn, Color("2a1418"), Color("e0a8a8"), Color(CRIMSON_BR.r, CRIMSON_BR.g, CRIMSON_BR.b, 0.55))
	leave_btn.pressed.connect(_on_leave_pressed)
	hb.add_child(leave_btn)

	_ready_btn = Button.new()
	_ready_btn.custom_minimum_size = Vector2(240, 50)
	_ready_btn.pressed.connect(_on_ready_pressed)
	hb.add_child(_ready_btn)
	return footer


func _build_countdown_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_countdown_overlay = ColorRect.new()
	_countdown_overlay.color = Color(0.03, 0.03, 0.08, 0.78)
	_countdown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_countdown_overlay.visible = false
	layer.add_child(_countdown_overlay)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	_countdown_overlay.add_child(v)

	var title := Label.new()
	title.text = "A BATALHA COMEÇA EM"
	title.add_theme_font_override("font", S.FONT_REG)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", READY_GLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_countdown_num = Label.new()
	_countdown_num.text = "3"
	_countdown_num.add_theme_font_override("font", FONT_DISPLAY)
	_countdown_num.add_theme_font_size_override("font_size", 130)
	_countdown_num.add_theme_color_override("font_color", GOLD_GLOW)
	_countdown_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_countdown_num)


# ════════════════════════════════════════════════════════════════════════════
#  RENDER
# ════════════════════════════════════════════════════════════════════════════
func _on_synced(p_detail: Dictionary) -> void:
	_detail = p_detail
	var my := _local_seat()
	if not my.is_empty():
		_local_ready = bool(my.get("ready", false))
	_render()
	_handle_countdown(bool(p_detail.get("counting_down", false)))


func _render() -> void:
	if _room_title == null:
		return
	_room_title.text = str(_detail.get("room_name", "Sala de Batalha"))
	var gtype := str(_detail.get("game_type", "classico"))
	_room_chip.text = "FLASH" if gtype == "flash" else "CLÁSSICO"
	var rid: int = int(_detail.get("room_id", 0))
	_room_id_lbl.text = "Sala #%d" % rid if rid > 0 else ""

	_rebuild_seats()
	_update_footer_and_button()


func _rebuild_seats() -> void:
	for c in _seats_box.get_children():
		c.queue_free()
	var seats: Array = _detail.get("seats", [null, null])
	var my_id := multiplayer.get_unique_id()
	_seats_box.add_child(_make_seat(seats[0] if seats.size() > 0 else null, my_id))
	_seats_box.add_child(_make_vs())
	_seats_box.add_child(_make_seat(seats[1] if seats.size() > 1 else null, my_id))


func _make_seat(p_seat, p_my_id: int) -> Control:
	var present := p_seat != null
	var seat := (p_seat as Dictionary) if present else {}
	var is_ready := present and bool(seat.get("ready", false))
	var is_you := present and int(seat.get("peer", -1)) == p_my_id

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size.x = 280
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	# Badge de status
	var badge := Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.custom_minimum_size.y = 26
	if is_ready:
		badge.text = "●  PRONTO"
		badge.add_theme_font_override("font", S.FONT_BOLD)
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", READY_GLOW)
	elif present:
		badge.text = "aguardando…"
		badge.add_theme_font_override("font", S.FONT_REG)
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", Color(PARCHMENT_D.r, PARCHMENT_D.g, PARCHMENT_D.b, 0.6))
	else:
		badge.text = "vazio"
		badge.add_theme_font_override("font", S.FONT_REG)
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", Color(PARCHMENT_D.r, PARCHMENT_D.g, PARCHMENT_D.b, 0.45))
	col.add_child(badge)

	# Palco do círculo
	col.add_child(_make_circle_stage(seat, present, is_ready))

	# Nameplate
	var name_lbl := Label.new()
	name_lbl.add_theme_font_override("font", FONT_DISPLAY_B)
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if present:
		name_lbl.text = str(seat.get("name", "Jogador"))
		name_lbl.add_theme_color_override("font_color", PARCHMENT)
	else:
		name_lbl.text = "Aguardando oponente…"
		name_lbl.add_theme_font_override("font", S.FONT_REG)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(PARCHMENT_D.r, PARCHMENT_D.g, PARCHMENT_D.b, 0.6))
	col.add_child(name_lbl)

	var deck_lbl := Label.new()
	deck_lbl.add_theme_font_override("font", S.FONT_REG)
	deck_lbl.add_theme_font_size_override("font_size", 13)
	deck_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_lbl.add_theme_color_override("font_color", GOLD_DIM)
	deck_lbl.text = str(seat.get("deck", "")) if present else ""
	col.add_child(deck_lbl)

	if is_you:
		var you_tag := Label.new()
		you_tag.text = "VOCÊ"
		you_tag.add_theme_font_override("font", S.FONT_BOLD)
		you_tag.add_theme_font_size_override("font_size", 11)
		you_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		you_tag.add_theme_color_override("font_color", CRIMSON_BR)
		col.add_child(you_tag)
	return col


func _make_circle_stage(p_seat: Dictionary, p_present: bool, p_ready: bool) -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(STAGE, STAGE)
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Halo pulsante (somente quando pronto)
	if p_ready:
		var halo := Panel.new()
		_fill(halo, -16.0)
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hs := StyleBoxFlat.new()
		hs.bg_color = Color(READY_GLOW.r, READY_GLOW.g, READY_GLOW.b, 0.18)
		hs.set_corner_radius_all(int((STAGE + 32) / 2.0))
		halo.add_theme_stylebox_override("panel", hs)
		stage.add_child(halo)
		var tw := halo.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tw.tween_property(halo, "modulate:a", 0.35, 1.2)
		tw.tween_property(halo, "modulate:a", 1.0, 1.2)

	# Anel lento (tracejado, dourado/verde) — levemente para fora
	var ring_slow := _DashedRing.new()
	_fill(ring_slow, -7.0)
	ring_slow.dotted = false
	ring_slow.spin_speed = TAU / 38.0
	ring_slow.ring_color = (Color(READY.r, READY.g, READY.b, 0.45) if p_ready
		else Color(GOLD.r, GOLD.g, GOLD.b, 0.30 if p_present else 0.16))
	stage.add_child(ring_slow)

	# Anel rápido (pontilhado, índigo/verde) — para dentro, sentido inverso
	var ring_fast := _DashedRing.new()
	_fill(ring_fast, 8.0)
	ring_fast.dotted = true
	ring_fast.spin_speed = -TAU / 24.0
	ring_fast.ring_color = (Color(READY_GLOW.r, READY_GLOW.g, READY_GLOW.b, 0.4) if p_ready
		else Color(RUNE.r, RUNE.g, RUNE.b, 0.25))
	stage.add_child(ring_fast)

	# Círculo (Panel) — preenchimento + borda por estado
	var circle := Panel.new()
	_fill(circle, 4.0)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_theme_stylebox_override("panel", _circle_style(p_present, p_ready))
	stage.add_child(circle)

	# Conteúdo central
	var cc := CenterContainer.new()
	_fill(cc, 0.0)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(cc)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 5)
	cc.add_child(content)

	if p_present:
		# Avatar (círculo interno + inicial)
		var av := Panel.new()
		av.custom_minimum_size = Vector2(AVATAR, AVATAR)
		var avs := StyleBoxFlat.new()
		avs.bg_color = Color(0.12, 0.10, 0.20, 1.0)
		avs.border_color = (Color(READY.r, READY.g, READY.b, 0.6) if p_ready
			else Color(GOLD.r, GOLD.g, GOLD.b, 0.5))
		avs.set_border_width_all(1)
		avs.set_corner_radius_all(int(AVATAR / 2.0))
		av.add_theme_stylebox_override("panel", avs)
		var init := Label.new()
		init.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		init.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		init.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		init.add_theme_font_override("font", FONT_DISPLAY)
		init.add_theme_font_size_override("font_size", 34)
		init.add_theme_color_override("font_color", READY_GLOW if p_ready else GOLD_GLOW)
		var nm := str(p_seat.get("name", "?"))
		init.text = (nm.substr(0, 1)).to_upper() if nm.length() > 0 else "?"
		av.add_child(init)
		content.add_child(av)

		if bool(p_seat.get("is_host", false)):
			var host := Label.new()
			host.text = "⌂ ANFITRIÃO"
			host.add_theme_font_override("font", S.FONT_REG)
			host.add_theme_font_size_override("font_size", 9)
			host.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			host.add_theme_color_override("font_color", Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 0.8))
			content.add_child(host)
	else:
		var q := Label.new()
		q.text = "?"
		q.add_theme_font_override("font", FONT_DISPLAY)
		q.add_theme_font_size_override("font_size", 40)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.add_theme_color_override("font_color", Color(PARCHMENT_D.r, PARCHMENT_D.g, PARCHMENT_D.b, 0.5))
		content.add_child(q)
		var et := Label.new()
		et.text = "à espera"
		et.add_theme_font_override("font", S.FONT_REG)
		et.add_theme_font_size_override("font_size", 12)
		et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		et.add_theme_color_override("font_color", Color(PARCHMENT_D.r, PARCHMENT_D.g, PARCHMENT_D.b, 0.4))
		content.add_child(et)
	return stage


func _make_vs() -> Control:
	var wrap := VBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 12)
	wrap.custom_minimum_size = Vector2(110, STAGE)

	wrap.add_child(_vs_line(true))

	var vs_box := Control.new()
	vs_box.custom_minimum_size = Vector2(100, 100)
	vs_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sigil := _VsSigil.new()
	_fill(sigil, 0.0)
	vs_box.add_child(sigil)
	var vs_lbl := Label.new()
	vs_lbl.text = "VS"
	vs_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs_lbl.add_theme_font_override("font", FONT_DISPLAY)
	vs_lbl.add_theme_font_size_override("font_size", 38)
	vs_lbl.add_theme_color_override("font_color", CRIMSON_BR)
	vs_box.add_child(vs_lbl)
	wrap.add_child(vs_box)

	wrap.add_child(_vs_line(false))
	return wrap


func _vs_line(p_top: bool) -> Control:
	var line := Panel.new()
	line.custom_minimum_size = Vector2(1, 56)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 0.35)
	line.add_theme_stylebox_override("panel", st)
	return line


func _circle_style(p_present: bool, p_ready: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(int(STAGE / 2.0))
	s.set_border_width_all(2)
	if p_ready:
		s.bg_color = Color(0.10, 0.22, 0.16, 0.7)
		s.border_color = Color(READY.r, READY.g, READY.b, 0.9)
	elif p_present:
		s.bg_color = Color(0.07, 0.06, 0.12, 0.85)
		s.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	else:
		s.bg_color = Color(0.06, 0.05, 0.10, 0.5)
		s.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.22)
	return s


func _update_footer_and_button() -> void:
	var seats: Array = _detail.get("seats", [null, null])
	var both_present := seats.size() >= 2 and seats[0] != null and seats[1] != null
	var both_ready := both_present \
		and bool((seats[0] as Dictionary).get("ready", false)) \
		and bool((seats[1] as Dictionary).get("ready", false))

	if not both_present:
		_footer_status.text = "Aguardando um oponente entrar na sala…"
	elif both_ready:
		_footer_status.text = "Ambos prontos — iniciando…"
	elif _local_ready:
		_footer_status.text = "Aguardando o oponente confirmar…"
	else:
		_footer_status.text = "Confirme quando estiver pronto"

	_ready_btn.disabled = not both_present and not _local_ready
	if _local_ready:
		_ready_btn.text = "Pronto — Cancelar"
		_style_button(_ready_btn, Color("1e160c"), Color.WHITE, Color(GOLD.r, GOLD.g, GOLD.b, 0.6), 18)
	else:
		_ready_btn.text = "Pronto"
		_style_button(_ready_btn, Color("1d3a2a"), Color.WHITE, Color(READY.r, READY.g, READY.b, 0.8), 18)

	# Não troca de deck depois de confirmar "Pronto".
	if _deck_picker != null:
		_deck_picker.disabled = _local_ready or _deck_picker.item_count == 0


# ════════════════════════════════════════════════════════════════════════════
#  CONTAGEM REGRESSIVA (visual; o servidor inicia a partida)
# ════════════════════════════════════════════════════════════════════════════
func _handle_countdown(p_on: bool) -> void:
	if p_on and not _countdown_active:
		_start_countdown()
	elif not p_on and _countdown_active:
		_abort_countdown()


func _start_countdown() -> void:
	_countdown_active = true
	_countdown_overlay.visible = true
	if _countdown_tween:
		_countdown_tween.kill()
	_countdown_tween = create_tween()
	for n in [3, 2, 1]:
		_countdown_tween.tween_callback(_set_countdown_num.bind(n))
		_countdown_tween.tween_interval(1.0)


func _set_countdown_num(p_n: int) -> void:
	_countdown_num.text = str(p_n)
	_countdown_num.pivot_offset = _countdown_num.size / 2.0
	_countdown_num.scale = Vector2(0.7, 0.7)
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_countdown_num, "scale", Vector2.ONE, 0.35)


func _abort_countdown() -> void:
	_countdown_active = false
	if _countdown_tween:
		_countdown_tween.kill()
		_countdown_tween = null
	_countdown_overlay.visible = false


# ════════════════════════════════════════════════════════════════════════════
#  AÇÕES
# ════════════════════════════════════════════════════════════════════════════
func _on_ready_pressed() -> void:
	_local_ready = not _local_ready
	_update_footer_and_button()
	RoomService.submit_ready(_local_ready)


func _on_leave_pressed() -> void:
	RoomService.request_leave_match_room()
	if multiplayer.is_server():
		get_tree().change_scene_to_file(RoomService.WORLD_SCENE)


func _on_peer_disconnected(p_peer_id: int) -> void:
	if p_peer_id == 1 and not multiplayer.is_server():
		get_tree().change_scene_to_file("res://scenes/ui/lobby/lobby.tscn")


# ════════════════════════════════════════════════════════════════════════════
#  HELPERS
# ════════════════════════════════════════════════════════════════════════════
func _local_seat() -> Dictionary:
	var seats: Array = _detail.get("seats", [])
	var my_id := multiplayer.get_unique_id()
	for s in seats:
		if s != null and int((s as Dictionary).get("peer", -1)) == my_id:
			return s
	return {}


func _active_deck_name() -> String:
	var id := ""
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		id = str(cfg.get_value("game", "active_deck_id", ""))
	var deck = DeckStore.get_deck(id) if id != "" else null
	if deck == null and not DeckStore.decks.is_empty():
		deck = DeckStore.decks[0]
	return str(deck.deck_name) if deck != null else ""


func _fill(p_node: Control, p_inset: float) -> void:
	p_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_node.offset_left = p_inset
	p_node.offset_top = p_inset
	p_node.offset_right = -p_inset
	p_node.offset_bottom = -p_inset


func _thin_divider() -> Control:
	var line := Panel.new()
	line.custom_minimum_size.y = 1
	var st := StyleBoxFlat.new()
	st.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.15)
	line.add_theme_stylebox_override("panel", st)
	return line


func _make_dot(p_size: int, p_color: Color) -> Control:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(p_size, p_size)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = p_color
	st.set_corner_radius_all(p_size)
	dot.add_theme_stylebox_override("panel", st)
	return dot


func _style_button(p_btn: Button, p_bg: Color, p_text: Color, p_border: Color, p_font_size: int = 14) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		var bg := p_bg
		if state == "hover":
			bg = p_bg.lightened(0.08)
		elif state == "pressed":
			bg = p_bg.darkened(0.06)
		elif state == "disabled":
			bg = Color(p_bg.r, p_bg.g, p_bg.b, 0.45)
		sb.bg_color = bg
		sb.border_color = p_border
		sb.set_border_width_all(1)
		sb.set_content_margin_all(10)
		p_btn.add_theme_stylebox_override(state, sb)
	p_btn.add_theme_font_override("font", S.FONT_BOLD)
	p_btn.add_theme_font_size_override("font_size", p_font_size)
	p_btn.add_theme_color_override("font_color", p_text)
	p_btn.add_theme_color_override("font_hover_color", p_text.lightened(0.15))
	p_btn.add_theme_color_override("font_pressed_color", p_text)
	p_btn.add_theme_color_override("font_disabled_color", Color(p_text.r, p_text.g, p_text.b, 0.4))


func _build_embers() -> void:
	var p := CPUParticles2D.new()
	p.amount = 90
	p.lifetime = 11.0
	p.preprocess = 8.0
	p.position = Vector2(960, 1080)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(960, 8)
	p.direction = Vector2(0, -1)
	p.gravity = Vector2(0, -22)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 26.0
	p.spread = 18.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.1

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.90, 0.71, 0.33, 0.0),
		Color(0.90, 0.71, 0.33, 0.55),
		Color(0.70, 0.25, 0.25, 0.45),
		Color(0.49, 0.50, 0.75, 0.0),
	])
	p.color_ramp = ramp

	var tex := GradientTexture2D.new()
	tex.width = 8
	tex.height = 8
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var tg := Gradient.new()
	tg.offsets = PackedFloat32Array([0.0, 1.0])
	tg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	tex.gradient = tg
	p.texture = tex

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	add_child(p)


# ════════════════════════════════════════════════════════════════════════════
#  NÓS DESENHADOS (inner classes)
# ════════════════════════════════════════════════════════════════════════════
class _DashedRing extends Control:
	var ring_color: Color = Color(1, 1, 1, 0.3)
	var dotted: bool = false
	var spin_speed: float = 0.16   # rad/s; negativo = sentido inverso

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _process(delta: float) -> void:
		pivot_offset = size / 2.0
		rotation += spin_speed * delta

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 1.5
		if r <= 0.0:
			return
		var segs := 44 if dotted else 30
		var frac := 0.4 if dotted else 0.62
		var w := 1.0 if dotted else 1.6
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := a0 + (TAU / float(segs)) * frac
			draw_arc(c, r, a0, a1, 4, ring_color, w, true)


class _VsSigil extends Control:
	var border_outer: Color = Color("b34141")
	var border_inner: Color = Color("c89d4a")
	var fill_color: Color = Color(0.10, 0.05, 0.07, 0.7)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 2.0
		if r <= 0.0:
			return
		var outer := PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		draw_colored_polygon(outer, fill_color)
		var oc := outer.duplicate()
		oc.append(outer[0])
		draw_polyline(oc, Color(border_outer.r, border_outer.g, border_outer.b, 0.6), 1.6, true)
		var ri := r - 13.0
		if ri > 0.0:
			var inner := PackedVector2Array([
				c + Vector2(0, -ri), c + Vector2(ri, 0), c + Vector2(0, ri), c + Vector2(-ri, 0)])
			var ic := inner.duplicate()
			ic.append(inner[0])
			draw_polyline(ic, Color(border_inner.r, border_inner.g, border_inner.b, 0.5), 1.0, true)
