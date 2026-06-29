# src/world/world_state.gd
# Autoload — autoridade do estado do mundo. Roda em todos os peers.
# Somente o servidor (host) processa RPCs de movimento e chat.
#
# Fluxo de sync:
#   Servidor chama _update_and_broadcast()
#     → atualiza _players localmente + emite world_state_synced no servidor
#     → envia _sync_world (call_remote) para TODOS os clientes
#   Clientes recebem _sync_world
#     → atualizam _players + emitem world_state_synced
#
# Sem "call_local" — a execução local do servidor é sempre explícita.
extends Node

var _active: bool = false

# peer_id (int) → { tile, map, player_name, appearance }
var _players: Dictionary = {}

# ── Ativação ───────────────────────────────────────────────────────────────────

func reset() -> void:
	_active  = false
	_players = {}

func activate(p_appearance: Dictionary = {}, p_as_player: bool = true) -> void:
	if _active:
		return
	_active = true

	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Servidor dedicado (p_as_player = false) é só autoridade: não vira jogador.
	if multiplayer.is_server() and not p_as_player:
		return

	if multiplayer.is_server():
		var id := multiplayer.get_unique_id()
		_players[id] = {
			"tile":        Vector2i(62, 34),
			"map":         "taldorian_city",
			"player_name": NetworkState.player_name,
			"player_id":   NetworkState.player_id,
			"appearance":  p_appearance,
		}
		# Atualiza local; nenhum cliente conectado ainda, mas emite o sinal
		# para que o servidor próprio veja seu estado inicial.
		_update_local(_players.duplicate(true))
		GameBus.world_player_joined.emit(id, _players[id])
	else:
		rpc_id(1, "_rpc_enter_world", NetworkState.player_name, p_appearance, NetworkState.player_id)

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

# ── Sync interno (só servidor chama) ──────────────────────────────────────────

# Atualiza o estado local do servidor E envia para todos os clientes.
func _update_and_broadcast() -> void:
	var state := _players.duplicate(true)
	_update_local(state)
	_sync_world.rpc(state)

# Atualiza apenas o estado local (sem envio de rede).
func _update_local(state: Dictionary) -> void:
	_players = state
	GameBus.world_state_synced.emit(_players)

# ── Callbacks internos ─────────────────────────────────────────────────────────

func _on_peer_disconnected(peer_id: int) -> void:
	if not _active or not multiplayer.is_server():
		return
	_players.erase(peer_id)
	_update_and_broadcast()
	_notify_left.rpc(peer_id)

func _process_move(peer_id: int, dir: Vector2i) -> void:
	if not _players.has(peer_id):
		return
	var new_tile: Vector2i = _players[peer_id]["tile"] + dir
	if new_tile.x < 1 or new_tile.x >= 200 or new_tile.y < 1 or new_tile.y >= 200:
		return
	_players[peer_id]["tile"] = new_tile
	_update_and_broadcast()

# ── RPCs recebidos pelo servidor ───────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func _rpc_enter_world(player_name: String, appearance: Dictionary, player_id: String = "") -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_players[sender_id] = {
		"tile":        Vector2i(62, 34),
		"map":         "taldorian_city",
		"player_name": player_name.left(32),
		"player_id":   player_id,
		"appearance":  appearance,
	}
	_update_and_broadcast()
	GameBus.world_player_joined.emit(sender_id, _players[sender_id])

@rpc("any_peer", "call_remote", "reliable")
func _rpc_move(dir: Vector2i) -> void:
	_process_move(multiplayer.get_remote_sender_id(), dir)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_chat(message: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_notify_chat.rpc(sender_id, message)

# Cliente pode pedir um re-sync explícito ao servidor.
# Útil para garantir que o estado correto chegue mesmo se um sync anterior
# foi perdido (ex: cena ainda não carregada).
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_sync() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_sync_world.rpc_id(sender_id, _players.duplicate(true))

# ── RPCs enviados pelo servidor para clientes (call_remote = sem execução local) ──

@rpc("authority", "call_remote", "reliable")
func _sync_world(state: Dictionary) -> void:
	_players = state
	GameBus.world_state_synced.emit(_players)

@rpc("authority", "call_remote", "reliable")
func _notify_left(peer_id: int) -> void:
	GameBus.world_player_left.emit(peer_id)

@rpc("authority", "call_remote", "reliable")
func _notify_chat(peer_id: int, message: String) -> void:
	GameBus.world_chat_received.emit(peer_id, message)
