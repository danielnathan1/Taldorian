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
enum PickSource { DECK, GRAVEYARD, HAND, HAND_DISCARD, HAND_ARSENAL, GRAVEYARD_ARSENAL, DECK_PEEK, GRAVEYARD_TO_TOP, GRAVEYARD_TO_HAND }

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
var _reactions_locked: bool:
	get:
		return _m._reactions_locked
	set(value):
		_m._reactions_locked = value
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
var _pending_backline_ability: Dictionary:
	get:
		return _m._pending_backline_ability
	set(value):
		_m._pending_backline_ability = value

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
var _pending_ally_pick_side: int:
	get:
		return _m._pending_ally_pick_side
	set(value):
		_m._pending_ally_pick_side = value
var _pending_ally_pick_filter: String:
	get:
		return _m._pending_ally_pick_filter
	set(value):
		_m._pending_ally_pick_filter = value

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
var _pending_symbol_to_chain: bool:
	get:
		return _m._pending_symbol_to_chain
	set(value):
		_m._pending_symbol_to_chain = value
var _pending_reveal_player: int:
	get:
		return _m._pending_reveal_player
	set(value):
		_m._pending_reveal_player = value
var _pending_reveal_card: Card:
	get:
		return _m._pending_reveal_card
	set(value):
		_m._pending_reveal_card = value

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
var _pending_pick_variable: bool:
	get:
		return _m._pending_pick_variable
	set(value):
		_m._pending_pick_variable = value
var _pending_pick_bonus_symbol: String:
	get:
		return _m._pending_pick_bonus_symbol
	set(value):
		_m._pending_pick_bonus_symbol = value
var _pending_pick_bonus_attack: int:
	get:
		return _m._pending_pick_bonus_attack
	set(value):
		_m._pending_pick_bonus_attack = value
var _pending_overload_player: int:
	get:
		return _m._pending_overload_player
	set(value):
		_m._pending_overload_player = value
var _pending_overload_phase: int:
	get:
		return _m._pending_overload_phase
	set(value):
		_m._pending_overload_phase = value
var _pending_overload_points: int:
	get:
		return _m._pending_overload_points
	set(value):
		_m._pending_overload_points = value
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
var _stealth_passive_queue: Array[Dictionary]:
	get:
		return _m._stealth_passive_queue
	set(value):
		_m._stealth_passive_queue = value
var _stealth_passive_player: int:
	get:
		return _m._stealth_passive_player
	set(value):
		_m._stealth_passive_player = value
var _stealth_passive_hero_idx: int:
	get:
		return _m._stealth_passive_hero_idx
	set(value):
		_m._stealth_passive_hero_idx = value
var _stealth_passive_card: Card:
	get:
		return _m._stealth_passive_card
	set(value):
		_m._stealth_passive_card = value
var _frontline_queue: Array[Dictionary]:
	get:
		return _m._frontline_queue
	set(value):
		_m._frontline_queue = value
var _frontline_confirm_player: int:
	get:
		return _m._frontline_confirm_player
	set(value):
		_m._frontline_confirm_player = value
var _frontline_confirm_hero_idx: int:
	get:
		return _m._frontline_confirm_hero_idx
	set(value):
		_m._frontline_confirm_hero_idx = value
var _dice_thrown: Array[bool]:
	get:
		return _m._dice_thrown
	set(value):
		_m._dice_thrown = value
var _dice_values: Array:
	get:
		return _m._dice_values
	set(value):
		_m._dice_values = value
var _dice_throw_vec: Array[Vector2]:
	get:
		return _m._dice_throw_vec
	set(value):
		_m._dice_throw_vec = value
var _dice_winner: int:
	get:
		return _m._dice_winner
	set(value):
		_m._dice_winner = value
var _dice_awaiting_choice: bool:
	get:
		return _m._dice_awaiting_choice
	set(value):
		_m._dice_awaiting_choice = value
var _first_player: int:
	get:
		return _m._first_player
	set(value):
		_m._first_player = value

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
	# Descarte de carta → passivas de descarte (Relicar). Só o servidor reage.
	if not GameBus.card_discarded.is_connected(_on_card_discarded_event):
		GameBus.card_discarded.connect(_on_card_discarded_event)

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
	#_debug_force_card_in_hand(0, 9)
	#_debug_force_card_in_hand(0, 11)  # "Dois Passos à Frente" → mão do Jogador 0
	# ── fim do bloco DEBUG ───────────────────────────────────────────────────

	_opening_mulligan_done = [false, false]
	# Rolagem de dados de abertura: primeira fase, antes do mulligan.
	_reset_dice_state()
	battle.current_phase = BattleManager.Phase.OPENING_ROLL
	# Envia os decks ao(s) cliente(s) para que construam seus próprios players
	# antes do primeiro _sync_state chegar.
	if multiplayer.is_server() and not multiplayer.get_peers().is_empty():
		_notify_init_players(deck0, deck1)
	battle.emit_phase_changed()

func _reset_dice_state() -> void:
	_dice_thrown          = [false, false]
	_dice_values          = [[0, 0], [0, 0]]
	_dice_throw_vec       = [Vector2.ZERO, Vector2.ZERO]
	_dice_winner          = -1
	_dice_awaiting_choice = false
	_first_player         = -1

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

## Ações extras disponíveis no segmento (Energizado / Circuito Aberto). Permitem jogar
## uma ACTION adicional mesmo com action_done == true.
func get_extra_actions(player_idx: int) -> int:
	if player_idx < 0 or player_idx > 1:
		return 0
	return players[player_idx].extra_actions

func get_hero_revealed(player_idx: int) -> bool:
	if player_idx < 0 or player_idx > 1:
		return false
	return _hero_revealed[player_idx]

func get_backline_awaiting_response() -> bool: return _backline_awaiting_response
func get_backline_awaiting_target()   -> bool: return _backline_awaiting_target
func get_backline_current_player()    -> int:  return _backline_current_player
func get_backline_current_hero_idx()  -> int:  return _backline_current_hero_idx

func get_stealth_passive_player()   -> int: return _stealth_passive_player
func get_stealth_passive_hero_idx() -> int: return _stealth_passive_hero_idx

func get_frontline_confirm_player()   -> int: return _frontline_confirm_player
func get_frontline_confirm_hero_idx() -> int: return _frontline_confirm_hero_idx

func get_dice_thrown(player_idx: int) -> bool:
	if player_idx < 0 or player_idx > 1: return false
	return _dice_thrown[player_idx]
func get_dice_values(player_idx: int) -> Array:
	if player_idx < 0 or player_idx > 1: return [0, 0]
	return _dice_values[player_idx]
func get_dice_throw_vec(player_idx: int) -> Vector2:
	if player_idx < 0 or player_idx > 1: return Vector2.ZERO
	return _dice_throw_vec[player_idx]
func get_dice_total(player_idx: int) -> int:
	if player_idx < 0 or player_idx > 1: return 0
	return int(_dice_values[player_idx][0]) + int(_dice_values[player_idx][1])
func get_dice_winner()          -> int:  return _dice_winner
func get_dice_awaiting_choice() -> bool: return _dice_awaiting_choice
func get_first_player()         -> int:  return _first_player

## true quando a partida atual é de teste (sala debug criada por ADMIN). Lido pelo
## board para mostrar o botão DEBUG. No cliente vem do snapshot (_apply_snapshot).
func is_debug_match()           -> bool: return _m != null and _m._debug

