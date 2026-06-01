# src/world/room_service.gd  (autoload: RoomService)
# Salas de batalha — AUTORIDADE NO SERVIDOR (Modelo A).
#
# O servidor do mundo mantém a lista real de salas e seus ocupantes. Clientes
# enviam intenções (criar/entrar/aleatório) via rpc_id(1, ...) e recebem a lista
# por broadcast. Quando uma sala enche (2 jogadores), o servidor inicia a partida
# pelo MatchService, reusando o GameState — sem nova conexão.
#
# A senha de uma sala fica SÓ no servidor; ao cliente só viaja `locked: bool`.
# Ver docs/roadmap-beta.md e memory project_network_model.
extends Node

signal rooms_updated(rooms: Array)            # Array[RoomInfo] — cliente e servidor
signal room_created(room: RoomInfo)           # emitido no criador, após o servidor confirmar
signal join_result(success: bool, msg: String)
signal ranked_queue_changed(in_queue: bool)

# Lista local de salas (no servidor é a autoritativa; no cliente é a cópia sincronizada).
var rooms: Array[RoomInfo] = []
var in_ranked_queue: bool = false

# ── Estado exclusivo do servidor ─────────────────────────────────────────────
var _next_id: int = 1000
var _passwords: Dictionary = {}   # id:int -> password:String  (nunca enviado ao cliente)
var _occupants: Dictionary = {}   # id:int -> Array[int] (peer_ids na sala)


func _ready() -> void:
	# Servidor limpa salas de um jogador que cai.
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


# ════════════════════════════════════════════════════════════════════════════
#  API DO CLIENTE (chamada pela UI room_lobby)
# ════════════════════════════════════════════════════════════════════════════

func refresh() -> void:
	if multiplayer.is_server():
		rooms_updated.emit(rooms)
	elif multiplayer.multiplayer_peer != null:
		rpc_id(1, "_rpc_request_rooms")

func create_room(p_name: String, p_type: String, p_locked: bool, p_password: String) -> void:
	if multiplayer.is_server():
		_srv_create_room(_self_peer(), p_name, p_type, p_locked, p_password)
	else:
		rpc_id(1, "_rpc_create_room", p_name, p_type, p_locked, p_password)

func join_room(p_id: int, p_password: String = "") -> void:
	if multiplayer.is_server():
		_srv_join_room(_self_peer(), p_id, p_password)
	else:
		rpc_id(1, "_rpc_join_room", p_id, p_password)

func join_random() -> void:
	if multiplayer.is_server():
		_srv_join_random(_self_peer())
	else:
		rpc_id(1, "_rpc_join_random")

func get_room(p_id: int) -> RoomInfo:
	for r in rooms:
		if r.id == p_id:
			return r
	return null


# ════════════════════════════════════════════════════════════════════════════
#  RPCs RECEBIDOS PELO SERVIDOR
# ════════════════════════════════════════════════════════════════════════════

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_rooms() -> void:
	if not multiplayer.is_server():
		return
	_sync_rooms.rpc_id(multiplayer.get_remote_sender_id(), _serialize_rooms())

@rpc("any_peer", "call_remote", "reliable")
func _rpc_create_room(p_name: String, p_type: String, p_locked: bool, p_password: String) -> void:
	if not multiplayer.is_server():
		return
	_srv_create_room(multiplayer.get_remote_sender_id(), p_name, p_type, p_locked, p_password)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_join_room(p_id: int, p_password: String) -> void:
	if not multiplayer.is_server():
		return
	_srv_join_room(multiplayer.get_remote_sender_id(), p_id, p_password)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_join_random() -> void:
	if not multiplayer.is_server():
		return
	_srv_join_random(multiplayer.get_remote_sender_id())


# ════════════════════════════════════════════════════════════════════════════
#  LÓGICA DO SERVIDOR
# ════════════════════════════════════════════════════════════════════════════

func _srv_create_room(p_creator: int, p_name: String, p_type: String, p_locked: bool, p_password: String) -> void:
	# Um jogador só pode estar em uma sala por vez: remove de qualquer outra antes.
	_remove_peer_from_rooms(p_creator, false)

	var room := RoomInfo.new()
	room.id        = _next_id
	_next_id      += 1
	room.room_name = p_name.strip_edges().left(32)
	if room.room_name.is_empty():
		room.room_name = "Sala #%d" % room.id
	room.game_type = p_type
	room.players   = 1
	room.capacity  = 2
	room.locked    = p_locked
	if p_locked:
		_passwords[room.id] = p_password
	_occupants[room.id] = [p_creator]
	rooms.push_front(room)

	_broadcast_rooms()
	_notify_room_created(p_creator, room.id)

