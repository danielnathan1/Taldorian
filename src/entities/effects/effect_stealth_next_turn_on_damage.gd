# "Golpe Furtivo" — marca para iniciar o próximo turno furtivo. A promoção de
# pending_next_turn_stealth → next_turn_stealth só acontece no CombatResolver se o
# herói ativo de fato causar dano neste turno (ver combat_resolver.gd).
class_name EffectStealthNextTurnOnDamage
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_next_turn_stealth = true
	ctx.request_vfx("stealth")
