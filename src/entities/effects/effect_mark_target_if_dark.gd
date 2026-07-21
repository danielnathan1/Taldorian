# Marca do Pacto — se você jogou OUTRA carta {DARK} neste turno (ou injetou símbolo Trevas
# na chain), *Marca* o herói ativo inimigo. Ver Hero.apply_mark.
class_name EffectMarkTargetIfDark
extends CardEffect

var _bonus: int = 1
var _turns: int = 1

func setup(params: Dictionary) -> void:
	_bonus = params.get("bonus", 1)
	_turns = params.get("turns", 1)

func execute(ctx: CardEffectContext) -> void:
	var played_dark := GameSymbols.TREVAS in ctx.source_player.bonus_chain_symbols
	if not played_dark:
		for card in ctx.source_player.cards_this_battle:
			if card == ctx.source_card:
				continue
			if GameSymbols.TREVAS in card.symbols:
				played_dark = true
				break
	if not played_dark:
		return
	var h := ctx.opponent_player.active_hero
	if h == null or not h.is_alive():
		return
	h.apply_mark(_bonus, _turns)
