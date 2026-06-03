# scenes/ui/login/login.gd
# LÓGICA da tela de login (FAKE — aceita qualquer usuário/senha não-vazios).
# Ao entrar, conecta direto ao servidor do mundo (IP mockado por enquanto) e cai
# no open world — mesmo comportamento do antigo "Connect". A cena fica em
# login.tscn (editável no editor). Quando a API real existir, _on_enter chama o
# auth de verdade antes de conectar.
extends Control

const SETTINGS_PATH := "user://settings.cfg"
const WORLD_SCENE   := "res://scenes/world/world_root.tscn"
const SERVER_IP     := "127.0.0.1"   # MOCK — futuro: configurável / vindo da API
const WORLD_PORT    := 7001

@onready var _user_input: LineEdit = %UserInput
@onready var _pass_input: LineEdit = %PassInput
@onready var _error_lbl:  Label    = %ErrorLabel
@onready var _enter_btn:  Button   = %EnterButton


func _ready() -> void:
	if WorldServer.is_dedicated:
		return
	multiplayer.multiplayer_peer = null
	_user_input.text = _load_last_user()
	_error_lbl.visible = false
	_enter_btn.pressed.connect(_on_enter)
	_user_input.text_submitted.connect(func(_t: String) -> void: _pass_input.grab_focus())
	_pass_input.text_submitted.connect(func(_t: String) -> void: _on_enter())
	if _user_input.text.is_empty():
		_user_input.grab_focus()
	else:
		_pass_input.grab_focus()


func _on_enter() -> void:
	var user := _user_input.text.strip_edges()
	var pwd := _pass_input.text
	if user.is_empty() or pwd.is_empty():
		_show_error("Informe usuário e senha.")
		return
	NetworkState.account_name = user
	NetworkState.player_name = user   # nome no mundo (até ter personagem próprio)
	_save_user(user)
	_connect_to_world()


# ── Conexão com o mundo (IP mockado por enquanto) ────────────────────────────
func _connect_to_world() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(SERVER_IP, WORLD_PORT)
	if err != OK:
		_show_error("Falha ao iniciar a conexão (%d)." % err)
		return
	multiplayer.multiplayer_peer = peer
	NetworkState.local_player_index = 1
	if not multiplayer.connected_to_server.is_connected(_on_world_connected):
		multiplayer.connected_to_server.connect(_on_world_connected, CONNECT_ONE_SHOT)
	if not multiplayer.connection_failed.is_connected(_on_world_failed):
		multiplayer.connection_failed.connect(_on_world_failed, CONNECT_ONE_SHOT)
	_set_connecting(true)

func _on_world_connected() -> void:
	if multiplayer.connection_failed.is_connected(_on_world_failed):
		multiplayer.connection_failed.disconnect(_on_world_failed)
	get_tree().change_scene_to_file(WORLD_SCENE)

func _on_world_failed() -> void:
	if multiplayer.connected_to_server.is_connected(_on_world_connected):
		multiplayer.connected_to_server.disconnect(_on_world_connected)
	multiplayer.multiplayer_peer = null
	_set_connecting(false)
	_show_error("Não foi possível conectar ao servidor (%s)." % SERVER_IP)

func _set_connecting(p_on: bool) -> void:
	_enter_btn.disabled = p_on
	_enter_btn.text = "Conectando…" if p_on else "⚔  Entrar"

func _show_error(p_msg: String) -> void:
	_error_lbl.text = p_msg
	_error_lbl.visible = true


# ── Persistência ──────────────────────────────────────────────────────────────
func _load_last_user() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return str(cfg.get_value("account", "username", ""))
	return ""

func _save_user(p_user: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("account", "username", p_user)
	cfg.save(SETTINGS_PATH)
