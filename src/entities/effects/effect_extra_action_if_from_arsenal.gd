# Circuito Aberto — se veio do arsenal, concede 1 ação extra neste turno.
class_name EffectExtraActionIfFromArsenal
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	if ctx.played_from_arsenal:
		ctx.source_player.extra_actions += _amount
