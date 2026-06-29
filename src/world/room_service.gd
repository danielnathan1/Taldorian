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

const MATCH_ROOM_SCENE := "res://scenes/ui/match_room/match_room.tscn"
const WORLD_SCENE      := "res://scenes/world/world_root.tscn"

# ── Estado exclusivo do servidor ─────────────────────────────────────────────
var _next_id: int = 1000
var _passwords: Dictionary = {}    # id:int -> password:String  (nunca enviado ao cliente)
var _occupants: Dictionary = {}    # id:int -> Array[int] (peer_ids na sala)
var _ready_state: Dictionary = {}  # id:int -> { peer_id:int -> bool }
var _counting_down: Dictionary = {} # id:int -> bool
var _peer_deck: Dictionary = {}    # peer_id:int -> nome do deck ativo

# Cliente: id da match room que acabou de entrar (lido pela cena MatchRoom).
var current_match_room_id: int = -1


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

func create_room(p_name: String, p_type: String, p_locked: bool, p_password: String, p_debug: bool = false) -> void:
	if multiplayer.is_server():
		_srv_create_room(_self_peer(), p_name, p_type, p_locked, p_password, p_debug)
	else:
		rpc_id(1, "_rpc_create_room", p_name, p_type, p_locked, p_password, p_debug)

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


# ── API da Match Room (sala de espera) ───────────────────────────────────────

## Cliente: alterna o "pronto" do jogador local.
func submit_ready(p_value: bool) -> void:
	if multiplayer.is_server():
		_srv_set_ready(_self_peer(), p_value)
	else:
		rpc_id(1, "_rpc_set_ready", p_value)

## Cliente: informa ao servidor o nome do seu deck ativo (exibido na Match Room).
func report_deck_name(p_name: String) -> void:
	if multiplayer.is_server():
		_peer_deck[_self_peer()] = p_name
		var rid := _room_of_peer(_self_peer())
		if rid != -1:
			_broadcast_room_detail(rid)
	else:
		rpc_id(1, "_rpc_set_deck_name", p_name)

## Cliente: sai da match room (volta ao mundo).
func request_leave_match_room() -> void:
	if multiplayer.is_server():
		_srv_leave_match_room(_self_peer())
	else:
		rpc_id(1, "_rpc_leave_match_room")

## Cliente: pede o detalhe atual da sala (chamado pela cena ao abrir, evita corrida).
func request_room_detail() -> void:
	if multiplayer.is_server():
		var rid := _room_of_peer(_self_peer())
		if rid != -1:
			GameBus.match_room_synced.emit(_build_room_detail(rid))
	elif multiplayer.multiplayer_peer != null:
		rpc_id(1, "_rpc_request_room_detail")


# ════════════════════════════════════════════════════════════════════════════
#  RPCs RECEBIDOS PELO SERVIDOR
# ════════════════════════════════════════════════════════════════════════════

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_rooms() -> void:
	if not multiplayer.is_server():
		return
	_sync_rooms.rpc_id(multiplayer.get_remote_sender_id(), _serialize_rooms())

@rpc("any_peer", "call_remote", "reliable")
func _rpc_create_room(p_name: String, p_type: String, p_locked: bool, p_password: String, p_debug: bool = false) -> void:
	if not multiplayer.is_server():
		return
	_srv_create_room(multiplayer.get_remote_sender_id(), p_name, p_type, p_locked, p_password, p_debug)

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

func _srv_create_room(p_creator: int, p_name: String, p_type: String, p_locked: bool, p_password: String, p_debug: bool = false) -> void:
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
	room.debug     = p_debug
	if p_locked:
		_passwords[room.id] = p_password
	_occupants[room.id] = [p_creator]
	_ready_state[room.id] = { p_creator: false }
	_counting_down[room.id] = false
	rooms.push_front(room)

	_broadcast_rooms()
	_notify_room_created(p_creator, room.id)
	# Criador vai direto pra sala de espera (Match Room), aguardando oponente.
	_send_to_match_room(p_creator, room.id)

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
	if not _ready_state.has(room.id):
		_ready_state[room.id] = {}
	_ready_state[room.id][p_joiner] = false
	room.players = occ.size()

	_notify_join_result(p_joiner, true, "Entrando na sala #%d…" % room.id)
	_broadcast_rooms()
	# Oponente entra na mesma sala de espera; ambos confirmam "pronto" para iniciar.
	_send_to_match_room(p_joiner, room.id)

func _srv_join_random(p_joiner: int) -> void:
	for room in rooms:
		if not room.is_full() and not room.locked and not (p_joiner in _occupants.get(room.id, [])):
			_srv_join_room(p_joiner, room.id, "")
			return
	_notify_join_result(p_joiner, false, "Nenhuma sala disponível")

# ── Match Room: ready-up, contagem e início ──────────────────────────────────

func _room_of_peer(p_peer: int) -> int:
	for id in _occupants:
		if p_peer in _occupants[id]:
			return id
	return -1

# Envia um peer para a cena da Match Room e (re)difunde o detalhe da sala.
func _send_to_match_room(p_peer: int, p_id: int) -> void:
	current_match_room_id = p_id
	if p_peer > 1:
		_rpc_enter_match_room.rpc_id(p_peer, p_id)
	_broadcast_room_detail(p_id)

func _srv_set_ready(p_peer: int, p_value: bool) -> void:
	var rid := _room_of_peer(p_peer)
	if rid == -1 or not _ready_state.has(rid):
		return
	_ready_state[rid][p_peer] = p_value
	_check_countdown(rid)

