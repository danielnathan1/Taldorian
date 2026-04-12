class_name Lobby
extends Control

const PORT := 7000
const BOARD_SCENE := "res://scenes/ui/board/board.tscn"

@onready var tittle_label    := $VBoxContainer/TittleLabel
@onready var btn_host    := $VBoxContainer/BtnHost
@onready var btn_join    := $VBoxContainer/HBoxContainer/BtnJoin
@onready var ip_input    := $VBoxContainer/HBoxContainer/IpInput
@onready var status      := $VBoxContainer/StatusLabel

func _ready() -> void:
	tittle_label.text = "LOBBY"
	ip_input.text             = "127.0.0.1"
	ip_input.placeholder_text = "IP do servidor"
	status.text               = ""

	# conecta os botões
	btn_host.pressed.connect(_on_btn_host_pressed)
	btn_join.pressed.connect(_on_btn_join_pressed)

	# conecta callbacks de rede
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

# ── ações do jogador ─────────────────────────────────────

func _on_btn_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT)
	if err != OK:
		_set_status("Erro ao criar servidor: %d" % err)
		return

	multiplayer.multiplayer_peer = peer
	NetworkState.local_player_index = 0
	_set_status("Aguardando jogador 2... (porta %d)" % PORT)
	_set_buttons_enabled(false)

func _on_btn_join_pressed() -> void:
	var ip: String = ip_input.text.strip_edges()
	if ip == "":
		_set_status("Digite o IP do servidor.")
		return

	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_client(ip, PORT)
	if err != OK:
		_set_status("Erro ao conectar: %d" % err)
		return

	multiplayer.multiplayer_peer = peer
	NetworkState.local_player_index = 1
	_set_status("Conectando em %s..." % ip)
	_set_buttons_enabled(false)

# ── callbacks de rede ────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	# só o servidor recebe isso
	_set_status("Jogador conectado (id %d). Iniciando partida..." % id)
	# aguarda um frame pra garantir que o cliente também processou
	await get_tree().process_frame
	_start_game.rpc()

func _on_peer_disconnected(id: int) -> void:
	_set_status("Jogador desconectado (id %d)." % id)
	_set_buttons_enabled(true)

func _on_connected_to_server() -> void:
	_set_status("Conectado! Aguardando início...")

func _on_connection_failed() -> void:
	_set_status("Falha na conexão. Verifique o IP e tente novamente.")
	multiplayer.multiplayer_peer = null
	_set_buttons_enabled(true)

# ── início de partida ────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	get_tree().change_scene_to_file(BOARD_SCENE)

# ── helpers ──────────────────────────────────────────────

func _set_status(msg: String) -> void:
	status.text = msg

func _set_buttons_enabled(value: bool) -> void:
	btn_host.disabled = !value
	btn_join.disabled = !value
	ip_input.editable = value
