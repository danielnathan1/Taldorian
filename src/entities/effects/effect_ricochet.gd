class_name EffectRicochet
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_ricochet = true
