class_name EffectDrawIfFullBlock
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_on_full_block_draw += 1
