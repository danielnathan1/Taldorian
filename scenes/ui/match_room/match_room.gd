# scenes/ui/match_room/match_room.gd
# Sala de espera (Match Room) — lobby pré-partida 1v1 (Modelo A).
#
# O servidor (RoomService) é a autoridade: difunde o detalhe da sala (assentos +
# ready + counting_down) por GameBus.match_room_synced. O "pronto" e o "sair" vão
# ao servidor via RoomService.request_ready / request_leave_match_room. Quando os
# dois ficam prontos, o servidor conta 3s e inicia a partida (MatchService troca
# todos para o board). Esta cena só REAGE — não decide nada de rede.
#
# Parte 1: layout funcional + partículas. Parte 2: polimento visual (anéis de
# runa, sigilo VS exato, glow/animações). Ver docs/Match Room.
extends Control

const S := preload("res://scenes/ui/deck_builder/db_styles.gd")

const READY      := Color("33b87a")
const READY_GLOW := Color("4fd693")
const GREEN_NET  := Color("3fbf7f")
const CIRCLE_SIZE := 190.0

# ── Estado ────────────────────────────────────────────────────────────────────
var _detail: Dictionary = {}
var _local_ready: bool = false
var _countdown_active: bool = false
var _countdown_tween: Tween

# ── Nós construídos em runtime ────────────────────────────────────────────────
var _room_title: Label
var _room_chip: Label
var _room_id_lbl: Label
var _seats_box: HBoxContainer
var _footer_status: Label
var _ready_btn: Button
var _countdown_overlay: ColorRect
var _countdown_num: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameBus.match_room_synced.connect(_on_synced)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	RoomService.request_room_detail()
	_render()


# ════════════════════════════════════════════════════════════════════════════
#  CONSTRUÇÃO DA UI
# ════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = S.C_BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_embers()

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 44)
	root.add_theme_constant_override("margin_right", 44)
	root.add_theme_constant_override("margin_top", 26)
	root.add_theme_constant_override("margin_bottom", 26)
	add_child(root)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 14)
	root.add_child(shell)

	shell.add_child(_build_topbar())
	var sep := HSeparator.new()
	shell.add_child(sep)

	var arena := CenterContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(arena)
	_seats_box = HBoxContainer.new()
	_seats_box.add_theme_constant_override("separation", 80)
	_seats_box.alignment = BoxContainer.ALIGNMENT_CENTER
	arena.add_child(_seats_box)

	shell.add_child(_build_footer())
	_build_countdown_overlay()


func _build_topbar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 52
	bar.add_theme_constant_override("separation", 12)

	_room_title = Label.new()
	_room_title.add_theme_font_override("font", S.FONT_BLACK)
	_room_title.add_theme_font_size_override("font_size", 26)
	_room_title.add_theme_color_override("font_color", S.C_GOLD_GLOW)
	_room_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_room_title)

	_room_chip = Label.new()
	_room_chip.add_theme_font_override("font", S.FONT_REG)
	_room_chip.add_theme_font_size_override("font_size", 12)
	_room_chip.add_theme_color_override("font_color", S.C_GOLD)
	_room_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_room_chip)

	_room_id_lbl = Label.new()
	_room_id_lbl.add_theme_font_override("font", S.FONT_REG)
	_room_id_lbl.add_theme_font_size_override("font_size", 12)
	_room_id_lbl.add_theme_color_override("font_color", S.C_GOLD_DIM)
	_room_id_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_room_id_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var net := HBoxContainer.new()
	net.add_theme_constant_override("separation", 8)
	net.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	net.add_child(_make_dot(8, GREEN_NET))
	var net_lbl := Label.new()
	net_lbl.text = "Rede Local · sincronizado"
	net_lbl.add_theme_font_override("font", S.FONT_REG)
	net_lbl.add_theme_font_size_override("font_size", 12)
	net_lbl.add_theme_color_override("font_color", S.C_PARCHMENT_D)
	net.add_child(net_lbl)
	bar.add_child(net)
	return bar


