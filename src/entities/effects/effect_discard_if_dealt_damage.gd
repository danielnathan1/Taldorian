# "Fúria Instável" — se o ataque causou dano, o atacante descarta 1 carta aleatória.
class_name EffectDiscardIfDealtDamage
extends CardEffect

func default_timing() -> int:
	return Timing.AFTER_COMBAT

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt > 0:
		ctx.source_player.discard_random_from_hand(1)
