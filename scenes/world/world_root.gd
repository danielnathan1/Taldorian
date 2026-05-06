# scenes/world/world_root.gd
extends Node2D

const LOBBY_SCENE         := "res://scenes/ui/lobby/lobby.tscn"
const REMOTE_PLAYER_SCENE := preload("res://scenes/world/player/remote_player.tscn")

@onready var map_container     : Node2D         = $MapContainer
@onready var players_container : Node2D         = $PlayersContainer
@onready var local_player      : CharacterBody2D = $PlayerCharacter
@onready var hud               : Control         = $HUD/HudWorld

# peer_id (int) → RemotePlayer node
var _remote_players: Dictionary = {}

func _ready() -> void:
	WorldState.activate()
	GameBus.world_state_synced.connect(_on_world_state_synced)
	GameBus.world_player_left.connect(_on_player_left)
	GameBus.world_chat_received.connect(_on_world_chat_received)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	hud.set_local_player(local_player)
	_load_map("taldorian_city")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_return_to_lobby()

# ── Mapa ───────────────────────────────────────────────────────────────────────

func _load_map(map_name: String) -> void:
	for child in map_container.get_children():
		child.queue_free()
	var scene := MapLoader.load_map(map_name)
	if scene == null:
		return
	var map_node := scene.instantiate()
	map_container.add_child(map_node)

# ── Sync de jogadores ──────────────────────────────────────────────────────────

func _on_world_state_synced(players: Dictionary) -> void:
	var local_id := multiplayer.get_unique_id()
	for peer_id: int in players:
		if peer_id == local_id:
			continue
		var data: Dictionary = players[peer_id]
		if not _remote_players.has(peer_id):
			_spawn_remote_player(peer_id, data)
		else:
			_remote_players[peer_id].set_target_tile(data["tile"])
	for peer_id: int in _remote_players.keys():
		if not players.has(peer_id):
			_despawn_remote_player(peer_id)

func _on_player_left(peer_id: int) -> void:
	_despawn_remote_player(peer_id)

func _on_peer_disconnected(_peer_id: int) -> void:
	if not multiplayer.is_server():
		_return_to_lobby()

func _on_world_chat_received(peer_id: int, message: String) -> void:
	if _remote_players.has(peer_id):
		_remote_players[peer_id].show_chat(message)

func _spawn_remote_player(peer_id: int, data: Dictionary) -> void:
	var rp: Node2D = REMOTE_PLAYER_SCENE.instantiate()
	players_container.add_child(rp)
	rp.setup(data["player_name"], data["tile"])
	_remote_players[peer_id] = rp

func _despawn_remote_player(peer_id: int) -> void:
	if not _remote_players.has(peer_id):
		return
	_remote_players[peer_id].queue_free()
	_remote_players.erase(peer_id)

# ── Navegação ──────────────────────────────────────────────────────────────────

func _return_to_lobby() -> void:
	WorldState.reset()
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file(LOBBY_SCENE)
