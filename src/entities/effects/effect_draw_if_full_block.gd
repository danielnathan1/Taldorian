class_name EffectDrawIfFullBlock
extends CardEffect

func default_timing() -> int:
	return Timing.AFTER_COMBAT

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_taken == 0:
		ctx.source_player.draw_cards(1)
