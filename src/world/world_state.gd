# src/world/world_state.gd
# Autoload — autoridade do estado do mundo. Roda em todos os peers.
# Somente o servidor (host) processa RPCs de movimento e chat.
extends Node

var _active: bool = false

# peer_id (int) → { tile: Vector2i, map: String, player_name: String }
var _players: Dictionary = {}

# ── Ativação ───────────────────────────────────────────────────────────────────

func activate() -> void:
	if _active:
		return
	_active = true
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if multiplayer.is_server():
		var id := multiplayer.get_unique_id()
		_players[id] = {
			"tile": Vector2i(5, 5),
			"map": "floresta_inicial",
			"player_name": NetworkState.player_name
		}
		_sync_world.rpc(_players.duplicate(true))
		GameBus.world_player_joined.emit(id, _players[id])
	else:
		rpc_id(1, "_rpc_enter_world", NetworkState.player_name)

# ── API pública ────────────────────────────────────────────────────────────────

func get_players() -> Dictionary:
	return _players

func request_move(dir: Vector2i) -> void:
	if multiplayer.is_server():
		_process_move(multiplayer.get_unique_id(), dir)
	else:
		rpc_id(1, "_rpc_move", dir)

func request_chat(message: String) -> void:
	rpc_id(1, "_rpc_chat", message.left(128))

# ── Callbacks internos ─────────────────────────────────────────────────────────

func _on_peer_disconnected(peer_id: int) -> void:
	if not _active or not multiplayer.is_server():
		return
	_players.erase(peer_id)
	_sync_world.rpc(_players.duplicate(true))
	_notify_left.rpc(peer_id)

func _process_move(peer_id: int, dir: Vector2i) -> void:
	if not _players.has(peer_id):
		return
	var new_tile: Vector2i = _players[peer_id]["tile"] + dir
	if new_tile.x < 1 or new_tile.x >= 39 or new_tile.y < 1 or new_tile.y >= 29:
		return
	_players[peer_id]["tile"] = new_tile
	_sync_world.rpc(_players.duplicate(true))

# ── RPCs recebidos pelo servidor ───────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func _rpc_enter_world(player_name: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_players[sender_id] = {
		"tile": Vector2i(5, 5),
		"map": "floresta_inicial",
		"player_name": player_name.left(32)
	}
	_sync_world.rpc(_players.duplicate(true))
	GameBus.world_player_joined.emit(sender_id, _players[sender_id])

@rpc("any_peer", "call_remote", "reliable")
func _rpc_move(dir: Vector2i) -> void:
	_process_move(multiplayer.get_remote_sender_id(), dir)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_chat(message: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_notify_chat.rpc(sender_id, message)

# ── RPCs enviados pelo servidor para todos ─────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _sync_world(state: Dictionary) -> void:
	_players = state
	GameBus.world_state_synced.emit(_players)

@rpc("authority", "call_local", "reliable")
func _notify_left(peer_id: int) -> void:
	GameBus.world_player_left.emit(peer_id)

@rpc("authority", "call_local", "reliable")
func _notify_chat(peer_id: int, message: String) -> void:
	GameBus.world_chat_received.emit(peer_id, message)
