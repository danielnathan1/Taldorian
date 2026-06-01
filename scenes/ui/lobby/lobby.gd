extends Control

const PORT              := 7000
const BOARD_SCENE              := "res://scenes/ui/boardv2/board.tscn"
const WORLD_CONNECT_SCENE      := "res://scenes/world/world_connect.tscn"
const DECK_BUILDER_SCENE       := "res://scenes/ui/deck_builder/deck_builder.tscn"
const BOOSTER_SHOP_SCENE       := "res://scenes/ui/booster_shop/booster_shop.tscn"
const CHARACTER_CREATOR_SCENE  := "res://scenes/ui/character_creator/character_creator.tscn"

# ── Node references ────────────────────────────────────────────────────────────
@onready var address_input   : LineEdit       = %AddressInput
@onready var join_button     : Button         = %JoinButton
@onready var host_button     : Button         = %HostButton
@onready var help_button     : Button         = %HelpButton
@onready var world_button         : Button = %WorldButton
@onready var deck_builder_button  : Button = %DeckBuilderButton
@onready var booster_shop_button  : Button = %BoosterShopButton
@onready var status_label    : Label          = %StatusLabel
@onready var toast_label     : Label          = %ToastLabel
@onready var help_dialog     : Control        = %HelpDialog
@onready var title_block     : Control        = %TitleBlock
@onready var panel_container : PanelContainer = %LobbyPanel
@onready var particles       : CPUParticles2D = %Particles

# ── Colors ─────────────────────────────────────────────────────────────────────
const C_GOLD        := Color(0.788, 0.627, 0.298, 1.0)
const C_GOLD_GLOW   := Color(0.910, 0.784, 0.337, 1.0)
const C_GOLD_DIM    := Color(0.549, 0.431, 0.192, 1.0)
const C_CRIMSON     := Color(0.545, 0.102, 0.102, 1.0)
const C_CRIMSON_BR  := Color(0.690, 0.125, 0.125, 1.0)
const C_PARCHMENT   := Color(0.929, 0.875, 0.784, 1.0)
const C_PARCHMENT_D := Color(0.722, 0.659, 0.549, 1.0)
const C_PANEL_BG    := Color(0.063, 0.082, 0.149, 0.90)

var _toast_tween : Tween
var _music       : AudioStreamPlayer

func _ready() -> void:
	# Servidor dedicado do mundo (--world-server): o lobby é a cena principal, mas
	# não deve rodar aqui — sairia zerando o peer do servidor e conectando os sinais
	# de matchmaking do TCG. Bail imediato, deixando o WorldServer no comando.
	if WorldServer.is_dedicated:
		set_process(false)
		set_process_input(false)
		hide()
		return

	# Garante que nenhum peer antigo (TCG ou mundo) interfere ao voltar para o lobby
	multiplayer.multiplayer_peer = null
	position = Vector2.ZERO
	size     = get_viewport_rect().size
	address_input.text = "127.0.0.1"
	_apply_styles()
	_setup_particles()
	_animate_entrance()
	_connect_signals()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	_start_music()


