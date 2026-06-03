# scenes/ui/lobby/lobby.gd
# Hub principal (pós-login). As salas de batalha agora nascem no mundo aberto, por
# isso o antigo host/join LAN 1×1 foi removido. Daqui o jogador entra no mundo,
# monta deck, abre a loja de boosters ou sai (logout).
extends Control

const LOGIN_SCENE          := "res://scenes/ui/login/login.tscn"
const WORLD_CONNECT_SCENE  := "res://scenes/world/world_connect.tscn"
const DECK_BUILDER_SCENE   := "res://scenes/ui/deck_builder/deck_builder.tscn"
const BOOSTER_SHOP_SCENE   := "res://scenes/ui/booster_shop/booster_shop.tscn"
const CHARACTER_CREATOR_SCENE := "res://scenes/ui/character_creator/character_creator.tscn"
const SETTINGS_PATH        := "user://settings.cfg"

const FONT_DISPLAY   := preload("res://assets/fonts/CinzelDecorative-Black.ttf")
const FONT_DISPLAY_B := preload("res://assets/fonts/CinzelDecorative-Bold.ttf")
const FONT_BODY      := preload("res://assets/fonts/palatino/palr45w.ttf")

const C_GOLD        := Color(0.788, 0.627, 0.298)
const C_GOLD_GLOW   := Color(0.910, 0.784, 0.337)
const C_GOLD_DIM    := Color(0.549, 0.431, 0.192)
const C_CRIMSON_BR  := Color(0.690, 0.125, 0.125)
const C_PARCHMENT   := Color(0.929, 0.875, 0.784)
const C_PARCHMENT_D := Color(0.722, 0.659, 0.549)
const C_GREEN       := Color(0.40, 0.80, 0.58)
const C_BG_DEEP     := Color(0.043, 0.039, 0.090)

var _music: AudioStreamPlayer