## Oculta o herói novamente (torna furtivo). Usado pela habilidade ativa de Hakai.
func set_hero_stealth(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	_hero_revealed[player_idx] = false
	# VFX de furtividade (bombinha → fumaça sobre o herói ativo). Ponto autoritativo
	# único onde o herói volta a ficar oculto (Instinto de Caça do Hakai, Véu Transitório).
	_notify_effect_vfx(player_idx, "stealth")

## Revela o herói ativo do jogador (contraparte pública de set_hero_stealth). Passa pelo
## _hero_revealed autoritativo e dispara a passiva de revelação (ex.: Muro da Valkar).
func reveal_active_hero(player_idx: int) -> void:
	if player_idx < 0 or player_idx > 1:
		return
	_reveal_active_hero(player_idx)

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
		# Quem começa foi decidido na rolagem de dados (OPENING_ROLL); fallback = 0.
		battle.current_player_index = _first_player if _first_player >= 0 else 0
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
			h.wall_active = false
			h.taunt_active = false
	_backline_queue.clear()
	_backline_awaiting_response = false
	_backline_awaiting_target   = false
	_backline_current_player    = -1
	_backline_current_hero_idx  = -1
	_clear_stealth_passive_queue()
	_clear_frontline_confirm_queue()

	# Escudo persistente re-aplica no início do turno (a Queimadura tica no FIM — _tick_burn).
	_tick_persistent_shields()

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
		# 1º: confirmação de passiva de frontline (Muro de Aço). Se houver pendência,
		# o fluxo pausa aguardando Sim/Não; ao drenar, segue para a retaguarda.
		_frontline_queue.clear()
		for i in 2:
			var act: Hero = players[i].active_hero
			if act != null and act.is_alive() and act.wants_frontline_confirm() \
					and not _hero_revealed[i]:
				_frontline_queue.append({ "player_idx": i, "hero_idx": players[i].heroes.find(act) })
		if _start_frontline_confirm_if_pending():
			return true
		_begin_backline_phase()
	else:
		# Apenas sincroniza — o outro jogador ainda verá a tela de seleção
		_emit_sync()
	return true

## Passivas de retaguarda — dispara não-interativas imediatamente; interativas
## (has_backline_ability) entram na fila de decisão do jogador. Chamado após as
## confirmações de frontline (se houver) terem sido resolvidas.
func _begin_backline_phase() -> void:
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

# ── confirmação de passiva de frontline (Muro de Aço da Valkar) ──────────────

## Drena a fila de confirmações de frontline. No primeiro ativo ainda oculto, abre a
## confirmação (sync) e devolve true — o chamador deve pausar. Itens já revelados
## ativam direto. Devolve false se nada a confirmar.
func _start_frontline_confirm_if_pending() -> bool:
	if _frontline_confirm_player >= 0:
		return true
	while not _frontline_queue.is_empty():
		var entry: Dictionary = _frontline_queue.pop_front()
		var p_idx: int = entry["player_idx"]
		var h_idx: int = entry["hero_idx"]
		var hero: Hero = players[p_idx].heroes[h_idx]
		if not hero.is_alive() or hero != players[p_idx].active_hero:
			continue
		if _hero_revealed[p_idx]:
			_activate_frontline_passive(p_idx, h_idx)
			continue
		_frontline_confirm_player   = p_idx
		_frontline_confirm_hero_idx = h_idx
		_emit_sync()
		return true
	return false

## Ativa a passiva de frontline do herói: liga o flag, revela o herói (quebra a
## furtividade) e dispara o aviso visual (VFX/popup via skill_activated).
func _activate_frontline_passive(player_idx: int, hero_idx: int) -> void:
	var hero: Hero = players[player_idx].heroes[hero_idx]
	hero.wall_active = true
	_reveal_active_hero(player_idx)
	GameBus.skill_activated.emit(hero, hero.passive_desc)
	_notify_skill_activated(player_idx, hero_idx, hero.passive_desc)

func _clear_frontline_confirm_queue() -> void:
	_frontline_queue.clear()
	_frontline_confirm_player   = -1
	_frontline_confirm_hero_idx = -1

## Jogador responde Sim/Não à confirmação de frontline. Sim quebra a furtividade e
## ativa a passiva; Não mantém a furtividade (sem proteção neste turno, até que se
## revele por outro meio).
@rpc("any_peer", "call_local", "reliable")
func rpc_respond_frontline_passive(use: bool) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if player_idx != _frontline_confirm_player:
		return
	var h_idx := _frontline_confirm_hero_idx
	_frontline_confirm_player   = -1
	_frontline_confirm_hero_idx = -1
	if use:
		_activate_frontline_passive(player_idx, h_idx)
	if _start_frontline_confirm_if_pending():
		return
	_begin_backline_phase()

## Liga o Muro de Aço quando o herói ativo se revela durante a fase ACTION (ex.:
## jogou carta não-furtiva após ter escolhido ficar oculto na seleção). Sem efeito
## na revelação forçada de COMBAT/END (onde já não há dano direcionado a prevenir).
func _activate_wall_on_reveal(player_idx: int) -> void:
	if battle.current_phase != BattleManager.Phase.ACTION:
		return
	var h: Hero = players[player_idx].active_hero
	if h != null and h.is_alive() and h.wants_frontline_confirm() and not h.wall_active:
		h.wall_active = true
		var hero_idx := players[player_idx].heroes.find(h)
		GameBus.skill_activated.emit(h, h.passive_desc)
		_notify_skill_activated(player_idx, hero_idx, h.passive_desc)

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
	# Dano direto da retaguarda (Retaguarda Precisa) pode derrubar um heroi ativo —
	# encerra a batalha e vai para o arsenal antes de processar a proxima habilidade.
	if _end_battle_if_active_defeated():
		return
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
	if _pending_overload_player >= 0:
		return false
	var pl: Player = players[player_idx]
	if hand_idx < 0 or hand_idx >= pl.hand.size():
		return false
	var card: Card = pl.hand[hand_idx]

	match card.timing:
		Card.TimingType.ACTION:
			if player_idx != _active_segment_player: return false
			if _segment_action_done[player_idx]:
				# Ação extra (Energizado / Circuito Aberto) permite jogar outra ACTION.
				if players[player_idx].extra_actions > 0:
					players[player_idx].extra_actions -= 1
				else:
					return false
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
			if players[player_idx].pending_cancel_reaction or _reactions_locked:
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
			if _reactions_locked:
				_reaction_window_for = -1
				_on_reaction_window_closed()
			else:
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
			_resolve_card_effects(player_idx, card, false)
			_fire_on_card_played(player_idx, card)
			_emit_card_played(player_idx, card)
			# Se o efeito abriu um pick (carta ou símbolo), pausar — o pick resolverá o fluxo
			if _pending_symbol_player >= 0 or _pending_pick_player >= 0 or _pending_ally_pick_player >= 0 or _pending_overload_player >= 0:
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
			if _segment_action_done[player_idx]:
				# Ação extra (Energizado / Circuito Aberto) permite jogar outra ACTION.
				if players[player_idx].extra_actions > 0:
					players[player_idx].extra_actions -= 1
				else:
					return false
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
			if players[player_idx].pending_cancel_reaction or _reactions_locked:
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
			if _reactions_locked:
				_reaction_window_for = -1
				_on_reaction_window_closed()
			else:
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
			_resolve_card_effects(player_idx, card, true)
			_fire_on_card_played(player_idx, card)
			_emit_card_played(player_idx, card)
			if _pending_symbol_player >= 0 or _pending_pick_player >= 0 or _pending_ally_pick_player >= 0 or _pending_overload_player >= 0:
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
	if _pending_overload_player >= 0:
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

# ── habilidades ativadas (Alastar e futuros heróis) ──────────────────────────
## Ativa uma habilidade declarada pelo herói ativo. Roteia por `cost`:
##   ACTION/BONUS → consome o tempo do segmento e abre janela de reação (ação normal).
##   FREE         → não gasta tempo; pode mirar heróis (targets = [[player_idx, hero_idx], ...]).
## `targets` é resolvido para Array[Hero] aqui — o herói só aplica o efeito.
func action_activate_ability(player_idx: int, ability_id: String, targets: Array = []) -> bool:
	if _winner_index >= 0:
		return false
	if battle.current_phase != BattleManager.Phase.ACTION:
		return false
	if _pending_pick_player >= 0 or _pending_symbol_player >= 0 or _pending_ally_pick_player >= 0 or _pending_overload_player >= 0:
		return false
	var pl: Player = players[player_idx]
	var hero: Hero = pl.active_hero
	if hero == null:
		return false
	var opponent: Player = players[1 - player_idx]
	# Localiza o descritor da habilidade disponível AGORA (validação de disponibilidade
	# fica com o dono — herói ou token: ex.: disparar só aparece se houver mísseis).
	var entry: Dictionary = {}
	for a in pl.get_active_abilities(opponent):
		if str(a.get("id", "")) == ability_id:
			entry = a
			break
	if entry.is_empty():
		return false
	var cost := str(entry.get("cost", ""))
	var hero_idx := pl.heroes.find(hero)

	match cost:
		"ACTION", "BONUS":
			if player_idx != _active_segment_player:
				return false
			if _reaction_window_for != -1:
				return false
			if cost == "ACTION" and _segment_action_done[player_idx]:
				# Ação extra (Energizado / Circuito Aberto) permite ativar outra ACTION.
				if players[player_idx].extra_actions > 0:
					players[player_idx].extra_actions -= 1
				else:
					return false
			if cost == "BONUS" and _segment_bonus_done[player_idx]:
				return false
			# Marcador de habilidade de RETAGUARDA (ex.: Darian): consome ação bônus do
			# jogador ativo, mas NÃO revela o herói ativo nem abre janela de reação.
			var from_backline := bool(entry.get("from_backline", false))
			# Alvos (ACTION/BONUS com needs_target, ex.: Selo da Ruína) — validação do ramo FREE.
			var hero_targets: Array = []
			if bool(entry.get("needs_target", false)):
				if targets.is_empty():
					return false
				for t in targets:
					if typeof(t) != TYPE_ARRAY or (t as Array).size() < 2:
						return false
					var tp := int(t[0])
					var th := int(t[1])
					if tp < 0 or tp > 1:
						return false
					if th < 0 or th >= players[tp].heroes.size():
						return false
					var target_hero: Hero = players[tp].heroes[th]
					if not target_hero.is_alive():
						return false
					hero_targets.append(target_hero)
			# Herói de origem do popup: o ativo, ou o herói de retaguarda dono da habilidade.
			var src_hero := hero
			var src_hero_idx := hero_idx
			var label := ""
			if from_backline:
				for j in pl.heroes.size():
					var h2: Hero = pl.heroes[j]
					if h2 == hero or not h2.is_alive():
						continue
					var ba := h2.get_backline_bonus_ability(pl, opponent)
					if not ba.is_empty() and str(ba.get("id", "")) == ability_id:
						src_hero = h2
						src_hero_idx = j
						break
			print("[TCG] Jogador %d (%s): ativou '%s' (%s%s)" % [player_idx, pl.player_name, ability_id, cost, " backline" if from_backline else ""])
			# Habilidade normal revela o herói ATIVO. Habilidade de retaguarda que marca
			# reveals_self quebra a furtividade do PRÓPRIO herói de retaguarda (ex.: Darian),
			# sem tocar no herói ativo.
			if not from_backline:
				_capture_hero_hidden(player_idx)
				_reveal_active_hero(player_idx)
			elif bool(entry.get("reveals_self", false)):
				src_hero.is_backline_revealed = true
			if cost == "ACTION":
				_segment_action_done[player_idx] = true
				_consecutive_empty_turns = 0
			else:
				_segment_bonus_done[player_idx] = true
			if from_backline:
				# Reação é mais rápida que ação bônus: a habilidade de retaguarda só RESOLVE
				# (efeito + VFX + popup) quando a janela de reação fechar. Guarda pendente.
				_pending_backline_ability = { "player": player_idx, "id": ability_id, "src_hero_idx": src_hero_idx, "targets": hero_targets }
			else:
				label = pl.activate_ability(ability_id, opponent, hero_targets)
				if not label.is_empty():
					GameBus.skill_activated.emit(src_hero, label)
					_notify_skill_activated(player_idx, src_hero_idx, label)
			# Tanto ACTION quanto ação bônus (incl. habilidade de retaguarda) abrem
			# janela de reação para o oponente.
			_reaction_window_for = 1 - player_idx
			GameBus.reaction_window_opened.emit(1 - player_idx)
			# Dano externo pode derrotar um herói ativo fora do ciclo de combate.
			if _end_battle_if_active_defeated():
				return true
			_emit_sync()
			return true

		"FREE":
			if player_idx != _active_segment_player:
				return false
			if _reaction_window_for != -1:
				return false
			var hero_targets: Array = []
			if bool(entry.get("needs_target", false)):
				if targets.is_empty():
					return false
				for t in targets:
					if typeof(t) != TYPE_ARRAY or (t as Array).size() < 2:
						return false
					var tp := int(t[0])
					var th := int(t[1])
					if tp < 0 or tp > 1:
						return false
					if th < 0 or th >= players[tp].heroes.size():
						return false
					var target_hero: Hero = players[tp].heroes[th]
					if not target_hero.is_alive():
						return false
					hero_targets.append(target_hero)
			print("[TCG] Jogador %d (%s): ativou '%s' (FREE, %d alvo(s))" % [player_idx, pl.player_name, ability_id, hero_targets.size()])
			var label := pl.activate_ability(ability_id, opponent, hero_targets)
			if not label.is_empty():
				GameBus.skill_activated.emit(hero, label)
				_notify_skill_activated(player_idx, hero_idx, label)
			# Habilidade FREE com alvos (ex.: disparar mísseis): VFX dos feixes em
			# ambos os clientes, cada um calculando posições do seu ponto de vista.
			if bool(entry.get("needs_target", false)) and not targets.is_empty():
				GameBus.missiles_fired.emit(player_idx, targets)
				_notify_missiles_fired(player_idx, targets)
			# Dano externo (misseis) pode derrotar um heroi ativo fora do ciclo de combate.
			if _end_battle_if_active_defeated():
				return true
			_emit_sync()
			return true

	return false

# ── helpers da fase ACTION ───────────────────────────────

## Chamado após cada carta ser adicionada a turn_cards/cards_this_battle.
## Verifica se a cadeia de símbolos ativa a skill do herói e notifica a passiva.
func _on_card_added_to_play(player_idx: int, card: Card) -> void:
	var pl: Player = players[player_idx]
	# Enfileira os efeitos AFTER_TURN desta carta para resolver após o combate.
	_enqueue_after_combat_effects(player_idx, card)
	# Consome bônus pendente para esta carta (definido pela carta anterior)
	if pl.pending_next_card_attack != 0:
		pl.pending_bonus_attack += pl.pending_next_card_attack
		pl.pending_next_card_attack = 0
	if pl.pending_next_card_defense != 0:
		pl.pending_bonus_defense += pl.pending_next_card_defense
		pl.pending_next_card_defense = 0
	# Fortaleza Inabalável: enquanto a flag está ativa, cada carta que aumenta a defesa
	# (defense_value > 0) dá +1 de ataque. A própria Fortaleza não conta (a flag só é
	# ligada pelo efeito dela depois deste ponto).
	if pl.pending_defense_scales_attack and card.defense_value > 0:
		pl.pending_bonus_attack += 1
	var active: Hero = pl.active_hero
	if active == null:
		return
	if not active._skill_activated_this_battle and not active.is_silenced():
		if active.is_skill_triggered(_build_chain(pl)):
			active.on_skill_activated(pl)
			var hero_idx := pl.heroes.find(active)
			_notify_skill_activated(pl.player_index, hero_idx, active.skill_desc)
			# Sintonia Primordial — compra 1 se habilidade ativa disparou
			if pl.pending_skill_draw:
				pl.pending_skill_draw = false
				pl.draw_cards(1)
				# TODO: animação específica de "compra por skill"; por ora reusa o fly de draw.
				_notify_effect_vfx(pl.player_index, "draw")

func _fire_on_card_played(player_idx: int, card: Card) -> void:
	var pl: Player = players[player_idx]
	var active: Hero = pl.active_hero
	if active != null:
		active.on_card_played(card, pl)

## Passiva de descarte: roda em TODOS os heróis do jogador com state == ACTIVE
## (não exausto/morto) — ativo OU retaguarda. Conectado a GameBus.card_discarded.
func _on_card_discarded_event(player_index: int, card: Card) -> void:
	if not multiplayer.is_server():
		return
	if player_index < 0 or player_index >= players.size():
		return
	var pl: Player = players[player_index]
	# Gatilho de descarte da própria carta (ex.: Descarga Residual → +N de defesa).
	card.execute_discard_effects(pl)
	for h in pl.heroes:
		if h.state != Hero.State.ACTIVE:
			continue
		var hero_idx := pl.heroes.find(h)
		# Passiva visível de herói furtivo (Relicar criando fragmento): adia e confirma
		# antes — disparar revela a identidade. A fila é drenada no fim do segmento.
		if h.discard_passive_reveals() and _is_hero_hidden(player_index, h):
			_stealth_passive_queue.append({
				"player_idx": player_index, "hero_idx": hero_idx, "card": card,
			})
			continue
		var desc := h.on_card_discarded(card, pl)
		if not desc.is_empty():
			GameBus.skill_activated.emit(h, desc)
			_notify_skill_activated(player_index, hero_idx, desc)

# ── confirmação de passiva de descarte que quebra furtividade (Relicar) ───────
# A passiva dispara sozinha (sinal card_discarded) no meio da resolução; não dá pra
# pausar a pilha em GDScript. Como o fragmento não tem efeito imediato, adiamos a
# confirmação para o ponto de convergência do segmento (_on_reaction_window_closed /
# resolução de pick), onde o jogador que descartou tem o controle e não há corrida
# com a janela de reação do oponente.

## Herói furtivo: ativo ainda oculto OU retaguarda não revelada.
func _is_hero_hidden(player_idx: int, hero: Hero) -> bool:
	if hero == players[player_idx].active_hero:
		return not _hero_revealed[player_idx]
	return not hero.is_backline_revealed

## Dispara a passiva de descarte de um herói (cria o token) e notifica o popup.
func _fire_discard_passive(player_idx: int, hero_idx: int, card: Card) -> void:
	var pl: Player = players[player_idx]
	var hero: Hero = pl.heroes[hero_idx]
	var desc := hero.on_card_discarded(card, pl)
	if not desc.is_empty():
		GameBus.skill_activated.emit(hero, desc)
		_notify_skill_activated(player_idx, hero_idx, desc)

## Revela o herói cuja passiva foi confirmada — ativo (quebra furtividade, emite
## hero_revealed) ou retaguarda (marca o flag; a UI atualiza pelo sync do snapshot).
func _reveal_hero_for_passive(player_idx: int, hero_idx: int) -> void:
	var hero: Hero = players[player_idx].heroes[hero_idx]
	if hero == players[player_idx].active_hero:
		_reveal_active_hero(player_idx)
	else:
		hero.is_backline_revealed = true

## Drena a fila de passivas furtivas. Itens cujo herói já foi revelado (ou ficou
## exausto/morto) resolvem na hora. No primeiro item ainda furtivo, abre a confirmação
## (sync) e devolve true — o chamador deve pausar. Devolve false se nada a confirmar.
func _start_stealth_confirm_if_pending() -> bool:
	if _stealth_passive_player >= 0:
		return true
	while not _stealth_passive_queue.is_empty():
		var entry: Dictionary = _stealth_passive_queue.pop_front()
		var p_idx: int = entry["player_idx"]
		var h_idx: int = entry["hero_idx"]
		var card: Card = entry.get("card")
		var hero: Hero = players[p_idx].heroes[h_idx]
		if not hero.is_alive() or hero.state != Hero.State.ACTIVE:
			continue
		if not _is_hero_hidden(p_idx, hero):
			_fire_discard_passive(p_idx, h_idx, card)
			continue
		_stealth_passive_player   = p_idx
		_stealth_passive_hero_idx = h_idx
		_stealth_passive_card     = card
		_emit_sync()
		return true
	return false

## Retoma o fluxo após drenar confirmações: encerra o segmento se o jogador ativo já
## completou ACTION + BONUS, senão apenas sincroniza.
func _advance_segment_or_sync() -> void:
	# Dano de area por cadeia (ex.: Chuva de Flechas) pode ter derrubado um heroi ativo
	# durante o segmento — encerra antes de seguir.
	if _end_battle_if_active_defeated():
		return
	if battle.current_phase == BattleManager.Phase.ACTION:
		var active := _active_segment_player
		if _segment_action_done[active] and _segment_bonus_done[active] and players[active].extra_actions == 0:
			_finish_segment(active)
			return
	_emit_sync()

func _clear_stealth_passive_queue() -> void:
	_stealth_passive_queue.clear()
	_stealth_passive_player   = -1
	_stealth_passive_hero_idx = -1
	_stealth_passive_card     = null

## Jogador responde Sim/Não à passiva de descarte furtiva. Sim revela o herói e cria
## o token; Não descarta a oportunidade (sem token, mantém a furtividade).
@rpc("any_peer", "call_local", "reliable")
func rpc_respond_stealth_passive(use: bool) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if player_idx != _stealth_passive_player:
		return
	var h_idx := _stealth_passive_hero_idx
	var card: Card = _stealth_passive_card
	_stealth_passive_player   = -1
	_stealth_passive_hero_idx = -1
	_stealth_passive_card     = null
	if use:
		_reveal_hero_for_passive(player_idx, h_idx)
		_fire_discard_passive(player_idx, h_idx, card)
	if _start_stealth_confirm_if_pending():
		return
	# Se a confirmação foi enfileirada durante o pós-combate (ex.: descarte forçado por
	# Execução Silenciosa), finaliza o combate em vez de avançar o segmento da fase ACTION.
	if _m._post_combat_pending:
		_finish_turn_combat()
		return
	_advance_segment_or_sync()

# ── Fila de efeitos AFTER_TURN ─────────────────────────────────────────────

func _enqueue_after_combat_effects(player_idx: int, card: Card) -> void:
	for effect in card.after_combat_effects():
		_m._after_combat_queue.append({
			"effect":       effect,
			"player":       player_idx,
			"card":         card,
			# TODO: threadear played_from_arsenal quando um efeito AFTER_TURN precisar.
			"from_arsenal": false,
			"hero_hidden":  _hero_was_hidden_at_play[player_idx],
		})

## Resolve, em ordem FIFO, os efeitos AFTER_TURN acumulados no turno.
## dmg_to_p0/dmg_to_p1 = dano sofrido por cada jogador no combate que acabou de resolver.
## Move a fila para um buffer de trabalho (reentrância: efeitos que enfileiram novos
## AFTER_TURN durante a resolução vão para a fila nova, não este lote) e processa.
func _drain_after_combat_queue(dmg_to_p0: int, dmg_to_p1: int) -> void:
	_m._after_combat_working = _m._after_combat_queue
	_m._after_combat_queue = []
	_m._after_combat_dmg = [dmg_to_p0, dmg_to_p1]
	_process_after_combat_queue()

## Drena o buffer de trabalho. Se um efeito abrir um pick (ex.: oponente escolhe a carta
## a descartar — Execução Silenciosa), pausa e retorna; rpc_submit_card_pick retoma daqui.
func _process_after_combat_queue() -> void:
	var dmg_taken: Array = _m._after_combat_dmg
	while not _m._after_combat_working.is_empty():
		var entry: Dictionary = _m._after_combat_working.pop_front()
		var pidx: int = entry["player"]
		var ctx := CardEffectContext.new()
		ctx.source_player       = players[pidx]
		ctx.opponent_player     = players[1 - pidx]
		ctx.source_card         = entry["card"]
		ctx.played_from_arsenal = entry["from_arsenal"]
		ctx.hero_was_hidden     = entry["hero_hidden"]
		ctx.damage_taken        = dmg_taken[pidx]
		ctx.damage_dealt        = dmg_taken[1 - pidx]
		var chain_before := players[pidx].bonus_chain_symbols.size()
		entry["effect"].resolve_after_combat(ctx)
		for r in ctx.requested_vfx:
			_notify_effect_vfx(pidx, r["key"], r["target_hero_idx"])
		for m in ctx.requested_moves:
			_notify_card_move(pidx, m["art_key"], m["kind"])
		for e in ctx.requested_empower:
			_notify_empower(pidx, e["atk"], e["def"], entry["card"].symbols)
		_announce_chain_symbols_added(pidx, chain_before)
		if _pending_pick_player >= 0 or _pending_ally_pick_player >= 0:
			return  # pausa: o pick aberto (carta ou herói) retoma o dreno ao ser resolvido

func _reset_action_phase_state() -> void:
	for p in players:
		p.reset_hero_turn_state()
	_active_segment_player    = battle.current_player_index
	_turn_first_player       = battle.current_player_index
	_segment_action_done      = [false, false]
	_segment_bonus_done       = [false, false]
	_reaction_window_for      = -1
	_reactions_locked         = false
	_consecutive_empty_turns = 0
	for i in 2:
		var _active := players[i].active_hero
		# Mantém revelado se a passiva de frontline foi ativada (Muro de Aço): a Valkar
		# já quebrou a furtividade na confirmação pós-seleção; não pode voltar a ocultar.
		_hero_revealed[i] = _active != null and (_active.starts_face_up or _active.wall_active)
	_pending_effect_card         = null
	_pending_effect_player       = -1
	_pending_effect_from_arsenal = false
	_pending_backline_ability    = {}
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
	_pending_symbol_to_chain       = false
	_pending_reveal_player         = -1
	_pending_reveal_card           = null

## Resolve os efeitos (não-AFTER_TURN) de uma carta E notifica o VFX de cada efeito
## que declara vfx_key — no MOMENTO real da resolução (ex.: heal após a janela de
## reação de uma ACTION). Centraliza os 3 pontos de resolução imediata.
func _resolve_card_effects(pidx: int, card: Card, from_arsenal: bool) -> void:
	var chain_before := players[pidx].bonus_chain_symbols.size()
	var ctx := _make_effect_ctx(pidx, card, from_arsenal)
	card.execute_effects(ctx)
	for r in ctx.requested_vfx:
		_notify_effect_vfx(pidx, r["key"], r["target_hero_idx"])
	for m in ctx.requested_moves:
		_notify_card_move(pidx, m["art_key"], m["kind"])
	for e in ctx.requested_empower:
		_notify_empower(pidx, e["atk"], e["def"], card.symbols)
	_announce_chain_symbols_added(pidx, chain_before)

## Após um efeito injetar símbolos na chain (ex.: Descarga Preparada → Raio), exibe cada
## novo símbolo nos clientes (reusa o VFX do Fragmento) e re-verifica a skill do herói ativo.
func _announce_chain_symbols_added(pidx: int, before_count: int) -> void:
	var pl: Player = players[pidx]
	if pl.bonus_chain_symbols.size() <= before_count:
		return
	for i in range(before_count, pl.bonus_chain_symbols.size()):
		var sym: String = pl.bonus_chain_symbols[i]
		GameBus.fragment_symbol_added.emit(pidx, sym)
		_notify_fragment_symbol_added(pidx, sym)
	_recheck_active_skill(pidx)

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
	_resolve_card_effects(pidx, card, from_arsenal)
	print("[PendingEffect] Mão P0 após efeito: %d cartas | Mão P1 após efeito: %d cartas" % [players[0].hand.size(), players[1].hand.size()])

# ── pick de carta (efeitos que precisam de input do jogador) ──────────────

func get_pending_pick_player() -> int:
	return _pending_pick_player

func get_pending_pick_source() -> PickSource:
	return _pending_pick_source

func get_pending_pick_count() -> int:
	return _pending_pick_count

func get_pending_pick_draw_after() -> int:
	return _pending_pick_draw_after

func get_pending_pick_instruction() -> String:
	return _pending_pick_instruction

func get_pending_pick_variable() -> bool:
	return _pending_pick_variable

func get_pending_overload_player() -> int:
	return _pending_overload_player

func get_pending_overload_phase() -> int:
	return _pending_overload_phase

func get_pending_overload_points() -> int:
	return _pending_overload_points

func get_pending_symbol_player() -> int:
	return _pending_symbol_player

func get_pending_symbol_count() -> int:
	return _pending_symbol_count

func get_pending_reveal_player() -> int:
	return _pending_reveal_player

## Carta revelada "só olhar" (efeito do Fragmento Arcano). No cliente vem do snapshot.
func get_pending_reveal_card() -> Card:
	return _pending_reveal_card

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
		PickSource.GRAVEYARD, PickSource.GRAVEYARD_ARSENAL, \
		PickSource.GRAVEYARD_TO_TOP, PickSource.GRAVEYARD_TO_HAND:
			return players[player_idx].discard_pile
		PickSource.HAND, PickSource.HAND_DISCARD, PickSource.HAND_ARSENAL:
			return players[player_idx].hand
		_:
			return players[player_idx].deck

## Recordar — pick do cemitério: a carta escolhida vai ao TOPO do deck.
func begin_graveyard_to_top_pick(player_idx: int, indices: Array[int], instruction: String = "") -> void:
	_pending_pick_player      = player_idx
	_pending_pick_source      = PickSource.GRAVEYARD_TO_TOP
	_pending_pick_count       = 1
	_pending_pick_indices     = indices
	_pending_pick_instruction = instruction

## Ressurgir — pick do cemitério: a carta escolhida vai para a MÃO. followup_player: se >=0,
## abre o mesmo pick para esse jogador depois (cada jogador recupera 1).
func begin_graveyard_to_hand_pick(player_idx: int, indices: Array[int], followup_player: int = -1, instruction: String = "") -> void:
	_pending_pick_player           = player_idx
	_pending_pick_source           = PickSource.GRAVEYARD_TO_HAND
	_pending_pick_count            = 1
	_pending_pick_indices          = indices
	_pending_pick_instruction      = instruction
	_pending_both_recycle_followup = followup_player

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
	_pending_pick_variable    = false
	_pending_pick_draw_after  = draw_after
	_pending_pick_indices     = indices
	_pending_pick_instruction = instruction

## Descarte de quantidade VARIÁVEL (0..indices.size()): o jogador escolhe quantas/quais.
## Para cada carta descartada com símbolo bonus_symbol, soma bonus_attack ao ataque pendente
## do jogador (ex.: Incinerar Tudo — +2 por carta de Fogo). bonus_symbol "" = sem bônus.
func begin_hand_discard_variable(player_idx: int, indices: Array[int], bonus_symbol: String, bonus_attack: int, instruction: String = "") -> void:
	_pending_pick_player       = player_idx
	_pending_pick_source       = PickSource.HAND_DISCARD
	_pending_pick_count        = indices.size()   # máximo selecionável
	_pending_pick_variable     = true
	_pending_pick_draw_after   = 0
	_pending_pick_indices      = indices
	_pending_pick_instruction  = instruction
	_pending_pick_bonus_symbol = bonus_symbol
	_pending_pick_bonus_attack = bonus_attack

## Sobrecarga de Núcleo: abre a fase 1 (escolher tokens a destruir). Sem tokens, não faz nada.
func begin_core_overload(player_idx: int) -> void:
	if players[player_idx].tokens.is_empty():
		return
	_pending_overload_player = player_idx
	_pending_overload_phase  = 1
	_pending_overload_points = 0

## Inicia um pick de herói (aliado OU inimigo). Ex.: Broto Vital (curar aliado), Exaurir
## (exaustar inimigo da retaguarda), Reanimar (tirar exaustão de aliado).
## action: "heal"|"cleanse_heal"|"exhaust"|"unexhaust"|"sacrifice_heal" · amount: valor do efeito.
## side: 0 = próprio time · 1 = time inimigo. filter: "" (qualquer vivo) · "exhausted" · "backline".
## Fizzle silencioso (nada acontece) se não houver alvo válido para o filtro/side.
func begin_ally_pick(player_idx: int, action: String, amount: int, side: int = 0, filter: String = "") -> void:
	if not _has_valid_hero_pick_target(player_idx, side, filter):
		return
	_pending_ally_pick_player = player_idx
	_pending_ally_pick_action = action
	_pending_ally_pick_amount = amount
	_pending_ally_pick_side   = side
	_pending_ally_pick_filter = filter

## True se existe ao menos 1 herói válido para um pick com este side/filter.
func _has_valid_hero_pick_target(player_idx: int, side: int, filter: String) -> bool:
	var team_idx := (1 - player_idx) if side == 1 else player_idx
	if team_idx < 0 or team_idx >= players.size():
		return false
	var team := players[team_idx]
	for h in team.heroes:
		if _hero_pick_selectable(h, team, filter):
			return true
	return false

## Regra de seleção de um herói num pick, dado o filtro.
func _hero_pick_selectable(h: Hero, team: Player, filter: String) -> bool:
	match filter:
		"exhausted":
			return h.state == Hero.State.EXHAUSTED
		"backline":
			# Vivo, não-exausto e NÃO é o ativo (retaguarda disponível).
			return h.is_alive() and h.state != Hero.State.EXHAUSTED and h != team.active_hero
		_:
			return h.is_alive()

func get_pending_ally_pick_player() -> int: return _pending_ally_pick_player
func get_pending_ally_pick_action()  -> String: return _pending_ally_pick_action
func get_pending_ally_pick_amount()  -> int: return _pending_ally_pick_amount
func get_pending_ally_pick_side()    -> int: return _pending_ally_pick_side
func get_pending_ally_pick_filter()  -> String: return _pending_ally_pick_filter

## O jogador escolheu um herói. hero_idx = índice em players[team].heroes, onde team é o
## próprio time ou o inimigo conforme _pending_ally_pick_side.
@rpc("any_peer", "call_local", "reliable")
func rpc_submit_ally_pick(hero_idx: int) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if _pending_ally_pick_player != player_idx:
		return
	var team_idx := (1 - player_idx) if _pending_ally_pick_side == 1 else player_idx
	var team := players[team_idx]
	if hero_idx < 0 or hero_idx >= team.heroes.size():
		return
	var target_hero := team.heroes[hero_idx]
	# Valida contra o filtro para impedir escolhas ilegais vindas do cliente.
	if not _hero_pick_selectable(target_hero, team, _pending_ally_pick_filter):
		return
	var action := _pending_ally_pick_action
	var amount := _pending_ally_pick_amount
	match action:
		"heal":
			var hp_before := target_hero.current_hp
			target_hero.heal(amount)
			# VFX de cura no aliado ESCOLHIDO (origem é a carta, alvo é este herói).
			_notify_effect_vfx(player_idx, "heal", hero_idx)
			var gained := target_hero.current_hp - hp_before
			print("[TCG]   ♥ Ally Pick (J%d): curou %s (+%d HP)" % [player_idx, target_hero.hero_name, gained])
		"cleanse_heal":
			# Toque Límpido — Purifica (remove Queimaduras) e cura o aliado escolhido.
			target_hero.clear_burn()
			target_hero.heal(amount)
			_notify_effect_vfx(player_idx, "heal", hero_idx)
			print("[TCG]   ✦ Ally Pick (J%d): purificou e curou %s" % [player_idx, target_hero.hero_name])
		"exhaust":
			# Exaurir / Peso da Alma — exausta um herói inimigo da retaguarda (nega a rotação).
			target_hero.exhaust()
			print("[TCG]   💤 Hero Pick (J%d): exaustou %s (J%d)" % [player_idx, target_hero.hero_name, team_idx])
		"unexhaust":
			# Reanimar / Despertar Sombrio — remove a exaustão (volta ao estado ACTIVE).
			target_hero.refresh()
			print("[TCG]   ⟳ Hero Pick (J%d): removeu exaustão de %s" % [player_idx, target_hero.hero_name])
		"sacrifice_heal":
			# Banquete de Sombras — sacrifica `amount` de HP do aliado escolhido; o ativo cura `amount`.
			var tctx := TurnContext.new()
			tctx.defender = target_hero
			target_hero.take_damage(amount, tctx)
			GameBus.hero_damaged.emit(target_hero, amount)
			var active := players[player_idx].active_hero
			if active != null:
				active.heal(amount)
				_notify_effect_vfx(player_idx, "heal")
			print("[TCG]   🩸 Hero Pick (J%d): sacrificou %s → curou o ativo" % [player_idx, target_hero.hero_name])
	_pending_ally_pick_player = -1
	_pending_ally_pick_action = ""
	_pending_ally_pick_amount = 0
	_pending_ally_pick_side   = 0
	_pending_ally_pick_filter = ""
	# Pick aberto por efeito on-hit durante o dreno pós-combate (ex.: Exaurir) → retoma o dreno.
	if _pending_pick_player < 0 and _m._post_combat_pending:
		_continue_post_combat()
		return
	# Retoma o fluxo do segmento se possível
	if _pending_pick_player < 0 and _pending_symbol_player < 0 \
			and battle.current_phase == BattleManager.Phase.ACTION:
		var active := _active_segment_player
		if _segment_action_done[active] and _segment_bonus_done[active] and players[active].extra_actions == 0:
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

# ── Loja do Fragmento Arcano (Relicar) ───────────────────────────────────────
# Fragmentos são moeda: cada efeito tem um custo. Disponível no SEU turno (segmento
# ACTION, sem janela de reação nem pick pendente), independente de qual herói está ativo.
const FRAGMENT_TOKEN_ID := "arcane_fragment"
const FRAGMENT_COSTS := { "peek": 1, "symbol": 2, "draw": 3 }

## Pode usar a loja agora? (mesmo gating do disparo de míssil, mas não exige herói específico.)
func can_use_fragment_shop(player_idx: int) -> bool:
	if _winner_index >= 0 or battle.current_phase != BattleManager.Phase.ACTION:
		return false
	if player_idx != _active_segment_player or _reaction_window_for != -1:
		return false
	if _pending_pick_player >= 0 or _pending_symbol_player >= 0 \
			or _pending_ally_pick_player >= 0 or _pending_reveal_player >= 0 \
			or _stealth_passive_player >= 0 or _pending_overload_player >= 0:
		return false
	return players[player_idx].count_tokens(FRAGMENT_TOKEN_ID) > 0

## Compra um efeito da loja, pagando seu custo em fragmentos. effect_id ∈ peek/symbol/draw.
func action_buy_fragment_effect(player_idx: int, effect_id: String) -> bool:
	if not can_use_fragment_shop(player_idx):
		return false
	var cost: int = int(FRAGMENT_COSTS.get(effect_id, 0))
	if cost <= 0:
		return false
	var pl: Player = players[player_idx]
	if pl.count_tokens(FRAGMENT_TOKEN_ID) < cost:
		return false
	# Não gasta fragmentos num efeito que seria no-op (olhar/comprar com deck vazio).
	if (effect_id == "peek" or effect_id == "draw") and pl.deck.is_empty():
		return false
	_consume_fragments(pl, cost)
	print("[TCG] Jogador %d (%s): gastou %d Fragmento(s) Arcano(s) em '%s'" % [player_idx, pl.player_name, cost, effect_id])
	match effect_id:
		"peek":
			_begin_deck_reveal(player_idx)
		"symbol":
			_pending_symbol_to_chain = true
			begin_symbol_pick(player_idx, null, 1, false)
		"draw":
			pl.draw_cards(1)
	# Feedback pros dois jogadores de que um efeito foi comprado.
	GameBus.fragment_used.emit(player_idx, effect_id, cost)
	_notify_fragment_used(player_idx, effect_id, cost)
	_emit_sync()
	return true

## Remove `count` Fragmentos Arcanos do jogador.
func _consume_fragments(pl: Player, count: int) -> void:
	var removed := 0
	var i := 0
	while i < pl.tokens.size() and removed < count:
		if pl.tokens[i].token_id == FRAGMENT_TOKEN_ID:
			pl.tokens.remove_at(i)
			removed += 1
		else:
			i += 1

## Efeito "só olhar": revela (não remove) a carta do topo do deck para o jogador.
func _begin_deck_reveal(player_idx: int) -> void:
	if players[player_idx].deck.is_empty():
		return
	_pending_reveal_player = player_idx
	_pending_reveal_card   = players[player_idx].deck[0]

## Jogador fechou a revelação (só informação — sem efeito no estado).
@rpc("any_peer", "call_local", "reliable")
func rpc_ack_reveal() -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if player_idx != _pending_reveal_player:
		return
	_pending_reveal_player = -1
	_pending_reveal_card   = null
	_emit_sync()

## Re-verifica a skill ativa do jogador com a chain atual (cards_this_battle +
## bonus_chain_symbols). Usado após injetar símbolo via Fragmento Arcano.
func _recheck_active_skill(player_idx: int) -> void:
	var pl: Player = players[player_idx]
	var active: Hero = pl.active_hero
	if active == null or active._skill_activated_this_battle or active.is_silenced():
		return
	if active.is_skill_triggered(_build_chain(pl)):
		active.on_skill_activated(pl)
		var hero_idx := pl.heroes.find(active)
		_notify_skill_activated(player_idx, hero_idx, active.skill_desc)
		if pl.pending_skill_draw:
			pl.pending_skill_draw = false
			pl.draw_cards(1)
			# TODO: animação específica de "compra por skill"; por ora reusa o fly de draw.
			_notify_effect_vfx(player_idx, "draw")

## Cadeia de símbolos do jogador: símbolos das cartas jogadas + bônus injetados.
func _build_chain(pl: Player) -> Array[String]:
	# Intercala simbolos de cartas e de fragmentos na ordem CRONOLOGICA em que entraram.
	# Um fragmento com posicao p aparece logo apos as p primeiras cartas jogadas.
	var chain: Array[String] = []
	var n := pl.cards_this_battle.size()
	for i in n:
		for k in pl.bonus_chain_symbols.size():
			if pl.bonus_chain_positions[k] == i:
				chain.append(pl.bonus_chain_symbols[k])
		for sym in pl.cards_this_battle[i].symbols:
			chain.append(sym)
	# Fragmentos injetados depois de todas as cartas jogadas ate agora.
	for k in pl.bonus_chain_symbols.size():
		if pl.bonus_chain_positions[k] >= n:
			chain.append(pl.bonus_chain_symbols[k])
	return chain

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
	_activate_wall_on_reveal(player_idx)

## Revela o herói ativo incondicionalmente (usado por habilidades ativadas, que
## não passam por carta — toda ativação visível revela o herói).
func _reveal_active_hero(player_idx: int) -> void:
	if _hero_revealed[player_idx]:
		return
	var h: Hero = players[player_idx].active_hero
	if h == null:
		return
	_hero_revealed[player_idx] = true
	GameBus.hero_revealed.emit(player_idx, h)
	_activate_wall_on_reveal(player_idx)

# Chamado quando a janela de reação fecha (pass ou carta REACTION jogada).
# Se o segmento ativo já completou ACTION e BONUS, encerra-o. Caso contrário,
# apenas sincroniza — o jogador ainda pode jogar a outra carta.
## Resolve a habilidade de retaguarda que ficou pendente até a reação fechar (ex.:
## Darian: aplica as rosas + dispara o VFX + popup só agora, depois da reação).
func _resolve_pending_backline_ability() -> void:
	if _pending_backline_ability.is_empty():
		return
	var data: Dictionary = _pending_backline_ability
	_pending_backline_ability = {}
	var pidx: int = int(data.get("player", -1))
	if pidx < 0 or pidx > 1:
		return
	var pl: Player = players[pidx]
	var opp: Player = players[1 - pidx]
	var ability_id: String = str(data.get("id", ""))
	var targets: Array = data.get("targets", [])
	var src_idx: int = int(data.get("src_hero_idx", -1))
	var label := pl.activate_ability(ability_id, opp, targets)
	if not label.is_empty():
		var src_hero: Hero = pl.heroes[src_idx] if src_idx >= 0 and src_idx < pl.heroes.size() else pl.active_hero
		GameBus.skill_activated.emit(src_hero, label)
		_notify_skill_activated(pidx, src_idx, label)

func _on_reaction_window_closed() -> void:
	# Habilidade de retaguarda (Darian) declarada agora RESOLVE — depois da reação.
	_resolve_pending_backline_ability()
	_execute_pending_effect()
	# If an effect triggered a pick, pause here — _continue_after_pick() resumes the flow.
	# Sobrecarga de Núcleo abre o fluxo de tokens/distribuição (_pending_overload_player).
	if _pending_pick_player >= 0 or _pending_symbol_player >= 0 or _pending_ally_pick_player >= 0 or _pending_overload_player >= 0:
		_emit_sync()
		return
	# Passiva de descarte furtiva (Relicar) enfileirada durante o efeito → confirma antes de seguir.
	if _start_stealth_confirm_if_pending():
		return
	_advance_segment_or_sync()

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
	return _player_out_of_cards(0) and _player_out_of_cards(1)

## Jogador sem recursos jogáveis: mão vazia E arsenal vazio.
## A carta do arsenal ainda pode ser jogada, então conta como recurso.
func _player_out_of_cards(player_idx: int) -> bool:
	return players[player_idx].hand.is_empty() and players[player_idx].arsenal.is_empty()

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
	# Resolve os efeitos AFTER_TURN enfileirados neste turno (dano já conhecido).
	# Entra no pós-combate: pode pausar se um efeito abrir um pick (oponente escolhe a
	# carta a descartar) ou enfileirar a passiva de descarte furtiva do Relicar.
	_m._post_combat_pending = true
	_drain_after_combat_queue(_cap[0], _cap[1])
	_after_combat_converge()

## Ponto de convergência do pós-combate: se um efeito AFTER_TURN abriu um pick (oponente
## escolhe descarte) ou enfileirou a passiva de descarte furtiva (Relicar), pausa esperando
## a resposta do jogador; caso contrário, finaliza o combate.
func _after_combat_converge() -> void:
	if _pending_pick_player >= 0:
		_emit_sync()
		return
	if _start_stealth_confirm_if_pending():
		return
	_finish_turn_combat()

## Conclui o pós-combate após o dreno (e eventuais picks). Limpa turn_cards, decide
## vencedor/baixas e inicia nova rodada ou entra na END. Separado de _resolve_turn_combat
## para poder ser retomado depois de um pick aberto por efeito AFTER_TURN.
func _finish_turn_combat() -> void:
	_m._post_combat_pending = false
	# Selo da Ruína (Lilith) sai assim que ESTE combate resolve: o banimento já disparou
	# durante o CombatResolver + dreno pós-combate acima, então a marca some agora e NÃO
	# persiste para as próximas rodadas. (Rosas Negras do Darian NÃO saem aqui — persistem
	# até a especial explodi-las.)
	for p in players:
		for h in p.heroes:
			h.sealed_ruin = false
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
		_conclude_match(w)
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

## Retoma o pós-combate após um pick aberto por efeito AFTER_TURN ser resolvido.
## Continua drenando a fila (pode haver outro pick) e converge — o descarte do pick pode
## ter enfileirado a passiva de descarte furtiva do Relicar, resolvida na convergência.
func _continue_post_combat() -> void:
	_process_after_combat_queue()
	_after_combat_converge()

func _any_active_hero_defeated() -> bool:
	for p in players:
		if p.active_hero != null and p.active_hero.state == Hero.State.DEFEATED:
			return true
	return false

## Encerra a batalha JA se algum heroi ativo (linha de frente) foi derrotado fora do
## ciclo de combate (dano direto de missil/retaguarda/habilidade de area). Pula para
## o arsenal (END). Retorna true se encerrou — o chamador deve abortar seu fluxo.
func _end_battle_if_active_defeated() -> bool:
	var w := _evaluate_winner()
	if w >= 0:
		_conclude_match(w)
		_run_combat_and_enter_end()
		return true
	if _any_active_hero_defeated():
		_run_combat_and_enter_end()
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
	# Queimadura tica no FIM do turno (após o combate deste turno), antes das passivas de
	# cura de fim de turno — assim o Cleric pode compensar. Pode derrotar heróis.
	_tick_burn()
	var burn_winner := _evaluate_winner()
	if burn_winner >= 0 and _winner_index < 0:
		_conclude_match(burn_winner)
	# Fonte da Vida — regeneração de área tica no fim do turno (após a Queimadura).
	_tick_team_regen()
	# Status negativos de Ecos (veneno/sangramento/marca/ferida/silêncio) perdem 1 turno de
	# duração no fim do turno. Depois da regeneração (a Ferida ainda bloqueia a cura deste turno).
	_tick_status_decay()
	# Onda Reversa: carta vai ao fundo do deck em vez do cemitério
	for p in players:
		if p.pending_return_card != null:
			p.cards_this_battle.erase(p.pending_return_card)
			p.deck.append(p.pending_return_card)
			p.pending_return_card = null
	# Ciclo Vital: a carta marcada retorna à mão SÓ se o herói ativo terminar o combate
	# com vida cheia (checado aqui, com o HP final); senão segue para o cemitério.
	for p in players:
		if p.pending_heal_return_card != null:
			var h: Hero = p.active_hero
			if h != null and h.current_hp >= h.max_hp:
				p.cards_this_battle.erase(p.pending_heal_return_card)
				p.hand.append(p.pending_heal_return_card)
			p.pending_heal_return_card = null
	# Todas as cartas jogadas no turno inteiro vão ao cemitério agora (END phase).
	for p in players:
		p.discard_pile.append_array(p.cards_this_battle)
	players[0].clear_combat_cards()
	players[1].clear_combat_cards()
	# (O Selo da Ruína já foi limpo em _finish_turn_combat, logo após o combate resolver.)
	# Só os tokens marcados (ex.: Mísseis Mágicos) somem quando o combate resolve;
	# os persistentes (ex.: Fragmento Arcano) ficam no campo até serem usados.
	players[0].clear_combat_end_tokens()
	players[1].clear_combat_end_tokens()
	# Confirmações de passiva de descarte pendentes não fazem mais sentido neste turno.
	_clear_stealth_passive_queue()

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

	# Exausta heróis e devolve aos slots. Iluminação (Nissin): se pending_prevent_exhaust,
	# o herói ativo NÃO exausta (fica disponível). A flag é consumida aqui.
	for i in 2:
		if players[i].pending_prevent_exhaust:
			players[i].pending_prevent_exhaust = false
		else:
			players[i].exhaust_active_hero()
		players[i].active_hero = null
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

## Aplica os status persistentes de todos os heróis vivos no início de um turno:
## escudo persistente (re-aplica/expira) e Queimadura (dano no início do turno).
## Chamado por _begin_battle_for_active_player antes da fase DRAW.
## Escudo persistente: re-aplica a cada herói vivo no INÍCIO do turno, expira ao zerar.
## (A Queimadura tica no FIM do turno — ver _tick_burn.)
func _tick_persistent_shields() -> void:
	for p in players:
		for h in p.heroes:
			if h.state == Hero.State.DEFEATED:
				continue
			if h.shield_turns > 0:
				h.shield_turns -= 1
				if h.shield_turns <= 0:
					h.shield_per_turn = 0
					h.damage_shield = 0
				else:
					h.damage_shield = maxi(h.damage_shield, h.shield_per_turn)

## Queimadura: no FIM de cada turno, todo herói vivo (ativo OU retaguarda exausto) com
## queimadura perde burn_amount de vida (ignora escudo — não é ataque) e decrementa 1 turno.
func _tick_burn() -> void:
	for p in players:
		for h in p.heroes:
			if h.state == Hero.State.DEFEATED:
				continue
			if h.burn_turns > 0 and h.burn_amount > 0:
				var burn := h.burn_amount
				h.burn_turns -= 1
				if h.burn_turns <= 0:
					h.burn_amount = 0
					h.burn_is_dark = false
				var ctx := TurnContext.new()
				ctx.defender = h
				h.take_damage(burn, ctx)
				GameBus.hero_damaged.emit(h, burn)
				print("[TCG] Queimadura: %s (J%d) perde %d (HP %d)" % [h.hero_name, p.player_index, burn, h.current_hp])

## Fonte da Vida: no FIM de cada turno, cada jogador com regeneração ativa cura o time
## inteiro (heróis vivos) em team_regen_amount e decrementa 1 turno. Espelha _tick_burn.
func _tick_team_regen() -> void:
	for i in 2:
		var p: Player = players[i]
		if p.team_regen_turns <= 0 or p.team_regen_amount <= 0:
			continue
		var amount := p.team_regen_amount
		p.team_regen_turns -= 1
		if p.team_regen_turns <= 0:
			p.team_regen_amount = 0
		for h in p.heroes:
			if h.is_alive():
				h.heal(amount)
		_notify_effect_vfx(i, "heal_all")
		print("[TCG] Regeneração: time J%d cura %d" % [i, amount])

## Decaimento (1 turno) dos status negativos de duração de Ecos, no fim do turno. O dano do
## Sangramento é aplicado no combate (CombatResolver); a Queimadura, em _tick_burn. Aqui só
## encolhe as durações. Roda em todo herói vivo (ativo ou retaguarda).
func _tick_status_decay() -> void:
	for p in players:
		for h in p.heroes:
			if h.state == Hero.State.DEFEATED:
				continue
			if h.poison_turns > 0:
				h.poison_turns -= 1
			if h.bleed_turns > 0:
				h.bleed_turns -= 1
				if h.bleed_turns <= 0:
					h.bleed_amount = 0
			if h.mark_turns > 0:
				h.mark_turns -= 1
				if h.mark_turns <= 0:
					h.mark_bonus = 0
			if h.wound_turns > 0:
				h.wound_turns -= 1
			if h.silence_turns > 0:
				h.silence_turns -= 1

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
		HeroNox.new(),  # DEBUG: Nox no slot 0 para testar mísseis mágicos
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
		"Nox":                return HeroNox.new()
		"Relicar":            return HeroRelicar.new()
		"Slime":              return HeroSlime.new()
		"Lai'can":            return HeroLaican.new()
		"Darian":             return HeroDarian.new()
		"Lilith":             return HeroLilith.new()
	push_warning("GameState: herói desconhecido '%s'" % hero_name)
	return null


static func _build_deck_from_entries(entries: Array) -> Array[Card]:
	var out: Array[Card] = []
	for entry in entries:
		var cname: String = str(entry.get("name", ""))
		var count: int    = int(entry.get("count", 1))
		var foil: int     = clampi(int(entry.get("foil", 0)), 0, count)
		var card_dict := Collection.get_card_dict(cname)
		if card_dict.is_empty():
			push_warning("GameState: carta '%s' não encontrada na coleção" % cname)
			continue
		# As primeiras `foil` cópias desta carta entram como holográficas (escolha do deck).
		for i in count:
			var card := Card.from_dict(card_dict)
			card.is_foil = i < foil
			out.append(card)
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
	atk0 -= p0.battle_attack_penalty  # Finta: debuff do próprio atacante

	var def0 := h0.base_defense
	for card in p0.turn_cards:
		def0 += card.defense_value
	def0 -= p0.next_defense_penalty
	def0 += p0.pending_bonus_defense

	var atk1 := h1.base_attack
	for card in p1.turn_cards:
		atk1 += card.attack_value
	atk1 += p1.pending_bonus_attack + p1.passive_attack_bonus + p1.battle_bonus_attack + p1.next_turn_bonus_attack
	atk1 -= p1.battle_attack_penalty  # Finta: debuff do próprio atacante

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

# ── rolagem de dados de abertura (OPENING_ROLL) ──────────────────────────────

## Jogador arremessou seus dados. O servidor sorteia 2d6 (autoritativo) e guarda o
## vetor do arremesso (cosmético, para o oponente animar). Quando ambos arremessam:
## empate → re-roll; senão define o vencedor, que escolherá quem começa.
@rpc("any_peer", "call_local", "reliable")
func rpc_submit_dice_throw(dir_x: float, dir_y: float, force: float) -> void:
	if not multiplayer.is_server():
		return
	if battle.current_phase != BattleManager.Phase.OPENING_ROLL:
		return
	if _dice_awaiting_choice:
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if player_idx < 0 or player_idx > 1 or _dice_thrown[player_idx]:
		return
	_dice_values[player_idx]    = [randi_range(1, 6), randi_range(1, 6)]
	_dice_throw_vec[player_idx] = Vector2(dir_x, dir_y)
	_dice_thrown[player_idx]    = true
	print("[TCG] Jogador %d rolou os dados: %s (total %d)" % [player_idx, str(_dice_values[player_idx]), get_dice_total(player_idx)])
	if _dice_thrown[0] and _dice_thrown[1]:
		var t0 := get_dice_total(0)
		var t1 := get_dice_total(1)
		if t0 == t1:
			# Empate → re-roll (mantém a fase, limpa os arremessos).
			_dice_thrown    = [false, false]
			_dice_values    = [[0, 0], [0, 0]]
			_dice_throw_vec = [Vector2.ZERO, Vector2.ZERO]
			print("[TCG] Empate nos dados (%d x %d) — re-roll" % [t0, t1])
		else:
			_dice_winner          = 0 if t0 > t1 else 1
			_dice_awaiting_choice = true
			print("[TCG] Jogador %d venceu a rolagem (%d x %d)" % [_dice_winner, t0, t1])
	_emit_sync()

## O vencedor da rolagem escolhe quem começa a partida. Conclui a OPENING_ROLL e
## entra no OPENING_MULLIGAN.
@rpc("any_peer", "call_local", "reliable")
func rpc_choose_first_player(first_idx: int) -> void:
	if not multiplayer.is_server():
		return
	if battle.current_phase != BattleManager.Phase.OPENING_ROLL or not _dice_awaiting_choice:
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if player_idx != _dice_winner:
		return
	if first_idx < 0 or first_idx > 1:
		return
	_first_player         = first_idx
	_dice_awaiting_choice = false
	print("[TCG] Jogador %d escolheu que o jogador %d começa" % [_dice_winner, first_idx])
	battle.current_phase = BattleManager.Phase.OPENING_MULLIGAN
	battle.emit_phase_changed()
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

## DEBUG — dá uma carta do catálogo (por card_id) direto na mão do jogador.
## Só funciona em partidas de teste (sala debug criada por ADMIN); fora delas é no-op.
## Ferramenta de teste: evita ter que mexer no código e reiniciar o servidor a cada carta.
@rpc("any_peer", "call_local", "reliable")
func rpc_debug_give_card(card_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_idx := _peer_to_player_index(sender)
	if player_idx < 0:
		return
	if _m == null or not _m._debug:
		print("[DEBUG] rpc_debug_give_card ignorado: partida não é de teste")
		return
	var d := Collection.get_card_dict_by_id(card_id)
	if d.is_empty():
		print("[DEBUG] rpc_debug_give_card: carta id:%d não existe no catálogo" % card_id)
		return
	var card := Card.from_dict(d)
	players[player_idx].hand.append(card)
	GameBus.card_drawn.emit(player_idx)
	print("[DEBUG] Carta '%s' (id:%d) dada à mão do Jogador %d (sala debug)" % [card.card_name, card_id, player_idx])
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

## Ativa uma habilidade do herói ativo. `targets` só é usado por habilidades FREE
## que miram (ex.: disparar mísseis) — cada item é [player_idx, hero_idx].
@rpc("any_peer", "call_local", "reliable")
func rpc_activate_ability(ability_id: String, targets: Array = []) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	action_activate_ability(player_idx, ability_id, targets)
	_emit_sync()

## Compra um efeito da loja do Fragmento Arcano (effect_id ∈ peek/symbol/draw).
@rpc("any_peer", "call_local", "reliable")
func rpc_buy_fragment_effect(effect_id: String) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	action_buy_fragment_effect(player_idx, str(effect_id))

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
	# DECK_PEEK permite 0 ou 1 índice (0 = manter no topo, 1 = mover ao fundo).
	# HAND_ARSENAL é opcional (Passo Estratégico): 0 = não guardar, 1 = guardar.
	if _pending_pick_source == PickSource.DECK_PEEK or _pending_pick_source == PickSource.HAND_ARSENAL:
		if pick_indices.size() > 1:
			return
		for pi in pick_indices:
			if pi < 0 or pi >= _pending_pick_indices.size():
				return
	elif _pending_pick_variable:
		# Descarte variável: 0..máximo. Sem duplicatas e dentro do range.
		if pick_indices.size() > _pending_pick_count:
			return
		for pi in pick_indices:
			if pi < 0 or pi >= _pending_pick_indices.size():
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
			# Carta escolhida vai para a mão (índice único) — tutor
			var source_idx: int = _pending_pick_indices[pick_indices[0]]
			if source_idx < p.deck.size():
				p.hand.append(p.deck[source_idx])
				p.deck.remove_at(source_idx)
				GameBus.card_drawn.emit(player_idx)
				_notify_effect_vfx(player_idx, "draw")   # tutor: fly da carta buscada
			_shuffle_deck(p.deck)
			GameBus.deck_shuffled.emit(player_idx)
			_notify_deck_shuffled(player_idx)             # tutor também embaralha (anima)
		PickSource.GRAVEYARD:
			# Carta escolhida vai ao fundo do deck; compra draw_after cartas
			var source_idx: int = _pending_pick_indices[pick_indices[0]]
			if source_idx < p.discard_pile.size():
				var card := p.discard_pile[source_idx]
				p.discard_pile.remove_at(source_idx)
				p.deck.append(card)
			if _pending_pick_draw_after > 0:
				p.draw_cards(_pending_pick_draw_after)
				_notify_effect_vfx(player_idx, "draw")   # recycle_graveyard_draw: só o fly
		PickSource.HAND:
			# Carta escolhida da mão vai ao fundo do deck (índice único)
			var source_idx: int = _pending_pick_indices[pick_indices[0]]
			if source_idx < p.hand.size():
				var card := p.hand[source_idx]
				p.hand.remove_at(source_idx)
				p.deck.append(card)
				_notify_card_move(player_idx, card.art_key, "to_deck")   # carta → baralho
			if _pending_pick_draw_after > 0:
				p.draw_cards(_pending_pick_draw_after)
				_notify_effect_vfx(player_idx, "draw")   # put_bottom_then_draw: depois do to_deck
		PickSource.HAND_DISCARD:
			# Cartas escolhidas vão ao cemitério — remover do maior para o menor índice
			var real_indices: Array[int] = []
			for pi in pick_indices:
				real_indices.append(_pending_pick_indices[pi])
			real_indices.sort()
			real_indices.reverse()   # maior primeiro para não deslocar índices
			# Bônus de ataque por carta descartada do símbolo alvo (Incinerar Tudo → Fogo).
			var discard_bonus := 0
			var bonus_symbol_count := 0
			for source_idx in real_indices:
				if source_idx < p.hand.size():
					var disc: Card = p.hand[source_idx]
					if _pending_pick_bonus_symbol != "" and _pending_pick_bonus_symbol in disc.symbols:
						discard_bonus += _pending_pick_bonus_attack
						bonus_symbol_count += 1
					p.hand.remove_at(source_idx)
					p.send_to_discard(disc)
					_notify_card_move(player_idx, disc.art_key, "discard")
			if discard_bonus != 0:
				p.pending_bonus_attack += discard_bonus
			# Fúria Incandescente: nº de cartas de Fogo descartadas → duração da Queimadura
			# on-hit (lida pelo efeito burn_on_hit_per_fire após o combate).
			if _pending_pick_bonus_symbol == GameSymbols.FOGO:
				p.pending_fire_discarded = bonus_symbol_count
			# Compra as cartas prometidas após o descarte
			if _pending_pick_draw_after > 0:
				p.draw_cards(_pending_pick_draw_after)
		PickSource.HAND_ARSENAL:
			# Carta escolhida da mão vai para o arsenal (opcional — vazio = não guardar)
			if not pick_indices.is_empty():
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
		PickSource.GRAVEYARD_TO_TOP:
			# Recordar — carta escolhida do cemitério vai ao TOPO do deck.
			var source_idx: int = _pending_pick_indices[pick_indices[0]]
			if source_idx < p.discard_pile.size():
				var card := p.discard_pile[source_idx]
				p.discard_pile.remove_at(source_idx)
				p.deck.push_front(card)
		PickSource.GRAVEYARD_TO_HAND:
			# Ressurgir — carta escolhida do cemitério vai para a MÃO.
			var source_idx: int = _pending_pick_indices[pick_indices[0]]
			if source_idx < p.discard_pile.size():
				var card := p.discard_pile[source_idx]
				p.discard_pile.remove_at(source_idx)
				p.hand.append(card)
				GameBus.card_drawn.emit(player_idx)
				_notify_effect_vfx(player_idx, "draw")
	var followup    := _pending_both_recycle_followup
	var resolved_source := _pending_pick_source        # preserva antes de limpar
	var instruction := _pending_pick_instruction   # preserva antes de limpar
	_pending_pick_player           = -1
	_pending_pick_source           = PickSource.DECK
	_pending_pick_count            = 1
	_pending_pick_variable         = false
	_pending_pick_bonus_symbol     = ""
	_pending_pick_bonus_attack     = 0
	_pending_pick_draw_after       = 0
	_pending_pick_instruction      = ""
	_pending_pick_indices.clear()
	_pending_both_recycle_followup = -1
	# Followup do segundo jogador (repassa a instrução), no mesmo tipo do pick que resolveu:
	# Ecos do Passado (cemitério→arsenal) ou Ressurgir (cemitério→mão).
	if followup >= 0 and not players[followup].discard_pile.is_empty():
		var idxs: Array[int] = []
		for i in players[followup].discard_pile.size():
			idxs.append(i)
		if resolved_source == PickSource.GRAVEYARD_TO_HAND:
			begin_graveyard_to_hand_pick(followup, idxs, -1, instruction)
		else:
			begin_graveyard_arsenal_pick(followup, idxs, -1, instruction)
	# Pick aberto por efeito AFTER_TURN durante o dreno pós-combate (ex.: Execução
	# Silenciosa) → retoma o pós-combate, não o segmento da fase ACTION.
	if _pending_pick_player < 0 and _m._post_combat_pending:
		_continue_post_combat()
		return
	# Se o pick foi disparado por um efeito durante o fechamento da janela de reação
	# e não há outro pick pendente, continua o fluxo do segmento.
	if _pending_pick_player < 0 and _pending_symbol_player < 0 \
			and battle.current_phase == BattleManager.Phase.ACTION:
		# Passiva de descarte furtiva enfileirada pelo efeito do pick → confirma antes de seguir.
		if _start_stealth_confirm_if_pending():
			return
		var active := _active_segment_player
		if _segment_action_done[active] and _segment_bonus_done[active] and players[active].extra_actions == 0:
			_finish_segment(active)
			return
	_emit_sync()

## Sobrecarga de Núcleo — fase 1: o jogador escolheu quais tokens destruir (índices em
## Player.tokens). Destrói os escolhidos; cada token vira 1 ponto a distribuir na fase 2.
@rpc("any_peer", "call_local", "reliable")
func rpc_submit_overload_tokens(token_indices: Array) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if _pending_overload_player != player_idx or _pending_overload_phase != 1:
		return
	var p := players[player_idx]
	# Valida índices: dentro do range e sem duplicatas.
	var seen := {}
	for ti in token_indices:
		var idx := int(ti)
		if idx < 0 or idx >= p.tokens.size() or seen.has(idx):
			return
		seen[idx] = true
	# Destrói do maior para o menor índice para não deslocar os demais.
	var real: Array[int] = []
	for ti in token_indices:
		real.append(int(ti))
	real.sort()
	real.reverse()
	for idx in real:
		p.tokens.remove_at(idx)
	var points := real.size()
	if points <= 0:
		# Nada destruído → efeito termina sem distribuição.
		_clear_overload_pending()
		_resume_overload_segment()
		return
	# Fase 2: distribuir os pontos.
	_pending_overload_phase  = 2
	_pending_overload_points = points
	_emit_sync()

## Sobrecarga de Núcleo — fase 2: distribuição dos pontos entre ataque e defesa.
## atk + def deve somar exatamente os pontos (1 por token destruído).
@rpc("any_peer", "call_local", "reliable")
func rpc_submit_overload_distribution(atk: int, def: int) -> void:
	if not multiplayer.is_server():
		return
	var player_idx := _peer_to_player_index(multiplayer.get_remote_sender_id())
	if _pending_overload_player != player_idx or _pending_overload_phase != 2:
		return
	if atk < 0 or def < 0 or atk + def != _pending_overload_points:
		return
	var p := players[player_idx]
	p.pending_bonus_attack  += atk
	p.pending_bonus_defense += def
	print("[TCG] Jogador %d: Sobrecarga de Núcleo → +%d ataque / +%d defesa" % [player_idx, atk, def])
	_clear_overload_pending()
	_resume_overload_segment()

func _clear_overload_pending() -> void:
	_pending_overload_player = -1
	_pending_overload_phase  = 0
	_pending_overload_points = 0

## Retoma o segmento após a Sobrecarga de Núcleo resolver (mesma lógica do resume de pick).
func _resume_overload_segment() -> void:
	if _start_stealth_confirm_if_pending():
		return
	if battle.current_phase == BattleManager.Phase.ACTION:
		var active := _active_segment_player
		if _segment_action_done[active] and _segment_bonus_done[active] and players[active].extra_actions == 0:
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
	# Destino dos símbolos: a chain do jogador (loja do Fragmento) ou uma carta.
	var to_chain := _pending_symbol_to_chain
	for sym in chosen_symbols:
		var sid := str(sym)
		if not GameSymbols.is_valid(sid):
			continue
		if to_chain:
			players[player_idx].bonus_chain_symbols.append(sid)
			# Registra quantas cartas ja haviam sido jogadas — define a posicao cronologica.
			players[player_idx].bonus_chain_positions.append(players[player_idx].cards_this_battle.size())
			# Exibe o símbolo na combat zone do jogador (ambos os clientes).
			GameBus.fragment_symbol_added.emit(player_idx, sid)
			_notify_fragment_symbol_added(player_idx, sid)
		elif _pending_symbol_card != null:
			_pending_symbol_card.symbols.append(sid)
	# Guarda referências antes de limpar — precisamos re-verificar skill com os novos símbolos
	var resolved_player := _pending_symbol_player
	var resolved_card   := _pending_symbol_card
	var continue_reaction := _pending_symbol_after_reaction
	_pending_symbol_player         = -1
	_pending_symbol_count          = 0
	_pending_symbol_card           = null
	_pending_symbol_after_reaction = false
	_pending_symbol_to_chain       = false
	# Re-verifica a skill agora que os símbolos entraram na chain
	if to_chain:
		_recheck_active_skill(resolved_player)
		_emit_sync()
		return
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
	_conclude_match(winner_idx)

# Notifica apenas o cliente (host já emitiu diretamente).
@rpc("authority", "call_remote", "reliable")
func _rpc_notify_game_over(winner_idx: int) -> void:
	GameBus.game_over.emit(winner_idx)

## Recompensas de partida rankeada (tier/pontos/delta/ouro) para o jogador local. Direcionado
## (cada peer recebe só o SEU lado). Chega após o reporte ao backend (corrotina).
@rpc("authority", "call_remote", "reliable")
func _rpc_notify_match_rewards(data: Dictionary) -> void:
	GameBus.match_rewards.emit(data)

## Gargalo único de "partida concluída com vencedor" (servidor). Marca o vencedor no
## MatchState corrente (_m), avisa as duas pontas e, se for rankeada, reporta o
## resultado ao backend. Usado por todos os caminhos de vitória exceto a desconexão
## (que opera sobre um MatchState específico, fora de _m).
func _conclude_match(winner_idx: int) -> void:
	_winner_index = winner_idx
	GameBus.game_over.emit(winner_idx)
	_notify_game_over(winner_idx)
	_report_ranked_result_if_needed(_m, winner_idx)

## Reporta o resultado de uma partida rankeada ao backend (server-to-server). No-op se a
## partida não for rankeada, se não houver token de serviço, ou se faltar o player_id de
## backend de algum dos dois peers. A idempotência (client_match_id) protege contra
## reportes duplicados (ex.: vitória + desconexão na mesma partida).
func _report_ranked_result_if_needed(m: MatchState, winner_idx: int) -> void:
	if not multiplayer.is_server():
		return
	if m == null or not m._ranked or m._client_match_id == "":
		return
	if not ApiClient.has_service_credential():
		print("[Ranked] Partida rankeada terminou, mas sem token de serviço — resultado não reportado.")
		return

	var winner_peer := -1
	var loser_peer := -1
	for peer in m._match_peer_to_idx.keys():
		if int(m._match_peer_to_idx[peer]) == winner_idx:
			winner_peer = peer
		else:
			loser_peer = peer
	if winner_peer < 0 or loser_peer < 0:
		return

	var world_players: Dictionary = WorldState.get_players()
	var winner_id := str((world_players.get(winner_peer, {}) as Dictionary).get("player_id", ""))
	var loser_id := str((world_players.get(loser_peer, {}) as Dictionary).get("player_id", ""))
	if winner_id == "" or loser_id == "":
		print("[Ranked] player_id de backend ausente (winner='%s' loser='%s') — resultado não reportado." % [winner_id, loser_id])
		return

	_send_ranked_result(m._client_match_id, winner_id, loser_id, winner_peer, loser_peer)

## Dispara a chamada HTTP (corrotina) sem bloquear o fluxo do jogo. Ao receber a resposta,
## entrega a cada peer as suas recompensas (tier/pontos/delta/ouro) via RPC direcionado.
func _send_ranked_result(client_match_id: String, winner_id: String, loser_id: String, winner_peer: int, loser_peer: int) -> void:
	var payload := {
		"clientMatchId": client_match_id,
		"winnerId":      winner_id,
		"loserId":       loser_id,
	}
	var res: Dictionary = await ApiClient.report_ranked_result(payload)
	if not res.get("ok", false):
		push_warning("[Ranked] Falha ao reportar resultado: %s" % str(res.get("error", "")))
		return
	print("[Ranked] Resultado reportado | match=%s winner=%s loser=%s" % [client_match_id, winner_id, loser_id])

	var data: Dictionary = res.get("data", {})
	_dispatch_match_rewards(winner_peer, data.get("winner", {}), "victory")
	_dispatch_match_rewards(loser_peer,  data.get("loser", {}),  "defeat")

## Monta o payload de recompensa de UM lado e envia ao peer dono. No-op se o lado vier vazio.
func _dispatch_match_rewards(peer: int, side: Dictionary, result: String) -> void:
	if side.is_empty():
		return
	var standing: Dictionary = side.get("standing", {})
	var payload := {
		"result":       result,
		"tier_enum":    str(standing.get("tier", "MADEIRA")),
		"points":       int(standing.get("points", 0)),
		"points_delta": int(side.get("pointsDelta", 0)),
		"gold":         int(side.get("goldAwarded", 0)),
		"apex":         standing.get("pointsToNextTier", null) == null,
	}
	rpc_id(peer, "_rpc_notify_match_rewards", payload)

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

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_missiles_fired(caster_player_idx: int, targets: Array) -> void:
	GameBus.missiles_fired.emit(caster_player_idx, targets)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_roses_fired(caster_player_idx: int, source_hero_idx: int, targets: Array) -> void:
	GameBus.roses_fired.emit(caster_player_idx, source_hero_idx, targets)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_roses_detonated(caster_player_idx: int, targets: Array) -> void:
	GameBus.roses_detonated.emit(caster_player_idx, targets)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_seal_applied(caster_player_idx: int, source_hero_idx: int, target_player_idx: int, target_hero_idx: int) -> void:
	GameBus.seal_applied.emit(caster_player_idx, source_hero_idx, target_player_idx, target_hero_idx)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_abyss_curse(caster_player_idx: int, opponent_player_idx: int, banished_art_keys: Array) -> void:
	GameBus.abyss_curse.emit(caster_player_idx, opponent_player_idx, banished_art_keys)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_fragment_used(player_idx: int, effect_id: String, cost: int) -> void:
	GameBus.fragment_used.emit(player_idx, effect_id, cost)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_fragment_symbol_added(player_idx: int, symbol: String) -> void:
	GameBus.fragment_symbol_added.emit(player_idx, symbol)

# Serializa o estado mínimo necessário para o cliente redesenhar a UI.
func _build_snapshot() -> Dictionary:
	var snap := { "players": [] }
	for p in players:
		var heroes_data: Array = []
		for h in p.heroes:
			heroes_data.append({ "hp": h.current_hp, "state": int(h.state), "backline_revealed": h.is_backline_revealed, "damage_shield": h.damage_shield, "wall_active": h.wall_active, "taunt_active": h.taunt_active, "black_roses": h.black_roses, "sealed_ruin": h.sealed_ruin, "burn_amount": h.burn_amount, "burn_turns": h.burn_turns, "burn_is_dark": h.burn_is_dark, "shield_per_turn": h.shield_per_turn, "shield_turns": h.shield_turns, "poison_turns": h.poison_turns, "bleed_amount": h.bleed_amount, "bleed_turns": h.bleed_turns, "mark_bonus": h.mark_bonus, "mark_turns": h.mark_turns, "wound_turns": h.wound_turns, "silence_turns": h.silence_turns })
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
			"banish_zone":          _serialize_cards(p.banish_zone),
			"tokens":               _serialize_tokens(p.tokens),
			"pending_bonus_attack":            p.pending_bonus_attack,
			"pending_bonus_defense":           p.pending_bonus_defense,
			"next_defense_penalty":            p.next_defense_penalty,
			"passive_attack_bonus":            (p.active_hero.get_passive_attack_bonus() if p.active_hero != null else 0),
			"battle_bonus_attack":               p.battle_bonus_attack,
			"battle_attack_penalty":          p.battle_attack_penalty,
			"next_turn_bonus_attack":         p.next_turn_bonus_attack,
			"extra_actions":                  p.extra_actions,
			"team_regen_amount":              p.team_regen_amount,
			"team_regen_turns":               p.team_regen_turns,
			"missile_overcharge":             p.missile_overcharge,
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
	snap["pending_pick_variable"]    = _pending_pick_variable
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
	snap["pending_ally_pick_side"]   = _pending_ally_pick_side
	snap["pending_ally_pick_filter"] = _pending_ally_pick_filter
	# pick de símbolo pendente
	snap["pending_symbol_player"] = _pending_symbol_player
	snap["pending_symbol_count"]  = _pending_symbol_count
	# Sobrecarga de Núcleo (destruir tokens → distribuir pontos)
	snap["pending_overload_player"] = _pending_overload_player
	snap["pending_overload_phase"]  = _pending_overload_phase
	snap["pending_overload_points"] = _pending_overload_points
	# habilidades de retaguarda interativas
	snap["backline_awaiting_response"] = _backline_awaiting_response
	snap["backline_awaiting_target"]   = _backline_awaiting_target
	snap["backline_current_player"]    = _backline_current_player
	snap["backline_current_hero_idx"]  = _backline_current_hero_idx
	# confirmação de passiva de descarte furtiva (Relicar)
	snap["stealth_passive_player"]     = _stealth_passive_player
	snap["stealth_passive_hero_idx"]   = _stealth_passive_hero_idx
	snap["frontline_confirm_player"]   = _frontline_confirm_player
	snap["frontline_confirm_hero_idx"] = _frontline_confirm_hero_idx
	snap["dice_thrown"]          = [_dice_thrown[0], _dice_thrown[1]]
	snap["dice_values"]          = [_dice_values[0].duplicate(), _dice_values[1].duplicate()]
	snap["dice_throw_vec"]       = [[_dice_throw_vec[0].x, _dice_throw_vec[0].y], [_dice_throw_vec[1].x, _dice_throw_vec[1].y]]
	snap["dice_winner"]          = _dice_winner
	snap["dice_awaiting_choice"] = _dice_awaiting_choice
	snap["first_player"]         = _first_player
	snap["debug"]                = _m._debug
	# revelação "só olhar" da loja do Fragmento Arcano
	snap["pending_reveal_player"]      = _pending_reveal_player
	var reveal_list: Array[Card] = []
	if _pending_reveal_card != null:
		reveal_list.append(_pending_reveal_card)
	snap["pending_reveal_card"]        = _serialize_cards(reveal_list)
	return snap

static func _serialize_tokens(tokens: Array[Token]) -> Array:
	var out: Array = []
	for t in tokens:
		out.append(t.to_dict())
	return out

static func _deserialize_tokens(arr: Array) -> Array[Token]:
	var out: Array[Token] = []
	for d in arr:
		var t := Token.from_dict(d)
		if t != null:
			out.append(t)
	return out

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
			"is_foil":       c.is_foil,
			"art_key":       c.art_key,
			"description":   c.description,
			"rarity":        Card.Rarity.keys()[c.rarity],
			"effects":       _serialize_effects(c.effects),
		})
	return out

