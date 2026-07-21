# Ressonância Umbral — +`per` de ataque por símbolo {DARK} (Trevas) na chain (cartas jogadas
# no turno + símbolos injetados). Ver Player.cards_this_battle / bonus_chain_symbols.
class_name EffectAttackPerDarkSymbol
extends CardEffect

var _per: int = 1

func setup(params: Dictionary) -> void:
	_per = params.get("per", 1)

func execute(ctx: CardEffectContext) -> void:
	var count := 0
	for card in ctx.source_player.cards_this_battle:
		for sym in card.symbols:
			if sym == GameSymbols.TREVAS:
				count += 1
	for sym in ctx.source_player.bonus_chain_symbols:
		if sym == GameSymbols.TREVAS:
			count += 1
	if count > 0:
		ctx.source_player.pending_bonus_attack += count * _per
