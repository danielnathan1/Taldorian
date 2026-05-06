# src/core/game_state.gd
extends Node

var players: Array[Player] = []
var turn: TurnManager = TurnManager.new()

var _opening_mulligan_done: Array[bool] = [false, false]
var _hero_submitted: Array[bool] = [false, false]
var _next_hero_pick_player: int = 0
var _winner_index: int = -1

# ── estado da fase ACTION ────────────────────────────────
var _active_segment_player: int       = 0
var _round_first_player: int          = 0    # quem abriu a rodada atual
var _segment_action_done: Array[bool] = [false, false]
var _segment_bonus_done:  Array[bool] = [false, false]
var _reaction_window_for: int         = -1   # -1=fechada; 0|1=quem pode reagir
var _consecutive_empty_rounds: int    = 0    # rodadas sem ACTION jogado
var _hero_revealed: Array[bool]       = [false, false]  # herói revelado ao oponente
var _end_submitted: Array[bool]       = [false, false]  # jogador confirmou arsenal na fase END

# Efeito pendente — disparado após a janela de reação fechar.
# Garante que reação resolve antes da ação/ação-bônus.
var _pending_effect_card: Card          = null
var _pending_effect_player: int         = -1
var _pending_effect_from_arsenal: bool  = false

# Pick de símbolo pendente — aguarda o jogador escolher elementos via PickSymbol overlay.
var _pending_symbol_player: int            = -1
var _pending_symbol_count: int             = 0
var _pending_symbol_card: Card             = null   # carta que receberá os símbolos (servidor)
var _pending_symbol_after_reaction: bool   = false  # se true, chama _on_reaction_window_closed() após resolver

# Pick de carta pendente — aguarda o jogador escolher uma carta via PickCard overlay.
enum PickSource { DECK, GRAVEYARD, HAND, HAND_DISCARD }
var _pending_pick_player: int                = -1
var _pending_pick_source: PickSource         = PickSource.DECK
var _pending_pick_count: int                 = 1    # quantas cartas o jogador deve selecionar
var _pending_pick_draw_after: int            = 0    # comprar N cartas após resolver o pick
var _pending_pick_indices: Array[int]        = []   # índices na fonte (deck, graveyard ou mão)
var _pending_pick_cards_display: Array[Card] = []   # cópias p/ exibição (cliente)

func _ready() -> void:
	if multiplayer.is_server():
		start_match()
func start_match() -> void:
	players = [_make_player(0, "Jogador 1"), _make_player2(1, "Jogador 2")]
	turn.players = players
	turn.current_player_index = 0
	_winner_index = -1
	for p in players:
		_shuffle_deck(p.deck)
	# Forçar cartas ANTES do draw inicial — assim draw_up_to completa até o cap
	# sem estourar o limite e sem causar descartes extras no mulligan.
	#_debug_force_card_to_hand(players[0], "Planos Futuros")
	#_debug_force_card_to_hand(players[0], "Planos Futuros")
	for p in players:
		p.draw_up_to(Player.HAND_CAP_START)
	_opening_mulligan_done = [false, false]
	turn.emit_phase_changed()

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
	if turn.current_phase != TurnManager.Phase.HERO_SELECTION:
		return -1
	if _hero_submitted[0] and _hero_submitted[1]:
		return -1
	return _next_hero_pick_player

func submit_opening_mulligan(player_idx: int, idx_a: int, idx_b: int) -> bool:
	if _winner_index >= 0:
		return false
	if turn.current_phase != TurnManager.Phase.OPENING_MULLIGAN:
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
	print(_opening_mulligan_done)
	if _opening_mulligan_done[0] and _opening_mulligan_done[1]:
		turn.current_player_index = 0
		_begin_turn_for_active_player()
	else:
		turn.emit_phase_changed()
	return true

func _begin_turn_for_active_player() -> void:
	if _winner_index >= 0:
		return
	var idx := turn.current_player_index
	var player: Player = players[idx]

	# 1. Fase DRAW — compra cartas e sincroniza
	turn.current_phase = TurnManager.Phase.DRAW
	GameBus.turn_started.emit(idx)
	player.draw_up_to(Player.HAND_CAP_START)
	if player.hand.size() >= 2:
		var hn := player.hand.size()
		player.send_cards_to_bottom([player.hand[hn - 1], player.hand[hn - 2]])
	player._check_rotation()
	_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())

	# 2. Fase HERO_SELECTION
	turn.current_phase = TurnManager.Phase.HERO_SELECTION
	_hero_submitted = [false, false]
	_next_hero_pick_player = idx
	_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())

