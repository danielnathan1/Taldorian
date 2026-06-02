# scenes/world/world_root.gd
extends Node2D

const LOBBY_SCENE         := "res://scenes/ui/lobby/lobby.tscn"
const REMOTE_PLAYER_SCENE := preload("res://scenes/world/player/remote_player.tscn")
const DECK_BUILDER_SCENE  := "res://scenes/ui/deck_builder/deck_builder.tscn"
const ROOM_LOBBY_SCENE    := preload("res://scenes/ui/room_lobby/room_lobby.tscn")
const PAUSE_MENU_SCENE    := preload("res://scenes/ui/pausemenu/PauseMenu.tscn")

var _room_lobby: Control = null
var _pause_menu: PauseMenu = null

@onready var map_container     : Node2D      = $MapContainer
@onready var players_container : Node2D      = $PlayersContainer
@onready var local_player      : CharacterBody2D = $PlayerCharacter
@onready var world_hud         : CanvasLayer = $WorldHUD

# peer_id (int) → RemotePlayer node
var _remote_players: Dictionary = {}

func _ready() -> void:
	# 1. Conecta sinais ANTES de qualquer ativação para não perder emits.
	GameBus.world_state_synced.connect(_on_world_state_synced)
	GameBus.world_player_left.connect(_on_player_left)
	GameBus.world_chat_received.connect(_on_world_chat_received)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# 2. Garante estado limpo (evita _active=true de sessão anterior).
	WorldState.reset()

	var appearance: Dictionary = {}
	if CharacterStore.has_character():
		appearance = CharacterStore.get_character()
		# Usa o nome do personagem como nome de rede (mundo, chat e Match Room).
		var char_name := str(appearance.get("name", "")).strip_edges()
		if char_name != "":
			NetworkState.player_name = char_name

	# 3. Ativa: servidor registra-se; cliente envia _rpc_enter_world ao servidor.
	WorldState.activate(appearance)

	# 4. Cliente pede re-sync explícito após um frame — garante que o servidor
	#    envie o estado completo mesmo que haja qualquer delay no processamento.
	if not multiplayer.is_server():
		_request_sync_deferred()

	_setup_hud()
	_load_map("taldorian_city")
	_setup_pause_menu()

func _setup_pause_menu() -> void:
	# Menu de pausa do mundo (ESC): volume + voltar ao menu. O próprio PauseMenu
	# trata o ESC (abre/fecha); por isso o world_root não intercepta mais a tecla.
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	_pause_menu.world_mode = true
	add_child(_pause_menu)
	_pause_menu.quit_to_menu_requested.connect(_return_to_lobby)

func _request_sync_deferred() -> void:
	await get_tree().process_frame
	if multiplayer.multiplayer_peer != null:
		WorldState._rpc_request_sync.rpc_id(1)

# ── HUD ────────────────────────────────────────────────────────────────────────

func _setup_hud() -> void:
	world_hud.set_player({
		"name":  NetworkState.player_name,
		"level": 1,
		"gold":  0,
		"rank":  "Bronze",
		"xp":    0.0,
	})
	world_hud.set_friends([
		{ "name": "Bromm",   "status": "on",   "status_text": "No mundo"   },
		{ "name": "Sayen",   "status": "on",   "status_text": "Em partida" },
		{ "name": "Mirae",   "status": "on",   "status_text": "No mundo"   },
		{ "name": "Korrin",  "status": "on",   "status_text": "Loja"       },
		{ "name": "Thalwen", "status": "idle", "status_text": "Ausente"    },
		{ "name": "Dorne",   "status": "off",  "status_text": "Offline · 2h" },
		{ "name": "Vael",    "status": "off",  "status_text": "Offline · 1d" },
	])
	world_hud.battle_requested.connect(_on_battle_requested)
	world_hud.logout_requested.connect(_return_to_lobby)
	world_hud.decks_requested.connect(func() -> void:
		get_tree().change_scene_to_file(DECK_BUILDER_SCENE)
	)

func _on_battle_requested() -> void:
	# Abre a tela de Salas de Batalha como overlay (sem trocar de cena, para
	# manter a conexão ENet do mundo viva — Modelo A).
	if _room_lobby != null and is_instance_valid(_room_lobby):
		return
	_room_lobby = ROOM_LOBBY_SCENE.instantiate()
	_room_lobby.closed.connect(func() -> void: _room_lobby = null)
	world_hud.add_child(_room_lobby)

# ── Mapa ───────────────────────────────────────────────────────────────────────

func _load_map(p_map_name: String) -> void:
	for child in map_container.get_children():
		child.queue_free()
	var scene := MapLoader.load_map(p_map_name)
	if scene == null:
		return
	var map_node := scene.instantiate()
	map_container.add_child(map_node)

# ── Sync de jogadores ──────────────────────────────────────────────────────────

func _on_world_state_synced(p_players: Dictionary) -> void:
	var local_id := multiplayer.get_unique_id()
	for peer_id: int in p_players:
		if peer_id == local_id:
			continue
		var data: Dictionary = p_players[peer_id]
		if not _remote_players.has(peer_id):
			_spawn_remote_player(peer_id, data)
		else:
			_remote_players[peer_id].set_target_tile(data["tile"])
			if data.has("appearance"):
				_remote_players[peer_id].set_appearance(data["appearance"])
	for peer_id: int in _remote_players.keys():
		if not p_players.has(peer_id):
			_despawn_remote_player(peer_id)

func _on_player_left(p_peer_id: int) -> void:
	_despawn_remote_player(p_peer_id)

func _on_peer_disconnected(_peer_id: int) -> void:
	if not multiplayer.is_server():
		_return_to_lobby()

func _on_world_chat_received(p_peer_id: int, _p_message: String) -> void:
	# Exibe bolha de chat no personagem remoto
	if _remote_players.has(p_peer_id):
		_remote_players[p_peer_id].show_chat(_p_message)

func _spawn_remote_player(p_peer_id: int, p_data: Dictionary) -> void:
	var rp: Node2D = REMOTE_PLAYER_SCENE.instantiate()
	players_container.add_child(rp)
	rp.setup(p_data["player_name"], p_data["tile"], p_data.get("appearance", {}))
	_remote_players[p_peer_id] = rp

func _despawn_remote_player(p_peer_id: int) -> void:
	if not _remote_players.has(p_peer_id):
		return
	_remote_players[p_peer_id].queue_free()
	_remote_players.erase(p_peer_id)

# ── Navegação ──────────────────────────────────────────────────────────────────

func _return_to_lobby() -> void:
	WorldState.reset()
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file(LOBBY_SCENE)
