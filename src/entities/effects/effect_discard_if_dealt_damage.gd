class_name EffectDiscardIfDealtDamage
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_discard_if_attacked = true
