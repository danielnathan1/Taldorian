# src/entities/effects/effect_weaken_defense.gd
class_name EffectWeakenDefense
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.opponent_player.next_defense_penalty += 1
