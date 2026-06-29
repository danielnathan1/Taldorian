class_name EffectDrawIfNthCard
extends CardEffect

var _n: int = 3
var _scope: String = "turn"  # "turn" = cards_this_battle (cumulativo no turno) | "combat" = turn_cards (rodada)

func setup(params: Dictionary) -> void:
	_n     = params.get("n", 3)
	_scope = params.get("scope", "turn")

# Avalia no momento de jogar (AFTER_REACTION padrão): a própria carta já está em
# cards_this_battle/turn_cards, então a contagem inclui ela + as anteriores. Com scope
# "turn" (cumulativo) a compra sai na hora. (scope "combat" conta só a rodada e, por ser
# no play, não enxerga uma bonus action jogada depois — hoje nenhuma carta usa "combat".)
func execute(ctx: CardEffectContext) -> void:
	var count: int
	if _scope == "combat":
		count = ctx.source_player.turn_cards.size()
	else:
		count = ctx.source_player.cards_this_battle.size()
	if count >= _n:
		ctx.source_player.draw_cards(1)
		ctx.request_vfx("draw")
