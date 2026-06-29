# scenes/world/ui/player_context_menu/player_context_menu.gd
# Modal social que aparece ao lado de outro jogador (clique direito no mundo).
# Só exibe as opções e emite o id selecionado — sem lógica de jogo aqui.
extends PanelContainer

signal option_selected(option_id: String)
signal closed

const SCREEN_MARGIN := 8.0

@onready var _name_label  : Label  = $Margin/VBox/Header/NameLabel
@onready var _close_button: Button = $Margin/VBox/Header/CloseButton
@onready var _btn_details : Button = $Margin/VBox/BtnDetails
@onready var _btn_friend  : Button = $Margin/VBox/BtnFriend
@onready var _btn_trade   : Button = $Margin/VBox/BtnTrade
@onready var _btn_report  : Button = $Margin/VBox/BtnReport

func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)
	_btn_details.pressed.connect(func() -> void: _emit_option("details"))
	_btn_friend.pressed.connect(func() -> void: _emit_option("friend"))
	_btn_trade.pressed.connect(func() -> void: _emit_option("trade"))
	_btn_report.pressed.connect(func() -> void: _emit_option("report"))

# Abre o modal exibindo p_player_name, posicionado ao lado de p_screen_pos
# (coordenadas de tela do jogador clicado).
func open_for(p_player_name: String, p_screen_pos: Vector2) -> void:
	_name_label.text = p_player_name
	visible = true
	# Aguarda um frame para que o container calcule seu tamanho antes de posicionar.
	await get_tree().process_frame
	_place_beside(p_screen_pos)

func close() -> void:
	visible = false
	closed.emit()

# ── Interno ──────────────────────────────────────────────────────────────────────

func _place_beside(p_screen_pos: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	# Posiciona à direita do jogador; mantém dentro da tela.
	var pos := p_screen_pos + Vector2(12.0, -size.y * 0.5)
	pos.x = clampf(pos.x, SCREEN_MARGIN, viewport_size.x - size.x - SCREEN_MARGIN)
	pos.y = clampf(pos.y, SCREEN_MARGIN, viewport_size.y - size.y - SCREEN_MARGIN)
	position = pos

func _emit_option(p_option_id: String) -> void:
	option_selected.emit(p_option_id)
	close()

func _on_close_pressed() -> void:
	close()
