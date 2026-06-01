# src/world/match_service.gd  (autoload: MatchService)
# Orquestra o início de partidas no Modelo A: o servidor do mundo pareia dois
# clientes conectados e os envia para o board, reusando o GameState.
#
# Slice atual (Passo 1): UMA partida por vez, pareamento por fila rápida.
# O Passo 2 (multi-sala) generaliza para N partidas simultâneas com salas
# isoladas e sync direcionado. Ver docs/roadmap-beta.md e memory
# project_network_model.
extends Node

const BOARD_SCENE := "res://scenes/ui/boardv2/board.tscn"

## Emitido no cliente quando ele entra/sai da fila de pareamento.
signal queue_state_changed(in_queue: bool)

# Servidor: peers aguardando partida.
var _queue: Array[int] = []
# Cliente: true enquanto aguarda pareamento.
var _in_queue: bool = false


func _ready() -> void:
	# Limpa o peer da fila ao desconectar (servidor).
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


# ── API do cliente ───────────────────────────────────────────────────────────

func request_quick_match() -> void:
	if multiplayer.multiplayer_peer == null:
		push_warning("[MatchService] Sem conexão com o servidor do mundo.")
		return
	_in_queue = true
	queue_state_changed.emit(true)
	rpc_id(1, "_rpc_join_queue")

func cancel_quick_match() -> void:
	if not _in_queue:
		return
	_in_queue = false
	queue_state_changed.emit(false)
	rpc_id(1, "_rpc_leave_queue")

func is_in_queue() -> bool:
	return _in_queue


# ── Servidor: fila e pareamento ──────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func _rpc_join_queue() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender in _queue:
		return
	_queue.append(sender)
	if _queue.size() >= 2:
		var a: int = _queue.pop_front()
		var b: int = _queue.pop_front()
		begin_match_between(a, b)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_leave_queue() -> void:
	if not multiplayer.is_server():
		return
	_queue.erase(multiplayer.get_remote_sender_id())

func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		_queue.erase(peer_id)

## Inicia uma partida entre dois peers (servidor). Usado pela fila rápida e pelo
## RoomService quando uma sala enche. Define o mapeamento peer→player_index no
## GameState e envia cada cliente ao board com seu índice.
func begin_match_between(p_a: int, p_b: int) -> void:
	if not multiplayer.is_server():
		return
	# Registra uma partida isolada (sala) no servidor e roteia ambos ao board.
	GameState.register_match(p_a, p_b)
	_rpc_begin_match.rpc_id(p_a, 0)
	_rpc_begin_match.rpc_id(p_b, 1)


# ── Cliente: entra no board ──────────────────────────────────────────────────

@rpc("authority", "call_remote", "reliable")
func _rpc_begin_match(p_player_index: int) -> void:
	_in_queue = false
	queue_state_changed.emit(false)
	NetworkState.local_player_index = p_player_index
	# Partida veio do mundo: ao terminar, o jogador volta ao mundo (não ao lobby).
	NetworkState.match_origin_world = true
	get_tree().change_scene_to_file(BOARD_SCENE)
