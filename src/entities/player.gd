# src/entities/player.gd
class_name Player
extends RefCounted

var player_index: int = 0
var player_name: String
var sleeve_key: String = "default"
var playmat_key: String = "default"
var heroes: Array[Hero] = []
var deck: Array[Card] = []
var hand: Array[Card] = []
var arsenal: Array[Card] = []
var arsenal_face_up: bool = false   # true apenas quando um efeito explicitamente define face-up
var discard_pile: Array[Card] = []
var active_hero: Hero = null

## Tokens que o jogador controla (ex.: Mísseis Mágicos do Nox). Criados em jogo, fora
## do deck. Tempo de vida por token (Token.destroy_at_combat_end): alguns somem quando
## o combate resolve, outros persistem no campo até serem usados (clear_combat_end_tokens).
var tokens: Array[Token] = []

var cards_this_battle: Array[Card] = []   # todas as cartas jogadas no turno (para chain)
var turn_cards:     Array[Card] = []   # cartas jogadas na rodada corrente
# Símbolos extras injetados na chain fora de cartas (ex.: efeito do Fragmento Arcano).
# Mesma vida da chain — contam para o gatilho da skill, somados a cards_this_battle.
var bonus_chain_symbols: Array[String] = []
# Posicao (nº de cartas ja jogadas) de cada simbolo de fragmento — preserva a ordem
# cronologica real ao intercalar com as cartas em _build_chain. Paralelo a bonus_chain_symbols.
var bonus_chain_positions: Array[int] = []

# Pending modifiers — acumulados por efeitos ao jogar a carta,
# consumidos pelo CombatResolver, zerados por reset_turn_modifiers().
# Obs: efeitos condicionais ao RESULTADO do combate (bloqueio total, dano zero,
# contra-ataque, ricochete, etc.) foram migrados para efeitos AFTER_TURN e não
# usam mais campos pending — ver CardEffect.Timing.AFTER_TURN.
var pending_bonus_attack: int = 0
var pending_bonus_defense: int = 0
var passive_attack_bonus: int = 0  # sincronizado pelo snapshot — usado só na UI
var pending_self_damage: int = 0
var next_defense_penalty: int = 0
var pending_cancel_reaction: bool = false
# Cura aplicada ao resolver o combate
var pending_heal: int = 0
# Bônus que se transfere para a próxima carta jogada
var pending_next_card_attack: int = 0
var pending_next_card_defense: int = 0
# Bônus cross-turn — transferido para pending_bonus_attack no próximo combate
var next_turn_bonus_attack: int = 0
# Bônus de ataque que dura o turno inteiro (ex: Frenesi) — só zerado em clear_combat_cards()
var battle_bonus_attack: int = 0
# Penalty de ataque que dura o turno inteiro (ex.: Finta) — reduz o ataque DESTE jogador.
# Keyed no próprio jogador debuffado (intuitivo). Só zerado em clear_combat_cards().
var battle_attack_penalty: int = 0
# Flag de turno: herói sofreu dano nesta rodada (para Sangue Quente)
var took_damage_this_turn: bool = false
# Stealth oculto no combate: bônus de ataque se herói estava oculto ao jogar
var pending_stealth_hidden_bonus: int = 0
# Cross-turn stealth: se causou dano, próximo combate começa oculto
var next_turn_stealth: bool = false
# Pending: ativa stealth cross-turn se causar dano este turn (Execução Silenciosa)
var pending_next_turn_stealth: bool = false
# Defesa espelha ataque (Fortaleza Inabalável)
var pending_defense_scales_attack: bool = false
# Habilidade ativa dispara compra (Sintonia Primordial)
var pending_skill_draw: bool = false
# Carta que retorna ao baralho ao fim do turno (Onda Reversa)
var pending_return_card: Card = null
# Cura e retorna à mão se HP cheio (Ciclo Vital)
var pending_heal_return_card: Card = null

