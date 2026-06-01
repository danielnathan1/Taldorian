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

var cards_this_turn: Array[Card] = []   # todas as cartas jogadas no turno (para chain)
var round_cards:     Array[Card] = []   # cartas jogadas na rodada corrente

# Pending modifiers — acumulados por efeitos ao jogar a carta,
# consumidos pelo CombatResolver, zerados por reset_round_modifiers()
var pending_bonus_attack: int = 0
var pending_bonus_defense: int = 0
var passive_attack_bonus: int = 0  # sincronizado pelo snapshot — usado só na UI
var pending_self_damage: int = 0
var pending_destroy_opponent_arsenal: bool = false
var pending_counter_damage: int = 0
var next_defense_penalty: int = 0
var pending_cancel_reaction: bool = false
var pending_on_zero_damage_self_damage: int = 0
var pending_on_zero_damage_draw: int = 0
# Cura aplicada ao resolver o combate
var pending_heal: int = 0
var pending_heal_after_combat: int = 0
# Bônus que se transfere para a próxima carta jogada
var pending_next_card_attack: int = 0
var pending_next_card_defense: int = 0
# Bônus cross-round — transferido para pending_bonus_attack no próximo combate
var next_round_bonus_attack: int = 0
# Bônus cross-round condicional: convertido em next_round_bonus_attack SÓ se o herói
# não tomar dano no combate atual (Guarda Inabalável). Zerado por reset_round_modifiers().
var pending_cross_round_if_no_damage: int = 0
# Bônus de ataque que dura o turno inteiro (ex: Frenesi) — só zerado em clear_combat_cards()
var turn_bonus_attack: int = 0
# Reação a bloqueio completo / dano zero
var pending_on_full_block_draw: int = 0
var pending_on_full_block_heal: int = 0
var pending_on_no_damage_heal: int = 0
# Penalty de ataque para a carta OPOSTA — aplicado ao atacante adversário no próximo round
var next_attack_penalty: int = 0
# Flag de turno: herói sofreu dano nesta rodada (para Sangue Quente)
var took_damage_this_round: bool = false
# Descarte pós-dano: se causou dano este combate, descarta 1 da mão
var pending_discard_if_attacked: bool = false
# Cura para todos os heróis aliados (Florescer Eterno)
var pending_heal_all_amount: int = 0
# Ricochetear: se causou dano, causa 1 dano direto de volta ao oponente
var pending_ricochet: bool = false
# Bloqueio completo: descarte aleatório
var pending_on_full_block_discard_random: int = 0
# Stealth oculto no combate: bônus de ataque se herói estava oculto ao jogar
var pending_stealth_hidden_bonus: int = 0
# Cross-round stealth: se causou dano, próximo combate começa oculto
var next_round_stealth: bool = false
# Pending: ativa stealth cross-round se causar dano este round (Execução Silenciosa)
var pending_next_round_stealth: bool = false
# Defesa espelha ataque (Fortaleza Inabalável)
var pending_defense_scales_attack: bool = false
# Habilidade ativa dispara compra (Sintonia Primordial)
var pending_skill_draw: bool = false
# Carta que retorna ao baralho ao fim do turno (Onda Reversa)
var pending_return_card: Card = null
# Cura e retorna à mão se HP cheio (Ciclo Vital)
var pending_heal_return_card: Card = null

const HAND_CAP_START := 6
const HAND_SIZE_REFILL_DRAW := 4

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

func discard_random_from_hand(amount: int) -> void:
	for i in mini(amount, hand.size()):
		var idx := randi() % hand.size()
		discard_pile.append(hand[idx])
		hand.remove_at(idx)

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

func reset_round_modifiers() -> void:
	pending_bonus_attack = 0
	pending_bonus_defense = 0
	pending_self_damage = 0
	pending_destroy_opponent_arsenal = false
	pending_counter_damage = 0
	next_defense_penalty = 0
	pending_cancel_reaction = false
	pending_on_zero_damage_self_damage = 0
	pending_on_zero_damage_draw = 0
	pending_heal = 0
	pending_heal_after_combat = 0
	pending_next_card_attack = 0
	pending_next_card_defense = 0

	pending_on_full_block_draw = 0
	pending_on_full_block_heal = 0
	pending_on_no_damage_heal = 0
	next_attack_penalty = 0
	took_damage_this_round = false
	pending_discard_if_attacked = false
	pending_heal_all_amount = 0
	pending_ricochet = false
	pending_on_full_block_discard_random = 0
	pending_stealth_hidden_bonus = 0
	pending_next_round_stealth = false
	pending_defense_scales_attack = false
	pending_skill_draw = false
	pending_return_card = null
	# pending_heal_return_card NÃO é zerado aqui — deve persistir até a fase END
	# processar o retorno à mão (erase de cards_this_turn + append em hand).
	pending_cross_round_if_no_damage = 0

func clear_round_cards() -> void:
	round_cards.clear()

func clear_combat_cards() -> void:
	cards_this_turn.clear()
	round_cards.clear()
	turn_bonus_attack = 0

func reset_hero_round_state() -> void:
	for h in heroes:
		h.on_round_reset()

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
