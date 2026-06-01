class_name EffectHealReturnIfFull
extends CardEffect

var _amount: int = 2

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 2)

func execute(ctx: CardEffectContext) -> void:
	var p    := ctx.source_player
	var hero := p.active_hero
	if hero == null:
		return
	hero.heal(_amount)
	if hero.current_hp >= hero.max_hp:
		p.pending_heal_return_card = ctx.source_card
