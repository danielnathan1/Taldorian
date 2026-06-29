# src/world/world_trade.gd
# Autoload — negociação de troca entre dois jogadores no mundo aberto.
# Autoridade ÚNICA no servidor (host, peer_id = 1). Roda em todos os peers, mas só
# o servidor processa as intenções e transmite o estado para os dois envolvidos.
#
# Modelo:
#   - A "experiência" da troca (slots/ouro/aceite/reset 3s) vive aqui, em tempo real.
#   - A "verdade" (transferência de itens) é responsabilidade do BACKEND: quando ambos
#     aceitam, o SERVIDOR de mundo (autoridade) chama ApiClient.finalize_trade(...) com
#     a credencial de serviço. Em sucesso, conclui e cada cliente recarrega o inventário.
#     Sem credencial de serviço (dev/LAN), conclui sem transferência real.
#
# Fluxo de convite:
#   A clica "solicitar troca" → request_trade(B)
#     → servidor registra pendência e avisa B (GameBus.trade_requested)
#   B aceita/recusa → respond_trade(A, accept)
#     → aceite: servidor cria sessão e avisa ambos (GameBus.trade_started)
#     → recusa: servidor avisa A (GameBus.trade_request_declined)
#
# Fluxo de negociação (mutações sempre consultam o aceite do OUTRO antes de limpar):
#   set_item / remove_item / set_gold → revoga aceites; se o outro lado já aceitara,
#   abre bloqueio de reconfirmação (RESET_SECONDS). accept alterna o aceite do lado;
#   com ambos aceitos (e sem bloqueio) → conclui.
extends Node

const SERVER_ID     := 1
const RESET_SECONDS := 3.0
const MAX_SLOTS     := 16

# ── Estado (apenas o servidor mantém) ────────────────────────────────────────────
var _sessions: Dictionary       = {}   # session_id (int) → session dict
var _peer_to_session: Dictionary = {}   # peer_id (int)    → session_id (int)
var _pending: Dictionary        = {}   # target_peer (int) → from_peer (int)
var _next_session_id: int       = 1

# ═══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA (chamada pela UI no cliente local)
# ═══════════════════════════════════════════════════════════════════════════════

func request_trade(p_target_peer: int) -> void:
	if multiplayer.is_server():
		_srv_request(multiplayer.get_unique_id(), p_target_peer)
	else:
		_rpc_request.rpc_id(SERVER_ID, p_target_peer)

func respond_trade(p_from_peer: int, p_accept: bool) -> void:
	if multiplayer.is_server():
		_srv_respond(multiplayer.get_unique_id(), p_from_peer, p_accept)
	else:
		_rpc_respond.rpc_id(SERVER_ID, p_from_peer, p_accept)

func add_item(p_card_id: int, p_foil: bool = false) -> void:
	if multiplayer.is_server():
		_srv_add_item(multiplayer.get_unique_id(), p_card_id, p_foil)
	else:
		_rpc_add_item.rpc_id(SERVER_ID, p_card_id, p_foil)

func remove_item(p_slot: int) -> void:
	if multiplayer.is_server():
		_srv_remove_item(multiplayer.get_unique_id(), p_slot)
	else:
		_rpc_remove_item.rpc_id(SERVER_ID, p_slot)

func set_gold(p_amount: int) -> void:
	if multiplayer.is_server():
		_srv_set_gold(multiplayer.get_unique_id(), p_amount)
	else:
		_rpc_set_gold.rpc_id(SERVER_ID, p_amount)

func accept() -> void:
	if multiplayer.is_server():
		_srv_accept(multiplayer.get_unique_id())
	else:
		_rpc_accept.rpc_id(SERVER_ID)

func cancel() -> void:
	if multiplayer.is_server():
		_srv_cancel(multiplayer.get_unique_id())
	else:
		_rpc_cancel.rpc_id(SERVER_ID)