# Reemite o spec de origem de cada efeito (id + params), para que o cliente reconstrua
# Card.effects fielmente via Card.from_dict. O cliente não executa efeitos (autoridade é
# o servidor), mas precisa saber se a carta tem efeito (ex.: flavor text entre aspas).
static func _serialize_effects(effects: Array) -> Array:
	var out: Array = []
	for e in effects:
		out.append(e.spec)
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
		p.battle_attack_penalty           = pd.get("battle_attack_penalty",           0)
		p.next_turn_bonus_attack          = pd.get("next_turn_bonus_attack",          0)
		p.extra_actions                   = pd.get("extra_actions",                   0)
		p.team_regen_amount               = pd.get("team_regen_amount",               0)
		p.team_regen_turns                = pd.get("team_regen_turns",                0)
		p.missile_overcharge              = pd.get("missile_overcharge",              false)
		if not multiplayer.is_server():
			var dp: Array = pd.get("discard_pile", [])
			p.discard_pile = _deserialize_cards(dp)
			p.banish_zone = _deserialize_cards(pd.get("banish_zone", []))
			p.tokens = _deserialize_tokens(pd.get("tokens", []))
		var hlist: Array = pd.get("heroes", [])
		for j in min(hlist.size(), p.heroes.size()):
			p.heroes[j].current_hp          = hlist[j].get("hp",                p.heroes[j].current_hp)
			p.heroes[j].state               = hlist[j].get("state",             int(p.heroes[j].state))
			p.heroes[j].is_backline_revealed = hlist[j].get("backline_revealed", false)
			p.heroes[j].damage_shield        = hlist[j].get("damage_shield",     0)
			p.heroes[j].wall_active          = hlist[j].get("wall_active",        false)
			p.heroes[j].taunt_active         = hlist[j].get("taunt_active",       false)
			p.heroes[j].black_roses          = hlist[j].get("black_roses",        0)
			p.heroes[j].sealed_ruin          = hlist[j].get("sealed_ruin",        false)
			p.heroes[j].burn_amount          = hlist[j].get("burn_amount",        0)
			p.heroes[j].burn_turns           = hlist[j].get("burn_turns",         0)
			p.heroes[j].burn_is_dark         = hlist[j].get("burn_is_dark",       false)
			p.heroes[j].shield_per_turn      = hlist[j].get("shield_per_turn",    0)
			p.heroes[j].shield_turns         = hlist[j].get("shield_turns",       0)
			p.heroes[j].poison_turns         = hlist[j].get("poison_turns",       0)
			p.heroes[j].bleed_amount         = hlist[j].get("bleed_amount",       0)
			p.heroes[j].bleed_turns          = hlist[j].get("bleed_turns",        0)
			p.heroes[j].mark_bonus           = hlist[j].get("mark_bonus",         0)
			p.heroes[j].mark_turns           = hlist[j].get("mark_turns",         0)
			p.heroes[j].wound_turns          = hlist[j].get("wound_turns",        0)
			p.heroes[j].silence_turns        = hlist[j].get("silence_turns",      0)
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
	_pending_pick_variable    = snap.get("pending_pick_variable",    false)
	_pending_pick_draw_after  = snap.get("pending_pick_draw_after",  0)
	_pending_pick_instruction = snap.get("pending_pick_instruction", "")
	if not multiplayer.is_server():
		_pending_pick_cards_display = _deserialize_cards(snap.get("pending_pick_cards", []))
	_pending_ally_pick_player = snap.get("pending_ally_pick_player", -1)
	_pending_ally_pick_action = snap.get("pending_ally_pick_action", "")
	_pending_ally_pick_amount = snap.get("pending_ally_pick_amount", 0)
	_pending_ally_pick_side   = snap.get("pending_ally_pick_side", 0)
	_pending_ally_pick_filter = snap.get("pending_ally_pick_filter", "")
	_pending_symbol_player = snap.get("pending_symbol_player", -1)
	_pending_symbol_count  = snap.get("pending_symbol_count",  0)
	_pending_overload_player = snap.get("pending_overload_player", -1)
	_pending_overload_phase  = snap.get("pending_overload_phase",  0)
	_pending_overload_points = snap.get("pending_overload_points", 0)
	_backline_awaiting_response = snap.get("backline_awaiting_response", false)
	_backline_awaiting_target   = snap.get("backline_awaiting_target",   false)
	_backline_current_player    = snap.get("backline_current_player",    -1)
	_backline_current_hero_idx  = snap.get("backline_current_hero_idx",  -1)
	_stealth_passive_player     = snap.get("stealth_passive_player",     -1)
	_stealth_passive_hero_idx   = snap.get("stealth_passive_hero_idx",   -1)
	_frontline_confirm_player   = snap.get("frontline_confirm_player",   -1)
	_frontline_confirm_hero_idx = snap.get("frontline_confirm_hero_idx", -1)
	var dt: Array = snap.get("dice_thrown", [false, false])
	_dice_thrown = [bool(dt[0]), bool(dt[1])]
	var dv: Array = snap.get("dice_values", [[0, 0], [0, 0]])
	_dice_values = [[int(dv[0][0]), int(dv[0][1])], [int(dv[1][0]), int(dv[1][1])]]
	var dvec: Array = snap.get("dice_throw_vec", [[0, 0], [0, 0]])
	_dice_throw_vec = [Vector2(dvec[0][0], dvec[0][1]), Vector2(dvec[1][0], dvec[1][1])]
	_dice_winner          = snap.get("dice_winner",          -1)
	_dice_awaiting_choice = snap.get("dice_awaiting_choice", false)
	_first_player         = snap.get("first_player",         -1)
	if _m != null:
		_m._debug = bool(snap.get("debug", false))
	_pending_reveal_player      = snap.get("pending_reveal_player",      -1)
	if not multiplayer.is_server():
		var rc := _deserialize_cards(snap.get("pending_reveal_card", []))
		_pending_reveal_card = rc[0] if not rc.is_empty() else null

