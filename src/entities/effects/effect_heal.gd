class_name EffectHeal
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	var hero := ctx.source_player.active_hero
	if hero == null:
		return
	hero.heal(_amount)
