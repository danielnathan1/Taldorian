# src/entities/effects/effect_fogo_chain_attack.gd
class_name EffectFogoChainAttack
extends CardEffect

func execute(ctx: CardEffectContext) -> void:
	var count := 0
	for card in ctx.source_player.cards_this_turn:
		for sym in card.get_symbol_ids():
			if sym == GameSymbols.FOGO:
				count += 1
	ctx.source_player.pending_bonus_attack += count
	ctx.source_player.pending_self_damage += 2
