class_name EffectDirectDamageIfFirst
extends CardEffect

var _amount: int = 1

func setup(params: Dictionary) -> void:
	_amount = params.get("amount", 1)

func execute(ctx: CardEffectContext) -> void:
	if ctx.source_player.turn_cards.size() == 1:
		var opp_idx := ctx.opponent_player.player_index
		GameState._deal_direct_damage(opp_idx, _amount)
