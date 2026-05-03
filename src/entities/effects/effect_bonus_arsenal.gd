# src/entities/effects/effect_bonus_arsenal.gd
class_name EffectBonusArsenal
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	if ctx.played_from_arsenal:
		ctx.source_player.pending_bonus_defense += 2
