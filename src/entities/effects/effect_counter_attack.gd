# src/entities/effects/effect_counter_attack.gd
class_name EffectCounterAttack
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_counter_damage += 1
