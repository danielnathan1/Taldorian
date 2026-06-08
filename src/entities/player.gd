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

var cards_this_battle: Array[Card] = []   # todas as cartas jogadas no turno (para chain)
var turn_cards:     Array[Card] = []   # cartas jogadas na rodada corrente

# Pending modifiers — acumulados por efeitos ao jogar a carta,
# consumidos pelo CombatResolver, zerados por reset_turn_modifiers().
# Obs: efeitos condicionais ao RESULTADO do combate (bloqueio total, dano zero,
# contra-ataque, ricochete, etc.) foram migrados para efeitos AFTER_COMBAT e não
# usam mais campos pending — ver CardEffect.Timing.AFTER_COMBAT.
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
# Penalty de ataque para a carta OPOSTA — aplicado ao atacante adversário no próximo turn
var next_attack_penalty: int = 0
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

func reset_turn_modifiers() -> void:
	pending_bonus_attack = 0
	pending_bonus_defense = 0
	pending_self_damage = 0
	next_defense_penalty = 0
	pending_cancel_reaction = false
	pending_heal = 0
	pending_next_card_attack = 0
	pending_next_card_defense = 0
	next_attack_penalty = 0
	took_damage_this_turn = false
	pending_stealth_hidden_bonus = 0
	pending_next_turn_stealth = false
	pending_defense_scales_attack = false
	pending_skill_draw = false
	pending_return_card = null
	# pending_heal_return_card NÃO é zerado aqui — deve persistir até a fase END
	# processar o retorno à mão (erase de cards_this_battle + append em hand).

func clear_turn_cards() -> void:
	turn_cards.clear()

func clear_combat_cards() -> void:
	cards_this_battle.clear()
	turn_cards.clear()
	battle_bonus_attack = 0

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