func _ready() -> void:
	# Servidor dedicado do mundo: o Hub é a cena principal mas não deve rodar aqui.
	if WorldServer.is_dedicated:
		set_process(false)
		set_process_input(false)
		hide()
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Garante estado limpo de rede ao voltar de uma partida/mundo.
	multiplayer.multiplayer_peer = null
	_build_ui()
	_start_music()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_embers()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	# Título
	col.add_child(_lbl("O MUNDO DE TALDORIAN", FONT_BODY, 13, C_GOLD_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_lbl("TALDORIAN", FONT_DISPLAY, 64, C_GOLD_GLOW, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_lbl("TRADING CARD GAME", FONT_BODY, 13, C_CRIMSON_BR, HORIZONTAL_ALIGNMENT_CENTER))

	var who := NetworkState.account_name if NetworkState.account_name != "" else "Aventureiro"
	col.add_child(_lbl("Bem-vindo, %s" % who, FONT_BODY, 15, C_PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER))

	var gap := Control.new(); gap.custom_minimum_size.y = 12; col.add_child(gap)

	# Botões
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	btns.custom_minimum_size.x = 380
	col.add_child(btns)

	var world_btn := _make_button("⊕   Entrar no Mundo de Taldorian", C_GREEN, 20)
	world_btn.pressed.connect(_on_world)
	btns.add_child(world_btn)

	var deck_btn := _make_button("⚒   Construir Deck", C_GOLD, 16)
	deck_btn.pressed.connect(func(): get_tree().change_scene_to_file(DECK_BUILDER_SCENE))
	btns.add_child(deck_btn)

	var shop_btn := _make_button("✦   Loja de Boosters", C_GOLD, 16)
	shop_btn.pressed.connect(func(): get_tree().change_scene_to_file(BOOSTER_SHOP_SCENE))
	btns.add_child(shop_btn)

	var gap2 := Control.new(); gap2.custom_minimum_size.y = 4; btns.add_child(gap2)

	var exit_btn := _make_button("⎋   Sair", C_CRIMSON_BR, 14)
	exit_btn.pressed.connect(_on_logout)
	btns.add_child(exit_btn)


func _on_world() -> void:
	if not CharacterStore.has_character():
		_show_no_character_dialog()
		return
	get_tree().change_scene_to_file(WORLD_CONNECT_SCENE)


func _on_logout() -> void:
	NetworkState.account_name = ""
	if _music:
		_music.stop()
	get_tree().change_scene_to_file(LOGIN_SCENE)


# ── Música ────────────────────────────────────────────────────────────────────
func _start_music() -> void:
	var path := "res://audio/theme/lobby_theme.mp3"
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	add_child(_music)
	_music.play()


# ── Dialog: sem personagem ────────────────────────────────────────────────────
func _show_no_character_dialog() -> void:
	var old := get_node_or_null("NoCharacterDialog")
	if old:
		old.queue_free()

	var overlay := ColorRect.new()
	overlay.name = "NoCharacterDialog"
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.063, 0.082, 0.149, 0.97)
	ps.border_color = Color(C_GOLD, 0.40)
	ps.set_border_width_all(1)
	ps.set_content_margin_all(36)
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	vbox.add_child(_lbl("Personagem não encontrado", FONT_DISPLAY_B, 18, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var desc := _lbl("Você ainda não criou seu personagem para o mundo aberto. Crie agora para explorar!",
		FONT_BODY, 13, C_PARCHMENT_D, HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var cancel_btn := _make_button("Cancelar", C_PARCHMENT_D, 13)
	cancel_btn.custom_minimum_size = Vector2(140, 40)
	cancel_btn.pressed.connect(func() -> void: overlay.queue_free())
	btn_row.add_child(cancel_btn)

	var create_btn := _make_button("✦ Criar Personagem", C_GOLD_GLOW, 13)
	create_btn.custom_minimum_size = Vector2(220, 40)
	create_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(CHARACTER_CREATOR_SCENE))
	btn_row.add_child(create_btn)

	overlay.modulate.a = 0.0
	create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO).tween_property(overlay, "modulate:a", 1.0, 0.25)


# ── Helpers de UI ─────────────────────────────────────────────────────────────
func _lbl(p_text: String, p_font: Font, p_size: int, p_color: Color, p_align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = p_text
	l.add_theme_font_override("font", p_font)
	l.add_theme_font_size_override("font_size", p_size)
	l.add_theme_color_override("font_color", p_color)
	l.horizontal_alignment = p_align
	return l

func _make_button(p_text: String, p_color: Color, p_font_size: int) -> Button:
	var btn := Button.new()
	btn.text = p_text
	btn.custom_minimum_size = Vector2(0, 52)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		var a := 0.85 if state == "hover" else 0.45
		sb.bg_color = Color(0.078, 0.090, 0.180, 0.9) if state != "hover" else Color(0.10, 0.12, 0.22, 0.95)
		sb.border_color = Color(p_color.r, p_color.g, p_color.b, a)
		sb.set_border_width_all(1)
		sb.set_content_margin(SIDE_TOP, 14)
		sb.set_content_margin(SIDE_BOTTOM, 14)
		sb.set_content_margin(SIDE_LEFT, 18)
		sb.set_content_margin(SIDE_RIGHT, 18)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_override("font", FONT_DISPLAY_B)
	btn.add_theme_font_size_override("font_size", p_font_size)
	btn.add_theme_color_override("font_color", p_color)
	btn.add_theme_color_override("font_hover_color", p_color.lightened(0.18))
	btn.add_theme_color_override("font_pressed_color", p_color)
	return btn

func _build_embers() -> void:
	var p := CPUParticles2D.new()
	p.amount = 36
	p.lifetime = 12.0
	p.preprocess = 6.0
	p.position = Vector2(960, 1080)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(960, 8)
	p.direction = Vector2(0, -1)
	p.gravity = Vector2(0, -10)
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 40.0
	p.spread = 22.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.85, 1.0])
	ramp.colors = PackedColorArray([
		Color(C_GOLD_GLOW.r, C_GOLD_GLOW.g, C_GOLD_GLOW.b, 0.0),
		Color(C_GOLD_GLOW.r, C_GOLD_GLOW.g, C_GOLD_GLOW.b, 0.8),
		Color(C_CRIMSON_BR.r, C_CRIMSON_BR.g, C_CRIMSON_BR.b, 0.4),
		Color(C_CRIMSON_BR.r, C_CRIMSON_BR.g, C_CRIMSON_BR.b, 0.0),
	])
	p.color_ramp = ramp
	add_child(p)