# ── Styling ────────────────────────────────────────────────────────────────────
func _apply_styles() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_PANEL_BG
	panel_style.border_color = Color(C_GOLD, 0.28)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(0)
	panel_style.set_content_margin_all(32.0)
	panel_container.add_theme_stylebox_override("panel", panel_style)

	var join_normal := _make_button_style(Color(0.078, 0.098, 0.188), C_GOLD, 0.5)
	var join_hover  := _make_button_style(Color(0.098, 0.118, 0.220), C_GOLD, 0.85)
	var join_press  := _make_button_style(Color(0.055, 0.071, 0.145), C_GOLD, 1.0)
	join_button.add_theme_stylebox_override("normal",  join_normal)
	join_button.add_theme_stylebox_override("hover",   join_hover)
	join_button.add_theme_stylebox_override("pressed", join_press)
	join_button.add_theme_color_override("font_color",         C_GOLD_GLOW)
	join_button.add_theme_color_override("font_hover_color",   C_GOLD_GLOW)
	join_button.add_theme_color_override("font_pressed_color", C_GOLD)

	var host_normal := _make_button_style(Color(0.110, 0.059, 0.059), C_CRIMSON, 0.55)
	var host_hover  := _make_button_style(Color(0.145, 0.075, 0.075), C_CRIMSON_BR, 0.85)
	var host_press  := _make_button_style(Color(0.082, 0.041, 0.041), C_CRIMSON, 1.0)
	host_button.add_theme_stylebox_override("normal",  host_normal)
	host_button.add_theme_stylebox_override("hover",   host_hover)
	host_button.add_theme_stylebox_override("pressed", host_press)
	host_button.add_theme_color_override("font_color",         Color(0.878, 0.600, 0.600))
	host_button.add_theme_color_override("font_hover_color",   Color(0.941, 0.706, 0.706))
	host_button.add_theme_color_override("font_pressed_color", Color(0.800, 0.500, 0.500))

	var help_normal := StyleBoxFlat.new()
	help_normal.bg_color = Color(0.063, 0.082, 0.149, 0.85)
	help_normal.border_color = Color(C_GOLD, 0.35)
	help_normal.set_border_width_all(1)
	help_normal.set_corner_radius_all(24)
	var help_hover := help_normal.duplicate() as StyleBoxFlat
	help_hover.border_color = Color(C_GOLD, 0.75)
	help_hover.bg_color = Color(0.090, 0.110, 0.200, 0.90)
	help_button.add_theme_stylebox_override("normal",  help_normal)
	help_button.add_theme_stylebox_override("hover",   help_hover)
	help_button.add_theme_stylebox_override("pressed", help_normal)
	help_button.add_theme_color_override("font_color",       C_GOLD_DIM)
	help_button.add_theme_color_override("font_hover_color", C_GOLD_GLOW)

	var world_normal := _make_button_style(Color(0.04, 0.10, 0.08), Color(0.3, 0.65, 0.45), 0.5)
	var world_hover  := _make_button_style(Color(0.06, 0.14, 0.11), Color(0.4, 0.85, 0.60), 0.85)
	var world_press  := _make_button_style(Color(0.03, 0.08, 0.06), Color(0.3, 0.65, 0.45), 1.0)
	world_button.add_theme_stylebox_override("normal",  world_normal)
	world_button.add_theme_stylebox_override("hover",   world_hover)
	world_button.add_theme_stylebox_override("pressed", world_press)
	world_button.add_theme_color_override("font_color",         Color(0.45, 0.80, 0.60))
	world_button.add_theme_color_override("font_hover_color",   Color(0.60, 1.00, 0.78))
	world_button.add_theme_color_override("font_pressed_color", Color(0.40, 0.70, 0.55))

	var db_normal := _make_button_style(Color(0.08, 0.06, 0.03), C_GOLD, 0.45)
	var db_hover  := _make_button_style(Color(0.12, 0.09, 0.04), C_GOLD_GLOW, 0.80)
	var db_press  := _make_button_style(Color(0.06, 0.04, 0.02), C_GOLD, 1.0)
	deck_builder_button.add_theme_stylebox_override("normal",  db_normal)
	deck_builder_button.add_theme_stylebox_override("hover",   db_hover)
	deck_builder_button.add_theme_stylebox_override("pressed", db_press)
	deck_builder_button.add_theme_color_override("font_color",         C_GOLD_DIM)
	deck_builder_button.add_theme_color_override("font_hover_color",   C_GOLD_GLOW)
	deck_builder_button.add_theme_color_override("font_pressed_color", C_GOLD)

	var bs_normal := _make_button_style(Color(0.10, 0.07, 0.02), C_GOLD, 0.50)
	var bs_hover  := _make_button_style(Color(0.16, 0.11, 0.03), C_GOLD_GLOW, 0.85)
	var bs_press  := _make_button_style(Color(0.07, 0.05, 0.01), C_GOLD, 1.0)
	booster_shop_button.add_theme_stylebox_override("normal",  bs_normal)
	booster_shop_button.add_theme_stylebox_override("hover",   bs_hover)
	booster_shop_button.add_theme_stylebox_override("pressed", bs_press)
	booster_shop_button.add_theme_color_override("font_color",         C_GOLD_DIM)
	booster_shop_button.add_theme_color_override("font_hover_color",   C_GOLD_GLOW)
	booster_shop_button.add_theme_color_override("font_pressed_color", C_GOLD)

	var input_normal := StyleBoxFlat.new()
	input_normal.bg_color = Color(0.031, 0.043, 0.110, 0.75)
	input_normal.border_color = Color(C_GOLD, 0.25)
	input_normal.set_border_width_all(1)
	input_normal.set_corner_radius_all(0)
	input_normal.set_content_margin_all(12.0)
	var input_focus := input_normal.duplicate() as StyleBoxFlat
	input_focus.border_color = Color(C_GOLD, 0.65)
	input_focus.bg_color = Color(0.039, 0.055, 0.129, 0.85)
	address_input.add_theme_stylebox_override("normal", input_normal)
	address_input.add_theme_stylebox_override("focus",  input_focus)
	address_input.add_theme_color_override("font_color",             C_PARCHMENT)
	address_input.add_theme_color_override("font_placeholder_color", Color(C_PARCHMENT_D, 0.45))
	address_input.add_theme_color_override("caret_color",            C_GOLD)
	address_input.add_theme_color_override("selection_color",        Color(C_GOLD, 0.28))

	toast_label.modulate.a = 0.0


