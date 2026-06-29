# Ressonância Elétrica — +1 de ataque para cada símbolo de Raio (LIGHTNING) na sua chain.
# Conta os símbolos LIGHTNING das cartas jogadas nesta batalha (cards_this_battle) mais os
# símbolos injetados fora de carta (bonus_chain_symbols, ex.: Fragmento Arcano) — ou seja,
# a mesma chain montada por GameState._build_chain. NÃO usa o recurso lightning_charges.
class_name EffectAttackPerLightningCharge
extends CardEffect

var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	var count := 0
	for card in ctx.source_player.cards_this_battle:
		for sym in card.symbols:
			if sym == GameSymbols.RAIO:
				count += 1
	for sym in ctx.source_player.bonus_chain_symbols:
		if sym == GameSymbols.RAIO:
			count += 1
	ctx.source_player.pending_bonus_attack += count * _bonus
