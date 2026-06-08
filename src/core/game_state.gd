# src/core/game_state.gd
extends Node

# ── Estado da partida (Modelo A — Fase 2.1) ──────────────────────────────────
# Todo o estado mutável de UMA partida vive em Match (`_m`). As propriedades
# abaixo são proxies que leem/escrevem em `_m`, mantendo a API GameState.players/
# battle para as cenas e TODOS os corpos de método inalterados. Na Fase 2.2 o
# servidor troca `_m` pela partida do remetente do RPC (multi-sala).
var _m: MatchState = MatchState.new()

# ── Router multi-sala (Fase 2.2 — só servidor) ───────────────────────────────
# O servidor mantém N partidas isoladas. Cada RPC de cliente roteia `_m` para a
# partida do remetente (via _peer_to_player_index). No cliente há só uma partida
# (o próprio `_m`), então estes ficam vazios.
var _matches: Dictionary = {}        # match_id:int -> MatchState
var _peer_to_match: Dictionary = {}  # peer_id:int -> match_id
var _next_match_id: int = 1

# Enum mantido no GameState: os corpos usam PickSource.X sem qualificar.
enum PickSource { DECK, GRAVEYARD, HAND, HAND_DISCARD, HAND_ARSENAL, GRAVEYARD_ARSENAL, DECK_PEEK }

var players: Array[Player]:
	get:
		return _m.players
	set(value):
		_m.players = value
var battle: BattleManager:
	get:
		return _m.battle
	set(value):
		_m.battle = value

var _opening_mulligan_done: Array[bool]:
	get:
		return _m._opening_mulligan_done
	set(value):
		_m._opening_mulligan_done = value
var _hero_submitted: Array[bool]:
	get:
		return _m._hero_submitted
	set(value):
		_m._hero_submitted = value
var _next_hero_pick_player: int:
	get:
		return _m._next_hero_pick_player
	set(value):
		_m._next_hero_pick_player = value
var _winner_index: int:
	get:
		return _m._winner_index
	set(value):
		_m._winner_index = value

var _active_segment_player: int:
	get:
		return _m._active_segment_player
	set(value):
		_m._active_segment_player = value
var _turn_first_player: int:
	get:
		return _m._turn_first_player
	set(value):
		_m._turn_first_player = value
var _segment_action_done: Array[bool]:
	get:
		return _m._segment_action_done
	set(value):
		_m._segment_action_done = value
var _segment_bonus_done: Array[bool]:
	get:
		return _m._segment_bonus_done
	set(value):
		_m._segment_bonus_done = value
var _reaction_window_for: int:
	get:
		return _m._reaction_window_for
	set(value):
		_m._reaction_window_for = value
var _consecutive_empty_turns: int:
	get:
		return _m._consecutive_empty_turns
	set(value):
		_m._consecutive_empty_turns = value
var _hero_revealed: Array[bool]:
	get:
		return _m._hero_revealed
	set(value):
		_m._hero_revealed = value
var _end_submitted: Array[bool]:
	get:
		return _m._end_submitted
	set(value):
		_m._end_submitted = value

var _pending_effect_card: Card:
	get:
		return _m._pending_effect_card
	set(value):
		_m._pending_effect_card = value
var _pending_effect_player: int:
	get:
		return _m._pending_effect_player
	set(value):
		_m._pending_effect_player = value
var _pending_effect_from_arsenal: bool:
	get:
		return _m._pending_effect_from_arsenal
	set(value):
		_m._pending_effect_from_arsenal = value

var _pending_ally_pick_player: int:
	get:
		return _m._pending_ally_pick_player
	set(value):
		_m._pending_ally_pick_player = value
var _pending_ally_pick_action: String:
	get:
		return _m._pending_ally_pick_action
	set(value):
		_m._pending_ally_pick_action = value
var _pending_ally_pick_amount: int:
	get:
		return _m._pending_ally_pick_amount
	set(value):
		_m._pending_ally_pick_amount = value

var _pending_symbol_player: int:
	get:
		return _m._pending_symbol_player
	set(value):
		_m._pending_symbol_player = value
var _pending_symbol_count: int:
	get:
		return _m._pending_symbol_count
	set(value):
		_m._pending_symbol_count = value
var _pending_symbol_card: Card:
	get:
		return _m._pending_symbol_card
	set(value):
		_m._pending_symbol_card = value
var _pending_symbol_after_reaction: bool:
	get:
		return _m._pending_symbol_after_reaction
	set(value):
		_m._pending_symbol_after_reaction = value

var _pending_pick_player: int:
	get:
		return _m._pending_pick_player
	set(value):
		_m._pending_pick_player = value
var _pending_pick_source: PickSource:
	get:
		return _m._pending_pick_source
	set(value):
		_m._pending_pick_source = value
var _pending_pick_count: int:
	get:
		return _m._pending_pick_count
	set(value):
		_m._pending_pick_count = value
var _pending_pick_draw_after: int:
	get:
		return _m._pending_pick_draw_after
	set(value):
		_m._pending_pick_draw_after = value
var _pending_pick_indices: Array[int]:
	get:
		return _m._pending_pick_indices
	set(value):
		_m._pending_pick_indices = value
var _pending_pick_cards_display: Array[Card]:
	get:
		return _m._pending_pick_cards_display
	set(value):
		_m._pending_pick_cards_display = value
var _pending_pick_instruction: String:
	get:
		return _m._pending_pick_instruction
	set(value):
		_m._pending_pick_instruction = value
var _pending_both_recycle_followup: int:
	get:
		return _m._pending_both_recycle_followup
	set(value):
		_m._pending_both_recycle_followup = value
var _hero_was_hidden_at_play: Array[bool]:
	get:
		return _m._hero_was_hidden_at_play
	set(value):
		_m._hero_was_hidden_at_play = value

var _backline_queue: Array[Dictionary]:
	get:
		return _m._backline_queue
	set(value):
		_m._backline_queue = value
var _backline_awaiting_response: bool:
	get:
		return _m._backline_awaiting_response
	set(value):
		_m._backline_awaiting_response = value
var _backline_awaiting_target: bool:
	get:
		return _m._backline_awaiting_target
	set(value):
		_m._backline_awaiting_target = value
var _backline_current_player: int:
	get:
		return _m._backline_current_player
	set(value):
		_m._backline_current_player = value
var _backline_current_hero_idx: int:
	get:
		return _m._backline_current_hero_idx
	set(value):
		_m._backline_current_hero_idx = value

var _deck_submitted: Array[bool]:
	get:
		return _m._deck_submitted
	set(value):
		_m._deck_submitted = value
var _submitted_deck: Array[Dictionary]:
	get:
		return _m._submitted_deck
	set(value):
		_m._submitted_deck = value

var _match_peer_to_idx: Dictionary:
	get:
		return _m._match_peer_to_idx
	set(value):
		_m._match_peer_to_idx = value

func _ready() -> void:
	# Servidor: limpa a partida de um peer que cai (e dá a vitória ao oponente).
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func start_match(deck0: Dictionary = {}, deck1: Dictionary = {}) -> void:
	var p0: Player = _make_player(0, "Jogador 1") if deck0.is_empty() else _make_player_from_deck(0, "Jogador 1", deck0)
	var p1: Player = _make_player2(1, "Jogador 2") if deck1.is_empty() else _make_player_from_deck(1, "Jogador 2", deck1)
	players = [p0, p1]
	battle.players = players
	battle.current_player_index = 0
	_winner_index = -1
	_deck_submitted   = [false, false]
	_submitted_deck   = [{}, {}]
	for p in players:
		_shuffle_deck(p.deck)

	for p in players:
		p.draw_up_to(Player.HAND_CAP_START)

	# ── DEBUG: forçar carta específica na mão ────────────────────────────────
	# Para ativar: descomente as 2 linhas abaixo.
	# Para desativar: comente novamente.
	# Parâmetros:
	#   player_idx → 0 = host/Jogador1 | 1 = cliente/Jogador2
	#   card_id    → id da carta em data/cards/taldorian_origins.json
	#   hand_slot  → posição na mão (0 = primeira, -1 = última)
	_debug_force_card_in_hand(0, 37)  # "Dois Passos à Frente" → mão do Jogador 0
	# ── fim do bloco DEBUG ───────────────────────────────────────────────────

	_opening_mulligan_done = [false, false]
	# Envia os decks ao(s) cliente(s) para que construam seus próprios players
	# antes do primeiro _sync_state chegar.
	if multiplayer.is_server() and not multiplayer.get_peers().is_empty():
		_notify_init_players(deck0, deck1)
	battle.emit_phase_changed()

@rpc("authority", "call_remote", "reliable")
func _rpc_init_players(deck0: Dictionary, deck1: Dictionary) -> void:
	var p0: Player = _make_player(0, "Jogador 1") if deck0.is_empty() else _make_player_from_deck(0, "Jogador 1", deck0)
	var p1: Player = _make_player2(1, "Jogador 2") if deck1.is_empty() else _make_player_from_deck(1, "Jogador 2", deck1)
	players = [p0, p1]
	battle.players = players

func is_game_over() -> bool:
	return _winner_index >= 0

func get_winner_index() -> int:
	return _winner_index

func get_next_action_player_index() -> int:
	return _active_segment_player

func get_reaction_window_for() -> int:
	return _reaction_window_for

func get_segment_action_done(player_idx: int) -> bool:
	if player_idx < 0 or player_idx > 1:
		return false
	return _segment_action_done[player_idx]

func get_segment_bonus_done(player_idx: int) -> bool:
	if player_idx < 0 or player_idx > 1:
		return false
	return _segment_bonus_done[player_idx]

func get_hero_revealed(player_idx: int) -> bool:
	if player_idx < 0 or player_idx > 1:
		return false
	return _hero_revealed[player_idx]

func get_backline_awaiting_response() -> bool: return _backline_awaiting_response
func get_backline_awaiting_target()   -> bool: return _backline_awaiting_target
func get_backline_current_player()    -> int:  return _backline_current_player
func get_backline_current_hero_idx()  -> int:  return _backline_current_hero_idx