func _build_footer() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)

	_footer_status = Label.new()
	_footer_status.add_theme_font_override("font", S.FONT_REG)
	_footer_status.add_theme_font_size_override("font_size", 14)
	_footer_status.add_theme_color_override("font_color", S.C_PARCHMENT_D)
	_footer_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_footer_status)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var leave_btn := Button.new()
	leave_btn.text = "⬅  Sair da Sala"
	leave_btn.custom_minimum_size = Vector2(180, 46)
	S.apply_button_crimson(leave_btn)
	leave_btn.pressed.connect(_on_leave_pressed)
	bar.add_child(leave_btn)

	_ready_btn = Button.new()
	_ready_btn.custom_minimum_size = Vector2(200, 46)
	S.apply_button_gold(_ready_btn)
	_ready_btn.pressed.connect(_on_ready_pressed)
	bar.add_child(_ready_btn)
	return bar


func _build_countdown_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_countdown_overlay = ColorRect.new()
	_countdown_overlay.color = Color(0.02, 0.02, 0.07, 0.82)
	_countdown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_countdown_overlay.visible = false
	layer.add_child(_countdown_overlay)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	_countdown_overlay.add_child(v)

	var title := Label.new()
	title.text = "A BATALHA COMEÇA EM"
	title.add_theme_font_override("font", S.FONT_REG)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", S.C_GOLD_DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_countdown_num = Label.new()
	_countdown_num.text = "3"
	_countdown_num.add_theme_font_override("font", S.FONT_BLACK)
	_countdown_num.add_theme_font_size_override("font_size", 120)
	_countdown_num.add_theme_color_override("font_color", S.C_GOLD_GLOW)
	_countdown_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_countdown_num)


