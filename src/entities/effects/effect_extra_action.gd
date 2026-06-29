# Energizado — concede 1 ação extra neste turno (permite jogar outra carta ACTION no
# segmento). Consumido pelo GameState ao jogar a ação adicional.
class_name EffectExtraAction
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.extra_actions += _amount
