# src/entities/effects/effect_all_in.gd
# "All In" — se o ataque causou 0 de dano, o atacante sofre 1 e compra 1.
class_name EffectAllIn
extends CardEffect

func default_timing() -> int:
	return Timing.AFTER_COMBAT

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt == 0:
		var hero := ctx.source_player.active_hero
		if hero != null:
			hero.take_damage(1, TurnContext.new())
		ctx.source_player.draw_cards(1)