static func _deserialize_cards(arr: Array) -> Array[Card]:
	var out: Array[Card] = []
	for d in arr:
		out.append(Card.from_dict(d))
	return out

static func _phase_from_string(s: String) -> BattleManager.Phase:
	match s:
		"OPENING_ROLL":     return BattleManager.Phase.OPENING_ROLL
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
## p_ranked=true marca a partida como rankeada (gera client_match_id p/ reportar o
## resultado a POST /ranked/result ao fim).
func register_match(p_peer0: int, p_peer1: int, p_ranked: bool = false, p_debug: bool = false) -> int:
	# Limpa partidas anteriores destes peers (evita leak ao rejogar).
	_cleanup_peer_match(p_peer0)
	_cleanup_peer_match(p_peer1)
	var mid := _next_match_id
	_next_match_id += 1
	var m := MatchState.new()
	m._match_peer_to_idx = { p_peer0: 0, p_peer1: 1 }
	m._ranked = p_ranked
	m._debug = p_debug
	if p_ranked:
		m._client_match_id = _generate_uuid()
	_matches[mid] = m
	_peer_to_match[p_peer0] = mid
	_peer_to_match[p_peer1] = mid
	_m = m
	return mid

## Gera um UUID v4 (string) — chave de idempotência da partida rankeada.
static func _generate_uuid() -> String:
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in 16:
		bytes[i] = randi() & 0xff
	bytes[6] = (bytes[6] & 0x0f) | 0x40   # versão 4
	bytes[8] = (bytes[8] & 0x3f) | 0x80   # variante
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

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
				# Rankeada: quem cai perde (anti rage-quit). Idempotente no backend.
				_report_ranked_result_if_needed(m, winner_idx)
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

