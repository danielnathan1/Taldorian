class_name EffectDrawOne
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	ctx.source_player.draw_cards(1)
