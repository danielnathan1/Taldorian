class_name EffectAttackIfSymbolPlayed
extends CardEffect

var _symbol: String = ""
var _bonus: int = 1

func setup(params: Dictionary) -> void:
	_symbol = params.get("symbol", "")
	_bonus  = params.get("bonus", 1)

func execute(ctx: CardEffectContext) -> void:
	for card in ctx.source_player.cards_this_battle:
		if card == ctx.source_card:
			continue
		if _symbol in card.symbols:
			ctx.source_player.pending_bonus_attack += _bonus
			return
