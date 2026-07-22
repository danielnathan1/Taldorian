# Legião dos Caídos — bane `count` cartas do elemento `element` do SEU cemitério para ganhar
# `attack` de ataque. Fizzle se não houver cartas suficientes desse elemento (custo não pago).
class_name EffectBanishGraveyardForAttack
extends CardEffect

var _element: String = "trevas"
var _count: int = 3
var _attack: int = 4

func setup(params: Dictionary) -> void:
	_element = params.get("element", "trevas")
	_count   = params.get("count", 3)
	_attack  = params.get("attack", 4)

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	var matching: Array[Card] = []
	for c in p.discard_pile:
		if _element in c.symbols:
			matching.append(c)
	if matching.size() < _count:
		return
	for i in _count:
		var c := matching[i]
		p.discard_pile.erase(c)
		p.send_to_banish(c)
	p.pending_bonus_attack += _attack
