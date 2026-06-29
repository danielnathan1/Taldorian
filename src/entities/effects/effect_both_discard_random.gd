# Colapso Mútuo — você e seu oponente descartam uma carta aleatória da mão.
class_name EffectBothDiscardRandom
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.discard_random_from_hand(_amount)
	ctx.opponent_player.discard_random_from_hand(_amount)
