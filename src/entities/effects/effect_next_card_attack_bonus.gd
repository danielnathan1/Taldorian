class_name EffectNextCardAttackBonus
extends CardEffect

var _bonus: int = 2

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 2)

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_next_card_attack += _bonus
