# src/core/game_state.gd
extends Node

var players: Array[Player] = []
var turn: TurnManager = TurnManager.new()

var _opening_mulligan_done: Array[bool] = [false, false]
var _hero_submitted: Array[bool] = [false, false]
var _next_hero_pick_player: int = 0
var _next_action_player: int = 0
var _consecutive_passes: int = 0
var _winner_index: int = -1

func _ready() -> void:
	if multiplayer.is_server():
		start_match()
func start_match() -> void:
	players = [_make_player(0, "Jogador 1"), _make_player(1, "Jogador 2")]
	turn.players = players
	turn.current_player_index = 0
	_winner_index = -1
	for p in players:
		_shuffle_deck(p.deck)
		p.draw_up_to(Player.HAND_CAP_START)
	_opening_mulligan_done = [false, false]
	turn.current_phase = TurnManager.Phase.OPENING_MULLIGAN
	turn.emit_phase_changed()

func is_game_over() -> bool:
	return _winner_index >= 0

func get_winner_index() -> int:
	return _winner_index

func get_next_action_player_index() -> int:
	return _next_action_player

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
	player.draw_up_to(Player.HAND_CAP_START)
	if player.hand.size() >= 2:
		var hn := player.hand.size()
		player.send_cards_to_bottom([player.hand[hn - 1], player.hand[hn - 2]])
	player._check_rotation()
	turn.current_phase = TurnManager.Phase.HERO_SELECTION
	_hero_submitted = [false, false]
	_next_hero_pick_player = idx
	_consecutive_passes = 0
	_next_action_player = idx
	GameBus.turn_started.emit(idx)
	turn.emit_phase_changed()

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
	GameBus.hero_chosen.emit(player_idx, hero)
	_hero_submitted[player_idx] = true
	if _hero_submitted[0] and _hero_submitted[1]:
		turn.current_phase = TurnManager.Phase.ACTION
		_next_action_player = turn.current_player_index
		_consecutive_passes = 0
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
	if player_idx != _next_action_player:
		return false
	var pl: Player = players[player_idx]
	if hand_idx < 0 or hand_idx >= pl.hand.size():
		return false
	var card: Card = pl.hand[hand_idx]
	if card.card_type == Card.CardType.ATTACK:
		pl.hand.remove_at(hand_idx)
		pl.attacks_this_turn.append(card)
	elif card.card_type == Card.CardType.DEFENSE:
		pl.hand.remove_at(hand_idx)
		pl.defenses_this_turn.append(card)
	else:
		return false
	GameBus.card_played.emit(player_idx, card)
	_consecutive_passes = 0
	_flip_action_player()
	return true

func action_pass(player_idx: int) -> bool:
	if _winner_index >= 0:
		return false
	if turn.current_phase != TurnManager.Phase.ACTION:
		return false
	if player_idx != _next_action_player:
		return false
	_consecutive_passes += 1
	_flip_action_player()
	if _consecutive_passes >= 2:
		_run_combat_and_enter_end()
	return true

func _flip_action_player() -> void:
	_next_action_player = 1 - _next_action_player

func _run_combat_and_enter_end() -> void:
	turn.current_phase = TurnManager.Phase.COMBAT
	var p0: Player = players[0]
	var p1: Player = players[1]
	for i in 2:
		var h: Hero = players[i].active_hero
		if h:
			GameBus.hero_revealed.emit(i, h)
	CombatResolver.resolve_mutual(p0, p1)
	p0.clear_combat_cards()
	p1.clear_combat_cards()
	var w := _evaluate_winner()
	if w >= 0:
		_winner_index = w
		GameBus.game_over.emit(w)
	turn.current_phase = TurnManager.Phase.END
	turn.emit_phase_changed()

func finish_end_turn(arsenal_hand_index: int) -> bool:
	if _winner_index >= 0:
		return false
	if turn.current_phase != TurnManager.Phase.END:
		return false
	var idx := turn.current_player_index
	var p: Player = players[idx]
	if not p.hand.is_empty():
		var pick := clampi(arsenal_hand_index, 0, p.hand.size() - 1)
		p.store_in_arsenal(p.hand[pick])
	p.draw_cards(Player.HAND_SIZE_REFILL_DRAW)
	players[0].exhaust_active_hero()
	players[1].exhaust_active_hero()
	
	GameBus.turn_ended.emit(idx)
	turn.current_player_index = (idx + 1) % 2
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
		_make_hero(),
	]
	p.deck = _build_deck_starter()
	return p

