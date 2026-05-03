# src/entities/effects/effect_all_in.gd
class_name EffectAllIn
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_on_zero_damage_self_damage += 1
	ctx.source_player.pending_on_zero_damage_draw += 1