func _make_button_style(bg: Color, border: Color, border_alpha: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(border, border_alpha)
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	s.set_content_margin(SIDE_LEFT,   24.0)
	s.set_content_margin(SIDE_RIGHT,  24.0)
	s.set_content_margin(SIDE_TOP,    16.0)
	s.set_content_margin(SIDE_BOTTOM, 16.0)
	return s


# ── Particles ──────────────────────────────────────────────────────────────────
func _setup_particles() -> void:
	particles.position = get_viewport_rect().size * Vector2(0.5, 1.05)
	particles.emitting = true
	particles.amount = 32
	particles.lifetime = 12.0
	particles.spread = 180.0
	particles.direction = Vector2(0.0, -1.0)
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 80.0
	particles.gravity = Vector2(0.0, -8.0)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 4.0
	particles.color = C_GOLD_GLOW
	var grad := Gradient.new()
	grad.set_color(0, Color(C_GOLD_GLOW, 0.0))
	grad.add_point(0.1,  Color(C_GOLD_GLOW, 0.8))
	grad.add_point(0.85, Color(C_CRIMSON_BR, 0.4))
	grad.add_point(1.0,  Color(C_CRIMSON_BR, 0.0))
	particles.color_ramp = grad


# ── Entrance animation ─────────────────────────────────────────────────────────
func _animate_entrance() -> void:
	title_block.modulate.a     = 0.0
	panel_container.modulate.a = 0.0

	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(title_block,     "modulate:a", 1.0, 1.0).set_delay(0.1)
	tween.tween_property(panel_container, "modulate:a", 1.0, 1.1).set_delay(0.35)


# ── Signal connections ─────────────────────────────────────────────────────────
func _connect_signals() -> void:
	join_button.pressed.connect(_on_join_pressed)
	host_button.pressed.connect(_on_host_pressed)
	help_button.pressed.connect(_on_help_pressed)
	world_button.pressed.connect(_on_world_pressed)
	deck_builder_button.pressed.connect(_on_deck_builder_pressed)
	booster_shop_button.pressed.connect(_on_booster_shop_pressed)
	address_input.text_submitted.connect(_on_address_submitted)
	%HelpCloseButton.pressed.connect(func(): help_dialog.hide())
	%HelpDialog.get_node("DimBG").gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			help_dialog.hide()
	)


