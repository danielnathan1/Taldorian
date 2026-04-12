# src/entities/player.gd
class_name Player
extends RefCounted

var player_index: int = 0
var player_name: String
var heroes: Array[Hero] = []
var deck: Array[Card] = []
var hand: Array[Card] = []
var arsenal: Array[Card] = []
var active_hero: Hero = null

var attacks_this_turn: Array[Card] = []
var defenses_this_turn: Array[Card] = []

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

func clear_combat_cards() -> void:
	attacks_this_turn.clear()
	defenses_this_turn.clear()

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
