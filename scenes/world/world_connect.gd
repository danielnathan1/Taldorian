# scenes/world/world_connect.gd
# Tela de conexão ao servidor do mundo — independente do lobby do TCG.
extends Control

const WORLD_PORT  := 7001
const LOBBY_SCENE := "res://scenes/ui/lobby/lobby.tscn"
const WORLD_SCENE := "res://scenes/world/world_root.tscn"

@onready var ip_input      : LineEdit = %IpInput
@onready var connect_button: Button   = %ConnectButton
@onready var back_button   : Button   = %BackButton
@onready var status_label  : Label    = %StatusLabel

func _ready() -> void:
	ip_input.text = "127.0.0.1"
	connect_button.pressed.connect(_on_connect_pressed)
	back_button.pressed.connect(_on_back_pressed)
	ip_input.text_submitted.connect(_on_connect_pressed.unbind(1))
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)

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
	_set_status("Conectando a %s:%d…" % [addr, WORLD_PORT])
	connect_button.disabled = true
	back_button.disabled    = true

func _on_connected() -> void:
	_set_status("Conectado! Entrando no mundo…")
	get_tree().change_scene_to_file(WORLD_SCENE)

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connect_button.disabled = false
	back_button.disabled    = false
	_set_status("Falha ao conectar — servidor offline ou IP errado")

func _on_back_pressed() -> void:
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _set_status(msg: String) -> void:
	status_label.text = msg