func _check_countdown(p_id: int) -> void:
	var occ: Array = _occupants.get(p_id, [])
	var both := occ.size() == 2 \
		and bool(_ready_state[p_id].get(occ[0], false)) \
		and bool(_ready_state[p_id].get(occ[1], false))
	_counting_down[p_id] = both
	_broadcast_room_detail(p_id)
	if both:
		get_tree().create_timer(3.0).timeout.connect(_on_countdown_done.bind(p_id), CONNECT_ONE_SHOT)

func _on_countdown_done(p_id: int) -> void:
	if not _occupants.has(p_id):
		return
	var occ: Array = _occupants[p_id]
	if occ.size() == 2 \
		and bool(_ready_state[p_id].get(occ[0], false)) \
		and bool(_ready_state[p_id].get(occ[1], false)):
		var a: int = occ[0]
		var b: int = occ[1]
		var room := get_room(p_id)
		var is_debug := room != null and room.debug
		_destroy_room(p_id)        # a sala vira partida; some da lista
		_broadcast_rooms()
		MatchService.begin_match_between(a, b, false, is_debug)

func _srv_leave_match_room(p_peer: int) -> void:
	var rid := _room_of_peer(p_peer)
	if rid == -1:
		return
	_remove_peer_from_rooms(p_peer, false)  # reseta ready + difunde detalhe ao que ficou
	_broadcast_rooms()
	if p_peer > 1:
		_rpc_match_room_exit.rpc_id(p_peer)

func _build_room_detail(p_id: int) -> Dictionary:
	var room := get_room(p_id)
	var occ: Array = _occupants.get(p_id, [])
	var ready: Dictionary = _ready_state.get(p_id, {})
	var players := WorldState.get_players()
	var seats: Array = []
	for i in 2:
		if i < occ.size():
			var peer: int = occ[i]
			var pname := "Jogador"
			var appearance: Dictionary = {}
			if players.has(peer):
				pname = str(players[peer].get("player_name", "Jogador"))
				appearance = players[peer].get("appearance", {})
			seats.append({
				"peer":       peer,
				"name":       pname,
				"deck":       str(_peer_deck.get(peer, "")),
				"ready":      bool(ready.get(peer, false)),
				"is_host":    i == 0,
				"appearance": appearance,
			})
		else:
			seats.append(null)
	return {
		"room_id":       p_id,
		"room_name":     (room.room_name if room != null else ""),
		"game_type":     (room.game_type if room != null else RoomInfo.TYPE_CLASSICO),
		"counting_down": bool(_counting_down.get(p_id, false)),
		"seats":         seats,
	}

func _broadcast_room_detail(p_id: int) -> void:
	var detail := _build_room_detail(p_id)
	for peer in _occupants.get(p_id, []):
		if peer > 1:
			_rpc_sync_room_detail.rpc_id(peer, detail)
		else:
			GameBus.match_room_synced.emit(detail)


# ── RPCs da Match Room recebidos pelo servidor ───────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_ready(p_value: bool) -> void:
	if not multiplayer.is_server():
		return
	_srv_set_ready(multiplayer.get_remote_sender_id(), p_value)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_leave_match_room() -> void:
	if not multiplayer.is_server():
		return
	_srv_leave_match_room(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_deck_name(p_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_peer_deck[sender] = p_name.left(40)
	var rid := _room_of_peer(sender)
	if rid != -1:
		_broadcast_room_detail(rid)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_room_detail() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var rid := _room_of_peer(sender)
	if rid != -1:
		_rpc_sync_room_detail.rpc_id(sender, _build_room_detail(rid))


# ── RPCs da Match Room enviados pelo servidor ao cliente ─────────────────────

@rpc("authority", "call_remote", "reliable")
func _rpc_enter_match_room(p_room_id: int) -> void:
	current_match_room_id = p_room_id
	get_tree().change_scene_to_file(MATCH_ROOM_SCENE)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_room_detail(p_detail: Dictionary) -> void:
	GameBus.match_room_synced.emit(p_detail)

@rpc("authority", "call_remote", "reliable")
func _rpc_match_room_exit() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


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
				# Oponente ficou sozinho: reseta prontos e avisa que está esperando de novo.
				if _ready_state.has(id):
					_ready_state[id].erase(p_peer_id)
					for p in occ:
						_ready_state[id][p] = false
				_counting_down[id] = false
				_broadcast_room_detail(id)
	return changed

func _destroy_room(p_id: int) -> void:
	_occupants.erase(p_id)
	_passwords.erase(p_id)
	_ready_state.erase(p_id)
	_counting_down.erase(p_id)
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


# ── Fila rankeada ─────────────────────────────────────────────────────────────
# Fase 0: pareamento FIFO real reusando a fila do MatchService (mesma usada pela
# fila rápida). Ainda SEM rating/MMR — isso entra na Fase 1 junto do backend real
# (ladder, seasons, reportar resultado server-to-server). Ver docs/roadmap-beta.md.
func enter_ranked_queue() -> void:
	_ensure_match_queue_link()
	MatchService.request_quick_match()

func leave_ranked_queue() -> void:
	MatchService.cancel_quick_match()

# Espelha o estado da fila do MatchService em `in_ranked_queue` e reemite o sinal
# que a UI escuta. Conectado de forma preguiçosa (em runtime o autoload já existe;
# no _ready do RoomService o MatchService ainda não foi registrado).
func _ensure_match_queue_link() -> void:
	if not MatchService.queue_state_changed.is_connected(_on_match_queue_changed):
		MatchService.queue_state_changed.connect(_on_match_queue_changed)

func _on_match_queue_changed(p_in_queue: bool) -> void:
	in_ranked_queue = p_in_queue
	ranked_queue_changed.emit(p_in_queue)


# ── Util ──────────────────────────────────────────────────────────────────────
func _self_peer() -> int:
	# Host-como-jogador: a chamada local não passa por get_remote_sender_id.
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1