# ── Raio / Lightning ─────────────────────────────────────────────────────────
# Não há contador de "carga de Raio": cartas como Descarga Preparada / Acúmulo Estático
# injetam um símbolo LIGHTNING na chain (add_chain_symbol). Ressonância Elétrica conta
# os símbolos de Raio na chain (cards_this_battle + bonus_chain_symbols).
# Ações extras concedidas neste turno (Energizado / Circuito Aberto). Permitem jogar
# uma ACTION adicional no segmento. Vida = turno.
var extra_actions: int = 0
# Marca de Caçador: herói inimigo que recebe dano extra ao ser atingido neste turno.
var marked_target: Hero = null
var marked_bonus: int = 0
# Ataque travado neste combate (Acúmulo Telúrico) — bônus positivos de ataque são ignorados.
var pending_attack_locked: bool = false

const HAND_CAP_START := 6
const HAND_SIZE_REFILL_DRAW := 4

## True se `target_hero` está protegido contra dano direcionado/direto por um aliado na
## linha de frente (ex: Muro de Aço da Valkar). A própria linha de frente NÃO é protegida —
## a passiva cobre apenas os aliados de retaguarda.
func is_targeting_protected(target_hero: Hero) -> bool:
	if active_hero == null or target_hero == active_hero:
		return false
	return active_hero.is_alive() and active_hero.protects_backline_from_targeting()

func get_available_heroes() -> Array[Hero]:
	return heroes.filter(func(h): return h.state == Hero.State.ACTIVE)

func choose_hero(hero: Hero) -> void:
	assert(hero in get_available_heroes(), "Herói indisponível")
	active_hero = hero

func draw_up_to(target_hand_size: int) -> void:
	while hand.size() < target_hand_size and not deck.is_empty():
		hand.append(deck.pop_front())
		GameBus.card_drawn.emit(player_index)

func draw_cards(amount: int) -> void:
	for i in amount:
		if deck.is_empty():
			break
		hand.append(deck.pop_front())
		GameBus.card_drawn.emit(player_index)

## Move uma carta (já removida da mão pelo chamador) ao cemitério e emite o
## evento de descarte — gatilho de passivas como a do Relicar (Fragmento Arcano).
## NÃO usar para cartas jogadas indo ao cemitério no fim do turno (aquilo não é
## "descarte pelo jogador" — usar discard_pile.append direto para isso).
func send_to_discard(card: Card) -> void:
	discard_pile.append(card)
	GameBus.card_discarded.emit(player_index, card)

## Descarta `amount` cartas aleatórias da mão e devolve as cartas descartadas
## (para o chamador animar/notificar o descarte de cada uma).
func discard_random_from_hand(amount: int) -> Array[Card]:
	var discarded: Array[Card] = []
	for i in mini(amount, hand.size()):
		var idx := randi() % hand.size()
		var card: Card = hand[idx]
		hand.remove_at(idx)
		send_to_discard(card)
		discarded.append(card)
	return discarded

func send_cards_to_bottom(cards: Array[Card]) -> void:
	for card in cards:
		hand.erase(card)
		deck.append(card)

func store_in_arsenal(card: Card) -> void:
	assert(card in hand, "Carta fora da mão")
	hand.erase(card)
	if not arsenal.is_empty():
		deck.append(arsenal.pop_back())
	arsenal.append(card)
	arsenal_face_up = false   # comportamento padrão: face-down (sleeve)

func reset_turn_modifiers() -> void:
	pending_bonus_attack = 0
	pending_bonus_defense = 0
	pending_self_damage = 0
	next_defense_penalty = 0
	pending_cancel_reaction = false
	pending_heal = 0
	pending_next_card_attack = 0
	pending_next_card_defense = 0
	took_damage_this_turn = false
	pending_stealth_hidden_bonus = 0
	pending_next_turn_stealth = false
	pending_defense_scales_attack = false
	pending_skill_draw = false
	pending_attack_locked = false
	# pending_return_card NÃO é zerado aqui — assim como pending_heal_return_card,
	# precisa persistir através das rodadas até a fase END processar o retorno
	# (Onda Reversa → fundo do deck). reset_turn_modifiers roda a cada combate de
	# rodada; zerar aqui mandava a carta ao cemitério em vez do deck. Ambos são
	# setados para null após o processamento em GameState._run_combat_and_enter_end.

func clear_turn_cards() -> void:
	turn_cards.clear()

