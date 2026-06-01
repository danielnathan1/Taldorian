class_name EffectFogoSymbolCountAttack
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var count := 0
	for card in ctx.source_player.cards_this_turn:
		for sym in card.symbols:
			if sym == "fogo":
				count += 1
	ctx.source_player.pending_bonus_attack += count
