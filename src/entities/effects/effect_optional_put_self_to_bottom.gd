class_name EffectOptionalPutSelfToBottom
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.pending_return_card = ctx.source_card
