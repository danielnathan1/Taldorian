# Sacrifício Elemental — banir 1 carta do elemento `element` da SUA mão (custo, auto-escolhe
# a primeira) → o oponente bane `opponent_banish` do topo do deck. Fizzle se você não tiver
# carta desse elemento na mão. Ver GameState.banish_from_deck_top / Player.send_to_banish.
class_name EffectSacrificeElementBanish
extends CardEffect

var _element: String = "trevas"
var _opponent_banish: int = 2

func setup(params: Dictionary) -> void:
	_element = params.get("element", "trevas")
	_opponent_banish = params.get("opponent_banish", 2)

func execute(ctx: CardEffectContext) -> void:
	var p := ctx.source_player
	var idx := -1
	for i in p.hand.size():
		if _element in p.hand[i].symbols:
			idx = i
			break
	if idx < 0:
		return
	var card := p.hand[idx]
	p.hand.remove_at(idx)
	p.send_to_banish(card)
	GameState.banish_from_deck_top(ctx.opponent_player.player_index, _opponent_banish)
