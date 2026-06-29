# "Fúria Instável" — se o ataque causou dano, o atacante descarta 1 carta aleatória.
class_name EffectDiscardIfDealtDamage
extends CardEffect

func default_timing() -> int:
	return Timing.AFTER_TURN

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt > 0:
		for c in ctx.source_player.discard_random_from_hand(1):
			ctx.request_card_move(c.art_key, "discard")
