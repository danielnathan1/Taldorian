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

func clear_round_cards() -> void:
	round_cards.clear()

func clear_combat_cards() -> void:
	cards_this_turn.clear()
	round_cards.clear()

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