func _srv_join_room(p_joiner: int, p_id: int, p_password: String) -> void:
	var room := get_room(p_id)
	if room == null:
		_notify_join_result(p_joiner, false, "Sala não encontrada")
		return
	if room.is_full():
		_notify_join_result(p_joiner, false, "Sala cheia")
		return
	if room.locked and str(_passwords.get(room.id, "")) != p_password:
		_notify_join_result(p_joiner, false, "Senha incorreta")
		return

	var occ: Array = _occupants.get(room.id, [])
	if p_joiner in occ:
		_notify_join_result(p_joiner, false, "Você já está nesta sala")
		return

	# Sai de qualquer outra sala antes de entrar nesta.
	_remove_peer_from_rooms(p_joiner, false)

	occ = _occupants.get(room.id, [])
	occ.append(p_joiner)
	_occupants[room.id] = occ
	room.players = occ.size()

	_notify_join_result(p_joiner, true, "Entrando na sala #%d…" % room.id)
	_broadcast_rooms()

	if occ.size() >= room.capacity:
		_begin_room_match(room.id)

func _srv_join_random(p_joiner: int) -> void:
	for room in rooms:
		if not room.is_full() and not room.locked and not (p_joiner in _occupants.get(room.id, [])):
			_srv_join_room(p_joiner, room.id, "")
			return
	_notify_join_result(p_joiner, false, "Nenhuma sala disponível")

func _begin_room_match(p_id: int) -> void:
	var occ: Array = _occupants.get(p_id, [])
	if occ.size() < 2:
		return
	var a: int = occ[0]
	var b: int = occ[1]
	_destroy_room(p_id)          # a sala vira partida; some da lista
	_broadcast_rooms()
	MatchService.begin_match_between(a, b)


# ── Limpeza ──────────────────────────────────────────────────────────────────

func _on_peer_disconnected(p_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _remove_peer_from_rooms(p_peer_id, true):
		_broadcast_rooms()

# Remove um peer de qualquer sala. Salas que ficarem vazias são destruídas.
# Retorna true se algo mudou. Se p_broadcast=false, o chamador faz o broadcast.
func _remove_peer_from_rooms(p_peer_id: int, _p_broadcast: bool) -> bool:
	var changed := false
	for id in _occupants.keys():
		var occ: Array = _occupants[id]
		if p_peer_id in occ:
			occ.erase(p_peer_id)
			_occupants[id] = occ
			changed = true
			var room := get_room(id)
			if occ.is_empty():
				_destroy_room(id)
			elif room != null:
				room.players = occ.size()
	return changed

func _destroy_room(p_id: int) -> void:
	_occupants.erase(p_id)
	_passwords.erase(p_id)
	for i in range(rooms.size() - 1, -1, -1):
		if rooms[i].id == p_id:
			rooms.remove_at(i)


# ════════════════════════════════════════════════════════════════════════════
#  SYNC SERVIDOR → CLIENTES
# ════════════════════════════════════════════════════════════════════════════

func _broadcast_rooms() -> void:
	var data := _serialize_rooms()
	_sync_rooms.rpc(data)         # call_remote: só clientes
	rooms_updated.emit(rooms)     # servidor atualiza a si mesmo

func _serialize_rooms() -> Array:
	var out: Array = []
	for r: RoomInfo in rooms:
		out.append(r.to_dict())
	return out

func _notify_room_created(p_peer: int, p_id: int) -> void:
	if p_peer <= 1:
		var room := get_room(p_id)
		if room != null:
			room_created.emit(room)
	else:
		_rpc_room_created.rpc_id(p_peer, p_id)

func _notify_join_result(p_peer: int, p_success: bool, p_msg: String) -> void:
	if p_peer <= 1:
		join_result.emit(p_success, p_msg)
	else:
		_rpc_join_result.rpc_id(p_peer, p_success, p_msg)

@rpc("authority", "call_remote", "reliable")
func _sync_rooms(p_data: Array) -> void:
	rooms.clear()
	for d in p_data:
		rooms.append(RoomInfo.from_dict(d))
	rooms_updated.emit(rooms)

@rpc("authority", "call_remote", "reliable")
func _rpc_room_created(p_id: int) -> void:
	var room := get_room(p_id)
	if room != null:
		room_created.emit(room)

@rpc("authority", "call_remote", "reliable")
func _rpc_join_result(p_success: bool, p_msg: String) -> void:
	join_result.emit(p_success, p_msg)


# ── Fila rankeada (ainda mock — fora do escopo da criação de sala) ────────────
func enter_ranked_queue() -> void:
	in_ranked_queue = true
	ranked_queue_changed.emit(true)

func leave_ranked_queue() -> void:
	in_ranked_queue = false
	ranked_queue_changed.emit(false)


# ── Util ──────────────────────────────────────────────────────────────────────
func _self_peer() -> int:
	# Host-como-jogador: a chamada local não passa por get_remote_sender_id.
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1