# ════════════════════════════════════════════════════════════════════════════
#  RENDER (a partir de _detail)
# ════════════════════════════════════════════════════════════════════════════
func _on_synced(p_detail: Dictionary) -> void:
	_detail = p_detail
	# Reconcilia o ready local com o que o servidor confirmou para o nosso assento.
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
	_room_chip.text = "Flash" if gtype == "flash" else "Clássico"
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
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size.x = 240
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	var present := p_seat != null
	var is_ready := present and bool((p_seat as Dictionary).get("ready", false))
	var is_you := present and int((p_seat as Dictionary).get("peer", -1)) == p_my_id

	# Badge de status (acima do círculo)
	var badge := Label.new()
	badge.add_theme_font_override("font", S.FONT_REG)
	badge.add_theme_font_size_override("font_size", 13)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.custom_minimum_size.y = 24
	if not present:
		badge.text = "vazio"
		badge.add_theme_color_override("font_color", S.C_GOLD_DIM)
	elif is_ready:
		badge.text = "●  PRONTO"
		badge.add_theme_color_override("font_color", READY_GLOW)
	else:
		badge.text = "aguardando…"
		badge.add_theme_color_override("font_color", S.C_GOLD_DIM)
	col.add_child(badge)

	# Círculo (Panel circular)
	var circle_wrap := CenterContainer.new()
	var circle := Panel.new()
	circle.custom_minimum_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	circle.add_theme_stylebox_override("panel", _circle_style(present, is_ready))
	var inner := Label.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_theme_font_override("font", S.FONT_BLACK)
	inner.add_theme_font_size_override("font_size", 56)
	if present:
		var nm := str((p_seat as Dictionary).get("name", "?"))
		inner.text = (nm.substr(0, 1)).to_upper() if nm.length() > 0 else "?"
		inner.add_theme_color_override("font_color", READY_GLOW if is_ready else S.C_GOLD_GLOW)
	else:
		inner.text = "?"
		inner.add_theme_color_override("font_color", S.C_GOLD_DIM)
	circle.add_child(inner)
	circle_wrap.add_child(circle)
	col.add_child(circle_wrap)

	# Nameplate
	var name_lbl := Label.new()
	name_lbl.add_theme_font_override("font", S.FONT_BOLD)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if present:
		var nm2 := str((p_seat as Dictionary).get("name", "Jogador"))
		name_lbl.text = nm2 + ("  (Você)" if is_you else "")
		name_lbl.add_theme_color_override("font_color", S.C_PARCHMENT)
	else:
		name_lbl.text = "Aguardando oponente…"
		name_lbl.add_theme_color_override("font_color", S.C_PARCHMENT_D)
	col.add_child(name_lbl)

	var sub := Label.new()
	sub.add_theme_font_override("font", S.FONT_REG)
	sub.add_theme_font_size_override("font_size", 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", S.C_GOLD_DIM)
	if present and bool((p_seat as Dictionary).get("is_host", false)):
		sub.text = "⌂ Anfitrião"
	else:
		sub.text = ""
	col.add_child(sub)
	return col


func _make_vs() -> Control:
	var v := CenterContainer.new()
	v.custom_minimum_size = Vector2(90, CIRCLE_SIZE)
	var lbl := Label.new()
	lbl.text = "VS"
	lbl.add_theme_font_override("font", S.FONT_BLACK)
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", S.C_CRIMSON_BR)
	v.add_child(lbl)
	return v


func _circle_style(p_present: bool, p_ready: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(int(CIRCLE_SIZE / 2.0))
	s.set_border_width_all(2)
	if p_ready:
		s.bg_color = Color(READY.r, READY.g, READY.b, 0.16)
		s.border_color = Color(READY_GLOW.r, READY_GLOW.g, READY_GLOW.b, 0.9)
	elif p_present:
		s.bg_color = Color(0.04, 0.04, 0.09, 0.85)
		s.border_color = Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.7)
	else:
		s.bg_color = Color(0.04, 0.04, 0.09, 0.4)
		s.border_color = Color(S.C_GOLD.r, S.C_GOLD.g, S.C_GOLD.b, 0.22)
	return s


func _update_footer_and_button() -> void:
	var seats: Array = _detail.get("seats", [null, null])
	var opp_present := seats.size() > 1 and seats[1] != null and seats[0] != null
	# (qualquer assento vazio = ainda aguardando)
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
		_ready_btn.text = "✓  Pronto — Cancelar"
	else:
		_ready_btn.text = "⚔  Pronto"


# ════════════════════════════════════════════════════════════════════════════
#  CONTAGEM REGRESSIVA (visual; o servidor é quem inicia a partida)
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
		_countdown_tween.tween_callback(func() -> void: _set_countdown_num(n))
		_countdown_tween.tween_interval(1.0)


func _set_countdown_num(p_n: int) -> void:
	_countdown_num.text = str(p_n)
	_countdown_num.scale = Vector2(0.7, 0.7)
	_countdown_num.pivot_offset = _countdown_num.size / 2.0
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
	# Fallback: se por algum motivo o servidor não responder, volta ao mundo.
	if multiplayer.is_server():
		get_tree().change_scene_to_file(RoomService.WORLD_SCENE)


func _on_peer_disconnected(p_peer_id: int) -> void:
	# Se o servidor caiu, volta ao lobby.
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


func _make_dot(p_size: int, p_color: Color) -> Control:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(p_size, p_size)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = p_color
	st.set_corner_radius_all(p_size)
	dot.add_theme_stylebox_override("panel", st)
	return dot


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

	# Cor sobre a vida: dourado → carmesim → índigo, com fade-in/out no alpha.
	# (Variação por partícula via color_initial_ramp fica para a Parte 2.)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.90, 0.71, 0.33, 0.0),
		Color(0.90, 0.71, 0.33, 0.55),
		Color(0.70, 0.25, 0.25, 0.45),
		Color(0.49, 0.50, 0.75, 0.0),
	])
	p.color_ramp = ramp

	# Pontinho redondo com glow (gerado por código — sem asset).
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