func submit_hero_pick(player_idx: int, hero_slot: int) -> bool:
	if _winner_index >= 0:
		return false
	if turn.current_phase != TurnManager.Phase.HERO_SELECTION:
		return false
	if player_idx < 0 or player_idx > 1 or hero_slot < 0 or hero_slot > 2:
		return false
	if player_idx != _next_hero_pick_player:
		return false
	if _hero_submitted[player_idx]:
		return false
	var pl: Player = players[player_idx]
	var hero: Hero = pl.heroes[hero_slot]
	if hero not in pl.get_available_heroes():
		return false
	pl.choose_hero(hero)
	hero.on_turn_start(pl)
	GameBus.hero_chosen.emit(player_idx, hero)
	_hero_submitted[player_idx] = true
	if _hero_submitted[0] and _hero_submitted[1]:
		turn.current_phase = TurnManager.Phase.ACTION
		_reset_action_phase_state()
		turn.emit_phase_changed()
	else:
		_next_hero_pick_player = 1 - player_idx
		turn.emit_phase_changed()
	return true

func action_play_card(player_idx: int, hand_idx: int) -> bool:
	if _winner_index >= 0:
		return false
	if turn.current_phase != TurnManager.Phase.ACTION:
		return false
	if _pending_pick_player >= 0:
		return false
	if _pending_symbol_player >= 0:
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
			pl.cards_this_turn.append(card)
			pl.round_cards.append(card)
			_try_reveal_hero(player_idx, card)
			_on_card_added_to_play(player_idx, card)
			_segment_action_done[player_idx] = true
			_consecutive_empty_rounds = 0
			_pending_effect_card         = card
			_pending_effect_player       = player_idx
			_pending_effect_from_arsenal = false
			card.execute_pre_window_effects(_make_effect_ctx(player_idx, card))
			_emit_card_played(player_idx, card)
			if players[player_idx].pending_cancel_reaction:
				_reaction_window_for = -1
				_on_reaction_window_closed()
			else:
				_reaction_window_for = 1 - player_idx
				GameBus.reaction_window_opened.emit(1 - player_idx)
				_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())
			return true

		Card.TimingType.BONUS_ACTION:
			if player_idx != _active_segment_player: return false
			if _segment_bonus_done[player_idx]: return false
			if _reaction_window_for != -1: return false
			pl.hand.remove_at(hand_idx)
			pl.cards_this_turn.append(card)
			pl.round_cards.append(card)
			_try_reveal_hero(player_idx, card)
			_on_card_added_to_play(player_idx, card)
			_segment_bonus_done[player_idx] = true
			_pending_effect_card         = card
			_pending_effect_player       = player_idx
			_pending_effect_from_arsenal = false
			card.execute_pre_window_effects(_make_effect_ctx(player_idx, card))
			_emit_card_played(player_idx, card)
			_reaction_window_for = 1 - player_idx
			GameBus.reaction_window_opened.emit(1 - player_idx)
			_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())
			return true

		Card.TimingType.REACTION:
			if _reaction_window_for != player_idx: return false
			pl.hand.remove_at(hand_idx)
			pl.cards_this_turn.append(card)
			pl.round_cards.append(card)
			_try_reveal_hero(player_idx, card)
			_on_card_added_to_play(player_idx, card)
			_reaction_window_for = -1
			card.execute_effects(_make_effect_ctx(player_idx, card))
			_emit_card_played(player_idx, card)
			# Se o efeito abriu um symbol pick, pausar — o pick resolverá o fluxo
			if _pending_symbol_player >= 0:
				_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())
				return true
			_on_reaction_window_closed()
			return true

	return false