## Oculta o herói novamente (torna furtivo). Usado pela habilidade ativa de Hakai.
func set_hero_stealth(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	_hero_revealed[player_idx] = false

func has_completed_opening_mulligan(player_idx: int) -> bool:
	if player_idx < 0 or player_idx > 1:
		return false
	return _opening_mulligan_done[player_idx]

func has_submitted_hero_pick(player_idx: int) -> bool:
	if player_idx < 0 or player_idx > 1:
		return false
	return _hero_submitted[player_idx]


func get_next_hero_pick_player_index() -> int:
	if battle.current_phase != BattleManager.Phase.HERO_SELECTION:
		return -1
	if _hero_submitted[0] and _hero_submitted[1]:
		return -1
	return _next_hero_pick_player

func submit_opening_mulligan(player_idx: int, idx_a: int, idx_b: int) -> bool:
	if _winner_index >= 0:
		return false
	if battle.current_phase != BattleManager.Phase.OPENING_MULLIGAN:
		return false
	if player_idx < 0 or player_idx > 1:
		return false
	if _opening_mulligan_done[player_idx]:
		return false
	if idx_a == idx_b:
		return false
	var pl: Player = players[player_idx]
	var n := pl.hand.size()
	if idx_a < 0 or idx_a >= n or idx_b < 0 or idx_b >= n:
		return false
	var c_a: Card = pl.hand[idx_a]
	var c_b: Card = pl.hand[idx_b]
	pl.send_cards_to_bottom([c_a, c_b])
	_opening_mulligan_done[player_idx] = true
	print("[TCG] Jogador %d (%s): mulligan — devolveu '%s' e '%s'" % [player_idx, pl.player_name, c_a.card_name, c_b.card_name])
	if _opening_mulligan_done[0] and _opening_mulligan_done[1]:
		battle.current_player_index = 0
		_begin_battle_for_active_player()
	else:
		battle.emit_phase_changed()
	return true

func _begin_battle_for_active_player() -> void:
	if _winner_index >= 0:
		return
	print("[TCG] ════════════════════════════════")
	print("[TCG] Início da batalha — Jogador %d (%s)" % [battle.current_player_index, players[battle.current_player_index].player_name])
	# Reseta revelação de heróis: valores do turno anterior (true/true ao final do
	# COMBAT) não devem vazar para DRAW e HERO_SELECTION do novo turno.
	# Herois normais voltam face-down para o blefe; starts_face_up permanecem revelados.
	for i in 2:
		var _active := players[i].active_hero
		_hero_revealed[i] = _active != null and _active.starts_face_up
	# Reseta is_backline_revealed e estado de fila de backline
	for p in players:
		for h in p.heroes:
			h.is_backline_revealed = h.starts_face_up
	_backline_queue.clear()
	_backline_awaiting_response = false
	_backline_awaiting_target   = false
	_backline_current_player    = -1
	_backline_current_hero_idx  = -1

	var idx := battle.current_player_index
	var player: Player = players[idx]

	# 1. Fase DRAW — compra cartas e sincroniza
	battle.current_phase = BattleManager.Phase.DRAW
	GameBus.battle_started.emit(idx)
	player.draw_up_to(Player.HAND_CAP_START)
	if player.hand.size() >= 2:
		var hn := player.hand.size()
		player.send_cards_to_bottom([player.hand[hn - 1], player.hand[hn - 2]])
	player._check_rotation()
	_emit_sync()

	# 2. Fase HERO_SELECTION
	battle.current_phase = BattleManager.Phase.HERO_SELECTION
	_hero_submitted = [false, false]
	_next_hero_pick_player = idx
	_emit_sync()

func submit_hero_pick(player_idx: int, hero_slot: int) -> bool:
	if _winner_index >= 0:
		return false
	if battle.current_phase != BattleManager.Phase.HERO_SELECTION:
		return false
	if player_idx < 0 or player_idx > 1 or hero_slot < 0 or hero_slot > 2:
		return false
	if _hero_submitted[player_idx]:
		return false
	var pl: Player = players[player_idx]
	var hero: Hero = pl.heroes[hero_slot]
	if hero not in pl.get_available_heroes():
		return false
	pl.choose_hero(hero)
	hero.on_battle_start(pl)
	if hero.starts_face_up:
		_hero_revealed[player_idx] = true
		GameBus.hero_revealed.emit(player_idx, hero)
	print("[TCG] Jogador %d (%s): escolheu herói %s (HP:%d/%d)" % [player_idx, pl.player_name, hero.hero_name, hero.current_hp, hero.max_hp])
	GameBus.hero_chosen.emit(player_idx, hero)
	_hero_submitted[player_idx] = true
	if _hero_submitted[0] and _hero_submitted[1]:
		# Passivas de retaguarda — dispara não-interativas imediatamente;
		# interativas (has_backline_ability) entram na fila de decisão do jogador.
		var interactive: Array[Dictionary] = []
		for i in 2:
			var sp: Player = players[i]
			var opp: Player = players[1 - i]
			for h in sp.heroes:
				if h.is_alive() and h.state == Hero.State.ACTIVE and h != sp.active_hero:
					if h.has_backline_ability():
						interactive.append({ "player_idx": i, "hero_idx": sp.heroes.find(h) })
					else:
						var desc := h.on_support_battle_start(sp, opp)
						if not desc.is_empty():
							var hero_idx := sp.heroes.find(h)
							GameBus.skill_activated.emit(h, desc)
							_notify_skill_activated(i, hero_idx, desc)
		_backline_queue = interactive
		_process_next_backline_ability()
	else:
		# Apenas sincroniza — o outro jogador ainda verá a tela de seleção
		_emit_sync()
	return true

# ── habilidades de retaguarda interativas ───────────────────────────────────

## Processa o próximo item da fila de habilidades de retaguarda.
## Se a fila estiver vazia, inicia a fase ACTION normalmente.
func _process_next_backline_ability() -> void:
	if _backline_queue.is_empty():
		battle.current_phase = BattleManager.Phase.ACTION
		_reset_action_phase_state()
		_emit_sync()
		return
	var entry: Dictionary = _backline_queue.pop_front()
	_backline_current_player    = entry["player_idx"]
	_backline_current_hero_idx  = entry["hero_idx"]
	battle.current_phase = BattleManager.Phase.BACKLINE_ABILITY
	var hero := players[_backline_current_player].heroes[_backline_current_hero_idx]
	# Só pede confirmação quando ativar a habilidade quebra a furtividade do herói.
	# Se ele já está revelado, não há tradeoff: ativa direto, sem popup.
	if hero.is_backline_revealed:
		_backline_awaiting_response = false
		_begin_backline_target_selection()
	else:
		_backline_awaiting_response = true
		_backline_awaiting_target   = false
	_emit_sync()

## Jogador responde se quer usar a habilidade de retaguarda (Sim/Não).
@rpc("any_peer", "call_local", "reliable")
func rpc_respond_backline_ability(use: bool) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if player_idx != _backline_current_player or not _backline_awaiting_response:
		return
	_backline_awaiting_response = false
	if not use:
		_process_next_backline_ability()
		return
	# Confirma uso: revela o herói na backline, pede escolha de alvo
	_begin_backline_target_selection()
	_emit_sync()

## Revela o herói de retaguarda atual (quebra a furtividade), dispara o aviso visual
## da passiva e abre a seleção de alvo. NÃO chama _emit_sync — o chamador cuida disso.
func _begin_backline_target_selection() -> void:
	var hero := players[_backline_current_player].heroes[_backline_current_hero_idx]
	hero.is_backline_revealed = true
	_backline_awaiting_target = true
	GameBus.skill_activated.emit(hero, hero.passive_desc)
	_notify_skill_activated(_backline_current_player, _backline_current_hero_idx, hero.passive_desc)

## Jogador escolheu o herói alvo para a habilidade de retaguarda.
@rpc("any_peer", "call_local", "reliable")
func rpc_submit_backline_target(target_player_idx: int, target_hero_idx: int) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if player_idx != _backline_current_player or not _backline_awaiting_target:
		return
	if target_player_idx < 0 or target_player_idx > 1:
		return
	if target_hero_idx < 0 or target_hero_idx >= players[target_player_idx].heroes.size():
		return
	var target_hero := players[target_player_idx].heroes[target_hero_idx]
	if not target_hero.is_alive():
		return
	var sp  := players[_backline_current_player]
	var opp := players[1 - _backline_current_player]
	var backline_hero := sp.heroes[_backline_current_hero_idx]
	# Notifica ambos os clientes para que animem a flecha antes de aplicar o efeito
	GameBus.backline_arrow_fired.emit(_backline_current_player, _backline_current_hero_idx, target_player_idx, target_hero_idx)
	_notify_backline_arrow(_backline_current_player, _backline_current_hero_idx, target_player_idx, target_hero_idx)
	var desc := backline_hero.apply_backline_ability(sp, opp, target_hero)
	if not desc.is_empty():
		GameBus.skill_activated.emit(backline_hero, desc)
		_notify_skill_activated(_backline_current_player, _backline_current_hero_idx, desc)
	_backline_awaiting_target  = false
	_backline_current_player   = -1
	_backline_current_hero_idx = -1
	var w := _evaluate_winner()
	if w >= 0:
		_winner_index = w
		GameBus.game_over.emit(w)
		_notify_game_over(w)
	_process_next_backline_ability()

func action_play_card(player_idx: int, hand_idx: int) -> bool:
	if _winner_index >= 0:
		return false
	if battle.current_phase != BattleManager.Phase.ACTION:
		return false
	if _pending_pick_player >= 0:
		return false
	if _pending_symbol_player >= 0:
		return false
	if _pending_ally_pick_player >= 0:
		return false
	var pl: Player = players[player_idx]
	if hand_idx < 0 or hand_idx >= pl.hand.size():
		return false
	var card: Card = pl.hand[hand_idx]

	match card.timing:
		Card.TimingType.ACTION:
			if player_idx != _active_segment_player: return false
			if _segment_action_done[player_idx]: return false
			if _reaction_window_for != -1: return false
			pl.hand.remove_at(hand_idx)
			pl.cards_this_battle.append(card)
			pl.turn_cards.append(card)
			var _syms_a := "" if card.symbols.is_empty() else " {%s}" % ", ".join(Array(card.symbols))
			print("[TCG] Jogador %d (%s): jogou ACTION '%s' (atk:%d def:%d%s%s)" % [player_idx, pl.player_name, card.card_name, card.attack_value, card.defense_value, _syms_a, " [furtivo]" if card.is_stealth else ""])
			_capture_hero_hidden(player_idx)
			_try_reveal_hero(player_idx, card)
			_on_card_added_to_play(player_idx, card)
			_segment_action_done[player_idx] = true
			_consecutive_empty_turns = 0
			_pending_effect_card         = card
			_pending_effect_player       = player_idx
			_pending_effect_from_arsenal = false
			card.execute_pre_window_effects(_make_effect_ctx(player_idx, card))
			_fire_on_card_played(player_idx, card)
			_emit_card_played(player_idx, card)
			if players[player_idx].pending_cancel_reaction:
				_reaction_window_for = -1
				_on_reaction_window_closed()
			else:
				_reaction_window_for = 1 - player_idx
				GameBus.reaction_window_opened.emit(1 - player_idx)
				_emit_sync()
			return true

		Card.TimingType.BONUS_ACTION:
			if player_idx != _active_segment_player: return false
			if _segment_bonus_done[player_idx]: return false
			if _reaction_window_for != -1: return false
			pl.hand.remove_at(hand_idx)
			pl.cards_this_battle.append(card)
			pl.turn_cards.append(card)
			var _syms_b := "" if card.symbols.is_empty() else " {%s}" % ", ".join(Array(card.symbols))
			print("[TCG] Jogador %d (%s): jogou BONUS '%s' (atk:%d def:%d%s)" % [player_idx, pl.player_name, card.card_name, card.attack_value, card.defense_value, _syms_b])
			_capture_hero_hidden(player_idx)
			_try_reveal_hero(player_idx, card)
			_on_card_added_to_play(player_idx, card)
			_segment_bonus_done[player_idx] = true
			_pending_effect_card         = card
			_pending_effect_player       = player_idx
			_pending_effect_from_arsenal = false
			card.execute_pre_window_effects(_make_effect_ctx(player_idx, card))
			_fire_on_card_played(player_idx, card)
			_emit_card_played(player_idx, card)
			_reaction_window_for = 1 - player_idx
			GameBus.reaction_window_opened.emit(1 - player_idx)
			_emit_sync()
			return true

		Card.TimingType.REACTION:
			if _reaction_window_for != player_idx: return false
			pl.hand.remove_at(hand_idx)
			pl.cards_this_battle.append(card)
			pl.turn_cards.append(card)
			var _syms_r := "" if card.symbols.is_empty() else " {%s}" % ", ".join(Array(card.symbols))
			print("[TCG] Jogador %d (%s): jogou REACTION '%s'%s" % [player_idx, pl.player_name, card.card_name, _syms_r])
			_capture_hero_hidden(player_idx)
			_try_reveal_hero(player_idx, card)
			_on_card_added_to_play(player_idx, card)
			_reaction_window_for = -1
			card.execute_effects(_make_effect_ctx(player_idx, card))
			_fire_on_card_played(player_idx, card)
			_emit_card_played(player_idx, card)
			# Se o efeito abriu um pick (carta ou símbolo), pausar — o pick resolverá o fluxo
			if _pending_symbol_player >= 0 or _pending_pick_player >= 0 or _pending_ally_pick_player >= 0:
				_emit_sync()
				return true
			_on_reaction_window_closed()
			return true

	return false

func action_play_from_arsenal(player_idx: int) -> bool:
	if _winner_index >= 0 or battle.current_phase != BattleManager.Phase.ACTION:
		return false
	var pl: Player = players[player_idx]
	if pl.arsenal.is_empty():
		return false
	var card: Card = pl.arsenal[0]

	match card.timing:
		Card.TimingType.ACTION:
			if player_idx != _active_segment_player: return false
			if _segment_action_done[player_idx]: return false
			if _reaction_window_for != -1: return false
			pl.arsenal.remove_at(0)
			pl.cards_this_battle.append(card)
			pl.turn_cards.append(card)
			var _syms_aa := "" if card.symbols.is_empty() else " {%s}" % ", ".join(Array(card.symbols))
			print("[TCG] Jogador %d (%s): jogou ACTION '%s' do arsenal (atk:%d def:%d%s%s)" % [player_idx, pl.player_name, card.card_name, card.attack_value, card.defense_value, _syms_aa, " [furtivo]" if card.is_stealth else ""])
			_capture_hero_hidden(player_idx)
			_try_reveal_hero(player_idx, card)
			_on_card_added_to_play(player_idx, card)
			_segment_action_done[player_idx] = true
			_consecutive_empty_turns = 0
			_pending_effect_card         = card
			_pending_effect_player       = player_idx
			_pending_effect_from_arsenal = true
			card.execute_pre_window_effects(_make_effect_ctx(player_idx, card, true))
			_fire_on_card_played(player_idx, card)
			_emit_card_played(player_idx, card)
			if players[player_idx].pending_cancel_reaction:
				_reaction_window_for = -1
				_on_reaction_window_closed()
			else:
				_reaction_window_for = 1 - player_idx
				GameBus.reaction_window_opened.emit(1 - player_idx)
				_emit_sync()
			return true
		Card.TimingType.BONUS_ACTION:
			if player_idx != _active_segment_player: return false
			if _segment_bonus_done[player_idx]: return false
			if _reaction_window_for != -1: return false
			pl.arsenal.remove_at(0)
			pl.cards_this_battle.append(card)
			pl.turn_cards.append(card)
			var _syms_ba := "" if card.symbols.is_empty() else " {%s}" % ", ".join(Array(card.symbols))
			print("[TCG] Jogador %d (%s): jogou BONUS '%s' do arsenal (atk:%d def:%d%s)" % [player_idx, pl.player_name, card.card_name, card.attack_value, card.defense_value, _syms_ba])
			_capture_hero_hidden(player_idx)
			_try_reveal_hero(player_idx, card)
			_on_card_added_to_play(player_idx, card)
			_segment_bonus_done[player_idx] = true
			_pending_effect_card         = card
			_pending_effect_player       = player_idx
			_pending_effect_from_arsenal = true
			card.execute_pre_window_effects(_make_effect_ctx(player_idx, card, true))
			_fire_on_card_played(player_idx, card)
			_emit_card_played(player_idx, card)
			_reaction_window_for = 1 - player_idx
			GameBus.reaction_window_opened.emit(1 - player_idx)
			_emit_sync()
			return true
		Card.TimingType.REACTION:
			if _reaction_window_for != player_idx: return false
			pl.arsenal.remove_at(0)
			pl.cards_this_battle.append(card)
			pl.turn_cards.append(card)
			var _syms_ra := "" if card.symbols.is_empty() else " {%s}" % ", ".join(Array(card.symbols))
			print("[TCG] Jogador %d (%s): jogou REACTION '%s' do arsenal%s" % [player_idx, pl.player_name, card.card_name, _syms_ra])
			_capture_hero_hidden(player_idx)
			_try_reveal_hero(player_idx, card)
			_on_card_added_to_play(player_idx, card)
			_reaction_window_for = -1
			card.execute_effects(_make_effect_ctx(player_idx, card, true))
			_fire_on_card_played(player_idx, card)
			_emit_card_played(player_idx, card)
			if _pending_symbol_player >= 0 or _pending_pick_player >= 0 or _pending_ally_pick_player >= 0:
				_emit_sync()
				return true
			_on_reaction_window_closed()
			return true
	return false

func action_pass(player_idx: int) -> bool:
	if _winner_index >= 0:
		return false
	if battle.current_phase != BattleManager.Phase.ACTION:
		return false
	# Não permite avançar enquanto um pick está aguardando resolução
	if _pending_pick_player >= 0:
		return false
	if _pending_symbol_player >= 0:
		return false
	if _pending_ally_pick_player >= 0:
		return false

	# Passar janela de reação
	if _reaction_window_for == player_idx:
		print("[TCG] Jogador %d (%s): passou a janela de reação" % [player_idx, players[player_idx].player_name])
		_reaction_window_for = -1
		_on_reaction_window_closed()
		return true

	# Passar segmento ativo (sem janela aberta)
	if player_idx != _active_segment_player:
		return false
	print("[TCG] Jogador %d (%s): passou o segmento" % [player_idx, players[player_idx].player_name])
	_finish_segment(player_idx)
	return true

# ── helpers da fase ACTION ───────────────────────────────

## Chamado após cada carta ser adicionada a turn_cards/cards_this_battle.
## Verifica se a cadeia de símbolos ativa a skill do herói e notifica a passiva.
func _on_card_added_to_play(player_idx: int, card: Card) -> void:
	var pl: Player = players[player_idx]
	# Enfileira os efeitos AFTER_COMBAT desta carta para resolver após o combate.
	_enqueue_after_combat_effects(player_idx, card)
	# Consome bônus pendente para esta carta (definido pela carta anterior)
	if pl.pending_next_card_attack != 0:
		pl.pending_bonus_attack += pl.pending_next_card_attack
		pl.pending_next_card_attack = 0
	if pl.pending_next_card_defense != 0:
		pl.pending_bonus_defense += pl.pending_next_card_defense
		pl.pending_next_card_defense = 0
	var active: Hero = pl.active_hero
	if active == null:
		return
	if not active._skill_activated_this_battle and not active.symbols_required.is_empty():
		var chain: Array[String] = []
		for c in pl.cards_this_battle:
			for sym in c.symbols:
				chain.append(sym)
		if SymbolChain.matches_chain(chain, active.symbols_required):
			active.on_skill_activated(pl)
			var hero_idx := pl.heroes.find(active)
			_notify_skill_activated(pl.player_index, hero_idx, active.skill_desc)
			# Sintonia Primordial — compra 1 se habilidade ativa disparou
			if pl.pending_skill_draw:
				pl.pending_skill_draw = false
				pl.draw_cards(1)

func _fire_on_card_played(player_idx: int, card: Card) -> void:
	var pl: Player = players[player_idx]
	var active: Hero = pl.active_hero
	if active != null:
		active.on_card_played(card, pl)

# ── Fila de efeitos AFTER_COMBAT ─────────────────────────────────────────────

func _enqueue_after_combat_effects(player_idx: int, card: Card) -> void:
	for effect in card.after_combat_effects():
		_m._after_combat_queue.append({
			"effect":       effect,
			"player":       player_idx,
			"card":         card,
			# TODO: threadear played_from_arsenal quando um efeito AFTER_COMBAT precisar.
			"from_arsenal": false,
			"hero_hidden":  _hero_was_hidden_at_play[player_idx],
		})

## Resolve, em ordem FIFO, os efeitos AFTER_COMBAT acumulados no turno.
## dmg_to_p0/dmg_to_p1 = dano sofrido por cada jogador no combate que acabou de resolver.
func _drain_after_combat_queue(dmg_to_p0: int, dmg_to_p1: int) -> void:
	var queue := _m._after_combat_queue
	_m._after_combat_queue = []  # esvazia antes de resolver (reentrância segura)
	var dmg_taken := [dmg_to_p0, dmg_to_p1]
	for entry in queue:
		var pidx: int = entry["player"]
		var ctx := CardEffectContext.new()
		ctx.source_player       = players[pidx]
		ctx.opponent_player     = players[1 - pidx]
		ctx.source_card         = entry["card"]
		ctx.played_from_arsenal = entry["from_arsenal"]
		ctx.hero_was_hidden     = entry["hero_hidden"]
		ctx.damage_taken        = dmg_taken[pidx]
		ctx.damage_dealt        = dmg_taken[1 - pidx]
		entry["effect"].resolve_after_combat(ctx)

func _reset_action_phase_state() -> void:
	for p in players:
		p.reset_hero_turn_state()
	_active_segment_player    = battle.current_player_index
	_turn_first_player       = battle.current_player_index
	_segment_action_done      = [false, false]
	_segment_bonus_done       = [false, false]
	_reaction_window_for      = -1
	_consecutive_empty_turns = 0
	for i in 2:
		var _active := players[i].active_hero
		_hero_revealed[i] = _active != null and _active.starts_face_up
	_pending_effect_card         = null
	_pending_effect_player       = -1
	_pending_effect_from_arsenal = false
	_m._after_combat_queue.clear()
	_pending_pick_player     = -1
	_pending_pick_source     = PickSource.DECK
	_pending_pick_count      = 1
	_pending_pick_draw_after = 0
	_pending_ally_pick_player = -1
	_pending_ally_pick_action = ""
	_pending_ally_pick_amount = 0
	_pending_pick_indices.clear()
	_pending_pick_cards_display.clear()
	_pending_both_recycle_followup = -1
	_pending_symbol_player         = -1
	_pending_symbol_count          = 0
	_pending_symbol_card           = null
	_pending_symbol_after_reaction = false

func _execute_pending_effect() -> void:
	if _pending_effect_card == null:
		return
	var card         := _pending_effect_card
	var pidx         := _pending_effect_player
	var from_arsenal := _pending_effect_from_arsenal
	_pending_effect_card         = null
	_pending_effect_player       = -1
	_pending_effect_from_arsenal = false
	print("[PendingEffect] Disparando efeito de '%s' (player %d)" % [card.card_name, pidx])
	card.execute_effects(_make_effect_ctx(pidx, card, from_arsenal))
	print("[PendingEffect] Mão P0 após efeito: %d cartas | Mão P1 após efeito: %d cartas" % [players[0].hand.size(), players[1].hand.size()])

# ── pick de carta (efeitos que precisam de input do jogador) ──────────────

func get_pending_pick_player() -> int:
	return _pending_pick_player

func get_pending_pick_source() -> PickSource:
	return _pending_pick_source

func get_pending_pick_count() -> int:
	return _pending_pick_count

func get_pending_pick_instruction() -> String:
	return _pending_pick_instruction

func get_pending_symbol_player() -> int:
	return _pending_symbol_player

func get_pending_symbol_count() -> int:
	return _pending_symbol_count

## Inicia um pick de símbolo. after_reaction=true faz o fluxo de reação continuar após resolver.
func begin_symbol_pick(player_idx: int, card: Card, count: int, after_reaction: bool) -> void:
	_pending_symbol_player          = player_idx
	_pending_symbol_count           = count
	_pending_symbol_card            = card
	_pending_symbol_after_reaction  = after_reaction

## Retorna as cartas que o jogador deve escolher.
## No servidor usa os objetos originais da fonte; no cliente usa as cópias do snapshot.
func get_pending_pick_cards(player_idx: int) -> Array[Card]:
	if _pending_pick_player != player_idx:
		return []
	if multiplayer.is_server():
		var source_arr := _pick_source_array(player_idx)
		var result: Array[Card] = []
		for idx in _pending_pick_indices:
			if idx < source_arr.size():
				result.append(source_arr[idx])
		return result
	return _pending_pick_cards_display

## Retorna o array-fonte correto (deck, graveyard ou mão) para o jogador dado.
func _pick_source_array(player_idx: int) -> Array[Card]:
	match _pending_pick_source:
		PickSource.GRAVEYARD, PickSource.GRAVEYARD_ARSENAL:
			return players[player_idx].discard_pile
		PickSource.HAND, PickSource.HAND_DISCARD, PickSource.HAND_ARSENAL:
			return players[player_idx].hand
		_:
			return players[player_idx].deck

## Inicia um pick a partir do deck do jogador.
func begin_card_pick(player_idx: int, indices: Array[int], instruction: String = "") -> void:
	_pending_pick_player      = player_idx
	_pending_pick_source      = PickSource.DECK
	_pending_pick_indices     = indices
	_pending_pick_instruction = instruction

## Inicia um pick a partir do cemitério do jogador.
## draw_after=1 → compra 1 após; draw_after=0 → apenas coloca ao fundo (Respiração Profunda).
func begin_graveyard_pick(player_idx: int, indices: Array[int], draw_after: int = 1, instruction: String = "") -> void:
	_pending_pick_player      = player_idx
	_pending_pick_source      = PickSource.GRAVEYARD
	_pending_pick_draw_after  = draw_after
	_pending_pick_indices     = indices
	_pending_pick_instruction = instruction

## Inicia um pick da mão do jogador (carta escolhida vai ao fundo do deck).
## draw_after=1 → compra 1 após (Reorganizar); draw_after=0 → apenas coloca ao fundo.
func begin_hand_pick(player_idx: int, indices: Array[int], draw_after: int = 0, instruction: String = "") -> void:
	_pending_pick_player      = player_idx
	_pending_pick_source      = PickSource.HAND
	_pending_pick_count       = 1
	_pending_pick_draw_after  = draw_after
	_pending_pick_indices     = indices
	_pending_pick_instruction = instruction

## Inicia um pick da mão do jogador para colocar no arsenal (Passo Estratégico).
func begin_hand_arsenal_pick(player_idx: int, indices: Array[int], instruction: String = "") -> void:
	_pending_pick_player      = player_idx
	_pending_pick_source      = PickSource.HAND_ARSENAL
	_pending_pick_count       = 1
	_pending_pick_draw_after  = 0
	_pending_pick_indices     = indices
	_pending_pick_instruction = instruction

## Inicia um pick do cemitério para o arsenal (Ecos do Passado).
## followup_player=-1 → nenhum; outro valor → inicia pick para esse jogador após resolver.
func begin_graveyard_arsenal_pick(player_idx: int, indices: Array[int], followup_player: int = -1, instruction: String = "") -> void:
	_pending_pick_player           = player_idx
	_pending_pick_source           = PickSource.GRAVEYARD_ARSENAL
	_pending_pick_count            = 1
	_pending_pick_draw_after       = 0
	_pending_pick_indices          = indices
	_pending_pick_instruction      = instruction
	_pending_both_recycle_followup = followup_player

## Inicia um pick de descarte da mão (cartas vão ao cemitério; depois compra draw_after).
func begin_hand_discard(player_idx: int, indices: Array[int], count: int, draw_after: int, instruction: String = "") -> void:
	_pending_pick_player      = player_idx
	_pending_pick_source      = PickSource.HAND_DISCARD
	_pending_pick_count       = count
	_pending_pick_draw_after  = draw_after
	_pending_pick_indices     = indices
	_pending_pick_instruction = instruction

## Inicia um pick de herói aliado (ex.: Broto Vital — curar 1 aliado à escolha).
## action: "heal" | amount: quantidade a aplicar.
func begin_ally_pick(player_idx: int, action: String, amount: int) -> void:
	_pending_ally_pick_player = player_idx
	_pending_ally_pick_action = action
	_pending_ally_pick_amount = amount

func get_pending_ally_pick_player() -> int: return _pending_ally_pick_player
func get_pending_ally_pick_action()  -> String: return _pending_ally_pick_action
func get_pending_ally_pick_amount()  -> int: return _pending_ally_pick_amount

## O jogador escolheu qual herói aliado curar. hero_idx = índice em Player.heroes.
@rpc("any_peer", "call_local", "reliable")
func rpc_submit_ally_pick(hero_idx: int) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if _pending_ally_pick_player != player_idx:
		return
	var p := players[player_idx]
	if hero_idx < 0 or hero_idx >= p.heroes.size():
		return
	var target_hero := p.heroes[hero_idx]
	if target_hero.state == Hero.State.DEFEATED:
		return
	match _pending_ally_pick_action:
		"heal":
			var hp_before := target_hero.current_hp
			target_hero.heal(_pending_ally_pick_amount)
			var gained := target_hero.current_hp - hp_before
			if gained > 0:
				print("[TCG]   ♥ Ally Pick (J%d): curou %s em %d HP (HP: %d→%d)" % [
					player_idx, target_hero.hero_name, gained, hp_before, target_hero.current_hp
				])
			else:
				print("[TCG]   ♥ Ally Pick (J%d): cura aplicada em %s (HP cheio — sem ganho de HP)" % [
					player_idx, target_hero.hero_name
				])
	_pending_ally_pick_player = -1
	_pending_ally_pick_action = ""
	_pending_ally_pick_amount = 0
	# Retoma o fluxo do segmento se possível
	if _pending_pick_player < 0 and _pending_symbol_player < 0 \
			and battle.current_phase == BattleManager.Phase.ACTION:
		var active := _active_segment_player
		if _segment_action_done[active] and _segment_bonus_done[active]:
			_finish_segment(active)
			return
	_emit_sync()

## Inicia um peek do topo do deck (Dois Passos à Frente).
## Mostra a carta do topo sem removê-la. Jogador escolhe: manter no topo (enviar [])
## ou mover ao fundo (enviar [0]).
func begin_deck_peek(player_idx: int, instruction: String = "") -> void:
	if players[player_idx].deck.is_empty():
		return
	_pending_pick_player      = player_idx
	_pending_pick_source      = PickSource.DECK_PEEK
	_pending_pick_count       = 0   # 0 = sem seleção obrigatória (manter no topo é válido)
	_pending_pick_indices     = [0]  # exibe deck[0]
	_pending_pick_instruction = instruction

# ── Revela herói ────────────────────────────────────────

## Captura se o herói estava oculto antes de tentar revelar (para CardEffectContext).
func _capture_hero_hidden(player_idx: int) -> void:
	_hero_was_hidden_at_play[player_idx] = not _hero_revealed[player_idx]

## Revela o herói ativo do jogador se a carta não for furtiva e ele ainda não foi revelado.
func _try_reveal_hero(player_idx: int, card: Card) -> void:
	if card.is_stealth or _hero_revealed[player_idx]:
		return
	var h: Hero = players[player_idx].active_hero
	if h == null:
		return
	_hero_revealed[player_idx] = true
	GameBus.hero_revealed.emit(player_idx, h)

# Chamado quando a janela de reação fecha (pass ou carta REACTION jogada).
# Se o segmento ativo já completou ACTION e BONUS, encerra-o. Caso contrário,
# apenas sincroniza — o jogador ainda pode jogar a outra carta.
func _on_reaction_window_closed() -> void:
	_execute_pending_effect()
	# If an effect triggered a pick, pause here — _continue_after_pick() resumes the flow.
	if _pending_pick_player >= 0 or _pending_symbol_player >= 0 or _pending_ally_pick_player >= 0:
		_emit_sync()
		return
	var active := _active_segment_player
	if _segment_action_done[active] and _segment_bonus_done[active]:
		_finish_segment(active)
	else:
		_emit_sync()

func _finish_segment(player_idx: int) -> void:
	if not _segment_action_done[player_idx]:
		_consecutive_empty_turns += 1
	_segment_action_done[player_idx] = false
	_segment_bonus_done[player_idx]  = false
	_reaction_window_for = -1

	if player_idx == _turn_first_player:
		# Primeiro segmento da rodada concluído → passa para o oponente
		_active_segment_player = 1 - player_idx
		_emit_sync()
	else:
		# Segundo segmento concluído → rodada terminou
		# Se qualquer carta foi jogada nesta rodada o combate SEMPRE resolve,
		# independente de as mãos estarem vazias.
		var turn_had_cards := not players[0].turn_cards.is_empty() \
							or not players[1].turn_cards.is_empty()
		if turn_had_cards:
			_resolve_turn_combat()
		elif _consecutive_empty_turns >= 2 or _both_hands_empty():
			_run_combat_and_enter_end()
		else:
			_resolve_turn_combat()

func _both_hands_empty() -> bool:
	return players[0].hand.is_empty() and players[1].hand.is_empty()

func _resolve_turn_combat() -> void:
	var preview := _build_combat_preview()
	if not preview.is_empty():
		_notify_combat_preview(preview)
	# Captura os valores de dano para replicar combat_resolved ao(s) cliente(s).
	# A lambda dispara sincronamente dentro de CombatResolver.resolve_turn().
	var _cap := [0, 0]
	GameBus.combat_resolved.connect(
		func(d0: int, d1: int) -> void: _cap[0] = d0; _cap[1] = d1,
		CONNECT_ONE_SHOT
	)
	CombatResolver.resolve_turn(players[0], players[1])
	# Propaga o sinal ao cliente (servidor já recebeu acima via CombatResolver).
	if multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty():
		_notify_combat_resolved(_cap[0], _cap[1])
	# Resolve os efeitos AFTER_COMBAT enfileirados neste turno (dano já conhecido).
	_drain_after_combat_queue(_cap[0], _cap[1])
	# Execução Silenciosa: se marcado, oculta herói para o próximo combate
	for i in 2:
		if players[i].next_turn_stealth:
			_hero_revealed[i] = false
			players[i].next_turn_stealth = false
	# Cartas NÃO vão ao cemitério aqui — apenas turn_cards é limpo para o
	# próximo combate começar do zero. O cemitério só recebe as cartas na END.
	players[0].clear_turn_cards()
	players[1].clear_turn_cards()

	# Verifica vencedor geral (todos os heróis mortos)
	var w := _evaluate_winner()
	if w >= 0:
		_winner_index = w
		GameBus.game_over.emit(w)
		_notify_game_over(w)
		_run_combat_and_enter_end()
		return

	# Se qualquer herói ativo foi derrotado nesta rodada, encerra o turno
	if _any_active_hero_defeated():
		_run_combat_and_enter_end()
		return

	# Nenhuma baixa — inicia nova rodada, a menos que ambas as mãos estejam vazias
	if _both_hands_empty():
		_run_combat_and_enter_end()
		return
	for p in players:
		p.reset_hero_turn_state()
	_active_segment_player = battle.current_player_index
	_turn_first_player    = battle.current_player_index
	_segment_action_done   = [false, false]
	_segment_bonus_done    = [false, false]
	_reaction_window_for   = -1
	_emit_sync()

func _any_active_hero_defeated() -> bool:
	for p in players:
		if p.active_hero != null and p.active_hero.state == Hero.State.DEFEATED:
			return true
	return false

func _run_combat_and_enter_end() -> void:
	# Revela heróis que ainda não foram revelados e anuncia fim do turno de ação
	battle.current_phase = BattleManager.Phase.COMBAT
	for i in 2:
		var h: Hero = players[i].active_hero
		if h and not _hero_revealed[i]:
			_hero_revealed[i] = true
			GameBus.hero_revealed.emit(i, h)
	# Onda Reversa: carta vai ao fundo do deck em vez do cemitério
	for p in players:
		if p.pending_return_card != null:
			p.cards_this_battle.erase(p.pending_return_card)
			p.deck.append(p.pending_return_card)
			p.pending_return_card = null
	# Ciclo Vital: retorna carta à mão se herói ficou com HP cheio
	for p in players:
		if p.pending_heal_return_card != null:
			p.cards_this_battle.erase(p.pending_heal_return_card)
			p.hand.append(p.pending_heal_return_card)
			p.pending_heal_return_card = null
	# Todas as cartas jogadas no turno inteiro vão ao cemitério agora (END phase).
	for p in players:
		p.discard_pile.append_array(p.cards_this_battle)
	players[0].clear_combat_cards()
	players[1].clear_combat_cards()

	# Dispara passivas de fim de turno dos heróis ativos (ex: cura da Irena).
	# on_battle_end() aplica o efeito e retorna a descrição — GameState emite o sinal
	# localmente (servidor) e via RPC (clientes) para o popup aparecer em ambos.
	for i in 2:
		var h: Hero = players[i].active_hero
		if h != null:
			var desc := h.on_battle_end(players[i])
			if not desc.is_empty():
				var hero_idx := players[i].heroes.find(h)
				GameBus.skill_activated.emit(h, desc)
				_notify_skill_activated(i, hero_idx, desc)

	# Exausta heróis e devolve aos slots
	players[0].exhaust_active_hero()
	players[1].exhaust_active_hero()
	players[0].active_hero = null
	players[1].active_hero = null
	battle.current_phase = BattleManager.Phase.END
	_end_submitted = [false, false]
	_emit_sync()
	# Jogadores sem cartas na mão pulam o arsenal automaticamente
	for _auto_i in 2:
		if players[_auto_i].hand.is_empty() and not _end_submitted[_auto_i]:
			print("[TCG] Jogador %d sem cartas na mão — pulando arsenal automaticamente" % _auto_i)
			finish_end_battle(_auto_i, -1)

func get_end_submitted(player_idx: int) -> bool:
	if player_idx < 0 or player_idx > 1:
		return false
	return _end_submitted[player_idx]

func finish_end_battle(player_idx: int, arsenal_hand_index: int) -> bool:
	if _winner_index >= 0:
		return false
	if battle.current_phase != BattleManager.Phase.END:
		return false
	if player_idx < 0 or player_idx > 1:
		return false
	if _end_submitted[player_idx]:
		return false
	var p: Player = players[player_idx]
	var _arsenal_log := "sem arsenal"
	if arsenal_hand_index >= 0 and arsenal_hand_index < p.hand.size():
		_arsenal_log = "guardou '%s' no arsenal" % p.hand[arsenal_hand_index].card_name
		p.store_in_arsenal(p.hand[arsenal_hand_index])
	print("[TCG] Jogador %d (%s): encerrou turno — %s" % [player_idx, p.player_name, _arsenal_log])
	_end_submitted[player_idx] = true
	_emit_sync()
	if _end_submitted[0] and _end_submitted[1]:
		var active_idx := battle.current_player_index
		players[active_idx].draw_up_to(Player.HAND_SIZE_REFILL_DRAW)
		GameBus.battle_ended.emit(active_idx)
		battle.current_player_index = (active_idx + 1) % 2
		_begin_battle_for_active_player()
	return true

func _evaluate_winner() -> int:
	for i in 2:
		var dead := 0
		for h in players[i].heroes:
			if h.state == Hero.State.DEFEATED:
				dead += 1
		if dead >= 3:
			return 1 - i
	return -1

static func _shuffle_deck(deck: Array[Card]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Card = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp

static func _make_player(index: int, pname: String) -> Player:
	var p := Player.new()
	p.player_index = index
	p.player_name = pname
	p.heroes = [
		HeroIeldor.new(),
		HeroNissin.new(),
		HeroValkar.new(),
	]
	p.deck = DeckLoader.load_from_json("res://data/cards/taldorian_origins.json")
	p.playmat_key = 'default'
	return p

static func _make_player2(index: int, pname: String) -> Player:
	var p := Player.new()
	p.player_index = index
	p.player_name = pname
	p.heroes = [
		HeroIrena.new(),
		HeroPoppy.new(),
		HeroHakai.new(),
	]
	p.deck = DeckLoader.load_from_json("res://data/cards/taldorian_origins.json")
	p.playmat_key = 'default'
	return p

static func _make_player_from_deck(index: int, pname: String, deck_dict: Dictionary) -> Player:
	var p := Player.new()
	p.player_index = index
	p.player_name  = pname
	var hero_names: Variant = deck_dict.get("heroes", [])
	if hero_names is Array:
		for hname in hero_names:
			var h := _hero_from_name(str(hname))
			if h != null:
				p.heroes.append(h)
	if p.heroes.is_empty():
		p.heroes = [HeroPoppy.new(), HeroHakai.new(), HeroIrena.new()]
	var card_entries: Variant = deck_dict.get("cards", [])
	if card_entries is Array and not (card_entries as Array).is_empty():
		p.deck = _build_deck_from_entries(card_entries as Array)
	else:
		p.deck = DeckLoader.load_from_json("res://data/cards/taldorian_origins.json")
	p.sleeve_key  = str(deck_dict.get("sleeve",  "default"))
	p.playmat_key = str(deck_dict.get("playmat", "default"))
	return p


static func _hero_from_name(hero_name: String) -> Hero:
	match hero_name:
		"Poppy":              return HeroPoppy.new()
		"Hakai":              return HeroHakai.new()
		"Irena":              return HeroIrena.new()
		"Ieldor":             return HeroIeldor.new()
		"Nissin":             return HeroNissin.new()
		"Valkar":             return HeroValkar.new()
	push_warning("GameState: herói desconhecido '%s'" % hero_name)
	return null


static func _build_deck_from_entries(entries: Array) -> Array[Card]:
	var out: Array[Card] = []
	for entry in entries:
		var cname: String = str(entry.get("name", ""))
		var count: int    = int(entry.get("count", 1))
		var card_dict := Collection.get_card_dict(cname)
		if card_dict.is_empty():
			push_warning("GameState: carta '%s' não encontrada na coleção" % cname)
			continue
		for _i in count:
			out.append(Card.from_dict(card_dict))
	return out


@rpc("any_peer", "call_local", "reliable")
func rpc_submit_deck(deck_dict: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender     := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	_submitted_deck[player_idx] = deck_dict
	_deck_submitted[player_idx] = true
	# Em standalone (sem peers conectados) inicia assim que o host submete
	if multiplayer.get_peers().is_empty():
		start_match(_submitted_deck[0], {})
		_emit_sync()
	elif _deck_submitted[0] and _deck_submitted[1]:
		start_match(_submitted_deck[0], _submitted_deck[1])
		_emit_sync()


func _make_effect_ctx(player_idx: int, card: Card, from_arsenal: bool = false) -> CardEffectContext:
	var ctx := CardEffectContext.new()
	ctx.source_player        = players[player_idx]
	ctx.opponent_player      = players[1 - player_idx]
	ctx.source_card          = card
	ctx.played_from_arsenal  = from_arsenal
	ctx.hero_was_hidden      = _hero_was_hidden_at_play[player_idx]
	return ctx

static func _make_hero() -> Hero:
	var h := HeroPoppy.new()
	return h

func _build_combat_preview() -> Dictionary:
	var p0 := players[0]
	var p1 := players[1]
	var h0 := p0.active_hero
	var h1 := p1.active_hero
	if h0 == null or h1 == null:
		return {}

	var atk0 := h0.base_attack
	for card in p0.turn_cards:
		atk0 += card.attack_value
	atk0 += p0.pending_bonus_attack + p0.passive_attack_bonus + p0.battle_bonus_attack + p0.next_turn_bonus_attack

	var def0 := h0.base_defense
	for card in p0.turn_cards:
		def0 += card.defense_value
	def0 -= p0.next_defense_penalty
	def0 += p0.pending_bonus_defense

	var atk1 := h1.base_attack
	for card in p1.turn_cards:
		atk1 += card.attack_value
	atk1 += p1.pending_bonus_attack + p1.passive_attack_bonus + p1.battle_bonus_attack + p1.next_turn_bonus_attack

	var def1 := h1.base_defense
	for card in p1.turn_cards:
		def1 += card.defense_value
	def1 -= p1.next_defense_penalty
	def1 += p1.pending_bonus_defense

	return {
		"hero_0_idx":  p0.heroes.find(h0),
		"hero_1_idx":  p1.heroes.find(h1),
		"atk_0": atk0, "def_0": def0,
		"atk_1": atk1, "def_1": def1,
		"dmg_to_0": maxi(0, atk1 - def0),
		"dmg_to_1": maxi(0, atk0 - def1),
	}

@rpc("authority", "call_local", "reliable")
func _rpc_notify_combat_preview(data: Dictionary) -> void:
	GameBus.combat_preview_ready.emit(data)

# ── camada de rede ───────────────────────────────────────
# Clientes chamam esses métodos — nunca a lógica diretamente.

## Empurra o estado atual do servidor para todos os peers.
## Chamado pelo Board logo após carregar para garantir que o cliente
## receba o estado autoritativo antes de interagir com o mulligan.
func broadcast_state() -> void:
	if not multiplayer.is_server():
		return
	_emit_sync()

@rpc("any_peer", "call_local", "reliable")
func rpc_submit_mulligan(idx_a: int, idx_b: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	submit_opening_mulligan(player_idx, idx_a, idx_b)
	_emit_sync()

@rpc("any_peer", "call_local", "reliable")
func rpc_submit_hero(hero_slot: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	submit_hero_pick(player_idx, hero_slot)
	_emit_sync()

@rpc("any_peer", "call_local", "reliable")
func rpc_play_card(hand_idx: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	action_play_card(player_idx, hand_idx)
	_emit_sync()

@rpc("any_peer", "call_local", "reliable")
func rpc_play_from_arsenal() -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	action_play_from_arsenal(player_idx)
	_emit_sync()

@rpc("any_peer", "call_local", "reliable")
func rpc_pass() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	action_pass(player_idx)
	_emit_sync()

@rpc("any_peer", "call_local", "reliable")
func rpc_submit_card_pick(pick_indices: Array) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if _pending_pick_player != player_idx:
		return
	# Valida todos os índices recebidos
	# DECK_PEEK permite 0 ou 1 índice (0 = manter no topo, 1 = mover ao fundo)
	if _pending_pick_source == PickSource.DECK_PEEK:
		if pick_indices.size() > 1:
			return
	else:
		if pick_indices.size() != _pending_pick_count:
			return
		for pi in pick_indices:
			if pi < 0 or pi >= _pending_pick_indices.size():
				return
	var p := players[player_idx]
	match _pending_pick_source:
		PickSource.DECK:
			# Carta escolhida vai para a mão (índice único)
			var source_idx: int = _pending_pick_indices[pick_indices[0]]
			if source_idx < p.deck.size():
				p.hand.append(p.deck[source_idx])
				p.deck.remove_at(source_idx)
				GameBus.card_drawn.emit(player_idx)
			_shuffle_deck(p.deck)
			GameBus.deck_shuffled.emit(player_idx)
			_notify_deck_shuffled(player_idx)
		PickSource.GRAVEYARD:
			# Carta escolhida vai ao fundo do deck; compra draw_after cartas
			var source_idx: int = _pending_pick_indices[pick_indices[0]]
			if source_idx < p.discard_pile.size():
				var card := p.discard_pile[source_idx]
				p.discard_pile.remove_at(source_idx)
				p.deck.append(card)
			if _pending_pick_draw_after > 0:
				p.draw_cards(_pending_pick_draw_after)
		PickSource.HAND:
			# Carta escolhida da mão vai ao fundo do deck (índice único)
			var source_idx: int = _pending_pick_indices[pick_indices[0]]
			if source_idx < p.hand.size():
				var card := p.hand[source_idx]
				p.hand.remove_at(source_idx)
				p.deck.append(card)
			if _pending_pick_draw_after > 0:
				p.draw_cards(_pending_pick_draw_after)
		PickSource.HAND_DISCARD:
			# Cartas escolhidas vão ao cemitério — remover do maior para o menor índice
			var real_indices: Array[int] = []
			for pi in pick_indices:
				real_indices.append(_pending_pick_indices[pi])
			real_indices.sort()
			real_indices.reverse()   # maior primeiro para não deslocar índices
			for source_idx in real_indices:
				if source_idx < p.hand.size():
					p.discard_pile.append(p.hand[source_idx])
					p.hand.remove_at(source_idx)
			# Compra as cartas prometidas após o descarte
			if _pending_pick_draw_after > 0:
				p.draw_cards(_pending_pick_draw_after)
		PickSource.HAND_ARSENAL:
			# Carta escolhida da mão vai para o arsenal
			var source_idx: int = _pending_pick_indices[pick_indices[0]]
			if source_idx < p.hand.size():
				p.store_in_arsenal(p.hand[source_idx])
		PickSource.GRAVEYARD_ARSENAL:
			# Carta escolhida do cemitério vai para o arsenal face-up (Ecos do Passado)
			var source_idx: int = _pending_pick_indices[pick_indices[0]]
			if source_idx < p.discard_pile.size():
				var card := p.discard_pile[source_idx]
				p.discard_pile.remove_at(source_idx)
				if not p.arsenal.is_empty():
					p.deck.append(p.arsenal.pop_back())
				p.arsenal.append(card)
				p.arsenal_face_up = true   # efeito explícito: virado para cima
		PickSource.DECK_PEEK:
			# pick_indices vazio → manter no topo (no-op)
			# pick_indices == [0] → mover ao fundo do deck
			if not pick_indices.is_empty() and not p.deck.is_empty():
				p.deck.push_back(p.deck.pop_front())
				print("[TCG]   ↕ Dois Passos à Frente (J%d): carta movida ao fundo do deck" % player_idx)
			else:
				print("[TCG]   ↑ Dois Passos à Frente (J%d): carta mantida no topo do deck" % player_idx)
	var followup    := _pending_both_recycle_followup
	var instruction := _pending_pick_instruction   # preserva antes de limpar
	_pending_pick_player           = -1
	_pending_pick_source           = PickSource.DECK
	_pending_pick_count            = 1
	_pending_pick_draw_after       = 0
	_pending_pick_instruction      = ""
	_pending_pick_indices.clear()
	_pending_both_recycle_followup = -1
	# Ecos do Passado: inicia o pick do segundo jogador (repassa a instrução)
	if followup >= 0 and not players[followup].discard_pile.is_empty():
		var idxs: Array[int] = []
		for i in players[followup].discard_pile.size():
			idxs.append(i)
		begin_graveyard_arsenal_pick(followup, idxs, -1, instruction)
	# Se o pick foi disparado por um efeito durante o fechamento da janela de reação
	# e não há outro pick pendente, continua o fluxo do segmento.
	if _pending_pick_player < 0 and _pending_symbol_player < 0 \
			and battle.current_phase == BattleManager.Phase.ACTION:
		var active := _active_segment_player
		if _segment_action_done[active] and _segment_bonus_done[active]:
			_finish_segment(active)
			return
	_emit_sync()

@rpc("any_peer", "call_local", "reliable")
func rpc_submit_symbol_pick(chosen_symbols: Array) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if _pending_symbol_player != player_idx:
		return
	if chosen_symbols.size() != _pending_symbol_count:
		return
	# Valida e adiciona os símbolos à carta
	for sym in chosen_symbols:
		var sid := str(sym)
		if GameSymbols.is_valid(sid) and _pending_symbol_card != null:
			_pending_symbol_card.symbols.append(sid)
	# Guarda referências antes de limpar — precisamos re-verificar skill com os novos símbolos
	var resolved_player := _pending_symbol_player
	var resolved_card   := _pending_symbol_card
	var continue_reaction := _pending_symbol_after_reaction
	_pending_symbol_player         = -1
	_pending_symbol_count          = 0
	_pending_symbol_card           = null
	_pending_symbol_after_reaction = false
	# Re-verifica a skill agora que os símbolos foram adicionados à carta
	if resolved_card != null:
		_on_card_added_to_play(resolved_player, resolved_card)
	if continue_reaction:
		_on_reaction_window_closed()
	else:
		_emit_sync()

@rpc("any_peer", "call_local", "reliable")
func rpc_finish_battle(arsenal_idx: int) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	finish_end_battle(player_idx, arsenal_idx)

# ── sincronização de estado ──────────────────────────────

# Recebe a fase e o snapshot do estado do servidor, aplica localmente
# e dispara os sinais de UI — garante que cliente e servidor fiquem alinhados.
@rpc("authority", "call_local", "reliable")
func _sync_state(phase_str: String, snapshot: Dictionary) -> void:
	battle.current_phase = _phase_from_string(phase_str)
	_apply_snapshot(snapshot)
	GameBus.phase_changed.emit(phase_str)
	GameBus.state_synced.emit()

@rpc("any_peer", "call_local", "reliable")
func rpc_forfeit() -> void:
	if not multiplayer.is_server():
		return
	if _winner_index >= 0:
		return
	var forfeiting_peer := multiplayer.get_remote_sender_id()
	var forfeiting_idx := _peer_to_player_index(forfeiting_peer)
	if forfeiting_idx < 0:
		return
	var winner_idx := 1 - forfeiting_idx
	_winner_index = winner_idx
	GameBus.game_over.emit(winner_idx)
	_notify_game_over(winner_idx)

# Notifica apenas o cliente (host já emitiu diretamente).
@rpc("authority", "call_remote", "reliable")
func _rpc_notify_game_over(winner_idx: int) -> void:
	GameBus.game_over.emit(winner_idx)

# Replica combat_resolved para o cliente (o servidor já o recebeu via CombatResolver).
@rpc("authority", "call_remote", "reliable")
func _rpc_notify_combat_resolved(dmg_p0: int, dmg_p1: int) -> void:
	GameBus.combat_resolved.emit(dmg_p0, dmg_p1)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_deck_shuffled(player_idx: int) -> void:
	GameBus.deck_shuffled.emit(player_idx)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_card_played(player_idx: int, card_data: Dictionary) -> void:
	var card := Card.from_dict(card_data)
	GameBus.card_played.emit(player_idx, card)

func _emit_card_played(player_idx: int, card: Card) -> void:
	GameBus.card_played.emit(player_idx, card)
	_notify_card_played(player_idx, _serialize_cards([card])[0])

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_skill_activated(player_idx: int, hero_idx: int, skill_name: String) -> void:
	if player_idx < 0 or player_idx >= players.size():
		return
	if hero_idx < 0 or hero_idx >= players[player_idx].heroes.size():
		return
	GameBus.skill_activated.emit(players[player_idx].heroes[hero_idx], skill_name)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_backline_arrow(source_player_idx: int, source_hero_idx: int, target_player_idx: int, target_hero_idx: int) -> void:
	GameBus.backline_arrow_fired.emit(source_player_idx, source_hero_idx, target_player_idx, target_hero_idx)

# Serializa o estado mínimo necessário para o cliente redesenhar a UI.
func _build_snapshot() -> Dictionary:
	var snap := { "players": [] }
	for p in players:
		var heroes_data: Array = []
		for h in p.heroes:
			heroes_data.append({ "hp": h.current_hp, "state": int(h.state), "backline_revealed": h.is_backline_revealed, "damage_shield": h.damage_shield })
		snap["players"].append({
			"hand":                 _serialize_cards(p.hand),
			"arsenal":              _serialize_cards(p.arsenal),
			"arsenal_face_up":      p.arsenal_face_up,
			"turn_cards":          _serialize_cards(p.turn_cards),
			"heroes":               heroes_data,
			"active_hero_idx":      p.heroes.find(p.active_hero),
			"sleeve_key":           p.sleeve_key,
			"playmat_key":          p.playmat_key,
			"discard_pile":         _serialize_cards(p.discard_pile),
			"pending_bonus_attack":            p.pending_bonus_attack,
			"pending_bonus_defense":           p.pending_bonus_defense,
			"next_defense_penalty":            p.next_defense_penalty,
			"passive_attack_bonus":            (p.active_hero.get_passive_attack_bonus() if p.active_hero != null else 0),
			"battle_bonus_attack":               p.battle_bonus_attack,
			"next_turn_bonus_attack":         p.next_turn_bonus_attack,
		})
	# estado do mulligan de abertura
	snap["opening_mulligan_done"] = [_opening_mulligan_done[0], _opening_mulligan_done[1]]
	# estado da fase de escolha de herói
	snap["next_hero_pick_player"] = _next_hero_pick_player
	snap["hero_submitted"]        = [_hero_submitted[0], _hero_submitted[1]]
	# estado da fase de ação (rodadas + timing)
	snap["active_segment_player"]    = _active_segment_player
	snap["round_first_player"]       = _turn_first_player
	snap["segment_action_done"]      = [_segment_action_done[0], _segment_action_done[1]]
	snap["segment_bonus_done"]       = [_segment_bonus_done[0],  _segment_bonus_done[1]]
	snap["reaction_window_for"]      = _reaction_window_for
	snap["consecutive_empty_rounds"] = _consecutive_empty_turns
	snap["hero_revealed"]            = [_hero_revealed[0], _hero_revealed[1]]
	snap["end_submitted"]            = [_end_submitted[0], _end_submitted[1]]
	# pick de carta pendente
	snap["pending_pick_player"]      = _pending_pick_player
	snap["pending_pick_source"]      = int(_pending_pick_source)
	snap["pending_pick_count"]       = _pending_pick_count
	snap["pending_pick_draw_after"]  = _pending_pick_draw_after
	snap["pending_pick_instruction"] = _pending_pick_instruction
	if _pending_pick_player >= 0 and _pending_pick_player < players.size():
		var source_arr := _pick_source_array(_pending_pick_player)
		var show: Array[Card] = []
		for idx in _pending_pick_indices:
			if idx < source_arr.size():
				show.append(source_arr[idx])
		snap["pending_pick_cards"] = _serialize_cards(show)
	else:
		snap["pending_pick_cards"] = []
	# pick de herói aliado pendente
	snap["pending_ally_pick_player"] = _pending_ally_pick_player
	snap["pending_ally_pick_action"] = _pending_ally_pick_action
	snap["pending_ally_pick_amount"] = _pending_ally_pick_amount
	# pick de símbolo pendente
	snap["pending_symbol_player"] = _pending_symbol_player
	snap["pending_symbol_count"]  = _pending_symbol_count
	# habilidades de retaguarda interativas
	snap["backline_awaiting_response"] = _backline_awaiting_response
	snap["backline_awaiting_target"]   = _backline_awaiting_target
	snap["backline_current_player"]    = _backline_current_player
	snap["backline_current_hero_idx"]  = _backline_current_hero_idx
	return snap

static func _serialize_cards(cards: Array[Card]) -> Array:
	var out: Array = []
	for c in cards:
		out.append({
			"name":          c.card_name,
			"timing":        Card.TimingType.keys()[c.timing],
			"attack_value":  c.attack_value,
			"defense_value": c.defense_value,
			"symbols":       Array(c.symbols),
			"stealth":       c.is_stealth,
			"art_key":       c.art_key,
			"description":   c.description,
			"rarity":        Card.Rarity.keys()[c.rarity],
		})
	return out

func _apply_snapshot(snap: Dictionary) -> void:
	if snap.is_empty() or players.is_empty():
		return
	var plist: Array = snap.get("players", [])
	for i in min(plist.size(), players.size()):
		var pd: Dictionary = plist[i]
		var p: Player = players[i]
		# O servidor já possui os objetos Card originais (com effects intactos).
		# Sobrescrever com cópias desserializadas (sem effects) quebraria a execução
		# de efeitos. Apenas o cliente precisa reconstruir essas listas.
		if not multiplayer.is_server():
			p.hand           = _deserialize_cards(pd.get("hand", []))
			p.arsenal        = _deserialize_cards(pd.get("arsenal", []))
			p.turn_cards    = _deserialize_cards(pd.get("turn_cards", []))
		p.arsenal_face_up = pd.get("arsenal_face_up", false)
		p.pending_bonus_attack             = pd.get("pending_bonus_attack",             0)
		p.pending_bonus_defense            = pd.get("pending_bonus_defense",            0)
		p.next_defense_penalty             = pd.get("next_defense_penalty",             0)
		p.passive_attack_bonus             = pd.get("passive_attack_bonus",             0)
		p.battle_bonus_attack                = pd.get("battle_bonus_attack",                0)
		p.next_turn_bonus_attack          = pd.get("next_turn_bonus_attack",          0)
		if not multiplayer.is_server():
			var dp: Array = pd.get("discard_pile", [])
			p.discard_pile = _deserialize_cards(dp)
		var hlist: Array = pd.get("heroes", [])
		for j in min(hlist.size(), p.heroes.size()):
			p.heroes[j].current_hp          = hlist[j].get("hp",                p.heroes[j].current_hp)
			p.heroes[j].state               = hlist[j].get("state",             int(p.heroes[j].state))
			p.heroes[j].is_backline_revealed = hlist[j].get("backline_revealed", false)
			p.heroes[j].damage_shield        = hlist[j].get("damage_shield",     0)
		var active_idx: int = pd.get("active_hero_idx", -1)
		p.active_hero  = p.heroes[active_idx] if active_idx >= 0 else null
		p.sleeve_key   = pd.get("sleeve_key",  p.sleeve_key)
		p.playmat_key  = pd.get("playmat_key", p.playmat_key)
	# mulligan de abertura — cliente precisa saber quando já confirmou
	var omd: Array = snap.get("opening_mulligan_done", [])
	if omd.size() >= 2:
		_opening_mulligan_done[0] = omd[0]
		_opening_mulligan_done[1] = omd[1]
	# estado da escolha de herói — necessário para o cliente saber de quem é a vez
	_next_hero_pick_player = snap.get("next_hero_pick_player", _next_hero_pick_player)
	var hs: Array = snap.get("hero_submitted", [])
	if hs.size() >= 2:
		_hero_submitted[0] = hs[0]
		_hero_submitted[1] = hs[1]
	_active_segment_player    = snap.get("active_segment_player",    _active_segment_player)
	_turn_first_player       = snap.get("round_first_player",       _turn_first_player)
	_reaction_window_for      = snap.get("reaction_window_for",      _reaction_window_for)
	_consecutive_empty_turns = snap.get("consecutive_empty_rounds", _consecutive_empty_turns)
	var sad: Array = snap.get("segment_action_done", [])
	if sad.size() >= 2:
		_segment_action_done[0] = sad[0]
		_segment_action_done[1] = sad[1]
	var sbd: Array = snap.get("segment_bonus_done", [])
	if sbd.size() >= 2:
		_segment_bonus_done[0] = sbd[0]
		_segment_bonus_done[1] = sbd[1]
	var hr: Array = snap.get("hero_revealed", [])
	if hr.size() >= 2:
		_hero_revealed[0] = hr[0]
		_hero_revealed[1] = hr[1]
	var es: Array = snap.get("end_submitted", [])
	if es.size() >= 2:
		_end_submitted[0] = es[0]
		_end_submitted[1] = es[1]
	# estado de pick pendente
	_pending_pick_player      = snap.get("pending_pick_player",      -1)
	_pending_pick_source      = snap.get("pending_pick_source",      int(PickSource.DECK)) as PickSource
	_pending_pick_count       = snap.get("pending_pick_count",       1)
	_pending_pick_draw_after  = snap.get("pending_pick_draw_after",  0)
	_pending_pick_instruction = snap.get("pending_pick_instruction", "")
	if not multiplayer.is_server():
		_pending_pick_cards_display = _deserialize_cards(snap.get("pending_pick_cards", []))
	_pending_ally_pick_player = snap.get("pending_ally_pick_player", -1)
	_pending_ally_pick_action = snap.get("pending_ally_pick_action", "")
	_pending_ally_pick_amount = snap.get("pending_ally_pick_amount", 0)
	_pending_symbol_player = snap.get("pending_symbol_player", -1)
	_pending_symbol_count  = snap.get("pending_symbol_count",  0)
	_backline_awaiting_response = snap.get("backline_awaiting_response", false)
	_backline_awaiting_target   = snap.get("backline_awaiting_target",   false)
	_backline_current_player    = snap.get("backline_current_player",    -1)
	_backline_current_hero_idx  = snap.get("backline_current_hero_idx",  -1)

static func _deserialize_cards(arr: Array) -> Array[Card]:
	var out: Array[Card] = []
	for d in arr:
		out.append(Card.from_dict(d))
	return out

static func _phase_from_string(s: String) -> BattleManager.Phase:
	match s:
		"OPENING_MULLIGAN": return BattleManager.Phase.OPENING_MULLIGAN
		"DRAW":             return BattleManager.Phase.DRAW
		"HERO_SELECTION":   return BattleManager.Phase.HERO_SELECTION
		"BACKLINE_ABILITY": return BattleManager.Phase.BACKLINE_ABILITY
		"ACTION":           return BattleManager.Phase.ACTION
		"COMBAT":           return BattleManager.Phase.COMBAT
		"END":              return BattleManager.Phase.END
		_:                  return BattleManager.Phase.OPENING_MULLIGAN

# ── helper ───────────────────────────────────────────────

# Resolve o player_index do remetente do RPC E, no servidor multi-sala, roteia
# `_m` para a partida desse peer. Chamado no topo de todos os handlers rpc_*, o
# que garante que o restante do corpo opere sobre a partida correta.
func _peer_to_player_index(peer_id: int) -> int:
	# Modelo A multi-sala: roteia _m para a partida do peer (servidor).
	if multiplayer.is_server() and _peer_to_match.has(peer_id):
		var mid: int = _peer_to_match[peer_id]
		if _matches.has(mid):
			_m = _matches[mid]
			return int(_m._match_peer_to_idx.get(peer_id, -1))
	# Mapeamento explícito da partida atual (já roteada, ou lobby com participantes).
	if not _match_peer_to_idx.is_empty():
		return int(_match_peer_to_idx.get(peer_id, -1))
	# Fallback (lobby/standalone): peer<=1 = host = player 0; qualquer outro = player 1.
	return 0 if peer_id <= 1 else 1

## Servidor: registra uma nova partida entre dois peers e a torna a partida ativa.
## Cria um MatchState isolado, mapeia peer→player_index e peer→match_id. Retorna
## o id da partida. Usado pelo MatchService quando uma sala enche (Modelo A).
func register_match(p_peer0: int, p_peer1: int) -> int:
	# Limpa partidas anteriores destes peers (evita leak ao rejogar).
	_cleanup_peer_match(p_peer0)
	_cleanup_peer_match(p_peer1)
	var mid := _next_match_id
	_next_match_id += 1
	var m := MatchState.new()
	m._match_peer_to_idx = { p_peer0: 0, p_peer1: 1 }
	_matches[mid] = m
	_peer_to_match[p_peer0] = mid
	_peer_to_match[p_peer1] = mid
	_m = m
	return mid

## Encerra uma partida e libera seu roteamento (servidor).
func end_match(p_match_id: int) -> void:
	if not _matches.has(p_match_id):
		return
	for peer in _peer_to_match.keys():
		if _peer_to_match[peer] == p_match_id:
			_peer_to_match.erase(peer)
	_matches.erase(p_match_id)

## Encerra a partida em que `peer_id` está, se houver (servidor).
func _cleanup_peer_match(peer_id: int) -> void:
	if _peer_to_match.has(peer_id):
		end_match(_peer_to_match[peer_id])

## Servidor: um peer caiu. Se estava numa partida em andamento, o oponente vence;
## em seguida a partida é encerrada e seu roteamento liberado.
func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server() or not _peer_to_match.has(peer_id):
		return
	var mid: int = _peer_to_match[peer_id]
	if _matches.has(mid):
		var m: MatchState = _matches[mid]
		if m._winner_index < 0:
			var leaver_idx: int = int(m._match_peer_to_idx.get(peer_id, -1))
			if leaver_idx >= 0:
				var winner_idx := 1 - leaver_idx
				m._winner_index = winner_idx
				for other_peer in m._match_peer_to_idx.keys():
					if other_peer != peer_id:
						_rpc_notify_game_over.rpc_id(other_peer, winner_idx)
	end_match(mid)

## Envia o estado autoritativo da partida atual (_m). No servidor multi-sala,
## direciona só aos 2 peers da partida; no lobby/standalone, broadcast (call_local).
func _emit_sync() -> void:
	var phase := battle.phase_to_string(battle.current_phase)
	var snap := _build_snapshot()
	if multiplayer.is_server() and not _m._match_peer_to_idx.is_empty():
		for peer in _m._match_peer_to_idx.keys():
			_sync_state.rpc_id(peer, phase, snap)
		# Replica o antigo call_local: o servidor aplica em si mesmo também,
		# preservando exatamente a evolução de estado da Fase 2.1.
		_sync_state(phase, snap)
	else:
		_sync_state.rpc(phase, snap)

# ── Notificações visuais direcionadas (Fase 2.2b) ────────────────────────────
# Eventos transientes (VFX, fim de jogo, preview) vão SÓ aos 2 peers da partida
# atual (_m). No lobby host-as-player (_match_peer_to_idx vazio) faz broadcast,
# preservando o comportamento anterior. Estes RPCs são call_remote: o servidor
# não os executa em si mesmo.
func _match_targets() -> Array:
	if multiplayer.is_server() and not _m._match_peer_to_idx.is_empty():
		return _m._match_peer_to_idx.keys()
	return []

func _notify_init_players(deck0: Dictionary, deck1: Dictionary) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_init_players", deck0, deck1)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_init_players", deck0, deck1)

func _notify_skill_activated(player_idx: int, hero_idx: int, skill_name: String) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_skill_activated", player_idx, hero_idx, skill_name)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_skill_activated", player_idx, hero_idx, skill_name)

## Emite skill_activated localmente (servidor) e via RPC (clientes) a partir de um
## Hero. Usado por passivas que disparam de dentro de hooks (ex: Hakai em combate),
## garantindo que o popup/VFX apareça em ambos os lados. Server-only.
func notify_skill_activated(hero: Hero, skill_name: String) -> void:
	for i in players.size():
		var hero_idx := players[i].heroes.find(hero)
		if hero_idx != -1:
			GameBus.skill_activated.emit(hero, skill_name)
			_notify_skill_activated(i, hero_idx, skill_name)
			return

func _notify_backline_arrow(source_player_idx: int, source_hero_idx: int, target_player_idx: int, target_hero_idx: int) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_backline_arrow", source_player_idx, source_hero_idx, target_player_idx, target_hero_idx)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_backline_arrow", source_player_idx, source_hero_idx, target_player_idx, target_hero_idx)

func _notify_game_over(winner_idx: int) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_game_over", winner_idx)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_game_over", winner_idx)

func _notify_combat_preview(data: Dictionary) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_combat_preview", data)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_combat_preview", data)

func _notify_combat_resolved(dmg_p0: int, dmg_p1: int) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_combat_resolved", dmg_p0, dmg_p1)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_combat_resolved", dmg_p0, dmg_p1)

