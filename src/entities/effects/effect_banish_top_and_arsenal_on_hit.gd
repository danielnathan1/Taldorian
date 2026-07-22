# Colapso Mental — on-hit: bane `count` do topo do deck inimigo E o arsenal do oponente
# (exila a carta guardada). Ver GameState.banish_from_deck_top / Player.send_to_banish.
class_name EffectBanishTopAndArsenalOnHit
extends CardEffect

var _count: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_count = params.get("count", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	var opp := ctx.opponent_player
	GameState.banish_from_deck_top(opp.player_index, _count)
	while not opp.arsenal.is_empty():
		opp.send_to_banish(opp.arsenal.pop_back())