func action_play_from_arsenal(player_idx: int) -> bool:
	if _winner_index >= 0 or turn.current_phase != TurnManager.Phase.ACTION:
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
			pl.cards_this_turn.append(card)
			pl.round_cards.append(card)
			_try_reveal_hero(player_idx, card)
			_on_card_added_to_play(player_idx, card)
			_segment_action_done[player_idx] = true
			_consecutive_empty_rounds = 0
			_pending_effect_card         = card
			_pending_effect_player       = player_idx
			_pending_effect_from_arsenal = true
			card.execute_pre_window_effects(_make_effect_ctx(player_idx, card, true))
			_emit_card_played(player_idx, card)
			if players[player_idx].pending_cancel_reaction:
				_reaction_window_for = -1
				_on_reaction_window_closed()
			else:
				_reaction_window_for = 1 - player_idx
				GameBus.reaction_window_opened.emit(1 - player_idx)
				_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())
			return true
		Card.TimingType.BONUS_ACTION:
			if player_idx != _active_segment_player: return false
			if _segment_bonus_done[player_idx]: return false
			if _reaction_window_for != -1: return false
			pl.arsenal.remove_at(0)
			pl.cards_this_turn.append(card)
			pl.round_cards.append(card)
			_try_reveal_hero(player_idx, card)
			_on_card_added_to_play(player_idx, card)
			_segment_bonus_done[player_idx] = true
			_pending_effect_card         = card
			_pending_effect_player       = player_idx
			_pending_effect_from_arsenal = true
			card.execute_pre_window_effects(_make_effect_ctx(player_idx, card, true))
			_emit_card_played(player_idx, card)
			_reaction_window_for = 1 - player_idx
			GameBus.reaction_window_opened.emit(1 - player_idx)
			_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())
			return true
		Card.TimingType.REACTION:
			if _reaction_window_for != player_idx: return false
			pl.arsenal.remove_at(0)
			pl.cards_this_turn.append(card)
			pl.round_cards.append(card)
			_try_reveal_hero(player_idx, card)
			_on_card_added_to_play(player_idx, card)
			_reaction_window_for = -1
			card.execute_effects(_make_effect_ctx(player_idx, card, true))
			_emit_card_played(player_idx, card)
			if _pending_symbol_player >= 0:
				_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())
				return true
			_on_reaction_window_closed()
			return true
	return false

func action_pass(player_idx: int) -> bool:
	if _winner_index >= 0:
		return false
	if turn.current_phase != TurnManager.Phase.ACTION:
		return false
	# Não permite avançar enquanto um pick está aguardando resolução
	if _pending_pick_player >= 0:
		return false
	if _pending_symbol_player >= 0:
		return false

	# Passar janela de reação
	if _reaction_window_for == player_idx:
		_reaction_window_for = -1
		_on_reaction_window_closed()
		return true

	# Passar segmento ativo (sem janela aberta)
	if player_idx != _active_segment_player:
		return false
	_finish_segment(player_idx)
	return true

# ── helpers da fase ACTION ───────────────────────────────

## Chamado após cada carta ser adicionada a round_cards/cards_this_turn.
## Verifica se a cadeia de símbolos ativa a skill do herói e notifica a passiva.
func _on_card_added_to_play(player_idx: int, card: Card) -> void:
	var pl: Player = players[player_idx]
	var active: Hero = pl.active_hero
	if active == null:
		return
	if not active._skill_activated_this_turn and not active.symbols_required.is_empty():
		var chain: Array[String] = []
		for c in pl.cards_this_turn:
			for sym in c.symbols:
				chain.append(sym)
		if SymbolChain.matches_chain(chain, active.symbols_required):
			active.on_skill_activated(pl)
			var hero_idx := pl.heroes.find(active)
			_rpc_notify_skill_activated.rpc(pl.player_index, hero_idx, active.skill_desc)
	active.on_card_played(card, pl)

func _reset_action_phase_state() -> void:
	_active_segment_player    = turn.current_player_index
	_round_first_player       = turn.current_player_index
	_segment_action_done      = [false, false]
	_segment_bonus_done       = [false, false]
	_reaction_window_for      = -1
	_consecutive_empty_rounds = 0
	_hero_revealed            = [false, false]
	_pending_effect_card         = null
	_pending_effect_player       = -1
	_pending_effect_from_arsenal = false
	_pending_pick_player     = -1
	_pending_pick_source     = PickSource.DECK
	_pending_pick_count      = 1
	_pending_pick_draw_after = 0
	_pending_pick_indices.clear()
	_pending_pick_cards_display.clear()
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
		PickSource.GRAVEYARD:   return players[player_idx].discard_pile
		PickSource.HAND:        return players[player_idx].hand
		PickSource.HAND_DISCARD: return players[player_idx].hand
		_:                      return players[player_idx].deck

## Inicia um pick a partir do deck do jogador.
func begin_card_pick(player_idx: int, indices: Array[int]) -> void:
	_pending_pick_player = player_idx
	_pending_pick_source = PickSource.DECK
	_pending_pick_indices = indices

