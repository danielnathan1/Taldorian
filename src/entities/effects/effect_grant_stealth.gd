# Névoa (Ritmo Calculado) — a furtividade DESTE turno vem da flag is_stealth da carta.
# Este efeito trata o "se não sofrer dano, continua furtivo no próximo turno": marca
# next_turn_stealth quando o herói ativo não sofreu dano, consumido em
# GameState._finish_turn_combat (que oculta o herói no próximo turno).
class_name EffectGrantStealth
extends CardEffect

func default_timing() -> int:
	return Timing.AFTER_TURN

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_taken > 0:
		return
	ctx.source_player.next_turn_stealth = true
	ctx.request_vfx("stealth")
