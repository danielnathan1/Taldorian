class_name EffectDefenseIfBehind
extends CardEffect

var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	var my_hero  := ctx.source_player.active_hero
	var opp_hero := ctx.opponent_player.active_hero
	if my_hero == null or opp_hero == null:
		return
	if my_hero.current_hp < opp_hero.current_hp:
		ctx.source_player.pending_bonus_defense += _bonus
		ctx.request_empower(0, _bonus)