## Inicia um pick a partir do cemitério do jogador.
func begin_graveyard_pick(player_idx: int, indices: Array[int]) -> void:
	_pending_pick_player  = player_idx
	_pending_pick_source  = PickSource.GRAVEYARD
	_pending_pick_indices = indices

## Inicia um pick da mão do jogador (carta escolhida vai ao fundo do deck).
func begin_hand_pick(player_idx: int, indices: Array[int]) -> void:
	_pending_pick_player     = player_idx
	_pending_pick_source     = PickSource.HAND
	_pending_pick_count      = 1
	_pending_pick_draw_after = 0
	_pending_pick_indices    = indices

## Inicia um pick de descarte da mão (cartas vão ao cemitério; depois compra draw_after).
func begin_hand_discard(player_idx: int, indices: Array[int], count: int, draw_after: int) -> void:
	_pending_pick_player     = player_idx
	_pending_pick_source     = PickSource.HAND_DISCARD
	_pending_pick_count      = count
	_pending_pick_draw_after = draw_after
	_pending_pick_indices    = indices

# ── Revela herói ────────────────────────────────────────

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
	var active := _active_segment_player
	if _segment_action_done[active] and _segment_bonus_done[active]:
		_finish_segment(active)
	else:
		_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())

func _finish_segment(player_idx: int) -> void:
	if not _segment_action_done[player_idx]:
		_consecutive_empty_rounds += 1
	_segment_action_done[player_idx] = false
	_segment_bonus_done[player_idx]  = false
	_reaction_window_for = -1

	if player_idx == _round_first_player:
		# Primeiro segmento da rodada concluído → passa para o oponente
		_active_segment_player = 1 - player_idx
		_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())
	else:
		# Segundo segmento concluído → rodada terminou
		if _consecutive_empty_rounds >= 2 or _both_hands_empty():
			_run_combat_and_enter_end()
		else:
			_resolve_round_combat()

func _both_hands_empty() -> bool:
	return players[0].hand.is_empty() and players[1].hand.is_empty()

func _resolve_round_combat() -> void:
	var preview := _build_combat_preview()
	if not preview.is_empty():
		_rpc_notify_combat_preview.rpc(preview)
	CombatResolver.resolve_round(players[0], players[1])
	# Cartas NÃO vão ao cemitério aqui — apenas round_cards é limpo para o
	# próximo combate começar do zero. O cemitério só recebe as cartas na END.
	players[0].clear_round_cards()
	players[1].clear_round_cards()

	# Verifica vencedor geral (todos os heróis mortos)
	var w := _evaluate_winner()
	if w >= 0:
		_winner_index = w
		GameBus.game_over.emit(w)
		_rpc_notify_game_over.rpc(w)
		_run_combat_and_enter_end()
		return

	# Se qualquer herói ativo foi derrotado nesta rodada, encerra o turno
	if _any_active_hero_defeated():
		_run_combat_and_enter_end()
		return

	# Nenhuma baixa — inicia nova rodada com o jogador dono do turno
	_active_segment_player = turn.current_player_index
	_round_first_player    = turn.current_player_index
	_segment_action_done   = [false, false]
	_segment_bonus_done    = [false, false]
	_reaction_window_for   = -1
	_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())

func _any_active_hero_defeated() -> bool:
	for p in players:
		if p.active_hero != null and p.active_hero.state == Hero.State.DEFEATED:
			return true
	return false

func _run_combat_and_enter_end() -> void:
	# Revela heróis que ainda não foram revelados e anuncia fim do turno de ação
	turn.current_phase = TurnManager.Phase.COMBAT
	for i in 2:
		var h: Hero = players[i].active_hero
		if h and not _hero_revealed[i]:
			_hero_revealed[i] = true
			GameBus.hero_revealed.emit(i, h)
	# Todas as cartas jogadas no turno inteiro vão ao cemitério agora (END phase).
	for p in players:
		p.discard_pile.append_array(p.cards_this_turn)
	players[0].clear_combat_cards()
	players[1].clear_combat_cards()

	# Exausta heróis e devolve aos slots
	players[0].exhaust_active_hero()
	players[1].exhaust_active_hero()
	players[0].active_hero = null
	players[1].active_hero = null
	turn.current_phase = TurnManager.Phase.END
	_end_submitted = [false, false]
	_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())