static func _make_hero() -> Hero:
	var h := HeroPoppy.new()
	return h

static func _build_deck_starter() -> Array[Card]:
	var out: Array[Card] = []
	var vals := [1, 1, 1, 1, 2, 2, 2, 2, 3, 3]
	# GDScript não permite Array[Array[String]]; cada entrada é um Array de IDs (constantes GameSymbols.*).
	var atk_sym: Array = [
		[GameSymbols.FOGO],
		[GameSymbols.TERRA],
		[GameSymbols.AGUA],
		[GameSymbols.AR],
		[GameSymbols.FOGO, GameSymbols.TERRA],
		[GameSymbols.AGUA, GameSymbols.AR],
		[GameSymbols.FOGO, GameSymbols.FOGO],
		[GameSymbols.TERRA, GameSymbols.AGUA],
		[GameSymbols.FOGO, GameSymbols.TERRA, GameSymbols.AGUA],
		[GameSymbols.AR, GameSymbols.FOGO, GameSymbols.AGUA],
	]
	var def_sym: Array = [
		[GameSymbols.TERRA],
		[GameSymbols.AGUA],
		[],
		[GameSymbols.FOGO, GameSymbols.AR],
		[GameSymbols.TERRA],
		[GameSymbols.AGUA, GameSymbols.AGUA],
		[],
		[GameSymbols.AR],
		[GameSymbols.FOGO, GameSymbols.TERRA],
		[GameSymbols.AGUA],
	]
	for i in vals.size():
		out.append(_make_attack_card(vals[i], atk_sym[i] as Array))
	for i in vals.size():
		out.append(_make_defense_card(vals[i], def_sym[i] as Array))
	return out

static func _make_attack_card(value: int, card_symbols: Array) -> Card:
	var c := Card.new()
	c.card_name = "Ataque +%d" % value
	c.card_type = Card.CardType.ATTACK
	c.value = value
	c.set_symbols(card_symbols)
	c.is_stealth = false
	return c

static func _make_defense_card(value: int, card_symbols: Array) -> Card:
	var c := Card.new()
	c.card_name = "Defesa +%d" % value
	c.card_type = Card.CardType.DEFENSE
	c.value = value
	c.set_symbols(card_symbols)
	c.is_stealth = false
	return c
	
	# ── camada de rede ───────────────────────────────────────
# Clientes chamam esses métodos — nunca a lógica diretamente.

@rpc("any_peer", "reliable")
func rpc_submit_mulligan(idx_a: int, idx_b: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	submit_opening_mulligan(player_idx, idx_a, idx_b)
	# sincroniza estado após a ação
	_sync_state.rpc()

@rpc("any_peer", "reliable")
func rpc_submit_hero(hero_slot: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	submit_hero_pick(player_idx, hero_slot)
	_sync_state.rpc()

@rpc("any_peer", "reliable")
func rpc_play_card(hand_idx: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	action_play_card(player_idx, hand_idx)
	_sync_state.rpc()

@rpc("any_peer", "reliable")
func rpc_pass() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	action_pass(player_idx)
	_sync_state.rpc()

@rpc("any_peer", "reliable")
func rpc_finish_turn(arsenal_idx: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	finish_end_turn(arsenal_idx)
	_sync_state.rpc()

# ── sincronização de estado ──────────────────────────────

@rpc("authority", "call_local", "reliable")
func _sync_state() -> void:
	# reconstrói o estado visual em todos os clientes
	GameBus.state_synced.emit()

# ── helper ───────────────────────────────────────────────

func _peer_to_player_index(peer_id: int) -> int:
	# servidor tem peer_id = 1, sempre é player 0
	# cliente tem peer_id diferente, sempre é player 1
	return 0 if peer_id == 1 else 1
