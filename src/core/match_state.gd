# src/core/match_state.gd
# Estado de UMA partida (Modelo A). Container puro de dados — sem rede, sem UI.
#
# O GameState (autoload) concentra a lógica e a rede, operando sobre uma instância
# de MatchState por vez (referência `_m`). Hoje há uma única partida; na Fase 2.2 o
# servidor terá uma MatchState por sala e roteará `_m` pelo remetente do RPC.
#
# Os nomes dos campos espelham exatamente os antigos campos do GameState, para
# que os corpos de método (que acessam via proxies) permaneçam inalterados.
# Ver docs/roadmap-beta.md e memory project_network_model.
class_name MatchState extends RefCounted

var players: Array[Player] = []
var battle: BattleManager = BattleManager.new()

var _opening_mulligan_done: Array[bool] = [false, false]
var _hero_submitted: Array[bool] = [false, false]
var _next_hero_pick_player: int = 0
var _winner_index: int = -1

# ── estado da fase ACTION ────────────────────────────────
var _active_segment_player: int       = 0
var _turn_first_player: int          = 0
var _segment_action_done: Array[bool] = [false, false]
var _segment_bonus_done:  Array[bool] = [false, false]
var _reaction_window_for: int         = -1
var _consecutive_empty_turns: int    = 0
var _hero_revealed: Array[bool]       = [false, false]
var _end_submitted: Array[bool]       = [false, false]

# Efeito pendente — disparado após a janela de reação fechar.
var _pending_effect_card: Card          = null
var _pending_effect_player: int         = -1
var _pending_effect_from_arsenal: bool  = false

# Fila de efeitos AFTER_COMBAT do turno corrente. Cada entrada é um Dictionary:
#   { effect: CardEffect, player: int, card: Card, from_arsenal: bool, hero_hidden: bool }
# Preenchida ao jogar cartas; drenada (FIFO) após o combate em _resolve_turn_combat().
var _after_combat_queue: Array[Dictionary] = []

# Pick de herói aliado pendente.
var _pending_ally_pick_player: int  = -1
var _pending_ally_pick_action: String = ""
var _pending_ally_pick_amount: int  = 0

# Pick de símbolo pendente.
var _pending_symbol_player: int            = -1
var _pending_symbol_count: int             = 0
var _pending_symbol_card: Card             = null
var _pending_symbol_after_reaction: bool   = false

# Pick de carta pendente.
# _pending_pick_source guarda um valor de GameState.PickSource (int); o enum
# permanece no GameState para os corpos de método o usarem sem qualificar.
var _pending_pick_player: int                = -1
var _pending_pick_source: int                = 0   # GameState.PickSource.DECK
var _pending_pick_count: int                 = 1
var _pending_pick_draw_after: int            = 0
var _pending_pick_indices: Array[int]        = []
var _pending_pick_cards_display: Array[Card] = []
var _pending_pick_instruction: String        = ""
var _pending_both_recycle_followup: int = -1
var _hero_was_hidden_at_play: Array[bool] = [false, false]

# ── habilidades de retaguarda interativas ───────────────
var _backline_queue:            Array[Dictionary] = []
var _backline_awaiting_response: bool = false
var _backline_awaiting_target:   bool = false
var _backline_current_player:    int  = -1
var _backline_current_hero_idx:  int  = -1

# ── submissão de deck (multiplayer) ─────────────────────────────────────────
var _deck_submitted: Array[bool]  = [false, false]
var _submitted_deck: Array[Dictionary] = [{}, {}]

# ── mapeamento de peers (Modelo A) ───────────────────────────────────────────
var _match_peer_to_idx: Dictionary = {}