func get_end_submitted(player_idx: int) -> bool:
	if player_idx < 0 or player_idx > 1:
		return false
	return _end_submitted[player_idx]

func finish_end_turn(player_idx: int, arsenal_hand_index: int) -> bool:
	if _winner_index >= 0:
		return false
	if turn.current_phase != TurnManager.Phase.END:
		return false
	if player_idx < 0 or player_idx > 1:
		return false
	if _end_submitted[player_idx]:
		return false
	var p: Player = players[player_idx]
	if arsenal_hand_index >= 0 and arsenal_hand_index < p.hand.size():
		p.store_in_arsenal(p.hand[arsenal_hand_index])
	_end_submitted[player_idx] = true
	_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())
	if _end_submitted[0] and _end_submitted[1]:
		var active_idx := turn.current_player_index
		players[active_idx].draw_up_to(Player.HAND_SIZE_REFILL_DRAW)
		GameBus.turn_ended.emit(active_idx)
		turn.current_player_index = (active_idx + 1) % 2
		_begin_turn_for_active_player()
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
		_make_hero(),
		_make_hero(),
		HeroHakai.new(),
	]
	p.deck = DeckLoader.load_from_json("res://data/cards/base_set.json")
	p.playmat_key = 'default'
	return p

static func _make_player2(index: int, pname: String) -> Player:
	var p := Player.new()
	p.player_index = index
	p.player_name = pname
	p.heroes = [
		HeroHakai.new(),
		HeroHakai.new(),
		HeroPoppy.new(),
	]
	p.deck = DeckLoader.load_from_json("res://data/cards/base_set.json")
	p.playmat_key = 'default'
	return p

func _make_effect_ctx(player_idx: int, card: Card, from_arsenal: bool = false) -> CardEffectContext:
	var ctx := CardEffectContext.new()
	ctx.source_player        = players[player_idx]
	ctx.opponent_player      = players[1 - player_idx]
	ctx.source_card          = card
	ctx.played_from_arsenal  = from_arsenal
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
	for card in p0.round_cards:
		atk0 += card.attack_value
	atk0 += p0.pending_bonus_attack + p0.passive_attack_bonus

	var def0 := h0.base_defense
	for card in p0.round_cards:
		def0 += card.defense_value
	def0 -= p0.next_defense_penalty
	def0 += p0.pending_bonus_defense

	var atk1 := h1.base_attack
	for card in p1.round_cards:
		atk1 += card.attack_value
	atk1 += p1.pending_bonus_attack + p1.passive_attack_bonus

	var def1 := h1.base_defense
	for card in p1.round_cards:
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
	_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())

@rpc("any_peer", "call_local", "reliable")
func rpc_submit_mulligan(idx_a: int, idx_b: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	submit_opening_mulligan(player_idx, idx_a, idx_b)
	_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())

@rpc("any_peer", "call_local", "reliable")
func rpc_submit_hero(hero_slot: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	submit_hero_pick(player_idx, hero_slot)
	_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())

@rpc("any_peer", "call_local", "reliable")
func rpc_play_card(hand_idx: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	action_play_card(player_idx, hand_idx)
	_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())

@rpc("any_peer", "call_local", "reliable")
func rpc_play_from_arsenal() -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	action_play_from_arsenal(player_idx)
	_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())

@rpc("any_peer", "call_local", "reliable")
func rpc_pass() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	action_pass(player_idx)
	_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())

@rpc("any_peer", "call_local", "reliable")
func rpc_submit_card_pick(pick_indices: Array) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if _pending_pick_player != player_idx:
		return
	# Valida todos os índices recebidos
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
		PickSource.GRAVEYARD:
			# Carta escolhida vai ao fundo do deck; puxa a carta do topo
			var source_idx: int = _pending_pick_indices[pick_indices[0]]
			if source_idx < p.discard_pile.size():
				var card := p.discard_pile[source_idx]
				p.discard_pile.remove_at(source_idx)
				p.deck.append(card)
			p.draw_cards(1)
		PickSource.HAND:
			# Carta escolhida da mão vai ao fundo do deck (índice único)
			var source_idx: int = _pending_pick_indices[pick_indices[0]]
			if source_idx < p.hand.size():
				var card := p.hand[source_idx]
				p.hand.remove_at(source_idx)
				p.deck.append(card)
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
	_pending_pick_player     = -1
	_pending_pick_source     = PickSource.DECK
	_pending_pick_count      = 1
	_pending_pick_draw_after = 0
	_pending_pick_indices.clear()
	_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())

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
		_sync_state.rpc(turn.phase_to_string(turn.current_phase), _build_snapshot())

