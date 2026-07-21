# Convergência (Relicar) — +atk e +def por elemento DISTINTO na chain (cartas jogadas
# no combate + símbolos injetados fora de carta, ex.: Fragmento Arcano).
class_name EffectBonusPerDistinctElement
extends CardEffect

var _atk: int = 1
var _def: int = 1

func setup(params: Dictionary) -> void:
	_atk = params.get("atk", 1)
	_def = params.get("def", 1)

func execute(ctx: CardEffectContext) -> void:
	var seen := {}
	for c in ctx.source_player.cards_this_battle:
		for s in c.symbols:
			seen[s] = true
	for s in ctx.source_player.bonus_chain_symbols:
		seen[s] = true
	var n := seen.size()
	if n > 0:
		ctx.source_player.pending_bonus_attack += _atk * n
		ctx.source_player.pending_bonus_defense += _def * n
		ctx.request_empower(_atk * n, _def * n)
