# Banir on-hit (Sussurro do Vazio, Fenda Abissal) — se causar dano neste combate, bane
# `count` cartas do topo do deck inimigo (exílio). Ver GameState.banish_from_deck_top.
class_name EffectBanishTopOnHit
extends CardEffect

var _count: int = 1

func default_timing() -> int:
	return Timing.AFTER_TURN

func setup(params: Dictionary) -> void:
	_count = params.get("count", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt <= 0:
		return
	GameState.banish_from_deck_top(ctx.opponent_player.player_index, _count)
