class_name EffectDrawDiscardIfFullBlock
extends CardEffect

var _draw: int = 1
var _discard: int = 1

func default_timing() -> int:
	return Timing.AFTER_COMBAT

func setup(params: Dictionary) -> void:
	_draw    = params.get("draw",    1)
	_discard = params.get("discard", 1)

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_taken == 0:
		ctx.source_player.draw_cards(_draw)
		ctx.source_player.discard_random_from_hand(_discard)
