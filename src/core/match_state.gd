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
# Bloqueio de reações no turno inteiro (Calor Sufocante) — nenhuma janela de reação
# abre enquanto ligado. Resetado no início da fase ACTION.
var _reactions_locked: bool           = false
var _consecutive_empty_turns: int    = 0
var _hero_revealed: Array[bool]       = [false, false]
var _end_submitted: Array[bool]       = [false, false]

# Efeito pendente — disparado após a janela de reação fechar.
var _pending_effect_card: Card          = null
var _pending_effect_player: int         = -1
var _pending_effect_from_arsenal: bool  = false
# Habilidade de retaguarda (ex.: Darian) declarada, resolvida só quando a janela de
# reação fechar (reação é mais rápida que ação bônus). {} = nenhuma pendente.
var _pending_backline_ability: Dictionary = {}

# Fila de efeitos AFTER_TURN do turno corrente. Cada entrada é um Dictionary:
#   { effect: CardEffect, player: int, card: Card, from_arsenal: bool, hero_hidden: bool }
# Preenchida ao jogar cartas; drenada (FIFO) após o combate em _resolve_turn_combat().
var _after_combat_queue: Array[Dictionary] = []
# Buffer de trabalho do dreno atual: a fila é movida para cá ao drenar (efeitos que
# enfileiram novos AFTER_TURN durante a resolução vão para _after_combat_queue, não este lote).
# Se um efeito abre um pick (ex.: oponente escolhe descarte), o dreno pausa com itens aqui.
var _after_combat_working: Array[Dictionary] = []
# Dano [p0, p1] do combate em resolução — guardado para retomar o dreno após um pick.
var _after_combat_dmg: Array[int] = [0, 0]
# True enquanto o pós-combate está pausado esperando um pick aberto por efeito AFTER_TURN.
var _post_combat_pending: bool = false

# Pick de herói aliado pendente.
var _pending_ally_pick_player: int  = -1
var _pending_ally_pick_action: String = ""
var _pending_ally_pick_amount: int  = 0

# Pick de símbolo pendente.
var _pending_symbol_player: int            = -1
var _pending_symbol_count: int             = 0
var _pending_symbol_card: Card             = null
var _pending_symbol_after_reaction: bool   = false
# Quando true, o símbolo escolhido vai para a chain do jogador (bonus_chain_symbols),
# não para uma carta — usado pela loja do Fragmento Arcano.
var _pending_symbol_to_chain: bool         = false

# Revelação "só olhar" da carta do topo do deck (efeito do Fragmento Arcano).
var _pending_reveal_player: int            = -1
var _pending_reveal_card: Card             = null

# Sobrecarga de Núcleo: fluxo de 2 fases. Fase 1 = jogador escolhe quais tokens destruir;
# fase 2 = distribui os pontos (1 por token destruído) entre ataque e defesa.
var _pending_overload_player: int          = -1
var _pending_overload_phase: int           = 0   # 0=nenhum, 1=selecionar tokens, 2=distribuir
var _pending_overload_points: int          = 0   # pontos a distribuir (= tokens destruídos)

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
# Descarte de quantidade VARIÁVEL: quando true, o jogador escolhe de 0 a _pending_pick_count
# cartas (não uma contagem exata). Usado por Incinerar Tudo. Serializado p/ o overlay.
var _pending_pick_variable: bool             = false
# Bônus de ataque por carta descartada de _pending_pick_bonus_symbol (ex.: Fogo → +2).
# Aplicado server-side ao resolver o descarte; não precisa ir no snapshot.
var _pending_pick_bonus_symbol: String       = ""
var _pending_pick_bonus_attack: int          = 0
var _pending_both_recycle_followup: int = -1
var _hero_was_hidden_at_play: Array[bool] = [false, false]

# ── habilidades de retaguarda interativas ───────────────
var _backline_queue:            Array[Dictionary] = []
var _backline_awaiting_response: bool = false
var _backline_awaiting_target:   bool = false
var _backline_current_player:    int  = -1
var _backline_current_hero_idx:  int  = -1

# ── passiva de descarte que quebra furtividade (Relicar) ─
# Fila de confirmações pendentes (1 por descarte de herói furtivo). _player >= 0
# indica que estamos aguardando a resposta Sim/Não do jogador.
var _stealth_passive_queue:     Array[Dictionary] = []
var _stealth_passive_player:    int  = -1
var _stealth_passive_hero_idx:  int  = -1
var _stealth_passive_card:      Card = null

# ── rolagem de dados de abertura (OPENING_ROLL) ─────────
# Cada jogador rola 2d6; maior total escolhe quem começa. Empate → re-roll.
var _dice_thrown:    Array[bool] = [false, false]          # cada jogador já arremessou?
var _dice_values:    Array       = [[0, 0], [0, 0]]        # 2d6 por jogador (0 = não rolado)
var _dice_throw_vec: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]  # vetor do arremesso (cosmético)
var _dice_winner:    int = -1                              # vencedor do dado (-1 = indefinido)
var _dice_awaiting_choice: bool = false                    # vencedor escolhendo quem começa
var _first_player:   int = -1                              # quem começa a partida (escolhido)

# ── confirmação de passiva de frontline que quebra furtividade (Valkar) ──
# Após ambos escolherem o herói ativo, um ativo com wants_frontline_confirm()
# ainda oculto pode optar por quebrar a furtividade e ativar a passiva (Muro de
# Aço). _player >= 0 indica que aguardamos a resposta Sim/Não desse jogador.
var _frontline_queue:           Array[Dictionary] = []
var _frontline_confirm_player:   int = -1
var _frontline_confirm_hero_idx: int = -1

# ── submissão de deck (multiplayer) ─────────────────────────────────────────
var _deck_submitted: Array[bool]  = [false, false]
var _submitted_deck: Array[Dictionary] = [{}, {}]

# ── mapeamento de peers (Modelo A) ───────────────────────────────────────────
var _match_peer_to_idx: Dictionary = {}

# ── rankeada ─────────────────────────────────────────────────────────────────
# _ranked: true quando a partida vale ranking (fila rankeada). _client_match_id é
# o UUID gerado no servidor ao criar a partida — chave de idempotência ao reportar
# o resultado a POST /ranked/result. Partidas casuais (salas) ficam ranked=false.
var _ranked: bool = false
var _client_match_id: String = ""

# ── debug ────────────────────────────────────────────────────────────────────
# _debug: true quando a partida veio de uma sala de teste (criada por ADMIN).
# Libera o botão DEBUG no board (dar qualquer carta à mão via rpc_debug_give_card).
var _debug: bool = false
