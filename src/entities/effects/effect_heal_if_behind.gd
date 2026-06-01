class_name EffectHealIfBehind
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	var my_hero := ctx.source_player.active_hero
	var opp_hero := ctx.opponent_player.active_hero
	if my_hero == null or opp_hero == null:
		return
	if my_hero.current_hp < opp_hero.current_hp:
		my_hero.heal(_amount)