## VFX de efeito resolvido → clientes (e local p/ teste single-process). Server-only.
func _notify_effect_vfx(player_idx: int, vfx_key: String, target_hero_idx: int = -1) -> void:
	GameBus.effect_vfx.emit(player_idx, vfx_key, target_hero_idx)
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_effect_vfx", player_idx, vfx_key, target_hero_idx)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_effect_vfx", player_idx, vfx_key, target_hero_idx)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_effect_vfx(player_idx: int, vfx_key: String, target_hero_idx: int) -> void:
	GameBus.effect_vfx.emit(player_idx, vfx_key, target_hero_idx)

## Movimento animado de carta específica → clientes (e local). Server-only.
## kind: "discard" | "to_deck" | "banish".
func _notify_card_move(player_idx: int, art_key: String, kind: String) -> void:
	GameBus.card_move_anim.emit(player_idx, art_key, kind)
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_card_move", player_idx, art_key, kind)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_card_move", player_idx, art_key, kind)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_card_move(player_idx: int, art_key: String, kind: String) -> void:
	GameBus.card_move_anim.emit(player_idx, art_key, kind)

## VFX "empower" (buff de atk/def por efeito) → clientes (e local). Server-only.
func _notify_empower(player_idx: int, atk: int, def: int, symbols: Array) -> void:
	GameBus.empower_anim.emit(player_idx, atk, def, symbols)
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_empower", player_idx, atk, def, symbols)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_empower", player_idx, atk, def, symbols)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify_empower(player_idx: int, atk: int, def: int, symbols: Array) -> void:
	GameBus.empower_anim.emit(player_idx, atk, def, symbols)

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