@rpc("any_peer", "call_local", "reliable")
func rpc_finish_turn(arsenal_idx: int) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	finish_end_turn(player_idx, arsenal_idx)

# ── sincronização de estado ──────────────────────────────

# Recebe a fase e o snapshot do estado do servidor, aplica localmente
# e dispara os sinais de UI — garante que cliente e servidor fiquem alinhados.
@rpc("authority", "call_local", "reliable")
func _sync_state(phase_str: String, snapshot: Dictionary) -> void:
	turn.current_phase = _phase_from_string(phase_str)
	_apply_snapshot(snapshot)
	GameBus.phase_changed.emit(phase_str)
	GameBus.state_synced.emit()

# Notifica apenas o cliente (host já emitiu diretamente).
@rpc("authority", "call_remote", "reliable")
func _rpc_notify_game_over(winner_idx: int) -> void:
	GameBus.game_over.emit(winner_idx)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_card_played(player_idx: int, card_data: Dictionary) -> void:
	var card := Card.from_dict(card_data)
	GameBus.card_played.emit(player_idx, card)

func _emit_card_played(player_idx: int, card: Card) -> void:
	GameBus.card_played.emit(player_idx, card)
	_rpc_notify_card_played.rpc(player_idx, _serialize_cards([card])[0])

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_skill_activated(player_idx: int, hero_idx: int, skill_name: String) -> void:
	if player_idx < 0 or player_idx >= players.size():
		return
	if hero_idx < 0 or hero_idx >= players[player_idx].heroes.size():
		return
	GameBus.skill_activated.emit(players[player_idx].heroes[hero_idx], skill_name)

