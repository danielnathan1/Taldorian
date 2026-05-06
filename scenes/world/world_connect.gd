# scenes/world/world_connect.gd
extends Control

const WORLD_PORT  := 7001
const LOBBY_SCENE := "res://scenes/ui/lobby/lobby.tscn"
const WORLD_SCENE := "res://scenes/world/world_root.tscn"

@onready var ip_input       : LineEdit = %IpInput
@onready var host_button    : Button   = %HostButton
@onready var connect_button : Button   = %ConnectButton
@onready var back_button    : Button   = %BackButton
@onready var status_label   : Label    = %StatusLabel

func _ready() -> void:
	# Garante peer limpo ao entrar na tela de conexão do mundo
	multiplayer.multiplayer_peer = null
	ip_input.text = "127.0.0.1"
	host_button.pressed.connect(_on_host_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	back_button.pressed.connect(_on_back_pressed)
	ip_input.text_submitted.connect(_on_connect_pressed.unbind(1))
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_server(WORLD_PORT)
	if err != OK:
		_set_status("Erro ao criar servidor: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	NetworkState.local_player_index = 0
	WorldState.activate()
	_set_buttons_enabled(false)
	get_tree().change_scene_to_file(WORLD_SCENE)

func _on_connect_pressed() -> void:
	var addr := ip_input.text.strip_edges()
	if addr.is_empty():
		_set_status("Insira o IP do servidor do mundo")
		return
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_client(addr, WORLD_PORT)
	if err != OK:
		_set_status("Erro ao conectar: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	NetworkState.local_player_index = 1
	_set_buttons_enabled(false)
	_set_status("Conectando a %s…" % addr)

func _on_connected() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	_set_buttons_enabled(true)
	_set_status("Falha ao conectar — verifique o IP ou hospede uma sala")

func _on_back_pressed() -> void:
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _set_buttons_enabled(value: bool) -> void:
	host_button.disabled    = not value
	connect_button.disabled = not value
	back_button.disabled    = not value
	ip_input.editable       = value

func _set_status(msg: String) -> void:
	status_label.text = msg