func _notify_missiles_fired(caster_player_idx: int, targets: Array) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_missiles_fired", caster_player_idx, targets)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_missiles_fired", caster_player_idx, targets)

## Anuncia o VFX das Rosas Negras (Darian) aos dois clientes da partida. Chamado
## pelo próprio herói dentro de activate_ability (server-side) após sortear os alvos.
func announce_roses_fired(caster_player_idx: int, source_hero_idx: int, targets: Array) -> void:
	if not multiplayer.is_server():
		return
	GameBus.roses_fired.emit(caster_player_idx, source_hero_idx, targets)
	_notify_roses_fired(caster_player_idx, source_hero_idx, targets)

func _notify_roses_fired(caster_player_idx: int, source_hero_idx: int, targets: Array) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_roses_fired", caster_player_idx, source_hero_idx, targets)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_roses_fired", caster_player_idx, source_hero_idx, targets)

## Anuncia o VFX da especial do Darian (Jardim de Espinhos) aos dois clientes. Chamado
## por HeroDarian.on_skill_activated (server-side) com os heróis que tinham rosas.
func announce_roses_detonated(caster_player_idx: int, targets: Array) -> void:
	if not multiplayer.is_server():
		return
	GameBus.roses_detonated.emit(caster_player_idx, targets)
	_notify_roses_detonated(caster_player_idx, targets)

