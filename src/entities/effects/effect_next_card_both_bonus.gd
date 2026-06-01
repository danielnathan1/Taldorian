class_name EffectNextCardBothBonus
extends CardEffect

var _attack_bonus: int = 1
var _defense_bonus: int = 1

func setup(params: Dictionary) -> void:
	_attack_bonus  = params.get("attack_bonus",  1)
	_defense_bonus = params.get("defense_bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_next_card_attack  += _attack_bonus
	ctx.source_player.pending_next_card_defense += _defense_bonus
