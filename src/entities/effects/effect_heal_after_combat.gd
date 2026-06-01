class_name EffectHealAfterCombat
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_heal_after_combat += _amount