# ── Button handlers ────────────────────────────────────────────────────────────
func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_server(PORT)
	if err != OK:
		_show_toast("✦  Erro ao criar sala: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	NetworkState.local_player_index = 0
	_set_buttons_enabled(false)
	_show_toast("✦  Sala criada… aguardando adversário")

func _on_join_pressed() -> void:
	var addr := address_input.text.strip_edges()
	if addr.is_empty():
		_show_toast("✦  Insira o endereço IP do hospedeiro")
		return
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_client(addr, PORT)
	if err != OK:
		_show_toast("✦  Erro ao conectar: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	NetworkState.local_player_index = 1
	_set_buttons_enabled(false)
	_show_toast("✦  Conectando a %s…" % addr)

func _on_help_pressed() -> void:
	help_dialog.show()

func _on_address_submitted(_text: String) -> void:
	_on_join_pressed()

func _on_world_pressed() -> void:
	if not CharacterStore.has_character():
		_show_no_character_dialog()
		return
	get_tree().change_scene_to_file(WORLD_CONNECT_SCENE)

func _on_deck_builder_pressed() -> void:
	get_tree().change_scene_to_file(DECK_BUILDER_SCENE)

func _on_booster_shop_pressed() -> void:
	get_tree().change_scene_to_file(BOOSTER_SHOP_SCENE)


# ── Callbacks de rede ──────────────────────────────────────────────────────────
func _on_peer_connected(_id: int) -> void:
	await get_tree().process_frame
	_start_game.rpc()

func _on_peer_disconnected(_id: int) -> void:
	_set_buttons_enabled(true)
	_show_toast("✦  Conexão encerrada")

func _on_connected_to_server() -> void:
	pass

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	_set_buttons_enabled(true)
	_show_toast("✦  Falha ao conectar — verifique o IP")


# ── Início de partida ──────────────────────────────────────────────────────────
func _start_music() -> void:
	var stream := load("res://audio/theme/lobby_theme.mp3") as AudioStreamMP3
	stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	add_child(_music)
	_music.play()

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	_music.stop()
	# Partida via lobby (LAN 1×1): ao terminar volta ao lobby, não ao mundo.
	NetworkState.match_origin_world = false
	get_tree().change_scene_to_file(BOARD_SCENE)


# ── Dialog: sem personagem ────────────────────────────────────────────────────
func _show_no_character_dialog() -> void:
	# Remove dialog anterior se existir
	var old := get_node_or_null("NoCharacterDialog")
	if old:
		old.queue_free()

	# Overlay escuro
	var overlay := ColorRect.new()
	overlay.name = "NoCharacterDialog"
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Painel central
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color     = Color(0.063, 0.082, 0.149, 0.97)
	panel_style.border_color = Color(C_GOLD, 0.40)
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(36)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Ícone + Título
	var title := Label.new()
	title.text = "Personagem não encontrado"
	title.add_theme_color_override("font_color", C_GOLD)
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Descrição
	var desc := Label.new()
	desc.text = "Você ainda não criou seu personagem para o\nmundo aberto. Crie agora para explorar!"
	desc.add_theme_color_override("font_color", C_PARCHMENT_D)
	desc.add_theme_font_size_override("font_size", 13)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Botões
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.custom_minimum_size = Vector2(140, 40)
	cancel_btn.add_theme_color_override("font_color", C_PARCHMENT_D)
	cancel_btn.pressed.connect(func() -> void: overlay.queue_free())
	btn_row.add_child(cancel_btn)

	var create_btn := Button.new()
	create_btn.text = "✦ CRIAR PERSONAGEM"
	create_btn.custom_minimum_size = Vector2(200, 40)
	create_btn.add_theme_color_override("font_color", C_GOLD_GLOW)
	create_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(CHARACTER_CREATOR_SCENE)
	)
	btn_row.add_child(create_btn)

	center.add_child(panel)

	# Fecha ao clicar fora do painel
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if not panel.get_global_rect().has_point(event.global_position):
				overlay.queue_free()
	)

	# Animação de entrada
	overlay.modulate.a = 0.0
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.25)

# ── Helpers ────────────────────────────────────────────────────────────────────
func _set_buttons_enabled(value: bool) -> void:
	host_button.disabled   = not value
	join_button.disabled   = not value
	address_input.editable = value

func _show_toast(msg: String) -> void:
	toast_label.text = msg
	if _toast_tween:
		_toast_tween.kill()
	toast_label.modulate.a = 0.0
	_toast_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)
