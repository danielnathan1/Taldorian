class_name EffectDrawIfNthCard
extends CardEffect

var _n: int = 3
var _scope: String = "turn"  # "turn" ou "combat"

func setup(params: Dictionary) -> void:
	_n     = params.get("n", 3)
	_scope = params.get("scope", "turn")

func execute(ctx: CardEffectContext) -> void:
	var count: int
	if _scope == "combat":
		count = ctx.source_player.round_cards.size()
	else:
		count = ctx.source_player.cards_this_turn.size()
	if count >= _n:
		ctx.source_player.draw_cards(1)
