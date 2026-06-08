# src/entities/effects/effect_counter_attack.gd
# "Contra Ataque" — se o herói defensor bloqueou tudo (não tomou dano),
# o herói ativo do oponente sofre 1 de dano (mitigado por escudo).
class_name EffectCounterAttack
extends CardEffect

func default_timing() -> int:
	return Timing.AFTER_COMBAT

func resolve_after_combat(ctx: CardEffectContext) -> void:
	if ctx.damage_taken != 0:
		return
	var foe := ctx.opponent_player.active_hero
	if foe == null:
		return
	var dmg := foe.absorb_shield(1)
	if dmg > 0:
		foe.take_damage(dmg, TurnContext.new())
