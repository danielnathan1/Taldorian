# src/entities/card.gd
class_name Card
extends RefCounted

enum CardType { ATTACK, DEFENSE, EFFECT }

var card_name: String
var card_type: CardType
var value: int                  # +1, +2, +3
## IDs de símbolo (`String`, ex.: GameSymbols.FOGO); um ou N por carta.
var symbols: Array[String] = []
var is_stealth: bool = false    # carta furtiva não revela herói


## Aceita `Array` “solto” (ex.: linha do baralho em `game_state`) e normaliza para `Array[String]` válido.
func set_symbols(ids: Array) -> void:
	symbols = GameSymbols.filter_valid(ids)


func get_symbol_ids() -> Array[String]:
	return symbols.duplicate()
	
func get_type_label()-> String:
	return CardType.keys()[card_type]


func symbols_display() -> String:
	return GameSymbols.display_chain(symbols)


static func from_dict(data: Dictionary) -> Card:
	var c = Card.new()
	c.card_name = data.get("name", "")
	c.card_type = CardType[data.get("type", "ATTACK").to_upper()]
	c.value = data.get("value", 1)
	c.set_symbols(data.get("symbols", []))
	c.is_stealth = data.get("stealth", false)
	return c
