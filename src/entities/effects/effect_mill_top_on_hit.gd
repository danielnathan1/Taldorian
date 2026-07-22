# Moer on-hit (Ceifar) — se causar dano neste combate, manda `count` cartas do topo do deck
# inimigo para o CEMITÉRIO dele (recuperável, diferente de banir). Ver GameState.mill_from_deck_top.
class_name EffectMillTopOnHit
extends CardEffect

var _count: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_count = params.get("count", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	GameState.mill_from_deck_top(ctx.opponent_player.player_index, _count)