func _notify_roses_detonated(caster_player_idx: int, targets: Array) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_roses_detonated", caster_player_idx, targets)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_roses_detonated", caster_player_idx, targets)

## Anuncia o VFX do Selo da Ruína (Lilith) aos dois clientes da partida. Chamado
## pelo próprio herói dentro de activate_ability (server-side) após marcar o alvo.
func announce_seal_applied(caster_player_idx: int, source_hero_idx: int, target_player_idx: int, target_hero_idx: int) -> void:
	if not multiplayer.is_server():
		return
	GameBus.seal_applied.emit(caster_player_idx, source_hero_idx, target_player_idx, target_hero_idx)
	_notify_seal_applied(caster_player_idx, source_hero_idx, target_player_idx, target_hero_idx)

func _notify_seal_applied(caster_player_idx: int, source_hero_idx: int, target_player_idx: int, target_hero_idx: int) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_seal_applied", caster_player_idx, source_hero_idx, target_player_idx, target_hero_idx)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_seal_applied", caster_player_idx, source_hero_idx, target_player_idx, target_hero_idx)

## Anuncia o VFX da especial "Maldição do Abismo" (Lilith) aos dois clientes. Chamado por
## HeroLilith.on_skill_activated (server-side) com os art_keys das cartas banidas do topo
## do deck do oponente — o board encena símbolos → centro → névoa → deck e bane 1 a 1.
func announce_abyss_curse(caster_player_idx: int, opponent_player_idx: int, banished_art_keys: Array) -> void:
	if not multiplayer.is_server():
		return
	GameBus.abyss_curse.emit(caster_player_idx, opponent_player_idx, banished_art_keys)
	_notify_abyss_curse(caster_player_idx, opponent_player_idx, banished_art_keys)