# ═══════════════════════════════════════════════════════════════════════════════
# RPCs recebidos pelo servidor (cliente → servidor)
# ═══════════════════════════════════════════════════════════════════════════════

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(p_target_peer: int) -> void:
	_srv_request(multiplayer.get_remote_sender_id(), p_target_peer)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_respond(p_from_peer: int, p_accept: bool) -> void:
	_srv_respond(multiplayer.get_remote_sender_id(), p_from_peer, p_accept)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_add_item(p_card_id: int, p_foil: bool) -> void:
	_srv_add_item(multiplayer.get_remote_sender_id(), p_card_id, p_foil)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_remove_item(p_slot: int) -> void:
	_srv_remove_item(multiplayer.get_remote_sender_id(), p_slot)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_gold(p_amount: int) -> void:
	_srv_set_gold(multiplayer.get_remote_sender_id(), p_amount)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_accept() -> void:
	_srv_accept(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func _rpc_cancel() -> void:
	_srv_cancel(multiplayer.get_remote_sender_id())

# ═══════════════════════════════════════════════════════════════════════════════
# LÓGICA DO SERVIDOR (autoridade)
# ═══════════════════════════════════════════════════════════════════════════════

func _srv_request(p_from: int, p_target: int) -> void:
	if p_from == p_target:
		return
	# Alvo (ou solicitante) já em uma troca → recusa automática.
	if _peer_to_session.has(p_target) or _peer_to_session.has(p_from):
		_send_declined(p_from, p_target)
		return
	_pending[p_target] = p_from
	_send_request(p_target, p_from, _name_of(p_from))

func _srv_respond(p_responder: int, p_from: int, p_accept: bool) -> void:
	# Só vale se houver pendência registrada de p_from para este responder.
	if int(_pending.get(p_responder, -1)) != p_from:
		return
	_pending.erase(p_responder)
	if not p_accept:
		_send_declined(p_from, p_responder)
		return
	# Verifica novamente se algum dos dois entrou em outra troca nesse meio-tempo.
	if _peer_to_session.has(p_from) or _peer_to_session.has(p_responder):
		_send_declined(p_from, p_responder)
		return
	_create_session(p_from, p_responder)

func _create_session(p_a: int, p_b: int) -> void:
	var sid := _next_session_id
	_next_session_id += 1
	var session := {
		"id":         sid,
		"a":          p_a,
		"b":          p_b,
		"sides":      {
			p_a: { "items": [], "gold": 0, "accepted": false },
			p_b: { "items": [], "gold": 0, "accepted": false },
		},
		"lock_until": 0,
		"completed":  false,
	}
	_sessions[sid] = session
	_peer_to_session[p_a] = sid
	_peer_to_session[p_b] = sid
	var state := _public(session)
	_send_started(p_a, p_b, _name_of(p_b), state)
	_send_started(p_b, p_a, _name_of(p_a), state)

func _srv_add_item(p_actor: int, p_card_id: int, p_foil: bool = false) -> void:
	var session := _session_of(p_actor)
	if session.is_empty() or _is_busy(session):
		return
	var items: Array = session["sides"][p_actor]["items"]
	if items.size() < MAX_SLOTS:
		items.append({ "card_id": p_card_id, "foil": p_foil })
	_after_mutation(session, p_actor)

func _srv_remove_item(p_actor: int, p_slot: int) -> void:
	var session := _session_of(p_actor)
	if session.is_empty() or _is_busy(session):
		return
	var items: Array = session["sides"][p_actor]["items"]
	if p_slot >= 0 and p_slot < items.size():
		items.remove_at(p_slot)
	_after_mutation(session, p_actor)

func _srv_set_gold(p_actor: int, p_amount: int) -> void:
	var session := _session_of(p_actor)
	if session.is_empty() or _is_busy(session):
		return
	session["sides"][p_actor]["gold"] = maxi(0, p_amount)
	_after_mutation(session, p_actor)

func _srv_accept(p_actor: int) -> void:
	var session := _session_of(p_actor)
	if session.is_empty() or _is_busy(session):
		return
	# Bloqueio de reconfirmação ativo → ignora.
	if Time.get_ticks_msec() < int(session["lock_until"]):
		_broadcast(session)
		return
	var side: Dictionary = session["sides"][p_actor]
	side["accepted"] = not bool(side["accepted"])
	var a: int = session["a"]
	var b: int = session["b"]
	if bool(session["sides"][a]["accepted"]) and bool(session["sides"][b]["accepted"]):
		# Ambos aceitaram → trava a edição e efetiva no backend (assíncrono).
		session["finalizing"] = true
		_broadcast(session)
		_finalize_and_complete(session)
	else:
		_broadcast(session)

func _srv_cancel(p_actor: int) -> void:
	var session := _session_of(p_actor)
	if session.is_empty():
		# Cancelou um convite ainda pendente? Limpa pendências envolvendo o ator.
		_clear_pending_of(p_actor)
		return
	# Em efetivação no backend → ignora (a chamada decide o desfecho).
	if bool(session.get("finalizing", false)):
		return
	var other := _other(session, p_actor)
	_send_cancelled(other, p_actor)
	_send_cancelled(p_actor, p_actor)
	_end_session(session)

# Pós-mutação: revoga aceites. Como a mudança só afeta itens/ouro (nunca o flag de
# aceite), ler o aceite do OUTRO lado aqui é equivalente a ler antes de aplicar —
# o que importa é ler ANTES de limpar (timing crítico do reset).
func _after_mutation(p_session: Dictionary, p_actor: int) -> void:
	var other := _other(p_session, p_actor)
	var other_was_accepted: bool = bool(p_session["sides"][other]["accepted"])
	p_session["sides"][p_session["a"]]["accepted"] = false
	p_session["sides"][p_session["b"]]["accepted"] = false
	if other_was_accepted:
		p_session["lock_until"] = Time.get_ticks_msec() + int(RESET_SECONDS * 1000.0)
		_send_reset(p_session["a"], RESET_SECONDS)
		_send_reset(p_session["b"], RESET_SECONDS)
	_broadcast(p_session)

func _is_busy(p_session: Dictionary) -> bool:
	return bool(p_session.get("completed", false)) or bool(p_session.get("finalizing", false))

# Efetiva a troca no backend (autoridade da transferência) e, em sucesso, conclui.
# Sem credencial de serviço (dev/LAN), conclui sem transferência real. Em falha,
# reverte os aceites e reabre a negociação.
func _finalize_and_complete(p_session: Dictionary) -> void:
	var a: int = p_session["a"]
	var b: int = p_session["b"]

	if not ApiClient.has_service_credential():
		print("[WorldTrade] Sem token de serviço — concluindo SEM chamar /trades (dev).")
		_complete(p_session)
		return

	var payload := {
		"clientTradeId": _gen_uuid(),
		"playerOne": _party_payload(a, p_session["sides"][a]),
		"playerTwo": _party_payload(b, p_session["sides"][b]),
	}
	print("[WorldTrade] Efetivando troca no backend (POST /trades): ", payload)
	var res: Dictionary = await ApiClient.finalize_trade(payload)

	# A sessão pode ter sido encerrada (desconexão) durante a chamada.
	if not _sessions.has(int(p_session["id"])):
		return

	if res.get("ok", false):
		_complete(p_session)
	else:
		push_warning("[WorldTrade] Falha ao efetivar troca: %s" % str(res.get("error", "")))
		p_session["finalizing"] = false
		p_session["sides"][a]["accepted"] = false
		p_session["sides"][b]["accepted"] = false
		_broadcast(p_session)

func _party_payload(p_peer: int, p_side: Dictionary) -> Dictionary:
	var players := WorldState.get_players()
	var pid := str((players.get(p_peer, {}) as Dictionary).get("player_id", ""))
	return {
		"playerId": pid,
		"cards":    _cards_payload(p_side["items"]),
		"gold":     int(p_side["gold"]),
	}

# Agrupa os itens ofertados em { cardId (UUID), quantity, foilQuantity }, usando o
# card_id do catálogo (taldorian_origins.json) — disponível em qualquer instância.
# `quantity` = total de cópias; `foilQuantity` = quantas dessas são foil (subconjunto).
func _cards_payload(p_items: Array) -> Array:
	var agg: Dictionary = {}   # card_id local → { "quantity": int, "foil": int }
	for it in p_items:
		var cid := int((it as Dictionary)["card_id"])
		var is_foil := bool((it as Dictionary).get("foil", false))
		if not agg.has(cid):
			agg[cid] = { "quantity": 0, "foil": 0 }
		agg[cid]["quantity"] += 1
		if is_foil:
			agg[cid]["foil"] += 1
	var out: Array = []
	for cid in agg:
		var uuid := _card_uuid(int(cid))
		if uuid == "":
			push_warning("[WorldTrade] Carta local %d sem card_id (UUID) no catálogo." % int(cid))
			continue
		out.append({
			"cardId":       uuid,
			"quantity":     int(agg[cid]["quantity"]),
			"foilQuantity": int(agg[cid]["foil"]),
		})
	return out

func _card_uuid(p_card_id: int) -> String:
	for d in Collection.all_card_dicts:
		if int(d.get("id", -1)) == p_card_id:
			return str(d.get("card_id", ""))
	return ""

func _gen_uuid() -> String:
	var b := PackedByteArray()
	b.resize(16)
	for i in 16:
		b[i] = randi() % 256
	b[6] = (b[6] & 0x0f) | 0x40   # versão 4
	b[8] = (b[8] & 0x3f) | 0x80   # variante
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

func _complete(p_session: Dictionary) -> void:
	p_session["completed"] = true
	var state := _public(p_session)
	_send_completed(p_session["a"], state)
	_send_completed(p_session["b"], state)
	_end_session(p_session)

func _end_session(p_session: Dictionary) -> void:
	var sid: int = p_session["id"]
	_peer_to_session.erase(p_session["a"])
	_peer_to_session.erase(p_session["b"])
	_sessions.erase(sid)

func _broadcast(p_session: Dictionary) -> void:
	var state := _public(p_session)
	_send_sync(p_session["a"], state)
	_send_sync(p_session["b"], state)

# ── Desconexão: encerra a troca do peer que saiu ────────────────────────────────

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_disconnected(p_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_clear_pending_of(p_peer_id)
	var session := _session_of(p_peer_id)
	if session.is_empty():
		return
	var other := _other(session, p_peer_id)
	_send_cancelled(other, p_peer_id)
	_end_session(session)

# ═══════════════════════════════════════════════════════════════════════════════
# ENTREGA AOS CLIENTES (servidor → peer; host-jogador recebe via emit local)
# ═══════════════════════════════════════════════════════════════════════════════

func _send_request(p_to: int, p_from: int, p_from_name: String) -> void:
	if p_to == SERVER_ID:
		GameBus.trade_requested.emit(p_from, p_from_name)
	else:
		_notify_request.rpc_id(p_to, p_from, p_from_name)

func _send_declined(p_to: int, p_by: int) -> void:
	if p_to == SERVER_ID:
		GameBus.trade_request_declined.emit(p_by, _name_of(p_by))
	else:
		_notify_declined.rpc_id(p_to, p_by, _name_of(p_by))

func _send_started(p_to: int, p_other: int, p_other_name: String, p_state: Dictionary) -> void:
	if p_to == SERVER_ID:
		GameBus.trade_started.emit(p_other, p_other_name, p_state)
	else:
		_notify_started.rpc_id(p_to, p_other, p_other_name, p_state)

func _send_sync(p_to: int, p_state: Dictionary) -> void:
	if p_to == SERVER_ID:
		GameBus.trade_state_synced.emit(p_state)
	else:
		_notify_sync.rpc_id(p_to, p_state)

func _send_reset(p_to: int, p_seconds: float) -> void:
	if p_to == SERVER_ID:
		GameBus.trade_reset.emit(p_seconds)
	else:
		_notify_reset.rpc_id(p_to, p_seconds)

func _send_completed(p_to: int, p_state: Dictionary) -> void:
	if p_to == SERVER_ID:
		GameBus.trade_completed.emit(p_state)
	else:
		_notify_completed.rpc_id(p_to, p_state)

func _send_cancelled(p_to: int, p_by: int) -> void:
	if p_to == SERVER_ID:
		GameBus.trade_cancelled.emit(p_by)
	else:
		_notify_cancelled.rpc_id(p_to, p_by)

# ── RPCs recebidos pelos clientes (servidor → cliente) ──────────────────────────

@rpc("authority", "call_remote", "reliable")
func _notify_request(p_from: int, p_from_name: String) -> void:
	GameBus.trade_requested.emit(p_from, p_from_name)

@rpc("authority", "call_remote", "reliable")
func _notify_declined(p_by: int, p_by_name: String) -> void:
	GameBus.trade_request_declined.emit(p_by, p_by_name)

@rpc("authority", "call_remote", "reliable")
func _notify_started(p_other: int, p_other_name: String, p_state: Dictionary) -> void:
	GameBus.trade_started.emit(p_other, p_other_name, p_state)

@rpc("authority", "call_remote", "reliable")
func _notify_sync(p_state: Dictionary) -> void:
	GameBus.trade_state_synced.emit(p_state)

@rpc("authority", "call_remote", "reliable")
func _notify_reset(p_seconds: float) -> void:
	GameBus.trade_reset.emit(p_seconds)

@rpc("authority", "call_remote", "reliable")
func _notify_completed(p_state: Dictionary) -> void:
	GameBus.trade_completed.emit(p_state)

@rpc("authority", "call_remote", "reliable")
func _notify_cancelled(p_by: int) -> void:
	GameBus.trade_cancelled.emit(p_by)

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITÁRIOS
# ═══════════════════════════════════════════════════════════════════════════════

func _session_of(p_peer: int) -> Dictionary:
	if not _peer_to_session.has(p_peer):
		return {}
	return _sessions.get(_peer_to_session[p_peer], {})

func _other(p_session: Dictionary, p_peer: int) -> int:
	return int(p_session["b"]) if int(p_session["a"]) == p_peer else int(p_session["a"])

func _clear_pending_of(p_peer: int) -> void:
	_pending.erase(p_peer)
	for target in _pending.keys():
		if int(_pending[target]) == p_peer:
			_pending.erase(target)

func _name_of(p_peer: int) -> String:
	var players := WorldState.get_players()
	if players.has(p_peer):
		return str(players[p_peer].get("player_name", "Jogador"))
	return "Jogador"

# Estado público enviado aos clientes (cópias, com chaves int por peer).
func _public(p_session: Dictionary) -> Dictionary:
	var a: int = p_session["a"]
	var b: int = p_session["b"]
	return {
		"id":        p_session["id"],
		"peers":     [a, b],
		"sides":     {
			a: _public_side(p_session["sides"][a]),
			b: _public_side(p_session["sides"][b]),
		},
		"completed": bool(p_session.get("completed", false)),
	}

func _public_side(p_side: Dictionary) -> Dictionary:
	return {
		"items":    (p_side["items"] as Array).duplicate(true),   # itens são dicts {card_id, foil}
		"gold":     int(p_side["gold"]),
		"accepted": bool(p_side["accepted"]),
	}