func _notify_deck_shuffled(player_idx: int) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_deck_shuffled", player_idx)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_deck_shuffled", player_idx)

func _notify_card_played(player_idx: int, card_data: Dictionary) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_card_played", player_idx, card_data)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_card_played", player_idx, card_data)

## Aplica dano direto ao herói ativo do jogador alvo, fora do fluxo de combat_resolver.
## Usado por efeitos como Tiro de Oportunidade e Ricochetear.
func _deal_direct_damage(target_player_idx: int, amount: int) -> void:
	if amount <= 0 or target_player_idx < 0 or target_player_idx > 1:
		return
	var tp: Player = players[target_player_idx]
	var hero: Hero = tp.active_hero
	if hero == null or not hero.is_alive():
		return
	var ctx := TurnContext.new()
	ctx.defender = hero
	ctx.defender_player = tp
	hero.take_damage(amount, ctx)
	GameBus.hero_damaged.emit(hero, amount)
	var w := _evaluate_winner()
	if w >= 0:
		_winner_index = w
		GameBus.game_over.emit(w)
		_notify_game_over(w)
	
static func _debug_force_card_to_hand(p: Player, card_name: String) -> void:
	for i in p.deck.size():
		if p.deck[i].card_name == card_name:
			p.hand.append(p.deck[i])
			p.deck.remove_at(i)
			return