func _notify_abyss_curse(caster_player_idx: int, opponent_player_idx: int, banished_art_keys: Array) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_abyss_curse", caster_player_idx, opponent_player_idx, banished_art_keys)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_abyss_curse", caster_player_idx, opponent_player_idx, banished_art_keys)

func _notify_fragment_used(player_idx: int, effect_id: String, cost: int) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_fragment_used", player_idx, effect_id, cost)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_fragment_used", player_idx, effect_id, cost)

func _notify_fragment_symbol_added(player_idx: int, symbol: String) -> void:
	var t := _match_targets()
	if t.is_empty():
		rpc("_rpc_notify_fragment_symbol_added", player_idx, symbol)
	else:
		for peer in t:
			rpc_id(peer, "_rpc_notify_fragment_symbol_added", player_idx, symbol)

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
	var dealt := hero.take_direct_damage(amount, ctx)  # respeita o escudo (Fluxo Reativo)
	if dealt > 0:
		GameBus.hero_damaged.emit(hero, dealt)
	var w := _evaluate_winner()
	if w >= 0:
		_conclude_match(w)

## Saraivada (Ieldor) — causa `amount` de dano direto a `count` heróis inimigos vivos
## aleatórios (distintos). Respeita o Muro de Aço (retaguarda protegida excluída dos
## candidatos), o *Provocar* (redireciona ao provocador) e a redução de dano de área.
func deal_direct_damage_random(target_player_idx: int, amount: int, count: int) -> void:
	if not multiplayer.is_server() or amount <= 0 or count <= 0:
		return
	if target_player_idx < 0 or target_player_idx > 1:
		return
	var tp: Player = players[target_player_idx]
	var candidates: Array[Hero] = []
	for h in tp.heroes:
		if h.is_alive() and not tp.is_targeting_protected(h):
			candidates.append(h)
	if candidates.is_empty():
		return
	candidates.shuffle()
	var shots: int = mini(count, candidates.size())
	for i in shots:
		var target: Hero = tp.redirect_target(candidates[i])
		if target == null or not target.is_alive():
			continue
		var ctx := TurnContext.new()
		ctx.defender = target
		ctx.defender_player = tp
		var dmg := amount
		for ally in tp.heroes:
			if ally != target:
				dmg = maxi(0, dmg - ally.get_aoe_damage_reduction(ctx))
		if dmg <= 0:
			continue
		var dealt := target.take_direct_damage(dmg, ctx)  # respeita o escudo
		if dealt > 0:
			GameBus.hero_damaged.emit(target, dealt)
	var w := _evaluate_winner()
	if w >= 0:
		_conclude_match(w)

## Bane `count` cartas do TOPO do deck do jogador para a zona de banimento (exílio).
## Server-only. Retorna os art_keys das cartas banidas (o deck pode esvaziar antes).
## `notify_moves`: se true (padrão), anima cada carta na hora (deck → pilha de banimento) —
## usado pelo Selo da Ruína. A especial da Lilith passa false e encena os banimentos ela
## mesma (após a névoa chegar ao deck), via o evento abyss_curse com esta lista.
func banish_from_deck_top(player_idx: int, count: int, notify_moves: bool = true) -> Array:
	var art_keys: Array = []
	if not multiplayer.is_server() or count <= 0 or player_idx < 0 or player_idx >= players.size():
		return art_keys
	var p: Player = players[player_idx]
	for i in count:
		if p.deck.is_empty():
			break
		var card: Card = p.deck.pop_front()
		p.send_to_banish(card)
		if notify_moves:
			_notify_card_move(player_idx, card.art_key, "banish")
		art_keys.append(card.art_key)
	return art_keys

## Server-only. Mói (mill) `count` cartas do topo do deck do jogador para o CEMITÉRIO dele.
## Diferente de banir (que exila): aqui as cartas ficam no cemitério (recuperáveis). Usado
## por Ceifar. Retorna os art_keys movidos.
func mill_from_deck_top(player_idx: int, count: int) -> Array:
	var art_keys: Array = []
	if not multiplayer.is_server() or count <= 0 or player_idx < 0 or player_idx >= players.size():
		return art_keys
	var p: Player = players[player_idx]
	for i in count:
		if p.deck.is_empty():
			break
		var card: Card = p.deck.pop_front()
		p.discard_pile.append(card)
		art_keys.append(card.art_key)
	return art_keys

## Chamado por Hero.take_damage quando um herói com Selo da Ruína (Lilith) sofre dano.
## Bane floor(amount/2) (mín 1) do topo do deck do DONO do herói marcado. Server-only.
func on_sealed_hero_damaged(hero: Hero, amount: int) -> void:
	if not multiplayer.is_server() or amount <= 0:
		return
	for i in players.size():
		if players[i].heroes.has(hero):
			banish_from_deck_top(i, maxi(1, amount / 2))
			return

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