func clear_combat_cards() -> void:
	cards_this_battle.clear()
	turn_cards.clear()
	bonus_chain_symbols.clear()
	bonus_chain_positions.clear()
	battle_bonus_attack = 0
	battle_attack_penalty = 0
	# Recursos de turno (ações extras / marca) zeram no fim do turno.
	extra_actions = 0
	marked_target = null
	marked_bonus = 0

## Ataque "atual" projetado deste jogador para o combate da rodada: base do herói
## ativo + ataque das cartas da rodada + bônus pendentes (a menos que travado),
## menos o battle_attack_penalty (debuff do turno, ex.: Finta). Espelha CombatResolver.
func current_attack() -> int:
	if active_hero == null:
		return 0
	var atk := active_hero.base_attack
	for card in turn_cards:
		atk += card.attack_value
	if not pending_attack_locked:
		atk += pending_bonus_attack
		atk += battle_bonus_attack
		atk += pending_stealth_hidden_bonus
	atk -= battle_attack_penalty
	return atk

## Injeta um símbolo "fora de carta" na chain (ex.: Descarga Preparada → Raio).
## Mantém bonus_chain_symbols e bonus_chain_positions paralelos; a posição é o número
## de cartas já jogadas, para intercalar cronologicamente em GameState._build_chain.
## O VFX do símbolo e a re-verificação da skill são feitos pelo GameState após o efeito.
func add_chain_symbol(sym: String) -> void:
	bonus_chain_symbols.append(sym)
	bonus_chain_positions.append(cards_this_battle.size())

# ── Habilidades ativadas disponíveis ao jogador ──────────────────────────────
## Reúne as habilidades ativadas disponíveis AGORA: do herói ativo + dos tokens
## controlados (1 entrada por token_id, pois tokens iguais expõem a mesma ação).
## Ponto único consumido pelo GameState (validação/timing) e pelo board (ícones).
func get_active_abilities(opponent: Player) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if active_hero != null:
		out.append_array(active_hero.get_active_abilities(self, opponent))
	var seen := {}
	for t in tokens:
		if seen.has(t.token_id):
			continue
		seen[t.token_id] = true
		var ab := t.get_active_ability(self, opponent)
		if not ab.is_empty():
			out.append(ab)
	return out

## Despacha a ativação de uma habilidade pelo `ability_id`, localizando o dono
## (herói ativo ou token) sem que o chamador precise saber qual é. Retorna o label.
func activate_ability(ability_id: String, opponent: Player, targets: Array) -> String:
	if active_hero != null:
		for a in active_hero.get_active_abilities(self, opponent):
			if str(a.get("id", "")) == ability_id:
				return active_hero.activate_ability(ability_id, self, opponent, targets)
	var seen := {}
	for t in tokens:
		if seen.has(t.token_id):
			continue
		seen[t.token_id] = true
		var ab := t.get_active_ability(self, opponent)
		if not ab.is_empty() and str(ab.get("id", "")) == ability_id:
			return t.activate_ability(ability_id, self, opponent, targets)
	return ""

## Conta quantos tokens de um dado id o jogador controla.
func count_tokens(token_id: String) -> int:
	var n := 0
	for t in tokens:
		if t.token_id == token_id:
			n += 1
	return n

## Destrói todos os tokens (reset total).
func clear_tokens() -> void:
	tokens.clear()

## Destrói apenas os tokens marcados para sumir quando o combate resolve (ex.: Mísseis
## Mágicos). Tokens persistentes (ex.: Fragmento Arcano) permanecem no campo.
func clear_combat_end_tokens() -> void:
	var kept: Array[Token] = []
	for t in tokens:
		if not t.destroy_at_combat_end:
			kept.append(t)
	tokens = kept

func reset_hero_turn_state() -> void:
	for h in heroes:
		h.on_turn_reset()

func exhaust_active_hero() -> void:
	if active_hero and active_hero.state != Hero.State.DEFEATED:
		active_hero.exhaust()
	_check_rotation()

func _check_rotation() -> void:
	var living: Array[Hero] = heroes.filter(func(h): return h.state != Hero.State.DEFEATED)
	if living.is_empty():
		return
	var all_exhausted := true
	for h in living:
		if h.state != Hero.State.EXHAUSTED:
			all_exhausted = false
			break
	if all_exhausted:
		for h in living:
			h.refresh()