# Serializa o estado mínimo necessário para o cliente redesenhar a UI.
func _build_snapshot() -> Dictionary:
	var snap := { "players": [] }
	for p in players:
		var heroes_data: Array = []
		for h in p.heroes:
			heroes_data.append({ "hp": h.current_hp, "state": int(h.state) })
		var discard_top: Dictionary = {}
		if not p.discard_pile.is_empty():
			discard_top = _serialize_cards([p.discard_pile.back()])[0]
		snap["players"].append({
			"hand":                 _serialize_cards(p.hand),
			"arsenal":              _serialize_cards(p.arsenal),
			"round_cards":          _serialize_cards(p.round_cards),
			"heroes":               heroes_data,
			"active_hero_idx":      p.heroes.find(p.active_hero),
			"sleeve_key":           p.sleeve_key,
			"playmat_key":          p.playmat_key,
			"discard_top":          discard_top,
			"pending_bonus_attack":  p.pending_bonus_attack,
			"pending_bonus_defense": p.pending_bonus_defense,
			"next_defense_penalty":  p.next_defense_penalty,
			"passive_attack_bonus":  (p.active_hero.get_passive_attack_bonus() if p.active_hero != null else 0),
		})
	# estado da fase de escolha de herói
	snap["next_hero_pick_player"] = _next_hero_pick_player
	snap["hero_submitted"]        = [_hero_submitted[0], _hero_submitted[1]]
	# estado da fase de ação (rodadas + timing)
	snap["active_segment_player"]    = _active_segment_player
	snap["round_first_player"]       = _round_first_player
	snap["segment_action_done"]      = [_segment_action_done[0], _segment_action_done[1]]
	snap["segment_bonus_done"]       = [_segment_bonus_done[0],  _segment_bonus_done[1]]
	snap["reaction_window_for"]      = _reaction_window_for
	snap["consecutive_empty_rounds"] = _consecutive_empty_rounds
	snap["hero_revealed"]            = [_hero_revealed[0], _hero_revealed[1]]
	snap["end_submitted"]            = [_end_submitted[0], _end_submitted[1]]
	# pick de carta pendente
	snap["pending_pick_player"]     = _pending_pick_player
	snap["pending_pick_source"]     = int(_pending_pick_source)
	snap["pending_pick_count"]      = _pending_pick_count
	snap["pending_pick_draw_after"] = _pending_pick_draw_after
	if _pending_pick_player >= 0 and _pending_pick_player < players.size():
		var source_arr := _pick_source_array(_pending_pick_player)
		var show: Array[Card] = []
		for idx in _pending_pick_indices:
			if idx < source_arr.size():
				show.append(source_arr[idx])
		snap["pending_pick_cards"] = _serialize_cards(show)
	else:
		snap["pending_pick_cards"] = []
	# pick de símbolo pendente
	snap["pending_symbol_player"] = _pending_symbol_player
	snap["pending_symbol_count"]  = _pending_symbol_count
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
			p.hand        = _deserialize_cards(pd.get("hand", []))
			p.arsenal     = _deserialize_cards(pd.get("arsenal", []))
			p.round_cards = _deserialize_cards(pd.get("round_cards", []))
		p.pending_bonus_attack  = pd.get("pending_bonus_attack",  0)
		p.pending_bonus_defense = pd.get("pending_bonus_defense", 0)
		p.next_defense_penalty  = pd.get("next_defense_penalty",  0)
		p.passive_attack_bonus  = pd.get("passive_attack_bonus",  0)
		if not multiplayer.is_server():
			var dt: Dictionary = pd.get("discard_top", {})
			if not dt.is_empty():
				p.discard_pile = _deserialize_cards([dt])
			else:
				p.discard_pile.clear()
		var hlist: Array = pd.get("heroes", [])
		for j in min(hlist.size(), p.heroes.size()):
			p.heroes[j].current_hp = hlist[j].get("hp", p.heroes[j].current_hp)
			p.heroes[j].state      = hlist[j].get("state", int(p.heroes[j].state))
		var active_idx: int = pd.get("active_hero_idx", -1)
		p.active_hero  = p.heroes[active_idx] if active_idx >= 0 else null
		p.sleeve_key   = pd.get("sleeve_key",  p.sleeve_key)
		p.playmat_key  = pd.get("playmat_key", p.playmat_key)
	# estado da escolha de herói — necessário para o cliente saber de quem é a vez
	_next_hero_pick_player = snap.get("next_hero_pick_player", _next_hero_pick_player)
	var hs: Array = snap.get("hero_submitted", [])
	if hs.size() >= 2:
		_hero_submitted[0] = hs[0]
		_hero_submitted[1] = hs[1]
	_active_segment_player    = snap.get("active_segment_player",    _active_segment_player)
	_round_first_player       = snap.get("round_first_player",       _round_first_player)
	_reaction_window_for      = snap.get("reaction_window_for",      _reaction_window_for)
	_consecutive_empty_rounds = snap.get("consecutive_empty_rounds", _consecutive_empty_rounds)
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
	_pending_pick_player     = snap.get("pending_pick_player",     -1)
	_pending_pick_source     = snap.get("pending_pick_source",     int(PickSource.DECK)) as PickSource
	_pending_pick_count      = snap.get("pending_pick_count",      1)
	_pending_pick_draw_after = snap.get("pending_pick_draw_after", 0)
	if not multiplayer.is_server():
		_pending_pick_cards_display = _deserialize_cards(snap.get("pending_pick_cards", []))
	_pending_symbol_player = snap.get("pending_symbol_player", -1)
	_pending_symbol_count  = snap.get("pending_symbol_count",  0)

static func _deserialize_cards(arr: Array) -> Array[Card]:
	var out: Array[Card] = []
	for d in arr:
		out.append(Card.from_dict(d))
	return out

static func _phase_from_string(s: String) -> TurnManager.Phase:
	match s:
		"OPENING_MULLIGAN": return TurnManager.Phase.OPENING_MULLIGAN
		"DRAW":             return TurnManager.Phase.DRAW
		"HERO_SELECTION":   return TurnManager.Phase.HERO_SELECTION
		"ACTION":           return TurnManager.Phase.ACTION
		"COMBAT":           return TurnManager.Phase.COMBAT
		"END":              return TurnManager.Phase.END
		_:                  return TurnManager.Phase.OPENING_MULLIGAN

# ── helper ───────────────────────────────────────────────

func _peer_to_player_index(peer_id: int) -> int:
	# Chamadas locais (host → si mesmo) chegam com peer_id = 0.
	# O servidor em si tem peer_id = 1.
	# Ambos os casos são o host → player 0.
	# Qualquer outro peer_id é o cliente → player 1.
	return 0 if peer_id <= 1 else 1
	
static func _debug_force_card_to_hand(p: Player, card_name: String) -> void:
	for i in p.deck.size():
		if p.deck[i].card_name == card_name:
			p.hand.append(p.deck[i])
			p.deck.remove_at(i)
			return
