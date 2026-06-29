# src/entities/effects/effect_destroy_arsenal.gd
# "Quebrando a Banca" — se o ataque causou dano, destrói o arsenal do oponente.
class_name EffectDestroyArsenal
extends CardEffect

func default_timing() -> int:
	return Timing.AFTER_TURN

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_dealt > 0:
		ctx.opponent_player.arsenal.clear()