## DEBUG — força a carta com `card_id` para a posição `hand_slot` da mão do jogador.
## Busca no deck; se não encontrar, não faz nada.
## hand_slot = 0 → primeira carta da mão | hand_slot = -1 → última carta da mão.
func _debug_force_card_in_hand(player_idx: int, card_id: int, hand_slot: int = 0) -> void:
	var p := players[player_idx]
	for i in p.deck.size():
		if p.deck[i].id == card_id:
			var card := p.deck[i]
			p.deck.remove_at(i)
			var insert_pos := hand_slot if hand_slot >= 0 else p.hand.size()
			insert_pos = clampi(insert_pos, 0, p.hand.size())
			p.hand.insert(insert_pos, card)
			print("[DEBUG] Carta '%s' (id:%d) inserida na posição %d da mão do Jogador %d" % [
				card.card_name, card_id, insert_pos, player_idx
			])
			return
	print("[DEBUG] Carta id:%d não encontrada no deck do Jogador %d" % [card_id, player_idx])

## DEBUG — move a carta com `card_id` para a frente do deck ANTES da distribuição inicial.
## Assim ela será a primeira carta sacada e vai para a mão automaticamente.
static func _debug_move_card_to_deck_front(p: Player, card_id: int) -> void:
	for i in p.deck.size():
		if p.deck[i].id == card_id:
			var card := p.deck[i]
			p.deck.remove_at(i)
			p.deck.push_front(card)
			print("[DEBUG] Carta '%s' (id:%d) movida para a frente do deck — será sacada na mão" % [
				card.card_name, card_id
			])
			return
	print("[DEBUG] Carta id:%d não encontrada no deck" % card_id)
