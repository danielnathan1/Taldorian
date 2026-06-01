class_name EffectDefenseScalesAttack
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_defense_scales_attack = true
